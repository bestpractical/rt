use strict;
use warnings;

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

# files to exclude from testing headers
my @exclude = (
    'SpawnLinkedTicket', # results in redirect, expires header not expected
);

# find endpoints to loop over
my @endpoints = (
    "/NoAuth/css/aileron/squished-".("0"x32).".css",
    '/static/images/bpslogo.png',
);
find({
  wanted => sub {
    if ( -f $_ && $_ !~ m|autohandler$| ) {
      return if m{/\.[^/]+\.sw[op]$}; # vim swap files
      ( my $endpoint = $_ ) =~ s|^$docroot||;
      return if grep $endpoint =~ m{/$_$}, @exclude;
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
      'Expires'       => 'Fri, 05 Apr 2013 15:30:19 GMT',
    },
    NoAuth      => {
      'Cache-Control' => 'max-age=2592000, public',
      'Expires'       => 'Sun, 05 May 2013 15:28:19 GMT',
    },
    default      => {
      'Cache-Control' => 'no-cache',
      'Expires'       => 'Fri, 05 Apr 2013 15:28:19 GMT',
    },
  };

}

foreach my $endpoint ( @endpoints ) {
  $m->get_ok( $endpoint . "?id=${ticket_id}&Status=open&Requestor=root" );

  my $header_key = 'default';
  if ( $endpoint =~ m|Autocomplete| ) {
    $header_key =  'Autocomplete';
  } elsif ( $endpoint =~ m/NoAuth|static/ ) {
    $header_key =  'NoAuth';
  }
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

done_testing;
