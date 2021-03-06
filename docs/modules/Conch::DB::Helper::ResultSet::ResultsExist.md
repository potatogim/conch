# Conch::DB::Helper::ResultSet::ResultsExist

## SOURCE

[https://github.com/joyent/conch/blob/master/lib/Conch/DB/Helper/ResultSet/ResultsExist.pm](https://github.com/joyent/conch/blob/master/lib/Conch/DB/Helper/ResultSet/ResultsExist.pm)

## DESCRIPTION

A component for [Conch::DB::ResultSet](../modules/Conch%3A%3ADB%3A%3AResultSet) classes that provides the `exists` method.

See also [DBIx::Class::Helper::ResultSet::Shortcut::ResultsExist](https://metacpan.org/pod/DBIx%3A%3AClass%3A%3AHelper%3A%3AResultSet%3A%3AShortcut%3A%3AResultsExist).

This code is postgres-specific but may work on other databases as well.

## USAGE

```
__PACKAGE__->load_components('+Conch::DB::Helper::ResultSet::ResultsExist');
```

## METHODS

### exists

Efficiently determines if a result exists, without needing to do a `->count`.
Essentially does:

```
select * from ( select exists (select 1 from ... your query ... ) ) as _existence_subq;
```

Returns a value that you can treat as a boolean.

## LICENSING

Copyright Joyent, Inc.

This Source Code Form is subject to the terms of the Mozilla Public License,
v.2.0. If a copy of the MPL was not distributed with this file, You can obtain
one at [https://www.mozilla.org/en-US/MPL/2.0/](https://www.mozilla.org/en-US/MPL/2.0/).
