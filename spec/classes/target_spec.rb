require 'spec_helper'

describe 'nagios::target' do
  let(:hiera_config) { 'spec/fixtures/hiera/hiera.yaml' }
  let(:facts) {{
    :osfamily   => 'Debian',
    :kernel     => 'Linux'
  }}

  it do
    should contain_class('nagios::target')
  end

  it do
    should contain_class('nagios::config')
  end

  context "with kernel == 'windows'" do
    let(:facts) {{
      :osfamily   => 'windows',
      :kernel     => 'windows',
    }}

    it do 
      should contain_file('C:\nagios') \
        .with_ensure('directory') \
          .with_owner(nil) \
          .with_mode(nil)
    end

    it do
      should contain_exec('delete-nagios-config') \
        .with_command('cmd.exe /c del /q C:\nagios\nagios_*') \
        .with_path(['C:\nagios\cwRsync_5.4.1_x86_Free', 'C:\windows', 'C:\windows\system32']) \
        .with_require('File[C:\\nagios]') \
        .with_loglevel('debug')
    end

    it do
      should contain_exec('remove-headers-from-config') \
        .with_command("C:\\windows\\system32\\cmd.exe /c findstr /v /b /c:\"#\" C:\\nagios\\nagios_config_commented.cfg > C:\\nagios\\nagios_config.cfg") \
        .with_require('Concat_file[nagios-config]') \
        .with_loglevel('debug')
    end

    it do
      should contain_concat_file('nagios-config') \
        .with_path('C:\nagios\nagios_config_commented.cfg') \
        .with_tag('nagios-config') \
        .with_loglevel('debug') \
    end

    it do
      should contain_concat_fragment('nagios-host-config') \
        .with_tag('nagios-config') \
        .with_source('C:\nagios/nagios_host.cfg') \
        .with_order('01')
    end

    it do
      should contain_concat_fragment('nagios-service-config') \
        .with_tag('nagios-config') \
        .with_source('C:\nagios/nagios_service.cfg') \
        .with_order('02')
    end

    context "with xfer_method == 'rsync'" do
      let(:params) {{ :xfer_method => 'rsync' }}

      it do 
        should contain_file('C:\nagios\.ssh') \
          .with_ensure('directory') \
          .with_require('File[C:\nagios]') \
          .with_owner(nil) \
          .with_mode(nil)
      end

      it do
        should_not contain_file('/etc/nagios/.ssh')
      end

      it do
        should_not contain_user('nagsync')
      end

      it do
        should contain_download_file('download-cwrsync') \
          .with_url('https://www.itefix.net/dl/cwRsync_5.4.1_x86_Free.zip') \
          .with_destination_directory('C:\nagios') \
          .with_proxyAddress(nil)
      end

      it do
        should contain_windows__unzip('C:\nagios\cwRsync_5.4.1_x86_Free.zip') \
          .with_destination('C:\nagios') \
          .with_creates('C:\nagios\cwRsync_5.4.1_x86_Free') \
          .with_before(['Exec[ssh-keygen-nagios]', 'Exec[ssh-keygen-nagios-test]', 'Exec[transfer-config-to-nagios]']) \
          .with_require('Download_file[download-cwrsync]')
      end

      it do
        should contain_exec('ssh-keygen-nagios') \
          .with_command('ssh-keygen -t rsa -b 2048 -f \'C:\nagios\.ssh\id_rsa\' -N \'\' -C \'Nagios SSH key\'') \
          .with_path(['C:\nagios\cwRsync_5.4.1_x86_Free', 'C:\windows', 'C:\windows\system32']) \
          .with_user(nil) \
          .with_creates('C:\nagios\.ssh\id_rsa') \
          .with_require('File[C:\nagios\.ssh]') \
          .with_before('Exec[transfer-config-to-nagios]')
      end

      it do
        should contain_exec('ssh-keygen-nagios-test') \
          .with_command('ssh-keygen -t rsa -b 2048 -f \'C:\nagios\.ssh\id_rsa_test\' -N \'\' -C \'Test Nagios SSH key\'') \
          .with_path(['C:\nagios\cwRsync_5.4.1_x86_Free', 'C:\windows', 'C:\windows\system32']) \
          .with_user(nil) \
          .with_creates('C:\nagios\.ssh\id_rsa_test') \
          .with_require('File[C:\nagios\.ssh]') \
          .with_before('Exec[transfer-config-to-nagios]')
      end

      it do
        should contain_exec('transfer-config-to-nagios') \
          .with_command("cmd.exe /c rsync -q --no-perms --chmod=ug=rw,o-rwx -c -e 'ssh -i /cygdrive/c/nagios/.ssh/id_rsa -l nagsync' /cygdrive/c/nagios/nagios_config.cfg nagsync@nagios.example.com:/etc/nagios3/conf.d/hosts/foo_example_com.cfg") \
          .with_environment(['CWRSYNCHOME=C:\nagios\cwRsync_5.4.1_x86_Free', 'HOME=C:\nagios']) \
          .with_path(['C:\nagios\cwRsync_5.4.1_x86_Free', 'C:\windows', 'C:\windows\system32']) \
          .with_onlyif("cmd.exe /c rsync --dry-run --itemize-changes --no-perms --chmod=ug=rw,o-rwx -c -e 'ssh -i /cygdrive/c/nagios/.ssh/id_rsa_test -l nagsync' /cygdrive/c/nagios/nagios_config.cfg nagsync@nagios.example.com:/etc/nagios3/conf.d/hosts/foo_example_com.cfg | find /v /c \"\"") \
          .with_require('Exec[remove-headers-from-config]')
      end
    end
  end

  context "with kernel == 'Linux'" do
    it do 
      should contain_user('nagsync') \
        .with_before('File[/etc/nagios]')
    end

    it do 
      should contain_file('/etc/nagios') \
        .with_ensure('directory') \
        .with_owner('nagsync') \
        .with_mode('0755')
    end

    it do
      should contain_concat_file('nagios-config') \
        .with_tag('nagios-config') \
        .with_path('/etc/nagios/nagios_config_commented.cfg') \
        .with_owner('nagsync') \
        .with_mode('0644')
    end

    it do
      should contain_concat_fragment('nagios-host-config') \
        .with_tag('nagios-config') \
        .with_source('/etc/nagios/nagios_host.cfg') \
        .with_order('01')
    end

    it do
      should contain_concat_fragment('nagios-service-config') \
        .with_tag('nagios-config') \
        .with_source('/etc/nagios/nagios_service.cfg') \
        .with_order('02')
    end

    it do
      should contain_exec('remove-headers-from-config') \
        .with_command("/bin/sed '/^#/ d' /etc/nagios/nagios_config_commented.cfg > /etc/nagios/nagios_config.cfg") \
        .with_require('Concat_file[nagios-config]') \
        .with_loglevel('debug')
    end

    context "with xfer_method == 'rsync'" do
      let(:params) {{ :xfer_method => 'rsync' }}

      it do
        should contain_file('/etc/nagios/.ssh') \
          .with_ensure('directory') \
          .with_owner('nagsync') \
          .with_mode('0755') \
          .with_require('File[/etc/nagios]')
      end

      it do
        should contain_package('openssh-client') \
          .with_ensure('present') \
          .with_before(['Exec[ssh-keygen-nagios]', 'Exec[ssh-keygen-nagios-test]', 'Exec[transfer-config-to-nagios]'])
      end

      it do
        should contain_package('rsync') \
          .with_ensure('present') \
          .with_before(['Exec[ssh-keygen-nagios]', 'Exec[ssh-keygen-nagios-test]', 'Exec[transfer-config-to-nagios]'])
      end
      
      it do
        should contain_exec('ssh-keygen-nagios') \
          .with_command('ssh-keygen -t rsa -b 2048 -f \'/etc/nagios/.ssh/id_rsa\' -N \'\' -C \'Nagios SSH key\'') \
          .with_path(['/bin', '/usr/bin']) \
          .with_user('nagsync') \
          .with_creates('/etc/nagios/.ssh/id_rsa') \
          .with_require('File[/etc/nagios/.ssh]') \
          .with_before('Exec[transfer-config-to-nagios]')
      end

      it do
        should contain_exec('ssh-keygen-nagios-test') \
          .with_command('ssh-keygen -t rsa -b 2048 -f \'/etc/nagios/.ssh/id_rsa_test\' -N \'\' -C \'Test Nagios SSH key\'') \
          .with_path(['/bin', '/usr/bin']) \
          .with_user('nagsync') \
          .with_creates('/etc/nagios/.ssh/id_rsa_test') \
          .with_require('File[/etc/nagios/.ssh]') \
          .with_before('Exec[transfer-config-to-nagios]')
      end

      it do
        should contain_exec('transfer-config-to-nagios') \
          .with_command("rsync -q --no-perms --chmod=ug=rw,o-rwx -c -e 'ssh -i /etc/nagios/.ssh/id_rsa -l nagsync' /etc/nagios/nagios_config.cfg nagsync@nagios.example.com:/etc/nagios3/conf.d/hosts/foo_example_com.cfg") \
          .with_environment(nil) \
          .with_path(['/bin','/usr/bin']) \
          .with_onlyif("test `rsync --dry-run --itemize-changes --no-perms --chmod=ug=rw,o-rwx -c -e 'ssh -i /etc/nagios/.ssh/id_rsa_test -l nagsync' /etc/nagios/nagios_config.cfg nagsync@nagios.example.com:/etc/nagios3/conf.d/hosts/foo_example_com.cfg | wc -l` -gt 0") \
          .with_require('Exec[remove-headers-from-config]')
      end
    end
  end

  it do
    should contain_nagios_host('testhost') \
      .with_ensure('present') \
      .with_alias('foo') \
      .with_address('1.2.3.4') \
      .with_use('generic-host') \
      .with_hostgroups('testhostgroup') \
      .with_icon_image('base/icon.png') \
      .with_notification_period('24x7')
  end

  it do
    should contain_nagios_service('testservice') \
      .with_check_command('/usr/bin/testcommand') \
      .with_use('generic-service') \
      .with_host_name('foo.example.com') \
      .with_service_description('test command') \
      .with_notification_period('24x7')
  end

  context "with use_nrpe == false" do
    let(:params) {{ :use_nrpe => false }}
    it do
      should_not contain_class('nrpe')
    end
  end

  context "with use_nrpe == true" do
    let(:params) {{ :use_nrpe => true }}
    it do
      should contain_class('nrpe')
    end

    it do
      should contain_nrpe__command('testnrpecommand')
    end

    it do
      should contain_nrpe__plugin('testnrpeplugin')
    end
  end
end
