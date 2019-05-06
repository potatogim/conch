# NAME

Conch::Plugin::Database

# DESCRIPTION

Sets up the database and provides convenient accessors to it.

# HELPERS

## schema

Provides read/write access to the database via [DBIx::Class](https://metacpan.org/pod/DBIx::Class).  Returns a [Conch::DB](https://metacpan.org/pod/Conch::DB) object
that persists for the lifetime of the application.

## rw\_schema

See ["schema"](#schema); can be used interchangeably with it.

## ro\_schema

Provides (guaranteed) read-only access to the database via [DBIx::Class](https://metacpan.org/pod/DBIx::Class).  Returns a
[Conch::DB](https://metacpan.org/pod/Conch::DB) object that persists for the lifetime of the application.

Note that because of the use of `AutoCommit => 0`, database errors must be explicitly
cleared with `->txn_rollback`; see ["ReadOnly-(boolean)" in DBD::Pg](https://metacpan.org/pod/DBD::Pg#ReadOnly--boolean).

## db\_&lt;table>s, db\_ro\_&lt;table>s

Provides direct read/write and read-only accessors to resultsets.  The table name is used in
the `alias` attribute (see ["alias" in DBIx::Class::ResultSet](https://metacpan.org/pod/DBIx::Class::ResultSet#alias)).

## txn\_wrapper

Wraps the provided subref in a database transaction, rolling back in case of an exception.
Any provided arguments are passed to the sub, along with the invocant controller.

If the exception is not `'rollback'` (which signals an intentional premature bailout), the
exception will be logged, and a response will be set up as an error response with the first
line of the exception.

# LICENSING

Copyright Joyent, Inc.

This Source Code Form is subject to the terms of the Mozilla Public License,
v.2.0. If a copy of the MPL was not distributed with this file, You can obtain
one at [http://mozilla.org/MPL/2.0/](http://mozilla.org/MPL/2.0/).