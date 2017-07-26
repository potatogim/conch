package Conch::Control::Device;

use strict;
use Log::Report;
use Log::Report::DBIC::Profiler;
use Dancer2::Plugin::Passphrase;

use Data::Printer;

use Exporter 'import';
our @EXPORT = qw( devices_for_user device_inventory device_validation_report update_device_location );

sub devices_for_user {
  my ($schema, $user_name) = @_;

  my @user_devices;

  foreach my $device ($schema->resultset('UserDeviceAccess')->
                      search({}, { bind => [$user_name] })->all) {
    push @user_devices,$device->id;
  }

  return @user_devices;

};

sub device_inventory {
  my ($schema, $device_id) = @_;

  # Get the most recent entry in device_report.
  my $report = $schema->resultset('DeviceReport')->search(
    { device_id => $device_id },
    { order_by => { -desc => 'created' } }
  )->first;

  if ($report) {
    return ($report->id, Dancer2::Serializer::JSON::from_json($report->report));
  } else {
    return undef;
  }
  
}

# Bundle up the validate logs for a given device report.
sub device_validation_report {
  my ($schema, $report_id) = @_;

  my @validate_report = $schema->resultset('DeviceValidate')->search({ report_id => $report_id });

  my @reports;
  foreach my $r (@validate_report) {
    push @reports, Dancer2::Serializer::JSON::from_json($r->validation);
  }

  return @reports;
}

sub update_device_location {
  my ($schema, $device_info ) = @_;

  # If the device doesn't exist, create a stub entry for it.
  my $device_check = $schema->resultset('Device')->find({
    id => $device_info->{device}
  });

  unless ($device_check) {

    p $device_info;

    my $slot_info = $schema->resultset('DatacenterRackLayout')->search({
      rack_id   => $device_info->{rack},
      ru_start  => $device_info->{rack_unit}
    })->single;

    unless ($slot_info) {
      warning "Could not find a slot $device_info->{rack}:$device_info->{rack_unit} for device $device_info->{device}";
      return undef;
    }
 
    my $device_create = $schema->resultset('Device')->update_or_create({
      id     => $device_info->{device},
      health => "UNKNOWN",
      state  => "UNKNOWN",
      hardware_product => $slot_info->product_id,
    });

    unless ($device_create->in_storage) { return undef }
  }

  my $existing = $schema->resultset('DeviceLocation')->find({
    device_id => $device_info->{device}
  });

  # Log that we're moving a device if we are.
  if ($existing) {
    my $e_ru = $existing->rack_id.":".$existing->rack_unit;
    my $n_ru = $device_info->{rack}.":".$device_info->{rack_unit};

    if ( $e_ru ne $n_ru ) {
      warning "Moving $device_info->{device} from $e_ru to $n_ru";
    }
  }

  my $occupied = $schema->resultset('DeviceLocation')->search({
    rack_id   => $device_info->{rack},
    rack_unit => $device_info->{rack_unit}
  })->single;

  # XXX I couldn't figure out how to defref this properly!
  # XXX It made me nuts :( -- bdha
  # Refuse to move a device to a slot occupied by another device.
  if ($occupied) {
    my $occupied_device = $occupied->device_id;

    unless ( $occupied_device == $device_info->{device} ) {
      # XXX This needs a real error message.
      warning "Cannot move $device_info->{device} to $device_info->{rack}:$device_info->{rack_unit}, occupied by $occupied_device";
      return undef;
    }
  }

  info "Updating location for $device_info->{device} to $device_info->{rack}:$device_info->{rack_unit}";
  my $result = $schema->resultset('DeviceLocation')->update_or_create({
    device_id => $device_info->{device},
    rack_id   => $device_info->{rack},
    rack_unit => $device_info->{rack_unit}
  }); 
}

1;