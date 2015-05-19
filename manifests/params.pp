class nagios::params {
  case $::osfamily {
    'Debian': {
      $plugin_path         = '/usr/lib/nagios/plugins'
      $eventhandler_path   = '/usr/share/nagios3/plugins/eventhandlers'
      $nagios_cfg_path     = '/etc/nagios3/nagios.cfg'
      $confdir             = '/etc/nagios3/conf.d'
      $nagios_service_name = 'nagios3'
      $cfg_files           = [ '/etc/nagios3/commands.cfg' ]
      $cfg_dirs            = [ '/etc/nagios-plugins/config', '/etc/nagios3/conf.d' ]
      $packages            = [ 'nagios3', 'nagios-plugins' ]
      $config_contact      = '/etc/nagios3/conf.d/contacts.cfg'
      $config_contactgroup = '/etc/nagios3/conf.d/contactgroups.cfg'
      $config_timeperiod   = '/etc/nagios3/conf.d/timeperiods.cfg'
    }
    'RedHat': {
      $plugin_path         = $::architecture ? {
        /x86_64/ => '/usr/lib64/nagios/plugins',
        default  => '/usr/lib/nagios/plugins',
      }
      $eventhandler_path   = $::architecture ? {
        /x86_64/ => '/usr/lib64/nagios/plugins/eventhandlers',
        default  => '/usr/lib/nagios/plugins/eventhandlers',
      }
      $nagios_cfg_path     = '/etc/nagios/nagios.cfg'
      $confdir             = '/etc/nagios'
      $nagios_service_name = 'nagios'
      $cfg_files           = [ '/etc/nagios/commands.cfg' ]
      $cfg_dirs            = [ '/etc/nagios-plugins/config', '/etc/nagios/conf.d' ]
      $packages            = [ 'nagios', 'nagios-plugins' ]
      $config_contact      = '/etc/nagios/conf.d/contacts.cfg'
      $config_contactgroup = '/etc/nagios/conf.d/contactgroups.cfg'
      $config_timeperiod   = '/etc/nagios/conf.d/timeperiods.cfg'
    }
    default: {
      fail("Unsupported operating system '${::osfamily}'.")
    }
  }
  $naginator_confdir  = '/etc/nagios'
  $plugin_mode        = '0755'
  $eventhandler_mode  = '0755'
  $nagios_user        = 'nagios'
  $nagios_group       = 'nagios'
}
