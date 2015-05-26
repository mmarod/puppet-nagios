# This class configures a target as a Nagios client. The target
# will be automatically added to the monitor after 3 Puppet runs.
# The first run generates an SSH key the will be used to rsync configs
# over to the monitor. The second run exports the generated SSH key
# as an 'ssh_authorized_key' so that the monitor can add it to its
# authorized_keys file. After this second run, Puppet needs to run on
# the monitor server to collect the SSH key. Finally, run Puppet a
# third time on the target machine and the configurations will be
# transferred to the monitor under /etc/nagios3/conf.d/*.
#
# @example A regular node that is not the Nagios monitor
#   class { '::nagios::target':
#     target_host    => 'nagios.example.com'
#   }
#
# @example A node that is also the Nagios monitor
#   include '::nagios::monitor'
#   class { '::nagios::target':
#     is_monitor  => true
#   }
#
# @params target_host [String] The IP or hostname of the Nagios monitor.
#   This value needs to be the same as the monitor_host param of the monitor for
#   sshkey sharing to work.
# @params target_path [String] The remote path to the Nagios conf.d directory.
# @params prefix [String] The prefix for the configuration files on the monitor.
# @params local_user [String] The local user to use for rsync'ing configs.
# @params remote_user [String] The remote user on the Nagios monitor to use for rsync'ing configs.
# @params use_nrpe [Boolean] Whether or not to configure nrpe.
# @params is_monitor [Boolean] Whether or not this target is the Nagios monitor.
#
class nagios::target(
  $target_host          = undef,
  $target_path          = '/etc/nagios3/conf.d/hosts',
  $filebase             = $::clientcert,
  $local_user           = 'nagsync',
  $remote_user          = 'nagios',
  $use_nrpe             = true,
) inherits nagios::params {
  validate_absolute_path($target_path)
  validate_string($local_user)
  validate_string($remote_user)
  validate_bool($use_nrpe)

  Nagios_host<||> -> Rsync::Put<||>
  Nagios_service<||> -> Rsync::Put<||>

  user { $local_user: ensure => present }

  file { [ $naginator_confdir, $ssh_confdir ]:
    ensure  => directory,
    owner   => $local_user,
    mode    => '0755',
    require => User[$local_user]
  } -> Nagios_host <||> -> Nagios_service <||>

  $filebase_escaped   = regsubst($filebase, '\.', '_', 'G')
  $config_file        = "${naginator_confdir}/${filebase_escaped}.cfg"

  $create_defaults = { 'ensure' => 'present' }

  $hosts              = hiera_hash('nagios_hosts', {})
  $services           = hiera_hash('nagios_services', {})

  create_resources('nagios_host',     $hosts,    $create_defaults)
  create_resources('nagios_service',  $services, $create_defaults)

  validate_string($target_host)

  Sshkey <<| tag == 'nagios-monitor-key' |>>

  include '::rsync'

  $type    = 'rsa'
  $bits    = '2048'
  $comment = 'Nagios SSH key'
  $keypath = "${ssh_confdir}/id_rsa"

  exec { 'ssh-keygen-nagios':
    command => "/usr/bin/ssh-keygen -t ${type} -b ${bits} -f '${keypath}' -N '' -C '${comment}'",
    user    => $local_user,
    creates => $keypath,
    require => File[$ssh_confdir]
  }

  $rsync_dest = "${target_host}:${target_path}/${filebase_escaped}.cfg"

  if $::nagios_key_exists == 'yes' {
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

  @@concat_fragment { "nagios_target_${filebase_escaped}":
    tag     => 'nagios-targets',
    content => "${filebase_escaped}.cfg",
  }

  concat::fragment { 'nagios-host-config':
    target  => $config_file,
    source  => "${naginator_confdir}/nagios_host.cfg",
    order   => '01',
  }

  concat::fragment { 'nagios-service-config':
    target  => $config_file,
    source  => "${naginator_confdir}/nagios_service.cfg",
    order   => '02',
  }

  resources { [ 'nagios_service', 'nagios_host' ]:
    purge  => true,
  }

  concat { $config_file:
    owner => $local_user,
    mode  => '0644'
  }

  rsync::put { $rsync_dest:
    user      => $remote_user,
    keyfile   => $keypath,
    source    => $config_file,
    subscribe => Concat[$config_file]
  }
}
