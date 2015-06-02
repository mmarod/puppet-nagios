require 'spec_helper'

describe 'nagios::target' do
  let(:hiera_config) { 'spec/fixtures/hiera/hiera.yaml' }
  let(:facts) {{
    :osfamily   => 'Debian',
    :kernel     => 'Linux',
    :hostname   => 'foo',
    :ipaddress  => '1.2.3.4',
    :clientcert => 'foo.example.com'
  }}

  it do
    should contain_class('nagios::target')
  end

  context "with kernel == 'Windows'" do
    let(:facts) {{
      :osfamily   => 'Windows',
      :kernel     => 'Windows',
      :hostname   => 'foo',
      :ipaddress  => '1.2.3.4',
      :clientcert => 'foo.example.com'
    }}

    it do 
      should contain_file('C:\nagios') \
        .with_ensure('directory')
    end

    it do
      should_not contain_file('/etc/nagios/.ssh')
    end

    it do
      should contain_concat_file('nagios-config') \
        .with_path('C:\nagios/nagios_config.cfg') \
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
  end

  context "with kernel == 'Linux'" do
    let(:facts) {{
      :osfamily   => 'Debian',
      :kernel     => 'Linux',
      :hostname   => 'foo',
      :ipaddress  => '1.2.3.4',
      :clientcert => 'foo.example.com'
    }}

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
      should contain_file('/etc/nagios/.ssh') \
        .with_ensure('directory') \
        .with_owner('nagsync') \
        .with_mode('0755') \
        .with_require(/User\[nagsync\]/) \
        .with_require(/File\[\/etc\/nagios\]/)
    end

    it do
      should contain_concat_file('nagios-config') \
        .with_tag('nagios-config') \
        .with_path('/etc/nagios/nagios_config.cfg') \
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

  context "with xfer_method == 'storeconfig'" do 
    let(:params) {{ :xfer_method => 'storeconfig' }}

    it do
      should_not contain_class('rsync')
    end
  end

  context "with xfer_method == 'rsync'" do
    let(:params) {{
      :xfer_method => 'rsync',
    }}

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
      should contain_rsync__put('nagios.example.com:/etc/nagios3/conf.d/hosts/foo_example_com.cfg') \
        .with_user('nagios') \
        .with_keyfile('/etc/nagios/.ssh/id_rsa') \
        .with_source('/etc/nagios/nagios_config.cfg')
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
