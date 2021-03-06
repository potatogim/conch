package Conch::Validation::FirmwareCurrent;

use Mojo::Base 'Conch::Validation';

use constant name        => 'firmware_current';
use constant version     => 1;
use constant category    => 'BIOS';
use constant description => 'Validate that firmware is \'current\' in device settings';

sub validate {
    my ($self) = @_;

    my $firmware_value = $self->device_settings->{firmware};

    if ($firmware_value) {
        $self->register_result(
            expected => 'current',
            got      => $firmware_value
        );
    }
    else {
        $self->fail("No 'firmware' setting in device settings",
            hint => 'Device may not have started initial setup yet');
    }
}

1;
__END__

=pod

=head1 LICENSING

Copyright Joyent, Inc.

This Source Code Form is subject to the terms of the Mozilla Public License,
v.2.0. If a copy of the MPL was not distributed with this file, You can obtain
one at L<https://www.mozilla.org/en-US/MPL/2.0/>.

=cut
