package Conch::Route::Datacenter;

use Mojo::Base -strict;

=pod

=head1 NAME

Conch::Route::Datacenter

=head1 METHODS

=head2 routes

Sets up the routes for /dc.

=cut

sub routes {
    my $class = shift;
    my $dc = shift;     # secured, under /dc

    $dc = $dc->require_system_admin->to({ controller => 'datacenter' });

    # GET /dc
    $dc->get('/')->to('#get_all');
    # POST /dc
    $dc->post('/')->to('#create');

    my $with_datacenter = $dc->under('/<datacenter_id:uuid>')->to('#find_datacenter');

    # GET /dc/:datacenter_id
    $with_datacenter->get('/')->to('#get_one');
    # POST /dc/:datacenter_id
    $with_datacenter->post('/')->to('#update');
    # DELETE /dc/:datacenter_id
    $with_datacenter->delete('/')->to('#delete');
    # GET /dc/:datacenter_id/rooms
    $with_datacenter->get('/rooms')->to('#get_rooms');
}

1;
__END__

=pod

=head1 ROUTE ENDPOINTS

All routes require authentication.

=head2 C<GET /dc>

=over 4

=item * Requires system admin authorization

=item * Response: F<response.yaml#/definitions/Datacenters>

=back

=head2 C<POST /dc>

=over 4

=item * Requires system admin authorization

=item * Request: F<request.yaml#/definitions/DatacenterCreate>

=item * Response: C<201 Created> or C<204 No Content>, plus Location header

=back

=head2 C<GET /dc/:datacenter_id>

=over 4

=item * Requires system admin authorization

=item * Response: F<response.yaml#/definitions/Datacenter>

=back

=head2 C<POST /dc/:datacenter_id>

=over 4

=item * Requires system admin authorization

=item * Request: F<request.yaml#/definitions/DatacenterUpdate>

=item * Response: Redirect to the updated datacenter

=back

=head2 C<DELETE /dc/:datacenter_id>

=over 4

=item * Requires system admin authorization

=item * Response: C<204 No Content>

=back

=head2 C<GET /dc/:datacenter_id/rooms>

=over 4

=item * Requires system admin authorization

=item * Response: F<response.yaml#/definitions/DatacenterRoomsDetailed>

=back

=head1 LICENSING

Copyright Joyent, Inc.

This Source Code Form is subject to the terms of the Mozilla Public License,
v.2.0. If a copy of the MPL was not distributed with this file, You can obtain
one at L<https://www.mozilla.org/en-US/MPL/2.0/>.

=cut
# vim: set ts=4 sts=4 sw=4 et :
