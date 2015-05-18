# Configures a Nagios event handlers
#
# @example
#   nagios::eventhandlers:
#     'reopen_zope_pgsql.sh':
#       source: 'puppet:///nagios/eventhandlers/reopen_zope_pgsql.sh'
#
define nagios::eventhandler (
    $ensure             = present,
    $content            = undef,
    $source             = undef,
    $owner              = 'nagios',
    $group              = 'nagios',
    $mode               = '0755',
    $eventhandler_path  = $nagios::params::eventhandler_path
) {
  file { "${eventhandler_path}/${title}":
    ensure  => $ensure,
    content => $content,
    source  => $source,
    owner   => $owner,
    group   => $group,
    mode    => $mode,
  }
}
