# NAME

Conch::Controller::Build

# METHODS

## list

If the user is a system admin, retrieve a list of all builds in the database; otherwise,
limits the list to those build of which the user is a member.

Response uses the Builds json schema.

## create

Creates a build.

Requires the user to be a system admin.

## find\_build

Chainable action that validates the `build_id` or `build_name` provided in the
path, and stashes the query to get to it in `build_rs`.

If `require_role` is provided, it is used as the minimum required role for the user to
continue; otherwise the user must be a system admin.

## get

Get the details of a single build.
Requires the 'read-only' role on the build.

Response uses the Build json schema.

## update

Modifies a build attribute: one or more of description, started, completed.
Requires the 'admin' role on the build.

## list\_users

Get a list of user members of the current build.
Requires the 'admin' role on the build.

Response uses the BuildUsers json schema.

## add\_user

Adds a user to the current build, or upgrades an existing role entry to access the build.
Requires the 'admin' role on the build.

Optionally takes a query parameter `send_mail` (defaulting to true), to send an email
to the user and to all build admins.

This endpoint is nearly identical to ["add\_user" in Conch::Controller::Organization](../modules/Conch::Controller::Organization#add_user).

## remove\_user

Removes the indicated user from the build.
Requires the 'admin' role on the build.

Optionally takes a query parameter `send_mail` (defaulting to true), to send an email
to the user and to all build admins.

This endpoint is nearly identical to ["remove\_user" in Conch::Controller::Organization](../modules/Conch::Controller::Organization#remove_user).

## list\_organizations

Get a list of organization members of the current build.
Requires the 'admin' role on the build.

Response uses the BuildOrganizations json schema.

## add\_organization

Adds a organization to the current build, or upgrades an existing role entry to access the
build.
Requires the 'admin' role on the build.

Optionally takes a query parameter `send_mail` (defaulting to true), to send an email
to all organization members and all build admins.

## remove\_organization

Removes the indicated organization from the build.
Requires the 'admin' role on the build.

Optionally takes a query parameter `send_mail` (defaulting to true), to send an email
to all organization members and to all build admins.

## get\_devices

Get the devices in this build.  (Includes devices located in rack(s) in this build.)
Requires the 'read-only' role on the build.

Response uses the Devices json schema.

## add\_device

Adds the specified device to the build (as long as it isn't in another build, or located in a
rack in another build).

Requires the 'read/write' role on the build.

## remove\_device

Removes the specified device from the build (if it is \*directly\* in the build, not via a rack).

Requires the 'read/write' role on the build.

## get\_racks

Get the racks in this build.
Requires the 'read-only' role on the build.

Response uses the Racks json schema.

## add\_rack

Adds the specified rack to the build (as long as it isn't in another build, or contains devices
located in another build).

Requires the 'read/write' role on the build.

## remove\_rack

Requires the 'read/write' role on the build.

# LICENSING

Copyright Joyent, Inc.

This Source Code Form is subject to the terms of the Mozilla Public License,
v.2.0. If a copy of the MPL was not distributed with this file, You can obtain
one at [http://mozilla.org/MPL/2.0/](http://mozilla.org/MPL/2.0/).