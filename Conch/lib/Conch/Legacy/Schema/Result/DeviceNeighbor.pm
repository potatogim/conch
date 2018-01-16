use utf8;

package Conch::Legacy::Schema::Result::DeviceNeighbor;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Conch::Legacy::Schema::Result::DeviceNeighbor

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

__PACKAGE__->load_components( "InflateColumn::DateTime", "TimeStamp" );

=head1 TABLE: C<device_neighbor>

=cut

__PACKAGE__->table("device_neighbor");

=head1 ACCESSORS

=head2 mac

  data_type: 'macaddr'
  is_foreign_key: 1
  is_nullable: 0

=head2 raw_text

  data_type: 'text'
  is_nullable: 1

=head2 peer_switch

  data_type: 'text'
  is_nullable: 1

=head2 peer_port

  data_type: 'text'
  is_nullable: 1

=head2 want_switch

  data_type: 'text'
  is_nullable: 1

=head2 want_port

  data_type: 'text'
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

=head2 peer_mac

  data_type: 'macaddr'
  is_nullable: 1

=cut

__PACKAGE__->add_columns(
  "mac",
  { data_type => "macaddr", is_foreign_key => 1, is_nullable => 0 },
  "raw_text",
  { data_type => "text", is_nullable => 1 },
  "peer_switch",
  { data_type => "text", is_nullable => 1 },
  "peer_port",
  { data_type => "text", is_nullable => 1 },
  "want_switch",
  { data_type => "text", is_nullable => 1 },
  "want_port",
  { data_type => "text", is_nullable => 1 },
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
  "peer_mac",
  { data_type => "macaddr", is_nullable => 1 },
);

=head1 PRIMARY KEY

=over 4

=item * L</mac>

=back

=cut

__PACKAGE__->set_primary_key("mac");

=head1 RELATIONS

=head2 mac

Type: belongs_to

Related object: L<Conch::Legacy::Schema::Result::DeviceNic>

=cut

__PACKAGE__->belongs_to(
  "mac",
  "Conch::Legacy::Schema::Result::DeviceNic",
  { mac           => "mac" },
  { is_deferrable => 0, on_delete => "NO ACTION", on_update => "NO ACTION" },
);

# Created by DBIx::Class::Schema::Loader v0.07047 @ 2018-01-12 11:35:37
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:/mZVe9wG3+oIacf76abUjA

# You can replace this text with custom code or comments, and it will be preserved on regeneration
__PACKAGE__->meta->make_immutable;
1;
