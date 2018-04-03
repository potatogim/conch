=head1 NAME

Conch::Plugin::JsonValidator

=head1 SYNOPSIS

	app->plugin('Conch::Plugin::JsonValidator');

	[ ... in a controller ]

	sub endpoint ($c) {
		my $body = $c->validate_input("MyInputDefinition");

		[ ... ]

		$c->status_with_validation(200, MyOutputDefinition => $ret);
	}


=head1 DESCRIPTION

Conch::Plugin::JsonValidator provides an optional manner to validate input and
output from a Mojo controller against JSON Schema.

The C<validate_input> helper uses the provided schema definition to validate
B<JUST> the incoming JSON request. Headers and query parameters B<ARE NOT> 
validated. If the data fails validation, a 400 status is returned to user
with an error payload containing the validation errors.

The C<status_with_validation> helper validates the outgoing data against the
provided schema definition. If the data validates, C<status> is called, using
the provided status code and data. If the data validation fails, a
C<Mojo::Exception> is thrown, returning a 500 to the user.

=head1 SCHEMAS

C<validate_input> validates data against the C<json-schema/input.yaml> file.

C<status_with_validation> validates data against the C<json-schema/v1.yaml>
file.

=head1 METHODS


=cut

package Conch::Plugin::JsonValidator;

use Mojo::Base 'Mojolicious::Plugin', -signatures;

use IO::All;
use JSON::Validator;
use Data::Validate::UUID 'is_uuid';

use constant OUTPUT_SCHEMA_FILE => "json-schema/v1.yaml";
use constant INPUT_SCHEMA_FILE => "json-schema/input.yaml";

sub _add_uuid_validation($v) {
	my $valid_formats = $v->formats;
	$valid_formats->{uuid} = \&is_uuid;
	$v->formats($valid_formats);
	return $v;
}

sub _find_schema($v, $schema) {
	if ( ref $schema eq 'HASH' ) {
		return $schema;
	} else {
		$v->get("/definitions/$schema");
	}
}


=head2 register

Load the plugin into Mojo. Called by Mojo directly

=cut

sub register ( $self, $app, $conf ) {

	my $input_validator = JSON::Validator->new();
	$input_validator->schema(INPUT_SCHEMA_FILE);
	_add_uuid_validation($input_validator);

	$app->helper(validate_input => sub ($c, $schema) {
		my $j = $c->req->json;
		my @errors = $input_validator->validate(
			$j,
			_find_schema($input_validator, $schema)
		);
		if (@errors) {
			$c->status(400 => { error => join("\n",@errors) });
			return undef;
		} else {
			return $j;
		}
	});

	####

	my $output_validator = JSON::Validator->new();
	$output_validator->schema(OUTPUT_SCHEMA_FILE);
	_add_uuid_validation($output_validator);

	$app->helper(
		status_with_validation => sub ($c, $status_code, $schema, $data) {

			my @errors = $output_validator->validate(
				$data,
				_find_schema($output_validator, $schema)
			);
			if(@errors) {
				my $err = join("\n\t", @errors);
				Mojo::Exception->throw("Output is not $schema: $err");
			} else {
				return $c->status($status_code => $data);
			}
		}
	);
}

1;


__DATA__

=pod

=head1 LICENSING

Copyright Joyent, Inc.

This Source Code Form is subject to the terms of the Mozilla Public License,
v.2.0. If a copy of the MPL was not distributed with this file, You can obtain
one at http://mozilla.org/MPL/2.0/.

=cut

