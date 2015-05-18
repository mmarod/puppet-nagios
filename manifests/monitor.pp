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
  $eventhandlers      = {},
  $hostgroups         = {},
  $servicegroups      = {},
  $commands           = {},
  $manage_firewall    = false,
  $config_changes     = {}
) inherits nagios::params {
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

  ensure_packages($packages)

  service { $nagios_service_name:
    ensure  => running,
  }

  user { $nagios_user:
    ensure         => present,
    managehome     => true,
    home           => '/home/nagios',
    purge_ssh_keys => true,
  }

  file { [ $confdir, "${confdir}/conf.d" ]:
    ensure  => directory,
    owner   => $nagios_user,
    require => Package[$packages]
  }

  file {[ '/etc/nagios/nagios_host.cfg',
          '/etc/nagios/nagios_hostgroup.cfg',
          '/etc/nagios/nagios_service.cfg',
          '/etc/nagios/nagios_servicegroup.cfg',
          '/etc/nagios/nagios_command.cfg']:
    ensure => present,
    owner  => $nagios_user,
    group  => $nagios_user,
    mode   => '0644',
    notify => Service[$nagios_service_name]
  }

  create_resources('nagios::plugin', $plugins)
  create_resources('nagios::eventhandler', $eventhandlers)
  create_resources('nagios_hostgroup', $hostgroups)
  create_resources('nagios_servicegroup', $servicegroups)
  create_resources('nagios_command', $commands)

  Ssh_authorized_key <<| tag == 'nagios-key' |>>

  include rsync::server

  rsync::server::module { 'nagios':
    path    => '${confdir}',
    require => Package[$packages]
  }

  augeas { 'custom-nagios-configuration-changes':
    incl    => "${confdir}/nagios.cfg",
    lens    => "NagiosCfg.lns",
    changes => $config_changes,
    require => Package[$packages]
  }

  augeas { 'ensure-cfg_file-nagios_host.cfg':
    incl    => "${confdir}/nagios.cfg",
    lens    => "NagiosCfg.lns",
    changes => [ 'ins cfg_file after cfg_file[last()]',
                 'set cfg_file[last()] /etc/nagios/nagios_host.cfg' ],
    onlyif  => "match cfg_file[.='/etc/nagios/nagios_host.cfg'] size == 0",
    require => Package[$packages]
  }

  augeas { 'ensure-cfg_file-nagios_hostgroup.cfg':
    incl    => "${confdir}/nagios.cfg",
    lens    => "NagiosCfg.lns",
    changes => [ 'ins cfg_file after cfg_file[last()]',
                 'set cfg_file[last()] /etc/nagios/nagios_hostgroup.cfg' ],
    onlyif  => "match cfg_file[.='/etc/nagios/nagios_hostgroup.cfg'] size == 0",
    require => Package[$packages]
  }

  augeas { 'ensure-cfg_file-nagios_service.cfg':
    incl    => "${confdir}/nagios.cfg",
    lens    => "NagiosCfg.lns",
    changes => [ 'ins cfg_file after cfg_file[last()]',
                 'set cfg_file[last()] /etc/nagios/nagios_service.cfg' ],
    onlyif  => "match cfg_file[.='/etc/nagios/nagios_service.cfg'] size == 0",
    require => Package[$packages]
  }

  augeas { 'ensure-cfg_file-nagios_servicegroup.cfg':
    incl    => "${confdir}/nagios.cfg",
    lens    => "NagiosCfg.lns",
    changes => [ 'ins cfg_file after cfg_file[last()]',
                 'set cfg_file[last()] /etc/nagios/nagios_servicegroup.cfg' ],
    onlyif  => "match cfg_file[.='/etc/nagios/nagios_servicegroup.cfg'] size == 0",
    require => Package[$packages]
  }

  augeas { 'ensure-cfg_file-nagios_command.cfg':
    incl    => "${confdir}/nagios.cfg",
    lens    => "NagiosCfg.lns",
    changes => [ 'ins cfg_file after cfg_file[last()]',
                 'set cfg_file[last()] /etc/nagios/nagios_command.cfg' ],
    onlyif  => "match cfg_file[.='/etc/nagios/nagios_command.cfg'] size == 0",
    require => Package[$packages]
  }

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
