use strict;
use warnings;

use RT::Test;

{
    my $french = RT::User->new(RT->SystemUser);
    $french->LoadOrCreateByEmail('french@example.com');
    $french->SetName('french');
    $french->SetLang('fr');
    $french->SetPrivileged(1);
    $french->SetPassword('password');
    $french->PrincipalObj->GrantRight(Right => 'SuperUser');
}


my ($baseurl, $m) = RT::Test->started_ok;
$m->login( root => "password" );
$m->get_ok('/Prefs/Other.html');
$m->content_lacks('Ne pas','Lacks translated french');
$m->get_ok( "/NoAuth/Logout.html" );

$m->login( french => "password" );
$m->get_ok('/Prefs/Other.html');
$m->content_contains('Ne pas','Has translated french');
$m->get_ok( "/NoAuth/Logout.html" ); # ->logout fails because it's translated

$m->login( root => "password" );
$m->get_ok('/Prefs/Other.html');
$m->content_lacks('Ne pas','Lacks translated french');
