require 'spec_helper'

describe 'nagios::plugin' do
  let(:title) { 'myplugin' }

  context 'with :content set' do
    let(:params) {{
      :content      => 'moo',
      :plugin_path  => '/usr/lib/nagios/plugins'
    }}

    it do
      should contain_file('/usr/lib/nagios/plugins/myplugin') \
        .with_ensure('present') \
        .with_content('moo') \
        .with_owner('nagios') \
        .with_group('nagios') \
        .with_mode('0755')
    end
  end

  context 'with :source set' do
    let(:params) {{
      :source       => 'moo',
      :plugin_path  => '/usr/lib/nagios/plugins'
    }}

    it do
      should contain_file('/usr/lib/nagios/plugins/myplugin') \
        .with_ensure('present') \
        .with_source('moo') \
        .with_owner('nagios') \
        .with_group('nagios') \
        .with_mode('0755')
    end
  end
end
