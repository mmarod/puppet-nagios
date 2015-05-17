class nagios::target(
  $target_host          = undef,
  $target_path          = '/etc/nagios3/conf.d',
  $prefix               = $::clientcert,
  $local_user           = 'nagsync',
  $remote_user          = 'nagios',
  $use_nrpe             = true,
  $is_monitor           = false,
) {
  Nagios_host<||> -> Rsync::Put<||>
  Nagios_service<||> -> Rsync::Put<||>

  user { $local_user: ensure => present }

  file { '/etc/nagios':
    ensure  => directory,
    owner   => $local_user,
    mode    => '0755',
    require => User[$local_user]
  } -> Nagios_host <||> -> Nagios_service <||>

  $hosts = hiera_hash('nagios_hosts', {})
  $services = hiera_hash('nagios_services', {})

  create_resources('nagios_host', $hosts)
  create_resources('nagios_service', $services)

  resources { [ 'nagios_service', 'nagios_host' ]:
    purge  => true,
  }

  if $is_monitor {
    file { "/etc/nagios3/conf.d/${prefix}_host.cfg":
      ensure  => link,
      target  => "/etc/nagios/nagios_host.cfg",
    }

    file { "/etc/nagios3/conf.d/${prefix}_service.cfg":
      ensure  => link,
      target  => "/etc/nagios/nagios_service.cfg",
    }
  } else {
    validate_string($target_host)

    file { '/etc/nagios/.ssh':
      ensure  => directory,
      owner   => $local_user,
      require => File['/etc/nagios']
    }

    include '::rsync'

    $type    = 'rsa'
    $bits    = '2048'
    $comment = 'Nagios SSH key'
    $keypath = '/etc/nagios/.ssh/id_rsa'

    exec { 'ssh-keygen-nagios':
      command => "/usr/bin/ssh-keygen -t ${type} -b ${bits} -f '${keypath}' -N '' -C '${comment}'",
      user    => $local_user,
      creates => $keypath,
      require => File['/etc/nagios/.ssh']
    }

    $rsync_dest_service = "${target_host}:${target_path}/${prefix}_service.cfg"
    $rsync_dest_host = "${target_host}:${target_path}/${prefix}_host.cfg"

    rsync::put { $rsync_dest_host:
      user    => $remote_user,
      keyfile => $keypath,
      source  => '/etc/nagios/nagios_host.cfg',
    }

    rsync::put { $rsync_dest_service:
      user    => $remote_user,
      keyfile => $keypath,
      source  => '/etc/nagios/nagios_service.cfg',
    }

    if $::nagios_key_exists == "yes" {
      @@ssh_authorized_key { "${local_user}@${::clientcert}":
        key  => $::nagios_key,
        user => $remote_user,
        type => 'ssh-rsa',
        tag  => 'nagios-key',
      }
    }

    if $use_nrpe {
      include '::nrpe'

      $nrpe_commands = hiera_hash('nrpe_commands', {})
      $nrpe_plugins = hiera_hash('nrpe_plugins', {})
      create_resources('nrpe::command', $nrpe_commands)
      create_resources('nrpe::plugin', $nrpe_plugins)
    }
  }
}
