# vim: set ft=perl ts=8 sts=4 sw=4 et :

print "Installing dependencies for conch, using $^X at version $]\n";
print "PERL5LIB=$ENV{PERL5LIB}\n\n";

requires 'perl', '5.026';


# basics
requires 'Cpanel::JSON::XS';
requires 'List::MoreUtils::XS';         # make List::MoreUtils faster
requires 'Data::UUID';
requires 'List::Compare';
requires 'Mail::Sendmail';
requires 'Try::Tiny';
requires 'Class::StrongSingleton';
requires 'Time::HiRes';
requires 'Time::Moment', '>= 0.43'; # for PR#28, fixes use of stdbool.h (thanks Dale)
requires 'JSON::Validator', '2.14';
requires 'Pod::Github', '>= 0.04';
requires 'Data::Validate::IP';      # for json schema validation of 'ipv4', 'ipv6' types
requires 'HTTP::Tiny';
requires 'Safe::Isa';
requires 'Encode', '2.98';
requires 'Capture::Tiny';
requires 'Dir::Self';
requires 'Carp';
requires 'Crypt::Eksblowfish::Bcrypt';
requires 'Module::Runtime';

# mojolicious and networking
requires 'Mojolicious', '7.87'; # for Mojo::JSON's bootstrapping of Cpanel::JSON::XS
requires 'Mojo::Pg';
requires 'Mojo::Server::PSGI';
requires 'Mojo::JWT';
requires 'Mojolicious::Plugin::Bcrypt';
requires 'Mojolicious::Plugin::Util::RandomString', '0.07'; # memory leak: https://rt.cpan.org/Ticket/Display.html?id=125981
requires 'Mojolicious::Plugin::NYTProf';
requires 'Mozilla::CA'; # not used directly, but IO::Socket::SSL sometimes demands it
requires 'IO::Socket::SSL';

requires 'Path::Tiny';
requires 'Moo';
requires 'Type::Tiny';
requires 'Types::Standard';
requires 'Types::UUID';
requires 'Role::Tiny';
requires 'Getopt::Long::Descriptive';
requires 'Session::Token';
requires 'Sys::Hostname';

# debugging aids
requires 'Data::Printer', '0.99_019', dist => 'GARU/Data-Printer-0.99_019.tar.gz';
requires 'Devel::Confess';

# database and rendering
requires 'DBD::Pg';
requires 'DBIx::Class';
requires 'DBIx::Class::Schema::Loader';
requires 'DBIx::Class::Helpers';
requires 'DateTime::Format::Pg';    # used by DBIx::Class::Storage::DBI::Pg
requires 'DBIx::Class::InflateColumn::TimeMoment';
requires 'Lingua::EN::Inflexion';
requires 'Text::CSV_XS';


on 'test' => sub {
    requires 'Test::More';
    requires 'Test::PostgreSQL', '1.27';
    requires 'Test::Pod::Coverage';
    requires 'YAML::XS';
    requires 'Test::Pod', '1.41';
    requires 'Test::Warnings';
    requires 'Test::Fatal';
    requires 'Test::Deep';
    requires 'Test::Memory::Cycle';
    requires 'Module::CPANfile';
    requires 'DBIx::Class::EasyFixture', '0.13';    # Moo not Moose
    requires 'Moo';
    requires 'MooX::HandlesVia';
};

# note: DBD::Pg will fail to install on macos 10.13.x because Apple is
# shipping a bad berkeley-db. To fix (do this in a subshell you will close
# afterward, so as to not pollute your environment):
# sudo port install db48    # you may have this already
# eval $(perl -Mlocal::lib='local/lib/perl5')
# cpanm --look DB_File
# (you're now in another subshell)
# edit config.in to add these two lines, replacing the existing INCLUDE and LIB lines:
#   INCLUDE	= /opt/local/include/db48
#   LIB	= /opt/local/lib/db48
# perl Makefile.PL; make install
# <close subshell>
# see also: https://rt.cpan.org/Public/Bug/Display.html?id=125238
# and https://rt.perl.org/Ticket/Display.html?id=133280
