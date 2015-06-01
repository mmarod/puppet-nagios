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
# @param local_user [String] The local user created on a target to use for
#   rsync'ing.
# @param cfg_files [Array] A list of cfg_files to include in nagios.cfg.
# @param cfg_dirs [Array] A list of cfg_dirs to include in nagios.cfg.
# @param config [Hash] A hash of key/value pairs to set options with in nagios.cfg.
# @param use_nrpe [Boolean] Whether or not to configure nrpe on a target.
# @param xfer_method [String] (rsync/storeconfig) How to transfer the Nagios config to the monitor.
# @param manage_firewall [Boolean] Whether or not to open port 873 for the rsync
#   server on the monitor.
#
#
class nagios::config (
  $monitor_host,
  $target_path      = '/etc/nagios3/conf.d/hosts',
  $nagios_user      = $nagios::params::nagios_user,
  $nagios_group     = $nagios::params::nagios_group
  $local_user       = 'nagsync',
  $cfg_files        = $nagios::params::cfg_files,
  $cfg_dirs         = $nagios::params::cfg_dirs,
  $config           = {},
  $manage_firewall  = false,
  $use_nrpe         = true,
  $xfer_method      = $nagios::params::xfer_method
) inherits nagios::params {
  validate_string($monitor_host)
  validate_absolute_path($target_path)
  validate_string($nagios_user)
  validate_string($nagios_group)
  validate_string($local_user)
  validate_array($cfg_files)
  validate_array($cfg_dirs)
  validate_hash($config)
  validate_bool($manage_firewall)
  validate_bool($use_nrpe)
  validate_string($xfer_method)
}
