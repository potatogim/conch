use Mojo::Base -strict;
use Test::More;
use Data::UUID;
use Path::Tiny;
use Test::Deep;
use Test::Warnings;
use Mojo::JSON 'decode_json';

use Test::Conch::Datacenter;

my $t = Test::Conch::Datacenter->new();

my $uuid = Data::UUID->new;

$t->get_ok('/ping')
	->status_is(200)
	->json_is({ status => 'ok' });
$t->get_ok('/version')
	->status_is(200)
	->json_cmp_deeply({ version => re(qr/^v/) });

$t->post_ok(
	'/login' => json => {
		user     => 'conch@conch.joyent.us',
		password => 'conch'
	}
)->status_is(200);
BAIL_OUT('Login failed') if $t->tx->res->code != 200;

isa_ok( $t->tx->res->cookie('conch'), 'Mojo::Cookie::Response' );

$t->get_ok('/workspace')
	->status_is(200)
	->json_schema_is('WorkspacesAndRoles')
	->json_is( '/0/name', 'GLOBAL' );

my $global_ws_id = $t->tx->res->json->[0]{id};
BAIL_OUT("No workspace ID") unless $global_ws_id;

$t->post_ok(
	"/workspace/$global_ws_id/child" => json => {
		name        => "test",
		description => "also test",
	}
)->status_is(201);

my $sub_ws_id = $t->tx->res->json->{id};
BAIL_OUT("Could not create sub-workspace.") unless $sub_ws_id;

subtest 'Workspace Rooms' => sub {

	$t->get_ok("/workspace/$global_ws_id/room")
		->status_is(200)
		->json_schema_is('Rooms')
		->json_is('/0/az', 'test-region-1a');

	my $room_id = $t->tx->res->json->[0]->{id};
	my $room = $t->app->db_datacenter_rooms->find($room_id);
	my $new_room = $t->app->db_datacenter_rooms->create({
		datacenter_id => $room->datacenter_id,
		az => $room->az,
	});
	my $new_room_id = $new_room->id;

	$t->put_ok( "/workspace/$global_ws_id/room", json => [$room_id, $new_room_id])
		->status_is(400, 'Cannot modify GLOBAL' )
		->json_is({ error => 'Cannot modify GLOBAL workspace' });

	my $bad_room_id = $uuid->create_str;
	$t->put_ok( "/workspace/$sub_ws_id/room", json => [$bad_room_id, $new_room_id])
		->status_is(409, 'bad room ids')
		->json_is({ error => "Datacenter room IDs must be members of the parent workspace: $bad_room_id" });

	$t->put_ok("/workspace/$sub_ws_id/room", json => [$room_id, $new_room_id])
		->status_is( 200, 'Replaced datacenter rooms' )
		->json_schema_is('Rooms')
		->json_is('/0/id', $room_id)
		->json_is('/1/id', $new_room_id);

	$t->get_ok("/workspace/$sub_ws_id/room")
		->status_is(200)
		->json_schema_is('Rooms')
		->json_is('/0/id', $room_id)
		->json_is('/1/id', $new_room_id);

	$t->put_ok("/workspace/$sub_ws_id/room", json => [])
		->json_schema_is('Rooms')
		->status_is(200, 'Remove datacenter rooms')
		->json_is('', []);
};

my $rack_id;
subtest 'Workspace Racks' => sub {

	note(
"Variance: /rack in returns a hash keyed by datacenter room AZ instead of an array"
	);
	$t->get_ok("/workspace/$global_ws_id/rack")
		->status_is(200)
		->json_schema_is('WorkspaceRackSummary')
		->json_is('/test-region-1a/0/name', 'Test Rack', 'Has test datacenter rack');

	$rack_id = $t->tx->res->json->{'test-region-1a'}->[0]->{id};

	$t->get_ok("/workspace/$global_ws_id/rack/notauuid")
		->status_is(400)
		->json_like( '/error', qr/must be a UUID/ );
	$t->get_ok("/workspace/$global_ws_id/rack/" . $uuid->create_str())
		->status_is(404);

	subtest 'Add rack to workspace' => sub {
		$t->post_ok("/workspace/$sub_ws_id/rack")
			->status_is(400, 'Requires request body')
			->json_like('/error', qr/Expected object/);

		$t->post_ok("/workspace/$sub_ws_id/rack", json => {
				id => $rack_id,
				serial_number => 'abc',
				asset_tag => 'deadbeef',
			})
			->status_is(303)
			->header_like(Location => qr!/workspace/$sub_ws_id/rack/$rack_id!);

		$t->get_ok("/workspace/$sub_ws_id/rack")
			->status_is(200)
			->json_schema_is('WorkspaceRackSummary');

		$t->get_ok("/workspace/$sub_ws_id/rack/$rack_id")
			->status_is(200)
			->json_schema_is('WorkspaceRack');

		subtest 'Cannot modify GLOBAL workspace' => sub {
			$t->post_ok( "/workspace/$global_ws_id/rack", json => { id => $rack_id } )
				->status_is(400)
				->json_is({ error => 'Cannot modify GLOBAL workspace' });
		};
	};

	subtest 'Remove rack from workspace' => sub {
		$t->delete_ok("/workspace/$sub_ws_id/rack/$rack_id")
			->status_is(204);

		$t->get_ok("/workspace/$sub_ws_id/rack/$rack_id")
			->status_is(404)
			->json_like( '/error', qr/not found/ );

		$t->post_ok( "/workspace/$global_ws_id/rack", json => { id => $rack_id } )
			->status_is(400)
			->json_is({ error => 'Cannot modify GLOBAL workspace' });
	};

};

subtest 'Register relay' => sub {
	$t->post_ok(
		'/relay/deadbeef/register',
		json => {
			serial   => 'deadbeef',
			version  => '0.0.1',
			ipaddr   => '127.0.0.1',
			ssh_port => '22',
			alias    => 'test relay'
		}
	)->status_is(204);
};

subtest 'Device Report' => sub {
	my $report = path('t/integration/resource/passing-device-report.json')->slurp_utf8;
	$t->post_ok( '/device/TEST', { 'Content-Type' => 'application/json' }, $report )
		->status_is(200)
		->json_schema_is('ValidationState')
		->json_is( '/status', 'pass' );

	my $device = $t->app->db_devices->find($t->tx->res->json->{device_id});
	cmp_deeply(
		$device->latest_report,
		decode_json($report),
		'json blob stored in the db matches report on disk',
	);

	$t->get_ok("/workspace/$global_ws_id/problem")->status_is(200)
		->json_schema_is('Problems')
		->json_is('/unlocated/TEST/health', 'PASS', 'device is listed as unlocated');
};

subtest 'Assign device to a location' => sub {
	$t->post_ok(
		"/workspace/$global_ws_id/rack/$rack_id/layout",
		json => { TEST => 1 })
	->status_is(200)
	->json_schema_is('WorkspaceRackLayoutUpdateResponse')
	->json_is({ updated => [ 'TEST' ] });

	$t->get_ok("/workspace/$global_ws_id/problem")
		->status_is(200)
		->json_schema_is('Problems')
		->json_hasnt('/unlocated/TEST', 'device is no longer unlocated');

	$t->get_ok('/device/TEST/location')
		->status_is(200)
		->json_schema_is('DeviceLocation');

	$t->get_ok("/workspace/$global_ws_id/rack/$rack_id")
		->status_is(200)
		->json_schema_is('WorkspaceRack')
		->json_is(
			'/slots/0/rack_unit_start', 1,
			'/slots/0/occupant/id', 'TEST',
		);

	$t->get_ok("/workspace/$global_ws_id/rack/$rack_id" => { Accept => 'text/csv' })
		->status_is(200)
		->content_like(qr/^az,rack_name,rack_unit_start,hardware_name,device_asset_tag,device_serial_number$/m)
		->content_like(qr/^test-region-1a,"Test Rack",1,2-ssds-1-cpu,,TEST$/m);

	$t->get_ok("/workspace/$global_ws_id/rack")
		->status_is(200)
		->json_schema_is('WorkspaceRackSummary')
		->json_is('/test-region-1a/0/name', 'Test Rack', 'Has test datacenter rack');
};

subtest 'Single device' => sub {

	$t->get_ok('/device/nonexistant')
		->status_is(404)
		->json_like( '/error', qr/not found/ );

	$t->get_ok('/device/TEST')
		->status_is(200)
		->json_schema_is('DetailedDevice')
		->json_is('/latest_report/product_name' => 'Joyent-S1');

	my $device_id = $t->tx->res->json->{id};
	my @macs = map { $_->{mac} } $t->tx->res->json->{nics}->@*;

	$t->get_ok('/device/nonexistant')
		->status_is(404)
		->json_like( '/error', qr/not found/ );

	subtest 'get by device attributes' => sub {

		$t->get_ok('/device?hostname=elfo')
			->status_is(200)
			->json_schema_is('DetailedDevice')
			->json_is( '/id', $device_id, 'got device by hostname');

		$t->get_ok("/device?mac=$macs[0]")
			->status_is(200)
			->json_schema_is('DetailedDevice')
			->json_is( '/id', $device_id, 'got device by mac');

		# device_nics->[2] has ipaddr' => '172.17.0.173'.
		$t->get_ok("/device?ipaddr=172.17.0.173")
			->status_is(200)
			->json_schema_is('DetailedDevice')
			->json_is( '/id', $device_id, 'got device by ipaddr');
	};

	subtest 'mutate device attributes' => sub {
		$t->post_ok('/device/nonexistant/graduate')
			->status_is(404);

		$t->post_ok('/device/TEST/graduate')
			->status_is(303)
			->header_like( Location => qr!/device/TEST$! );

		$t->post_ok('/device/TEST/triton_setup')
			->status_is(409)
			->json_like( '/error',
			qr/must be marked .+ before it can be .+ set up for Triton/ );

		$t->post_ok('/device/TEST/triton_reboot')
			->status_is(303)
			->header_like( Location => qr!/device/TEST$! );

		$t->post_ok('/device/TEST/triton_uuid')
			->status_is( 400, 'Request body required' );

		$t->post_ok('/device/TEST/triton_uuid', json => { triton_uuid => 'not a UUID' })
			->status_is(400)
			->json_like('/error', qr/String does not match/);

		$t->post_ok('/device/TEST/triton_uuid', json => { triton_uuid => $uuid->create_str() })
			->status_is(303)
			->header_like( Location => qr!/device/TEST$! );

		$t->post_ok('/device/TEST/triton_setup')
			->status_is(303)
			->header_like( Location => qr!/device/TEST$! );

		$t->post_ok('/device/TEST/asset_tag')
			->status_is( 400, 'Request body required' );

		$t->post_ok('/device/TEST/asset_tag', json => { asset_tag => 'asset tag' })
			->status_is(400)
			->json_like('/error', qr/String does not match/);

		$t->post_ok('/device/TEST/asset_tag', json => { asset_tag => 'asset_tag' })
			->status_is(303)
			->header_like( Location => qr!/device/TEST$! );

		$t->post_ok('/device/TEST/validated')
			->status_is(303)
			->header_like( Location => qr!/device/TEST$! );

		$t->post_ok('/device/TEST/validated')
			->status_is(204)
			->content_is('');
	};

	subtest 'Device settings' => sub {
		$t->get_ok('/device/TEST/settings')
			->status_is(200)
			->content_is('{}');

		$t->get_ok('/device/TEST/settings/foo')
			->status_is(404);

		$t->post_ok('/device/TEST/settings')
			->status_is( 400, 'Requires body' )
			->json_like( '/error', qr/required/ );

		$t->post_ok( '/device/TEST/settings', json => { foo => 'bar' } )
			->status_is(200)
			->content_is('');

		$t->get_ok('/device/TEST/settings')
			->status_is(200)
			->json_is( '/foo', 'bar', 'Setting was stored' );

		$t->get_ok('/device/TEST/settings/foo')
			->status_is(200)
			->json_is( '/foo', 'bar', 'Setting was stored' );

		$t->post_ok( '/device/TEST/settings/fizzle',
			json => { no_match => 'gibbet' } )
			->status_is( 400, 'Fail if parameter and key do not match' );

		$t->post_ok( '/device/TEST/settings/fizzle',
			json => { fizzle => 'gibbet' } )
			->status_is(200);

		$t->get_ok('/device/TEST/settings/fizzle')
			->status_is(200)
			->json_is( '/fizzle', 'gibbet' );

		$t->delete_ok('/device/TEST/settings/fizzle')
			->status_is(204)
			->content_is('');

		$t->get_ok('/device/TEST/settings/fizzle')
			->status_is(404)
			->json_like( '/error', qr/fizzle/ );

		$t->delete_ok('/device/TEST/settings/fizzle')
			->status_is(404)
			->json_like( '/error', qr/fizzle/ );

		$t->post_ok( '/device/TEST/settings',
			json => { 'tag.foo' => 'foo', 'tag.bar' => 'bar' } )->status_is(200);

		$t->post_ok( '/device/TEST/settings/tag.bar',
			json => { 'tag.bar' => 'newbar' } )->status_is(200);

		$t->get_ok('/device/TEST/settings/tag.bar')->status_is(200)
			->json_is( '/tag.bar', 'newbar', 'Setting was updated' );

		$t->delete_ok('/device/TEST/settings/tag.bar')->status_is(204)
			->content_is('');

		$t->get_ok('/device/TEST/settings/tag.bar')->status_is(404)
			->json_like( '/error', qr/tag\.bar/ );

		$t->get_ok('/device?foo=bar')->status_is(200)
			->json_is('/id', 'TEST', 'got device by arbitrary setting key');
	};

};

subtest 'Workspace devices' => sub {

	$t->get_ok("/workspace/$global_ws_id/device")->status_is(200)
		->json_is( '/0/id', 'TEST' );

	$t->get_ok("/workspace/$global_ws_id/device?graduated=f")
		->status_is(200)
		->json_schema_is('Devices')
		->json_is( '', [] );
	$t->get_ok("/workspace/$global_ws_id/device?graduated=F")
		->status_is(200)
		->json_schema_is('Devices')
		->json_is( '', [] );

	$t->get_ok("/workspace/$global_ws_id/device?graduated=t")
		->status_is(200)
		->json_schema_is('Devices')
		->json_is( '/0/id', 'TEST' );
	$t->get_ok("/workspace/$global_ws_id/device?graduated=T")
		->status_is(200)
		->json_schema_is('Devices')
		->json_is( '/0/id', 'TEST' );

	$t->get_ok("/workspace/$global_ws_id/device?health=fail")
		->status_is(200)
		->json_schema_is('Devices')
		->json_is( '', [] );

	$t->get_ok("/workspace/$global_ws_id/device?health=FAIL")
		->status_is(200)
		->json_schema_is('Devices')
		->json_is( '', [] );

	$t->get_ok("/workspace/$global_ws_id/device?health=pass")
		->status_is(200)
		->json_schema_is('Devices')
		->json_is( '/0/id', 'TEST' );

	$t->get_ok("/workspace/$global_ws_id/device?health=PASS")
		->status_is(200)
		->json_schema_is('Devices')
		->json_is( '/0/id', 'TEST' );

	$t->get_ok("/workspace/$global_ws_id/device?health=pass&graduated=t")
		->status_is(200)
		->json_schema_is('Devices')
		->json_is( '/0/id', 'TEST' );
	$t->get_ok("/workspace/$global_ws_id/device?health=pass&graduated=f")
		->status_is(200)
		->json_schema_is('Devices')
		->json_is( '', [] );

	$t->get_ok("/workspace/$global_ws_id/device?ids_only=1")
		->status_is(200)
		->content_is('["TEST"]');

	$t->get_ok("/workspace/$global_ws_id/device?ids_only=1&health=pass")
		->status_is(200)
		->content_is('["TEST"]');

	$t->get_ok("/workspace/$global_ws_id/device?active=t")
		->status_is(200)
		->json_schema_is('Devices')
		->json_is( '/0/id', 'TEST' );

	$t->get_ok("/workspace/$global_ws_id/device?active=t&graduated=t")
		->status_is(200)
		->json_schema_is('Devices')
		->json_is( '/0/id', 'TEST' );

	# /device/active redirects to /device so first make sure there is a redirect,
	# then follow it and verify the results
	subtest 'Redirect /workspace/:id/device/active' => sub {
		$t->get_ok("/workspace/$global_ws_id/device/active")
			->status_is(302);

		my $temp = $t->ua->max_redirects;
		$t->ua->max_redirects(1);

		$t->get_ok("/workspace/$global_ws_id/device/active")
			->status_is(200)
			->json_is( '/0/id', 'TEST' );

		$t->ua->max_redirects($temp);
	};
};

subtest 'Relays' => sub {
	$t->get_ok("/workspace/$global_ws_id/relay")
		->status_is(200)
		->json_schema_is('WorkspaceRelays')
		->json_is( '/0/id', 'deadbeef', 'Has relay from reporting device' )
		->json_is( '/0/devices/0/id', 'TEST', 'Associated with reporting device' );

	$t->get_ok("/workspace/$global_ws_id/relay?active=1")
		->status_is(200)
		->json_schema_is('WorkspaceRelays')
		->json_is( '/0/id', 'deadbeef', 'Has active relay' );

	$t->get_ok('/relay')
		->status_is(200)
		->json_schema_is('Relays')
		->json_is( '/0/id' => 'deadbeef' );

	$t->get_ok("/workspace/$global_ws_id/relay?no_devices=0")
		->status_is(200)
		->json_schema_is('WorkspaceRelays')
		->json_is( '/0/id', 'deadbeef', 'Has relay from reporting device' )
		->json_is( '/0/devices/0/id', 'TEST', 'Associated with reporting device' );

	$t->get_ok("/workspace/$global_ws_id/relay?no_devices=1")->status_is(200)
		->json_schema_is('WorkspaceRelays')
		->json_is( '/0/id', 'deadbeef' )
		->json_is( '/0/devices', [] );

};

subtest 'Validations' => sub {
	$t->get_ok('/validation')
		->status_is(200)
		->json_schema_is('Validations');

	my $validation_id = $t->tx->res->json->[0]->{id};
	my @validations = $t->tx->res->json->@*;

	$t->post_ok('/validation_plan', json => { name => 'my_test_plan', description => 'another test plan' })
		->status_is(303);

	$t->get_ok($t->tx->res->headers->location)
		->status_is(200)
		->json_schema_is('ValidationPlan');

	my $validation_plan_id = $t->tx->res->json->{id};

	$t->get_ok('/validation_plan')
		->status_is(200)
		->json_schema_is('ValidationPlans')
		->json_cmp_deeply([
			{
				id => ignore,
				name => 'Conch v1 Legacy Plan: Server',
				description => 'Test Plan',
				created => ignore,
			},
			{
				id => $validation_plan_id,
				name => 'my_test_plan',
				description => 'another test plan',
				created => ignore,
			},
		]);

	my @plans = $t->tx->res->json->@*;

	$t->get_ok("/validation_plan/$validation_plan_id")
		->status_is(200)
		->json_schema_is('ValidationPlan')
		->json_is($plans[1]);

	$t->post_ok("/validation_plan/$validation_plan_id/validation",
			json => { id => $validation_id })
		->status_is(204);

	$t->post_ok("/validation_plan/$validation_plan_id/validation",
			json => { id => $validation_id })
		->status_is(204, 'adding a validation to a plan twice is not an error');

	$t->post_ok('/validation_plan',
			json => { name => 'my_test_plan', description => 'test plan' })
		->status_is(409)
		->json_is({ error => "A Validation Plan already exists with the name 'my_test_plan'" });

	$t->get_ok('/validation_plan')
		->status_is(200)
		->json_schema_is('ValidationPlans')
		->json_is(\@plans);

	$t->get_ok("/validation_plan/$validation_plan_id/validation")
		->status_is(200)
		->json_schema_is('Validations')
		->json_is([ $validations[0] ]);

	subtest 'test validating a device' => sub {
		$t->post_ok("/device/TEST/validation/$validation_id", json => {})
			->status_is(200)
			->json_schema_is('ValidationResults')
			->json_cmp_deeply([ superhashof({
				id => undef,
				device_id => 'TEST',
			}) ]);

		my $validation_results = $t->tx->res->json;

		$t->post_ok("/device/TEST/validation_plan/$validation_plan_id", json => {})
			->status_is(200)
			->json_schema_is('ValidationResults')
			->json_is($validation_results);
	};

	$t->delete_ok("/validation_plan/$validation_plan_id/validation/$validation_id")
		->status_is(204);

	$t->get_ok("/validation_plan/$validation_plan_id/validation")
		->status_is(200)
		->json_is('', []);

	my $device = $t->app->db_devices->find('TEST');
	my $validation = $t->app->db_validations
		->search({ id => { '!=' => $validation_id } })
		->rows(1)->single;	# other random validation

	# manually create a failing validation result... ew ew ew.
	# this uses the new validation plan, which is guaranteed to be different from the passing
	# valdiation that got recorded for this device via the report earlier.
	my $validation_state = $t->app->db_validation_states->create({
		device_id => 'TEST',
		validation_plan_id => $validation_plan_id,
		status => 'fail',
		completed => \'NOW()',
		validation_state_members => [{
			validation_result => {
				device_id => 'TEST',
				hardware_product_id => $device->hardware_product_id,
				validation_id => $validation->id,
				message => 'faked failure',
				hint => 'boo',
				status => 'fail',
				category => 'test',
				result_order => 0,
			},
		}],
	});

	# record another, older, failing test using the same plan.
	$t->app->db_validation_states->create({
		device_id => 'TEST',
		validation_plan_id => $validation_plan_id,
		status => 'fail',
		completed => '2001-01-01',
		validation_state_members => [{
			validation_result => {
				created => '2001-01-01',
				device_id => 'TEST',
				hardware_product_id => $device->hardware_product_id,
				validation_id => $validation->id,
				message => 'earlier failure',
				hint => 'boo',
				status => 'fail',
				category => 'test',
				result_order => 0,
			},
		}],
	});

	$t->get_ok('/device/TEST/validation_state')
		->status_is(200)
		->json_schema_is('ValidationStatesWithResults')
		->json_cmp_deeply(bag(
			{
				id => ignore,
				validation_plan_id => ignore,
				device_id => 'TEST',
				completed => ignore,
				created => ignore,
				status => 'pass',	# we force-validated this device earlier
				results => [ ignore ],
			},
			{
				id => $validation_state->id,
				validation_plan_id => $validation_plan_id,
				device_id => 'TEST',
				completed => ignore,
				created => ignore,
				status => 'fail',
				results => [ {
					id => ignore,
					device_id => 'TEST',
					hardware_product_id => $device->hardware_product_id,
					validation_id => $validation->id,
					component_id => undef,
					message => 'faked failure',
					hint => 'boo',
					status => 'fail',
					category => 'test',
					order => 0,
				} ],
			},
		));

	my $validation_states = $t->tx->res->json;

	$t->get_ok('/device/TEST/validation_state?status=pass')
		->status_is(200)
		->json_schema_is('ValidationStatesWithResults')
		->json_is([ grep { $_->{status} eq 'pass' } $validation_states->@* ]);

	$t->get_ok('/device/TEST/validation_state?status=fail')
		->status_is(200)
		->json_schema_is('ValidationStatesWithResults')
		->json_is([ grep { $_->{status} eq 'fail' } $validation_states->@* ]);

	$t->get_ok('/device/TEST/validation_state?status=error')
		->status_is(200)
		->json_schema_is('ValidationStatesWithResults')
		->json_is('', []);

	$t->get_ok('/device/TEST/validation_state?status=pass,fail')
		->status_is(200)
		->json_schema_is('ValidationStatesWithResults')
		->json_is($validation_states);

	$t->get_ok('/device/TEST/validation_state?status=pass,bar')
		->status_is(400)
		->json_is({ error => "'status' query parameter must be any of 'pass', 'fail', or 'error'." });
};

subtest 'Device location' => sub {
	$t->post_ok('/device/TEST/location')
		->status_is(400, 'requires body')
		->json_like('/error', qr/Expected object/);

	$t->post_ok( '/device/TEST/location',
		json => { rack_id => $rack_id, rack_unit => 3 } )->status_is(303)
		->header_like( Location => qr!/device/TEST/location$! );

	$t->delete_ok('/device/TEST/location')->status_is(204, 'can delete device location');

	$t->post_ok( '/device/TEST/location',
		json => { rack_id => $rack_id, rack_unit => 3 })->status_is(303, 'add it back');
};

subtest 'Log out' => sub {
	$t->post_ok("/logout")->status_is(204);
	$t->get_ok("/workspace")->status_is(401);
};

subtest 'Permissions' => sub {
	my $ro_name = 'wat';
	my $ro_email = 'readonly@wat.wat';
	my $ro_pass = 'password';

	subtest "Read-only" => sub {

		my $ro_user = $t->app->db_user_accounts->create({
			name => $ro_name,
			email => $ro_email,
			password => $ro_pass,
			user_workspace_roles => [{
				workspace_id => $global_ws_id,
				role => 'ro',
			}],
		});

		$t->post_ok(
			"/login" => json => {
				user     => $ro_email,
				password => $ro_pass,
			}
		)->status_is(200);
		BAIL_OUT("Login failed") if $t->tx->res->code != 200;

		$t->get_ok('/workspace')
			->status_is(200)
			->json_schema_is('WorkspacesAndRoles')
			->json_is( '/0/name', 'GLOBAL' );

		subtest "Can't create a subworkspace" => sub {
			$t->post_ok(
				"/workspace/$global_ws_id/child" => json => {
					name        => "test",
					description => "also test",
				}
			)->status_is(403)
			->json_is({ error => 'Forbidden' });
		};

		subtest "Can't add a rack" => sub {
			$t->post_ok( "/workspace/$global_ws_id/rack", json => { id => $rack_id } )
				->status_is(403)
				->json_is({ error => 'Forbidden' });
		};

		subtest "Can't set a rack layout" => sub {
			$t->post_ok(
				"/workspace/$global_ws_id/rack/$rack_id/layout",
				json => {
					TEST => 1
				}
			)->status_is(403)
			->json_is({ error => 'Forbidden' });
		};

		subtest "Can't add a user to workspace" => sub {
			$t->post_ok(
				"/workspace/$global_ws_id/user",
				json => {
					user => 'another@wat.wat',
					role => 'ro',
				}
			)->status_is(403)
			->json_is({ error => 'Forbidden' });
		};

		subtest "Can't get a relay list" => sub {
			$t->get_ok("/relay")->status_is(403);
		};

		$t->get_ok("/workspace/$global_ws_id/user")
			->status_is(200, 'get list of users for this workspace')
			->json_schema_is('WorkspaceUsers')
			->json_cmp_deeply(bag(
				{
					id => ignore,
					name => 'conch',
					email => 'conch@conch.joyent.us',
					role => 'admin',
				},
				{
					id => $ro_user->id,
					name => $ro_name,
					email => $ro_email,
					role => 'ro',
				},
			));

		subtest 'device settings' => sub {
			$t->post_ok('/device/TEST/settings', json => { name => 'new value' })
				->status_is(403)
				->json_is({ error => 'insufficient permissions' });
			$t->post_ok('/device/TEST/settings/foo', json => { foo => 'new_value' })
				->status_is(403)
				->json_is({ error => 'insufficient permissions' });
			$t->delete_ok('/device/TEST/settings/foo')
				->status_is(403)
				->json_is({ error => 'insufficient permissions' });
		};

		$t->post_ok("/logout")->status_is(204);
	};

	subtest "Read-write" => sub {
		my $name = 'integrator';
		my $email = 'integrator@wat.wat';
		my $pass = 'password';

		my $user = $t->app->db_user_accounts->create({
			name => $name,
			email => $email,
			password => $pass,
			user_workspace_roles => [{
				workspace_id => $global_ws_id,
				role => 'rw',
			}],
		});

		$t->post_ok(
			"/login" => json => {
				user     => $email,
				password => $pass,
			}
		)->status_is(200);

		$t->get_ok('/workspace')
			->status_is(200)
			->json_schema_is('WorkspacesAndRoles')
			->json_is( '/0/name', 'GLOBAL' );

		subtest "Can't create a subworkspace" => sub {
			$t->post_ok(
				"/workspace/$global_ws_id/child" => json => {
					name        => "test",
					description => "also test",
				}
			)->status_is(403)
			->json_is({ error => 'Forbidden' });
		};

		subtest "Can't add a user to workspace" => sub {
			$t->post_ok(
				"/workspace/$global_ws_id/user",
				json => {
					user => 'another@wat.wat',
					role => 'ro',
				}
			)->status_is(403)
			->json_is({ error => 'Forbidden' });
		};

		subtest "Can't get a relay list" => sub {
			$t->get_ok("/relay")->status_is(403);
		};

		$t->get_ok("/workspace/$global_ws_id/user")
			->status_is(200, 'get list of users for this workspace')
			->json_schema_is('WorkspaceUsers')
			->json_cmp_deeply(bag(
				{
					id => ignore,
					name => 'conch',
					email => 'conch@conch.joyent.us',
					role => 'admin',
				},
				{
					id => ignore,
					name => $ro_name,
					email => $ro_email,
					role => 'ro',
				},
				{
					id => $user->id,
					name => $name,
					email => $email,
					role => 'rw',
				},
			));

		subtest 'device settings' => sub {
			$t->post_ok('/device/TEST/settings', json => { newkey => 'new value' })
				->status_is(200, 'writing new key only requires rw');
			$t->post_ok('/device/TEST/settings/foo', json => { foo => 'new_value' })
				->status_is(403)
				->json_is({ error => 'insufficient permissions' });
			$t->delete_ok('/device/TEST/settings/foo')
				->status_is(403)
				->json_is({ error => 'insufficient permissions' });

			$t->post_ok('/device/TEST/settings', json => { 'foo' => 'foo', 'tag.bar' => 'bar' })
				->status_is(403)
				->json_is({ error => 'insufficient permissions' });
			$t->post_ok('/device/TEST/settings', json => { 'tag.foo' => 'foo', 'tag.bar' => 'bar' })
				->status_is(200);

			$t->post_ok('/device/TEST/settings/tag.bar',
				json => { 'tag.bar' => 'newbar' } )->status_is(200);
			$t->get_ok('/device/TEST/settings/tag.bar')->status_is(200)
				->json_is('/tag.bar', 'newbar', 'Setting was updated');
			$t->delete_ok('/device/TEST/settings/tag.bar')->status_is(204)
				->content_is('');
			$t->get_ok('/device/TEST/settings/tag.bar')->status_is(404)
				->json_is({ error => 'No such setting \'tag.bar\'' });
		};

		$t->post_ok("/logout")->status_is(204);
	};
};

done_testing();
