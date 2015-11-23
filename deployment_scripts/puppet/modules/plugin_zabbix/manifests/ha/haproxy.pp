#
#    Copyright 2015 Mirantis, Inc.
#
#    Licensed under the Apache License, Version 2.0 (the "License"); you may
#    not use this file except in compliance with the License. You may obtain
#    a copy of the License at
#
#         http://www.apache.org/licenses/LICENSE-2.0
#
#    Unless required by applicable law or agreed to in writing, software
#    distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
#    WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
#    License for the specific language governing permissions and limitations
#    under the License.
#
class plugin_zabbix::ha::haproxy {

  Haproxy::Service        { use_include => true }
  Haproxy::Balancermember { use_include => true }

  $public_vip = hiera('public_vip')
  $management_vip = hiera('management_vip')
  $nodes_hash = hiera('nodes')
  $primary_controller_nodes = filter_nodes($nodes_hash,'role','primary-controller')
  $controllers = concat($primary_controller_nodes, filter_nodes($nodes_hash,'role','controller'))

  Plugin_zabbix::Ha::Haproxy_service {
    server_names        => filter_hash($controllers, 'name'),
    ipaddresses         => filter_hash($controllers, 'internal_address'),
    public_virtual_ip   => $public_vip,
    internal_virtual_ip => $management_vip,
  }

  plugin_zabbix::ha::haproxy_service { 'zabbix-agent':
    order                  => '210',
    listen_port            => $plugin_zabbix::params::zabbix_ports['agent'],
    balancermember_port    => $plugin_zabbix::params::zabbix_ports['backend_agent'],

    haproxy_config_options => {
      'option'         => ['tcpka'],
      'timeout client' => '48h',
      'timeout server' => '48h',
      'balance'        => 'roundrobin',
      'mode'           => 'tcp'
    },

    balancermember_options => 'check inter 5000 rise 2 fall 3',
  }

  plugin_zabbix::ha::haproxy_service { 'zabbix-server':
    order                  => '200',
    listen_port            => $plugin_zabbix::params::zabbix_ports['server'],
    balancermember_port    => $plugin_zabbix::params::zabbix_ports['backend_server'],

    haproxy_config_options => {
      'option'         => ['tcpka'],
      'timeout client' => '48h',
      'timeout server' => '48h',
      'balance'        => 'roundrobin',
      'mode'           => 'tcp'
    },

    balancermember_options => 'check inter 5000 rise 2 fall 3',
  }

  file_line { 'add binding to management VIP for horizon and zabbix':
    path   => '/etc/haproxy/conf.d/015-horizon.cfg',
    after  => 'listen horizon',
    line   => "  bind ${management_vip}:80",
    before => Exec['haproxy reload'],
  }

  exec { 'haproxy reload':
    command   => 'export OCF_ROOT="/usr/lib/ocf"; (ip netns list | grep haproxy) && ip netns exec haproxy /usr/lib/ocf/resource.d/fuel/ns_haproxy reload',
    path      => '/usr/bin:/usr/sbin:/bin:/sbin',
    logoutput => true,
    provider  => 'shell',
    tries     => 10,
    try_sleep => 10,
    returns   => [0, ''],
  }

  Haproxy::Listen <||> -> Exec['haproxy reload']
  Haproxy::Balancermember <||> -> Exec['haproxy reload']

  firewall { '998 zabbix agent vip':
    proto  => 'tcp',
    action => 'accept',
    port   => $plugin_zabbix::params::zabbix_ports['agent'],
  }

  firewall { '998 zabbix server vip':
    proto  => 'tcp',
    action => 'accept',
    port   => $plugin_zabbix::params::zabbix_ports['server'],
  }
}
