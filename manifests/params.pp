# Params class
#
class nagios::params {
  $plugin_mode        = '0755'
  $eventhandler_mode  = '0755'
  $nagios_user        = 'nagios'
  $nagios_group       = 'nagios'
  $xfer_method        = 'rsync'
  $filebase           = $::clientcert

  case downcase($::kernel) {
    'windows': {
      $environment            = [ 'NAGSYNCHOME=C:\nagios',
                                  'CWRSYNCHOME=C:\nagios\cwrsync',
                                  'HOME=C:\nagios' ]
      $exec_path              = [ 'C:\nagios\cwrsync', 'C:\windows', 'C:\windows\system32' ]
      $ssh_confdir            = 'C:\nagios\.ssh'
      $ssh_keygen_path        = 'C:\nagios\cwrsync\ssh-keygen'
      $sshkey_path            = 'C:\nagios\.ssh\known_hosts'
      $local_user             = undef
      $naginator_confdir      = 'C:\nagios'
      $naginator_confdir_mode = undef
      $config_file_mode       = undef
      $config_file_loglevel   = 'debug'
      $host_defaults          = { 'ensure' => 'present', 'target' => 'C:/nagios/nagios_host.cfg', 'loglevel' => 'debug' }
      $service_defaults       = { 'ensure' => 'present', 'target' => 'C:/nagios/nagios_service.cfg', 'loglevel' => 'debug' }
      $use_nrpe               = false
      # lint:ignore:double_quoted_strings
      $sep                    = "\\"
      # lint:endignore
    }
    'linux': {
      $environment            = undef
      $exec_path              = undef
      $ssh_confdir            = '/etc/nagios/.ssh'
      $ssh_keygen_path        = '/usr/bin/ssh-keygen'
      $sshkey_path            = undef
      $local_user             = 'nagsync'
      $naginator_confdir      = '/etc/nagios'
      $naginator_confdir_mode = '0755'
      $config_file_mode       = '0644'
      $config_file_loglevel   = undef
      $host_defaults          = { 'ensure' => 'present' }
      $service_defaults       = { 'ensure' => 'present' }
      $use_nrpe               = true
      $sep                    = '/'

      case downcase($::osfamily) {
        'debian': {
          $plugin_path          = '/usr/lib/nagios/plugins'
          $eventhandler_path    = '/usr/share/nagios3/plugins/eventhandlers'
          $nagios_cfg_path      = '/etc/nagios3/nagios.cfg'
          $nagios_targets       = '/etc/nagios3/nagios-targets.txt'
          $confdir              = '/etc/nagios3/conf.d'
          $logdir               = '/var/log/nagios3'
          $inotify_log          = '/var/log/nagios3/inotify.log'
          $inotify_script       = '/usr/sbin/inotify-nagios'
          $inotify_init         = '/etc/init.d/inotify-nagios'
          $inotify_source       = 'puppet:///modules/nagios/inotify-nagios.DEBIAN.erb'
          $inotify_default      = '/etc/default/inotify-nagios'
          $inotify_service_name = 'inotify-nagios'
          $nagios_service_name  = 'nagios3'
          $cfg_files            = []
          $cfg_dirs             = [ '/etc/nagios-plugins/config', '/etc/nagios3/conf.d' ]
          $packages             = [ 'nagios3', 'nagios-plugins', 'screen', 'inotify-tools' ]
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
          $nagios_cfg_path      = '/etc/nagios/nagios.cfg'
          $nagios_targets       = '/etc/nagios/nagios-targets.txt'
          $confdir              = '/etc/nagios/conf.d'
          $logdir               = '/var/log/nagios'
          $inotify_log          = '/var/log/nagios/inotify.log'
          $inotify_script       = '/usr/sbin/inotify-nagios'
          $inotify_init         = '/etc/init.d/inotify-nagios'
          $inotify_source       = 'puppet:///modules/nagios/inotify-nagios.REDHAT.erb'
          $inotify_service_name = 'inotify-nagios'
          $nagios_service_name  = 'nagios'
          $cfg_files            = []
          $cfg_dirs             = [ '/etc/nagios-plugins/config', '/etc/nagios/conf.d' ]
          $packages             = [ 'nagios', 'nagios-plugins', 'screen', 'inotify-tools' ]
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
}
