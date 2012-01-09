#!/usr/bin/env perl
use strict;
use warnings;

use RT::Test tests => undef;

my $queue = RT::Test->load_or_create_queue( Name => 'Test' );
ok $queue && $queue->id, 'loaded or created queue';

my $user = RT::Test->load_or_create_user(
    Name        => 'ausername',
    Privileged  => 1,
);
ok $user && $user->id, 'loaded or created user';

my $group = RT::Group->new(RT->SystemUser);
my ($ok, $msg) = $group->CreateUserDefinedGroup(Name => 'Disabled Group');
ok($ok, $msg);

($ok, $msg) = $group->AddMember( $user->PrincipalId );
ok($ok, $msg);

ok( RT::Test->set_rights({
    Principal   => $group,
    Object      => $queue,
    Right       => [qw(OwnTicket)]
}), 'set rights');

RT->Config->Set( AutocompleteOwners => 0 );
my ($base, $m) = RT::Test->started_ok;
ok $m->login, 'logged in';

diag "user from group shows up in create form";
{
    $m->get_ok('/', 'open home page');
    $m->form_name('CreateTicketInQueue');
    $m->select( 'Queue', $queue->id );
    $m->submit;

    $m->content_contains('Create a new ticket', 'opened create ticket page');
    my $form = $m->form_name('TicketCreate');
    my $input = $form->find_input('Owner');
    is $input->value, RT->Nobody->Id, 'correct owner selected';
    ok((scalar grep { $_ == $user->Id } $input->possible_values), 'user from group is in dropdown');
}

diag "user from disabled group DOESN'T shows up in create form";
{
    ($ok, $msg) = $group->SetDisabled(1);
    ok($ok, $msg);

    $m->get_ok('/', 'open home page');
    $m->form_name('CreateTicketInQueue');
    $m->select( 'Queue', $queue->id );
    $m->submit;

    $m->content_contains('Create a new ticket', 'opened create ticket page');
    my $form = $m->form_name('TicketCreate');
    my $input = $form->find_input('Owner');
    is $input->value, RT->Nobody->Id, 'correct owner selected';
    ok((not scalar grep { $_ == $user->Id } $input->possible_values), 'user from disabled group is NOT in dropdown');
}

undef $m;
done_testing;
