package Conch::DB::ResultSet::Rack;
use v5.26;
use warnings;
use parent 'Conch::DB::ResultSet';

use experimental 'signatures';
use Carp ();
use List::Util 'none';

=head1 NAME

Conch::DB::ResultSet::Rack

=head1 DESCRIPTION

Interface to queries involving racks.

=head1 METHODS

=head2 assigned_rack_units

Returns a list of rack_unit positions that are assigned to current layouts (including positions
assigned to hardware that start at an earlier position) at the specified rack. (Will return
merged results when passed a resultset referencing multiple racks, which is probably not what
you want, so don't do that.)

This is used for identifying potential conflicts when adjusting layouts.

=cut

sub assigned_rack_units ($self) {
    my @layout_data = $self->search_related('rack_layouts', undef, {
        columns => {
            rack_unit_start => 'rack_layouts.rack_unit_start',
            rack_unit_size => 'hardware_product.rack_unit_size',
        },
        join => 'hardware_product',
        order_by => 'rack_unit_start',
    })->hri->all;

    return map
        +(($_->{rack_unit_start}) .. ($_->{rack_unit_start} + ($_->{rack_unit_size} // 1) - 1)),
        @layout_data;
}

=head2 user_has_role

Checks that the provided user_id has (at least) the specified role in at least one workspace
associated with the specified rack(s) (implicitly including parent workspaces), or at least one
build associated with the rack(s).

Returns a boolean.

=cut

sub user_has_role ($self, $user_id, $role) {
    return 1 if $role eq 'none';

    Carp::croak('role must be one of: ro, rw, admin')
        if !$ENV{MOJO_MODE} and none { $role eq $_ } qw(ro rw admin);

    # since every workspace_rack entry has an equivalent entry in the parent workspace, we do
    # not need to search the workspace heirarchy here, but simply look for a role entry for any
    # workspace the rack is associated with.
    my $ws_rs = $self
        ->related_resultset('workspace_racks')
        ->related_resultset('workspace');

    # this is Conch::DB::ResultSet::Workspace::user_has_role, unrolled
    my $ws_via_user_rs = $ws_rs
        ->search_related('user_workspace_roles', { user_id => $user_id })
        ->with_role($role)
        ->related_resultset('user_account');

    my $ws_via_org_rs = $ws_rs
        ->related_resultset('organization_workspace_roles')
        ->with_role($role)
        ->related_resultset('organization')
        ->search_related('user_organization_roles', { user_id => $user_id })
        ->related_resultset('user_account');

    my $build_rs = $self->related_resultset('build');

    # this is Conch::DB::ResultSet::Build::user_has_role, unrolled
    my $build_via_user_rs = $build_rs
        ->search_related('user_build_roles', { user_id => $user_id })
        ->with_role($role)
        ->related_resultset('user_account');

    my $build_via_org_rs = $build_rs
        ->related_resultset('organization_build_roles')
        ->with_role($role)
        ->related_resultset('organization')
        ->search_related('user_organization_roles', { user_id => $user_id })
        ->related_resultset('user_account');

    return $ws_via_user_rs
        ->union_all($ws_via_org_rs)
        ->union_all($build_via_user_rs)
        ->union_all($build_via_org_rs)
        ->exists;
}

1;
__END__

=pod

=head1 LICENSING

Copyright Joyent, Inc.

This Source Code Form is subject to the terms of the Mozilla Public License,
v.2.0. If a copy of the MPL was not distributed with this file, You can obtain
one at L<http://mozilla.org/MPL/2.0/>.

=cut
# vim: set ts=4 sts=4 sw=4 et :
