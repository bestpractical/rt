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
my $queue_obj = RT::Model::Queue->new(current_user => RT->system_user);
($ret, $msg) = $queue_obj->create(name => $queue,
                                  description => 'queue for custom field sort testing');
ok($ret, "$queue test queue creation. $msg");


# ---- Create some users

my $me = RT::Model::User->new(current_user => RT->system_user);
($ret, $msg) = $me->create(name => "Me$$", email => $$.'create-me-1@example.com');
($ret, $msg) = $me->principal_object->grant_right(object =>$queue_obj, right => 'OwnTicket');
($ret, $msg) = $me->principal_object->grant_right(object =>$queue_obj, right => 'SeeQueue');
($ret, $msg) = $me->principal_object->grant_right(object =>$queue_obj, right => 'ShowTicket');
my $you = RT::Model::User->new(current_user => RT->system_user);
($ret, $msg) = $you->create(name => "You$$", email => $$.'create-you-1@example.com');
($ret, $msg) = $you->principal_object->grant_right(object =>$queue_obj, right => 'OwnTicket');
($ret, $msg) = $you->principal_object->grant_right(object =>$queue_obj, right => 'SeeQueue');
($ret, $msg) = $you->principal_object->grant_right(object =>$queue_obj, right => 'ShowTicket');

my $nobody = RT::Model::User->new(current_user => RT->system_user);
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
  my $t = RT::Model::Ticket->new(current_user => RT->system_user);
  $t->create( queue => $queue_obj->id,
              subject => $_->[0],
              owner => $_->[2]->id,
              priority => $_->[1],
            );
}

sub check_order {
  my ($tx, @order) = @_;
  my @results;
  while (my $t = $tx->next) {
    push @results, $t->subject;
  }
  my $results = join (" ",@results);
  my $order = join(" ",@order);
  is( $results, $order );
}


# The real tests start here

my $cme = RT::CurrentUser->new( id =>$me->id );
my $metx = RT::Model::TicketCollection->new( current_user => $cme );
# Make sure we can sort in both directions on a queue specific field.
$metx->from_sql(qq[queue="$queue"] );
$metx->order_by( {column => "Custom.Ownership", order => 'ASC'} );
is($metx->count,6);
check_order( $metx, qw[2 1 6 5 4 3]);

$metx->order_by({ column => "Custom.Ownership", order => 'DESC'} );
is($metx->count,6);
check_order( $metx, reverse qw[2 1 6 5 4 3]);



my $cyou = RT::CurrentUser->new( id => $you->id );
my $youtx = RT::Model::TicketCollection->new( current_user => $cyou );
# Make sure we can sort in both directions on a queue specific field.
$youtx->from_sql(qq[queue="$queue"] );
$youtx->order_by({ column => "Custom.Ownership", order => 'ASC'} );
is($youtx->count,6);
check_order( $youtx, qw[4 3 6 5 2 1]);

__END__


