use Mojo::Base -strict;
use Test::More;
use Test::Warnings;
use Test::Deep;
use Data::UUID;
use Test::Conch;

my $t = Test::Conch->new;
$t->load_fixture_set('workspace_room_rack_layout', 0);  # contains compute, storage products
$t->load_fixture('hardware_product_switch', 'hardware_product_profile_switch');

my $hw_product_switch = $t->load_fixture('hardware_product_switch');    # rack_unit_size 1
my $hw_product_compute = $t->load_fixture('hardware_product_compute');  # rack_unit_size 2
my $hw_product_storage = $t->load_fixture('hardware_product_storage');  # rack_unit_size 4

my $uuid = Data::UUID->new;

# at the start, both racks have these assigned slots:
# start 1, width 2
# start 3, width 4
# start 11, width 4

$t->post_ok(
    '/login' => json => {
        user     => 'conch@conch.joyent.us',
        password => 'conch',
    }
)->status_is(200);
BAIL_OUT('Login failed') if $t->tx->res->code != 200;

my $fake_id = $uuid->create_str();

my $rack_id = $t->load_fixture('datacenter_rack_0a')->id;

$t->get_ok('/layout')
    ->status_is(200)
    ->json_schema_is('RackLayouts')
    ->json_cmp_deeply([
        superhashof({ rack_id => $rack_id, ru_start => 1, product_id => $hw_product_compute->id }),
        superhashof({ rack_id => $rack_id, ru_start => 3, product_id => $hw_product_storage->id }),
        superhashof({ rack_id => $rack_id, ru_start => 11, product_id => $hw_product_storage->id }),
    ]);

my $initial_layouts = $t->tx->res->json;
my $layout_width_4 = $initial_layouts->[2];    # start 11, width 4.

$t->get_ok("/layout/$initial_layouts->[0]{id}")
    ->status_is(200)
    ->json_schema_is('RackLayout')
    ->json_is('', $initial_layouts->[0]);

$t->post_ok('/layout', json => { wat => 'wat' })
    ->status_is(400)
    ->json_schema_is('Error');

my $rack_id = $t->load_fixture('datacenter_rack_0a')->id;

$t->get_ok("/rack/$rack_id/layouts")
    ->status_is(200)
    ->json_schema_is('RackLayouts')
    ->json_cmp_deeply([
        superhashof({ rack_id => $rack_id, ru_start => 1, product_id => $hw_product_compute->id }),
        superhashof({ rack_id => $rack_id, ru_start => 3, product_id => $hw_product_storage->id }),
        superhashof({ rack_id => $rack_id, ru_start => 11, product_id => $hw_product_storage->id }),
    ]);

$t->post_ok('/layout', json => {
        rack_id => $fake_id,
        product_id => $hw_product_compute->id,
        ru_start => 1,
    })
    ->status_is(400)
    ->json_schema_is('Error')
    ->json_is({ error => 'Rack does not exist' });

$t->post_ok('/layout', json => {
        rack_id => $rack_id,
        product_id => $fake_id,
        ru_start => 1,
    })
    ->status_is(400)
    ->json_schema_is('Error')
    ->json_is({ error => 'Hardware product does not exist' });

$t->post_ok('/layout', json => {
        rack_id => $rack_id,
        product_id => $hw_product_switch->id,
        ru_start => 42,
    })
    ->status_is(303);

$t->get_ok($t->tx->res->headers->location)
    ->status_is(200)
    ->json_schema_is('RackLayout');

$t->post_ok('/layout', json => {
        rack_id => $rack_id,
        product_id => $hw_product_switch->id,
        ru_start => 42,
    })
    ->status_is(400)
    ->json_schema_is('Error')
    ->json_is({ error => 'ru_start conflict' });

# at the moment, we have these assigned slots:
# start 1, width 2
# start 3, width 4
# start 11, width 4
# start 42, width 1

$t->get_ok("/rack/$rack_id/layouts")
    ->status_is(200)
    ->json_schema_is('RackLayouts')
    ->json_cmp_deeply([
        superhashof({ rack_id => $rack_id, ru_start => 1, product_id => $hw_product_compute->id }),
        superhashof({ rack_id => $rack_id, ru_start => 3, product_id => $hw_product_storage->id }),
        superhashof({ rack_id => $rack_id, ru_start => 11, product_id => $hw_product_storage->id }),
        superhashof({ rack_id => $rack_id, ru_start => 42, product_id => $hw_product_switch->id }),
    ]);

my $layout_3_6 = $t->load_fixture('datacenter_rack_0a_layout_3_6');

# can't put something into an assigned position
$t->post_ok('/layout/'.$layout_3_6->id, json => { ru_start => 11 })
    ->status_is(400)
    ->json_is({ error => 'ru_start conflict' });

# the start of this product will overlap with assigned slots (need 12-15, 11-14 are assigned)
$t->post_ok('/layout/'.$layout_3_6->id, json => { ru_start => 12 })
    ->status_is(400)
    ->json_is({ error => 'ru_start conflict' });

# the end of this product will overlap with assigned slots (need 10-13, 11-14 are assigned)
my $layout_1_2 = $t->load_fixture('datacenter_rack_0a_layout_1_2');
$t->post_ok('/layout/'.$layout_1_2->id,
        json => { ru_start => 10, product_id => $hw_product_storage->id })
    ->status_is(400)
    ->json_is({ error => 'ru_start conflict' });

$t->post_ok('/layout/'.$layout_1_2->id,
        json => { ru_start => 19, product_id => $hw_product_storage->id })
    ->status_is(303)
    ->location_is('/layout/'.$layout_1_2->id);

my $layout_19_22 = $layout_1_2;
undef $layout_1_2;

$t->get_ok($t->tx->res->headers->location)
    ->status_is(200)
    ->json_is('/ru_start' => 19)
    ->json_schema_is('RackLayout');

# now we have these assigned slots:
# start 3, width 4
# start 11, width 4
# start 19, width 4     originally start 1, width 2
# start 42, width 1

$t->get_ok("/rack/$rack_id/layouts")
    ->status_is(200)
    ->json_schema_is('RackLayouts')
    ->json_cmp_deeply([
        superhashof({ rack_id => $rack_id, ru_start => 3, product_id => $hw_product_storage->id }),
        superhashof({ rack_id => $rack_id, ru_start => 11, product_id => $hw_product_storage->id }),
        superhashof({ rack_id => $rack_id, ru_start => 19, product_id => $hw_product_storage->id }),
        superhashof({ rack_id => $rack_id, ru_start => 42, product_id => $hw_product_switch->id }),
    ]);

$t->post_ok('/layout/'.$layout_19_22->id, json => { rack_id => $fake_id })
    ->status_is(400)
    ->json_schema_is('Error')
    ->json_is({ error => 'Rack does not exist' });

$t->post_ok('/layout/'.$layout_19_22->id, json => { product_id => $fake_id })
    ->status_is(400)
    ->json_schema_is('Error')
    ->json_is({ error => 'Hardware product does not exist' });

$t->post_ok('/layout', json => {
        rack_id => $rack_id,
        product_id => $hw_product_compute->id,
        ru_start => 1,
    })
    ->status_is(303);

# now we have these assigned slots:
# start 1, width 2
# start 3, width 4
# start 11, width 4
# start 19, width 4     originally start 1, width 2
# start 42, width 1

$t->get_ok("/rack/$rack_id/layouts")
    ->status_is(200)
    ->json_schema_is('RackLayouts')
    ->json_cmp_deeply([
        superhashof({ rack_id => $rack_id, ru_start => 1, product_id => $hw_product_compute->id }),
        superhashof({ rack_id => $rack_id, ru_start => 3, product_id => $hw_product_storage->id }),
        superhashof({ rack_id => $rack_id, ru_start => 11, product_id => $hw_product_storage->id }),
        superhashof({ rack_id => $rack_id, ru_start => 19, product_id => $hw_product_storage->id }),
        superhashof({ rack_id => $rack_id, ru_start => 42, product_id => $hw_product_switch->id }),
    ]);

$t->delete_ok('/layout/'.$layout_3_6->id)
    ->status_is(204);
$t->get_ok('/layout/'.$layout_3_6->id)
    ->status_is(404);

done_testing();
# vim: set ts=4 sts=4 sw=4 et :
