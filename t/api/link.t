use strict;
use warnings;

use RT::Test nodata => 1, tests => 83;
use RT::Test::Web;
use Test::Warn;

use RT::Link;
my $link = RT::Link->new(RT->SystemUser);

ok (ref $link);
isa_ok( $link, 'RT::Link');
isa_ok( $link, 'RT::Base');
isa_ok( $link, 'RT::Record');
isa_ok( $link, 'DBIx::SearchBuilder::Record');

my $queue = RT::Test->load_or_create_queue(Name => 'General');
ok($queue->Id, "loaded the General queue");

my $parent = RT::Ticket->new(RT->SystemUser);
my ($pid, undef, $msg) = $parent->Create(
    Queue   => $queue->id,
    Subject => 'parent',
);
ok $pid, 'created a ticket #'. $pid or diag "error: $msg";

my $child = RT::Ticket->new(RT->SystemUser);
((my $cid), undef, $msg) = $child->Create(
    Queue   => $queue->id,
    Subject => 'child',
);
ok $cid, 'created a ticket #'. $cid or diag "error: $msg";

{
    my ($status, $msg);
    clean_links();

    ($status, $msg) = $parent->AddLink;
    ok(!$status, "didn't create a link: $msg");

    warning_like {
        ($status, $msg) = $parent->AddLink( Base => $parent->id );
    } qr/Can't link a ticket to itself/, "warned about linking a ticket to itself";
    ok(!$status, "didn't create a link: $msg");

    warning_like {
        ($status, $msg) = $parent->AddLink( Base => $parent->id, Type => 'HasMember' );
    } qr/Can't link a ticket to itself/, "warned about linking a ticket to itself";
    ok(!$status, "didn't create a link: $msg");
}

{
    clean_links();
    my ($status, $msg) = $parent->AddLink(
        Type => 'MemberOf', Base => $child->id,
    );
    ok($status, "created a link: $msg");

    my $children = $parent->Members;
    $children->RedoSearch; $children->GotoFirstItem;
    is $children->Count, 1, 'link is there';

    my $link = $children->First;
    ok $link->id, 'correct link';

    is $link->Type,        'MemberOf',  'type';
    is $link->LocalTarget, $parent->id, 'local target';
    is $link->LocalBase,   $child->id,  'local base';
    is $link->Target, 'fsck.com-rt://example.com/ticket/'. $parent->id, 'local target';
    is $link->Base,   'fsck.com-rt://example.com/ticket/'. $child->id,  'local base';

    isa_ok $link->TargetObj, 'RT::Ticket';
    is $link->TargetObj->id, $parent->id, 'correct ticket';

    isa_ok $link->TargetURI, 'RT::URI';
    is $link->TargetURI->Scheme, 'fsck.com-rt', 'correct scheme';
    is $link->TargetURI->URI,
        'fsck.com-rt://example.com/ticket/'. $parent->id,
        'correct URI'
    ;
    ok $link->TargetURI->IsLocal, 'local object';
    is $link->TargetURI->AsHREF,
        RT::Test::Web->rt_base_url .'Ticket/Display.html?id='. $parent->id,
        'correct href'
    ;

    isa_ok $link->BaseObj, 'RT::Ticket';
    is $link->BaseObj->id, $child->id, 'correct ticket';

    isa_ok $link->BaseURI, 'RT::URI';
    is $link->BaseURI->Scheme, 'fsck.com-rt', 'correct scheme';
    is $link->BaseURI->URI,
        'fsck.com-rt://example.com/ticket/'. $child->id,
        'correct URI'
    ;
    ok $link->BaseURI->IsLocal, 'local object';
    is $link->BaseURI->AsHREF,
        RT::Test::Web->rt_base_url .'Ticket/Display.html?id='. $child->id,
        'correct href'
    ;
}

{
    clean_links();
    my ($status, $msg) = $parent->AddLink(
        Type => 'MemberOf', Base => $child->URI,
    );
    ok($status, "created a link: $msg");

    my $children = $parent->Members;
    $children->RedoSearch; $children->GotoFirstItem;
    is $children->Count, 1, 'link is there';

    my $link = $children->First;
    ok $link->id, 'correct link';

    is $link->Type,        'MemberOf',  'type';
    is $link->LocalTarget, $parent->id, 'local target';
    is $link->LocalBase,   $child->id,  'local base';
    is $link->Target, 'fsck.com-rt://example.com/ticket/'. $parent->id, 'local target';
    is $link->Base,   'fsck.com-rt://example.com/ticket/'. $child->id,  'local base';

    isa_ok $link->TargetObj, 'RT::Ticket';
    is $link->TargetObj->id, $parent->id, 'correct ticket';

    isa_ok $link->TargetURI, 'RT::URI';
    is $link->TargetURI->Scheme, 'fsck.com-rt', 'correct scheme';
    is $link->TargetURI->URI,
        'fsck.com-rt://example.com/ticket/'. $parent->id,
        'correct URI'
    ;
    ok $link->TargetURI->IsLocal, 'local object';
    is $link->TargetURI->AsHREF,
        RT::Test::Web->rt_base_url .'Ticket/Display.html?id='. $parent->id,
        'correct href'
    ;

    isa_ok $link->BaseObj, 'RT::Ticket';
    is $link->BaseObj->id, $child->id, 'correct ticket';

    isa_ok $link->BaseURI, 'RT::URI';
    is $link->BaseURI->Scheme, 'fsck.com-rt', 'correct scheme';
    is $link->BaseURI->URI,
        'fsck.com-rt://example.com/ticket/'. $child->id,
        'correct URI'
    ;
    ok $link->BaseURI->IsLocal, 'local object';
    is $link->BaseURI->AsHREF,
        RT::Test::Web->rt_base_url .'Ticket/Display.html?id='. $child->id,
        'correct href'
    ;
}

{
    clean_links();
    my ($status, $msg) = $parent->AddLink(
        Type => 'MemberOf', Base => 't:'. $child->id,
    );
    ok($status, "created a link: $msg");

    my $children = $parent->Members;
    $children->RedoSearch; $children->GotoFirstItem;
    is $children->Count, 1, 'link is there';

    my $link = $children->First;
    ok $link->id, 'correct link';

    is $link->Type,        'MemberOf',  'type';
    is $link->LocalTarget, $parent->id, 'local target';
    is $link->LocalBase,   $child->id,  'local base';
    is $link->Target, 'fsck.com-rt://example.com/ticket/'. $parent->id, 'local target';
    is $link->Base,   'fsck.com-rt://example.com/ticket/'. $child->id,  'local base';

    isa_ok $link->TargetObj, 'RT::Ticket';
    is $link->TargetObj->id, $parent->id, 'correct ticket';

    isa_ok $link->TargetURI, 'RT::URI';
    is $link->TargetURI->Scheme, 'fsck.com-rt', 'correct scheme';
    is $link->TargetURI->URI,
        'fsck.com-rt://example.com/ticket/'. $parent->id,
        'correct URI'
    ;
    ok $link->TargetURI->IsLocal, 'local object';
    is $link->TargetURI->AsHREF,
        RT::Test::Web->rt_base_url .'Ticket/Display.html?id='. $parent->id,
        'correct href'
    ;

    isa_ok $link->BaseObj, 'RT::Ticket';
    is $link->BaseObj->id, $child->id, 'correct ticket';

    isa_ok $link->BaseURI, 'RT::URI';
    is $link->BaseURI->Scheme, 'fsck.com-rt', 'correct scheme';
    is $link->BaseURI->URI,
        'fsck.com-rt://example.com/ticket/'. $child->id,
        'correct URI'
    ;
    ok $link->BaseURI->IsLocal, 'local object';
    is $link->BaseURI->AsHREF,
        RT::Test::Web->rt_base_url .'Ticket/Display.html?id='. $child->id,
        'correct href'
    ;
}

{
    clean_links();
    $child->SetStatus('deleted');

    my ($status, $msg) = $parent->AddLink(
        Type => 'MemberOf', Base => $child->id,
    );
    ok(!$status, "can't link to deleted ticket: $msg");

    $child->SetStatus('new');
    ($status, $msg) = $parent->AddLink(
        Type => 'MemberOf', Base => $child->id,
    );
    ok($status, "created a link: $msg");

    $child->SetStatus('deleted');
    my $children = $parent->Members;
    $children->RedoSearch;

    my $total = 0;
    $total++ while $children->Next;
    is( $total, 0, 'Next skips deleted tickets' );

    is( @{ $children->ItemsArrayRef },
        0, 'ItemsArrayRef skips deleted tickets' );

    # back to active status
    $child->SetStatus('new');
}

sub clean_links {
    my $links = RT::Links->new( RT->SystemUser );
    $links->UnLimit;
    while ( my $link = $links->Next ) {
        my ($status, $msg) = $link->Delete;
        $RT::Logger->error("Couldn't delete a link: $msg")
            unless $status;
    }
}

