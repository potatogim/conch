package Conch::Plugin::Mail;

use v5.26;
use warnings;
use Mojo::Base 'Mojolicious::Plugin', -signatures;

use Email::Simple;
use Email::Sender::Simple 'sendmail';
use Email::Sender::Transport::SMTP;
use Try::Tiny;
use Safe::Isa;

=pod

=head1 NAME

Conch::Plugin::Mail

=head1 DESCRIPTION

Helper methods for sending emails.

=head1 METHODS

=head2 register

Sets up the helpers.

=head1 HELPERS

These methods are made available on the C<$c> object (the invocant of all controller methods,
and therefore other helpers).

=cut

sub register ($self, $app, $config) {

    state sub address ($user) {
        my $name = $user->name;
        my $email = $user->email;
        return $name eq $email
            ? $email
            : '"'.$name.'" <'.$email.'>';
    }

=head2 send_mail

    $c->send_mail(
        template_file => $filename, # file in templates/email, without extension
            # OR
        template => $template_string,
            # OR
        content => $raw_content,

        To => $to_email,        # defaults to stashed 'target_user'
        From => $from_email,    # defaults to stashed 'user'
        Subject => $subject,

        # ... all additional arguments are passed to the template renderer ...
    );

=cut

    $app->helper(send_mail => sub ($c, %args) {
        state sub compose_message ($c, %args) {
            # see Mojolicious::Guides::Rendering, Mojo::Template
            my $content = $args{content} // $c->render_to_string(
                $args{template_file}
                    ? (template => 'email/'.$args{template_file})
                    : (inline => $args{template} // 'missing template'),
                format => 'txt',    # handler defaults to 'ep'
                %args,
            );

            my $to = $args{To} // address($c->stash('target_user'));
            my $from = $args{From} // address($c->stash('user'));
            $from .= '@'.($config->{mail}{from_host}//$c->host) if $from !~ /@/;
            my $subject = $args{Subject} // 'Important email from Conch';

            return Email::Simple->create(
                header => [
                    To => $to,
                    From => $from,
                    Subject => $subject,
                ],
                body => $content,
            );
        }

        my $email = compose_message($c, %args);
        my $log = $c->log;
        my $request_id = length($c->req->url) ? $c->req->request_id : undef;

        Mojo::IOLoop->subprocess(
            # called in the context of the child process; returns the email object that was
            # sent for delivery
            sub ($subprocess) {
                local $Conch::Log::REQUEST_ID = $request_id;
                $log->info('sending email "'
                    .($args{template_file} // substr(0,20,$args{template} // $args{content}).'...')
                    .'" to '.$email->header('to').' from '.$email->header('from')
                );

                my $result = try {
                    Email::Sender::Simple->send($email, {
                        transport => Email::Sender::Transport::SMTP->new($config->{mail}{transport} // {}),
                    });
                }
                catch {
                    my $exception = $_;
                    $c->send_exception_to_rollbar(Mojo::Exception->new($exception));
                    die $exception->$_can('message') ? $exception->message."\n" : $exception;
                };

                return $result, $email;
            },

            # called in the context of the parent process on completion
            sub ($subprocess, $err, @args) {
                local $Conch::Log::REQUEST_ID = $request_id;
                if ($err) {
                    $log->error('sending email errored: '.$err);
                    return;
                }

                my ($result, $email) = @args;

                # this is typically the receipt response from sendmail
                # (methods not available because the class was never composed in this process)
                if ($result->{message}) {
                    chomp $result->{message};
                    $log->debug('sent email: '.$result->{message});
                }
            },
        );

        # the only listener here is in our test infrastructure
        $c->app->plugins->emit(mail_composed => $email);
    });

=head2 construct_address_list

Given a list of L<user|Conch::DB::Result::UserAccount> records, returns a string suitable to be
used in a C<To> header, comprising names and email addresses.

=cut

    $app->helper(construct_address_list => sub ($c, @users) {
        join(', ', map address($_), @users);
    });
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
# vim: set ts=4 sts=4 sw=4 et :
