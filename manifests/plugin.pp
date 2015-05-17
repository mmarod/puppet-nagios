# Configures a Nagios plugins
#
# @example
#   nagios::plugins:
#     'check_windows.cfg':
#       source: 'puppet:///nagios/plugins/check_windows.cfg'
#
define nagios::plugin (
    $ensure       = present,
    $content      = undef,
    $source       = undef,
    $owner        = 'nagios',
    $group        = 'nagios',
    $mode         = '0755',
    $plugin_path  = '/etc/nagios-plugins/config',
) {
  file { "${plugin_path}/${title}":
    ensure  => $ensure,
    content => $content,
    source  => $source,
    owner   => $owner,
    group   => $group,
    mode    => $mode,
  }
}
