# Conch::Controller::Validation

## SOURCE

[https://github.com/joyent/conch/blob/master/lib/Conch/Controller/Validation.pm](https://github.com/joyent/conch/blob/master/lib/Conch/Controller/Validation.pm)

Controller for managing Validations, **NOT** executing them.

## METHODS

### get\_all

List all Validations.

Response uses the Validations json schema (including deactivated ones).

### find\_validation

Chainable action that uses the `validation_id_or_name` value provided in the stash (usually
via the request URL) to look up a validation, and stashes the query to get to it in
`validation_rs`.

### get

Get the Validation specified by uuid or name.

Response uses the Validation json schema.

## LICENSING

Copyright Joyent, Inc.

This Source Code Form is subject to the terms of the Mozilla Public License,
v.2.0. If a copy of the MPL was not distributed with this file, You can obtain
one at [https://www.mozilla.org/en-US/MPL/2.0/](https://www.mozilla.org/en-US/MPL/2.0/).
