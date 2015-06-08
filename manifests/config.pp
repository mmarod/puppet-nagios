# This class is used to share a couple of values between targets and the
# monitor. Do not call this class directly.
#
# @example Minimal Hiera Configuration
#   nagios::config::monitor_host: nagios.example.com
#
# @example Configuration with RedHat monitor and Debian host
#   nagios::config::monitor_host: nagios.example.com
#   nagios::config::target_path: /etc/nagios/conf.d/hosts
#
# @param monitor_host [String] The domain name or IP address of the monitor.
# @param target_path [String] The path where host configurations will be stored.
# @param nagios_user [String] The nagios user. Also used as the default value
#   for remote_user on targets.
# @param nagios_group [String] The nagios group.
# @param target_sync_user [String] The user to use on targets that perform rsyncing
#   and naginator configuration
# @param monitor_sync_user [String] The user to use on targets that perform rsyncing
#   and naginator configuration
# @param cwrsync_version [String] The version of cwRsync to download
# @param proxyAddress [String] Proxy address to use for downloading cwRsync
#
class nagios::config (
  $monitor_host,
  $target_path       = $nagios::params::target_path,
  $nagios_user       = $nagios::params::nagios_user,
  $nagios_group      = $nagios::params::nagios_group,
  $target_sync_user  = $nagios::params::target_sync_user,
  $monitor_sync_user = $nagios::params::monitor_sync_user,
  $cfg_files         = $nagios::params::cfg_files,
  $cfg_dirs          = $nagios::params::cfg_dirs,
  $cfg_extra         = $nagios::params::cfg_extra,
  $cwrsync_version   = $nagios::params::cwrsync_version,
  $proxyAddress      = undef,
) inherits nagios::params {
  validate_string($monitor_host)
  validate_absolute_path($target_path)
  validate_string($nagios_user)
  validate_string($nagios_group)
  validate_string($target_sync_user)
  validate_string($monitor_sync_user)
  validate_array($cfg_files)
  validate_array($cfg_dirs)
  validate_hash($cfg_extra)
  validate_string($cwrsync_version)
  validate_string($proxyAddress)
}
