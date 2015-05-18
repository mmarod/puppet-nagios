class nagios::params {
  case $::osfamily {
    'Debian': {
      $plugin_path         = '/usr/lib/nagios/plugins'
      $eventhandler_path   = '/usr/share/nagios3/plugins/eventhandlers'
      $confdir             = '/etc/nagios3'
      $nagios_service_name = 'nagios3'
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
      $confdir             = '/etc/nagios'
      $nagios_service_name = 'nagios'
    }
    default: {}
  }
}
