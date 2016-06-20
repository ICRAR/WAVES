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
Build the daluige graph for WAVES
"""
import argparse
import glob
import json
import logging
import os
from time import sleep

from configobj import ConfigObj
from os.path import exists, isdir, join

from build_graph.build import BuildGraph
from build_graph.common import get_argument

LOG = logging.getLogger(__name__)


def do_json(input_directory, parallel_streams, nodes):
    if not exists(input_directory) or not isdir(input_directory):
        LOG.warning('{0} is not a directory'.format(input_directory))
        return

    # Get a list of file names
    files_to_process = []
    file_pattern = join(input_directory, '*.fit')
    for match in glob.glob(file_pattern):
        files_to_process.append(match)

    graph = BuildGraph(
        files_to_process,
        parallel_streams,
        nodes,
    )
    graph.build_graph()
    json_dumps = json.dumps(graph.drop_list, indent=2)
    LOG.info(json_dumps)
    with open("/tmp/json_waves.txt", "w") as json_file:
        json_file.write(json_dumps)


def command_json(args):
    do_json(
        args.input_directory,
        args.parallel_streams,
        args.nodes.split(','),
    )


def command_interactive(args):
    LOG.info(args)
    sleep(0.5)  # Allow the logging time to print
    path_dirname, filename = os.path.split(__file__)
    config_file_name = '{0}/aws-chiles02.settings'.format(path_dirname)
    if os.path.exists(config_file_name):
        config = ConfigObj(config_file_name)
    else:
        config = ConfigObj()
        config.filename = config_file_name

    get_argument(config, 'use_json', 'Use or json', allowed=['use', 'json'], help_text='the use a network or create a network')
    get_argument(config, 'input_directory', 'Input directory', help_text='where to read the input files from')

    if config['use_json'] == 'use':
        pass
    else:
        get_argument(config, 'parallel_streams', 'Parallel Streams', data_type=int, help_text='the number of parallel streams', default='vvv')
        get_argument(config, 'nodes', 'Node IP addresses', help_text='the IP of the nodes as comma separated list', default=8)

    # Write the arguments
    config.write()

    # Run the command
    if config['create_use'] == 'use':
        pass
    else:
        do_json(
            config['input_directory'],
            config['parallel_streams'],
            config['nodes'].split(','),
        )


def parser_arguments():
    parser = argparse.ArgumentParser('Build the WAVES physical graph')

    common_parser = argparse.ArgumentParser(add_help=False)
    common_parser.add_argument('input_directory', help='the directory to read the fit files from')
    common_parser.add_argument('nodes', help='the nodes to process')

    subparsers = parser.add_subparsers()

    parser_json = subparsers.add_parser('json', parents=[common_parser], help='display the json')
    parser_json.add_argument('parallel_streams', type=int, help='the number of parallel streams')
    parser_json.set_defaults(func=command_json)

    parser_interactive = subparsers.add_parser('interactive', help='prompt the user for parameters and then run')
    parser_interactive.set_defaults(func=command_interactive)

    args = parser.parse_args()
    return args


if __name__ == '__main__':
    # interactive
    logging.basicConfig(level=logging.INFO)
    arguments = parser_arguments()
    arguments.func(arguments)
