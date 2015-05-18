# This class configures a Nagios monitor.
#
# @example Standard configuration
#   include '::nagios::monitor'
#   class { '::nagios::target':
#     is_monitor  => true
#   }
#
# @param monitor_host [String] The domain name or IP address of the monitor.
#   This value needs to be the same as the target_host param of the targets for
#   sshkey sharing to work.
# @param packages [Array] A list of packages to install.
# @param nagios_user [String] The nagios user.
# @param nagios_group [String] The nagios group.
# @param plugin_mode [String] The mode for the Nagios plugins.
# @param eventhander_mode [String] The mode for the Nagios eventhandlers.
# @param plugins [Hash] A hash of nagios::plugin types.
# @param plugin_path [String] The path to the Nagios plugins.
# @param eventhandlers [Hash] A hash of nagios::eventhandler types.
# @param eventhandler_path [String] The path to the Nagios eventhandlers.
# @param hostgroups [Hash] A hash of nagios_hostgroup types.
# @param servicegroups [Hash] A hash of nagios_servicegroup types.
# @param commands [Hash] A hash of nagios_comand types.
# @param manage_firewall [Boolean] Whether or not to open port 873 for rsync.
#
class nagios::monitor(
  $monitor_host       = $::ipaddress,
  $packages           = [ 'nagios3', 'nagios-plugins' ],
  $nagios_user        = 'nagios',
  $nagios_group       = 'nagios',
  $plugin_mode        = '0755',
  $eventhandler_mode  = '0755',
  $plugins            = {},
  $plugin_path        = '/etc/nagios-plugins/config',
  $eventhandlers      = {},
  $eventhandler_path  = '/usr/share/nagios3/plugins/eventhandlers',
  $hostgroups         = {},
  $servicegroups      = {},
  $commands           = {},
  $manage_firewall    = false,
) {
  validate_array($packages)
  validate_string($nagios_user)
  validate_string($nagios_group)
  validate_string($plugin_mode)
  validate_string($eventhandler_mode)
  validate_hash($plugins)
  validate_absolute_path($plugin_path)
  validate_hash($eventhandlers)
  validate_absolute_path($eventhandler_path)
  validate_hash($hostgroups)
  validate_hash($servicegroups)
  validate_hash($commands)
  validate_bool($manage_firewall)

  Package<||> -> Ssh_authorized_key<||>

  include rsync::server

  ensure_packages($packages)
  ensure_resource('user', $nagios_user, { 'ensure'          => 'present',
                                          'managehome'      => true,
                                          'home'            => '/home/nagios',
                                          'purge_ssh_keys'  => true })

  file { [ '/etc/nagios3', '/etc/nagios3/conf.d' ]:
    ensure  => directory,
    owner   => $nagios_user,
    require => Package[$packages]
  }

  Ssh_authorized_key <<| tag == 'nagios-key' |>>

  rsync::server::module { 'nagios':
    path    => '/etc/nagios3',
    require => Package[$packages]
  }

  create_resources('nagios::plugin', $plugins)
  create_resources('nagios::eventhandler', $eventhandlers)
  create_resources('nagios_hostgroup', $hostgroups)
  create_resources('nagios_servicegroup', $servicegroups)
  create_resources('nagios_command', $commands)

  resources { [ 'nagios_hostgroup',
                'nagios_servicegroup',
                'nagios_command' ]:
    purge => true,
  }

  if $manage_firewall {
    firewall { '200 Allow rsync access for Nagios':
      chain  => 'INPUT',
      proto  => 'tcp',
      dport  => '873',
      action => 'accept'
    }
  }

  @@sshkey { $monitor_host:
    key  => $sshrsakey,
    type => 'ssh-rsa',
    tag  => 'nagios-monitor-key'
  }
}
