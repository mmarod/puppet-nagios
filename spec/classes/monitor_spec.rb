require 'spec_helper'

describe 'nagios::monitor' do
  let(:facts) {{
    :osfamily       => 'Debian',
    :kernel         => 'Linux',
  }}

  let(:hiera_config) { 'spec/fixtures/hiera/hiera.yaml' }

  it do
    should contain_class('nagios::monitor')
  end

  it do
    should contain_class('nagios::config')
  end

  it do
    should contain_package('nagios3')
    should contain_package('nagios-plugins')
    should contain_package('inotify-tools')
    should contain_package('screen')
    should contain_package('openssh-client')
    should contain_package('openssh-server')
    should contain_package('rsync')
  end

  it do
    should contain_service('nagios3') \
      .with_ensure('running')
  end

  it do
    should contain_user('nagsync') \
      .with_ensure('present') \
      .with_managehome(true) \
      .with_home('/home/nagsync') \
      .with_purge_ssh_keys(true)
  end

  it do
    should contain_user('nagios') \
      .with_ensure('present')
  end

  it do
    should contain_file('/home/nagsync/.ssh') \
      .with_ensure('directory') \
      .with_owner('nagsync') \
      .with_require('User[nagsync]')
  end

  it do
    should contain_file('/etc/nagios3/commands.cfg') \
      .with_ensure('absent') \
      .with_notify('Service[nagios3]')
  end

  it do
    should contain_file('/etc/nagios3/conf.d/contacts_nagios2.cfg') \
      .with_ensure('absent') \
      .with_notify('Service[nagios3]')
  end

  it do
    should contain_file('/etc/nagios3/conf.d/extinfo_nagios2.cfg') \
      .with_ensure('absent') \
      .with_notify('Service[nagios3]')
  end

  it do
    should contain_file('/etc/nagios3/conf.d/generic-host_nagios2.cfg') \
      .with_ensure('absent') \
      .with_notify('Service[nagios3]')
  end

  it do
    should contain_file('/etc/nagios3/conf.d/generic-service_nagios2.cfg') \
      .with_ensure('absent') \
      .with_notify('Service[nagios3]')
  end

  it do
    should contain_file('/etc/nagios3/conf.d/hostgroups_nagios2.cfg') \
      .with_ensure('absent') \
      .with_notify('Service[nagios3]')
  end

  it do
    should contain_file('/etc/nagios3/conf.d/localhost_nagios2.cfg') \
      .with_ensure('absent') \
      .with_notify('Service[nagios3]')
  end

  it do
    should contain_file('/etc/nagios3/conf.d/services_nagios2.cfg') \
      .with_ensure('absent') \
      .with_notify('Service[nagios3]')
  end

  it do
    should contain_file('/etc/nagios3/conf.d/timeperiods_nagios2.cfg') \
      .with_ensure('absent') \
      .with_notify('Service[nagios3]')
  end

  it do
    should contain_file('/etc/init.d/inotify-nagios') \
      .with_ensure('present') \
      .with_mode('0755') \
      .with_owner('root') \
      .with_source('puppet:///modules/nagios/inotify-nagios.DEBIAN.erb')
  end

  it do
    should contain_file('/usr/sbin/inotify-nagios') \
      .with_ensure('present') \
      .with_mode('0755') \
      .with_owner('root') \
      .with_content(/\/var\/log\/nagios3\/inotify.log/) \
      .with_content(/\/etc\/nagios3\/conf\.d\/hosts/)
  end

  context "with osfamily == 'Debian'" do
    it do
      should contain_file('/etc/default/inotify-nagios') \
        .with_ensure('present') \
        .with_mode('0644') \
        .with_content('VERBOSE=yes') \
        .with_before('Service[inotify-nagios]')
    end
  end

  context "with osfamily == 'RedHat'" do
    let(:facts) {{
      :osfamily       => 'RedHat',
      :kernel         => 'Linux',
    }}

    it do
      should_not contain_file('/etc/default/inotify-nagios')
    end
  end

  it do
    should contain_service('inotify-nagios') \
      .with_require(/File\[\/etc\/init\.d\/inotify-nagios\]/) \
      .with_require(/File\[\/usr\/sbin\/inotify-nagios\]/)
  end

  it do
    should contain_file('/etc/nagios') \
      .with_ensure('directory') \
      .with_owner('nagios') \
      .with_mode('0755') \
      .with_require('User[nagios]')
  end

  it do
    should contain_file('/etc/nagios3') \
      .with_ensure('directory') \
      .with_owner('nagios') \
      .with_group('nagsync') \
      .with_mode('0750') \
      .with_require(/Package\[nagios3\]/) \
      .with_before('File[/etc/nagios3/conf.d/hosts]')
  end

  it do
    should contain_file('/etc/nagios3/conf.d') \
      .with_ensure('directory') \
      .with_owner('nagios') \
      .with_group('nagsync') \
      .with_mode('0750') \
      .with_require(/Package\[nagios3\]/) \
      .with_before('File[/etc/nagios3/conf.d/hosts]')
  end

  it do
    should contain_file('/etc/nagios3/conf.d/hosts') \
      .with_ensure('directory') \
      .with_owner('nagsync') \
      .with_group('nagios') \
      .with_mode('2750')
  end

  it do
    should contain_concat_file('/etc/nagios3/nagios-targets.txt') \
      .with_tag('nagios-targets') \
      .with_ensure_newline(true)
  end

  it do
    should contain_exec('remove-unmanaged-hosts') \
      .with_command("/usr/bin/find /etc/nagios3/conf.d/hosts ! -path /etc/nagios3/conf.d/hosts -exec basename {} \\; | /bin/grep -Fxvf /etc/nagios3/nagios-targets.txt | awk '{print \"/etc/nagios3/conf.d/hosts/\" \$1}' | /usr/bin/xargs rm") \
      .with_onlyif("/usr/bin/find /etc/nagios3/conf.d/hosts ! -path /etc/nagios3/conf.d/hosts -exec basename {} \\; | /bin/grep -Fxvf /etc/nagios3/nagios-targets.txt") \
      .with_require('Concat_file[/etc/nagios3/nagios-targets.txt]')
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
    should contain_file('/etc/nagios/nagios_command.cfg') \
      .with_ensure('present') \
      .with_owner('nagios') \
      .with_group('nagios') \
      .with_mode('0644') \
      .with_notify('Service[nagios3]') \
      .with_before(/Concat\[\/etc\/nagios3\/conf.d\/hosts\/foo_example_com.cfg\]/) \
      .with_before(/Concat\[\/etc\/nagios3\/conf.d\/commands.cfg\]/) \
      .with_before(/Concat\[\/etc\/nagios3\/conf.d\/contacts.cfg\]/) \
      .with_before(/Concat\[\/etc\/nagios3\/conf.d\/hostgroups.cfg\]/) \
      .with_before(/Concat\[\/etc\/nagios3\/conf.d\/servicegroups.cfg\]/) \
      .with_before(/Concat\[\/etc\/nagios3\/conf.d\/contactgroups.cfg\]/) \
      .with_before(/Concat\[\/etc\/nagios3\/conf.d\/timeperiods.cfg\]/)
  end

  it do
    should contain_file('/etc/nagios/nagios_contact.cfg') \
      .with_ensure('present') \
      .with_owner('nagios') \
      .with_group('nagios') \
      .with_mode('0644') \
      .with_notify('Service[nagios3]') \
      .with_before(/Concat\[\/etc\/nagios3\/conf.d\/hosts\/foo_example_com.cfg\]/) \
      .with_before(/Concat\[\/etc\/nagios3\/conf.d\/commands.cfg\]/) \
      .with_before(/Concat\[\/etc\/nagios3\/conf.d\/contacts.cfg\]/) \
      .with_before(/Concat\[\/etc\/nagios3\/conf.d\/hostgroups.cfg\]/) \
      .with_before(/Concat\[\/etc\/nagios3\/conf.d\/servicegroups.cfg\]/) \
      .with_before(/Concat\[\/etc\/nagios3\/conf.d\/contactgroups.cfg\]/) \
      .with_before(/Concat\[\/etc\/nagios3\/conf.d\/timeperiods.cfg\]/)
  end

  it do
    should contain_file('/etc/nagios/nagios_contactgroup.cfg') \
      .with_ensure('present') \
      .with_owner('nagios') \
      .with_group('nagios') \
      .with_mode('0644') \
      .with_notify('Service[nagios3]') \
      .with_before(/Concat\[\/etc\/nagios3\/conf.d\/hosts\/foo_example_com.cfg\]/) \
      .with_before(/Concat\[\/etc\/nagios3\/conf.d\/commands.cfg\]/) \
      .with_before(/Concat\[\/etc\/nagios3\/conf.d\/contacts.cfg\]/) \
      .with_before(/Concat\[\/etc\/nagios3\/conf.d\/hostgroups.cfg\]/) \
      .with_before(/Concat\[\/etc\/nagios3\/conf.d\/servicegroups.cfg\]/) \
      .with_before(/Concat\[\/etc\/nagios3\/conf.d\/contactgroups.cfg\]/) \
      .with_before(/Concat\[\/etc\/nagios3\/conf.d\/timeperiods.cfg\]/)
  end

  it do
    should contain_file('/etc/nagios/nagios_hostgroup.cfg') \
      .with_ensure('present') \
      .with_owner('nagios') \
      .with_group('nagios') \
      .with_mode('0644') \
      .with_notify('Service[nagios3]') \
      .with_before(/Concat\[\/etc\/nagios3\/conf.d\/hosts\/foo_example_com.cfg\]/) \
      .with_before(/Concat\[\/etc\/nagios3\/conf.d\/commands.cfg\]/) \
      .with_before(/Concat\[\/etc\/nagios3\/conf.d\/contacts.cfg\]/) \
      .with_before(/Concat\[\/etc\/nagios3\/conf.d\/hostgroups.cfg\]/) \
      .with_before(/Concat\[\/etc\/nagios3\/conf.d\/servicegroups.cfg\]/) \
      .with_before(/Concat\[\/etc\/nagios3\/conf.d\/contactgroups.cfg\]/) \
      .with_before(/Concat\[\/etc\/nagios3\/conf.d\/timeperiods.cfg\]/)
  end

  it do
    should contain_file('/etc/nagios/nagios_host.cfg') \
      .with_ensure('present') \
      .with_owner('nagios') \
      .with_group('nagios') \
      .with_mode('0644') \
      .with_notify('Service[nagios3]') \
      .with_before(/Concat\[\/etc\/nagios3\/conf.d\/hosts\/foo_example_com.cfg\]/) \
      .with_before(/Concat\[\/etc\/nagios3\/conf.d\/commands.cfg\]/) \
      .with_before(/Concat\[\/etc\/nagios3\/conf.d\/contacts.cfg\]/) \
      .with_before(/Concat\[\/etc\/nagios3\/conf.d\/hostgroups.cfg\]/) \
      .with_before(/Concat\[\/etc\/nagios3\/conf.d\/servicegroups.cfg\]/) \
      .with_before(/Concat\[\/etc\/nagios3\/conf.d\/contactgroups.cfg\]/) \
      .with_before(/Concat\[\/etc\/nagios3\/conf.d\/timeperiods.cfg\]/)
  end

  it do
    should contain_file('/etc/nagios/nagios_servicegroup.cfg') \
      .with_ensure('present') \
      .with_owner('nagios') \
      .with_group('nagios') \
      .with_mode('0644') \
      .with_notify('Service[nagios3]') \
      .with_before(/Concat\[\/etc\/nagios3\/conf.d\/hosts\/foo_example_com.cfg\]/) \
      .with_before(/Concat\[\/etc\/nagios3\/conf.d\/commands.cfg\]/) \
      .with_before(/Concat\[\/etc\/nagios3\/conf.d\/contacts.cfg\]/) \
      .with_before(/Concat\[\/etc\/nagios3\/conf.d\/hostgroups.cfg\]/) \
      .with_before(/Concat\[\/etc\/nagios3\/conf.d\/servicegroups.cfg\]/) \
      .with_before(/Concat\[\/etc\/nagios3\/conf.d\/contactgroups.cfg\]/) \
      .with_before(/Concat\[\/etc\/nagios3\/conf.d\/timeperiods.cfg\]/)
  end

  it do
    should contain_file('/etc/nagios/nagios_service.cfg') \
      .with_ensure('present') \
      .with_owner('nagios') \
      .with_group('nagios') \
      .with_mode('0644') \
      .with_notify('Service[nagios3]') \
      .with_before(/Concat\[\/etc\/nagios3\/conf.d\/hosts\/foo_example_com.cfg\]/) \
      .with_before(/Concat\[\/etc\/nagios3\/conf.d\/commands.cfg\]/) \
      .with_before(/Concat\[\/etc\/nagios3\/conf.d\/contacts.cfg\]/) \
      .with_before(/Concat\[\/etc\/nagios3\/conf.d\/hostgroups.cfg\]/) \
      .with_before(/Concat\[\/etc\/nagios3\/conf.d\/servicegroups.cfg\]/) \
      .with_before(/Concat\[\/etc\/nagios3\/conf.d\/contactgroups.cfg\]/) \
      .with_before(/Concat\[\/etc\/nagios3\/conf.d\/timeperiods.cfg\]/)
  end   

  it do
    should contain_file('/etc/nagios/nagios_timeperiod.cfg') \
      .with_ensure('present') \
      .with_owner('nagios') \
      .with_group('nagios') \
      .with_mode('0644') \
      .with_notify('Service[nagios3]') \
      .with_before(/Concat\[\/etc\/nagios3\/conf.d\/hosts\/foo_example_com.cfg\]/) \
      .with_before(/Concat\[\/etc\/nagios3\/conf.d\/commands.cfg\]/) \
      .with_before(/Concat\[\/etc\/nagios3\/conf.d\/contacts.cfg\]/) \
      .with_before(/Concat\[\/etc\/nagios3\/conf.d\/hostgroups.cfg\]/) \
      .with_before(/Concat\[\/etc\/nagios3\/conf.d\/servicegroups.cfg\]/) \
      .with_before(/Concat\[\/etc\/nagios3\/conf.d\/contactgroups.cfg\]/) \
      .with_before(/Concat\[\/etc\/nagios3\/conf.d\/timeperiods.cfg\]/)
  end   

  context "with hiera yaml containing default keys" do
    it do
      should contain_nagios_contactgroup('admins') \
        .with_alias('overridden')
    end

    it do
      should contain_nagios_timeperiod('24x7') \
        .with_alias('overridden')
    end

    it do
      should contain_nagios_timeperiod('workhours') \
        .with_alias('overridden')
    end

    it do
      should contain_nagios_timeperiod('nonworkhours') \
        .with_alias('overridden')
    end

    it do
      should contain_nagios_timeperiod('never') \
        .with_alias('overridden')
    end

    it do
      should contain_nagios_host('generic-host') \
        .with_check_command('overridden')
    end

    it do
      should contain_nagios_service('generic-service') \
        .with_contact_groups('overridden')
    end

    it do
      should contain_nagios_command('notify-host-by-email') \
        .with_command_line('overridden')
    end

    it do
      should contain_nagios_command('notify-service-by-email') \
        .with_command_line('overridden')
    end

    it do
      should contain_nagios_command('process-host-perfdata') \
        .with_command_line('overridden')
    end

    it do
      should contain_nagios_command('process-service-perfdata') \
        .with_command_line('overridden')
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
      .with_ensure('present') \
      .with_check_command('/usr/bin/testcommand') \
      .with_use('generic-service') \
      .with_host_name('foo.example.com') \
      .with_service_description('test command') \
      .with_notification_period('24x7')
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

  it do
    should contain_nagios_contact('testcontact')
  end

  it do
    should contain_nagios_contactgroup('testcontactgroup')
  end

  it do
    should contain_nagios_timeperiod('testtimeperiod')
  end

  it do
    should contain_concat('/etc/nagios3/conf.d/hosts/foo_example_com.cfg') \
      .with_owner('nagios') \
      .with_mode('0644')
  end

  it do
    should contain_concat__fragment('nagios-host-config') \
      .with_target('/etc/nagios3/conf.d/hosts/foo_example_com.cfg') \
      .with_source('/etc/nagios/nagios_host.cfg') \
      .with_order('01')
  end

  it do
    should contain_concat__fragment('nagios-service-config') \
      .with_target('/etc/nagios3/conf.d/hosts/foo_example_com.cfg') \
      .with_source('/etc/nagios/nagios_service.cfg') \
      .with_order('02')
  end

  it do
    should contain_concat('/etc/nagios3/conf.d/hostgroups.cfg') \
      .with_owner('nagios') \
      .with_mode('0644')
  end

  it do
    should contain_concat__fragment('nagios-hostgroup-config') \
      .with_target('/etc/nagios3/conf.d/hostgroups.cfg') \
      .with_source('/etc/nagios/nagios_hostgroup.cfg') \
      .with_order('01')
  end

  it do
    should contain_concat('/etc/nagios3/conf.d/servicegroups.cfg') \
      .with_owner('nagios') \
      .with_mode('0644')
  end

  it do
    should contain_concat__fragment('nagios-servicegroup-config') \
      .with_target('/etc/nagios3/conf.d/servicegroups.cfg') \
      .with_source('/etc/nagios/nagios_servicegroup.cfg') \
      .with_order('01')
  end

  it do
    should contain_concat('/etc/nagios3/conf.d/commands.cfg') \
      .with_owner('nagios') \
      .with_mode('0644')
  end

  it do
    should contain_concat__fragment('nagios-command-config') \
      .with_target('/etc/nagios3/conf.d/commands.cfg') \
      .with_source('/etc/nagios/nagios_command.cfg') \
      .with_order('01')
  end

  it do
    should contain_concat('/etc/nagios3/conf.d/contacts.cfg') \
      .with_owner('nagios') \
      .with_mode('0644')
  end

  it do
    should contain_concat__fragment('nagios-contact-config') \
      .with_target('/etc/nagios3/conf.d/contacts.cfg') \
      .with_source('/etc/nagios/nagios_contact.cfg') \
      .with_order('01')
  end

  it do
    should contain_concat('/etc/nagios3/conf.d/contactgroups.cfg') \
      .with_owner('nagios') \
      .with_mode('0644')
  end

  it do
    should contain_concat__fragment('nagios-contactgroup-config') \
      .with_target('/etc/nagios3/conf.d/contactgroups.cfg') \
      .with_source('/etc/nagios/nagios_contactgroup.cfg') \
      .with_order('01')
  end

  it do
    should contain_concat('/etc/nagios3/conf.d/timeperiods.cfg') \
      .with_owner('nagios') \
      .with_mode('0644')
  end

  it do
    should contain_concat__fragment('nagios-timeperiod-config') \
      .with_target('/etc/nagios3/conf.d/timeperiods.cfg') \
      .with_source('/etc/nagios/nagios_timeperiod.cfg') \
      .with_order('01')
  end

  describe "nag_to_aug()" do
    let(:scope) { PuppetlabsSpec::PuppetInternals.scope }
    it "should return a hash containing 'changes' and 'onlyif' keys for cfg_file" do
      scope.function_nag_to_aug([['cfg1', 'cfg2'], 'cfg_file', '/etc/nagios3/nagios.cfg']).should == { 'changes' => [ 'rm cfg_file', "ins cfg_file before /files/etc/nagios3/nagios.cfg/#comment[.='LOG FILE']", 'set cfg_file[1] cfg1', 'ins cfg_file after /files/etc/nagios3/nagios.cfg/cfg_file[last()]', 'set cfg_file[last()] cfg2' ], 'onlyif' => "values cfg_file != ['cfg1', 'cfg2']" }
    end
    it "should return a hash containing 'changes' and 'onlyif' keys for cfg_dir" do
      scope.function_nag_to_aug([['cfg1', 'cfg2'], 'cfg_dir', '/etc/nagios3/nagios.cfg']).should == { 'changes' => [ 'rm cfg_dir', "ins cfg_dir before /files/etc/nagios3/nagios.cfg/#comment[.='LOG FILE']", 'set cfg_dir[1] cfg1', 'ins cfg_dir after /files/etc/nagios3/nagios.cfg/cfg_dir[last()]', 'set cfg_dir[last()] cfg2' ], 'onlyif' => "values cfg_dir != ['cfg1', 'cfg2']" }
    end
    it "should return a hash containing 'changes' and 'onlyif' keys when an empty value set is supplied to cfg_file" do
      scope.function_nag_to_aug([[], 'cfg_file', '/etc/nagios3/nagios.cfg']).should == { 'changes' => [ 'rm cfg_file' ], 'onlyif' => "match cfg_file size > 0" }
    end
    it "should return a hash containing 'changes' and 'onlyif' keys with an empty value set is supplied to cfg_dir" do
      scope.function_nag_to_aug([[], 'cfg_dir', '/etc/nagios3/nagios.cfg']).should == { 'changes' => [ 'rm cfg_dir' ], 'onlyif' => "match cfg_dir size > 0" }
    end
  end

end
