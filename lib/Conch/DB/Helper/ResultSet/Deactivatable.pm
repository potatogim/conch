package Conch::DB::Helper::ResultSet::Deactivatable;
use v5.26;
use warnings;

use experimental 'signatures';

=head1 NAME

Conch::DB::Helper::ResultSet::Deactivatable

=head1 DESCRIPTION

A component for L<Conch::DB::ResultSet> classes for database tables with a C<deactivated>
column, to provide common query functionality.

=head1 USAGE

    __PACKAGE__->load_components('+Conch::DB::Helper::ResultSet::Deactivatable');

=head1 METHODS

=head2 active

Chainable resultset to limit results to those that aren't deactivated.

=cut

sub active ($self) {
    Carp::croak($self->result_source->result_class->table,
            ' does not have a \'deactivated\' column')
        if !$ENV{MOJO_MODE} and not $self->result_source->has_column('deactivated');

    $self->search({ $self->current_source_alias.'.deactivated' => undef });
}

=head2 deactivate

Update all matching rows by setting deactivated = now().

=cut

sub deactivate ($self) {
    Carp::croak($self->result_source->result_class->table,
            ' does not have a \'deactivated\' column')
        if !$ENV{MOJO_MODE} and not $self->result_source->has_column('deactivated');

    $self->update({
        deactivated => \'now()',
        $self->result_source->has_column('updated') ? ( updated => \'now()' ) : (),
    });
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
