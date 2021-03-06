use utf8;
package Conch::DB::Result::UserSessionToken;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Conch::DB::Result::UserSessionToken

=cut

use strict;
use warnings;


=head1 BASE CLASS: L<Conch::DB::Result>

=cut

use base 'Conch::DB::Result';

=head1 TABLE: C<user_session_token>

=cut

__PACKAGE__->table("user_session_token");

=head1 ACCESSORS

=head2 user_id

  data_type: 'uuid'
  is_foreign_key: 1
  is_nullable: 0
  size: 16

=head2 expires

  data_type: 'timestamp with time zone'
  is_nullable: 0

=head2 name

  data_type: 'text'
  is_nullable: 0

=head2 created

  data_type: 'timestamp with time zone'
  default_value: current_timestamp
  is_nullable: 0
  original: {default_value => \"now()"}

=head2 last_used

  data_type: 'timestamp with time zone'
  is_nullable: 1

=head2 id

  data_type: 'uuid'
  default_value: gen_random_uuid()
  is_nullable: 0
  size: 16

=head2 last_ipaddr

  data_type: 'inet'
  is_nullable: 1

=cut

__PACKAGE__->add_columns(
  "user_id",
  { data_type => "uuid", is_foreign_key => 1, is_nullable => 0, size => 16 },
  "expires",
  { data_type => "timestamp with time zone", is_nullable => 0 },
  "name",
  { data_type => "text", is_nullable => 0 },
  "created",
  {
    data_type     => "timestamp with time zone",
    default_value => \"current_timestamp",
    is_nullable   => 0,
    original      => { default_value => \"now()" },
  },
  "last_used",
  { data_type => "timestamp with time zone", is_nullable => 1 },
  "id",
  {
    data_type => "uuid",
    default_value => \"gen_random_uuid()",
    is_nullable => 0,
    size => 16,
  },
  "last_ipaddr",
  { data_type => "inet", is_nullable => 1 },
);

=head1 PRIMARY KEY

=over 4

=item * L</id>

=back

=cut

__PACKAGE__->set_primary_key("id");

=head1 UNIQUE CONSTRAINTS

=head2 C<user_session_token_user_id_name_key>

=over 4

=item * L</user_id>

=item * L</name>

=back

=cut

__PACKAGE__->add_unique_constraint("user_session_token_user_id_name_key", ["user_id", "name"]);

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


# Created by DBIx::Class::Schema::Loader v0.07049
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:ekYKuvEUSX1+YiDrS0novg

__PACKAGE__->add_columns(
    '+id' => { is_serializable => 0 },
    '+user_id' => { is_serializable => 0 },
    '+created' => { retrieve_on_insert => 1 },
    '+expires' => { retrieve_on_insert => 1 },
);

use experimental 'signatures';

=head1 METHODS

=head2 is_login

Boolean indicating whether this token was created via the main /login flow.

=cut

sub is_login ($self) {
    $self->name =~ /^login_jwt_[\d_]+$/;
}

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
