
use strict;
use warnings;
use RT::Test tests => 39;

my ( $url, $m ) = RT::Test->started_ok;

$m->login();

my @links = (
    '/',                                '/Ticket/Create.html?Queue=1',
    '/SelfService/Create.html?Queue=1', '/m/ticket/create?Queue=1'
);

my $root = RT::Test->load_or_create_user( Name => 'root' );
ok( $root->id, 'loaded root' );
is( $root->EmailAddress, 'root@localhost', 'default root email' );

for my $link (@links) {
    $m->get_ok($link);
    $m->content_contains( '"root@localhost"', "default email in $link" );
}

$root->SetEmailAddress('foo@example.com');
is( $root->EmailAddress, 'foo@example.com', 'changed to foo@example.com' );

for my $link (@links) {
    $m->get_ok($link);
    $m->content_lacks( '"root@localhost"', "no default email in $link" );
    $m->content_contains( '"foo@example.com"', "new email in $link" );
}

$root->SetEmailAddress('root@localhost');
is( $root->EmailAddress, 'root@localhost', 'changed back to root@localhost' );

for my $link (@links) {
    $m->get_ok($link);
    $m->content_lacks( '"foo@example.com"', "no previous email in $link" );
    $m->content_contains( '"root@localhost"', "default email in $link" );
}

