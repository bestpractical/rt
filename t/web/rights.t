#!/usr/bin/perl -w
use strict;
use warnings;

use RT::Test tests => 14;

my ($baseurl, $m) = RT::Test->started_ok;
ok $m->login, "logged in";

$m->follow_link_ok({ id => 'tools-config-global-group-rights'});


sub get_rights {
    my $agent = shift;
    my $principal_id = shift;
    my $object = shift;
    $agent->form_name('ModifyGroupRights');
    my @inputs = $agent->current_form->find_input("SetRights-$principal_id-$object");
    my @rights = sort grep $_, map $_->possible_values, grep $_ && $_->value, @inputs;
    return @rights;
};

diag "load Everyone group";
my ($everyone, $everyone_gid);
{
    $everyone = RT::Group->new( RT->SystemUser );
    $everyone->LoadSystemInternalGroup('Everyone');
    ok($everyone_gid = $everyone->id, "loaded 'everyone' group");
}

diag "revoke all global rights from Everyone group";
my @has = get_rights( $m, $everyone_gid, 'RT::System-1' );
if ( @has ) {
    $m->form_name('ModifyGroupRights');
    $m->untick("SetRights-$everyone_gid-RT::System-1", $_) foreach @has;
    $m->submit;
    
    is_deeply([get_rights( $m, $everyone_gid, 'RT::System-1' )], [], 'deleted all rights' );
} else {
    ok(1, 'the group has no global rights');
}

diag "grant SuperUser right to everyone";
{
    $m->form_name('ModifyGroupRights');
    $m->tick("SetRights-$everyone_gid-RT::System-1", 'SuperUser');
    $m->submit;

    $m->content_contains('Right Granted', 'got message');
    RT::Principal::InvalidateACLCache();
    ok($everyone->PrincipalObj->HasRight( Right => 'SuperUser', Object => $RT::System ), 'group has right');
    is_deeply( [get_rights( $m, $everyone_gid, 'RT::System-1' )], ['SuperUser'], 'granted SuperUser right' );
}

diag "revoke the right";
{
    $m->form_name('ModifyGroupRights');
    $m->untick("SetRights-$everyone_gid-RT::System-1", 'SuperUser');
    $m->submit;

    $m->content_contains('Right revoked', 'got message');
    RT::Principal::InvalidateACLCache();
    ok(!$everyone->PrincipalObj->HasRight( Right => 'SuperUser', Object => $RT::System ), 'group has no right');
    is_deeply( [get_rights( $m, $everyone_gid, 'RT::System-1' )], [], 'revoked SuperUser right' );
}


diag "return rights the group had in the beginning";
if ( @has ) {
    $m->form_name('ModifyGroupRights');
    $m->tick("SetRights-$everyone_gid-RT::System-1", $_) for @has;
    $m->submit;

    $m->content_contains('Right Granted', 'got message');
    is_deeply(
        [ get_rights( $m, $everyone_gid, 'RT::System-1' ) ],
        [ @has ],
        'returned back all rights'
    );
} else {
    ok(1, 'the group had no global rights, so nothing to return');
}

