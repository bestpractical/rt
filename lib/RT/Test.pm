package RT::Test;

use Test::More;

my $port;
use File::Temp;
my $config;

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
    $ENV{RT_SITE_CONFIG} = $config;
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
    require RT::Handle;
    RT::Handle->drop_db(undef, { force => 1});
    RT::Handle->create_db;

    RT->ConnectToDatabase;
    $RT::Handle->insert_schema($dbh);
    $RT::Handle->insert_initial_data();
    $RT::Handle->insert_data( $RT::EtcPath . "/initialdata" );
    RT::Init;
}

sub started_ok {
    my $s = RT::Interface::Web::Standalone->new($port);
    push @server, $s;
    return ($s->started_ok, Test::WWW::Mechanize->new);
}


1;
