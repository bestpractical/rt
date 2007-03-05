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
1;
};
    close $config;
    $ENV{RT_SITE_CONFIG} = $config;
    use RT;
    RT::LoadConfig;
    if (RT->Config->Get('DevelMode')) { require Module::Refresh; }

};
RT::Init;

use RT::Interface::Web::Standalone;
use Test::HTTP::Server::Simple;
use Test::WWW::Mechanize;

unshift @RT::Interface::Web::Standalone::ISA, 'Test::HTTP::Server::Simple';

my @server;

sub started_ok {
    my $s = RT::Interface::Web::Standalone->new($port);
    push @server, $s;
    return ($s->started_ok, Test::WWW::Mechanize->new);
}


1;
