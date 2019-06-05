package Conch::Controller::DeviceLocation;

use Mojo::Base 'Mojolicious::Controller', -signatures;

=pod

=head1 NAME

Conch::Controller::DeviceLocation

=head1 METHODS

=head2 get

Retrieves location data for the current device.

Response uses the DeviceLocation json schema.

=cut

sub get ($c) {
    my $device_location_rs = $c->stash('device_rs')
        ->related_resultset('device_location');

    my $rack = $device_location_rs
        ->related_resultset('rack')
        ->prefetch({ datacenter_room => 'datacenter' })
        ->add_columns({ rack_unit_start => 'device_location.rack_unit_start' })
        ->single;

    return $c->status(409, { error =>
        'Device '.$c->stash('device_id').' is not assigned to a rack'
    }) if not $rack;

    my $location = +{
        rack => $rack,
        rack_unit_start => $rack->get_column('rack_unit_start'),
        datacenter_room => $rack->datacenter_room,
        datacenter => $rack->datacenter_room->datacenter,
        target_hardware_product => $device_location_rs->target_hardware_product->single,
    };

    $c->status(200, $location);
}

=head2 set

Sets the location for a device, given a valid rack id and rack unit. The existing occupant is
removed, if there is one. The device is created based on the hardware_product specified for
the layout if it does not yet exist.

=cut

sub set ($c) {
    my $input = $c->validate_request('DeviceLocationUpdate');
    return if not $input;

    my $layout_rs = $c->db_rack_layouts->search({ map +('rack_layout.'.$_ => $input->{$_}), qw(rack_id rack_unit_start) });
    return $c->status(409, { error => "slot $input->{rack_unit_start} does not exist in the layout for rack $input->{rack_id}" }) if not $layout_rs->exists;

    my $device_id = $c->stash('device_id');

    return $c->status(303, '/device/'.$device_id.'/location')
        if $layout_rs->search_related('device_location', { device_id => $device_id })->exists;

    my $result = $c->txn_wrapper(sub ($c) {
        # create a device if it doesn't exist
        if (not $c->db_devices->search({ id => $device_id })->exists) {
            $c->db_devices->create({
                id      => $device_id,
                hardware_product_id => $layout_rs->get_column('hardware_product_id')->as_query,
                health  => 'unknown',
            });
        }

        # remove current occupant if it exists
        $layout_rs->related_resultset('device_location')->delete;

        # create device_location entry, moving the device's location if it already had one
        $c->db_device_locations->update_or_create(
            {
                device_id => $device_id,
                $input->%*,
                updated => \'now()',
            },
            { key => 'primary' },   # only search for conflicts by device_id
        );
    });

    # if the result code was already set, we errored and rolled back the db...
    return if $c->res->code;

    $c->status(303, '/device/'.$device_id.'/location');
}

=head2 delete

Deletes the location data for a device, provided it has been assigned to a location

=cut

sub delete ($c) {
    return $c->status(409, { error => 'Device '.$c->stash('device_id').' is not assigned to a rack' })
        # 0 rows updated -> 0E0 which is boolean truth, not false
        if $c->stash('device_rs')->related_resultset('device_location')->delete <= 0;

    $c->status(204);
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
