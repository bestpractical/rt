package RT::Test::Web;

use strict;
use warnings;

use base qw(Jifty::Test::WWW::Mechanize);

require RT::Test;
require Test::More;

sub get_ok {
    my $self = shift;
    my $url  = shift;
    if ( $url =~ m{^/} ) {
        $url = $self->rt_base_url . $url;
    }
    return $self->SUPER::get_ok( $url, @_ );
}

sub rt_base_url {
    return $RT::Test::existing_server if $RT::Test::existing_server;
    return $RT::Test::server_url      if $RT::Test::server_url;
}

sub login {
    my $self = shift;
    my $user = shift || 'root';
    my $pass = shift || 'password';

    my $url = $self->rt_base_url;

    $self->get( $url . "/logout" );
    $self->get($url);

    my $moniker = $self->moniker_for('RT::Action::Login');

    $self->fill_in_action( $moniker, email => $user, password => $pass );
    $self->submit();
    unless ( $self->status == 200 ) {
        Test::More::diag( "error: status is " . $self->status );
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
        Test::More::diag(
            "error: wrong id " . defined $id ? $id : '(undef)' );
        return 0;
    }

    my $url = $self->rt_base_url;
    $url .= "/Ticket/Display.html?id=$id";
    $self->get($url);
    unless ( $self->status == 200 ) {
        Test::More::diag( "error: status is " . $self->status );
        return 0;
    }
    return 1;
}

sub goto_create_ticket {
    my $self  = shift;
    my $queue = shift;

    my $id;
    if ( ref $queue ) {
        $id = $queue->id;
    } elsif ( $queue =~ /^\d+$/ ) {
        $id = $queue;
    } else {
        die "not yet implemented";
    }

    $self->get('/');
    $self->form_name('create_ticketInQueue');
    $self->select( 'Queue', $id );
    $self->submit;

    return 1;
}

1;
