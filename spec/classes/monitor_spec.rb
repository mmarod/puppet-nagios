require 'spec_helper'

describe 'nagios::monitor' do
  let(:facts) {{
    :osfamily       => 'Debian',
    :hostname       => 'foo',
    :ipaddress      => '1.2.3.4',
    :clientcert     => 'foo.example.com',
    :concat_basedir => '/tmp'
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
      .with_path('/etc/nagios3')
  end

  it do
    should contain_package('nagios3')
    should contain_package('nagios-plugins')
  end

  it do
    should contain_user('nagios') \
      .with_ensure('present') \
      .with_managehome(true) \
      .with_home('/home/nagios') \
      .with_purge_ssh_keys(true)
  end

  it do
    should contain_file('/etc/nagios3') \
      .with_ensure('directory') \
      .with_owner('nagios')
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
