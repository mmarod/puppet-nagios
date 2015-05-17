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
}
