use strict;
use warnings;
use utf8;

# trs: I'd write a quick t/web/caching-headers.t file which loops the available
#      endpoints checking for the right headers.

use File::Find;

BEGIN {
    # Ensure that the test and server processes use the same fixed time.
    use constant TIME => 1365175699;
    use Test::MockTime 'set_fixed_time';
    set_fixed_time(TIME);

    use RT::Test
        tests   => undef,
        config  => "use Test::MockTime 'set_fixed_time'; set_fixed_time(".TIME.");";
}

my ($base, $m) = RT::Test->started_ok;
ok $m->login, 'logged in';

my $docroot = join '/', qw(share html);

# find endpoints to loop over
my @endpoints;
find({
  wanted => sub {
    if ( -f $_ && $_ !~ m|autohandler$| ) {
      ( my $endpoint = $_ ) =~ s|^$docroot||;
      push @endpoints, $endpoint;
    }
  },
  no_chdir => 1,
} => join '/', $docroot => 'Helpers');

my $ticket_id;
diag "create a ticket via the API";
{
    my $ticket = RT::Ticket->new( RT->SystemUser );
    my ($id, $txn, $msg) = $ticket->Create(
        Queue => 'General',
        Subject => 'test ticket',
    );
    ok $id, 'created a ticket #'. $id or diag "error: $msg";
    is $ticket->Subject, 'test ticket', 'correct subject';
    $ticket_id = $id;
}


my $expected;
diag "set up expected date headers";
{

  # expected headers
  $expected = {
    Autocomplete => {
      'Cache-Control' => 'max-age=120, private',
      'Expires'       => 'Fri, 5 Apr 2013 15:30:19 GMT',
    },
    default      => {
      'Cache-Control' => 'no-cache',
      'Expires'       => 'Fri, 5 Apr 2013 15:28:19 GMT',
    },
  };

}

foreach my $endpoint ( @endpoints ) {
  $m->get_ok( $endpoint . "?id=${ticket_id}&Status=open&Requestor=root" );

  my $header_key = $endpoint =~ m|Autocomplete| ? 'Autocomplete' : 'default';
  my $headers = $expected->{$header_key};

  is(
      $m->res->header('Cache-Control') => $headers->{'Cache-Control'},
      'got expected Cache-Control header'
  );

  is(
    $m->res->header('Expires') => $headers->{'Expires'},
    'got expected Expires header'
  );
}

undef $m;
done_testing;
