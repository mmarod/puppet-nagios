# This class configures a Nagios monitor.
#
# @example Standard configuration
#   include '::nagios::monitor'
#   class { '::nagios::target':
#     is_monitor  => true
#   }
#
# @param monitor_host [String] The domain name or IP address of the monitor.
# @param file_base [String] The prefix to the name on the Nagios configs.
# @param packages [Array] A list of packages to install.
# @param nagios_user [String] The nagios user.
# @param nagios_group [String] The nagios group.
# @param cfg_files [Array] A list of cfg_files to include.
# @param cfg_dirs [Array] A list of cfg_dirs to include.
# @param config [Hash] A hash of key/value pairs to set options with in nagios.cfg.
# @param manage_firewall [Boolean] Whether or not to open port 873 for rsync.
#
class nagios::monitor(
  $monitor_host        = $::ipaddress,
  $filebase            = $::clientcert,
  $packages            = $nagios::params::packages,
  $nagios_user         = $nagios::params::nagios_user,
  $nagios_group        = $nagios::params::nagios_group,
  $cfg_files           = $nagios::params::cfg_files,
  $cfg_dirs            = $nagios::params::cfg_dirs,
  $config              = {},
  $manage_firewall     = false,
) inherits nagios::params {
  validate_string($monitor_host)
  validate_string($filebase)
  validate_array($packages)
  validate_string($nagios_user)
  validate_string($nagios_group)
  validate_array($cfg_files)
  validate_array($cfg_dirs)
  validate_bool($manage_firewall)

  $filebase_escaped = regsubst($filebase, '\.', '_', 'G')
  $config_file = "${nagios::params::confdir_hosts}/${filebase_escaped}.cfg"

  ensure_packages($packages)

  service { $nagios::params::nagios_service_name:
    ensure  => running,
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

  user { $nagios_user:
    ensure         => present,
    managehome     => true,
    home           => '/home/nagios',
    purge_ssh_keys => true,
  } -> Ssh_authorized_key<||>

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

  file { $nagios::params::confdir:
    ensure  => directory,
    owner   => $nagios_user,
    require => Package[$packages]
  } ->

  file { $nagios::params::confdir_hosts:
    ensure => directory,
    owner  => $nagios_user,
  }

  # Make sure that we are in the nagios-targets.txt file
  @@concat_fragment { "nagios_target_${filebase_escaped}":
    tag     => 'nagios-targets',
    content => "${filebase_escaped}.cfg",
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
    command => "/usr/bin/find ${nagios::params::confdir_hosts} ! -path ${nagios::params::confdir_hosts} -exec basename {} \\; | /bin/grep -Fxvf ${nagios::params::nagios_targets} | awk '{print \"${nagios::params::confdir_hosts}/\" \$1}' | /usr/bin/xargs rm",
    onlyif  => "/usr/bin/find ${nagios::params::confdir_hosts} ! -path ${nagios::params::confdir_hosts} -exec basename {} \\; | /bin/grep -Fxvf ${nagios::params::nagios_targets}",
    require => Concat_file[$nagios::params::nagios_targets]
  }

  # Take an array of cfg_file names and turn them into something Augeas can understand.
  $aug_file = nag_to_aug($cfg_files, 'cfg_file', $nagios::params::nagios_cfg_path)

  augeas { 'configure-nagios_cfg-cfg_file-settings':
    incl    => $nagios::params::nagios_cfg_path,
    lens    => 'NagiosCfg.lns',
    changes => $aug_file['changes'],
    onlyif  => $aug_file['onlyif'],
    require => File[$nagios::params::confdir]
  }

  # Take an array of cfg_dir names and turn them into something Augeas can understand.
  $aug_dir = nag_to_aug($cfg_dirs, 'cfg_dir', $nagios::params::nagios_cfg_path)

  augeas { 'configure-nagios_cfg-cfg_dir-settings':
    incl    => $nagios::params::nagios_cfg_path,
    lens    => 'NagiosCfg.lns',
    changes => $aug_dir['changes'],
    onlyif  => $aug_dir['onlyif'],
    require => File[$nagios::params::confdir]
  }

  # Takes a hash of changes to make and applies them with Augeas.
  $changes_array = join_keys_to_values($config, ' \'"')
  $changes_quoted = suffix($changes_array, '"\'')
  $changes = prefix($changes_quoted, 'set ')

  augeas { 'configure-nagios_cfg-custom-settings':
    incl    => $nagios::params::nagios_cfg_path,
    lens    => 'NagiosCfg.lns',
    changes => $changes,
    require => File[$nagios::params::confdir]
  }

  # Ensure that all of these files exist before using Concat on them.
  file {[ "${nagios::params::naginator_confdir}/nagios_host.cfg",
          "${nagios::params::naginator_confdir}/nagios_hostgroup.cfg",
          "${nagios::params::naginator_confdir}/nagios_service.cfg",
          "${nagios::params::naginator_confdir}/nagios_servicegroup.cfg",
          "${nagios::params::naginator_confdir}/nagios_command.cfg",
          "${nagios::params::naginator_confdir}/nagios_contact.cfg",
          "${nagios::params::naginator_confdir}/nagios_contactgroup.cfg",
          "${nagios::params::naginator_confdir}/nagios_timeperiod.cfg"]:
    ensure => present,
    owner  => $nagios_user,
    group  => $nagios_user,
    mode   => '0644',
    notify => Service[$nagios::params::nagios_service_name],
    before => [ Concat[$config_file],
                Concat[$nagios::params::config_contact],
                Concat[$nagios::params::config_contactgroup],
                Concat[$nagios::params::config_timeperiod] ]
  }

  # Collect data from Hiera
  $hosts          = hiera_hash('nagios_hosts', {})
  $hostgroups     = hiera_hash('nagios_hostgroups', {})
  $services       = hiera_hash('nagios_services', {})
  $servicegroups  = hiera_hash('nagios_servicegroups', {})
  $commands       = hiera_hash('nagios_commands', {})
  $contacts       = hiera_hash('nagios_contacts', {})
  $contactgroups  = hiera_hash('nagios_contactgroups', {})
  $timeperiods    = hiera_hash('nagios_timeperiods', {})
  $plugins        = hiera_hash('nagios_plugins', {})
  $eventhandlers  = hiera_hash('nagios_eventhandlers', {})

  $create_defaults = { 'ensure' => 'present' }

  # Create Nagios resources
  create_resources('nagios_host',           $hosts,         $create_defaults)
  create_resources('nagios_service',        $services,      $create_defaults)
  create_resources('nagios_hostgroup',      $hostgroups,    $create_defaults)
  create_resources('nagios_servicegroup',   $servicegroups, $create_defaults)
  create_resources('nagios_command',        $commands,      $create_defaults)
  create_resources('nagios_contact',        $contacts,      $create_defaults)
  create_resources('nagios_contactgroup',   $contactgroups, $create_defaults)
  create_resources('nagios_timeperiod',     $timeperiods,   $create_defaults)
  create_resources('nagios::plugin',        $plugins)
  create_resources('nagios::eventhandler',  $eventhandlers)

  # Merge host, hostgroup, service, servicegroup, and command into one file
  concat { $config_file:
    owner => $nagios_user,
    mode  => '0644'
  }

  concat::fragment { 'nagios-host-config':
    target => $config_file,
    source => "${nagios::params::naginator_confdir}/nagios_host.cfg",
    order  => '01',
  }

  concat::fragment { 'nagios-hostgroup-config':
    target => $config_file,
    source => "${nagios::params::naginator_confdir}/nagios_hostgroup.cfg",
    order  => '02',
  }

  concat::fragment { 'nagios-service-config':
    target => $config_file,
    source => "${nagios::params::naginator_confdir}/nagios_service.cfg",
    order  => '03',
  }

  concat::fragment { 'nagios-servicegroup-config':
    target => $config_file,
    source => "${nagios::params::naginator_confdir}/nagios_servicegroup.cfg",
    order  => '04',
  }

  concat::fragment { 'nagios-command-config':
    target => $config_file,
    source => "${nagios::params::naginator_confdir}/nagios_command.cfg",
    order  => '05',
  }

  # This essentially copies /etc/nagios/nagios_contact.cfg to /etc/nagios3/conf.d/contacts_puppet.cfg
  concat { $nagios::params::config_contact:
    owner => $nagios_user,
    mode  => '0644'
  }

  concat::fragment { 'nagios-contact-config':
    target => $nagios::params::config_contact,
    source => "${nagios::params::naginator_confdir}/nagios_contact.cfg",
    order  => '01',
  }

  # This essentially copies /etc/nagios/nagios_contactgroup.cfg to /etc/nagios3/conf.d/contactgroups_puppet.cfg
  concat { $nagios::params::config_contactgroup:
    owner => $nagios_user,
    mode  => '0644'
  }

  concat::fragment { 'nagios-contactgroup-config':
    target => $nagios::params::config_contactgroup,
    source => "${nagios::params::naginator_confdir}/nagios_contactgroup.cfg",
    order  => '01',
  }

  # This essentially copies /etc/nagios/nagios_timeperiod.cfg to /etc/nagios3/conf.d/timeperiods_puppet.cfg
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

  include rsync::server

  rsync::server::module { 'nagios':
    path    => $nagios::params::confdir_hosts,
    require => Package[$packages]
  }

  if $manage_firewall {
    firewall { '200 Allow rsync access for Nagios':
      chain  => 'INPUT',
      proto  => 'tcp',
      dport  => '873',
      action => 'accept'
    }
  }

  # Distribute the monitor host key to targets
  @@sshkey { $monitor_host:
    key  => $nagios::params::sshrsakey,
    type => 'ssh-rsa',
    tag  => 'nagios-monitor-key'
  }
}
