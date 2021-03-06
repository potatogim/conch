# Conch::Controller::WorkspaceRack

## SOURCE

[https://github.com/joyent/conch/blob/master/lib/Conch/Controller/WorkspaceRack.pm](https://github.com/joyent/conch/blob/master/lib/Conch/Controller/WorkspaceRack.pm)

## METHODS

### get\_all

Get a list of racks for the indicated workspace.

Response uses the WorkspaceRackSummary json schema.

### find\_workspace\_rack

Chainable action that uses the `workspace_id` and `rack_id` values provided in the stash
to confirm the rack is a (direct or indirect) member of the workspace.

Relies on ["find\_workspace" in Conch::Controller::Workspace](../modules/Conch%3A%3AController%3A%3AWorkspace#find_workspace) and
["find\_rack" in Conch::Controller::Rack](../modules/Conch%3A%3AController%3A%3ARack#find_rack) to have already run, verified user roles, and populated
the stash values.

Saves `workspace_rack_rs` to the stash.

### add

Add a rack to a workspace, unless it is the GLOBAL workspace, provided the rack
is assigned to the parent workspace of this one.

### remove

Remove a rack from a workspace (and all descendants).

Requires the 'admin' role on the workspace.

## LICENSING

Copyright Joyent, Inc.

This Source Code Form is subject to the terms of the Mozilla Public License,
v.2.0. If a copy of the MPL was not distributed with this file, You can obtain
one at [https://www.mozilla.org/en-US/MPL/2.0/](https://www.mozilla.org/en-US/MPL/2.0/).
