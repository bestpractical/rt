use strict;
use warnings;

use RT::Test tests => undef;

eval { require RT::Authen::ExternalAuth; require Net::LDAP::Server::Test; 1; } or do {
    plan skip_all => 'Unable to test without Net::LDAP and Net::LDAP::Server::Test';
};

setup_auth_source();

RT->Config->Set("WebSessionClass" => "Apache::Session::File");

{
    my %sessions;
    sub sessions_seen_is {
        local $Test::Builder::Level = $Test::Builder::Level + 1;

        my ($agent, $expected, $msg) = @_;
        $msg ||= "$expected sessions seen";

        $agent->cookie_jar->scan(sub { $sessions{$_[2]}++ if $_[1] =~ /SID/; });
        is scalar keys %sessions, $expected, $msg;
    }
}

my ($base, $m) = RT::Test->started_ok();

diag "Login as tom";
{
    sessions_seen_is($m, 0);

    $m->get_ok("/");
    $m->submit_form(
        with_fields => {
            user => 'tom',
            pass => 'password',
        },
    );
    $m->text_contains( 'Logout', 'logged in via form' );
    sessions_seen_is($m, 1);

    $m->get_ok("/NoAuth/Logout.html");
    sessions_seen_is($m, 2);
}

diag "Login as alex";
{
    $m->get_ok("/");
    $m->submit_form(
        with_fields => {
            user => 'alex',
            pass => 'password',
        },
    );
    $m->text_contains( 'Logout', 'logged in via form' );
    sessions_seen_is($m, 3);

    $m->get_ok("/NoAuth/Logout.html");
    sessions_seen_is($m, 4);
}

done_testing;

sub setup_auth_source {
    require DBI;
    require File::Temp;
    require Digest::MD5;
    require File::Spec;

    eval { require DBD::SQLite; } or do {
        plan skip_all => 'Unable to test without DBD::SQLite';
    };

    my $dir    = File::Temp::tempdir( CLEANUP => 1 );
    my $dbname = File::Spec->catfile( $dir, 'rtauthtest' );
    my $table  = 'users';
    my $dbh = DBI->connect("dbi:SQLite:$dbname");
    my $password = Digest::MD5::md5_hex('password');
    my $schema = <<"    EOF";
        CREATE TABLE users (
          username varchar(200) NOT NULL,
          password varchar(40) NULL,
          email varchar(16) NULL
        );
    EOF
    $dbh->do( $schema );

    foreach my $user ( qw(tom alex) ){
        $dbh->do(<<"            SQL");
            INSERT INTO $table VALUES
            ( '$user',  '$password', '$user\@invalid.tld');
            SQL
    }

    RT->Config->Set( ExternalAuthPriority        => ['My_SQLite'] );
    RT->Config->Set( ExternalInfoPriority        => ['My_SQLite'] );
    RT->Config->Set( AutoCreateNonExternalUsers  => 0 );
    RT->Config->Set( AutoCreate                  => undef );
    RT->Config->Set(
        ExternalSettings => {
            'My_SQLite' => {
                'type'   => 'db',
                'database'        => $dbname,
                'table'           => $table,
                'dbi_driver'      => 'SQLite',
                'u_field'         => 'username',
                'p_field'         => 'password',
                'p_enc_pkg'       => 'Digest::MD5',
                'p_enc_sub'       => 'md5_hex',
                'attr_match_list' => ['Name'],
                'attr_map'        => {
                    'Name'           => 'username',
                    'EmailAddress'   => 'email',
                }
            },
        }
    );
    RT->Config->PostLoadCheck;
}

