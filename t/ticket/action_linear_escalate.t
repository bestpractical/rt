#!/usr/bin/perl -w

use strict;
use warnings;
use RT::Test;

use Test::More tests => 17;
use RT;

my ($id, $msg);
my $RecordTransaction;
my $UpdateLastUpdated;


use_ok('RT::ScripAction::LinearEscalate');

my $q = RT::Test->load_or_create_queue( name =>  'Regression' );
ok $q && $q->id, 'loaded or created queue';

# rt-cron-tool uses Gecos name to get rt user, so we'd better create one
my $gecos = RT::Test->load_or_create_user(
    name =>  'gecos',
    password => 'password',
    gecos => ($^O eq 'MSWin32') ? Win32::LoginName() : (getpwuid($<))[0],
);
ok $gecos && $gecos->id, 'loaded or created gecos user';

# get rid of all right permissions
$gecos->principal_object->grant_right( right => 'SuperUser' );


my $user = RT::Test->load_or_create_user(
    name =>  'user', password => 'password',
);
ok $user && $user->id, 'loaded or created user';

$user->principal_object->grant_right( right => 'SuperUser' );
my $current_user = RT::CurrentUser->new( id => $user->id );
is( $user->id, $current_user->id, "Got current user?" );

#defaults
$RecordTransaction = 0;
$UpdateLastUpdated = 1;
my $ticket2 = create_ticket_as_ok($current_user);
escalate_ticket_ok($ticket2);
ok( $ticket2->last_updated_by->id != $user->id, "Set LastUpdated" );
ok( $ticket2->transactions->last->type =~ /Create/i, "Did not record a transaction" );

$RecordTransaction = 1;
$UpdateLastUpdated = 1;
my $ticket1 = create_ticket_as_ok($current_user);
escalate_ticket_ok($ticket1);
ok( $ticket1->last_updated_by->id != $user->id, "Set LastUpdated" );
ok( $ticket1->transactions->last->type !~ /Create/i, "Recorded a transaction" );

$RecordTransaction = 0;
$UpdateLastUpdated = 0;
my $ticket3 = create_ticket_as_ok($current_user);
escalate_ticket_ok($ticket3);
ok( $ticket3->last_updated_by->id == $user->id, "Did not set LastUpdated" );
ok( $ticket3->transactions->last->type =~ /Create/i, "Did not record a transaction" );

1;


sub create_ticket_as_ok {
    my $user = shift;

    my $created = RT::Date->new( current_user => RT->system_user );
    $created->unix(time() - ( 7 * 24 * 60**2 ));
    my $due = RT::Date->new( current_user => RT->system_user );
    $due->unix(time() + ( 7 * 24 * 60**2 ));

    my $ticket = RT::Model::Ticket->new( current_user => $user);
    ($id, $msg) = $ticket->create( queue => $q->id,
                                   subject => "Escalation test",
                                   priority => 0,
                                   initial_priority => 0,
                                   final_priority => 50,
                                 );
    ok($id, "Created ticket? ".$id);
    $ticket->__set( column => 'created',
                    value => $created->iso,
                  );
    $ticket->__set( column => 'due',
                    value => $due->iso,
                  );

    return $ticket;
}

sub escalate_ticket_ok {
    my $ticket = shift;
    my $id = $ticket->id;
    print "$RT::BinPath/rt-crontool --search RT::Search::FromSQL --search-arg \"id = @{[$id]}\" --action RT::ScripAction::LinearEscalate --action-arg \"RecordTransaction:$RecordTransaction; UpdateLastUpdated:$UpdateLastUpdated\"\n";
    print STDERR `$RT::BinPath/rt-crontool --search RT::Search::FromSQL --search-arg "id = @{[$id]}" --action RT::ScripAction::LinearEscalate --action-arg "RecordTransaction:$RecordTransaction; UpdateLastUpdated:$UpdateLastUpdated"`;

    Jifty::DBI::Record::Cachable->flush_cache;
    $ticket->load($id);     # reload, because otherwise we get the cached value
    ok( $ticket->priority != 0, "Escalated ticket" );
}
