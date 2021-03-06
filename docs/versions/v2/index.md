# Introduction

The Conch ecosystem is designed to make the deployment of new server hardware
easier, specifically targetting equipment to be used in the Joyent
SmartDatacenter product line.

Conch has two major backend systems.

First, edge software boots new hardware, upgrades firmware, performs burn-in
testing, and gathers the general state of the hardware. (This software is
currently closed source.)

Second, this edge data is fed into the Conch API (this codebase) where the data
is processed, validated, stored, and reported upon.

# The Ecosystem

* [The Web UI](https://github.com/joyent/conch-ui)
* [The CLI Tooling](https://github.com/joyent/conch-shell)

# Development

Our development process is documented over [here](development.html)

# Routes / URLs

The majority of our endpoints consume and respond with JSON documents that
conform to a set of JSON schema. These schema can be found in the
[json-schema](https://github.com/joyent/conch/tree/master/json-schema)
directory in the main repository.

* [Conch::Route](modules/Conch::Route)
  * `/ping`
  * `/version`
  * `/login`
  * `/logout`
  * `/refresh_token`
  * `/me`
  * `/schema`

* [Conch::Route::Datacenter](modules/Conch::Route::Datacenter)
  * `/dc`
  * `/room`
  * `/rack_role`
  * `/layout`

* [Conch::Route::Device](modules/Conch::Route::Device)
  * `/device`

* [Conch::Route::DeviceReport](modules/Conch::Route::DeviceReport)
  * `/device_report`

* [Conch::Route::HardwareProduct](modules/Conch::Route::HardwareProduct)
  * `/hardware_product`

* [Conch::Route::HardwareVendor](modules/Conch::Route::HardwareVendor)
  * `/hardware_vendor`

* [Conch::Route::Relay](modules/Conch::Route::Relay)
  * `/relay`

* [Conch::Route::User](modules/Conch::Route::User)
  * `/user`

* [Conch:Route::Validation](modules/Conch::Route::Validation)
  * `/validation`
  * `/validation_plan`
  * `/validation_state`

* [Conch::Route::Workspace](modules/Conch::Route::Workspace)
  * `/workspace`

# Modules

Individual module documentation can be found [here](modules).

Script documentation can be found [here](scripts).

JSON Schema defining request and response payloads can be found [here](json-schema).

# Copyright / License

Copyright Joyent Inc

This Source Code Form is subject to the terms of the Mozilla Public
License, v. 2.0. If a copy of the MPL was not distributed with this
file, you can obtain one at <http://mozilla.org/MPL/2.0/>
