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
  $local_user       = $nagios::params::local_user,
  $use_nrpe         = $nagios::params::use_nrpe,
  $xfer_method      = $nagios::params::xfer_method
) inherits nagios::params {
  validate_string($local_user)
  validate_bool($use_nrpe)
  validate_string($xfer_method)

  include nagios::config

  $monitor_host = $nagios::config::monitor_host
  $target_path = $nagios::config::target_path
  $remote_user = $nagios::config::nagios_user

  $filebase_escaped      = regsubst($nagios::params::filebase, '\.', '_', 'G')
  $config_file_commented = "${nagios::params::naginator_confdir}${nagios::params::sep}nagios_config_commented.cfg"
  $config_file           = "${nagios::params::naginator_confdir}${nagios::params::sep}nagios_config.cfg"

  # Make sure that the nagios configurations are generated before concat
  # and rsync are used.
  Nagios_host<||>    -> Concat_file<||> -> Rsync::Put<||>
  Nagios_service<||> -> Concat_file<||> -> Rsync::Put<||>

  # Ensure that /etc/nagios or C:\nagios exist
  file { [ $nagios::params::naginator_confdir, $nagios::params::ssh_confdir ]:
    ensure => directory,
    owner  => $local_user,
    mode   => $nagios::params::naginator_confdir_mode,
  } -> Nagios_host <||> -> Nagios_service <||> -> Sshkey <||>

  case downcase($::kernel) {
    'linux': {
      user { $local_user:
        ensure => present,
        before => File[$nagios::params::naginator_confdir]
      }
    }
    'windows': {
      exec { 'delete-nagios-config':
        command  => "C:\\windows\\system32\\cmd.exe /c del /q ${nagios::params::naginator_confdir}\\*",
        require  => File[$nagios::params::naginator_confdir],
        loglevel => 'debug',
      } -> Nagios_host<||> -> Nagios_service<||>

      exec { 'remove-headers-from-config':
        command  => "C:\\windows\\system32\\cmd.exe /c findstr /v /b /c:\"#\" ${config_file_commented} > ${config_file}",
        require  => Concat_file['nagios-config'],
        loglevel => 'debug',
      }
    }
    default: {
      fail("Invalid 'kernel' fact '${::kernel}'. Allowed values are 'windows' and 'linux'")
    }
  }

  # Collect Hiera data
  $hosts              = hiera_hash('nagios_hosts', {})
  $services           = hiera_hash('nagios_services', {})

  # Create resources from Hiera data
  create_resources('nagios_host',     $hosts,    $nagios::params::host_defaults)
  create_resources('nagios_service',  $services, $nagios::params::service_defaults)

  # Send our config filename to the monitor so our configuration is not purged.
  @@concat_fragment { "nagios_target_${filebase_escaped}":
    tag     => 'nagios-targets',
    content => "${filebase_escaped}.cfg",
  }

  # Merge host and service configuration into a single file.
  concat_file { 'nagios-config':
    tag      => 'nagios-config',
    path     => $config_file_commented,
    owner    => $local_user,
    mode     => $nagios::params::config_file_mode,
    loglevel => $nagios::params::config_file_loglevel,
  }

  concat_fragment { 'nagios-host-config':
    tag    => 'nagios-config',
    source => "${nagios::params::naginator_confdir}/nagios_host.cfg",
    order  => '01',
  }

  concat_fragment { 'nagios-service-config':
    tag    => 'nagios-config',
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
      Sshkey <<| tag == 'nagios-monitor-key' |>> {
        target => $nagios::params::sshkey_path,
      }

      include '::rsync'

      $type    = 'rsa'
      $bits    = '2048'
      $comment = 'Nagios SSH key'
      $keypath = "${nagios::params::ssh_confdir}/id_rsa"

      exec { 'ssh-keygen-nagios':
        command => "${nagios::params::ssh_keygen_path} -t ${type} -b ${bits} -f '${keypath}' -N '' -C '${comment}'",
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
        environment => $nagios::params::environment,
        exec_path   => $nagios::params::exec_path,
        user        => $remote_user,
        keyfile     => $keypath,
        source      => $config_file,
        subscribe   => Concat[$config_file]
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
