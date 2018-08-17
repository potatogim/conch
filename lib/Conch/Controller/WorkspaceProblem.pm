=pod

=head1 NAME

Conch::Controller::WorkspaceProblem

=head1 METHODS

=cut

package Conch::Controller::WorkspaceProblem;

use Role::Tiny::With;
use Mojo::Base 'Mojolicious::Controller', -signatures;

use Mojo::JSON 'decode_json';

with 'Conch::Role::MojoLog';


=head2 list

Get a list of problems for a workspace, using the Legacy code base

=cut

sub list ($c) {
	my $problems = $c->_get_problems;
	$c->status( 200, $problems );
}


=head2 _get_problems

Build a collection of failing devices in a workspace

=cut
# The report / validation format is not normalized yet, so this is going to be
# a giant mess. Sorry. -- bdha
sub _get_problems ($c) {

	my $schema = $c->schema;

	my $criteria = _get_validation_criteria($schema);

	my @failing_user_devices;
	my @unreported_user_devices;

	# TODO: this query could be further modified to also fetch
	# device_rack_location and latest_device_report at the same time.
	my @workspace_devices = $c->stash('workspace_rs')
		->associated_racks
		->related_resultset('device_locations')
		->search_related('device', { health => [ qw(FAIL UNKNOWN) ] })
		->active;

	foreach my $d (@workspace_devices) {
		if ( $d->health eq 'FAIL' ) {
			push @failing_user_devices, $d;
		}
		if ( $d->health eq 'UNKNOWN' ) {
			push @unreported_user_devices, $d;
		}
	}

	# TODO: this query could be further modified to also fetch
	# device_rack_location and latest_device_report at the same time.
	my @unlocated_user_devices = $c->stash('user')
		->related_resultset('user_relay_connections')
		->related_resultset('device_relay_connections')
		->search_related_rs('device',
			{
				# all devices in device_location table
				'device.id' => { -not_in => $c->db_device_locations->get_column('device_id')->as_query },
			},
		)
		->all;

	my $failing_problems = {};
	foreach my $device (@failing_user_devices) {
		my $device_id = $device->id;

		$failing_problems->{$device_id}{health} = $device->health;
		$failing_problems->{$device_id}{location} =
			_device_rack_location( $schema, $device_id );

		my $report = _latest_device_report( $schema, $device_id );
		$failing_problems->{$device_id}{report_id} = $report->id;
		my @failures = _validation_failures( $schema, $criteria, $report->id );
		$failing_problems->{$device_id}{problems} = \@failures;
	}

	my $unreported_problems = {};
	foreach my $device (@unreported_user_devices) {
		my $device_id = $device->id;

		$unreported_problems->{$device_id}{health} = $device->health;
		$unreported_problems->{$device_id}{location} =
			_device_rack_location( $schema, $device_id );
	}

	my $unlocated_problems = {};
	foreach my $device (@unlocated_user_devices) {
		my $device_id = $device->id;

		$unlocated_problems->{$device_id}{health} = $device->health;
		my $report = _latest_device_report( $schema, $device_id );
		$unlocated_problems->{$device_id}{report_id} = $report->id;
		my @failures = _validation_failures( $schema, $criteria, $report->id );
		$unlocated_problems->{$device_id}{problems} = \@failures;
	}

	return {
		failing    => $failing_problems,
		unreported => $unreported_problems,
		unlocated  => $unlocated_problems
	};
}

sub _validation_failures {
	my ( $schema, $criteria, $report_id ) = @_;
	my @failures;

	# Bundle up the validate logs for a given device report.
	my @validation_report =
		map { decode_json( $_->validation ) }
		$schema->resultset('DeviceValidate')->search( { report_id => $report_id } );

	foreach my $v (@validation_report) {
		my $fail = {};
		if ( $v->{status} eq 0 ) {
			$fail->{criteria}{id} = $v->{criteria_id} || undef;
			$fail->{criteria}{component} =
				$criteria->{ $v->{criteria_id} }{component} || undef;
			$fail->{criteria}{condition} =
				$criteria->{ $v->{criteria_id} }{condition} || undef;
			$fail->{criteria}{min}  = $criteria->{ $v->{criteria_id} }{min}  || undef;
			$fail->{criteria}{warn} = $criteria->{ $v->{criteria_id} }{warn} || undef;
			$fail->{criteria}{crit} = $criteria->{ $v->{criteria_id} }{crit} || undef;

			$fail->{component_id}   = $v->{component_id}   || undef;
			$fail->{component_name} = $v->{component_name} || undef;
			$fail->{component_type} = $v->{component_type} || undef;
			$fail->{log}            = $v->{log}            || undef;
			$fail->{metric}         = $v->{metric}         || undef;

			push @failures, $fail;
		}
	}

	return @failures;
}

sub _get_validation_criteria {
	my ($schema) = @_;

	my $criteria = {};

	my @rs = $schema->resultset('DeviceValidateCriteria')->search( {} )->all;
	foreach my $c (@rs) {
		$criteria->{ $c->id }{product_id} = $c->product_id || undef;
		$criteria->{ $c->id }{component}  = $c->component  || undef;
		$criteria->{ $c->id }{condition}  = $c->condition  || undef;
		$criteria->{ $c->id }{vendor}     = $c->vendor     || undef;
		$criteria->{ $c->id }{model}      = $c->model      || undef;
		$criteria->{ $c->id }{string}     = $c->string     || undef;
		$criteria->{ $c->id }{min}        = $c->min        || undef;
		$criteria->{ $c->id }{warn}       = $c->warn       || undef;
		$criteria->{ $c->id }{crit}       = $c->crit       || undef;
	}

	return $criteria;
}

# Gives a hash of Rack and Datacenter location details
sub _device_rack_location {
	my ( $schema, $device_id ) = @_;

	my $location;
	my $device_location = $schema->resultset('DeviceLocation')->find( { device_id => $device_id } );

	if ($device_location) {

		# FIXME: this can all be done in one single query.
		my $rack_info =
			$schema->resultset('DatacenterRack')
				->find( { id => $device_location->rack_id, deactivated => { '=', undef } } );

		my $datacenter =
			$schema->resultset('DatacenterRoom')->find( { id => $rack_info->datacenter_room_id } );

		# get the hardware product a device should be by rack location
		my $target_hardware = $schema->resultset('HardwareProduct')->search(
			{
				'datacenter_rack_layouts.rack_id'  => $rack_info->id,
				'datacenter_rack_layouts.ru_start' => $device_location->rack_unit,
			},
			{ join => 'datacenter_rack_layouts' }
		)->single;

		$location->{rack}{id}   = $device_location->rack_id;
		$location->{rack}{unit} = $device_location->rack_unit;
		$location->{rack}{name} = $rack_info->name;
		$location->{rack}{role} = $rack_info->role->name;

		$location->{target_hardware_product}{id}    = $target_hardware->id;
		$location->{target_hardware_product}{name}  = $target_hardware->name;
		$location->{target_hardware_product}{alias} = $target_hardware->alias;
		$location->{target_hardware_product}{vendor} =
			$target_hardware->vendor->name;

		$location->{datacenter}{id}          = $datacenter->id;
		$location->{datacenter}{name}        = $datacenter->az;
		$location->{datacenter}{vendor_name} = $datacenter->vendor_name;
	}

	return $location;
}

sub _latest_device_report {
	my ( $schema, $device_id ) = @_;

	return $schema->resultset('DeviceReport')->search(
		{ device_id => $device_id },
		{ order_by => { -desc => 'created' }, rows => 1 },
	)
	->single;
}

1;
__END__

=pod

=head1 LICENSING

Copyright Joyent, Inc.

This Source Code Form is subject to the terms of the Mozilla Public License,
v.2.0. If a copy of the MPL was not distributed with this file, You can obtain
one at http://mozilla.org/MPL/2.0/.

=cut
