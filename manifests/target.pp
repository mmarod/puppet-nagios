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
# @param use_nrpe [Boolean] Whether or not to configure nrpe on a target.
# @param xfer_method [String] (rsync/storeconfig) How to transfer the Nagios config to the monitor.
#
class nagios::target (
  $use_nrpe            = $nagios::params::use_nrpe,
  $xfer_method         = $nagios::params::xfer_method,
  $notification_period = '24x7'
) inherits nagios::params {
  validate_bool($use_nrpe)
  validate_string($xfer_method)

  include nagios::config

  # Grab variables from nagios::config class
  $monitor_host    = $nagios::config::monitor_host
  $target_path     = $nagios::config::target_path
  $remote_user     = $nagios::config::monitor_sync_user
  $local_user      = $nagios::config::target_sync_user
  $cwrsync_version = $nagios::config::cwrsync_version
  $proxyAddress    = $nagios::config::proxyAddress

  # Escape the clientcert to create a unique filename
  $filebase     = regsubst($::clientcert, '\.', '_', 'G')

  # Make sure that the nagios configurations are generated before concat
  # and rsync are used.
  Nagios_host<||>    -> Concat<||>
  Nagios_service<||> -> Concat<||>

  # Ensure that /etc/nagios or C:\nagios exist
  file { $nagios::params::naginator_confdir:
    ensure => directory,
    owner  => $local_user,
    mode   => $nagios::params::naginator_confdir_mode,
  } -> Nagios_host <||> -> Nagios_service <||>

  case downcase($::kernel) {
    'linux': {
      $exec_path         = [ '/bin', '/usr/bin' ]
      $rsync_environment = undef

      user { $local_user:
        ensure     => present,
        managehome => true,
        before     => File[$nagios::params::naginator_confdir]
      }
    }
    'windows': {
      $exec_path         = [ "${nagios::params::naginator_confdir}\\cwRsync_${cwrsync_version}_x86_Free", 'C:\windows', 'C:\windows\system32' ]
      $rsync_environment = [ "CWRSYNCHOME=C:\\nagios\\cwRsync_${cwrsync_version}_x86_Free", 'HOME=C:\nagios' ]

      exec { 'delete-nagios-config':
        command  => "cmd.exe /c del /q ${nagios::params::naginator_confdir}\\nagios_*",
        path     => $exec_path,
        require  => File[$nagios::params::naginator_confdir],
        loglevel => 'debug',
      } -> Nagios_host<||> -> Nagios_service<||>
    }
    default: {
      fail("Invalid 'kernel' fact '${::kernel}'. Allowed values are 'windows' and 'linux'")
    }
  }

  # Collect Hiera data
  $hosts              = hiera_hash('nagios_hosts', {})
  $services           = hiera_hash('nagios_services', {})

  $_host_defaults = merge($nagios::params::host_defaults, { 'notification_period' => $notification_period })
  $_service_defaults = merge($nagios::params::service_defaults, { 'notification_period' => $notification_period })

  # Create resources from Hiera data
  create_resources('nagios_host',     $hosts,    $_host_defaults)
  create_resources('nagios_service',  $services, $_service_defaults)

  # Send our config filename to the monitor so our configuration is not purged.
  @@concat::fragment { "nagios_target_${filebase}":
    target  => $nagios::params::nagios_targets,
    tag     => 'nagios-targets',
    content => "${filebase}.cfg",
  }

  # Merge host and service configuration into a single file.
  concat::fragment { 'nagios-host-config':
    target => $nagios::params::config_file_commented,
    tag    => 'nagios-config',
    source => "${nagios::params::naginator_confdir}/nagios_host.cfg",
    order  => '01',
  }

  concat::fragment { 'nagios-service-config':
    target => $nagios::params::config_file_commented,
    tag    => 'nagios-config',
    source => "${nagios::params::naginator_confdir}/nagios_service.cfg",
    order  => '02',
  }

  concat { $nagios::params::config_file_commented:
    tag            => 'nagios-config',
    owner          => $local_user,
    mode           => $nagios::params::config_file_mode,
    ensure_newline => true,
    loglevel       => $nagios::params::config_file_loglevel,
  }

  # Remove headers from the final config
  exec { 'remove-headers-from-config':
    command  => $nagios::params::remove_comments_command,
    require  => Concat[$nagios::params::config_file_commented],
    loglevel => 'debug',
  }

  case $xfer_method {
    'storeconfig': {
      # Creates an exported file for collection on the monitor.
      @@file { "${target_path}/${filebase}.cfg":
        tag     => 'nagios-config',
        owner   => $remote_user,
        mode    => '0644',
        content => $::nagios_config,
      }
    }
    'rsync': {
      # Ensure that /etc/nagios/.ssh or C:\nagios\.ssh exist
      file { $nagios::params::ssh_confdir:
        ensure  => directory,
        owner   => $local_user,
        mode    => $nagios::params::naginator_confdir_mode,
        require => File[$nagios::params::naginator_confdir]
      } -> Sshkey <||>

      # Collect the monitor host key
      Sshkey <<| tag == 'nagios-monitor-key' |>> {
        target => $nagios::params::sshkey_path,
      }

      $rsync_options = "--no-perms --chmod=ug=rw,o-rwx -c -e 'ssh -i ${nagios::params::rsync_keypath} -l ${remote_user}' ${nagios::params::rsync_source} ${remote_user}@${monitor_host}:${target_path}/${filebase}.cfg"
      $rsync_onlyif_options = "--no-perms --chmod=ug=rw,o-rwx -c -e 'ssh -i ${nagios::params::rsync_test_keypath} -l ${remote_user}' ${nagios::params::rsync_source} ${remote_user}@${monitor_host}:${target_path}/${filebase}.cfg"

      # Ensure rsync exists
      if downcase($::kernel) == 'windows' {
        $destination_directory = $nagios::params::naginator_confdir
        $destination_zipped    = "cwRsync_${cwrsync_version}_x86_Free.zip"
        $destination_unzipped  = "cwRsync_${cwrsync_version}_x86_Free"
        $cwrsync_url           = "https://www.itefix.net/dl/cwRsync_${cwrsync_version}_x86_Free.zip"
        $rsync_onlyif          = "cmd.exe /c rsync --dry-run --itemize-changes ${rsync_onlyif_options} | find /v /c \"\""
        $rsync_command         = "cmd.exe /c rsync -q ${rsync_options}"

        download_file { 'download-cwrsync':
          url                   => $cwrsync_url,
          destination_directory => $destination_directory,
          proxyAddress          => $proxyAddress,
        } ->

        windows::unzip { "${destination_directory}\\${destination_zipped}":
          destination => $destination_directory,
          creates     => "${destination_directory}\\${destination_unzipped}",
          before      => [ Exec['ssh-keygen-nagios'], Exec['ssh-keygen-nagios-test'], Exec['transfer-config-to-nagios'] ],
          require     => Download_file['download-cwrsync']
        }
      } elsif downcase($::kernel) == 'linux' {
        $rsync_onlyif          = "test `rsync --dry-run --itemize-changes ${rsync_onlyif_options} | wc -l` -gt 0"
        $rsync_command         = "rsync -q ${rsync_options}"

        ensure_packages( $nagios::params::target_packages,
          { 'before' => [ Exec['ssh-keygen-nagios'], Exec['ssh-keygen-nagios-test'], Exec['transfer-config-to-nagios'] ] }
        )
      }

      exec { 'ssh-keygen-nagios':
        command => "ssh-keygen -t ${nagios::params::ssh_key_type} -b ${nagios::params::ssh_key_bits} -f '${nagios::params::keypath}' -N '' -C '${nagios::params::ssh_key_comment}'",
        path    => $exec_path,
        user    => $local_user,
        creates => $nagios::params::keypath,
        before  => Exec['transfer-config-to-nagios'],
        require => File[$nagios::params::ssh_confdir],
      }

      exec { 'ssh-keygen-nagios-test':
        command => "ssh-keygen -t ${nagios::params::ssh_key_type} -b ${nagios::params::ssh_key_bits} -f '${nagios::params::test_keypath}' -N '' -C '${nagios::params::test_ssh_key_comment}'",
        path    => $exec_path,
        user    => $local_user,
        creates => $nagios::params::test_keypath,
        before  => Exec['transfer-config-to-nagios'],
        require => File[$nagios::params::ssh_confdir],
      }

      # $::nagios_key_exists is used to determine whether or not $::nagios_key
      # is a fact yet. It won't be on the first Puppet run.
      if $::nagios_key_exists == 'yes' {
        @@ssh_authorized_key { "${local_user}@${::clientcert}":
          key     => $::nagios_key,
          user    => $remote_user,
          type    => 'ssh-rsa',
          tag     => 'nagios-key',
          options => [ "command=\"rsync --server -ce.Lsfx . ${target_path}/${filebase}.cfg\"" ]
        }
      }

      if $::nagios_test_key_exists == 'yes' {
        @@ssh_authorized_key { "${local_user}test@${::clientcert}":
          key     => $::nagios_test_key,
          user    => $remote_user,
          type    => 'ssh-rsa',
          tag     => 'nagios-key',
          options => [ "command=\"rsync --server -nce.Lsfx --log-format=%i . ${target_path}/${filebase}.cfg\"" ]
        }
      }

      # Transfer the configuration to the monitor.
      exec { 'transfer-config-to-nagios':
        command     => $rsync_command,
        environment => $rsync_environment,
        path        => $exec_path,
        onlyif      => $rsync_onlyif,
        require     => Exec['remove-headers-from-config']
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
    if $::lsbdistcodename == 'jessie' {
      file { "/etc/systemd/system/nagios-nrpe-server.service":
        ensure    => present,
        owner     => 'root',
        group     => 'root',
        mode      => '0644',
        source    => 'puppet:///modules/nagios/nagios-nrpe-server.service',
        before    => Class['nrpe']
      }
    }

    include '::nrpe'

    $nrpe_commands = hiera_hash('nrpe_commands', {})
    $nrpe_plugins = hiera_hash('nrpe_plugins', {})
    create_resources('nrpe::command', $nrpe_commands)
    create_resources('nrpe::plugin', $nrpe_plugins)
  }
}
