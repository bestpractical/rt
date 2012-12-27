
use strict;
use warnings;

use RT::Test;
use HTML::TreeBuilder;

my ( $baseurl, $m ) = RT::Test->started_ok;

ok( $m->login( 'root' => 'password' ), 'login as root' );

my %viewed = ( '/NoAuth/Logout.html' => 1 );    # in case logout

my $user = RT::User->new($RT::SystemUser);
$user->Load('root');
ok( $user->id, 'loaded root' );

my $queue = RT::Queue->new($RT::SystemUser);
$queue->Load('General');
ok( $queue->id, 'loaded General queue' );

my $group = RT::Group->new($RT::SystemUser);
ok( $group->CreateUserDefinedGroup( Name => 'group_foo' ) );
my $cf = RT::CustomField->new($RT::SystemUser);
ok(
    $cf->Create(
        Name       => 'cf_foo',
        Type       => 'Freeform',
        LookupType => 'RT::Queue-RT::Ticket',
    )
);
ok( $cf->id, 'created cf_foo' );

my $class = RT::Class->new($RT::SystemUser);
ok( $class->Create( Name => 'class_foo' ) );
ok( $class->id, 'created class_foo' );

# to make search have results
my $open_ticket = RT::Test->create_ticket(
    Subject => 'ticket_foo',
    Queue   => 1,
);

my $resolved_ticket = RT::Test->create_ticket(
    Subject => 'ticket_bar',
    Status  => 'resolved',
    Queue   => 1,
);

my @links = (
    '/',
    '/Admin/Users/Modify.html?id=' . $user->id,
    '/Admin/Groups/Modify.html?id=' . $group->id,
    '/Admin/Queues/Modify.html?id=' . $queue->id,
    '/Admin/CustomFields/Modify.html?id=' . $cf->id,
    '/Admin/Scrips/Modify.html?id=1',
    '/Admin/Global/Template.html?Template=1',
    '/Admin/Articles/Classes/Modify.html?id=' . $class->id,
    '/Search/Build.html?Query=id<10',
    '/Ticket/Display.html?id=' . $open_ticket->id,
    '/Ticket/Display.html?id=' . $resolved_ticket->id,
);

for my $link (@links) {
    test_page($m, $link);
}

$m->get_ok('/NoAuth/Logout.html');

sub test_page {
    my $m = shift;
    my $link = shift;
    $m->get_ok( $link, $link );
    $m->no_warnings_ok($link);

    my $tree = HTML::TreeBuilder->new();
    $tree->parse( $m->content );
    $tree->elementify;
    my ($top_menu)  = $tree->look_down( id => 'main-navigation' );
    my ($page_menu) = $tree->look_down( id => 'page-navigation' );

    my (@links) =
      grep { !$viewed{$_}++ && /^[^#]/ }
      map { $_->attr('href') || () } ( $top_menu ? $top_menu->find('a') : () ),
      ( $page_menu ? $page_menu->find('a') : () );

    for my $link (@links) {
        test_page($m, $link);
    }
}

