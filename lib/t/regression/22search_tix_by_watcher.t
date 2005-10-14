#!/usr/bin/perl -w
use strict;
use warnings;

use Test::More qw/no_plan/;
use_ok('RT');
RT::LoadConfig();
RT::Init();
use RT::Ticket;

my $q = RT::Queue->new($RT::SystemUser);
my $queue = 'SearchTests-'.rand(200);
$q->Create(Name => $queue);

my @data = (
    { Subject => '1', Requestor => 'bravo@example.com' },
    { Subject => '2', Cc => 'alpha@example.com' },
);

my $total = 0;

sub add_tix_from_data {
    my @res = ();
    while (@data) {
        my $t = RT::Ticket->new($RT::SystemUser);
        my ( $id, undef $msg ) = $t->Create(
            Queue => $q->id,
            %{ shift(@data) },
        );
        ok( $id, "ticket created" ) or diag("error: $msg");
        push @res, $t;
        $total++;
    }
    return @res;
}
add_tix_from_data();

{
    my $tix = RT::Tickets->new($RT::SystemUser);
    $tix->FromSQL("Queue = '$queue'");
    is($tix->Count, $total, "found $total tickets");
}

{
    my $tix = RT::Tickets->new($RT::SystemUser);
    $tix->FromSQL("Queue = '$queue' AND Requestor = 'bravo\@example.com'");
    is($tix->Count, 1, "found ticket(s)");
    is($tix->First->RequestorAddresses, 'bravo@example.com',"correct requestor");
}

{
    my $tix = RT::Tickets->new($RT::SystemUser);
    $tix->FromSQL("Queue = '$queue' AND Cc = 'alpha\@example.com'");
    is($tix->Count, 1, "found ticket(s)");
    is($tix->First->CcAddresses, 'alpha@example.com', "correct Cc");
}

{
    my $tix = RT::Tickets->new($RT::SystemUser);
    $tix->FromSQL("Queue = '$queue' AND (Cc = 'alpha\@example.com' OR Requestor = 'bravo\@example.com')");
    is($tix->Count, 2, "found ticket(s)");
    my @mails;
    while (my $t = $tix->Next) {
        push @mails, $t->RequestorAddresses;
        push @mails, $t->CcAddresses;
    }
    @mails = sort grep $_, @mails;
    is_deeply(\@mails, ['alpha@example.com', 'bravo@example.com'], "correct addresses");
}

{
    my $tix = RT::Tickets->new($RT::SystemUser);
    $tix->FromSQL("Queue = '$queue' AND (Cc = 'alpha\@example.com' AND Requestor = 'bravo\@example.com')");
    is($tix->Count, 0, "found ticket(s)");
}

{
    my $tix = RT::Tickets->new($RT::SystemUser);
    $tix->FromSQL("Queue = '$queue' AND Cc != 'alpha\@example.com'");
    is($tix->Count, 1, "found ticket(s)");
    is($tix->First->RequestorAddresses, 'bravo@example.com',"correct requestor");
}

@data = ( { Subject => '3' } );
add_tix_from_data();

{
    my $tix = RT::Tickets->new($RT::SystemUser);
    $tix->FromSQL("Queue = '$queue' AND Cc != 'alpha\@example.com'");
    is($tix->Count, 2, "found ticket(s)");
    my @mails;
    while (my $t = $tix->Next) { push @mails, ($t->CcAddresses||'') }
    is( scalar(grep 'alpha@example.com' eq $_, @mails), 0, "no tickets with non required data");
}

{
    # has no requestor search
    my $tix = RT::Tickets->new($RT::SystemUser);
    $tix->FromSQL("Queue = '$queue' AND Requestor IS NULL");
    is($tix->Count, 2, "found ticket(s)");
    my @mails;
    while (my $t = $tix->Next) { push @mails, ($t->RequestorAddresses||'') }
    is( scalar(grep $_, @mails), 0, "no tickets with non required data");
}

{
    # has at least one requestor search
    my $tix = RT::Tickets->new($RT::SystemUser);
    $tix->FromSQL("Queue = '$queue' AND Requestor IS NOT NULL");
    is($tix->Count, 1, "found ticket(s)");
    my @mails;
    while (my $t = $tix->Next) { push @mails, ($t->RequestorAddresses||'') }
    is( scalar(grep !$_, @mails), 0, "no tickets with non required data");
}

@data = ( { Subject => '3', Requestor => 'charly@example.com' } );
add_tix_from_data();

{
    # has no requestor search
    my $tix = RT::Tickets->new($RT::SystemUser);
    $tix->FromSQL("Queue = '$queue' AND
                   (Requestor = 'bravo\@example.com' OR Requestor = 'charly\@example.com')");
    is($tix->Count, 2, "found ticket(s)");
    my @mails;
    while (my $t = $tix->Next) { push @mails, ($t->RequestorAddresses||'') }
    is_deeply( [sort @mails],
               ['bravo@example.com', 'charly@example.com'],
               "requestor addresses are correct"
             );
}

# owner is special watcher because reference is duplicated in two places,
# owner was an ENUM field now it's WATCHERFIELD, but should support old
# style ENUM searches for backward compatibility
my $nobody = RT::Nobody();
{
    my $tix = RT::Tickets->new($RT::SystemUser);
    $tix->FromSQL("Queue = '$queue' AND Owner = '". $nobody->id ."'");
    is($tix->Count, 4, "found ticket(s)");
}
{
    my $tix = RT::Tickets->new($RT::SystemUser);
    $tix->FromSQL("Queue = '$queue' AND Owner = '". $nobody->Name ."'");
    is($tix->Count, 4, "found ticket(s)");
}
{
    my $tix = RT::Tickets->new($RT::SystemUser);
    $tix->FromSQL("Queue = '$queue' AND Owner != '". $nobody->id ."'");
    is($tix->Count, 0, "found ticket(s)");
}
{
    my $tix = RT::Tickets->new($RT::SystemUser);
    $tix->FromSQL("Queue = '$queue' AND Owner != '". $nobody->Name ."'");
    is($tix->Count, 0, "found ticket(s)");
}

{
    my $tix = RT::Tickets->new($RT::SystemUser);
    $tix->FromSQL("Queue = '$queue' AND Owner.Name LIKE 'nob'");
    is($tix->Count, 4, "found ticket(s)");
}

{
    # create ticket and force type to not a 'ticket' value
    # bug #6898@rt3.fsck.com
    # and http://marc.theaimsgroup.com/?l=rt-devel&m=112662934627236&w=2
    @data = ( { Subject => 'not a ticket' } );
    my($t) = add_tix_from_data();
    $t->_Set( Field             => 'Type',
              Value             => 'not a ticket',
              CheckACL          => 0,
              RecordTransaction => 0,
            );
    $total--;

    my $tix = RT::Tickets->new($RT::SystemUser);
    $tix->FromSQL("Queue = '$queue' AND Owner = 'Nobody'");
    is($tix->Count, 4, "found ticket(s)");
}

{
    my $everyone = RT::Group->new( $RT::SystemUser );
    $everyone->LoadSystemInternalGroup('Everyone');
    ok($everyone->id, "loaded 'everyone' group");
    my($id, $msg) = $everyone->PrincipalObj->GrantRight( Right => 'OwnTicket',
                                                         Object => $q
                                                       );
    ok($id, "granted OwnTicket right to Everyone on '$queue'") or diag("error: $msg");

    my $u = RT::User->new( $RT::SystemUser );
    $u->LoadByCols( EmailAddress => 'alpha@example.com' );
    ok($u->id, "loaded user");
    @data = ( { Subject => '4', Owner => $u->id } );
    my($t) = add_tix_from_data();
    is( $t->Owner, $u->id, "created ticket with custom owner" );
    my $u_alpha_id = $u->id;

    $u = RT::User->new( $RT::SystemUser );
    $u->LoadByCols( EmailAddress => 'bravo@example.com' );
    ok($u->id, "loaded user");
    @data = ( { Subject => '5', Owner => $u->id } );
    ($t) = add_tix_from_data();
    is( $t->Owner, $u->id, "created ticket with custom owner" );
    my $u_bravo_id = $u->id;

    my $tix = RT::Tickets->new($RT::SystemUser);
    $tix->FromSQL("Queue = '$queue' AND
                   ( Owner = '$u_alpha_id' OR
                     Owner = '$u_bravo_id' )"
                 );
    is($tix->Count, 2, "found ticket(s)");
}

exit(0)
