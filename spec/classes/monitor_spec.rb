require 'spec_helper'

describe 'nagios::monitor' do
  let(:facts) {{
    :osfamily       => 'Debian',
    :hostname       => 'foo',
    :ipaddress      => '1.2.3.4',
    :clientcert     => 'foo.example.com',
    :concat_basedir => '/var/lib/puppet/concat'
  }}

  let(:hiera_config) { 'spec/fixtures/hiera/hiera.yaml' }

  it do
    should contain_class('nagios::monitor')
  end

  it do
    should contain_class('rsync::server')
  end

  it do
    should contain_rsync__server__module('nagios') \
      .with_path('/etc/nagios3/conf.d/hosts')
  end

  it do
    should contain_package('nagios3')
    should contain_package('nagios-plugins')
    should contain_package('inotify-tools')
    should contain_package('screen')
  end

  it do
    should contain_service('nagios3')
    should contain_service('inotify-nagios')
  end

  it do
    should contain_file('/etc/init.d/inotify-nagios') \
      .with_ensure('present') \
      .with_mode('0755') \
      .with_owner('root') \
      .with_content(/inotify-nagios/)
  end

  it do
    should contain_user('nagios') \
      .with_ensure('present') \
      .with_managehome(true) \
      .with_home('/home/nagios') \
      .with_purge_ssh_keys(true)
  end

  it do
    should contain_file('/etc/nagios') \
      .with_ensure('directory') \
      .with_owner('nagios') \
      .with_mode('0755')
  end

  it do
    should contain_file('/etc/nagios3/conf.d') \
      .with_ensure('directory') \
      .with_owner('nagios')
  end

  it do
    should contain_file('/etc/nagios3/conf.d/hosts') \
      .with_ensure('directory') \
      .with_owner('nagios')
  end

  it 'should have a cfg_file augeas resource' do
    should contain_augeas('configure-nagios_cfg-cfg_file-settings')
  end

  describe_augeas 'configure-nagios_cfg-cfg_file-settings', :lens => 'NagiosCfg.lns', :target => 'etc/nagios3/nagios.cfg' do
    it 'should contain /etc/nagios3/some.cfg and /etc/nagios3/someother.cfg' do
      should execute.with_change
      aug_get('cfg_file[1]').should == '/etc/nagios3/some.cfg'
      aug_get('cfg_file[2]').should == '/etc/nagios3/someother.cfg'
      should execute.idempotently
    end
  end

  it 'should have a cfg_dir augeas resource' do
    should contain_augeas('configure-nagios_cfg-cfg_dir-settings')
  end

  describe_augeas 'configure-nagios_cfg-cfg_dir-settings', :lens => 'NagiosCfg.lns', :target => 'etc/nagios3/nagios.cfg' do
    it 'should contain /etc/nagios3/somedir and /etc/nagios3/someotherdir' do
      should execute.with_change
      aug_get('cfg_dir[1]').should == '/etc/nagios3/somedir'
      aug_get('cfg_dir[2]').should == '/etc/nagios3/someotherdir'
      should execute.idempotently
    end
  end

  it 'should have a custom-settings augeas resource' do
    should contain_augeas('configure-nagios_cfg-custom-settings')
  end

  describe_augeas 'configure-nagios_cfg-custom-settings', :lens => 'NagiosCfg.lns', :target => 'etc/nagios3/nagios.cfg' do
    it 'should contain /etc/nagios3/somedir and /etc/nagios3/someotherdir' do
      should execute.with_change
      aug_get('log_file').should == '"/path/to/nagios.log"'
      should execute.idempotently
    end
  end

  it do
    should contain_nagios__plugin('testplugin') \
      .with_content('moo')
  end

  it do
    should contain_nagios__eventhandler('testeventhandler') \
      .with_content('moo')
  end

  it do
    should contain_nagios_hostgroup('testhostgroup')
  end

  it do
    should contain_nagios_servicegroup('testservicegroup')
  end

  it do
    should contain_nagios_command('testcommand')
  end

  context "with manage_firewall == true" do
    let(:params) {{
      :manage_firewall => true
    }}
    it do
      should contain_firewall('200 Allow rsync access for Nagios') \
        .with_chain('INPUT') \
        .with_proto('tcp') \
        .with_dport('873') \
        .with_action('accept')
    end
  end
end
