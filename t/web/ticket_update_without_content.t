use strict;
use warnings;

use RT::Test tests => 12;
my ( $url, $m ) = RT::Test->started_ok;

# merged tickets still show up in search
my $ticket = RT::Ticket->new(RT->SystemUser);
my ( $ret, $msg ) = $ticket->Create(
    Subject   => 'base ticket' . $$,
    Queue     => 'general',
    Owner     => 'root',
    Requestor => 'root@localhost',
    MIMEObj   => MIME::Entity->build(
        From    => 'root@localhost',
        To      => 'rt@localhost',
        Subject => 'base ticket' . $$,
        Data    => "",
    ),
);
ok( $ret, "ticket created: $msg" );

ok( $m->login, 'logged in' );

$m->get_ok( $url . "/Ticket/ModifyAll.html?id=" . $ticket->id );

$m->submit_form(
    form_number => 3,
    fields      => { Priority => '1', }
);

$m->content_contains("Priority changed");
$m->content_lacks("message recorded");

my $root = RT::User->new( RT->SystemUser );
$root->Load('root');
( $ret, $msg ) = $root->SetSignature(<<EOF);
best wishes
foo
EOF

ok( $ret, $msg );

$m->get_ok( $url . "/Ticket/ModifyAll.html?id=" . $ticket->id );

$m->submit_form(
    form_number => 3,
    fields      => { Priority => '2', }
);
$m->content_contains("Priority changed");
$m->content_lacks("message recorded");
