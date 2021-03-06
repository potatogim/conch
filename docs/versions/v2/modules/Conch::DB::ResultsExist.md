# NAME

Conch::DB::ResultsExist

# DESCRIPTION

A component for [Conch::DB::ResultSet](/modules/Conch::DB::ResultSet) classes that provides the `exists` method.

See also [DBIx::Class::Helper::ResultSet::Shortcut::ResultsExist](https://metacpan.org/pod/DBIx::Class::Helper::ResultSet::Shortcut::ResultsExist), which is not usable in its
present form due to [https://github.com/frioux/DBIx-Class-Helpers/issues/54](https://github.com/frioux/DBIx-Class-Helpers/issues/54).

This code is postgres-specific.

# USAGE

```
__PACKAGE__->load_components('+Conch::DB::ResultsExist');
```

# METHODS

## exists

Efficiently efficiently determines if a result exists, without needing to do a `->count`.
Essentially does:

```
select exists (select 1 from ... rest of your query ...);
```

Returns a value that you can treat as a boolean.

# LICENSING

Copyright Joyent, Inc.

This Source Code Form is subject to the terms of the Mozilla Public License,
v.2.0. If a copy of the MPL was not distributed with this file, You can obtain
one at [http://mozilla.org/MPL/2.0/](http://mozilla.org/MPL/2.0/).
