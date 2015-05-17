require 'spec_helper'

describe 'nagios::target' do
  let(:facts) {{
    :osfamily   => 'Debian',
    :hostname   => 'foo',
    :ipaddress  => '1.2.3.4',
    :clientcert => 'foo.example.com'
  }}

  let(:hiera_config) { 'spec/fixtures/hiera/hiera.yaml' }

  it do
    should contain_class('nagios::target')
  end

  context "with defaults" do
    let(:params) {{
      :target_host  => '1.2.3.5',
    }}

    it do 
      should contain_user('nagsync')
    end

    it do 
      should contain_file('/etc/nagios') \
        .with_ensure('directory') \
        .with_owner('nagsync') \
        .with_mode('0755') \
        .with_require('User[nagsync]')
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
  end

  context "with is_monitor == false" do
    let(:params) {{
      :use_nrpe     => false,
      :target_host  => '1.2.3.5'
    }}

    it do
      should contain_file('/etc/nagios/.ssh') \
        .with_ensure('directory') \
        .with_owner('nagsync') \
        .with_require('File[/etc/nagios]')
    end

    it do
      should contain_class('rsync')
    end

    it do
      should contain_exec('ssh-keygen-nagios') \
        .with_command('/usr/bin/ssh-keygen -t rsa -b 2048 -f \'/etc/nagios/.ssh/id_rsa\' -N \'\' -C \'Nagios SSH key\'') \
        .with_user('nagsync') \
        .with_creates('/etc/nagios/.ssh/id_rsa') \
        .with_require('File[/etc/nagios/.ssh]')
    end

    it do
        should contain_rsync__put('1.2.3.5:/etc/nagios3/conf.d/foo.example.com_host.cfg') \
          .with_user('nagios') \
          .with_keyfile('/etc/nagios/.ssh/id_rsa')
          .with_source('/etc/nagios/nagios_host.cfg')
    end

    it do
        should contain_rsync__put('1.2.3.5:/etc/nagios3/conf.d/foo.example.com_service.cfg') \
          .with_user('nagios') \
          .with_keyfile('/etc/nagios/.ssh/id_rsa')
          .with_source('/etc/nagios/nagios_service.cfg')
    end

    context "with use_nrpe == false" do
      let(:params) {{ :use_nrpe => false }}

      it do
        should_not contain_class('nrpe')
      end
    end
  end
end
