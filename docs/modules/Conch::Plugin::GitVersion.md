# Conch::Plugin::GitVersion

## SOURCE

[https://github.com/joyent/conch/blob/master/lib/Conch/Plugin/GitVersion.pm](https://github.com/joyent/conch/blob/master/lib/Conch/Plugin/GitVersion.pm)

## DESCRIPTION

Mojo plugin registering the git version tag and hash for the repository

## METHODS

### register

Sets up the helpers.

## HELPERS

These methods are made available on the `$c` object (the invocant of all controller methods,
and therefore other helpers).

### version\_tag

Provides a string that uniquely describes the version and commit of the currently-running code.

### version\_hash

Provides the exact git SHA of the currently-running code.

## LICENSING

Copyright Joyent, Inc.

This Source Code Form is subject to the terms of the Mozilla Public License,
v.2.0. If a copy of the MPL was not distributed with this file, You can obtain
one at [https://www.mozilla.org/en-US/MPL/2.0/](https://www.mozilla.org/en-US/MPL/2.0/).
