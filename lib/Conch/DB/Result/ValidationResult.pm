use utf8;
package Conch::DB::Result::ValidationResult;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Conch::DB::Result::ValidationResult

=cut

use strict;
use warnings;


=head1 BASE CLASS: L<Conch::DB::Result>

=cut

use base 'Conch::DB::Result';

=head1 TABLE: C<validation_result>

=cut

__PACKAGE__->table("validation_result");

=head1 ACCESSORS

=head2 id

  data_type: 'uuid'
  default_value: gen_random_uuid()
  is_nullable: 0
  size: 16

=head2 validation_id

  data_type: 'uuid'
  is_foreign_key: 1
  is_nullable: 0
  size: 16

=head2 message

  data_type: 'text'
  is_nullable: 0

=head2 hint

  data_type: 'text'
  is_nullable: 1

=head2 status

  data_type: 'enum'
  extra: {custom_type_name => "validation_status_enum",list => ["error","fail","pass"]}
  is_nullable: 0

=head2 category

  data_type: 'text'
  is_nullable: 0

=head2 component

  data_type: 'text'
  is_nullable: 1

=head2 created

  data_type: 'timestamp with time zone'
  default_value: current_timestamp
  is_nullable: 0
  original: {default_value => \"now()"}

=head2 device_id

  data_type: 'uuid'
  is_foreign_key: 1
  is_nullable: 0
  size: 16

=cut

__PACKAGE__->add_columns(
  "id",
  {
    data_type => "uuid",
    default_value => \"gen_random_uuid()",
    is_nullable => 0,
    size => 16,
  },
  "validation_id",
  { data_type => "uuid", is_foreign_key => 1, is_nullable => 0, size => 16 },
  "message",
  { data_type => "text", is_nullable => 0 },
  "hint",
  { data_type => "text", is_nullable => 1 },
  "status",
  {
    data_type => "enum",
    extra => {
      custom_type_name => "validation_status_enum",
      list => ["error", "fail", "pass"],
    },
    is_nullable => 0,
  },
  "category",
  { data_type => "text", is_nullable => 0 },
  "component",
  { data_type => "text", is_nullable => 1 },
  "created",
  {
    data_type     => "timestamp with time zone",
    default_value => \"current_timestamp",
    is_nullable   => 0,
    original      => { default_value => \"now()" },
  },
  "device_id",
  { data_type => "uuid", is_foreign_key => 1, is_nullable => 0, size => 16 },
);

=head1 PRIMARY KEY

=over 4

=item * L</id>

=back

=cut

__PACKAGE__->set_primary_key("id");

=head1 UNIQUE CONSTRAINTS

=head2 C<validation_result_all_columns_key>

=over 4

=item * L</device_id>

=item * L</validation_id>

=item * L</message>

=item * L</hint>

=item * L</status>

=item * L</category>

=item * L</component>

=back

=cut

__PACKAGE__->add_unique_constraint(
  "validation_result_all_columns_key",
  [
    "device_id",
    "validation_id",
    "message",
    "hint",
    "status",
    "category",
    "component",
  ],
);

=head1 RELATIONS

=head2 device

Type: belongs_to

Related object: L<Conch::DB::Result::Device>

=cut

__PACKAGE__->belongs_to(
  "device",
  "Conch::DB::Result::Device",
  { id => "device_id" },
  { is_deferrable => 0, on_delete => "NO ACTION", on_update => "NO ACTION" },
);

=head2 validation

Type: belongs_to

Related object: L<Conch::DB::Result::Validation>

=cut

__PACKAGE__->belongs_to(
  "validation",
  "Conch::DB::Result::Validation",
  { id => "validation_id" },
  { is_deferrable => 0, on_delete => "NO ACTION", on_update => "NO ACTION" },
);

=head2 validation_state_members

Type: has_many

Related object: L<Conch::DB::Result::ValidationStateMember>

=cut

__PACKAGE__->has_many(
  "validation_state_members",
  "Conch::DB::Result::ValidationStateMember",
  { "foreign.validation_result_id" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 validation_states

Type: many_to_many

Composing rels: L</validation_state_members> -> validation_state

=cut

__PACKAGE__->many_to_many(
  "validation_states",
  "validation_state_members",
  "validation_state",
);


# Created by DBIx::Class::Schema::Loader v0.07049
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:00k1URNkOBldwrhf2z7WVg

__PACKAGE__->add_columns(
    '+created' => { is_serializable => 0 },
    '+device_id' => { is_serializable => 0 },
);

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
