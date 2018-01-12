use utf8;
package Conch::Legacy::Schema::Result::DeviceDisk;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Conch::Legacy::Schema::Result::DeviceDisk

=cut

use strict;
use warnings;

use Moose;
use MooseX::NonMoose;
use MooseX::MarkAsMethods autoclean => 1;
extends 'DBIx::Class::Core';

=head1 COMPONENTS LOADED

=over 4

=item * L<DBIx::Class::InflateColumn::DateTime>

=item * L<DBIx::Class::TimeStamp>

=back

=cut

__PACKAGE__->load_components("InflateColumn::DateTime", "TimeStamp");

=head1 TABLE: C<device_disk>

=cut

__PACKAGE__->table("device_disk");

=head1 ACCESSORS

=head2 id

  data_type: 'uuid'
  default_value: gen_random_uuid()
  is_nullable: 0
  size: 16

=head2 device_id

  data_type: 'text'
  is_foreign_key: 1
  is_nullable: 0

=head2 serial_number

  data_type: 'text'
  is_nullable: 0

=head2 slot

  data_type: 'integer'
  is_nullable: 1

=head2 size

  data_type: 'integer'
  is_nullable: 1

=head2 vendor

  data_type: 'text'
  is_nullable: 1

=head2 model

  data_type: 'text'
  is_nullable: 1

=head2 firmware

  data_type: 'text'
  is_nullable: 1

=head2 transport

  data_type: 'text'
  is_nullable: 1

=head2 health

  data_type: 'text'
  is_nullable: 1

=head2 drive_type

  data_type: 'text'
  is_nullable: 1

=head2 temp

  data_type: 'integer'
  is_nullable: 1

=head2 deactivated

  data_type: 'timestamp with time zone'
  is_nullable: 1

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

=head2 enclosure

  data_type: 'text'
  is_nullable: 1

=head2 hba

  data_type: 'text'
  is_nullable: 1

=cut

__PACKAGE__->add_columns(
  "id",
  {
    data_type => "uuid",
    default_value => \"gen_random_uuid()",
    is_nullable => 0,
    size => 16,
  },
  "device_id",
  { data_type => "text", is_foreign_key => 1, is_nullable => 0 },
  "serial_number",
  { data_type => "text", is_nullable => 0 },
  "slot",
  { data_type => "integer", is_nullable => 1 },
  "size",
  { data_type => "integer", is_nullable => 1 },
  "vendor",
  { data_type => "text", is_nullable => 1 },
  "model",
  { data_type => "text", is_nullable => 1 },
  "firmware",
  { data_type => "text", is_nullable => 1 },
  "transport",
  { data_type => "text", is_nullable => 1 },
  "health",
  { data_type => "text", is_nullable => 1 },
  "drive_type",
  { data_type => "text", is_nullable => 1 },
  "temp",
  { data_type => "integer", is_nullable => 1 },
  "deactivated",
  { data_type => "timestamp with time zone", is_nullable => 1 },
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
  "enclosure",
  { data_type => "text", is_nullable => 1 },
  "hba",
  { data_type => "text", is_nullable => 1 },
);

=head1 PRIMARY KEY

=over 4

=item * L</id>

=back

=cut

__PACKAGE__->set_primary_key("id");

=head1 UNIQUE CONSTRAINTS

=head2 C<device_disk_serial_number_key>

=over 4

=item * L</serial_number>

=back

=cut

__PACKAGE__->add_unique_constraint("device_disk_serial_number_key", ["serial_number"]);

=head1 RELATIONS

=head2 device

Type: belongs_to

Related object: L<Conch::Legacy::Schema::Result::Device>

=cut

__PACKAGE__->belongs_to(
  "device",
  "Conch::Legacy::Schema::Result::Device",
  { id => "device_id" },
  { is_deferrable => 0, on_delete => "NO ACTION", on_update => "NO ACTION" },
);


# Created by DBIx::Class::Schema::Loader v0.07047 @ 2018-01-12 11:35:37
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:r5Zlz0rRVI6yQhGH96L0oA


# You can replace this text with custom code or comments, and it will be preserved on regeneration
__PACKAGE__->meta->make_immutable;
1;