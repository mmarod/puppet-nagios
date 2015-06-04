Facter.add('nagios_key_exists') do
  setcode do
    if Facter.value('kernel').downcase == 'windows'
      keypath = 'C:\nagios\.ssh\id_rsa.pub'
    elsif Facter.value('kernel').downcase == 'linux'
      keypath = '/etc/nagios/.ssh/id_rsa.pub'
    end

    if File.exist?(keypath)
      nagios_key_exists = 'yes'
    else
      nagios_key_exists = 'no'
    end
    nagios_key_exists
  end
end

Facter.add('nagios_key') do
  setcode do
    if Facter.value('kernel').downcase == 'windows'
      keypath = 'C:\nagios\.ssh\id_rsa.pub'
    elsif Facter.value('kernel').downcase == 'linux'
      keypath = '/etc/nagios/.ssh/id_rsa.pub'
    end

    if File.exist?(keypath)
      id_rsa_pub = File.read(keypath)
      nagios_key = id_rsa_pub.split(' ')[1]
    else
      nagios_key = ''
    end
    nagios_key
  end
end
