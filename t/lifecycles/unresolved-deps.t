use strict;
use warnings;

BEGIN {require  './t/lifecycles/utils.pl'};

my $general = RT::Test->load_or_create_queue(
    Name => 'General',
);
ok $general && $general->id, 'loaded or created a queue';

# different value tested in basics
RT->Config->Set('HideResolveActionsWithDependencies' => 1);

my ($baseurl, $m) = RT::Test->started_ok;
ok $m->login, 'logged in';

{
    my $child_ticket = RT::Test->create_ticket(
        Queue => $general->id,
        Subject => 'child',
    );
    my $cid = $child_ticket->id;
    my $parent_ticket = RT::Test->create_ticket(
        Queue => $general->id,
        Subject => 'parent',
        DependsOn => $child_ticket->id,
    );
    my $pid = $parent_ticket->id;

    ok $m->goto_ticket( $pid ), 'opened a ticket';
    $m->check_links(
        has => ['Open It'],
        has_no => ['Stall', 'Re-open', 'Undelete', 'Resolve', 'Reject', 'Delete'],
    );
    ok $m->goto_ticket( $cid ), 'opened a ticket';
    $m->check_links(
        has => ['Open It', 'Resolve', 'Reject', 'Delete'],
        has_no => ['Stall', 'Re-open', 'Undelete'],
    );
}

done_testing;
