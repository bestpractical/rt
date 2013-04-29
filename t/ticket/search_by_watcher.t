
use strict;
use warnings;

use RT::Test nodata => 1, tests => undef;
use RT::Ticket;

my $q = RT::Test->load_or_create_queue( Name => 'Regression' );
ok $q && $q->id, 'loaded or created queue';
my $queue = $q->Name;

my ($total, @tickets, @test, @conditions) = (0, ());

sub generate_tix {
    my @list = (
        [],
        ['x@foo.com'], ['y@bar.com'], ['z@bar.com'],
        ['x@foo.com', 'y@bar.com'],
        ['y@bar.com', 'z@bar.com'],
        ['x@foo.com', 'z@bar.com'],
        ['x@foo.com', 'y@bar.com', 'z@bar.com'],
    );
    my @data = ();
    foreach my $r (@list) {
        foreach my $c (@list) {
            my $subject = 'r:'. (join( '', map substr($_, 0, 1), @$r ) || '-') .';';
            $subject .= 'c:'. (join( '', map substr($_, 0, 1), @$c ) || '-') .';';

            push @data, {
                Subject => $subject,
                Requestor => $r,
                Cc => $c,
            };
        }
    }
    return RT::Test->create_tickets( { Queue => $q->id }, @data );
}

sub run_tests {
    while ( my ($query, $checks) = splice @test, 0, 2 ) {
        run_test( $query, %$checks );
    }
}

sub run_test {
    my ($query, %checks) = @_;

    my $tix = RT::Tickets->new(RT->SystemUser);
    $tix->FromSQL($query);
    my $error = 0;

    my $count = 0;
    $count++ foreach grep $_, values %checks;
    is($tix->Count, $count, "found correct number of ticket(s) by '$query'") or $error = 1;

    my $good_tickets = ($tix->Count == $count);
    while ( my $ticket = $tix->Next ) {
        next if $checks{ $ticket->Subject };
        diag $ticket->Subject ." ticket has been found when it's not expected";
        $good_tickets = 0;
    }
    ok( $good_tickets, "all tickets are good with '$query'" ) or $error = 1;

    diag "Wrong SQL query for '$query':". $tix->BuildSelectQuery if $error;
}

sub run_auto_tests {
    {
        my @atmp = @conditions;
        while ( my ($query, $cb) = splice @atmp, 0, 2 ) {
            my %checks = ();
            foreach my $ticket ( @tickets ) {
                my $s = $ticket->Subject;
                $checks{ $s } = $cb->($s);
            }
            run_test($query, %checks);
        }
    }
    my @queries = (
        '? AND ?'  => sub { $_[0] and $_[1] },
        '? OR  ?' => sub  { $_[0] or $_[1] },
    );
    while ( my ($template, $t_cb) = splice @queries, 0, 2 ) {
        my @atmp = @conditions;
        while ( my ($a, $a_cb) = splice @atmp, 0, 2 ) {
        my @btmp = @conditions;
        while ( my ($b, $b_cb) = splice @btmp, 0, 2 ) {
        next if $a eq $b;

            my %checks = ();
            foreach my $ticket ( @tickets ) {
                my $s = $ticket->Subject;
                $checks{ $s } = $t_cb->( scalar $a_cb->($s), scalar $b_cb->($s) );
            }

            my $query = $template;
            foreach my $tmp ($a, $b) {
                $query =~ s/\?/$tmp/;
            }

            run_test( $query, %checks );
        } }
    }
    return unless $ENV{'RT_TEST_HEAVY'};

    @queries = (
        '? AND ? AND ?'  => sub { $_[0] and $_[1] and $_[2] },
        '(? OR ?) AND ?' => sub { return (($_[0] or $_[1]) and $_[2]) },
        '? OR (? AND ?)' => sub { $_[0] or ($_[1] and $_[2]) },
        '(? AND ?) OR ?' => sub { ($_[0] and $_[1]) or $_[2] },
        '? AND (? OR ?)' => sub { $_[0] and ($_[1] or $_[2]) },
        '? OR ? OR ?'    => sub { $_[0] or $_[1] or $_[2] },
    );
    while ( my ($template, $t_cb) = splice @queries, 0, 2 ) {
        my @atmp = @conditions;
        while ( my ($a, $a_cb) = splice @atmp, 0, 2 ) {
        my @btmp = @conditions;
        while ( my ($b, $b_cb) = splice @btmp, 0, 2 ) {
        next if $a eq $b;
        my @ctmp = @conditions;
        while ( my ($c, $c_cb) = splice @ctmp, 0, 2 ) {
        next if $a eq $c;
        next if $b eq $c;

            my %checks = ();
            foreach my $ticket ( @tickets ) {
                my $s = $ticket->Subject;
                $checks{ $s } = $t_cb->( scalar $a_cb->($s), scalar $b_cb->($s), scalar $c_cb->($s) );
            }

            my $query = $template;
            foreach my $tmp ($a, $b, $c) {
                $query =~ s/\?/$tmp/;
            }

            run_test( $query, %checks );
        } } }
    }

}

@conditions = (
    'Cc = "not@exist"'       => sub { 0 },
    'Cc != "not@exist"'      => sub { 1 },
    'Cc IS NULL'             => sub { $_[0] =~ /c:-;/ },
    'Cc IS NOT NULL'         => sub { $_[0] !~ /c:-;/ },
    'Cc = "x@foo.com"'       => sub { $_[0] =~ /c:[^;]*x/ },
    'Cc != "x@foo.com"'      => sub { $_[0] !~ /c:[^;]*x/ },
    'Cc LIKE "@bar.com"'     => sub { $_[0] =~ /c:[^;]*(?:y|z)/ },
# TODO:
#    'Cc NOT LIKE "@bar.com"' => sub { $_[0] !~ /y|z/ },

    'Requestor = "not@exist"'   => sub { 0 },
    'Requestor != "not@exist"'  => sub { 1 },
    'Requestor IS NULL'         => sub { $_[0] =~ /r:-;/ },
    'Requestor IS NOT NULL'     => sub { $_[0] !~ /r:-;/ },
    'Requestor = "x@foo.com"'   => sub { $_[0] =~ /r:[^;]*x/ },
    'Requestor != "x@foo.com"'  => sub { $_[0] !~ /r:[^;]*x/ },
    'Requestor LIKE "@bar.com"' => sub { $_[0] =~ /r:[^;]*(?:y|z)/ },
# TODO:
#    'Requestor NOT LIKE "@bar.com"' => sub { $_[0] !~ /y|z/ },

    'Watcher = "not@exist"'   => sub { 0 },
    'Watcher != "not@exist"'  => sub { 1 },
# TODO:
#    'Watcher IS NULL'         => sub { $_[0] eq 'r:-;c:-;' },
#    'Watcher IS NOT NULL'     => sub { $_[0] ne 'r:-;c:-;' },
    'Watcher = "x@foo.com"'   => sub { $_[0] =~ /x/ },
#    'Watcher != "x@foo.com"'  => sub { $_[0] !~ /x/ },
    'Watcher LIKE "@bar.com"' => sub { $_[0] =~ /(?:y|z)/ },
# TODO:
#    'Watcher NOT LIKE "@bar.com"' => sub { $_[0] !~ /y|z/ },

    'Subject LIKE "ne"'      => sub { 0 },
    'Subject NOT LIKE "ne"'  => sub { 1 },
    'Subject = "r:x;c:y;"'   => sub { $_[0] eq 'r:x;c:y;' },
    'Subject LIKE "x"'       => sub { $_[0] =~ /x/ },
);

@tickets = generate_tix();
$total += scalar @tickets;
{
    my $tix = RT::Tickets->new(RT->SystemUser);
    $tix->FromSQL("Queue = '$queue'");
    is($tix->Count, $total, "found $total tickets");
}
run_auto_tests();

# owner is special watcher because reference is duplicated in two places,
# owner was an ENUM field now it's WATCHERFIELD, but should support old
# style ENUM searches for backward compatibility
my $nobody = RT::Nobody();
{
    my $tix = RT::Tickets->new(RT->SystemUser);
    $tix->FromSQL("Queue = '$queue' AND Owner = '". $nobody->id ."'");
    ok($tix->Count, "found ticket(s)");
}
{
    my $tix = RT::Tickets->new(RT->SystemUser);
    $tix->FromSQL("Queue = '$queue' AND Owner = '". $nobody->Name ."'");
    ok($tix->Count, "found ticket(s)");
}
{
    my $tix = RT::Tickets->new(RT->SystemUser);
    $tix->FromSQL("Queue = '$queue' AND Owner != '". $nobody->id ."'");
    is($tix->Count, 0, "found ticket(s)");
}
{
    my $tix = RT::Tickets->new(RT->SystemUser);
    $tix->FromSQL("Queue = '$queue' AND Owner != '". $nobody->Name ."'");
    is($tix->Count, 0, "found ticket(s)");
}

{
    my $tix = RT::Tickets->new(RT->SystemUser);
    $tix->FromSQL("Queue = '$queue' AND Owner.Name LIKE 'nob'");
    ok($tix->Count, "found ticket(s)");
}

{
    # create ticket and force type to not a 'ticket' value
    # bug #6898@rt3.fsck.com
    # and http://marc.theaimsgroup.com/?l=rt-devel&m=112662934627236&w=2
    my($t) = RT::Test->create_tickets( { Queue => $q->id }, { Subject => 'not a ticket' } );
    $t->_Set( Field             => 'Type',
              Value             => 'not a ticket',
              CheckACL          => 0,
              RecordTransaction => 0,
            );

    my $tix = RT::Tickets->new(RT->SystemUser);
    $tix->FromSQL("Queue = '$queue' AND Owner = 'Nobody'");
    is($tix->Count, $total, "found ticket(s)");
}

{
    my $everyone = RT::Group->new( RT->SystemUser );
    $everyone->LoadSystemInternalGroup('Everyone');
    ok($everyone->id, "loaded 'everyone' group");
    my($id, $msg) = $everyone->PrincipalObj->GrantRight( Right => 'OwnTicket',
                                                         Object => $q
                                                       );
    ok($id, "granted OwnTicket right to Everyone on '$queue'") or diag("error: $msg");

    my $u = RT::User->new( RT->SystemUser );
    $u->LoadOrCreateByEmail('alpha@e.com');
    ok($u->id, "loaded user");
    my($t) = RT::Test->create_tickets(
        { Queue => $q->id }, { Subject => '4', Owner => $u->id },
    );
    my $u_alpha_id = $u->id;

    $u = RT::User->new( RT->SystemUser );
    $u->LoadOrCreateByEmail('bravo@e.com');
    ok($u->id, "loaded user");
    ($t) = RT::Test->create_tickets(
        { Queue => $q->id }, { Subject => '5', Owner => $u->id },
    );
    my $u_bravo_id = $u->id;

    my $tix = RT::Tickets->new(RT->SystemUser);
    $tix->FromSQL("Queue = '$queue' AND
                   ( Owner = '$u_alpha_id' OR
                     Owner = '$u_bravo_id' )"
                 );
    is($tix->Count, 2, "found ticket(s)");
}

@tickets = ();
done_testing();
