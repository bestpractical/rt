package RT::Test;

use strict;
use warnings;

use Test::More;

use File::Temp;
my $config;
my $port;
my $existing_server;
my $mailsent;

BEGIN {
    # TODO: allocate a port dynamically
    if (my $test_server = $ENV{RT_TEST_SERVER}) {
	my ($host, $test_port) = split(':', $test_server, 2);
	$port = $test_port || 80;
	$existing_server = "http://$host:$port";
    }
    else {
	$port = 11229;
    }
    $config = File::Temp->new;
    print $config qq{
Set( \$WebPort , $port);
Set( \$WebBaseURL , "http://localhost:\$WebPort");
Set( \$DatabaseName , "rt3test");
Set( \$LogToSyslog , undef);
Set( \$LogToScreen , "warning");
1;
};
    close $config;
    $ENV{RT_SITE_CONFIG} = $config->filename;
    use RT;
    RT::LoadConfig;
    if (RT->Config->Get('DevelMode')) { require Module::Refresh; }

    # make it another function
    $mailsent = 0;
    my $mailfunc = sub { 
	my $Entity = shift;
	$mailsent++;
	return 1;
    };
    RT::Config->Set( 'MailCommand' => $mailfunc);


};

use RT::Interface::Web::Standalone;
use Test::HTTP::Server::Simple;
use Test::WWW::Mechanize;

unshift @RT::Interface::Web::Standalone::ISA, 'Test::HTTP::Server::Simple';

my @server;

sub import {
    my $class = shift;

    require RT::Handle;
    if ($existing_server) {
	RT->Init;
	return;
    }

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
    RT->InitSystemObjects;
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
    require RT::Test::Web;
    if ($existing_server) {
	ok(1, "using existing server $existing_server");
	warn $existing_server;
	return ($existing_server, RT::Test::Web->new);
    }
    my $s = RT::Interface::Web::Standalone->new($port);
    push @server, $s;
    my $ret = $s->started_ok;
    $RT::Handle = new RT::Handle;
    $RT::Handle->dbh( undef );
    RT->ConnectToDatabase;
    return ($ret, RT::Test::Web->new);
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

sub open_mailgate_ok {
    my $class   = shift;
    my $baseurl = shift;
    my $queue   = shift || 'general';
    my $action  = shift || 'correspond';
    ok(open(my $mail, "|$RT::BinPath/rt-mailgate --url $baseurl --queue $queue --action $action"), "Opened the mailgate - $!");
    return $mail;
}


sub close_mailgate_ok {
    my $class = shift;
    my $mail  = shift;
    close $mail;
    is ($? >> 8, 0, "The mail gateway exited normally. yay");
}

sub mailsent_ok {
    my $class = shift;
    my $expected  = shift;
    is ($mailsent, $expected, "The number of mail sent ($expected) matches. yay");
}

1;
