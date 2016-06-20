#
#    ICRAR - International Centre for Radio Astronomy Research
#    (c) UWA - The University of Western Australia
#    Copyright by UWA (in the framework of the ICRAR)
#    All rights reserved
#
#    This library is free software; you can redistribute it and/or
#    modify it under the terms of the GNU Lesser General Public
#    License as published by the Free Software Foundation; either
#    version 2.1 of the License, or (at your option) any later version.
#
#    This library is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
#    Lesser General Public License for more details.
#
#    You should have received a copy of the GNU Lesser General Public
#    License along with this library; if not, write to the Free Software
#    Foundation, Inc., 59 Temple Place, Suite 330, Boston,
#    MA 02111-1307  USA
#
"""
Build the graph
"""
import os
import uuid

from dfms.apps.bash_shell_app import BashShellApp
from dfms.drop import dropdict, BarrierAppDROP

from build_graph.common import get_module_name


class BuildGraph(object):
    def __init__(self, files_to_process, parallel_streams, nodes):
        self._files_to_process = files_to_process
        self._parallel_streams = parallel_streams
        self._nodes = nodes

        self._map_carry_over_data = {}
        self._counters = {}
        self._drop_list = []
        self._start_oids = []

        # Clear all the carry over nodes
        for node in nodes:
            self._map_carry_over_data[node] = None
        self._list_ip = self._map_carry_over_data.keys()

    def build_graph(self):
        for file_to_process in self._files_to_process:
            head, tail = os.path.splitext(file_to_process)
            output_filename = head + '.fits'
            node_id = self._get_next_node()

            carry_over_data = self._map_carry_over_data[node_id]

            file_drop_input_fit_file = self.create_file_drop(
                node_id,
                file_to_process,
            )
            file_drop_fits_file = self.create_file_drop(
                node_id,
                output_filename,
            )
            bash_drop = self.create_bash_shell_app(
                node_id,
                '/usr/local/star-kapuahi/bin/imcopy %i0 %o0'
            )
            bash_drop.addInput(file_drop_input_fit_file)
            bash_drop.addOutput(file_drop_fits_file)

            if carry_over_data is None:
                self._start_oids.append(file_drop_input_fit_file['uid'])
            else:
                bash_drop.addInput(carry_over_data)

            self._map_carry_over_data[node_id] = carry_over_data

            counter = 0
            streams = [None] * self._parallel_streams
            for process_id in range(2, 18):
                file_drop_r_fits_file = self.create_file_drop(
                    node_id,
                    '{0}_{1}_r.fits'.format(head, process_id - 1),
                )
                bash_drop_r = self.create_bash_shell_app(
                    node_id,
                    '/gamah/simon/codes/renorm/preprocess.r %i0 {0} %o0'.format(process_id)
                )
                bash_drop_r.addInput(file_drop_fits_file)
                bash_drop_r.addOutput(file_drop_r_fits_file)

                if streams[counter] is not None:
                    bash_drop_r.addInput(streams[counter])

                streams[counter] = file_drop_r_fits_file

                counter += 1
                if counter >= self._parallel_streams:
                    counter = 0

            barrier_app = self.create_barrier_app(
                node_id
            )
            for drop in streams:
                if drop is not None:
                    barrier_app.addInput(drop)

            memory_drop = self.create_memory_drop(node_id)
            barrier_app.addOutput(memory_drop)
            self._map_carry_over_data[node_id] = memory_drop

    @property
    def drop_list(self):
        return self._drop_list

    def _get_next_node(self):
        next_node = self._list_ip[self._node_index]
        self._node_index += 1
        if self._node_index >= len(self._list_ip):
            self._node_index = 0

        return next_node

    @property
    def start_oids(self):
        return self._start_oids

    def add_drop(self, drop):
        self._drop_list.append(drop)

    def get_oid(self, count_type):
        count = self._counters.get(count_type)
        if count is None:
            count = 1
        else:
            count += 1
        self._counters[count_type] = count

        return '{0}__{1:06d}'.format(count_type, count)

    @staticmethod
    def get_uuid():
        return str(uuid.uuid4())

    def create_file_drop(self, node_id, filepath, oid='file'):
        oid_text = self.get_oid(oid)
        uid_text = self.get_uuid()
        drop = dropdict({
            "type": 'plain',
            "storage": 'file',
            "oid": oid_text,
            "uid": uid_text,
            "precious": False,
            "filepath": filepath,
            "node": node_id,
        })
        self.add_drop(drop)
        return drop

    def create_bash_shell_app(self, node_id, command, oid='bash_shell_app', input_error_threshold=100):
        oid_text = self.get_oid(oid)
        uid_text = self.get_uuid()
        drop = dropdict({
            "type": 'app',
            "app": get_module_name(BashShellApp),
            "oid": oid_text,
            "uid": uid_text,
            "command": command,
            "input_error_threshold": input_error_threshold,
            "node": node_id,
        })
        self.add_drop(drop)
        return drop

    def create_barrier_app(self, node_id, oid='barrier_app', input_error_threshold=100):
        oid_text = self.get_oid(oid)
        uid_text = self.get_uuid()
        drop = dropdict({
            "type": 'app',
            "app": get_module_name(BarrierAppDROP),
            "oid": oid_text,
            "uid": uid_text,
            "input_error_threshold": input_error_threshold,
            "node": node_id,
        })
        self.add_drop(drop)
        return drop

    def create_memory_drop(self, node_id, oid='memory_drop'):
        oid_text = self.get_oid(oid)
        uid_text = self.get_uuid()
        drop = dropdict({
            "type": 'plain',
            "storage": 'memory',
            "oid": oid_text,
            "uid": uid_text,
            "precious": False,
            "node": node_id,
        })
        self.add_drop(drop)
        return drop
