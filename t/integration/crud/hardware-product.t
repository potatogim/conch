use Mojo::Base -strict;
use open ':std', ':encoding(UTF-8)'; # force stdin, stdout, stderr into utf8

use Test::More;
use Test::Warnings;
use Test::Deep;
use Test::Deep::JSON;
use Test::Conch;
use Conch::UUID 'create_uuid_str';

my $t = Test::Conch->new;
$t->load_fixture('super_user');

$t->authenticate;

$t->get_ok('/hardware_product')
    ->status_is(200)
    ->json_schema_is('HardwareProducts')
    ->json_is([]);

$t->load_fixture('00-hardware');

$t->get_ok('/hardware_product')
    ->status_is(200)
    ->json_schema_is('HardwareProducts');

my $products = $t->tx->res->json;
my $hw_id = $products->[0]{id};

$t->get_ok('/hardware_product/'.create_uuid_str())
    ->status_is(404)
    ->log_debug_like(qr/^Looking up a hardware product by id ${\Conch::UUID::UUID_FORMAT}$/);

$t->get_ok("/hardware_product/$hw_id")
    ->status_is(200)
    ->json_schema_is('HardwareProduct')
    ->json_cmp_deeply(superhashof($products->[0]));

my $vendor_id = $t->tx->res->json->{hardware_vendor_id};
my $validation_plan_id = $t->tx->res->json->{validation_plan_id};

$t->post_ok('/hardware_product', json => { wat => 'wat' })
    ->status_is(400)
    ->json_schema_is('RequestValidationError')
    ->json_cmp_deeply('/details', superbagof({ path => '/', message => re(qr/properties not allowed/i) }));

$t->post_ok('/hardware_product', json => { name => 'sungo', alias => 'sungo' })
    ->status_is(400)
    ->json_schema_is('RequestValidationError')
    ->json_cmp_deeply('/details', bag(
        map +{ path => "/$_", message => re(qr/missing property/i) },
        qw(hardware_vendor_id sku rack_unit_size validation_plan_id purpose bios_firmware cpu_type),
    ));

$t->post_ok('/hardware_product', json => {
        name => 'sungo',
        hardware_vendor_id => $vendor_id,
        alias => 'sungo',
        rack_unit_size => 2,
        sku => 'my sku',
        validation_plan_id => $validation_plan_id,
        purpose => 'myself',
        bios_firmware => '1.2.3',
        cpu_num => 2,
        cpu_type => 'fooey',
    })
    ->status_is(303)
    ->location_like(qr!^/hardware_product/${\Conch::UUID::UUID_FORMAT}$!);

$t->get_ok($t->tx->res->headers->location)
    ->status_is(200)
    ->json_schema_is('HardwareProduct')
    ->json_cmp_deeply({
        id => re(Conch::UUID::UUID_FORMAT),
        name => 'sungo',
        alias => 'sungo',
        prefix => undef,
        hardware_vendor_id => $vendor_id,
        created => re(qr/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{3,9}Z$/),
        updated => re(qr/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{3,9}Z$/),
        specification => undef,
        sku => 'my sku',
        generation_name => undef,
        legacy_product_name => undef,
        rack_unit_size => 2,
        validation_plan_id => $validation_plan_id,
        purpose => 'myself',
        bios_firmware => '1.2.3',
        hba_firmware => undef,
        cpu_num => 2,
        cpu_type => 'fooey',
        dimms_num => 0,
        ram_total => 0,
        nics_num => 0,
        sata_hdd_num => 0,
        sata_hdd_size => undef,
        sata_hdd_slots => undef,
        sas_hdd_num => 0,
        sas_hdd_size => undef,
        sas_hdd_slots => undef,
        sata_ssd_num => 0,
        sata_ssd_size => undef,
        sata_ssd_slots => undef,
        sas_ssd_num => 0,
        sas_ssd_size => undef,
        sas_ssd_slots => undef,
        nvme_ssd_num => 0,
        nvme_ssd_size => undef,
        nvme_ssd_slots => undef,
        raid_lun_num => 0,
        psu_total => 0,
        usb_num => 0,
    });

my $new_product = $t->tx->res->json;
my $new_hw_id = $new_product->{id};

$t->get_ok('/hardware_product')
    ->status_is(200)
    ->json_schema_is('HardwareProducts')
    ->json_cmp_deeply(bag(@$products, +{ $new_product->%{qw(id name alias generation_name sku created updated)} }));

$t->post_ok('/hardware_product', json => {
        name => 'sungo',
        hardware_vendor_id => $vendor_id,
        alias => 'sungo',
        sku => 'another sku',
        rack_unit_size => 1,
        validation_plan_id => $validation_plan_id,
        purpose => 'nothing',
        bios_firmware => '0',
        cpu_type => 'cold',
    })
    ->status_is(409)
    ->json_schema_is('Error')
    ->json_is({ error => 'Unique constraint violated on \'name\'' });

$t->post_ok('/hardware_product', json => {
        name => 'another name',
        hardware_vendor_id => create_uuid_str(),
        alias => 'another alias',
        sku => 'another sku',
        rack_unit_size => 1,
        validation_plan_id => $validation_plan_id,
        purpose => 'nothing',
        bios_firmware => '0',
        cpu_type => 'cold',
    })
    ->status_is(409)
    ->json_schema_is('Error')
    ->json_is({ error => 'hardware_vendor_id does not exist' });

$t->post_ok('/hardware_product', json => {
        name => 'another name',
        hardware_vendor_id => $vendor_id,
        alias => 'another alias',
        sku => 'another sku',
        rack_unit_size => 1,
        validation_plan_id => create_uuid_str(),
        purpose => 'nothing',
        bios_firmware => '0',
        cpu_type => 'cold',
    })
    ->status_is(409)
    ->json_schema_is('Error')
    ->json_is({ error => 'validation_plan_id does not exist' });

$t->post_ok("/hardware_product/$new_hw_id", json => { name => 'sungo2' })
    ->status_is(303)
    ->location_is('/hardware_product/'.$new_hw_id);

$new_product->{name} = 'sungo2';
$new_product->{updated} = re(qr/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{3,9}Z$/);

$t->get_ok($t->tx->res->headers->location)
    ->status_is(200)
    ->json_schema_is('HardwareProduct')
    ->json_cmp_deeply($new_product);

$t->get_ok('/hardware_product/foo')
    ->status_is(404)
    ->log_debug_is('Looking up a hardware product by sku,name,alias foo');

$t->get_ok('/hardware_product/name=sungo2')
    ->status_is(308)
    ->location_is('/hardware_product/sungo2');

$t->get_ok($_)
    ->status_is(200)
    ->location_is('/hardware_product/'.$new_product->{id})
    ->json_schema_is('HardwareProduct')
    ->json_cmp_deeply($new_product)
    foreach
        '/hardware_product/'.$new_product->{id},
        '/hardware_product/my sku',     # sku
        '/hardware_product/sungo2',     # name  TODO: remove later
        '/hardware_product/sungo';      # alias TODO: remove later

$t->post_ok('/hardware_product', json => {
        name => 'sungo3',
        alias => 'my sku',  # these two fields are
        sku => 'sungo',     # flipped from the other product
        hardware_vendor_id => $vendor_id,
        rack_unit_size => 2,
        validation_plan_id => $validation_plan_id,
        purpose => 'myself',
        bios_firmware => '1.2.3',
        cpu_num => 2,
        cpu_type => 'fooey',
    })
    ->status_is(303)
    ->location_like(qr!^/hardware_product/${\Conch::UUID::UUID_FORMAT}$!);

$t->get_ok('/hardware_product/sungo')
    ->status_is(409)
    ->json_is({ error => 'there is more than one match' });

subtest 'manipulate hardware_product.specification' => sub {
  $t->put_ok('/hardware_product/'.$new_hw_id.'/specification', json => {})
    ->status_is(400)
    ->json_schema_is('QueryParamsValidationError')
    ->json_cmp_deeply('/details', [ { path => '/path', message => re(qr/Missing property/) } ]);

  $t->put_ok('/hardware_product/'.$new_hw_id.'/specification?path=', json => {})
    ->status_is(204)
    ->location_is('/hardware_product/'.$new_hw_id);

  $t->get_ok('/hardware_product/'.$new_hw_id)
    ->status_is(200)
    ->json_schema_is('HardwareProduct')
    ->json_cmp_deeply(superhashof({ specification => '{}' }));

  $t->put_ok('/hardware_product/'.$new_hw_id.'/specification?path=', json => 'hello')
    ->status_is(400)
    ->json_schema_is('RequestValidationError')
    ->json_cmp_deeply(superhashof({
      details => [ { path => '/', message => re(qr/Expected object - got string/) } ],
      schema => '/schema/request/hardware_product_specification',
    }));

  $t->put_ok('/hardware_product/'.$new_hw_id.'/specification?path=/disk_size', json => 1)
    ->status_is(400)
    ->json_schema_is('RequestValidationError')
    ->json_cmp_deeply(superhashof({
      details => [ { path => '/disk_size', message => re(qr/Expected object - got number/) } ],
      schema => '/schema/request/hardware_product_specification',
    }));

  $t->put_ok('/hardware_product/'.$new_hw_id.'/specification?path=/disk_size',
      json => { _default => 128 })
    ->status_is(204)
    ->location_is('/hardware_product/'.$new_hw_id);

  $t->get_ok('/hardware_product/'.$new_hw_id)
    ->status_is(200)
    ->json_schema_is('HardwareProduct')
    ->json_cmp_deeply(superhashof({
      specification => json({ disk_size => { _default => 128 } }),
    }));

  $t->put_ok('/hardware_product/'.$new_hw_id.'/specification?path=/disk_size/SEAGATE_8000',
      json => {})
    ->status_is(400)
    ->json_schema_is('RequestValidationError')
    ->json_cmp_deeply(superhashof({
      details => [ { path => '/disk_size/SEAGATE_8000', message => re(qr/Expected integer - got object/) } ],
      schema => '/schema/request/hardware_product_specification',
    }));

  $t->put_ok('/hardware_product/'.$new_hw_id.'/specification?path=/disk_size/SEAGATE_8000',
      json => 1)
    ->status_is(204)
    ->location_is('/hardware_product/'.$new_hw_id);

  $t->get_ok('/hardware_product/'.$new_hw_id)
    ->status_is(200)
    ->json_schema_is('HardwareProduct')
    ->json_cmp_deeply(superhashof({
      specification => json({ disk_size => { _default => 128, SEAGATE_8000 => 1 } }),
    }));

  $t->put_ok('/hardware_product/'.$new_hw_id.'/specification?path=/disk_size/_default', json => 64)
    ->status_is(204)
    ->location_is('/hardware_product/'.$new_hw_id);

  $t->get_ok('/hardware_product/'.$new_hw_id)
    ->status_is(200)
    ->json_schema_is('HardwareProduct')
    ->json_cmp_deeply(superhashof({
      specification => json({ disk_size => { _default => 64, SEAGATE_8000 => 1 } })
    }));

  # the path we want to operate on is called .../~1~device/  and encodes as .../~01~0device/...
  $t->put_ok('/hardware_product/'.$new_hw_id.'/specification?path=/disk_size/tilde~1~device', json => 2)
    ->status_is(400)
    ->json_schema_is('QueryParamsValidationError')
    ->json_cmp_deeply('/details', [ { path => '/path', message => re(qr/Does not match json-pointer format/) } ]);

  $t->put_ok('/hardware_product/'.$new_hw_id.'/specification?path=/disk_size/tilde~01~0device', json => 2)
    ->status_is(204)
    ->location_is('/hardware_product/'.$new_hw_id);

  $t->get_ok('/hardware_product/'.$new_hw_id)
    ->status_is(200)
    ->json_schema_is('HardwareProduct')
    ->json_cmp_deeply(superhashof({
      specification => json({ disk_size => {
        _default => 64,
        SEAGATE_8000 => 1,
        'tilde~1~device' => 2,
      } })
    }));

  $t->put_ok('/hardware_product/'.$new_hw_id.'/specification?path=/other_prop', json => [ 1,2,3 ])
    ->status_is(204)
    ->location_is('/hardware_product/'.$new_hw_id);

  $t->get_ok('/hardware_product/'.$new_hw_id)
    ->status_is(200)
    ->json_schema_is('HardwareProduct')
    ->json_cmp_deeply(superhashof({
      specification => json({
        disk_size => { _default => 64, SEAGATE_8000 => 1, 'tilde~1~device' => 2 },
        other_prop => [ 1, 2, 3 ],
      }),
    }));

  $t->delete_ok('/hardware_product/'.$new_hw_id.'/specification')
    ->status_is(400)
    ->json_schema_is('QueryParamsValidationError')
    ->json_cmp_deeply('/details', [ { path => '/path', message => re(qr/Missing property/) } ]);

  # the path we want to operate on is called .../~1~device/  and encodes as .../~01~0device/...
  $t->delete_ok('/hardware_product/'.$new_hw_id.'/specification?path=/disk_size/tilde~1~device')
    ->status_is(400)
    ->json_schema_is('QueryParamsValidationError')
    ->json_cmp_deeply('/details', [ { path => '/path', message => re(qr/Does not match json-pointer format/) } ]);

  $t->delete_ok('/hardware_product/'.$new_hw_id.'/specification?path=/disk_size/_default')
    ->status_is(400)
    ->json_schema_is('RequestValidationError')
    ->json_cmp_deeply('/details', [ { path => '/disk_size/_default', message => re(qr/Missing property/) } ]);

  $t->delete_ok('/hardware_product/'.$new_hw_id.'/specification?path=/disk_size/tilde~01~0device')
    ->status_is(204)
    ->location_is('/hardware_product/'.$new_hw_id);

  $t->get_ok('/hardware_product/'.$new_hw_id)
    ->status_is(200)
    ->json_schema_is('HardwareProduct')
    ->json_cmp_deeply(superhashof({
      specification => json({
        disk_size => { _default => 64, SEAGATE_8000 => 1 },
        other_prop => [ 1, 2, 3 ],
      }),
    }));

  $t->delete_ok('/hardware_product/'.$new_hw_id.'/specification?path=/disk_size')
    ->status_is(204)
    ->location_is('/hardware_product/'.$new_hw_id);

  $t->get_ok('/hardware_product/'.$new_hw_id)
    ->status_is(200)
    ->json_schema_is('HardwareProduct')
    ->json_cmp_deeply(superhashof({
      specification => json({ other_prop => [ 1, 2, 3 ] }),
    }));

  $t->delete_ok('/hardware_product/'.$new_hw_id.'/specification?path=')
    ->status_is(204)
    ->location_is('/hardware_product/'.$new_hw_id);

  $t->get_ok('/hardware_product/'.$new_hw_id)
    ->status_is(200)
    ->json_schema_is('HardwareProduct')
    ->json_cmp_deeply(superhashof({ specification => undef }));
};

subtest 'delete a hardware product' => sub {
    $t->delete_ok("/hardware_product/$new_hw_id")
        ->status_is(204);

    $t->get_ok("/hardware_product/$new_hw_id")
        ->status_is(410);

    $t->delete_ok('/hardware_product/sungo')
        ->status_is(204);

    $t->get_ok('/hardware_product')
        ->status_is(200)
        ->json_schema_is('HardwareProducts')
        ->json_cmp_deeply($products);
};

done_testing;
# vim: set ts=4 sts=4 sw=4 et :
