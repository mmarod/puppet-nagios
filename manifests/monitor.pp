class nagios::monitor(
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
) {
  include rsync::server

  ensure_packages($packages)

  user { $nagios_user: ensure => present }

  file { [ '/etc/nagios', '/etc/nagios/conf.d' ]:
    ensure  => directory,
    owner   => $nagios_user,
    group   => $nagios_group,
    require => Package[$packages]
  } ->

  Ssh_authorized_key <<| tag == 'nagios-key' |>>

  rsync::server::module { 'nagios':
    path    => '/etc/nagios',
    require => File['/etc/nagios']
  }

  create_resources('nagios::plugin', $plugins)
  create_resources('nagios::eventhandler', $eventhandlers)
  create_resources('nagios_hostgroup', $hostgroups)
  create_resources('nagios_servicegroup', $servicegroups)
  create_resources('nagios_command', $commands)

  resources { [  'nagios_hostgroup',
                'nagios_servicegroup',
                'nagios_command' ]:
    purge => true,
  }
}
