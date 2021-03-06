# Params class
#
# lint:ignore:2sp_soft_tabs
class nagios::params {
  case downcase($::kernel) {
    'windows': {
      $remove_comments_command = 'C:\windows\system32\cmd.exe /c findstr /v /b /c:"#" C:\nagios\nagios_config_commented.cfg > C:\nagios\nagios_config.cfg'
      $config_file_commented   = 'C:\nagios\nagios_config_commented.cfg'
      $config_file             = 'C:\nagios\nagios_config.cfg'
      $keypath                 = 'C:\nagios\.ssh\id_rsa'
      $test_keypath            = 'C:\nagios\.ssh\id_rsa_test'
      $rsync_source            = '/cygdrive/c/nagios/nagios_config.cfg'
      $rsync_keypath           = '/cygdrive/c/nagios/.ssh/id_rsa'
      $rsync_test_keypath      = '/cygdrive/c/nagios/.ssh/id_rsa_test'
      $ssh_confdir             = 'C:\nagios\.ssh'
      $sshkey_path             = 'C:\nagios\.ssh\known_hosts'
      $target_sync_user        = undef
      $naginator_confdir       = 'C:\nagios'
      $naginator_confdir_cyg   = '/cygdrive/c/nagios'
      $naginator_confdir_mode  = undef
      $config_file_mode        = undef
      $config_file_loglevel    = 'debug'
      $host_defaults           = { 'ensure' => 'present', 'target' => 'C:\nagios\nagios_host.cfg', 'loglevel' => 'debug' }
      $service_defaults        = { 'ensure' => 'present', 'target' => 'C:\nagios\nagios_service.cfg', 'loglevel' => 'debug' }
      $use_nrpe                = false
    }
    'linux': {
      $remove_comments_command = "/bin/sed '/^#/ d' /etc/nagios/nagios_config_commented.cfg > /etc/nagios/nagios_config.cfg"
      $config_file_commented   = '/etc/nagios/nagios_config_commented.cfg'
      $config_file             = '/etc/nagios/nagios_config.cfg'
      $keypath                 = '/etc/nagios/.ssh/id_rsa'
      $test_keypath            = '/etc/nagios/.ssh/id_rsa_test'
      $rsync_source            = '/etc/nagios/nagios_config.cfg'
      $rsync_keypath           = '/etc/nagios/.ssh/id_rsa'
      $rsync_test_keypath      = '/etc/nagios/.ssh/id_rsa_test'
      $ssh_confdir             = '/etc/nagios/.ssh'
      $sshkey_path             = undef
      $target_sync_user        = 'nagsync'
      $naginator_confdir       = '/etc/nagios'
      $naginator_confdir_cyg   = undef
      $naginator_confdir_mode  = '0755'
      $config_file_mode        = '0644'
      $config_file_loglevel    = undef
      $host_defaults           = { 'ensure' => 'present' }
      $service_defaults        = { 'ensure' => 'present' }
      $use_nrpe                = true

      case downcase($::osfamily) {
        'debian': {
          $nagios_binary        = '/usr/sbin/nagios3'
          $plugin_path          = '/usr/lib/nagios/plugins'
          $eventhandler_path    = '/usr/share/nagios3/plugins/eventhandlers'
          $nagios_cfg_path      = '/etc/nagios3/nagios.cfg'
          $nagios_targets       = '/etc/nagios3/nagios-targets.txt'
          $conf_dir             = '/etc/nagios3'
          $conf_d_dir           = '/etc/nagios3/conf.d'
          $logdir               = '/var/log/nagios3'
          $inotify_log          = '/var/log/nagios3/inotify.log'
          $inotify_script       = '/usr/sbin/inotify-nagios'
          $inotify_script_loop  = '/usr/sbin/inotify-nagios-loop'
          $inotify_init         = '/etc/init.d/inotify-nagios'
          $inotify_source       = 'puppet:///modules/nagios/inotify-nagios.DEBIAN.erb'
          $inotify_default      = '/etc/default/inotify-nagios'
          $inotify_service_name = 'inotify-nagios'
          $nagios_service_name  = 'nagios3'
          $cfg_files            = []
          $cfg_dirs             = [ '/etc/nagios-plugins/config', '/etc/nagios3/conf.d' ]
          $cfg_extra            = {}
          $monitor_packages     = [ 'nagios3', 'nagios-plugins', 'screen', 'inotify-tools', 'rsync', 'openssh-client', 'openssh-server' ]
          $target_packages      = [ 'rsync', 'openssh-client' ]
          $config_command       = '/etc/nagios3/conf.d/commands.cfg'
          $config_servicegroup  = '/etc/nagios3/conf.d/servicegroups.cfg'
          $config_hostgroup     = '/etc/nagios3/conf.d/hostgroups.cfg'
          $config_contact       = '/etc/nagios3/conf.d/contacts.cfg'
          $config_contactgroup  = '/etc/nagios3/conf.d/contactgroups.cfg'
          $config_timeperiod    = '/etc/nagios3/conf.d/timeperiods.cfg'
          $files_to_purge       = [ '/etc/nagios3/commands.cfg',
                                    '/etc/nagios3/conf.d/contacts_nagios2.cfg',
                                    '/etc/nagios3/conf.d/extinfo_nagios2.cfg',
                                    '/etc/nagios3/conf.d/generic-host_nagios2.cfg',
                                    '/etc/nagios3/conf.d/generic-service_nagios2.cfg',
                                    '/etc/nagios3/conf.d/hostgroups_nagios2.cfg',
                                    '/etc/nagios3/conf.d/localhost_nagios2.cfg',
                                    '/etc/nagios3/conf.d/services_nagios2.cfg',
                                    '/etc/nagios3/conf.d/timeperiods_nagios2.cfg' ]
        }
        'redhat': {
          $plugin_path         = $::architecture ? {
            /x86_64/ => '/usr/lib64/nagios/plugins',
            default  => '/usr/lib/nagios/plugins',
          }
          $eventhandler_path   = $::architecture ? {
            /x86_64/ => '/usr/lib64/nagios/plugins/eventhandlers',
            default  => '/usr/lib/nagios/plugins/eventhandlers',
          }
          $nagios_binary        = '/usr/sbin/nagios'
          $nagios_cfg_path      = '/etc/nagios/nagios.cfg'
          $nagios_targets       = '/etc/nagios/nagios-targets.txt'
          $conf_dir             = '/etc/nagios3'
          $conf_d_dir           = '/etc/nagios3/conf.d'
          $logdir               = '/var/log/nagios'
          $inotify_log          = '/var/log/nagios/inotify.log'
          $inotify_script       = '/usr/sbin/inotify-nagios'
          $inotify_script_loop  = '/usr/sbin/inotify-nagios-loop'
          $inotify_init         = '/etc/init.d/inotify-nagios'
          $inotify_source       = 'puppet:///modules/nagios/inotify-nagios.REDHAT.erb'
          $inotify_service_name = 'inotify-nagios'
          $nagios_service_name  = 'nagios'
          $cfg_files            = []
          $cfg_dirs             = [ '/etc/nagios-plugins/config', '/etc/nagios/conf.d' ]
          $cfg_extra            = {}
          $monitor_packages     = [ 'nagios', 'nagios-plugins', 'screen', 'inotify-tools', 'rsync', 'openssh-clients', 'openssh-server' ]
          $target_packages      = [ 'rsync', 'openssh-clients' ]
          $config_command       = '/etc/nagios/conf.d/commands.cfg'
          $config_servicegroup  = '/etc/nagios/conf.d/servicegroups.cfg'
          $config_hostgroup     = '/etc/nagios/conf.d/hostgroups.cfg'
          $config_contact       = '/etc/nagios/conf.d/contacts.cfg'
          $config_contactgroup  = '/etc/nagios/conf.d/contactgroups.cfg'
          $config_timeperiod    = '/etc/nagios/conf.d/timeperiods.cfg'
          $files_to_purge       = [ '/etc/nagios/commands.cfg',
                                    '/etc/nagios/conf.d/contacts_nagios2.cfg',
                                    '/etc/nagios/conf.d/extinfo_nagios2.cfg',
                                    '/etc/nagios/conf.d/generic-host_nagios2.cfg',
                                    '/etc/nagios/conf.d/generic-service_nagios2.cfg',
                                    '/etc/nagios/conf.d/hostgroups_nagios2.cfg',
                                    '/etc/nagios/conf.d/localhost_nagios2.cfg',
                                    '/etc/nagios/conf.d/services_nagios2.cfg',
                                    '/etc/nagios/conf.d/timeperiods_nagios2.cfg' ]
        }
        default: {
          fail("Unsupported operating system '${::osfamily}'.")
        }
      }
    }
    default: {
      fail("Unsupported kernel '${::kernel}'.")
    }
  }
  $plugin_mode           = '0755'
  $eventhandler_mode     = '0755'
  $nagios_user           = 'nagios'
  $nagios_group          = 'nagios'
  $xfer_method           = 'rsync'
  $cwrsync_version       = '5.4.1'
  $ssh_key_type          = 'rsa'
  $ssh_key_bits          = '2048'
  $ssh_key_comment       = 'Nagios SSH key'
  $test_ssh_key_comment  = 'Test Nagios SSH key'
  $monitor_sync_user     = 'nagsync'
  $target_path           = '/etc/nagios3/conf.d/hosts'

  $default_commands      = { 'notify-host-by-email' => {
                               'command_line' => '/usr/bin/printf "%b" "***** Nagios *****\n\nNotification Type: $NOTIFICATIONTYPE$\nHost: $HOSTNAME$\nState: $HOSTSTATE$\nAddress: $HOSTADDRESS$\nInfo: $HOSTOUTPUT$\n\nDate/Time: $LONGDATETIME$\n" | /usr/bin/mail -s "** $NOTIFICATIONTYPE$ Host Alert: $HOSTNAME$ is $HOSTSTATE$ **" $CONTACTEMAIL$' },
                             'notify-service-by-email' => {
                               'command_line' => '/usr/bin/printf "%b" "***** Nagios *****\n\nNotification Type: $NOTIFICATIONTYPE$\n\nService: $SERVICEDESC$\nHost: $HOSTALIAS$\nAddress: $HOSTADDRESS$\nState: $SERVICESTATE$\n\nDate/Time: $LONGDATETIME$\n\nAdditional Info:\n\n$SERVICEOUTPUT$\n" | /usr/bin/mail -s "** $NOTIFICATIONTYPE$ Service Alert: $HOSTALIAS$/$SERVICEDESC$ is $SERVICESTATE$ **" $CONTACTEMAIL$' },
                             'notify-host-perfdata' => {
                               'command_line' => '/usr/bin/printf "%b" "$LASTHOSTCHECK$\t$HOSTNAME$\t$HOSTSTATE$\t$HOSTATTEMPT$\t$HOSTSTATETYPE$\t$HOSTEXECUTIONTIME$\t$HOSTOUTPUT$\t$HOSTPERFDATA$\n" >> /var/lib/nagios3/host-perfdata.out' },
                             'process-service-perfdata' => {
                               'command_line' => '/usr/bin/printf "%b" "$LASTSERVICECHECK$\t$HOSTNAME$\t$SERVICEDESC$\t$SERVICESTATE$\t$SERVICEATTEMPT$\t$SERVICESTATETYPE$\t$SERVICEEXECUTIONTIME$\t$SERVICELATENCY$\t$SERVICEOUTPUT$\t$SERVICEPERFDATA$\n" >> /var/lib/nagios3/service-perfdata.out'
                             }
                           }
  $default_contacts      = {}
  $default_contactgroups = { 'admins' => {
                               'alias'   => 'Nagios Administrators',
                               'members' => 'root' }
                           }
  $default_eventhandlers = {}
  $default_hostgroups    = {}
  $default_hosts         = { 'generic-host' => {
                               'notifications_enabled'        => 1,
                               'event_handler_enabled'        => 1,
                               'flap_detection_enabled'       => 1,
                               'failure_prediction_enabled'   => 1,
                               'process_perf_data'            => 1,
                               'retain_status_information'    => 1,
                               'retain_nonstatus_information' => 1,
                               'check_command'                => 'check-host-alive',
                               'max_check_attempts'           => 10,
                               'notification_interval'        => 10,
                               'notification_period'          => '24x7',
                               'notification_options'         => 'd,u,r',
                               'contact_groups'               => 'admins',
                               'register'                     => 0 }
                           }
  $default_plugins       = {}
  $default_servicegroups = {}
  $default_services      = { 'generic-service' => {
                               'active_checks_enabled'        => 1,
                               'passive_checks_enabled'       => 1,
                               'parallelize_check'            => 1,
                               'obsess_over_service'          => 1,
                               'check_freshness'              => 0,
                               'notifications_enabled'        => 1,
                               'event_handler_enabled'        => 1,
                               'flap_detection_enabled'       => 1,
                               'failure_prediction_enabled'   => 1,
                               'process_perf_data'            => 1,
                               'retain_status_information'    => 1,
                               'retain_nonstatus_information' => 1,
                               'notification_interval'        => 10,
                               'is_volatile'                  => 0,
                               'check_period'                 => '24x7',
                               'normal_check_interval'        => 5,
                               'retry_check_interval'         => 1,
                               'max_check_attempts'           => 4,
                               'notification_period'          => '24x7',
                               'notification_options'         => 'w,u,c,r',
                               'contact_groups'               => 'admins',
                               'register'                     => 0 }
                             }
  $default_timeperiods   = { '24x7' => {
                               'alias'     => '24 Hours A Day, 7 Days A Week',
                               'sunday'    => '00:00-24:00',
                               'monday'    => '00:00-24:00',
                               'tuesday'   => '00:00-24:00',
                               'wednesday' => '00:00-24:00',
                               'thursday'  => '00:00-24:00',
                               'friday'    => '00:00-24:00',
                               'saturday'  => '00:00-24:00' },
                             'workhours' => {
                               'alias'     => 'Standard Work Hours',
                               'monday'    => '09:00-17:00',
                               'tuesday'   => '09:00-17:00',
                               'wednesday' => '09:00-17:00',
                               'thursday'  => '09:00-17:00',
                               'friday'    => '09:00-17:00' },
                             'nonworkhours' => {
                               'alias'     => 'Non-Work Hours',
                               'sunday'    => '00:00-24:00',
                               'monday'    => '00:00-09:00,17:00-24:00',
                               'tuesday'   => '00:00-09:00,17:00-24:00',
                               'wednesday' => '00:00-09:00,17:00-24:00',
                               'thursday'  => '00:00-09:00,17:00-24:00',
                               'friday'    => '00:00-09:00,17:00-24:00',
                               'saturday'  => '00:00-24:00' },
                             'never' => {
                               'alias'  => 'never' }
                           }
}
# lint:endignore
