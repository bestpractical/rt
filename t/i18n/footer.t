use strict;
use warnings;

use RT::Test;

{
    my $chinese = RT::User->new(RT->SystemUser);
    $chinese->LoadOrCreateByEmail('chinese@example.com');
    $chinese->SetName('chinese');
    $chinese->SetLang('zh_tw');
    $chinese->SetPrivileged(1);
    $chinese->SetPassword('password');
    $chinese->PrincipalObj->GrantRight(Right => 'SuperUser');
}

my ($baseurl, $m) = RT::Test->started_ok;
$m->login( root => "password" );
$m->content_contains('Copyright','Has english coypright');
$m->get_ok( "/NoAuth/Logout.html" );

$m->login( chinese => "password" );
$m->content_lacks('Copyright','Lacks english copyright');
$m->get_ok( "/NoAuth/Logout.html" ); # ->logout fails because it's translated

$m->login( root => "password" );
$m->content_contains('Copyright','Still has english copyright');

