# This class configures a Nagios monitor.
#
# @example Standard configuration
#   include '::nagios::monitor'
#
# @example Include /etc/nagios3/commands.cfg
#   class { '::nagios::monitor':
#     cfg_files => [ '/etc/nagios3/commands.cfg' ]
#   }
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
# @param manage_firewall [Boolean] Whether or not to open port 873 for the rsync
#   server on the monitor.
#
class nagios::monitor(
  $cfg_files           = $nagios::params::cfg_files,
  $cfg_dirs            = $nagios::params::cfg_dirs,
  $cfg_extra           = {},
  $manage_firewall     = false,
) inherits nagios::params {
  validate_array($cfg_files)
  validate_array($cfg_dirs)
  validate_hash($cfg_extra)
  validate_bool($manage_firewall)

  include nagios::config

  $monitor_host        = $nagios::config::monitor_host
  $target_path         = $nagios::config::target_path
  $nagios_user         = $nagios::config::nagios_user
  $nagios_group        = $nagios::config::nagios_group

  $filebase_escaped = regsubst($nagios::params::filebase, '\.', '_', 'G')
  $config_file = "${target_path}/${filebase_escaped}.cfg"

  ensure_packages($nagios::params::packages)

  service { $nagios::params::nagios_service_name:
    ensure  => running,
  }

  file { $nagios::params::files_to_purge:
    ensure  => absent,
    require => Package[$nagios::params::packages],
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
    require => Package[$nagios::params::packages]
  } ->

  file { $target_path:
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
  $changes_array = join_keys_to_values($cfg_extra, ' \'"')
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
                Concat[$nagios::params::config_command],
                Concat[$nagios::params::config_servicegroup],
                Concat[$nagios::params::config_hostgroup],
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

  # Create default contactgroup if there are none defined
  if ! has_key($contactgroups, 'admins') {
    nagios_contactgroup { 'admins':
      ensure  => present,
      alias   => 'Nagios Administrators',
      members => 'root'
    }
  }
  
  # Create default timeperiods if there are none defined
  if ! has_key($timeperiods, '24x7') {
    nagios_timeperiod { '24x7':
      ensure    => present,
      alias     => '24 Hours A Day, 7 Days A Week',
      sunday    => '00:00-24:00',
      monday    => '00:00-24:00',
      tuesday   => '00:00-24:00',
      wednesday => '00:00-24:00',
      thursday  => '00:00-24:00',
      friday    => '00:00-24:00',
      saturday  => '00:00-24:00',
    }
  }

  if ! has_key($timeperiods, 'workhours') {
    nagios_timeperiod { 'workhours':
      ensure    => present,
      alias     => 'Standard Work Hours',
      monday    => '09:00-17:00',
      tuesday   => '09:00-17:00',
      wednesday => '09:00-17:00',
      thursday  => '09:00-17:00',
      friday    => '09:00-17:00',
    }
  }

  if ! has_key($timeperiods, 'nonworkhours') {
    nagios_timeperiod { 'nonworkhours':
      ensure    => present,
      alias     => 'Non-Work Hours',
      sunday    => '00:00-24:00',
      monday    => '00:00-09:00,17:00-24:00',
      tuesday   => '00:00-24:00,17:00-24:00',
      wednesday => '00:00-24:00,17:00-24:00',
      thursday  => '00:00-24:00,17:00-24:00',
      friday    => '00:00-24:00,17:00-24:00',
      saturday  => '00:00-24:00',
    }
  }

  if ! has_key($timeperiods, 'never') {
    nagios_timeperiod { 'never':
      ensure => present,
      alias  => 'never'
    }
  }

  # Create generic-host
  if ! has_key($hosts, 'generic-host') {
    nagios_host { 'generic-host':
      ensure                       => present,
      notifications_enabled        => 1,
      event_handler_enabled        => 1,
      flap_detection_enabled       => 1,
      failure_prediction_enabled   => 1,
      process_perf_data            => 1,
      retain_status_information    => 1,
      retain_nonstatus_information => 1,
      check_command                => 'check-host-alive',
      max_check_attempts           => 10,
      notification_interval        => 0,
      notification_period          => '24x7',
      notification_options         => 'd,u,r',
      contact_groups               => 'admins',
      register                     => 0
    }
  }

  # Create generic-service
  if ! has_key($services, 'generic-service') {
    nagios_service { 'generic-service':
      ensure                       => present,
      active_checks_enabled        => 1,
      passive_checks_enabled       => 1,
      parallelize_check            => 1,
      obsess_over_service          => 1,
      check_freshness              => 0,
      notifications_enabled        => 1,
      event_handler_enabled        => 1,
      flap_detection_enabled       => 1,
      failure_prediction_enabled   => 1,
      process_perf_data            => 1,
      retain_status_information    => 1,
      retain_nonstatus_information => 1,
      notification_interval        => 0,
      is_volatile                  => 0,
      check_period                 => '24x7',
      normal_check_interval        => 5,
      retry_check_interval         => 1,
      max_check_attempts           => 4,
      notification_period          => '24x7',
      notification_options         => 'w,u,c,r',
      contact_groups               => 'admins',
      register                     => 0
    }
  }

  if ! has_key($commands, 'notify-host-by-email') {
    nagios_command { 'notify-host-by-email':
      command_line => '/usr/bin/printf "%b" "***** Nagios *****\n\nNotification Type: $NOTIFICATIONTYPE$\nHost: $HOSTNAME$\nState: $HOSTSTATE$\nAddress: $HOSTADDRESS$\nInfo: $HOSTOUTPUT$\n\nDate/Time: $LONGDATETIME$\n" | /usr/bin/mail -s "** $NOTIFICATIONTYPE$ Host Alert: $HOSTNAME$ is $HOSTSTATE$ **" $CONTACTEMAIL$'
    }
  }

  if ! has_key($commands, 'notify-service-by-email') {
    nagios_command { 'notify-service-by-email':
      command_line => '/usr/bin/printf "%b" "***** Nagios *****\n\nNotification Type: $NOTIFICATIONTYPE$\n\nService: $SERVICEDESC$\nHost: $HOSTALIAS$\nAddress: $HOSTADDRESS$\nState: $SERVICESTATE$\n\nDate/Time: $LONGDATETIME$\n\nAdditional Info:\n\n$SERVICEOUTPUT$\n" | /usr/bin/mail -s "** $NOTIFICATIONTYPE$ Service Alert: $HOSTALIAS$/$SERVICEDESC$ is $SERVICESTATE$ **" $CONTACTEMAIL$'
    }
  }

  if ! has_key($commands, 'process-host-perfdata') {
    nagios_command { 'process-host-perfdata':
      command_line => '/usr/bin/printf "%b" "$LASTHOSTCHECK$\t$HOSTNAME$\t$HOSTSTATE$\t$HOSTATTEMPT$\t$HOSTSTATETYPE$\t$HOSTEXECUTIONTIME$\t$HOSTOUTPUT$\t$HOSTPERFDATA$\n" >> /var/lib/nagios3/host-perfdata.out'
    }
  }

  if ! has_key($commands, 'process-service-perfdata') {
    nagios_command { 'process-service-perfdata':
      command_line => '/usr/bin/printf "%b" "$LASTSERVICECHECK$\t$HOSTNAME$\t$SERVICEDESC$\t$SERVICESTATE$\t$SERVICEATTEMPT$\t$SERVICESTATETYPE$\t$SERVICEEXECUTIONTIME$\t$SERVICELATENCY$\t$SERVICEOUTPUT$\t$SERVICEPERFDATA$\n" >> /var/lib/nagios3/service-perfdata.out'
    }
  }

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

  include rsync::server

  rsync::server::module { 'nagios':
    path    => $target_path,
    require => Package[$nagios::params::packages]
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
