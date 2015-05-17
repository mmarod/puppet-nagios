Facter.add('nagios_key_exists') do
  setcode do
    if File.exist?('/etc/nagios/.ssh/id_rsa.pub')
      Facter::Core::Execution.exec('/bin/echo yes')
    else
      Facter::Core::Execution.exec('/bin/echo no')
    end
  end
end

Facter.add('nagios_key') do
  setcode do
    if File.exist?('/etc/nagios/.ssh/id_rsa.pub')
      Facter::Core::Execution.exec('/bin/cat /etc/nagios/.ssh/id_rsa.pub | /usr/bin/awk \'{print $2}\'')
    else
      Facter::Core::Execution.exec('/bin/echo ""')
    end
  end
end
