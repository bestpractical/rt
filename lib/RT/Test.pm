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
    my $dbh = _get_dbh(RT::Handle->SystemDSN,
               $ENV{RT_DBA_USER}, $ENV{RT_DBA_PASSWORD});
    RT::Handle->DropDatabase( $dbh, Force => 1 );
    RT::Handle->CreateDatabase( $dbh );
    $dbh->disconnect;

    $dbh = _get_dbh(RT::Handle->DSN,
            $ENV{RT_DBA_USER}, $ENV{RT_DBA_PASSWORD});

    $RT::Handle = new RT::Handle;
    $RT::Handle->dbh( $dbh );
    $RT::Handle->InsertSchema( $dbh );

    my $db_type = RT->Config->Get('DatabaseType');
    $RT::Handle->InsertACL( $dbh ) unless $db_type eq 'Oracle';

    $RT::Handle = new RT::Handle;
    $RT::Handle->dbh( undef );
    RT->ConnectToDatabase;
    RT->InitLogging;
    $RT::Handle->InsertInitialData;

    DBIx::SearchBuilder::Record::Cachable->FlushCache;
    $RT::Handle = new RT::Handle;
    $RT::Handle->dbh( undef );
    RT->Init;

    $RT::Handle->PrintError;
    $RT::Handle->dbh->{PrintError} = 1;

    unless ( ($_[0] || '') eq 'nodata' ) {
        $RT::Handle->InsertData( $RT::EtcPath . "/initialdata" );
    }
    DBIx::SearchBuilder::Record::Cachable->FlushCache;
    RT->Init;
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
        { RaiseError => 0, PrintError => 1 },
    );
    unless ( $dbh ) {
        my $msg = "Failed to connect to $dsn as user '$user': ". $DBI::errstr;
    print STDERR $msg; exit -1;
    }
    return $dbh;
}


1;
