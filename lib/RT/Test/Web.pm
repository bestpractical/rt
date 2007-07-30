package RT::Test::Web;

use strict;
use warnings;

use base qw(Test::WWW::Mechanize);

require RT::Test;
require Test::More;

sub rt_base_url {
    return $RT::Test::existing_server if $RT::Test::existing_server;
    return "http://localhost:" . RT->Config->Get('WebPort') . RT->Config->Get('WebPath') . "/";
}

sub login {
    my $self = shift;
    my $user = shift || 'root';
    my $pass = shift || 'password';

    my $url = $self->rt_base_url;

    $self->get($url);
    Test::More::diag( "error: status is ". $self->status )
        unless $self->status == 200;
    if ( $self->content =~ qr/Logout/i ) {
        $self->follow_link( text => 'Logout' );
    }

    $self->get($url . "?user=$user;pass=$pass");
    unless ( $self->status == 200 ) {
        Test::More::diag( "error: status is ". $self->status );
        return 0;
    }
    unless ( $self->content =~ qr/Logout/i ) {
        Test::More::diag("error: page has no Logout");
        return 0;
    }
    return 1;
}

sub goto_ticket {
    my $self = shift;
    my $id   = shift;
    unless ( $id && int $id ) {
        Test::More::diag( "error: wrong id ". defined $id? $id : '(undef)' );
        return 0;
    }

    my $url = $self->rt_base_url;
    $url .= "/Ticket/Display.html?id=$id";
    $self->get($url);
    unless ( $self->status == 200 ) {
        Test::More::diag( "error: status is ". $self->status );
        return 0;
    }
    return 1;

}

1;
