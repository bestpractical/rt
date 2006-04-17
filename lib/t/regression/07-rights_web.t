#!/usr/bin/perl -w
use strict;

use Test::More tests => 12;
BEGIN {
    use RT;
    RT::LoadConfig;
    RT::Init;
}
use constant BaseURL => "http://localhost:".RT->Config->Get('WebPort').RT->Config->Get('WebPath')."/";

use Test::WWW::Mechanize;
my $m = Test::WWW::Mechanize->new;
isa_ok($m, 'Test::WWW::Mechanize');

$m->get( BaseURL."?user=root;pass=password" );
$m->content_like(qr/Logout/, 'we did log in');
$m->follow_link_ok({ text => 'Configuration' });
$m->follow_link_ok({ text => 'Global' });
$m->follow_link_ok({ text => 'Group Rights' });


sub get_rights {
    my $agent = shift;
    my $principal_id = shift;
    my $object = shift;
    $agent->form_number(3);
    my @inputs = $agent->current_form->find_input("RevokeRight-$principal_id-$object");
    my @rights = sort grep $_, map $_->possible_values, grep $_, @inputs;
    return @rights;
};

my $everyone = RT::Group->new( $RT::SystemUser );
$everyone->LoadSystemInternalGroup('Everyone');
ok(my $everyone_gid = $everyone->id, "loaded 'everyone' group");

my @has = get_rights( $m, $everyone_gid, 'RT::System-1' );
if ( @has ) {
    $m->form_number(3);
    $m->tick("RevokeRight-$everyone_gid-RT::System-1", $_) foreach @has;
    $m->submit;
    
    is_deeply([get_rights( $m, $everyone_gid, 'RT::System-1' )], [], 'deleted all rights' );
}

{
    $m->form_number(3);
    $m->select("GrantRight-$everyone_gid-RT::System-1", ['SuperUser']);
    $m->submit;

    $m->content_contains('Right Granted', 'got message');
    RT::Principal::InvalidateACLCache();
    ok($everyone->PrincipalObj->HasRight( Right => 'SuperUser', Object => $RT::System ), 'group has right');
    is_deeply( [get_rights( $m, $everyone_gid, 'RT::System-1' )], ['SuperUser'], 'granted SuperUser right' );
}

{
    $m->form_number(3);
    $m->tick("RevokeRight-$everyone_gid-RT::System-1", 'SuperUser');
    $m->submit;

    $m->content_contains('Right revoked', 'got message');
    RT::Principal::InvalidateACLCache();
    ok(!$everyone->PrincipalObj->HasRight( Right => 'SuperUser', Object => $RT::System ), 'group has no right');
    is_deeply( [get_rights( $m, $everyone_gid, 'RT::System-1' )], [], 'revoked SuperUser right' );
}

