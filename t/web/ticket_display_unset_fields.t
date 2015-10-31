use strict;
use warnings;

use RT::Test tests => undef, config => 'Set( $HideUnsetFieldsOnDisplay, 1 );';

my @link_labels = (
    'Depends on',
    'Depended on by',
    'Parents',
    'Children',
    'Refers to',
    'Referred to by',
);

my $foo = RT::Test->create_ticket(
    Queue   => 'General',
    Subject => 'test display page',
);
my $dep = RT::Test->create_ticket(
    Queue   => 'General',
    Subject => 'dep ticket',
);
my $bar = RT::Test->create_ticket(
    Queue     => 'General',
    Subject   => 'depend ticket',
    Starts    => '2011-07-08 00:00:00',
    Started   => '2011-07-09 00:00:00',
    Resolved  => '2011-07-11 00:00:00',
    Due       => '2011-07-12 00:00:00',
    Cc        => 'foo@example.com',
    AdminCc   => 'admin@example.com',
    DependsOn => [ $dep->id ],
);
$bar->SetTold;

my ( $baseurl, $m ) = RT::Test->started_ok;

diag "test with root";
{
    $m->login;
    $m->goto_ticket( $foo->id );

    for my $label (qw/Starts Started Closed Cc AdminCc/) {
        $m->content_lacks( "$label:", "lacks $label as value is unset" );
    }

    # there is one Due: in reminder
    $m->content_unlike( qr/Due:.*Due:/s, "lacks Due as value is unset" );

    $m->content_contains( "Last Contact", "has Told as root can set it" );
    for my $label (@link_labels) {
        $m->content_contains( "$label:", "has $label as root can create" );
    }

    $m->goto_ticket( $bar->id );
    for my $label (qw/Starts Started Closed Cc AdminCc/) {
        $m->content_contains( "$label:", "has $label as value is set" );
    }
    $m->content_like( qr/Due:.*Due:/s, "has Due as value is set" );
}

diag "test without ModifyTicket right";
{
    my $user =
      RT::Test->load_or_create_user( Name => 'foo', Password => 'password' );
    RT::Test->set_rights( Principal => $user, Right => ['ShowTicket'] );
    $m->login( 'foo', 'password', logout => 1 );
    $m->goto_ticket( $foo->id );
    $m->content_lacks( "Last Contact", "lacks Told as it is unset" );
    for my $label ( @link_labels ) {
        $m->content_lacks( "$label:", "lacks $label as it is unset" );
    }

    $m->goto_ticket( $bar->id );
    $m->content_contains( "Depends on:", "has Depends on as it is set" );
}

undef $m;
done_testing;
