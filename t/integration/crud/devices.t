use v5.26;
use Mojo::Base -strict, -signatures;

use Test::More;
use Test::Warnings;
use Path::Tiny;
use Test::Deep;
use Test::Conch;
use Conch::UUID 'create_uuid_str';
use Mojo::JSON 'from_json';

my $t = Test::Conch->new;
$t->load_fixture_set('workspace_room_rack_layout', 0);

$t->load_validation_plans([{
    name        => 'Conch v1 Legacy Plan: Server',
    description => 'Test Plan',
    validations => [ 'Conch::Validation::DeviceProductName' ],
}]);

my $rack = $t->load_fixture('rack_0a');
my $rack_id = $rack->id;
my $hardware_product_id = $t->load_fixture('hardware_product_compute')->id;

# perform most tests as a user with read only access to the GLOBAL workspace
my $null_user = $t->load_fixture('null_user');
my $ro_user = $t->load_fixture('ro_user_global_workspace')->user_account;
my $rw_user = $t->load_fixture('rw_user_global_workspace')->user_account;
my $admin_user = $t->load_fixture('conch_user_global_workspace')->user_account;
$t->authenticate(email => $ro_user->email);

$t->get_ok('/device/nonexistent')
    ->status_is(404);

my $test_device_id;

subtest 'unlocated device, no registered relay' => sub {
    my $report_data = from_json(path('t/integration/resource/passing-device-report.json')->slurp_utf8);
    $t->post_ok('/device/TEST', json => $report_data)
        ->status_is(409)
        ->json_schema_is('Error')
        ->json_is({ error => 'relay serial deadbeef is not registered' });

    delete $report_data->{relay};

    $t->post_ok('/device/TEST', json => $report_data)
        ->status_is(200)
        ->json_schema_is('ValidationStateWithResults');

    $test_device_id = $t->tx->res->json->{device_id};
    my $device_report_id = $t->tx->res->json->{device_report_id};

    $t->get_ok('/device/TEST')
        ->status_is(403, 'unlocated device isn\'t visible to a ro user');

    $t->get_ok('/device_report/'.$device_report_id)
        ->status_is(403, 'unlocated device report isn\'t visible to a ro user');

    {
        $t->authenticate(email => $admin_user->email);

        $t->get_ok('/device/TEST')
            ->status_is(200)
            ->json_schema_is('DetailedDevice', 'devices are always visible to a sysadmin user')
            ->json_is('/id', $test_device_id)
            ->json_is('/serial_number', 'TEST');

        $t->get_ok('/device/'.$test_device_id)
            ->status_is(200)
            ->json_schema_is('DetailedDevice')
            ->json_is('/id', $test_device_id)
            ->json_is('/serial_number', 'TEST');

        $t->get_ok('/device_report/'.$device_report_id)
            ->status_is(200)
            ->json_schema_is('DeviceReportRow', 'device reports are always visible to a sysadmin user');

        $t->authenticate(email => $ro_user->email);
    }
};

subtest 'unlocated device with a registered relay' => sub {
    $t->post_ok('/relay/deadbeef/register', json => { serial => 'deadbeef' })
        ->status_is(201);

    my $report = path('t/integration/resource/passing-device-report.json')->slurp_utf8;
    $t->post_ok('/device/TEST', { 'Content-Type' => 'application/json' }, $report)
        ->status_is(200)
        ->json_schema_is('ValidationStateWithResults');

    my $validation_state = $t->tx->res->json;

    $t->get_ok('/device_report/'.$validation_state->{device_report_id})
        ->status_is(200)
        ->json_schema_is('DeviceReportRow')
        ->json_cmp_deeply({
            id => $validation_state->{device_report_id},
            device_id => $test_device_id,
            report => from_json($report),
            created => re(qr/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{3,9}Z$/),
        });

    $t->get_ok('/device/TEST')
        ->status_is(200)
        ->json_schema_is('DetailedDevice')
        ->json_cmp_deeply({
            id => $test_device_id,
            serial_number => 'TEST',
            health => 'pass',
            hostname => 'elfo',
            system_uuid => ignore,
            phase => 'integration',
            (map +($_ => undef), qw(asset_tag uptime_since validated)),
            (map +($_ => re(qr/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{3,9}Z$/)), qw(created updated last_seen)),
            hardware_product_id => $hardware_product_id,
            location => undef,
            latest_report => from_json($report),
            nics => supersetof(),
            disks => supersetof(superhashof({ serial_number => 'BTHC640405WM1P6PGN' })),
        });

    $t->app->db_device_disks->deactivate;
    $t->get_ok('/device/TEST')
        ->status_is(200)
        ->json_schema_is('DetailedDevice')
        ->json_cmp_deeply({
            id => $test_device_id,
            serial_number => 'TEST',
            health => 'pass',
            hostname => 'elfo',
            system_uuid => ignore,
            phase => 'integration',
            (map +($_ => undef), qw(asset_tag uptime_since validated)),
            (map +($_ => re(qr/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{3,9}Z$/)), qw(created updated last_seen)),
            hardware_product_id => $hardware_product_id,
            location => undef,
            latest_report => superhashof({ product_name => 'Joyent-G1' }),
            nics => supersetof(),
            disks => [],
        });

    $t->get_ok('/validation_state/'.$validation_state->{id})
        ->status_is(200)
        ->json_schema_is('ValidationStateWithResults')
        ->json_is($validation_state);

    $t->authenticate(email => $null_user->email);
    $t->get_ok('/device/TEST')
        ->status_is(403, 'cannot see device without the relay connection');

    $t->get_ok('/device_report/'.$validation_state->{device_report_id})
        ->status_is(403, 'cannot see device report without the relay connection');

    {
        $null_user->update({ is_admin => 1 });

        $t->get_ok('/device/TEST')
            ->status_is(200)
            ->json_schema_is('DetailedDevice', 'devices are always visible to a sysadmin user');

        $t->get_ok('/device_report/'.$validation_state->{device_report_id})
            ->status_is(200)
            ->json_schema_is('DeviceReportRow', 'device reports are always visible to a sysadmin user');

        $null_user->update({ is_admin => 0 });

        $t->authenticate(email => $ro_user->email);
    }
};

my $located_device_id;

subtest 'located device' => sub {
    # create the device in the requested rack location
    my $device = $t->app->db_devices->create({
        serial_number => 'LOCATED_DEVICE',
        hardware_product_id => $t->app->db_rack_layouts->search({ rack_id => $rack_id, rack_unit_start => 1 })->get_column('hardware_product_id')->as_query,
        health  => 'unknown',
        device_location => { rack_id => $rack_id, rack_unit_start => 1 },
    });

    $located_device_id = $device->id;

    $t->get_ok('/device/'.$located_device_id)
        ->status_is(200)
        ->json_schema_is('DetailedDevice')
        ->json_cmp_deeply({
            id => $located_device_id,
            serial_number => 'LOCATED_DEVICE',
            health => 'unknown',
            phase => 'integration',
            (map +($_ => undef), qw(asset_tag hostname last_seen system_uuid uptime_since validated)),
            (map +($_ => re(qr/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{3,9}Z$/)), qw(created updated)),
            hardware_product_id => $hardware_product_id,
            location => {
                rack => {
                    (map +($_ => $rack->$_), qw(id name datacenter_room_id serial_number asset_tag phase)),
                    rack_role_id => $rack->rack_role_id,
                    (map +($_ => re(qr/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{3,9}Z$/)), qw(created updated)),
                },
                rack_unit_start => 1,
                datacenter => ignore,
                datacenter_room => superhashof({ az => 'room-0a' }),
                target_hardware_product => superhashof({ alias => 'Test Compute' }),
            },
            latest_report => undef,
            nics => [],
            disks => [],
        });

    $t->txn_local('remove device from its workspace', sub ($t) {
        $t->app->db_workspace_racks->delete;
        $t->get_ok('/device/LOCATED_DEVICE')
            ->status_is(403, 'device isn\'t in a workspace anymore');
    });

    # TODO: permissions for PUT, DELETE queries

    subtest 'permissions for POST queries' => sub {
        my @queries = (
            '/device/LOCATED_DEVICE/validated',
            [ '/device/LOCATED_DEVICE/phase', json => { phase => 'installation' } ],
        );

        $t->authenticate(email => $rw_user->email);
        foreach my $query (@queries) {
            $t->post_ok(ref $query ? $query->@* : $query)
                ->status_is(303)
                ->location_is('/device/'.$located_device_id);
        }

        # now switch back to ro_user...
        $t->authenticate(email => $ro_user->email);
        foreach my $query (@queries) {
            $t->post_ok(ref $query ? $query->@* : $query)
                ->status_is(403);
        }
    };

    subtest 'permissions for GET queries' => sub {
        $t->app->db_devices->search({ id => $located_device_id })->update({
            hostname => 'Luci',
        });
        $t->app->db_device_settings->create({
            device_id => $located_device_id,
            name => 'hello',
            value => 'world',
        });
        $t->app->db_device_nics->create({
            device_id => $located_device_id,
            iface_name => 'home',
            iface_type => 'me',
            iface_vendor => 'me',
            mac => '00:00:00:00:00:00',
            ipaddr => '127.0.0.1',
        });

        my @queries = (
            '/device/LOCATED_DEVICE',
            '/device/LOCATED_DEVICE/location',
            '/device/LOCATED_DEVICE/settings',
            '/device/LOCATED_DEVICE/settings/hello',
            '/device/LOCATED_DEVICE/validation_state',
            '/device/LOCATED_DEVICE/interface',
            '/device/LOCATED_DEVICE/phase',
            # TODO: filter search results for permissions
            #'/device?hostname=Luci',
            #'/device?mac=00:00:00:00:00:00',
            #'/device?ipaddr=127.0.0.1',
        );

        foreach my $query (@queries) {
            $t->get_ok($query)
                ->status_is(200);
        }

        $t->txn_local('remove all workspace permissions', sub ($t) {
            $t->app->db_user_workspace_roles->delete;

            foreach my $query (@queries) {
                $t->get_ok($query)
                    ->status_is(403);
            }

            $ro_user->update({ is_admin => 1 });
            foreach my $query (@queries) {
                $t->get_ok($query)
                    ->status_is(200);
            }
            $ro_user->update({ is_admin => 0 });
        });
    };
};

subtest 'device network interfaces' => sub {
    $t->get_ok('/device/TEST/interface')
        ->status_is(200)
        ->json_schema_is('DeviceNics');

    $t->get_ok('/device/TEST/interface/ipmi1')
        ->status_is(200)
        ->json_schema_is('DeviceNic');

    $t->get_ok('/device/TEST/interface/ipmi1/device_id')
        ->status_is(404);

    $t->get_ok('/device/TEST/interface/ipmi1/created')
        ->status_is(404);

    $t->get_ok('/device/TEST/interface/ipmi1/mac')
        ->status_is(200)
        ->json_schema_is('DeviceNicField')
        ->json_is({ mac => '18:66:da:78:d9:b3' });

    $t->get_ok('/device/TEST/interface/ipmi1/ipaddr')
        ->status_is(200)
        ->json_schema_is('DeviceNicField')
        ->json_is({ ipaddr => '10.72.160.146' });
};

$t->get_ok('/device/TEST')
    ->status_is(200)
    ->json_schema_is('DetailedDevice');

my $detailed_device = $t->tx->res->json;

$t->app->db_device_nics->create({
    mac => '00:00:00:00:00:0'.$_,
    device_id => $test_device_id,
    iface_name => $_,
    iface_type => 'foo',
    iface_vendor => 'bar',
    iface_driver => 'baz',
    deactivated => \'now()',
}) foreach (7..9);

$t->get_ok('/device/TEST')
    ->status_is(200)
    ->json_schema_is('DetailedDevice')
    ->json_is($detailed_device);

my @macs = map $_->{mac}, $detailed_device->{nics}->@*;

my $undetailed_device = {
    $detailed_device->%*,
    ($t->app->db_device_locations->search({ device_id => $test_device_id })->hri->single // {})->%{qw(rack_id rack_unit_start)},
};
delete $undetailed_device->@{qw(latest_report location nics disks)};

subtest 'get by device attributes' => sub {
    $t->get_ok('/device?hostname=elfo')
        ->status_is(200)
        ->json_schema_is('Devices')
        ->json_is('', [ $undetailed_device ], 'got device by hostname');

    $t->get_ok("/device?mac=$macs[0]")
        ->status_is(200)
        ->json_schema_is('Devices')
        ->json_is('', [ $undetailed_device ], 'got device by mac');

    # device_nics->[2] has ipaddr' => '172.17.0.173'.
    $t->get_ok('/device?ipaddr=172.17.0.173')
        ->status_is(200)
        ->json_schema_is('Devices')
        ->json_is('', [ $undetailed_device ], 'got device by ipaddr');
};

subtest 'mutate device attributes' => sub {
    $t->post_ok('/device/nonexistent/validate')
        ->status_is(404);

    $t->post_ok('/device/TEST/asset_tag')
        ->status_is(400)
        ->json_schema_is('RequestValidationError')
        ->json_cmp_deeply('/details', [ { path => '/', message => re(qr/expected object/i) } ]);

    $t->post_ok('/device/TEST/asset_tag', json => { asset_tag => 'asset tag' })
        ->status_is(400)
        ->json_schema_is('RequestValidationError')
        ->json_cmp_deeply('/details', [ { path => '/asset_tag', message => re(qr/string does not match/i) } ]);

    $t->post_ok('/device/TEST/asset_tag', json => { asset_tag => 'asset_tag' })
        ->status_is(303)
        ->location_is('/device/'.$test_device_id);

    $t->post_ok('/device/TEST/asset_tag', json => { asset_tag => undef })
        ->status_is(303)
        ->location_is('/device/'.$test_device_id);

    $t->post_ok('/device/TEST/validated')
        ->status_is(303)
        ->location_is('/device/'.$test_device_id);
    $detailed_device->{validated} = re(qr/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{3,9}Z$/);

    $t->post_ok('/device/TEST/validated')
        ->status_is(204);

    $t->post_ok('/device/TEST/phase', json => { phase => 'decommissioned' })
        ->status_is(303)
        ->location_is('/device/'.$test_device_id);
    $detailed_device->{phase} = 'decommissioned';

    $t->get_ok('/device/TEST/phase')
        ->status_is(200)
        ->json_schema_is('DevicePhase')
        ->json_is({ id => $test_device_id, phase => 'decommissioned' });

    $t->get_ok('/device/TEST')
        ->status_is(200)
        ->json_schema_is('DetailedDevice')
        ->json_cmp_deeply({
            $detailed_device->%*,
            updated => re(qr/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{3,9}Z$/),
        });
};

subtest 'Device settings' => sub {
    # device settings that check for 'admin' permission need the device to have a location
    $t->authenticate(email => $admin_user->email);

    $t->app->db_device_settings->search({ device_id => $located_device_id })->delete;

    $t->get_ok('/device/LOCATED_DEVICE/settings')
        ->status_is(200)
        ->json_schema_is('DeviceSettings')
        ->json_is({});

    $t->get_ok('/device/LOCATED_DEVICE/settings/foo')
        ->status_is(404);

    $t->post_ok('/device/LOCATED_DEVICE/settings')
        ->status_is(400)
        ->json_schema_is('RequestValidationError')
        ->json_cmp_deeply('/details', [ { path => '/', message => re(qr/expected object/i) } ]);

    $t->post_ok('/device/LOCATED_DEVICE/settings/FOO/BAR', json => { 'FOO/BAR' => 1 })
        ->status_is(404);

    $t->post_ok('/device/LOCATED_DEVICE/settings', json => { foo => 'bar' })
        ->status_is(204);

    $t->get_ok('/device/LOCATED_DEVICE/settings')
        ->status_is(200)
        ->json_schema_is('DeviceSettings')
        ->json_is('/foo', 'bar', 'Setting was stored');

    $t->get_ok('/device/LOCATED_DEVICE/settings/foo')
        ->status_is(200)
        ->json_schema_is('DeviceSetting')
        ->json_is('/foo', 'bar', 'Setting was stored');

    $t->post_ok('/device/LOCATED_DEVICE/settings/foo', json => { foo => { bar => 'baz' } })
        ->status_is(400)
        ->json_schema_is('RequestValidationError')
        ->json_cmp_deeply('/details', [ { path => '/foo', message => re(qr/expected string.*got object/i) } ]);

    $t->post_ok('/device/LOCATED_DEVICE/settings/fizzle', json => { no_match => 'gibbet' })
        ->status_is(400);

    $t->post_ok('/device/LOCATED_DEVICE/settings/fizzle', json => { fizzle => 'gibbet' })
        ->status_is(204);

    $t->get_ok('/device/LOCATED_DEVICE/settings/fizzle')
        ->status_is(200)
        ->json_schema_is('DeviceSetting')
        ->json_is('/fizzle', 'gibbet');

    $t->delete_ok('/device/LOCATED_DEVICE/settings/fizzle')
        ->status_is(204);

    $t->get_ok('/device/LOCATED_DEVICE/settings/fizzle')
        ->status_is(404);

    $t->delete_ok('/device/LOCATED_DEVICE/settings/fizzle')
        ->status_is(404);

    $t->post_ok('/device/LOCATED_DEVICE/settings', json => { 'tag.foo' => 'foo', 'tag.bar' => 'bar' })
        ->status_is(204);

    $t->post_ok('/device/LOCATED_DEVICE/settings/tag.bar', json => { 'tag.bar' => 'newbar' })
        ->status_is(204);

    $t->get_ok('/device/LOCATED_DEVICE/settings/tag.bar')
        ->status_is(200)
        ->json_schema_is('DeviceSetting')
        ->json_is('/tag.bar', 'newbar', 'Setting was updated');

    $t->delete_ok('/device/LOCATED_DEVICE/settings/tag.bar')
        ->status_is(204);

    $t->get_ok('/device/LOCATED_DEVICE/settings/tag.bar')
        ->status_is(404);

    $t->get_ok('/device/LOCATED_DEVICE')
        ->status_is(200)
        ->json_schema_is('DetailedDevice');

    my $detailed_device = $t->tx->res->json;

    my $undetailed_device = {
        $detailed_device->%*,
        ($t->app->db_device_locations->search({ device_id => $located_device_id })->hri->single // {})->%{qw(rack_id rack_unit_start)},
    };
    delete $undetailed_device->@{qw(latest_report location nics disks)};

    $t->get_ok('/device?foo=bar')
        ->status_is(200)
        ->json_schema_is('Devices')
        ->json_is('', [ $undetailed_device ], 'got device by arbitrary setting key');

    $t->authenticate(email => $ro_user->email);

    $t->post_ok('/device/LOCATED_DEVICE/settings/foo', json => { foo => 'new_value' })
        ->status_is(403);
    $t->post_ok('/device/LOCATED_DEVICE/settings', json => { name => 'new value' })
        ->status_is(403);
    $t->delete_ok('/device/LOCATED_DEVICE/settings/foo')
        ->status_is(403);

    $t->authenticate(email => $rw_user->email);

    $t->post_ok('/device/LOCATED_DEVICE/settings', json => { key => 'value' })
        ->status_is(204, 'writing new non-tag key only requires rw');
    $t->post_ok('/device/LOCATED_DEVICE/settings/key', json => { key => 'new value' })
        ->status_is(403);
    $t->delete_ok('/device/LOCATED_DEVICE/settings/foo')
        ->status_is(403);

    $t->post_ok('/device/LOCATED_DEVICE/settings', json => { key => 'new value', 'tag.bar' => 'bar' })
        ->status_is(403);
    $t->post_ok('/device/LOCATED_DEVICE/settings', json => { 'tag.foo' => 'foo', 'tag.bar' => 'bar' })
        ->status_is(204);

    $t->post_ok('/device/LOCATED_DEVICE/settings/tag.bar', json => { 'tag.bar' => 'newbar' })
        ->status_is(204);
    $t->get_ok('/device/LOCATED_DEVICE/settings/tag.bar')
        ->status_is(200)
        ->json_schema_is('DeviceSetting')
        ->json_is('/tag.bar', 'newbar', 'Setting was updated');
    $t->delete_ok('/device/LOCATED_DEVICE/settings/tag.bar')
        ->status_is(204);
    $t->get_ok('/device/LOCATED_DEVICE/settings/tag.bar')
};

subtest 'Device PXE' => sub {
    $t->authenticate(email => $admin_user->email);
    my $layout = $t->load_fixture('rack_0a_layout_3_6');

    my $relay = $t->app->db_relays->create({ serial_number => 'my_relay' });

    my $device_pxe = $t->app->db_devices->create({
        serial_number => 'PXE_TEST',
        hardware_product_id => $layout->hardware_product_id,
        health => 'unknown',
        device_relay_connections => [{
            relay => {
                id => $relay->id,
                user_relay_connections => [ { user_id => $t->load_fixture('conch_user')->id } ],
            }
        }],
        device_nics => [
            {
                state => 'up',
                iface_name => 'milhouse',
                iface_type => 'human',
                iface_vendor => 'Groening',
                mac => '00:00:00:00:00:aa',
                ipaddr => '0.0.0.1',
            },
            {
                state => 'up',
                iface_name => 'ned',
                iface_type => 'human',
                iface_vendor => 'Groening',
                mac => '00:00:00:00:00:bb',
                ipaddr => '0.0.0.2',
            },
            {
                state => undef,
                iface_name => 'ipmi1',
                iface_type => 'human',
                iface_vendor => 'Groening',
                mac => '00:00:00:00:00:cc',
                ipaddr => '0.0.0.3',
            },
        ],
    });

    $t->get_ok('/device/PXE_TEST/pxe')
        ->status_is(200)
        ->json_schema_is('DevicePXE')
        ->json_is({
            id => $device_pxe->id,
            location => undef,
            ipmi => {
                mac => '00:00:00:00:00:cc',
                ip => '0.0.0.3',
            },
            pxe => {
                mac => '00:00:00:00:00:aa',
            },
        });

    $layout->create_related('device_location', { device_id => $device_pxe->id });
    my $datacenter = $t->load_fixture('datacenter_0');

    $t->get_ok('/device/PXE_TEST/pxe')
        ->status_is(200)
        ->json_schema_is('DevicePXE')
        ->json_is({
            id => $device_pxe->id,
            location => {
                datacenter => {
                    name => $datacenter->region,
                    vendor_name => $datacenter->vendor_name,
                },
                rack => {
                    name => $layout->rack->name,
                    rack_unit_start => $layout->rack_unit_start,
                },
            },
            ipmi => {
                mac => '00:00:00:00:00:cc',
                ip => '0.0.0.3',
            },
            pxe => {
                mac => '00:00:00:00:00:aa',
            },
        });


    $device_pxe->delete_related('device_location');
    $device_pxe->delete_related('device_nics');

    $t->get_ok('/device/PXE_TEST/pxe')
        ->status_is(200)
        ->json_schema_is('DevicePXE')
        ->json_is({
            id => $device_pxe->id,
            location => undef,
            ipmi => undef,
            pxe => undef,
        });
};

subtest 'Device location' => sub {
    $t->post_ok('/device/TEST/location')
        ->status_is(400)
        ->json_schema_is('RequestValidationError')
        ->json_cmp_deeply('/details', [ { path => '/', message => re(qr/expected object/i) } ]);

    $t->post_ok('/device/TEST/location', json => { rack_id => $rack_id, rack_unit_start => 42 })
        ->status_is(409)
        ->json_is({ error => "slot 42 does not exist in the layout for rack $rack_id" });

    $t->post_ok('/device/TEST/location', json => { rack_id => $rack_id, rack_unit_start => 3 })
        ->status_is(303)
        ->location_is('/device/'.$test_device_id.'/location');

    $t->delete_ok('/device/TEST/location')
        ->status_is(204, 'can delete device location');

    $t->post_ok('/device/TEST/location', json => { rack_id => $rack_id, rack_unit_start => 3 })
        ->status_is(303, 'add it back');
};

done_testing;
# vim: set ts=4 sts=4 sw=4 et :
