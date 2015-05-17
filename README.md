# Nagios

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

This Nagios module uses rsync and storeconfigs to manage Nagios configurations. I made this
module because the nagios_* types require you to put all of your configurations into
one file at /etc/nagios/nagios_*.cfg. This requirement makes collecting and merging a large
number of stored configurations on the monitor a painful experience.

My solution to this problem is to write the nagios configurations to nagios_*.cfg on each
node and then rsync the configurations over to the monitor server. This way the merging of
configuration files occurs on each individual server in smaller jobs.

## Setup

### What Nagios affects

This configuration requires that rsync works which means that port 873 must be open on the
monitor server. SSH keys are automatically created and distributed using store configs.

It will create a user named 'nagsync' and also generate an SSH key for this user.

### Setup requirements

#### Puppet Requirements

* Puppet-3.0.0 or later
* PuppetDB-2.0.0 or later
* Facter-2.0.0 or later
* Hiera-2.0.0 or later

Storeconfigs must be enabled on the Puppetmaster.

#### Dependencies

* puppetlabs/stdlib >=4.2.0
* puppetlabs/rsync >=0.4.0
* puppetlabs/firewall >= 1.0.0
* pdxcat/nrpe >=1.0.0

### Beginning with Nagios

This module requires a little bit of patience to get a target syncing its configs to a monitor.
The initial Puppet run will not magically make everything work, however, if you simply include
the `nagios::target` class and wait it will eventually work.

The monitor should be configured first. To do this, simply include the `nagios::monitor` class
and optionally also include the `nagios::target` class with `is_monitor` set to true if you want
the monitor server to monitor itself..

```puppet
include '::nagios::monitor'
class { '::nagios::target':
  is_monitor  => true
}
```

Run Puppet on the monitor server to get the initial configuration realized.

Once the monitor has been configured, targets can be configured.

```puppet
class { '::nagios::target':
    target_host => '192.168.10.20'
}
```

Puppet needs to run a couple
of times before configurations will actually be shared. Here is how it all goes down:

1. *Target*: The first Puppet run will configure a user named 'nagsync' and generate an SSH key for it.
    This key will be used for rsyncing configurations over to the monitor later on.
2. *Target*: The second Puppet run will export the key generated in the previous step as an
    export ssh_authorized_key resource.
3. *Monitor*: Once the key has been exported, it needs to be collected by the monitor. Run
    Puppet again on the monitor to collect the key.
4. *Target*: Finally, the configurations are ready to be transferred to the master. Run
    Puppet again and watch the configurations transfer over to the master.

You do not need to manually run these steps if you do not want to. Puppet will figure all of
this out on its own. However, if you are impatient, this is the order you should go in.

## Usage

### Target

* The Hiera key `nagios_services` creates target specific services
* The Hiera key `nagios_hosts` creates target specific hosts
* THe Hiera key `nrpe_commands` creates NRPE commands
* THe Hiera key `nrpe_plugins` creates NRPE plugins

If you plan on  monitoring your monitor, you will need to include the nagios::target
class on the monitor. Set `nagios::target::is_monitor` to true to manage those
configurations.

### Monitor

* `nagios::monitor::hostgroups` Creates hostgroups
* `nagios::monitor::servicegroups` Creates servicegroups
* `nagios::monitor::commands` Creates commands
* `nagios::monitor::plugins` Creates plugins
* `nagios::monitor::eventhandlers` Creates eventhandlers

## Reference

### Facts

#### nagios_key_exists

Whether or not the Nagios key has been generated yet.

#### nagios_key

The SSH key for the nagsync user.

### Classes

#### Public Classes

* [nagios::target](#nagios-target): The Nagios target class
* [nagios::monitor](#nagios-target): The Nagios monitor class

#### Defined Types

* [nagios::plugin](#nagios-plugin): Creates a Nagios plugin
* [nagios::eventhandler](#nagios-eventhandler): Creates a Nagios event handler

### Parameters

#### `nagios::target::target_host`

The IP or DNS of the Nagios monitor

#### `nagios::target::target_path`

The path to the conf.d server on the monitor.

Default: /etc/nagios/conf.d

#### `nagios::target::prefix`

The name of the prefix for the configuration files that will show up on the monitor.

Default: $::clientcert

#### `nagios::target::local_user`

The local user to use for rsync and Nagios config file generation.

Default: nagios

#### `nagios::target::remote_user`

The remote user to use for rsync and Nagios config file generation.

Default: nagios

#### `nagios::target::use_nrpe`

Deteremines whether or not to install and manage nrpe.

Default: true

#### `nagios::target::is_monitor`

Determines whether or not this target is also the monitor.

Default: false

### `nagios::monitor::packages`

The Nagios packages

Default: [ 'nagios3', 'nagios-plugins' ]

#### `nagios::monitor::nagios_user`

The Nagios user

Default: nagios

#### `nagios::monitor::nagios_group`

The Nagios group

Default: nagios

#### `nagios::monitor::plugin_mode`

The mode to give plugins

Default: 0755

#### `nagios::monitor::eventhandler_mode`

The mode to give eventhandlers

Default: 0755

#### `nagios::monitor::plugins`

A hash of nagios::plugin resources.

Default: {}

#### `nagios::monitor::plugin_path`

The path to the Nagios plugins

Default: /etc/nagios-plugins/config

#### `nagios::monitor::eventhandlers`

A hash of nagios::eventhandler resources.

Default: {}

#### `nagios::monitor::plugin_path`

The path to the Nagios plugins

Default: /usr/share/nagios3/plugins/eventhandlers

#### `nagios::monitor::hostgroups`

A hash of nagios_hostgroups.

Default: {}

#### `nagios::monitor::servicegroups`

A hash of nagios_servicegroups.

Default: {}

#### `nagios::monitor::commands`

A hash of nagios_commands.

Default: {}

#### `nagios::monitor::manage_firewall`

Whether or not to open port 873.

Default: false
