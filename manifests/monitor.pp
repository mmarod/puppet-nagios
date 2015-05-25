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
  $config_file = "${confdir_hosts}/${filebase_escaped}.cfg"

  ensure_packages($packages)

  service { $nagios_service_name:
    ensure  => running,
  }

  file { $inotify_init:
    ensure  => present,
    mode    => '0755',
    owner   => 'root',
    content => template($inotify_template),
  }

  file { $inotify_script:
    ensure  => present,
    mode    => '0755',
    owner   => 'root',
    content => template('nagios/inotify-nagios.erb'),
  }

  if $::osfamily == 'Debian' {
    file { $inotify_default:
      ensure  => present,
      mode    => '0644',
      content => 'VERBOSE=yes',
      before  => Service[$inotify_service_name]
    }
  }

  service { $inotify_service_name:
    ensure  => running,
    require => [ File[$inotify_init], File[$inotify_script] ]
  }

  user { $nagios_user:
    ensure         => present,
    managehome     => true,
    home           => '/home/nagios',
    purge_ssh_keys => true,
  } -> Ssh_authorized_key<||>

  file { $naginator_confdir:
    ensure  => directory,
    owner   => $nagios_user,
    mode    => '0755',
    require => User[$nagios_user]
  } -> Nagios_host<||> ->
       Nagios_service<||> ->
       Nagios_hostgroup<||> ->
       Nagios_servicegroup<||> ->
       Nagios_command<||> ->
       Nagios_contact<||> ->
       Nagios_contactgroup<||> ->
       Nagios_timeperiod<||>

  file { $confdir:
    ensure  => directory,
    owner   => $nagios_user,
    require => Package[$packages]
  } ->

  file { $confdir_hosts:
    ensure  => directory,
    owner   => $nagios_user,
  }

  Concat_fragment <<| tag == 'nagios-targets' |>>

  concat_file { $nagios_targets:
    tag             => 'nagios-targets',
    ensure_newline  => true,
  }

  exec { 'remove-unmanaged-hosts':
    command => "/usr/bin/find ${confdir_hosts} -name '*.cfg' -exec basename {} \; | /bin/grep -Fxvf ${nagios_targets} | /usr/bin/xargs rm",
    onlyif  => "/usr/bin/find ${confdir_hosts} -name '*.cfg' -exec basename {} \; | /bin/grep -Fxvf ${nagios_targets}",
    require => Concat_file[$nagios_targets]
  }

  $aug_file = nag_to_aug($cfg_files, 'cfg_file', $nagios_cfg_path)

  augeas { 'configure-nagios_cfg-cfg_file-settings':
    incl    => $nagios_cfg_path,
    lens    => "NagiosCfg.lns",
    changes => $aug_file['changes'],
    onlyif  => $aug_file['onlyif'],
    require => File[$confdir]
  }

  $aug_dir = nag_to_aug($cfg_dirs, 'cfg_dir', $nagios_cfg_path)

  augeas { 'configure-nagios_cfg-cfg_dir-settings':
    incl    => $nagios_cfg_path,
    lens    => "NagiosCfg.lns",
    changes => $aug_dir['changes'],
    onlyif  => $aug_dir['onlyif'],
    require => File[$confdir]
  }

  $changes_array = join_keys_to_values($config, ' \'"')
  $changes_quoted = suffix($changes_array, '"\'')
  $changes = prefix($changes_quoted, 'set ')

  augeas { 'configure-nagios_cfg-custom-settings':
    incl    => $nagios_cfg_path,
    lens    => "NagiosCfg.lns",
    changes => $changes,
    require => File[$confdir]
  }

  file {[ "${naginator_confdir}/nagios_host.cfg",
          "${naginator_confdir}/nagios_hostgroup.cfg",
          "${naginator_confdir}/nagios_service.cfg",
          "${naginator_confdir}/nagios_servicegroup.cfg",
          "${naginator_confdir}/nagios_command.cfg",
          "${naginator_confdir}/nagios_contact.cfg",
          "${naginator_confdir}/nagios_contactgroup.cfg",
          "${naginator_confdir}/nagios_timeperiod.cfg"]:
    ensure => present,
    owner  => $nagios_user,
    group  => $nagios_user,
    mode   => '0644',
    notify => Service[$nagios_service_name],
    before => [ Concat[$config_file],
                Concat[$config_contact],
                Concat[$config_contactgroup],
                Concat[$config_timeperiod] ]
  }

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

  concat { $config_file:
    owner   => $nagios_user,
    mode    => '0644'
  }

  concat::fragment { 'nagios-host-config':
    target  => $config_file,
    source  => "${naginator_confdir}/nagios_host.cfg",
    order   => '01',
  }

  concat::fragment { 'nagios-hostgroup-config':
    target  => $config_file,
    source  => "${naginator_confdir}/nagios_hostgroup.cfg",
    order   => '02',
  }

  concat::fragment { 'nagios-service-config':
    target  => $config_file,
    source  => "${naginator_confdir}/nagios_service.cfg",
    order   => '03',
  }

  concat::fragment { 'nagios-servicegroup-config':
    target  => $config_file,
    source  => "${naginator_confdir}/nagios_servicegroup.cfg",
    order   => '04',
  }

  concat::fragment { 'nagios-command-config':
    target  => $config_file,
    source  => "${naginator_confdir}/nagios_command.cfg",
    order   => '05',
  }

  concat { $config_contact:
    owner   => $nagios_user,
    mode    => '0644'
  }

  concat::fragment { 'nagios-contact-config':
    target  => $config_contact,
    source  => "${naginator_confdir}/nagios_contact.cfg",
    order   => '01',
  }

  concat { $config_contactgroup:
    owner   => $nagios_user,
    mode    => '0644'
  }

  concat::fragment { 'nagios-contactgroup-config':
    target  => $config_contactgroup,
    source  => "${naginator_confdir}/nagios_contactgroup.cfg",
    order   => '01',
  }

  concat { $config_timeperiod:
    owner   => $nagios_user,
    mode    => '0644'
  }

  concat::fragment { 'nagios-timeperiod-config':
    target  => $config_timeperiod,
    source  => "${naginator_confdir}/nagios_timeperiod.cfg",
    order   => '01',
  }

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

  Ssh_authorized_key <<| tag == 'nagios-key' |>>

  include rsync::server

  rsync::server::module { 'nagios':
    path    => $confdir_hosts,
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

  @@sshkey { $monitor_host:
    key  => $sshrsakey,
    type => 'ssh-rsa',
    tag  => 'nagios-monitor-key'
  }
}
