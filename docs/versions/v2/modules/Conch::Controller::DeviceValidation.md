# NAME

Conch::Controller::DeviceValidation

# METHODS

## list\_validation\_states

Get the latest validation states for a device. Accepts the query parameter 'status',
indicating the desired status(es) (comma-separated) to search for -- one or more of:
pass, fail, error.

Response uses the ValidationStatesWithResults json schema.

## validate

Validate the device against the specified validation.

**DOES NOT STORE VALIDATION RESULTS**.

This is useful for testing and evaluating Validation Plans against a given
device.

Response uses the ValidationResults json schema.

## run\_validation\_plan

Validate the device against the specified Validation Plan.

**DOES NOT STORE VALIDATION RESULTS**.

This is useful for testing and evaluating Validation Plans against a given
device.

Response uses the ValidationResults json schema.

# LICENSING

Copyright Joyent, Inc.

This Source Code Form is subject to the terms of the Mozilla Public License,
v.2.0. If a copy of the MPL was not distributed with this file, You can obtain
one at [http://mozilla.org/MPL/2.0/](http://mozilla.org/MPL/2.0/).
