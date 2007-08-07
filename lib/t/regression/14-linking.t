use Test::More  tests => '89';

use strict;
use warnings;

use_ok('RT');
use_ok('RT::Ticket');
use_ok('RT::ScripConditions');
use_ok('RT::ScripActions');
use_ok('RT::Template');
use_ok('RT::Scrips');
use_ok('RT::Scrip');
RT::LoadConfig();
RT::Init();

use File::Temp qw/tempfile/;
my ($fh, $filename) = tempfile( UNLINK => 1, SUFFIX => '.rt');
my $link_scrips_orig = RT->Config->Get( 'LinkTransactionsRun1Scrip' );
RT->Config->Set( 'LinkTransactionsRun1Scrip', 1 );

my $link_acl_checks_orig = RT->Config->Get( 'StrictLinkACL' );
RT->Config->Set( 'StrictLinkACL', 1);

my $condition = RT::ScripCondition->new( $RT::SystemUser );
$condition->Load('User Defined');
ok($condition->id);
my $action = RT::ScripAction->new( $RT::SystemUser );
$action->Load('User Defined');
ok($action->id);
my $template = RT::Template->new( $RT::SystemUser );
$template->Load('Blank');
ok($template->id);

my $q1 = RT::Queue->new($RT::SystemUser);
my ($id,$msg) = $q1->Create(Name => "LinkTest1.$$");
ok ($id,$msg);
my $q2 = RT::Queue->new($RT::SystemUser);
($id,$msg) = $q2->Create(Name => "LinkTest2.$$");
ok ($id,$msg);

my $commit_code = <<END;
open my \$file, "<$filename" or die "couldn't open $filename";
my \$data = <\$file>;
chomp \$data;
\$data += 0;
close \$file;
\$RT::Logger->debug("Data is \$data");

open \$file, ">$filename" or die "couldn't open $filename";
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

my $Scrips = RT::Scrips->new( $RT::SystemUser );
$Scrips->UnLimit;
while ( my $Scrip = $Scrips->Next ) {
    $Scrip->Delete if $Scrip->Description =~ /Add or Delete Link \d+/;
}


my $scrip = RT::Scrip->new($RT::SystemUser);
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

my $u1 = RT::User->new($RT::SystemUser);
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

diag('Create tickets without rights to link') if $ENV{'TEST_VERBOSE'};
{
    # on q2 we have no rights, yet
    my $parent = RT::Ticket->new( $RT::SystemUser );
    my ($id,$tid,$msg) = $parent->Create( Subject => 'Link test 1', Queue => $q2->id );
    ok($id,$msg);
    my $child = RT::Ticket->new( $creator );
    ($id,$tid,$msg) = $child->Create( Subject => 'Link test 1', Queue => $q1->id, MemberOf => $parent->id );
    ok($id,$msg);
    $child->CurrentUser( $RT::SystemUser );
    is($child->_Links('Base')->Count, 0, 'link was not created, no permissions');
    is($child->_Links('Target')->Count, 0, 'link was not create, no permissions');
}

diag('Create tickets with rights checks on one end of a link') if $ENV{'TEST_VERBOSE'};
{
    # on q2 we have no rights, but use checking one only on thing
    RT->Config->Set( StrictLinkACL => 0 );
    my $parent = RT::Ticket->new( $RT::SystemUser );
    my ($id,$tid,$msg) = $parent->Create( Subject => 'Link test 1', Queue => $q2->id );
    ok($id,$msg);
    my $child = RT::Ticket->new( $creator );
    ($id,$tid,$msg) = $child->Create( Subject => 'Link test 1', Queue => $q1->id, MemberOf => $parent->id );
    ok($id,$msg);
    $child->CurrentUser( $RT::SystemUser );
    is($child->_Links('Base')->Count, 1, 'link was created');
    is($child->_Links('Target')->Count, 0, 'link was created only one');
    # no scrip run on second ticket accroding to config option
    is(link_count($filename), undef, "scrips ok");
    RT->Config->Set( StrictLinkACL => 1 );
}

($id,$msg) = $u1->PrincipalObj->GrantRight ( Object => $q1, Right => 'ModifyTicket');
ok ($id,$msg);

diag('try to add link without rights') if $ENV{'TEST_VERBOSE'};
{
    # on q2 we have no rights, yet
    my $parent = RT::Ticket->new( $RT::SystemUser );
    my ($id,$tid,$msg) = $parent->Create( Subject => 'Link test 1', Queue => $q2->id );
    ok($id,$msg);
    my $child = RT::Ticket->new( $creator );
    ($id,$tid,$msg) = $child->Create( Subject => 'Link test 1', Queue => $q1->id );
    ok($id,$msg);
    ($id, $msg) = $child->AddLink(Type => 'MemberOf', Target => $parent->id);
    ok(!$id, $msg);
    is(link_count($filename), undef, "scrips ok");
    $child->CurrentUser( $RT::SystemUser );
    is($child->_Links('Base')->Count, 0, 'link was not created, no permissions');
    is($child->_Links('Target')->Count, 0, 'link was not create, no permissions');
}

diag('add link with rights only on base') if $ENV{'TEST_VERBOSE'};
{
    # on q2 we have no rights, but use checking one only on thing
    RT->Config->Set( StrictLinkACL => 0 );
    my $parent = RT::Ticket->new( $RT::SystemUser );
    my ($id,$tid,$msg) = $parent->Create( Subject => 'Link test 1', Queue => $q2->id );
    ok($id,$msg);
    my $child = RT::Ticket->new( $creator );
    ($id,$tid,$msg) = $child->Create( Subject => 'Link test 1', Queue => $q1->id );
    ok($id,$msg);
    ($id, $msg) = $child->AddLink(Type => 'MemberOf', Target => $parent->id);
    ok($id, $msg);
    is(link_count($filename), 1, "scrips ok");
    $child->CurrentUser( $RT::SystemUser );
    is($child->_Links('Base')->Count, 1, 'link was created');
    is($child->_Links('Target')->Count, 0, 'link was created only one');
    $child->CurrentUser( $creator );

    # turn off feature and try to delete link, we should fail
    RT->Config->Set( StrictLinkACL => 1 );
    ($id, $msg) = $child->AddLink(Type => 'MemberOf', Target => $parent->id);
    ok(!$id, $msg);
    is(link_count($filename), 1, "scrips ok");
    $child->CurrentUser( $RT::SystemUser );
    $child->_Links('Base')->_DoCount;
    is($child->_Links('Base')->Count, 1, 'link was not deleted');
    $child->CurrentUser( $creator );

    # try to delete link, we should success as feature is active
    RT->Config->Set( StrictLinkACL => 0 );
    ($id, $msg) = $child->DeleteLink(Type => 'MemberOf', Target => $parent->id);
    ok($id, $msg);
    is(link_count($filename), 0, "scrips ok");
    $child->CurrentUser( $RT::SystemUser );
    $child->_Links('Base')->_DoCount;
    is($child->_Links('Base')->Count, 0, 'link was deleted');
    RT->Config->Set( StrictLinkACL => 1 );
}

my $tid;
my $ticket = RT::Ticket->new( $creator);
ok($ticket->isa('RT::Ticket'));
($id,$tid, $msg) = $ticket->Create(Subject => 'Link test 1', Queue => $q1->id);
ok ($id,$msg);

diag('try link to itself') if $ENV{'TEST_VERBOSE'};
{
    my ($id, $msg) = $ticket->AddLink(Type => 'RefersTo', Target => $ticket->id);
    ok(!$id, $msg);
    is(link_count($filename), 0, "scrips ok");
}

my $ticket2 = RT::Ticket->new($RT::SystemUser);
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
is(link_count($filename), 1, "scrips ok");
($id,$msg) = $ticket->AddLink(Type => 'RefersTo', Target => -1);
ok(!$id,$msg);
($id,$msg) = $ticket->AddLink(Type => 'RefersTo', Target => $ticket2->id);
ok($id,$msg);
is(link_count($filename), 1, "scrips ok");

my $transactions = $ticket2->Transactions;
$transactions->Limit( FIELD => 'Type', VALUE => 'AddLink' );
is( $transactions->Count, 1, "Transaction found in other ticket" );
ok( $transactions->First->Field eq 'ReferredToBy');
ok( $transactions->First->NewValue eq $ticket->URI );

($id,$msg) = $ticket->DeleteLink(Type => 'RefersTo', Target => $ticket2->id);
ok($id,$msg);
is(link_count($filename), 0, "scrips ok");
$transactions = $ticket2->Transactions;
$transactions->Limit( FIELD => 'Type', VALUE => 'DeleteLink' );
is( $transactions->Count, 1, "Transaction found in other ticket" );
ok( $transactions->First->Field eq 'ReferredToBy');
ok( $transactions->First->OldValue eq $ticket->URI );

RT->Config->Set( LinkTransactionsRun1Scrip => 0 );

($id,$msg) =$ticket->AddLink(Type => 'RefersTo', Target => $ticket2->id);
ok($id,$msg);
is(link_count($filename), 2, "scrips ok");
($id,$msg) =$ticket->DeleteLink(Type => 'RefersTo', Target => $ticket2->id);
ok($id,$msg);
is(link_count($filename), 0, "scrips ok");

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
is(link_count($filename), 0, "scrips ok");

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
is(link_count($filename), 0, "scrips ok");


# restore
RT->Config->Set( LinkTransactionsRun1Scrip => $link_scrips_orig );
RT->Config->Set( StrictLinkACL => $link_acl_checks_orig );

{
    my $Scrips = RT::Scrips->new( $RT::SystemUser );
    $Scrips->Limit( FIELD => 'Description', OPERATOR => 'STARTSWITH', VALUE => 'Add or Delete Link ');
    while ( my $s = $Scrips->Next ) { $s->Delete };
}


sub link_count {
    my $file = shift;
    open my $fh, "<$file" or die "couldn't open $file";
    my $data = <$fh>;
    close $fh;

    return undef unless $data;
    chomp $data;
    return $data + 0;
}
