# Conch::DB::Result::HardwareVendor

## SOURCE

[https://github.com/joyent/conch/blob/master/lib/Conch/DB/Result/HardwareVendor.pm](https://github.com/joyent/conch/blob/master/lib/Conch/DB/Result/HardwareVendor.pm)

## BASE CLASS: [Conch::DB::Result](../modules/Conch%3A%3ADB%3A%3AResult)

## TABLE: `hardware_vendor`

## ACCESSORS

### id

```
data_type: 'uuid'
default_value: gen_random_uuid()
is_nullable: 0
size: 16
```

### name

```
data_type: 'text'
is_nullable: 0
```

### deactivated

```
data_type: 'timestamp with time zone'
is_nullable: 1
```

### created

```
data_type: 'timestamp with time zone'
default_value: current_timestamp
is_nullable: 0
original: {default_value => \"now()"}
```

### updated

```
data_type: 'timestamp with time zone'
default_value: current_timestamp
is_nullable: 0
original: {default_value => \"now()"}
```

## PRIMARY KEY

- ["id"](#id)

## RELATIONS

### hardware\_products

Type: has\_many

Related object: [Conch::DB::Result::HardwareProduct](../modules/Conch%3A%3ADB%3A%3AResult%3A%3AHardwareProduct)

## LICENSING

Copyright Joyent, Inc.

This Source Code Form is subject to the terms of the Mozilla Public License,
v.2.0. If a copy of the MPL was not distributed with this file, You can obtain
one at [https://www.mozilla.org/en-US/MPL/2.0/](https://www.mozilla.org/en-US/MPL/2.0/).
