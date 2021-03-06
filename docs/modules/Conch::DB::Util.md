# Conch::DB:::Util - utility functions for working with the Conch database

## SOURCE

[https://github.com/joyent/conch/blob/master/lib/Conch/DB/Util.pm](https://github.com/joyent/conch/blob/master/lib/Conch/DB/Util.pm)

## METHODS

### get\_credentials

Return the credentials and connection options suitable for passing to [Conch::DB](../modules/Conch%3A%3ADB) for both
read-write and read-only connections, containing keys:

returns a hashref containing keys:

```
dsn
username
password
options
ro_username
ro_password
```

Overrides are accepted from the following environment variables:

```
POSTGRES_DB
POSTGRES_HOST
POSTGRES_USER
POSTGRES_PASSWORD
```

If not all credentials can be determined from environment variables, the `$config` is read
from. It should be a database configuration hashref (such as that extracted from `conch.conf`
at the appropriate hash key).

See ["connect" in DBI](https://metacpan.org/pod/DBI#connect) and ["connect" in DBD::Pg](https://metacpan.org/pod/DBD%3A%3APg#connect) for the correct syntax for these values.

### get\_postgres\_version

Retrieves the current running version of postgres.

### get\_migration\_level

Returns as a tuple the number of the latest database migration that has been applied, and the
latest migration file found on disk.

Note that the migration level retrieved from the database does **not** have leading zeroes.

### initialize\_db

Initialize an empty database with the conch user and role and create empty tables.

### migrate\_db

Bring the Conch database up to the latest migration.

### create\_validation\_plans

Sets up the static validation plans currently in use by Conch.

## LICENSING

Copyright Joyent, Inc.

This Source Code Form is subject to the terms of the Mozilla Public License,
v.2.0. If a copy of the MPL was not distributed with this file, You can obtain
one at [https://www.mozilla.org/en-US/MPL/2.0/](https://www.mozilla.org/en-US/MPL/2.0/).
