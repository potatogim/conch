package Conch::Route::Device;

use strict;

use Dancer2 appname => 'Conch';
use Dancer2::Plugin::Auth::Tiny;
use Dancer2::Plugin::DBIC;
use Dancer2::Plugin::LogReport;
use Dancer2::Plugin::REST;
use Hash::MultiValue;
use Conch::Control::Device;
use Conch::Control::DeviceReport;
use Conch::Control::Device::Validation;

set serializer => 'JSON';

# Return all devices an integrator user has access to
# Admins currently don't have access to endpoint and they get a 401.
# TODO: If we want to add admin access, what should this endpoint return? All
# devices across all DCs?
get '/device' => needs integrator => sub {
  my $user_name = session->read('integrator');
  my @devices;
  process sub { @devices = devices_for_user(schema, $user_name); };
  status_200({devices => (@devices || []) });
};

post '/device' => sub {
  my $device;
  my $report_id;
  if (process sub {
      ($device, $report_id) = record_device_report(
          schema,
          parse_device_report(body_parameters->as_hashref)
        );
      validate_device(schema, $device, $report_id);
    }) {
      status_200(entity => {
          device_id => $device->id,
          validated => 1,
          action    => "create",
          status    => "200"
      });
  }
  else {
    status_500("error occurred in persisting device report");
  }
};

1;
