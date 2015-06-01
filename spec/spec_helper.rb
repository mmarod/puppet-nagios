require 'rspec-puppet-augeas'
require 'puppetlabs_spec_helper/module_spec_helper'
require 'puppetlabs_spec_helper/puppetlabs_spec/puppet_internals'
require 'hiera'

fixture_path = File.expand_path(File.join(__FILE__, '..', 'fixtures'))

RSpec.configure do |c|
  c.augeas_fixtures = File.join(fixture_path, 'augeas')
  c.module_path = File.join(fixture_path, 'modules')
  c.manifest_dir = File.join(fixture_path, 'manifests')
  c.before :each do
    HieraPuppet.instance_variable_set('@hiera', nil) if defined? HieraPuppet
  end
end
