use strict;
use warnings;
use warnings FATAL => 'utf8';
use utf8;
use open ':std', ':encoding(UTF-8)'; # force stdin, stdout, stderr into utf8
use experimental 'signatures';

use Test::More;
use Test::Warnings ':all';
use Test::Deep;
use Test::Conch;
use Test::Memory::Cycle;
use Mojo::Promise;
use PadWalker 'closed_over';
use Path::Tiny;

my $t = Test::Conch->new(
    config => {
        features => { rollbar => 1, no_db => 1 },
        rollbar => {
            access_token => 'TOKEN',
            environment => 'custom_environment',
            error_match_header => { 'My-Buggy-Client' => qr/^1\.[0-9]$/ },
        },
    },
    pg => undef,
);

my $r = Mojolicious::Routes->new;
my $line_number;
$r->post('/_die/cb')->to(cb => sub ($c) {
    $line_number = __LINE__; die 'ach, I am slain';
});
$r->post('/_die/action')->to('user#die');
$r->post('/_die/dbix_class')->to('user#dbix_class');
$r->post('/_send_message')->to(cb => sub ($c) {
    $c->send_message_to_rollbar(
        'info',
        'here is a message',
        { foo => 'bar', baz => 123 },
    );
    $c->status(204);
});
$r->post('/_conflict')->to('user#conflict');
$t->add_routes($r);

package Conch::Controller::User {
    sub die ($c) {
        $line_number = __LINE__; my $singularity = 1/0;
    }
    sub dbix_class ($c) {
        require DBIx::Class::Exception;
        DBIx::Class::Exception->throw('ach, I am slain', 1);
    }
    sub conflict ($c) {
        $c->status(409, { error => 'something bad happened and you should feel bad' });
    }
}

package RollbarSimulator {
    use Conch::UUID 'create_uuid_str';
    use Mojo::Base 'Mojolicious', -signatures;
    sub startup ($self) {
        $self->routes->post('/api/1/item')->to(cb => sub ($c) {
            my $payload = $c->req->json;
            Test::More::like($payload->{data}{uuid}, Conch::UUID::UUID_FORMAT, 'got rollbar uuid in payload');
            $c->app->plugins->emit(rollbar_sent => $payload);
            $c->res->code(200);
            $c->render(json => { err => 0, result => { id => undef, uuid => $payload->{data}{uuid} } });
        });
    }
}

closed_over(\&WebService::Rollbar::Notifier::_post)->{'$API_URL'}->$* = '/api/1/';

my $rollbar_app = RollbarSimulator->new;
$t->app->ua->server->app($rollbar_app); # Conch ua will use our new test app for hostless URLs


# Payload documented at https://rollbar.com/docs/api/items_post/
my $exception_payload = {
    access_token => 'TOKEN',
    data => {
        environment => 'custom_environment',
        body => {
            # both keys required for exception type
            trace => {
                frames => array_each(
                    all(
                        # required keys
                        superhashof({ filename => isa('')}),
                        # optional, but we always pass them
                        superhashof({ map +($_ => isa('')), qw(class_name filename lineno method) }),
                        # optional keys
                        subhashof({
                            # if these keys exist, their values are strings
                            (map +($_ => isa('')), qw(filename lineno method code class_name)),
                            context => subhashof({
                                pre => supersetof(),
                                post => supersetof(),
                            }),
                        }),
                    ),
                ),
                exception => {
                    class => 'Mojo::Exception',
                    message => isa(''),
                    # description is optional and we do not use it.
                },
            },
        },
        # optional but conch always sends these:
        (map +($_ => ignore), qw(timestamp code_version platform fingerprint uuid context notifier)),
        language => 'perl '.$Config::Config{version},
        request => subhashof({ map +($_ => ignore), qw(url method headers params GET query_string POST body user_ip charset) }),
        # person - only sent when there is an authed user
        server => subhashof({ map +($_ => ignore), qw(cpu host root branch code_version perlpath archname osname osvers) }),
        custom => {
            request_id => code(sub { $_[0] eq $t->tx->res->headers->header('Request-Id') }),
            stash => all(
                # privileged data (e.g. from config file) is not leaked
                hash_each(isa('')),    # not a ref
                superhashof({ config => re(qr/^HASH\(0x/) }),
            ),
        },
        # optional, that we don't send: level framework client title
    },
};

my $message_payload = {
    access_token => 'TOKEN',
    data => {
        environment => 'custom_environment',
        body => {
            message => superhashof({
                body => isa(''),    # a string
                # all other keys are optional and can take any form
            }),
        },
        # optional but conch always sends these:
        (map +($_ => ignore), qw(timestamp code_version platform fingerprint uuid context notifier)),
        language => 'perl '.$Config::Config{version},
        request => subhashof({ map +($_ => ignore), qw(url method headers params GET query_string POST body user_ip charset) }),
        # person - only sent when there is an authed user
        server => subhashof({ map +($_ => ignore), qw(cpu host root branch code_version perlpath archname osname osvers) }),
        level => any(qw(critical error warning info debug)),
        custom => {
            request_id => code(sub { $_[0] eq $t->tx->res->headers->header('Request-Id') }),
            stash => all(
                # privileged data (e.g. from config file) is not leaked
                hash_each(isa('')),    # not a ref
                superhashof({ config => re(qr/^HASH\(0x/) }),
            ),
        },
        # optional, that we don't send: framework client title
    },
};

chomp(my @test_contents = path(__FILE__)->lines_utf8);
unshift @test_contents, undef;  # use 1-relative indexing

$t->do_and_wait_for_event(
    $rollbar_app->plugins, 'rollbar_sent',
    sub ($t) {
        $t->post_ok('/_die/cb?query_param=value0', json => { body_param => 'value1' })
            ->status_is(500);
    },
    sub ($payload) {
        cmp_deeply(
            $payload,
            $exception_payload,
            'basic exception payload',
        );

        cmp_deeply(
            $payload->{data}{request},
            superhashof({
                method => 'POST',
                url => re(qr{_die/cb}),
                query_string => 'query_param=value0',
                body => '{"body_param":"value1"}',
                # GET => { query_param => 'value0' },
                # POST => { body_param => 'value1' },
            }),
            'request details are included',
        );

        cmp_deeply(
            $payload->{data}{body}{trace}{exception}{message},
            re(qr/^ach, I am slain/),
            'exception message',
        );

        cmp_deeply(
            $payload->{data}{body}{trace}{frames}[0],
            {
                class_name => 'main',
                filename => __FILE__,
                lineno => $line_number,
                method => ignore,   # something internal in Mojo
                code => $test_contents[$line_number],
                context => {
                    pre => [ @test_contents[$line_number-5..$line_number-1] ],
                    post => [ @test_contents[$line_number+1..$line_number+5] ],
                },
            },
            'first frame of stack trace',
        );
    },
);

$t->do_and_wait_for_event(
    $rollbar_app->plugins, 'rollbar_sent',
    sub ($t) {
        $t->post_ok('/_die/action?query_param=value0', json => { body_param => 'value1' })
            ->status_is(500);
    },
    sub ($payload) {
        cmp_deeply(
            $payload,
            $exception_payload,
            'basic exception payload',
        );

        cmp_deeply(
            $payload->{data}{request},
            superhashof({
                method => 'POST',
                url => re(qr{_die/action}),
                query_string => 'query_param=value0',
                body => '{"body_param":"value1"}',
                # GET => { query_param => 'value0' },
                # POST => { body_param => 'value1' },
            }),
            'request details are included',
        );

        is($payload->{data}{context}, 'user#die', 'logged controller and action');

        cmp_deeply(
            $payload->{data}{body}{trace}{exception}{message},
            re(qr/^Illegal division by zero/),
            'exception message',
        );

        cmp_deeply(
            $payload->{data}{body}{trace}{frames}[0],
            {
                class_name => 'Conch::Controller::User',
                filename => __FILE__,
                lineno => $line_number,
                method => ignore,   # something internal in Mojo
                code => $test_contents[$line_number],
                context => {
                    pre => [ @test_contents[$line_number-5..$line_number-1] ],
                    post => [ @test_contents[$line_number+1..$line_number+5] ],
                },
            },
            'first frame of stack trace',
        );
    },
);

$t->do_and_wait_for_event(
    $rollbar_app->plugins, 'rollbar_sent',
    sub ($t) {
        $t->post_ok('/_die/dbix_class')
            ->status_is(500);
    },
    sub ($payload) {
        my $frameless_payload = {
            $exception_payload->%*,
            data => {
                $exception_payload->{data}->%*,
                body => {
                    $exception_payload->{data}{body}->%*,
                    trace => {
                        $exception_payload->{data}{body}{trace}->%*,
                        # the exception object has no frames, so we are unable to populate
                        # this section of the payload. The exception message contains
                        # everything of relevance.
                        frames => [],
                    },
                },
            },
        };

        cmp_deeply(
            $payload,
            $frameless_payload,
            'exception payload does not contain a trace this time',
        );

        cmp_deeply(
            $payload->{data}{request},
            superhashof({
                method => 'POST',
                url => re(qr{_die/dbix_class}),
                query_string => '',
                body => '',
            }),
            'request details are included',
        );

        is($payload->{data}{context}, 'user#dbix_class', 'logged controller and action');

        cmp_deeply(
            $payload->{data}{body}{trace}{exception}{message},
            re(qr/^ach, I am slain/),
            'exception message',
        );
    },
);

$t->do_and_wait_for_event(
    $rollbar_app->plugins, 'rollbar_sent',
    sub ($t) {
        $t->get_ok('/i_do_not_exist')
            ->status_is(404)
            ->json_is({ error => 'Not Found' });
    },
    sub ($payload) {
        cmp_deeply(
            $payload,
            $message_payload,
            'basic message payload',
        );

        cmp_deeply(
            $payload->{data}{request},
            superhashof({
                method => 'GET',
                url => re(qr{/i_do_not_exist}),
                query_string => '',
                body => '',
            }),
            'request details are included',
        );

        cmp_deeply(
            $payload->{data}{body},
            {
                message => {
                    body => 'no endpoint found for: GET /i_do_not_exist',
                },
            },
            'message for endpoint-not-found',
        );
    },
);

$t->do_and_wait_for_event(
    $rollbar_app->plugins, 'rollbar_sent',
    sub ($t) {
        $t->post_ok('/_send_message')
            ->status_is(204);
    },
    sub ($payload) {
        cmp_deeply(
            $payload,
            $message_payload,
            'basic message payload',
        );

        cmp_deeply(
            $payload->{data}{request},
            superhashof({
                method => 'POST',
                url => re(qr{/_send_message}),
                query_string => '',
                body => '',
            }),
            'request details are included',
        );

        cmp_deeply(
            $payload->{data}{body},
            {
                message => {
                    body => 'here is a message',
                    foo => 'bar',
                    baz => 123,
                },
            },
            'arbitrary message',
        );
    },
);

$t->do_and_wait_for_event(
    $rollbar_app->plugins, 'rollbar_sent',
    sub ($t) {
        $t->post_ok('/_conflict', { 'My-Buggy-Client' => '1.1' }, json => { ugh => [ 1, 2, 3 ] })
            ->status_is(409)
            ->json_is({ error => 'something bad happened and you should feel bad' });
    },
    sub ($payload) {
        cmp_deeply(
            $payload,
            $message_payload,
            'basic message payload',
        );

        cmp_deeply(
            $payload->{data}{request},
            superhashof({
                method => 'POST',
                url => re(qr{/_conflict}),
                query_string => '',
                body => '{"ugh":[1,2,3]}',
                # POST => { ugh => [ 1, 2, 3 ] },
            }),
            'request details are included',
        );

        cmp_deeply(
            $payload->{data}{body},
            {
                message => {
                    body => 'api error',
                    api_version => re(qr/^v\d+\.\d+\.\d+(-a\d+)?-\d+-g[[:xdigit:]]+$/),
                    latency => re(qr/^\d+$/),
                    req => {
                        user        => 'NOT AUTHED',
                        method      => 'POST',
                        url         => '/_conflict',
                        remoteAddress => '127.0.0.1',
                        remotePort  => ignore,
                        headers     => superhashof({
                            'My-Buggy-Client' => [ '1.1' ],
                        }),
                        query_params => {},
                    },
                    res => {
                        headers => superhashof({}),
                        statusCode => 409,
                        body => { error => 'something bad happened and you should feel bad' },
                    },
                },
            },
            'message sent when client error encountered',
        );
    },
);

warnings(sub {
    memory_cycle_ok($t, 'no leaks in the Test::Conch object');
});

done_testing;