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
#     monitor_host    => 'nagios.example.com'
#   }
#
# @param local_user [String] The local user created on a target to use for
#   rsync'ing.
# @param use_nrpe [Boolean] Whether or not to configure nrpe on a target.
# @param xfer_method [String] (rsync/storeconfig) How to transfer the Nagios config to the monitor.
#
class nagios::target(
  $local_user       = 'nagsync',
  $use_nrpe         = true,
  $xfer_method      = $nagios::params::xfer_method
) inherits nagios::params {
  validate_string($local_user)
  validate_bool($use_nrpe)
  validate_string($xfer_method)

  include nagios::config

  $monitor_host = $nagios::config::monitor_host
  $target_path = $nagios::config::target_path
  $remote_user = $nagios::config::nagios_user

  Nagios_host<||> -> Rsync::Put<||>
  Nagios_service<||> -> Rsync::Put<||>

  user { $local_user: ensure => present }

  file { [ $nagios::params::naginator_confdir, $nagios::params::ssh_confdir ]:
    ensure  => directory,
    owner   => $local_user,
    mode    => '0755',
    require => User[$local_user]
  } -> Nagios_host <||> -> Nagios_service <||>

  $filebase_escaped   = regsubst($nagios::params::filebase, '\.', '_', 'G')
  $config_file        = "${nagios::params::naginator_confdir}/nagios_config.cfg"

  $create_defaults = { 'ensure' => 'present' }

  # Collect Hiera data
  $hosts              = hiera_hash('nagios_hosts', {})
  $services           = hiera_hash('nagios_services', {})

  # Create resources from Hiera data
  create_resources('nagios_host',     $hosts,    $create_defaults)
  create_resources('nagios_service',  $services, $create_defaults)

  # Send our config filename to the monitor so our configuration is not purged.
  @@concat_fragment { "nagios_target_${filebase_escaped}":
    tag     => 'nagios-targets',
    content => "${filebase_escaped}.cfg",
  }

  # Merge host and service configuration into a single file.
  concat { $config_file:
    owner => $local_user,
    mode  => '0644'
  }

  concat::fragment { 'nagios-host-config':
    target => $config_file,
    source => "${nagios::params::naginator_confdir}/nagios_host.cfg",
    order  => '01',
  }

  concat::fragment { 'nagios-service-config':
    target => $config_file,
    source => "${nagios::params::naginator_confdir}/nagios_service.cfg",
    order  => '02',
  }

  case $xfer_method {
    'storeconfig': {
      # Creates an exported file for collection on the monitor.
      @@file { "${target_path}/${filebase_escaped}.cfg":
        tag     => 'nagios-config',
        owner   => $remote_user,
        mode    => '0644',
        content => $::nagios_config,
      }
    }
    'rsync': {
      # Collect the monitor host key
      Sshkey <<| tag == 'nagios-monitor-key' |>>

      include '::rsync'

      $type    = 'rsa'
      $bits    = '2048'
      $comment = 'Nagios SSH key'
      $keypath = "${nagios::params::ssh_confdir}/id_rsa"

      exec { 'ssh-keygen-nagios':
        command => "/usr/bin/ssh-keygen -t ${type} -b ${bits} -f '${keypath}' -N '' -C '${comment}'",
        user    => $local_user,
        creates => $keypath,
        require => File[$nagios::params::ssh_confdir]
      }

      $rsync_dest = "${monitor_host}:${target_path}/${filebase_escaped}.cfg"

      # $::nagios_key_exists is used to determine whether or not $::nagios_key
      # is a fact yet. It won't be on the first Puppet run.
      if $::nagios_key_exists == 'yes' {
        @@ssh_authorized_key { "${local_user}@${::clientcert}":
          key  => $::nagios_key,
          user => $remote_user,
          type => 'ssh-rsa',
          tag  => 'nagios-key',
        }
      }

      # Transfer the configuration to the monitor.
      rsync::put { $rsync_dest:
        user      => $remote_user,
        keyfile   => $keypath,
        source    => $config_file,
        subscribe => Concat[$config_file]
      }
    }
    default: {
      fail("Invalid 'xfer_method' parameter '${xfer_method}'. Allowed values are 'storeconfig' and 'rsync'")
    }
  }

  # Purge unmanaged resources
  resources { [ 'nagios_service', 'nagios_host' ]:
    purge => true,
  }

  if $use_nrpe {
    include '::nrpe'

    $nrpe_commands = hiera_hash('nrpe_commands', {})
    $nrpe_plugins = hiera_hash('nrpe_plugins', {})
    create_resources('nrpe::command', $nrpe_commands)
    create_resources('nrpe::plugin', $nrpe_plugins)
  }
}
