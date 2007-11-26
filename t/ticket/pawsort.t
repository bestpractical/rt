#!/usr/bin/perl

use RT::Test; use Test::More; 
plan tests => 7;
use RT;



use strict;
use warnings;

use RT::Model::TicketCollection;
use RT::Model::Queue;
use RT::Model::CustomField;

my($ret,$msg);

# Test Paw Sort



# ---- Create a queue to test with.
my $queue = "PAWSortQueue-$$";
my $queue_obj = RT::Model::Queue->new(RT->system_user);
($ret, $msg) = $queue_obj->create(Name => $queue,
                                  Description => 'queue for custom field sort testing');
ok($ret, "$queue test queue creation. $msg");


# ---- Create some users

my $me = RT::Model::User->new(RT->system_user);
($ret, $msg) = $me->create(Name => "Me$$", EmailAddress => $$.'create-me-1@example.com');
($ret, $msg) = $me->PrincipalObj->GrantRight(Object =>$queue_obj, Right => 'OwnTicket');
($ret, $msg) = $me->PrincipalObj->GrantRight(Object =>$queue_obj, Right => 'SeeQueue');
($ret, $msg) = $me->PrincipalObj->GrantRight(Object =>$queue_obj, Right => 'ShowTicket');
my $you = RT::Model::User->new(RT->system_user);
($ret, $msg) = $you->create(Name => "You$$", EmailAddress => $$.'create-you-1@example.com');
($ret, $msg) = $you->PrincipalObj->GrantRight(Object =>$queue_obj, Right => 'OwnTicket');
($ret, $msg) = $you->PrincipalObj->GrantRight(Object =>$queue_obj, Right => 'SeeQueue');
($ret, $msg) = $you->PrincipalObj->GrantRight(Object =>$queue_obj, Right => 'ShowTicket');

my $nobody = RT::Model::User->new(RT->system_user);
$nobody->load('nobody');


# ----- Create some tickets to test with.  Assign them some values to
# make it easy to sort with.

my @tickets = (
               [qw[1 10], $me],
               [qw[2 20], $me],
               [qw[3 20], $you],
               [qw[4 30], $you],
               [qw[5  5], $nobody],
               [qw[6 55], $nobody],
              );
for (@tickets) {
  my $t = RT::Model::Ticket->new(RT->system_user);
  $t->create( Queue => $queue_obj->id,
              Subject => $_->[0],
              Owner => $_->[2]->id,
              Priority => $_->[1],
            );
}

sub check_order {
  my ($tx, @order) = @_;
  my @results;
  while (my $t = $tx->next) {
    push @results, $t->Subject;
  }
  my $results = join (" ",@results);
  my $order = join(" ",@order);
  is( $results, $order );
}


# The real tests start here

my $cme = new RT::CurrentUser( $me );
my $metx = new RT::Model::TicketCollection( $cme );
# Make sure we can sort in both directions on a queue specific field.
$metx->from_sql(qq[queue="$queue"] );
$metx->order_by( {column => "Custom.Ownership", order => 'ASC'} );
is($metx->count,6);
check_order( $metx, qw[2 1 6 5 4 3]);

$metx->order_by({ column => "Custom.Ownership", order => 'DESC'} );
is($metx->count,6);
check_order( $metx, reverse qw[2 1 6 5 4 3]);



my $cyou = new RT::CurrentUser( $you );
my $youtx = new RT::Model::TicketCollection( $cyou );
# Make sure we can sort in both directions on a queue specific field.
$youtx->from_sql(qq[queue="$queue"] );
$youtx->order_by({ column => "Custom.Ownership", order => 'ASC'} );
is($youtx->count,6);
check_order( $youtx, qw[4 3 6 5 2 1]);

__END__


