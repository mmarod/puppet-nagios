source 'https://rubygems.org'

group :rake, :test do
  gem 'puppetlabs_spec_helper', '>=0.8.2', :require => false
end

group :rake do
  gem 'rspec-puppet',       :git => 'git://github.com/joshcooper/rspec-puppet.git', :branch => 'dont-set-libdir'
  gem 'rake',               '>=0.9.2.2'
  gem 'puppet-lint',        '>=1.0.1'
  gem 'metadata-json-lint', '>=0.0.6'
end

if puppetversion = ENV['PUPPET_GEM_VERSION']
  gem 'puppet', puppetversion, :require => false
else
  gem 'puppet', :require => false
end

