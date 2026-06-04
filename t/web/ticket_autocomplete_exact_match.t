use strict;
use warnings;

use RT::Test nodata => 1, tests => undef;
use JSON qw(from_json);

my $queue = RT::Test->load_or_create_queue( Name => 'General' );
ok $queue && $queue->id, 'loaded or created queue';

my $other_queue = RT::Test->load_or_create_queue( Name => 'Other' );
ok $other_queue && $other_queue->id, 'loaded or created other queue';

# The autocomplete helper requires a privileged user. Under "nodata" there is
# no root login, so create our own privileged user with SuperUser to see every
# ticket regardless of queue.
my $user = RT::Test->load_or_create_user(
    Name => 'autocomplete_user', Password => 'password',
);
ok $user && $user->id, 'loaded or created user';

ok( RT::Test->add_rights(
    { Principal => $user, Right => [qw(SuperUser)] },
), 'granted SuperUser');

my ($baseurl, $m) = RT::Test->started_ok;
ok $m->login( 'autocomplete_user', 'password' ), 'logged in';

# Decoy tickets first so they get the LOW ids. Subjects get the exact
# ticket's id spliced in below, so they all match "Subject LIKE '%id%'".
# We create plenty of decoys (well past $max=10) so the uncapped search,
# whose result order is not guaranteed, reliably truncates the high exact
# id out of the first page.
my @decoys;
for my $i ( 1 .. 60 ) {
    my $t = RT::Test->create_ticket( Queue => $queue->id, Subject => "decoy $i" );
    push @decoys, $t;
}
is( scalar( grep { $_ && $_->id } @decoys ), 60, 'created 60 decoy tickets' );

# Exact ticket last => highest id. Subject deliberately has no digits so it
# only matches via the exact id, not the Subject LIKE clause.
my $exact = RT::Test->create_ticket(
    Queue   => $queue->id,
    Subject => 'the special one',
);
ok $exact && $exact->id, 'created exact ticket #' . $exact->id;
my $exact_id = $exact->id;

# Splice the exact id into every decoy subject so all of them match by Subject.
my $set_ok = 0;
for my $t ( @decoys ) {
    my ($ok) = $t->SetSubject( "decoy mentioning $exact_id" );
    $set_ok++ if $ok;
}
is( $set_ok, 60, 'spliced exact id into every decoy subject' );

diag "exact id ($exact_id) must be first even with many subject matches";
{
    $m->get_ok(
        "/Helpers/Autocomplete/Tickets?term=$exact_id&return=id",
        "fetched ticket autocomplete",
    );
    my $results = from_json( $m->content );
    is( ref $results, 'ARRAY', 'response is an array' );
    is( $results->[0]{value}, $exact_id, 'exact id match is the first suggestion' );

    my @matches = grep { $_->{value} == $exact_id } @$results;
    is( scalar @matches, 1, 'exact id appears exactly once (deduped)' );
}

diag "exclude should suppress the exact id match";
{
    $m->get_ok(
        "/Helpers/Autocomplete/Tickets?term=$exact_id&return=id&exclude=$exact_id",
        "fetched ticket autocomplete with exclude",
    );
    my $results = from_json( $m->content );
    my @matches = grep { $_->{value} == $exact_id } @$results;
    is( scalar @matches, 0, 'excluded exact id is not suggested' );
}

diag "limit clause must also constrain the exact-match pass";
{
    my $other_id = $other_queue->id;
    $m->get_ok(
        "/Helpers/Autocomplete/Tickets?term=$exact_id&return=id&limit=Queue%3D$other_id",
        "fetched ticket autocomplete with limit",
    );
    my $results = from_json( $m->content );
    my @matches = grep { $_->{value} == $exact_id } @$results;
    is( scalar @matches, 0, 'exact id outside the limit is not suggested' );
}

diag "non-numeric term skips the exact pass and still returns subject matches";
{
    $m->get_ok(
        "/Helpers/Autocomplete/Tickets?term=mentioning&return=id",
        "fetched ticket autocomplete for non-numeric term",
    );
    my $results = from_json( $m->content );
    is( ref $results, 'ARRAY', 'response is an array' );
    ok( scalar @$results > 0, 'subject matches still returned for a text term' );
}

done_testing();
