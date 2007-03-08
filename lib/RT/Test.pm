package RT::Test;

use strict;
use warnings;

use Test::More;

use File::Temp;
my $config;
my $port;

BEGIN {
    # TODO: allocate a port dynamically
    $config = File::Temp->new;
    $port = 11229;
    print $config qq{
Set( \$WebPort , $port);
Set( \$WebBaseURL , "http://localhost:\$WebPort");
Set( \$DatabaseName , "rt3test");
1;
};
    close $config;
    $ENV{RT_SITE_CONFIG} = $config->filename;
    use RT;
    RT::LoadConfig;
    if (RT->Config->Get('DevelMode')) { require Module::Refresh; }

};

use RT::Interface::Web::Standalone;
use Test::HTTP::Server::Simple;
use Test::WWW::Mechanize;

unshift @RT::Interface::Web::Standalone::ISA, 'Test::HTTP::Server::Simple';

my @server;

sub import {
    my $class = shift;
    require RT::Handle;
    # bootstrap with dba cred
    my $dbh = _get_dbh(RT::Handle->get_system_dsn,
		       $ENV{RT_DBA_USER}, $ENV{RT_DBA_PASSWORD});
    my $db_type = RT->Config->Get('DatabaseType');

    RT::Handle->drop_db( $dbh, { force => 1 } );
    RT::Handle->create_db( $dbh );

    $dbh->disconnect;
    $dbh = _get_dbh(RT::Handle->get_rt_dsn,
		    $ENV{RT_DBA_USER}, $ENV{RT_DBA_PASSWORD});

    RT->ConnectToDatabase;
    $RT::Handle->insert_schema($dbh);
    $RT::Handle->insert_acl($dbh) unless $db_type eq 'Oracle';
    $RT::Handle->insert_initial_data();

    unless ( ($_[0] || '') eq 'nodata' ) {
        $RT::Handle->insert_data( $RT::EtcPath . "/initialdata" );
    }
    RT::Init;
}

sub started_ok {
    my $s = RT::Interface::Web::Standalone->new($port);
    push @server, $s;
    return ($s->started_ok, Test::WWW::Mechanize->new);
}

sub _get_dbh {
    my ($dsn, $user, $pass) = @_;
    my $dbh = DBI->connect(
        $dsn, $user, $pass,
        { RaiseError => 0, PrintError => 0 },
    );
    unless ( $dbh ) {
        my $msg = "Failed to connect to $dsn as user '$user': ". $DBI::errstr;
	print STDERR $msg; exit -1;
    }
    return $dbh;
}


1;
