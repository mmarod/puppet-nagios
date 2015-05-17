class nagios::target(
  $target_host,
  $target_path          = '/etc/nagios/conf.d',
  $conf_name            = $::clientcert,
  $local_user           = 'nagios',
  $remote_user          = 'nagios',
  $use_nrpe             = true,
) {
  include '::rsync'

  if $use_nrpe {
    include '::nrpe'

    $nrpe_commands = hiera_hash('nrpe_commands', {})
    $nrpe_plugins = hiera_hash('nrpe_plugins', {})
    create_resources('nrpe::command', $nrpe_commands)
    create_resources('nrpe::plugin', $nrpe_plugins)
  }

  $keypath = "/etc/nagios/.ssh/id_rsa"

  user { $local_user:
    ensure      => present,
    managehome  => true
  }

  file { [ '/etc/nagios', '/etc/nagios/.ssh' ]:
    ensure => directory,
    owner  => $local_user
  }

  if $nagios_key_exists == "no" {
    $type     = 'rsa'
    $bits     = '2048'
    $comment  = 'Nagios ssh key'

    exec { "ssh-keygen-nagios":
      command => "/usr/bin/ssh-keygen -t ${type} -b ${bits} -f '${keypath}' -N '' -C '${comment}'",
      user    => $local_user,
      creates => $keypath,
      require => File['/etc/nagios/.ssh']
    }
  } else {
    @@ssh_authorized_key { "${local_user}@${::clientcert}":
      key     => $nagios_key,
      user    => $remote_user,
      type    => 'ssh-rsa',
      tag     => 'nagios-key',
    }

    $rsync_dest_service = "${target_host}:${target_path}/${conf_name}_service.cfg"
    $rsync_dest_host = "${target_host}:${target_path}/${conf_name}_host.cfg"

    $hosts = hiera_hash('nagios_hosts', {})
    $services = hiera_hash('nagios_services', {})

    create_resources('nagios_host', $hosts)
    create_resources('nagios_service', $services)

    resources { nagios_service:
      purge   => true,
      notify  => Rsync::Put[$rsync_dest_service]
    }

    resources { nagios_host:
      purge   => true,
      notify  => Rsync::Put[$rsync_dest_host]
    }

    rsync::put { "$rsync_dest_service":
      user    => $remote_user,
      keyfile => $keyfile,
      source  => "/etc/nagios/nagios_service.cfg",
    }

    rsync::put { "$rsync_dest_host":
      user    => $remote_user,
      keyfile => $keyfile,
      source  => "/etc/nagios/nagios_host.cfg",
    }
  }
}
