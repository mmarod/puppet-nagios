# This class is used to share a couple of values between targets and the
# monitor. Do not call this class directly.
#
# @example Hiera Configuration
#   nagios::config::monitor_host: nagios.example.com
#   nagios::config::target_path: /etc/nagios3/conf.d/hosts
#
# @param monitor_host [String] The domain name or IP address of the monitor.
# @param target_path [String] The path where host configurations will be stored.
# @param nagios_user [String] The nagios user. Also used as the default value
#   for remote_user on targets.
# @param nagios_group [String] The nagios group.
#
class nagios::config (
  $monitor_host,
  $target_path    = '/etc/nagios3/conf.d/hosts',
  $nagios_user    = 'nagios',
  $nagios_group   = 'nagios'
){
  validate_string($monitor_host)
  validate_absolute_path($target_path)
  validate_string($nagios_user)
  validate_string($nagios_group)
}
