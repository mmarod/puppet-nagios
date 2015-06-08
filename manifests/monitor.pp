# This class configures a Nagios monitor.
#
# @example Standard configuration
#   include '::nagios::monitor'
#
# @example Include /etc/nagios3/commands.cfg
#   nagios::config::cfg_files:
#     - /etc/nagios3/commands.cfg
#
# @example Configuration for a Debian monitor.
#   nagios::config::monitor_host: nagios.example.com
#
# @example Configuration for a RedHat monitor.
#   nagios::config::monitor_host: nagios.example.com
#   nagios::config::target_path: /etc/nagios/conf.d/hosts
#
# @param cfg_files [Array] A list of cfg_files to include in nagios.cfg.
# @param cfg_dirs [Array] A list of cfg_dirs to include in nagios.cfg.
# @param cfg_extra [Hash] A hash of key/value pairs to set options with in nagios.cfg.
#
class nagios::monitor inherits nagios::params {
  include nagios::config

  # Grab variables from nagios::config class
  $monitor_host           = $nagios::config::monitor_host
  $target_path            = $nagios::config::target_path
  $local_user             = $nagios::config::monitor_sync_user
  $nagios_user            = $nagios::config::nagios_user
  $nagios_group           = $nagios::config::nagios_group
  $cfg_files              = $nagios::config::cfg_files
  $cfg_dirs               = $nagios::config::cfg_dirs
  $cfg_extra              = $nagios::config::cfg_extra
  $inotify_send_errors_to = $nagios::config::inotify_send_errors_to

  # Escape the clientcert to create a unique filename
  $filebase     = regsubst($::clientcert, '\.', '_', 'G')
  $config_file  = "${target_path}/${filebase}.cfg"

  ensure_packages($nagios::params::monitor_packages)

  service { $nagios::params::nagios_service_name:
    ensure  => running,
  }

  user { $local_user:
    ensure         => present,
    managehome     => true,
    home           => "/home/${local_user}",
    purge_ssh_keys => true,
  } -> Ssh_authorized_key<||>

  user { $nagios_user: ensure => present }

  file { "/home/${local_user}/.ssh":
    ensure  => directory,
    owner   => $local_user,
    require => User[$local_user],
  }

  file { $nagios::params::files_to_purge:
    ensure  => absent,
    require => Package[$nagios::params::monitor_packages],
    notify  => Service[$nagios::params::nagios_service_name]
  }

  # inotify is used to reload Nagios when configurations change.
  file { $nagios::params::inotify_init:
    ensure => present,
    mode   => '0755',
    owner  => 'root',
    source => $nagios::params::inotify_source,
  }

  file { $nagios::params::inotify_script:
    ensure  => present,
    mode    => '0755',
    owner   => 'root',
    content => template('nagios/inotify-nagios.erb'),
  }

  file { $nagios::params::inotify_script_loop:
    ensure  => present,
    mode    => '0755',
    owner   => 'root',
    content => template('nagios/inotify-nagios-loop.erb'),
  }

  if $::osfamily == 'Debian' {
    file { $nagios::params::inotify_default:
      ensure  => present,
      mode    => '0644',
      content => 'VERBOSE=yes',
      before  => Service[$nagios::params::inotify_service_name]
    }
  }

  service { $nagios::params::inotify_service_name:
    ensure  => running,
    require => [ File[$nagios::params::inotify_init], File[$nagios::params::inotify_script] ]
  }

  file { $nagios::params::naginator_confdir:
    ensure  => directory,
    owner   => $nagios_user,
    mode    => '0755',
    require => User[$nagios_user]
  } ->  Nagios_host<||> ->
        Nagios_service<||> ->
        Nagios_hostgroup<||> ->
        Nagios_servicegroup<||> ->
        Nagios_command<||> ->
        Nagios_contact<||> ->
        Nagios_contactgroup<||> ->
        Nagios_timeperiod<||>

  # Sets /etc/nagios3/conf.d to rwxr-x--- nagios/nagsync
  file { [ $nagios::params::conf_dir, $nagios::params::conf_d_dir ]:
    ensure  => directory,
    owner   => $nagios_user,
    group   => $local_user,
    mode    => '0750',
    require => Package[$nagios::params::monitor_packages],
    before  => File[$target_path]
  }

  # Sets /etc/nagios3/conf.d/hosts to rwxr-s--- nagsync/nagios
  file { $target_path:
    ensure => directory,
    owner  => $local_user,
    group  => $nagios_group,
    mode   => '2750',
  }

  # Make sure that we are in the nagios-targets.txt file
  @@concat_fragment { "nagios_target_${filebase}":
    tag     => 'nagios-targets',
    content => "${filebase}.cfg",
  }

  # Collect all of the configs with xfer_method set to storeconfig
  File <<| tag == 'nagios-config' |>>

  # Collect all of the nagios::target names and store them in a file
  Concat_fragment <<| tag == 'nagios-targets' |>>

  concat_file { $nagios::params::nagios_targets:
    tag            => 'nagios-targets',
    ensure_newline => true,
  }

  # Purge any hosts that are not collected in the above method
  # Note: inotify-nagios will automatically reload Nagios upon deletion
  exec { 'remove-unmanaged-hosts':
    command => "/usr/bin/find ${target_path} ! -path ${target_path} -exec basename {} \\; | /bin/grep -Fxvf ${nagios::params::nagios_targets} | awk '{print \"${target_path}/\" \$1}' | /usr/bin/xargs rm",
    onlyif  => "/usr/bin/find ${target_path} ! -path ${target_path} -exec basename {} \\; | /bin/grep -Fxvf ${nagios::params::nagios_targets}",
    require => Concat_file[$nagios::params::nagios_targets]
  }

  # Take an array of cfg_file names and turn them into something Augeas can understand.
  $aug_file = nag_to_aug($cfg_files, 'cfg_file', $nagios::params::nagios_cfg_path)

  augeas { 'configure-nagios_cfg-cfg_file-settings':
    incl    => $nagios::params::nagios_cfg_path,
    lens    => 'NagiosCfg.lns',
    changes => $aug_file['changes'],
    onlyif  => $aug_file['onlyif'],
    require => File[$nagios::params::conf_dir]
  }

  # Take an array of cfg_dir names and turn them into something Augeas can understand.
  $aug_dir = nag_to_aug($cfg_dirs, 'cfg_dir', $nagios::params::nagios_cfg_path)

  augeas { 'configure-nagios_cfg-cfg_dir-settings':
    incl    => $nagios::params::nagios_cfg_path,
    lens    => 'NagiosCfg.lns',
    changes => $aug_dir['changes'],
    onlyif  => $aug_dir['onlyif'],
    require => File[$nagios::params::conf_dir]
  }

  # Takes a hash of changes to make and applies them with Augeas.
  $changes_array = join_keys_to_values($cfg_extra, ' \'"')
  $changes_quoted = suffix($changes_array, '"\'')
  $changes = prefix($changes_quoted, 'set ')

  augeas { 'configure-nagios_cfg-custom-settings':
    incl    => $nagios::params::nagios_cfg_path,
    lens    => 'NagiosCfg.lns',
    changes => $changes,
    require => File[$nagios::params::conf_dir]
  }

  # Ensure that all of these files exist before using Concat on them.
  file {[ "${nagios::params::naginator_confdir}/nagios_command.cfg",
          "${nagios::params::naginator_confdir}/nagios_contact.cfg",
          "${nagios::params::naginator_confdir}/nagios_contactgroup.cfg",
          "${nagios::params::naginator_confdir}/nagios_hostgroup.cfg",
          "${nagios::params::naginator_confdir}/nagios_host.cfg",
          "${nagios::params::naginator_confdir}/nagios_servicegroup.cfg",
          "${nagios::params::naginator_confdir}/nagios_service.cfg",
          "${nagios::params::naginator_confdir}/nagios_timeperiod.cfg"]:
    ensure => present,
    owner  => $nagios_user,
    group  => $nagios_user,
    mode   => '0644',
    notify => Service[$nagios::params::nagios_service_name],
    before => [ Concat[$config_file],
                Concat[$nagios::params::config_contact],
                Concat[$nagios::params::config_contactgroup],
                Concat[$nagios::params::config_command],
                Concat[$nagios::params::config_servicegroup],
                Concat[$nagios::params::config_hostgroup],
                Concat[$nagios::params::config_timeperiod] ]
  }

  $create_defaults = { 'ensure' => 'present' }

  # Collect data from Hiera
  $nagios_commands       = hiera_hash('nagios_commands', {})
  $nagios_contactgroups  = hiera_hash('nagios_contactgroups', {})
  $nagios_contacts       = hiera_hash('nagios_contacts', {})
  $nagios_eventhandlers  = hiera_hash('nagios_eventhandlers', {})
  $nagios_hostgroups     = hiera_hash('nagios_hostgroups', {})
  $nagios_hosts          = hiera_hash('nagios_hosts', {})
  $nagios_plugins        = hiera_hash('nagios_plugins', {})
  $nagios_servicegroups  = hiera_hash('nagios_servicegroups', {})
  $nagios_services       = hiera_hash('nagios_services', {})
  $nagios_timeperiods    = hiera_hash('nagios_timeperiods', {})

  # Merge in the default parameters. The hash on the right of the merge command is higher precedence.
  $commands       = merge($nagios::params::default_commands, $nagios_commands)
  $contactgroups  = merge($nagios::params::default_contactgroups, $nagios_contactgroups)
  $contacts       = merge($nagios::params::default_contacts, $nagios_contacts)
  $eventhandlers  = merge($nagios::params::default_eventhandlers, $nagios_eventhandlers)
  $hostgroups     = merge($nagios::params::default_hostgroups, $nagios_hostgroups)
  $hosts          = merge($nagios::params::default_hosts, $nagios_hosts)
  $plugins        = merge($nagios::params::default_plugins, $nagios_plugins)
  $servicegroups  = merge($nagios::params::default_servicegroups, $nagios_servicegroups)
  $services       = merge($nagios::params::default_services, $nagios_services)
  $timeperiods    = merge($nagios::params::default_timeperiods, $nagios_timeperiods)

  # Create Nagios resources
  create_resources('nagios_command',        $commands,      $create_defaults)
  create_resources('nagios_contactgroup',   $contactgroups, $create_defaults)
  create_resources('nagios_contact',        $contacts,      $create_defaults)
  create_resources('nagios::eventhandler',  $eventhandlers)
  create_resources('nagios_hostgroup',      $hostgroups,    $create_defaults)
  create_resources('nagios_host',           $hosts,         $create_defaults)
  create_resources('nagios_servicegroup',   $servicegroups, $create_defaults)
  create_resources('nagios_service',        $services,      $create_defaults)
  create_resources('nagios::plugin',        $plugins)
  create_resources('nagios_timeperiod',     $timeperiods,   $create_defaults)

  # Merge host and service into one file
  concat { $config_file:
    owner => $nagios_user,
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

  # This essentially copies /etc/nagios/nagios_hostgroup.cfg to /etc/nagios3/conf.d/hostgroups.cfg
  concat { $nagios::params::config_hostgroup:
    owner => $nagios_user,
    mode  => '0644'
  }

  concat::fragment { 'nagios-hostgroup-config':
    target => $nagios::params::config_hostgroup,
    source => "${nagios::params::naginator_confdir}/nagios_hostgroup.cfg",
    order  => '01',
  }

  # This essentially copies /etc/nagios/nagios_servicegroup.cfg to /etc/nagios3/conf.d/servicegroups.cfg
  concat { $nagios::params::config_servicegroup:
    owner => $nagios_user,
    mode  => '0644'
  }

  concat::fragment { 'nagios-servicegroup-config':
    target => $nagios::params::config_servicegroup,
    source => "${nagios::params::naginator_confdir}/nagios_servicegroup.cfg",
    order  => '01',
  }

  # This essentially copies /etc/nagios/nagios_command.cfg to /etc/nagios3/conf.d/commands.cfg
  concat { $nagios::params::config_command:
    owner => $nagios_user,
    mode  => '0644'
  }

  concat::fragment { 'nagios-command-config':
    target => $nagios::params::config_command,
    source => "${nagios::params::naginator_confdir}/nagios_command.cfg",
    order  => '01',
  }

  # This essentially copies /etc/nagios/nagios_contact.cfg to /etc/nagios3/conf.d/contacts.cfg
  concat { $nagios::params::config_contact:
    owner => $nagios_user,
    mode  => '0644'
  }

  concat::fragment { 'nagios-contact-config':
    target => $nagios::params::config_contact,
    source => "${nagios::params::naginator_confdir}/nagios_contact.cfg",
    order  => '01',
  }

  # This essentially copies /etc/nagios/nagios_contactgroup.cfg to /etc/nagios3/conf.d/contactgroups.cfg
  concat { $nagios::params::config_contactgroup:
    owner => $nagios_user,
    mode  => '0644'
  }

  concat::fragment { 'nagios-contactgroup-config':
    target => $nagios::params::config_contactgroup,
    source => "${nagios::params::naginator_confdir}/nagios_contactgroup.cfg",
    order  => '01',
  }

  # This essentially copies /etc/nagios/nagios_timeperiod.cfg to /etc/nagios3/conf.d/timeperiods.cfg
  concat { $nagios::params::config_timeperiod:
    owner => $nagios_user,
    mode  => '0644'
  }

  concat::fragment { 'nagios-timeperiod-config':
    target => $nagios::params::config_timeperiod,
    source => "${nagios::params::naginator_confdir}/nagios_timeperiod.cfg",
    order  => '01',
  }

  # Purge unmanaged resources
  resources { [ 'nagios_host',
                'nagios_hostgroup',
                'nagios_service',
                'nagios_servicegroup',
                'nagios_command',
                'nagios_contact',
                'nagios_contactgroup',
                'nagios_timeperiod' ]:
    purge => true,
  }

  # Collect SSH keys from targets for rsync usage
  Ssh_authorized_key <<| tag == 'nagios-key' |>>

  # Distribute the monitor host key to targets
  @@sshkey { $monitor_host:
    key  => $nagios::params::sshrsakey,
    type => 'ssh-rsa',
    tag  => 'nagios-monitor-key'
  }
}
