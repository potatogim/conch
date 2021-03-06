use utf8;
package Conch::DB::Result::UserWorkspaceRole;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Conch::DB::Result::UserWorkspaceRole

=cut

use strict;
use warnings;


=head1 BASE CLASS: L<Conch::DB::Result>

=cut

use base 'Conch::DB::Result';

=head1 TABLE: C<user_workspace_role>

=cut

__PACKAGE__->table("user_workspace_role");

=head1 ACCESSORS

=head2 user_id

  data_type: 'uuid'
  is_foreign_key: 1
  is_nullable: 0
  size: 16

=head2 workspace_id

  data_type: 'uuid'
  is_foreign_key: 1
  is_nullable: 0
  size: 16

=head2 role

  data_type: 'enum'
  default_value: 'ro'
  extra: {custom_type_name => "role_enum",list => ["ro","rw","admin"]}
  is_nullable: 0

=cut

__PACKAGE__->add_columns(
  "user_id",
  { data_type => "uuid", is_foreign_key => 1, is_nullable => 0, size => 16 },
  "workspace_id",
  { data_type => "uuid", is_foreign_key => 1, is_nullable => 0, size => 16 },
  "role",
  {
    data_type => "enum",
    default_value => "ro",
    extra => { custom_type_name => "role_enum", list => ["ro", "rw", "admin"] },
    is_nullable => 0,
  },
);

=head1 PRIMARY KEY

=over 4

=item * L</user_id>

=item * L</workspace_id>

=back

=cut

__PACKAGE__->set_primary_key("user_id", "workspace_id");

=head1 RELATIONS

=head2 user_account

Type: belongs_to

Related object: L<Conch::DB::Result::UserAccount>

=cut

__PACKAGE__->belongs_to(
  "user_account",
  "Conch::DB::Result::UserAccount",
  { id => "user_id" },
  { is_deferrable => 0, on_delete => "NO ACTION", on_update => "NO ACTION" },
);

=head2 workspace

Type: belongs_to

Related object: L<Conch::DB::Result::Workspace>

=cut

__PACKAGE__->belongs_to(
  "workspace",
  "Conch::DB::Result::Workspace",
  { id => "workspace_id" },
  { is_deferrable => 0, on_delete => "NO ACTION", on_update => "NO ACTION" },
);


# Created by DBIx::Class::Schema::Loader v0.07049
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:hztQ0pH4Hj4A+sMl+Ih55A

__PACKAGE__->load_components('+Conch::DB::Helper::Row::WithRole');

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
