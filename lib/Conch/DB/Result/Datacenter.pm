use utf8;
package Conch::DB::Result::Datacenter;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Conch::DB::Result::Datacenter

=cut

use strict;
use warnings;


=head1 BASE CLASS: L<Conch::DB::Result>

=cut

use base 'Conch::DB::Result';

=head1 TABLE: C<datacenter>

=cut

__PACKAGE__->table("datacenter");

=head1 ACCESSORS

=head2 id

  data_type: 'uuid'
  default_value: gen_random_uuid()
  is_nullable: 0
  size: 16

=head2 vendor

  data_type: 'text'
  is_nullable: 0

=head2 vendor_name

  data_type: 'text'
  is_nullable: 1

=head2 region

  data_type: 'text'
  is_nullable: 0

=head2 location

  data_type: 'text'
  is_nullable: 0

=head2 created

  data_type: 'timestamp with time zone'
  default_value: current_timestamp
  is_nullable: 0
  original: {default_value => \"now()"}

=head2 updated

  data_type: 'timestamp with time zone'
  default_value: current_timestamp
  is_nullable: 0
  original: {default_value => \"now()"}

=cut

__PACKAGE__->add_columns(
  "id",
  {
    data_type => "uuid",
    default_value => \"gen_random_uuid()",
    is_nullable => 0,
    size => 16,
  },
  "vendor",
  { data_type => "text", is_nullable => 0 },
  "vendor_name",
  { data_type => "text", is_nullable => 1 },
  "region",
  { data_type => "text", is_nullable => 0 },
  "location",
  { data_type => "text", is_nullable => 0 },
  "created",
  {
    data_type     => "timestamp with time zone",
    default_value => \"current_timestamp",
    is_nullable   => 0,
    original      => { default_value => \"now()" },
  },
  "updated",
  {
    data_type     => "timestamp with time zone",
    default_value => \"current_timestamp",
    is_nullable   => 0,
    original      => { default_value => \"now()" },
  },
);

=head1 PRIMARY KEY

=over 4

=item * L</id>

=back

=cut

__PACKAGE__->set_primary_key("id");

=head1 UNIQUE CONSTRAINTS

=head2 C<datacenter_vendor_region_location_key>

=over 4

=item * L</vendor>

=item * L</region>

=item * L</location>

=back

=cut

__PACKAGE__->add_unique_constraint(
  "datacenter_vendor_region_location_key",
  ["vendor", "region", "location"],
);

=head1 RELATIONS

=head2 datacenter_rooms

Type: has_many

Related object: L<Conch::DB::Result::DatacenterRoom>

=cut

__PACKAGE__->has_many(
  "datacenter_rooms",
  "Conch::DB::Result::DatacenterRoom",
  { "foreign.datacenter_id" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);


# Created by DBIx::Class::Schema::Loader v0.07049
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:tNDz5pB75SuWTRSF/f4rYg

1;
__END__

=pod

=head1 LICENSING

Copyright Joyent, Inc.

This Source Code Form is subject to the terms of the Mozilla Public License,
v.2.0. If a copy of the MPL was not distributed with this file, You can obtain
one at L<https://www.mozilla.org/en-US/MPL/2.0/>.

=cut
# vim: set ts=4 sts=4 sw=4 et :
