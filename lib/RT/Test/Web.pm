package RT::Test::Web;

use strict;
use warnings;

use base qw(Test::WWW::Mechanize);

sub rt_base_url {
    return "http://localhost:" . RT->Config->Get('WebPort') . RT->Config->Get('WebPath') . "/";
}

sub login {
    my $self = shift;
    my $user = shift || 'root';
    my $pass = shift || 'password';
    
    my $url = $self->rt_base_url;

    $self->get($url . "?user=$user;pass=$pass");
    return 0 unless $self->status == 200;
    return 0 unless $self->content =~ qr/Logout/i;
    return 1;
}

1;
