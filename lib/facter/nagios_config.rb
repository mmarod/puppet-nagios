Facter.add(:nagios_config) do
  setcode do
    if Facter.value('kernel').downcase == 'windows'
      if File.exist?('C:\nagios\nagios_config.cfg')
        Facter::Core::Execution.exec('C:\windows\system32\cmd.exe /c type C:\nagios\nagios_config.cfg')
      end
    elsif Facter.value('kernel').downcase == 'linux'
      if File.exist?('/etc/nagios/nagios_config.cfg')
        Facter::Core::Execution.exec('cat /etc/nagios/nagios_config.cfg')
      end
    end
  end
end
