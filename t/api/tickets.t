
use strict;
use warnings;
use RT::Test; use Test::More; 
plan tests => 16;
use RT;



{

ok (require RT::Model::TicketCollection);
ok( my $testtickets = RT::Model::TicketCollection->new( RT->system_user ) );
ok( $testtickets->LimitStatus( value => 'deleted' ) );
# Should be zero until 'allow_deleted_search'
is( $testtickets->count , 0 );


}

{

# Test to make sure that you can search for tickets by requestor address and
# by requestor name.

my ($id,$msg);
my $u1 = RT::Model::User->new(RT->system_user);
($id, $msg) = $u1->create( Name => 'RequestorTestOne', EmailAddress => 'rqtest1@example.com');
ok ($id,$msg);
my $u2 = RT::Model::User->new(RT->system_user);
($id, $msg) = $u2->create( Name => 'RequestorTestTwo', EmailAddress => 'rqtest2@example.com');
ok ($id,$msg);

my $t1 = RT::Model::Ticket->new(RT->system_user);
my ($trans);
($id,$trans,$msg) =$t1->create (Queue => 'general', Subject => 'Requestor test one', Requestor => [$u1->EmailAddress]);
ok ($id, $msg);

my $t2 = RT::Model::Ticket->new(RT->system_user);
($id,$trans,$msg) =$t2->create (Queue => 'general', Subject => 'Requestor test one', Requestor => [$u2->EmailAddress]);
ok ($id, $msg);


my $t3 = RT::Model::Ticket->new(RT->system_user);
($id,$trans,$msg) =$t3->create (Queue => 'general', Subject => 'Requestor test one', Requestor => [$u2->EmailAddress, $u1->EmailAddress]);
ok ($id, $msg);


my $tix1 = RT::Model::TicketCollection->new(RT->system_user);
$tix1->from_sql('Requestor.EmailAddress LIKE "rqtest1" OR Requestor.EmailAddress LIKE "rqtest2"');

is ($tix1->count, 3);

my $tix2 = RT::Model::TicketCollection->new(RT->system_user);
$tix2->from_sql('Requestor.Name LIKE "TestOne" OR Requestor.Name LIKE "TestTwo"');

is ($tix2->count, 3);


my $tix3 = RT::Model::TicketCollection->new(RT->system_user);
$tix3->from_sql('Requestor.EmailAddress LIKE "rqtest1"');

is ($tix3->count, 2);

my $tix4 = RT::Model::TicketCollection->new(RT->system_user);
$tix4->from_sql('Requestor.Name LIKE "TestOne" ');

is ($tix4->count, 2);

# Searching for tickets that have two requestors isn't supported
# There's no way to differentiate "one requestor name that matches foo and bar"
# and "two requestors, one matching foo and one matching bar"

# my $tix5 = RT::Model::TicketCollection->new(RT->system_user);
# $tix5->from_sql('Requestor.Name LIKE "TestOne" AND Requestor.Name LIKE "TestTwo"');
# 
# is ($tix5->count, 1);
# 
# my $tix6 = RT::Model::TicketCollection->new(RT->system_user);
# $tix6->from_sql('Requestor.EmailAddress LIKE "rqtest1" AND Requestor.EmailAddress LIKE "rqtest2"');
# 
# is ($tix6->count, 1);



    undef $main::_STDOUT_;
    undef $main::_STDERR_;
}

{
    undef $main::_STDOUT_;
    undef $main::_STDERR_;

my $t1 = RT::Model::Ticket->new(RT->system_user);
$t1->create(Queue => 'general', Subject => "LimitWatchers test", Requestors => \['requestor1@example.com']);


    undef $main::_STDOUT_;
    undef $main::_STDERR_;
}

{
    undef $main::_STDOUT_;
    undef $main::_STDERR_;

# We assume that we've got some tickets hanging around from before.
ok( my $unlimittickets = RT::Model::TicketCollection->new( RT->system_user ) );
ok( $unlimittickets->find_all_rows );
ok( $unlimittickets->count > 0, "unlimited tickets object should return tickets" );


}

1;
