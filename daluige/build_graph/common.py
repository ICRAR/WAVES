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
Common code used all over the place
"""
import getpass
import time


def get_argument(config, key, prompt, help_text=None, data_type=None, default=None, allowed=None):
    if key in config:
        default = config[key]

    if default is not None:
        prompt = '{0} [{1}]:'.format(prompt, default)
    else:
        prompt = '{0}:'.format(prompt)

    data = None

    while data is None:
        data = raw_input(prompt)
        if data == '?':
            if help_text is not None:
                print '\n' + help_text + '\n'
            else:
                print '\nNo help available\n'

            data = None
        elif data == '':
            data = default

        if allowed is not None:
            if data not in allowed:
                data = None

    if data_type is not None:
        if data_type == int:
            config[key] = int(data)
        elif data_type == float:
            config[key] = float(data)
        elif data_type == bool:
            config[key] = data in ['True', 'true']
    else:
        config[key] = data


def get_module_name(item):
    return item.__module__ + '.' + item.__name__


def get_session_id():
    return '{0}-{1}'.format(
        getpass.getuser(),
        time.strftime('%Y%m%d%H%M%S')
    )


