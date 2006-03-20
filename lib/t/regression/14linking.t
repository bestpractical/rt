use Test::More tests => '59';
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
($id,$msg) =$u1->Create(Name => "LinkTestUser.$$");

ok ($id,$msg);

# grant ShowTicket right to allow count transactions
($id,$msg) = $u1->PrincipalObj->GrantRight ( Object => $q1, Right => 'ShowTicket');
ok ($id,$msg);
($id,$msg) = $u1->PrincipalObj->GrantRight ( Object => $q2, Right => 'ShowTicket');
ok ($id,$msg);

($id,$msg) = $u1->PrincipalObj->GrantRight ( Object => $q1, Right => 'CreateTicket');
ok ($id,$msg);
($id,$msg) = $u1->PrincipalObj->GrantRight ( Object => $q1, Right => 'ModifyTicket');
ok ($id,$msg);

my $tid;

my $creator = RT::CurrentUser->new($u1->id);

my $ticket = RT::Ticket->new( $creator);
ok($ticket->isa('RT::Ticket'));
($id,$tid, $msg) = $ticket->Create(Subject => 'Link test 1', Queue => $q1->id);
ok ($id,$msg);


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
    is( $transactions->Count, 5, "Still five txns on the base" );

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
    is( $transactions->Count, 5, "still five txn on the base" );

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
    is( $transactions->Count, 6, "+1 txn on the base" );

    $transactions = $ticket2->Transactions;
    $transactions->Limit( FIELD => 'Type', VALUE => 'AddLink' );
    is( $transactions->Count, 3, "three txns on the target" );
}
($id,$msg) =$ticket->DeleteLink(Type => 'RefersTo', Target => $ticket2->id, SilentTarget => 1);
ok($id,$msg);
is(link_count($filename), 0, "scrips ok");


# restore
RT->Config->Set( LinkTransactionsRun1Scrip => $link_scrips_orig );

sub link_count {
    my $file = shift;
    open my $fh, "<$file" or die "couldn't open $file";
    my $data = <$fh>;
    chomp $data;
    return $data + 0;
    close $fh;
}
