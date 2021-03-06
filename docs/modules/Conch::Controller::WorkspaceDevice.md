# Conch::Controller::WorkspaceDevice

## SOURCE

[https://github.com/joyent/conch/blob/master/lib/Conch/Controller/WorkspaceDevice.pm](https://github.com/joyent/conch/blob/master/lib/Conch/Controller/WorkspaceDevice.pm)

## METHODS

### get\_all

Get a list of all devices in the indicated workspace.

Supports these query parameters to constrain results (which are ANDed together for the search,
not ORed):

```
validated=1     only devices with validated set
validated=0     only devices with validated not set
health=<value>  only devices with health matching the provided value
    (can be used more than once to search for ANY of the specified health values)
active_minutes=X  only devices last seen within X minutes
ids_only=1      only return device ids, not full data
serials_only=1  only return device serial numbers, not full data
```

Response uses the Devices json schema, or DeviceIds iff `ids_only=1`, or DeviceSerials iff
`serials_only=1`.

### get\_pxe\_devices

Response uses the WorkspaceDevicePXEs json schema.

### device\_totals

Ported from 'conch-stats'.

Response uses the 'DeviceTotals' and 'DeviceTotalsCirconus' json schemas.
Add '.circ' to the end of the URL to select the data format customized for Circonus.

Note that this is an unauthenticated endpoint.

## LICENSING

Copyright Joyent, Inc.

This Source Code Form is subject to the terms of the Mozilla Public License,
v.2.0. If a copy of the MPL was not distributed with this file, You can obtain
one at [https://www.mozilla.org/en-US/MPL/2.0/](https://www.mozilla.org/en-US/MPL/2.0/).
