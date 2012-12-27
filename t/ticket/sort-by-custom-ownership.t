
use RT;
use RT::Test nodata => 1, tests => 7;


use strict;
use warnings;

use RT::Tickets;
use RT::Queue;
use RT::CustomField;

my($ret,$msg);

# Test Paw Sort



# ---- Create a queue to test with.
my $queue = "PAWSortQueue-$$";
my $queue_obj = RT::Queue->new(RT->SystemUser);
($ret, $msg) = $queue_obj->Create(Name => $queue,
                                  Description => 'queue for custom field sort testing');
ok($ret, "$queue test queue creation. $msg");


# ---- Create some users

my $me = RT::User->new(RT->SystemUser);
($ret, $msg) = $me->Create(Name => "Me$$", EmailAddress => $$.'create-me-1@example.com');
($ret, $msg) = $me->PrincipalObj->GrantRight(Object =>$queue_obj, Right => 'OwnTicket');
($ret, $msg) = $me->PrincipalObj->GrantRight(Object =>$queue_obj, Right => 'SeeQueue');
($ret, $msg) = $me->PrincipalObj->GrantRight(Object =>$queue_obj, Right => 'ShowTicket');
my $you = RT::User->new(RT->SystemUser);
($ret, $msg) = $you->Create(Name => "You$$", EmailAddress => $$.'create-you-1@example.com');
($ret, $msg) = $you->PrincipalObj->GrantRight(Object =>$queue_obj, Right => 'OwnTicket');
($ret, $msg) = $you->PrincipalObj->GrantRight(Object =>$queue_obj, Right => 'SeeQueue');
($ret, $msg) = $you->PrincipalObj->GrantRight(Object =>$queue_obj, Right => 'ShowTicket');

my $nobody = RT::User->new(RT->SystemUser);
$nobody->Load('nobody');


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
  my $t = RT::Ticket->new(RT->SystemUser);
  $t->Create( Queue => $queue_obj->Id,
              Subject => $_->[0],
              Owner => $_->[2]->Id,
              Priority => $_->[1],
            );
}

sub check_order {
  my ($tx, @order) = @_;
  my @results;
  while (my $t = $tx->Next) {
    push @results, $t->Subject;
  }
  my $results = join (" ",@results);
  my $order = join(" ",@order);
  is( $results, $order );
}


# The real tests start here

my $cme = RT::CurrentUser->new( $me );
my $metx = RT::Tickets->new( $cme );
# Make sure we can sort in both directions on a queue specific field.
$metx->FromSQL(qq[queue="$queue"] );
$metx->OrderBy( FIELD => "Custom.Ownership", ORDER => 'ASC' );
is($metx->Count,6);
check_order( $metx, qw[2 1 6 5 4 3]);

$metx->OrderBy( FIELD => "Custom.Ownership", ORDER => 'DESC' );
is($metx->Count,6);
check_order( $metx, reverse qw[2 1 6 5 4 3]);



my $cyou = RT::CurrentUser->new( $you );
my $youtx = RT::Tickets->new( $cyou );
# Make sure we can sort in both directions on a queue specific field.
$youtx->FromSQL(qq[queue="$queue"] );
$youtx->OrderBy( FIELD => "Custom.Ownership", ORDER => 'ASC' );
is($youtx->Count,6);
check_order( $youtx, qw[4 3 6 5 2 1]);

__END__


