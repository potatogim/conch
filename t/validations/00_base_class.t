use Mojo::Base -strict;
use DDP;
use Test::More;
use Test::Fatal;
use Test::Deep;

# SUMMARY
# =======
#
# These tests are for the core functionality of Conch::Validation. It tests
# each of the component pieces of the module are working as expected. In
# general, if Conch::Validation is changed, corresponding tests should be
# added.

use_ok("Conch::Validation");
new_ok("Conch::Validation");

subtest '->validate' => sub {
	like(
		exception {
			my $base_validation = Conch::Validation->new;
			$base_validation->validate( {} );
		},
		qr/Validations must implement the `validate` method in subclass/
	);
};

subtest '->fail' => sub {
	my $base_validation = Conch::Validation->new;
	$base_validation->fail('Validation failure');
	is( $base_validation->validation_results->[0]->{message},
		'Validation failure' );
	is( scalar $base_validation->validation_results->@*, 1 );
	is( scalar $base_validation->failures->@*,           1 );
	is( scalar $base_validation->successes->@*,          0 );
};

subtest '->die' => sub {
	my $base_validation = Conch::Validation->new;

	cmp_deeply(
		exception { $base_validation->die( 'Validation dies', hint => 'how to fix' ); },
		all(
			isa('Conch::ValidationError'),
			methods(
				message => 'Validation dies',
				hint	=> 'how to fix',
				error_loc => re(qr/Exception raised in 'main' at line \d+/),
			),
		),
		'got the right validation errors',
	);
};

subtest '->clear_results' => sub {
	my $base_validation = Conch::Validation->new;
	$base_validation->fail('Validation fail 1');
	$base_validation->fail('Validation fail 2');
	is( scalar $base_validation->validation_results->@*, 2, 'Results collect' );
	is( scalar $base_validation->failures->@*,           2 );
	is( scalar $base_validation->successes->@*,          0 );

	$base_validation->clear_results;
	is( scalar $base_validation->validation_results->@*, 0, 'Results clear' );
	is( scalar $base_validation->failures->@*,           0 );
	is( scalar $base_validation->successes->@*,          0 );
};

subtest '->register_result' => sub {
	my $base_validation = Conch::Validation->new;

	like exception { $base_validation->register_result() },
	qr/'expected' value must be defined/;

	like exception {
		$base_validation->register_result( got => [ 1, 2 ], expected => 1 )
	},
	qr/must be a scalar/;

	like exception {
		$base_validation->register_result( got => 1, expected => [ 1, 2 ] )
	},
	qr/must be a scalar when comparing with 'eq'/;

	like exception {
		$base_validation->register_result( got => 1, expected => { a => 1 } )
	},
	qr/must be a scalar when comparing with 'eq'/;

	$base_validation->clear_results;

	$base_validation->register_result( expected => 'test', got => 'test' );
	is( scalar $base_validation->successes->@*, 1, 'Successful result' );
	is(
		$base_validation->successes->[0]->{message},
		"Expected eq 'test'. Got 'test'."
	);

	$base_validation->register_result( expected => 'test', got => 'bad' );
	is( scalar $base_validation->failures->@*, 1, 'Failed result' );
	is( $base_validation->failures->[0]->{message},
		"Expected eq 'test'. Got 'bad'." );

	$base_validation->register_result(
		expected => 'test',
		got      => 'good',
		cmp      => 'ne'
	);
	is( scalar $base_validation->successes->@*, 2, 'Successful result' );
	is(
		$base_validation->successes->[1]->{message},
		"Expected ne 'test'. Got 'good'."
	);
	$base_validation->clear_results;

	$base_validation->register_result(
		expected => 20,
		got      => 40,
		cmp      => '>'
	);
	is( scalar $base_validation->successes->@*, 1, 'Successful comparison result' );
	is(
		$base_validation->successes->[0]->{message},
		"Expected a value > '20'. Passed."
	);

	$base_validation->register_result(
		expected => 20,
		got      => 40,
		cmp      => '<'
	);
	is( scalar $base_validation->failures->@*, 1, 'Failing comparison result' );
	is(
		$base_validation->failures->[0]->{message},
		"Expected a value < '20'. Failed."
	);

	$base_validation->clear_results;

	$base_validation->register_result(
		expected => [ 'a', 'b', 'c' ],
		got      => 'b',
		cmp      => 'oneOf'
	);
	is( scalar $base_validation->successes->@*, 1, 'Successful oneOf result' );
	is(
		$base_validation->successes->[0]->{message},
		"Expected one of: 'a', 'b', 'c'. Got 'b'."
	);

	$base_validation->register_result(
		expected => [ 'a', 'b', 'c' ],
		got      => 'bad',
		cmp      => 'oneOf'
	);
	is( scalar $base_validation->failures->@*, 1, 'Failing oneOf result' );
	is(
		$base_validation->failures->[0]->{message},
		"Expected one of: 'a', 'b', 'c'. Got 'bad'."
	);

	$base_validation->clear_results;

	$base_validation->register_result(
		expected => qr/\w{3}\d{3}/,
		got      => 'foo123',
		cmp      => 'like'
	);
	is( scalar $base_validation->successes->@*, 1, 'Successful like result' );
	is(
		$base_validation->successes->[0]->{message},
		'Expected like \'(?^:\w{3}\d{3})\'. Got \'foo123\'.'
	);

	$base_validation->register_result(
		expected => qr/\w{3}\d{3}/,
		got      => 'bad42',
		cmp      => 'like'
	);
	is( scalar $base_validation->failures->@*, 1, 'Failing like result' );
	is(
		$base_validation->failures->[0]->{message},
		'Expected like \'(?^:\w{3}\d{3})\'. Got \'bad42\'.'
	);
};

done_testing();