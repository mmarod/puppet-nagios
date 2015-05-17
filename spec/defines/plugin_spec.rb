require 'spec_helper'

describe 'nagios::plugin' do
  let(:title) { 'myplugin' }

  context 'with :content set' do
    let(:params) {{
      :content    => 'moo',
    }}

    it do
      should contain_file('/etc/nagios-plugins/config/myplugin') \
        .with_ensure('present') \
        .with_content('moo') \
        .with_owner('nagios') \
        .with_group('nagios') \
        .with_mode('0755')
    end
  end

  context 'with :source set' do
    let(:params) {{
      :source    => 'moo',
    }}

    it do
      should contain_file('/etc/nagios-plugins/config/myplugin') \
        .with_ensure('present') \
        .with_source('moo') \
        .with_owner('nagios') \
        .with_group('nagios') \
        .with_mode('0755')
    end
  end
end
