
use strict;
use warnings;

use RT::Test tests => 102;
use Test::Warn;
use_ok('RT');
use_ok('RT::Ticket');
use_ok('RT::ScripConditions');
use_ok('RT::ScripActions');
use_ok('RT::Template');
use_ok('RT::Scrips');
use_ok('RT::Scrip');


my $filename = File::Spec->catfile( RT::Test->temp_directory, 'link_count' );
open my $fh, '>', $filename or die $!;
close $fh;

my $link_acl_checks_orig = RT->Config->Get( 'StrictLinkACL' );
RT->Config->Set( 'StrictLinkACL', 1);

my $condition = RT::ScripCondition->new( RT->SystemUser );
$condition->Load('User Defined');
ok($condition->id);
my $action = RT::ScripAction->new( RT->SystemUser );
$action->Load('User Defined');
ok($action->id);
my $template = RT::Template->new( RT->SystemUser );
$template->Load('Blank');
ok($template->id);

my $q1 = RT::Queue->new(RT->SystemUser);
my ($id,$msg) = $q1->Create(Name => "LinkTest1.$$");
ok ($id,$msg);
my $q2 = RT::Queue->new(RT->SystemUser);
($id,$msg) = $q2->Create(Name => "LinkTest2.$$");
ok ($id,$msg);

my $commit_code = <<END;
open( my \$file, '<', "$filename" ) or die "couldn't open $filename";
my \$data = <\$file>;
\$data += 0;
close \$file;
\$RT::Logger->debug("Data is \$data");

open( \$file, '>', "$filename" ) or die "couldn't open $filename";
if (\$self->TransactionObj->Type eq 'AddLink') {
    \$RT::Logger->debug("AddLink");
    print \$file \$data+1, "\n";
}
elsif (\$self->TransactionObj->Type eq 'DeleteLink') {
    \$RT::Logger->debug("DeleteLink");
    print \$file \$data-1, "\n";
}
else {
    \$RT::Logger->error("THIS SHOULDN'T HAPPEN");
    print \$file "666\n";
}
close \$file;
1;
END

my $Scrips = RT::Scrips->new( RT->SystemUser );
$Scrips->UnLimit;
while ( my $Scrip = $Scrips->Next ) {
    $Scrip->Delete if $Scrip->Description and $Scrip->Description =~ /Add or Delete Link \d+/;
}


my $scrip = RT::Scrip->new(RT->SystemUser);
($id,$msg) = $scrip->Create( Description => "Add or Delete Link $$",
                          ScripCondition => $condition->id,
                          ScripAction    => $action->id,
                          Template       => $template->id,
                          Stage          => 'TransactionCreate',
                          Queue          => 0,
                  CustomIsApplicableCode => '$self->TransactionObj->Type =~ /(Add|Delete)Link/;',
                       CustomPrepareCode => '1;',
                       CustomCommitCode  => $commit_code,
                           );
ok($id, "Scrip created");

my $u1 = RT::User->new(RT->SystemUser);
($id,$msg) = $u1->Create(Name => "LinkTestUser.$$");
ok ($id,$msg);

# grant ShowTicket right to allow count transactions
($id,$msg) = $u1->PrincipalObj->GrantRight ( Object => $q1, Right => 'ShowTicket');
ok ($id,$msg);
($id,$msg) = $u1->PrincipalObj->GrantRight ( Object => $q2, Right => 'ShowTicket');
ok ($id,$msg);
($id,$msg) = $u1->PrincipalObj->GrantRight ( Object => $q1, Right => 'CreateTicket');
ok ($id,$msg);

my $creator = RT::CurrentUser->new($u1->id);

diag('Create tickets without rights to link');
{
    # on q2 we have no rights, yet
    my $parent = RT::Ticket->new( RT->SystemUser );
    my ($id,$tid,$msg) = $parent->Create( Subject => 'Link test 1', Queue => $q2->id );
    ok($id,$msg);
    my $child = RT::Ticket->new( $creator );
    ($id,$tid,$msg) = $child->Create( Subject => 'Link test 1', Queue => $q1->id, MemberOf => $parent->id );
    ok($id,$msg);
    $child->CurrentUser( RT->SystemUser );
    is($child->_Links('Base')->Count, 0, 'link was not created, no permissions');
    is($child->_Links('Target')->Count, 0, 'link was not create, no permissions');
}

diag('Create tickets with rights checks on one end of a link');
{
    # on q2 we have no rights, but use checking one only on thing
    RT->Config->Set( StrictLinkACL => 0 );
    my $parent = RT::Ticket->new( RT->SystemUser );
    my ($id,$tid,$msg) = $parent->Create( Subject => 'Link test 1', Queue => $q2->id );
    ok($id,$msg);
    my $child = RT::Ticket->new( $creator );
    ($id,$tid,$msg) = $child->Create( Subject => 'Link test 1', Queue => $q1->id, MemberOf => $parent->id );
    ok($id,$msg);
    $child->CurrentUser( RT->SystemUser );
    is($child->_Links('Base')->Count, 1, 'link was created');
    is($child->_Links('Target')->Count, 0, 'link was created only one');
    # only one scrip run (on second ticket) since this is on a ticket Create txn
    is(link_count($filename), 1, "scrips ok");
    RT->Config->Set( StrictLinkACL => 1 );
}

($id,$msg) = $u1->PrincipalObj->GrantRight ( Object => $q1, Right => 'ModifyTicket');
ok ($id,$msg);

diag('try to add link without rights');
{
    # on q2 we have no rights, yet
    my $parent = RT::Ticket->new( RT->SystemUser );
    my ($id,$tid,$msg) = $parent->Create( Subject => 'Link test 1', Queue => $q2->id );
    ok($id,$msg);
    my $child = RT::Ticket->new( $creator );
    ($id,$tid,$msg) = $child->Create( Subject => 'Link test 1', Queue => $q1->id );
    ok($id,$msg);
    ($id, $msg) = $child->AddLink(Type => 'MemberOf', Target => $parent->id);
    ok(!$id, $msg);
    is(link_count($filename), 0, "scrips ok");
    $child->CurrentUser( RT->SystemUser );
    is($child->_Links('Base')->Count, 0, 'link was not created, no permissions');
    is($child->_Links('Target')->Count, 0, 'link was not create, no permissions');
}

diag('add link with rights only on base');
{
    # on q2 we have no rights, but use checking one only on thing
    RT->Config->Set( StrictLinkACL => 0 );
    my $parent = RT::Ticket->new( RT->SystemUser );
    my ($id,$tid,$msg) = $parent->Create( Subject => 'Link test 1', Queue => $q2->id );
    ok($id,$msg);
    my $child = RT::Ticket->new( $creator );
    ($id,$tid,$msg) = $child->Create( Subject => 'Link test 1', Queue => $q1->id );
    ok($id,$msg);
    ($id, $msg) = $child->AddLink(Type => 'MemberOf', Target => $parent->id);
    ok($id, $msg);
    is(link_count($filename), 2, "scrips ok");
    $child->CurrentUser( RT->SystemUser );
    is($child->_Links('Base')->Count, 1, 'link was created');
    is($child->_Links('Target')->Count, 0, 'link was created only one');
    $child->CurrentUser( $creator );

    # turn off feature and try to delete link, we should fail
    RT->Config->Set( StrictLinkACL => 1 );
    ($id, $msg) = $child->DeleteLink(Type => 'MemberOf', Target => $parent->id);
    ok(!$id, $msg);
    is(link_count($filename), 0, "scrips ok");
    $child->CurrentUser( RT->SystemUser );
    $child->_Links('Base')->_DoCount;
    is($child->_Links('Base')->Count, 1, 'link was not deleted');
    $child->CurrentUser( $creator );

    # try to delete link, we should success as feature is active
    RT->Config->Set( StrictLinkACL => 0 );
    ($id, $msg) = $child->DeleteLink(Type => 'MemberOf', Target => $parent->id);
    ok($id, $msg);
    is(link_count($filename), -2, "scrips ok");
    $child->CurrentUser( RT->SystemUser );
    $child->_Links('Base')->_DoCount;
    is($child->_Links('Base')->Count, 0, 'link was deleted');
    RT->Config->Set( StrictLinkACL => 1 );
}

my $tid;
my $ticket = RT::Ticket->new( $creator);
ok($ticket->isa('RT::Ticket'));
($id,$tid, $msg) = $ticket->Create(Subject => 'Link test 1', Queue => $q1->id);
ok ($id,$msg);

diag('try link to itself');
{
    warning_like {
        ($id, $msg) = $ticket->AddLink(Type => 'RefersTo', Target => $ticket->id);
    } qr/Can't link a ticket to itself/;
    ok(!$id, $msg);
    is(link_count($filename), 0, "scrips ok");
}

my $ticket2 = RT::Ticket->new(RT->SystemUser);
($id, $tid, $msg) = $ticket2->Create(Subject => 'Link test 2', Queue => $q2->id);
ok ($id, $msg);
($id,$msg) =$ticket->AddLink(Type => 'RefersTo', Target => $ticket2->id);
ok(!$id,$msg);
is(link_count($filename), 0, "scrips ok");

($id,$msg) = $u1->PrincipalObj->GrantRight ( Object => $q2, Right => 'CreateTicket');
ok ($id,$msg);
($id,$msg) = $u1->PrincipalObj->GrantRight ( Object => $q2, Right => 'ModifyTicket');
ok ($id,$msg);
($id,$msg) = $ticket->AddLink(Type => 'RefersTo', Target => $ticket2->id);
ok($id,$msg);
is(link_count($filename), 2, "scrips ok");

warnings_like {
    ($id,$msg) = $ticket->AddLink(Type => 'RefersTo', Target => -1);
} [
    qr/Could not determine a URI scheme for -1/,
];

($id,$msg) = $ticket->AddLink(Type => 'RefersTo', Target => $ticket2->id);
ok($id,$msg);
is(link_count($filename), 0, "scrips ok"); # already added

my $transactions = $ticket2->Transactions;
$transactions->Limit( FIELD => 'Type', VALUE => 'AddLink' );
is( $transactions->Count, 1, "Transaction found in other ticket" );
is( $transactions->First->Field , 'ReferredToBy');
is( $transactions->First->NewValue , $ticket->URI );

($id,$msg) = $ticket->DeleteLink(Type => 'RefersTo', Target => $ticket2->id);
ok($id,$msg);
is(link_count($filename), -2, "scrips ok");
$transactions = $ticket2->Transactions;
$transactions->Limit( FIELD => 'Type', VALUE => 'DeleteLink' );
is( $transactions->Count, 1, "Transaction found in other ticket" );
is( $transactions->First->Field , 'ReferredToBy');
is( $transactions->First->OldValue , $ticket->URI );

($id,$msg) =$ticket->AddLink(Type => 'RefersTo', Target => $ticket2->id);
ok($id,$msg);
is(link_count($filename), 2, "scrips ok");
($id,$msg) =$ticket->DeleteLink(Type => 'RefersTo', Target => $ticket2->id);
ok($id,$msg);
is(link_count($filename), -2, "scrips ok");

# tests for silent behaviour
($id,$msg) = $ticket->AddLink(Type => 'RefersTo', Target => $ticket2->id, Silent => 1);
ok($id,$msg);
is(link_count($filename), 0, "scrips ok");
{
    my $transactions = $ticket->Transactions;
    $transactions->Limit( FIELD => 'Type', VALUE => 'AddLink' );
    is( $transactions->Count, 2, "Still two txns on the base" );

    $transactions = $ticket2->Transactions;
    $transactions->Limit( FIELD => 'Type', VALUE => 'AddLink' );
    is( $transactions->Count, 2, "Still two txns on the target" );

}
($id,$msg) =$ticket->DeleteLink(Type => 'RefersTo', Target => $ticket2->id, Silent => 1);
ok($id,$msg);
is(link_count($filename), 0, "scrips ok");

($id,$msg) = $ticket->AddLink(Type => 'RefersTo', Target => $ticket2->id, SilentBase => 1);
ok($id,$msg);
is(link_count($filename), 1, "scrips ok");
{
    my $transactions = $ticket->Transactions;
    $transactions->Limit( FIELD => 'Type', VALUE => 'AddLink' );
    is( $transactions->Count, 2, "still five txn on the base" );

    $transactions = $ticket2->Transactions;
    $transactions->Limit( FIELD => 'Type', VALUE => 'AddLink' );
    is( $transactions->Count, 3, "+1 txn on the target" );

}
($id,$msg) =$ticket->DeleteLink(Type => 'RefersTo', Target => $ticket2->id, SilentBase => 1);
ok($id,$msg);
is(link_count($filename), -1, "scrips ok");

($id,$msg) = $ticket->AddLink(Type => 'RefersTo', Target => $ticket2->id, SilentTarget => 1);
ok($id,$msg);
is(link_count($filename), 1, "scrips ok");
{
    my $transactions = $ticket->Transactions;
    $transactions->Limit( FIELD => 'Type', VALUE => 'AddLink' );
    is( $transactions->Count, 3, "+1 txn on the base" );

    $transactions = $ticket2->Transactions;
    $transactions->Limit( FIELD => 'Type', VALUE => 'AddLink' );
    is( $transactions->Count, 3, "three txns on the target" );
}
($id,$msg) =$ticket->DeleteLink(Type => 'RefersTo', Target => $ticket2->id, SilentTarget => 1);
ok($id,$msg);
is(link_count($filename), -1, "scrips ok");


# restore
RT->Config->Set( StrictLinkACL => $link_acl_checks_orig );

{
    my $Scrips = RT::Scrips->new( RT->SystemUser );
    $Scrips->Limit( FIELD => 'Description', OPERATOR => 'STARTSWITH', VALUE => 'Add or Delete Link ');
    while ( my $s = $Scrips->Next ) { $s->Delete };
}


my $link = RT::Link->new( RT->SystemUser );
($id,$msg) = $link->Create( Base => $ticket->URI, Target => $ticket2->URI, Type => 'MyLinkType' );
ok($id, $msg);
ok($link->LocalBase   == $ticket->id,  "LocalBase   set correctly");
ok($link->LocalTarget == $ticket2->id, "LocalTarget set correctly");

{
    no warnings 'once';
    *RT::NotTicket::Id = sub { return $$ };
    *RT::NotTicket::id = \&RT::NotTicket::Id;
}

{
    package RT::URI::not_ticket;
    use RT::URI::base;
    use vars qw(@ISA);
    @ISA = qw/RT::URI::base/;
    sub IsLocal { 1; }
    sub Object { return bless {}, 'RT::NotTicket'; }
}

my $orig_getresolver = \&RT::URI::_GetResolver;
{
    no warnings 'redefine';
    *RT::URI::_GetResolver = sub {
        my $self = shift;
        my $scheme = shift;

        $scheme =~ s/(\.|-)/_/g;
        my $resolver;
        my $module = "RT::URI::$scheme";
        $resolver = $module->new($self->CurrentUser);

       if ($resolver) {
           $self->{'resolver'} = $resolver;
        } else {
            $self->{'resolver'} = RT::URI::base->new($self->CurrentUser);
        }
    };
}

($id,$msg) = $link->Create( Base => "not_ticket::$RT::Organization/notticket/$$", Target => $ticket2->URI, Type => 'MyLinkType' );
ok($id, $msg);
ok($link->LocalBase   == 0,            "LocalBase set correctly");
ok($link->LocalTarget == $ticket2->id, "LocalTarget set correctly");

($id,$msg) = $link->Create( Target => "not_ticket::$RT::Organization/notticket/$$", Base => $ticket->URI, Type => 'MyLinkType' );
ok($id, $msg);
ok($link->LocalTarget == 0,           "LocalTarget set correctly");
ok($link->LocalBase   == $ticket->id, "LocalBase set correctly");

($id,$msg) = $link->Create(
                       Target => "not_ticket::$RT::Organization/notticket/1$$",
                       Base   => "not_ticket::$RT::Organization/notticket/$$",
                       Type => 'MyLinkType' );

ok($id, $msg);
ok($link->LocalTarget == 0, "LocalTarget set correctly");
ok($link->LocalBase   == 0, "LocalBase set correctly");

# restore _GetResolver
{
    no warnings 'redefine';
    *RT::URI::_GetResolver = $orig_getresolver;
}

sub link_count {
    my $file = shift;
    open( my $fh, '<', $file ) or die "couldn't open $file";
    my $data = <$fh>;
    close $fh;
    truncate($file, 0);

    return 0 unless defined $data;
    chomp $data;
    return $data + 0;
}
