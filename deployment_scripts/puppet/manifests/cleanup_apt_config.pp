# Copyright 2016 Mirantis, Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License"); you may
# not use this file except in compliance with the License. You may obtain
# a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
# WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
# License for the specific language governing permissions and limitations
# under the License.

notice('fuel-plugin-external-zabbix: cleanup_apt_config.pp')

case $::osfamily {
    'Debian': {
        file { '/etc/apt/apt.conf.d/99norecommends':
            ensure  => absent,
        }
    }
    default: {
        # Currently only Debian like distributions need specific configuration.
    }
}
