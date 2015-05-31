# Nagios

[![Build Status](https://travis-ci.org/mmarod/puppet-nagios.svg?branch=master)](https://travis-ci.org/mmarod/puppet-nagios)

#### Table of Contents

1. [Overview](#overview)
2. [Module Description - What the module does and why it is useful](#module-description)
3. [Setup - The basics of getting started with Nagios](#setup)
    * [What Nagios affects](#what-Nagios-affects)
    * [Setup requirements](#setup-requirements)
    * [Beginning with Nagios](#beginning-with-Nagios)
4. [Usage - Configuration options and additional functionality](#usage)
5. [Reference - An under-the-hood peek at what the module is doing and how](#reference)
6. [Limitations - OS compatibility, etc.](#limitations)
7. [Development - Guide for contributing to the module](#development)

## Overview

The Nagios module installs and configures the Nagios service.

## Module Description

This Nagios module uses rsync and/or storeconfigs to manage Nagios configurations.
I made this module because the nagios_[type] types require you to put all of
your configurations into large files at /etc/nagios/nagios_[type].cfg. This
requirement makes collecting and merging a large number of stored configurations
on the monitor a painful experience.

My solution to this problem is to write the nagios configurations to
nagios_[type].cfg on each node and then rsync the configurations over to the
monitor server. This way the merging of configuration files occurs on each
individual server in smaller jobs.

## Setup

### What Nagios affects

This configuration requires that rsync works which means that port 873 must be
open on the monitor server. SSH keys are automatically created and distributed
using store configs.

It will create a user named 'nagsync' and also generate an SSH key for this
user.

### Setup requirements

#### Puppet Requirements

* Puppet-3.7.6 or later
* PuppetDB-2.0.0 or later
* Facter-2.0.0 or later
* Hiera-2.0.0 or later

Storeconfigs must be enabled on the Puppetmaster.

#### Dependencies

* puppetlabs/stdlib >=4.2.0
* puppetlabs/rsync >=0.4.0
* puppetlabs/firewall >= 1.0.0
* pdxcat/nrpe >=1.0.0
* stahnma/epel >=1.0.2

### Beginning with Nagios

This module requires a little bit of patience to get a target syncing its
configs to a monitor.  The initial Puppet run will not magically make everything
work, however, if you simply include the `nagios::target` class and wait it will
eventually work.

The monitor should be configured first. To do this, simply include the
`nagios::monitor` class.

```puppet
include '::nagios::monitor'
```

Run Puppet on the monitor server to get the initial configuration realized.

Once the monitor has been configured, targets can be configured.

```puppet
class { '::nagios::target':
    target_host => 'nagios.example.com'
}
```

Puppet needs to run a couple of times before configurations will actually be
shared. Here is how it all goes down:

1. *Target*: The first Puppet run will configure a user named 'nagsync' and
generate an SSH key for it.  This key will be used for rsyncing configurations
over to the monitor later on.
2. *Target*: The second Puppet run will export the key generated in the
previous step as an export ssh_authorized_key resource.
3. *Monitor*: Once the key has been exported, it needs to be collected by the
monitor. Run Puppet again on the monitor to collect the key.
4. *Target*: Finally, the configurations are ready to be transferred to the
master. Run Puppet again and watch the configurations transfer over to the
master.

You do not need to manually run these steps if you do not want to. Puppet will
figure all of this out on its own. However, if you are impatient, this is the
order you should go in.

## Usage

### Target

* `nagios_hosts` Creates `nagios_host` resources
* `nagios_services` Creates `nagios_service` resources
* `nrpe_commands` Creates `nrpe::command` resources
* `nrpe_plugins` Creates `nrpe::plugin` resources

```yaml
nagios_hosts:
  '%{::clientcert}':
    ensure: present
    alias: '%{::hostname}'
    address: '%{::ipaddress}'
    use: generic-host
    hostgroups: testhostgroup
    icon_image: base/icon.png
    notification_period: 24x7
nagios_services:
  someservice:
    check_command: /usr/bin/testcommand
    use: generic-service
    host_name: '%{::clientcert}'
    service_description: 'test command'
    notification_period: 24x7
```

### Monitor

* `nagios_commands` Creates `nagios_command` resources
* `nagios_contactgroups` Creates `nagios_contactgroup` resources
* `nagios_contacts` Creates `nagios_contact` resources
* `nagios_eventhandlers` Creates `nagios::eventhandlers` resources
* `nagios_hostgroups` Creates `nagios_hostgroup` resources
* `nagios_hosts` Creates `nagios_host` resources
* `nagios_plugins` Creates `nagios::plugin` resources
* `nagios_servicegroups` Creates servicegroups
* `nagios_services` Creates `nagios_service` resources
* `nagios_timeperiods` Creates `nagios_timeperiod` resources

```yaml
nagios_plugins:
  myplugin:
    content: moo
nagios_eventhandlers:
  myeventhandler:
    content: moo
nagios_hostgroups:
  myhostgroup: {}
nagios_servicegroups:
  myservicegroup: {}
nagios_commands:
  mycommand:
    command_line: /usr/bin/whoami
```

## Reference

### Facts

#### `nagios_key_exists`

Whether or not the Nagios key has been generated yet.

#### `nagios_key`

The SSH key for the nagsync user.

#### `nagios_config`

The Nagios configuration. This is necessary for when storeconfigs are used as
the `xfer_method`.

### Classes

#### Public Classes

* [nagios::target](#nagios-target): The Nagios target class
* [nagios::monitor](#nagios-target): The Nagios monitor class

#### Private Classes

* [nagios::params](#nagios-params): The Nagios params class

#### Defined Types

* [nagios::plugin](#nagios-plugin): Creates a Nagios plugin
* [nagios::eventhandler](#nagios-eventhandler): Creates a Nagios event handler

### Parameters

#### `nagios::target::target_host`

The hostname, fqdn, or ip address of the Nagios monitor. This needs to
be exactly the same as the value of monitor_host on the monitor for ssh
key exchanging to work.

#### `nagios::target::target_path`

The path to the conf.d server on the monitor.

Default: /etc/nagios/conf.d

#### `nagios::target::local_user`

The local user to use for rsync and Nagios config file generation.

Default: nagios

#### `nagios::target::remote_user`

The remote user to use for rsync and Nagios config file generation.

Default: nagios

#### `nagios::target::use_nrpe`

Deteremines whether or not to install and manage nrpe.

Default: true

#### `nagios::monitor::monitor_host`

The hostname, fqdn, or ip address of the Nagios monitor. This needs to
be exactly the same as the value of target_host on the targets for ssh
key exchanging to work.

Default: $::ipaddress

#### `nagios::monitor::nagios_user`

The Nagios user

Default: nagios

#### `nagios::monitor::nagios_group`

The Nagios group

Default: nagios

#### `nagios::monitor::cfg_files`

`cfg_file` keys to include in nagios.cfg

Default: [ '/etc/nagios3/commands.cfg' ]

#### `nagios::monitor::cfg_dirs`

`cfg_dir` keys to include in nagios.cfg

Default: [ '/etc/nagios-plugins/config', '/etc/nagios3/conf.d' ]

#### `nagios::monitor::config`

A hash of key/value pairs to configure in nagios.cfg.

Default: {}

#### `nagios::monitor::manage_firewall`

Whether or not to open port 873.

Default: false
