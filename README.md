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

This configuration requires that rsync works which means that port 187 must be open on the
monitor server. SSH keys are automatically created and distributed using store configs.

### Setup requirements

* Puppet-3.0.0 or later
* Storeconfigs enabled

### Beginning with Nagios

#### Target

````puppet
include '::nagios::target'
```

````yaml
nagios::target::target_server: 192.168.10.100
```

#### Monitor

```
include '::nagios::server'
```

## Usage

### Target

* `nagios_services` Creates target specific services
* `nagios_hosts` Creates target specific hosts

### Monitor

* `nagios::monitor::hostgroups` Creates hostgroups
* `nagios::monitor::servicegroups` Creates servicegroups
* `nagios::monitor::commands` Creates commands
* `nagios::monitor::plugins` Creates plugins
* `nagios::monitor::eventhandlers` Creates eventhandlers

## Reference

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

#### `nagios::target::conf_name`

The name of the configuration files that will show up on the monitor.

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

### `nagios::monitor::packages`

The Nagios packages

Default: [ 'nagios3', 'nagios-plugins' ]

### `nagios::monitor::nagios_user`

The Nagios user

Default: nagios

### `nagios::monitor::nagios_group`

The Nagios group

Default: nagios

### `nagios::monitor::plugin_mode`

The mode to give plugins

Default: 0755

### `nagios::monitor::eventhandler_mode`

The mode to give eventhandlers

Default: 0755

### `nagios::monitor::plugins`

A hash of nagios::plugin resources.

Default: {}

### `nagios::monitor::plugin_path`

The path to the Nagios plugins

Default: /etc/nagios-plugins/config

### `nagios::monitor::eventhandlers`

A hash of nagios::eventhandler resources.

Default: {}

### `nagios::monitor::plugin_path`

The path to the Nagios plugins

Default: /usr/share/nagios3/plugins/eventhandlers

### `nagios::monitor::hostgroups`

A hash of nagios_hostgroups.

Default: {}

### `nagios::monitor::servicegroups`

A hash of nagios_servicegroups.

Default: {}

### `nagios::monitor::commands`

A hash of nagios_commands.

Default: {}
