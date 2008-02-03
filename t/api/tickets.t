
use strict;
use warnings;
use RT::Test; use Test::More; 
plan tests => 16;
use RT;



{

ok (require RT::Model::TicketCollection);
ok( my $testtickets = RT::Model::TicketCollection->new(current_user => RT->system_user ) );
ok( $testtickets->limit_status( value => 'deleted' ) );
# Should be zero until 'allow_deleted_search'
is( $testtickets->count , 0 );


}

{

# Test to make sure that you can search for tickets by requestor address and
# by requestor name.

my ($id,$msg);
my $u1 = RT::Model::User->new(current_user => RT->system_user);
($id, $msg) = $u1->create( name => 'RequestorTestOne', email => 'rqtest1@example.com');
ok ($id,$msg);
my $u2 = RT::Model::User->new(current_user => RT->system_user);
($id, $msg) = $u2->create( name => 'RequestorTestTwo', email => 'rqtest2@example.com');
ok ($id,$msg);

my $t1 = RT::Model::Ticket->new(current_user => RT->system_user);
my ($trans);
($id,$trans,$msg) =$t1->create (queue => 'general', subject => 'Requestor test one', requestor => [$u1->email]);
ok ($id, $msg);

my $t2 = RT::Model::Ticket->new(current_user => RT->system_user);
($id,$trans,$msg) =$t2->create (queue => 'general', subject => 'Requestor test one', requestor => [$u2->email]);
ok ($id, $msg);


my $t3 = RT::Model::Ticket->new(current_user => RT->system_user);
($id,$trans,$msg) =$t3->create (queue => 'general', subject => 'Requestor test one', requestor => [$u2->email, $u1->email]);
ok ($id, $msg);


my $tix1 = RT::Model::TicketCollection->new(current_user => RT->system_user);
$tix1->from_sql('Requestor.email LIKE "rqtest1" OR Requestor.email LIKE "rqtest2"');

is ($tix1->count, 3);

my $tix2 = RT::Model::TicketCollection->new(current_user => RT->system_user);
$tix2->from_sql('Requestor.name LIKE "TestOne" OR Requestor.name LIKE "TestTwo"');

is ($tix2->count, 3);


my $tix3 = RT::Model::TicketCollection->new(current_user => RT->system_user);
$tix3->from_sql('Requestor.email LIKE "rqtest1"');

is ($tix3->count, 2);

my $tix4 = RT::Model::TicketCollection->new(current_user => RT->system_user);
$tix4->from_sql('Requestor.name LIKE "TestOne" ');

is ($tix4->count, 2);

# Searching for tickets that have two requestors isn't supported
# There's no way to differentiate "one requestor name that matches foo and bar"
# and "two requestors, one matching foo and one matching bar"

# my $tix5 = RT::Model::TicketCollection->new(current_user => RT->system_user);
# $tix5->from_sql('Requestor.name LIKE "TestOne" AND Requestor.name LIKE "TestTwo"');
# 
# is ($tix5->count, 1);
# 
# my $tix6 = RT::Model::TicketCollection->new(current_user => RT->system_user);
# $tix6->from_sql('Requestor.email LIKE "rqtest1" AND Requestor.email LIKE "rqtest2"');
# 
# is ($tix6->count, 1);



}

{

my $t1 = RT::Model::Ticket->new(current_user => RT->system_user);
$t1->create(queue => 'general', subject => "limit_Watchers test", requestors => \['requestor1@example.com']);

}

{

# We assume that we've got some tickets hanging around from before.
ok( my $unlimittickets = RT::Model::TicketCollection->new(current_user => RT->system_user ) );
ok( $unlimittickets->find_all_rows );
ok( $unlimittickets->count > 0, "unlimited tickets object should return tickets" );


}

1;
