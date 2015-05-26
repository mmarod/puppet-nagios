Facter.add(:nagios_config) do
  setcode do
    if File.exist?('/etc/nagios/nagios_config.cfg')
      Facter::Core::Execution.exec('cat /etc/nagios/nagios_config.cfg')
    end
  end
end
