#!/usr/bin/perl -w

use warnings;
use RT::Test;
use strict;
use Test::More tests => 31;
use RT;
my @users = qw/ emailnormal@example.com emaildaily@example.com emailweekly@example.com emailsusp@example.com /;

my( $ret, $msg );
my $user_n = RT::Model::User->new( current_user => RT->system_user );
( $ret, $msg ) = $user_n->load_or_create_by_email( $users[0] );
ok( $ret, "user with default email prefs created: $msg" );
$user_n->set_privileged( 1 );

my $user_d = RT::Model::User->new( current_user => RT->system_user );
( $ret, $msg ) = $user_d->load_or_create_by_email( $users[1] );
ok( $ret, "user with daily digest email prefs created: $msg" );
# Set a username & password for testing the interface.
$user_d->set_privileged( 1 );
$user_d->set_preferences($RT::system => { %{ $user_d->preferences( $RT::System ) || {}}, email_frequency => 'Daily digest'});



my $user_w = RT::Model::User->new(current_user => RT->system_user );
( $ret, $msg ) = $user_w->load_or_create_by_email( $users[2] );
ok( $ret, "user with weekly digest email prefs created: $msg" );
$user_w->set_privileged( 1 );
$user_w->set_preferences($RT::system => { %{ $user_w->preferences( $RT::System ) || {}}, email_frequency => 'Weekly digest'});

my $user_s = RT::Model::User->new(current_user => RT->system_user );
( $ret, $msg ) = $user_s->load_or_create_by_email( $users[3] );
ok( $ret, "user with suspended email prefs created: $msg" );
$user_s->set_preferences($RT::system => { %{ $user_s->preferences( $RT::System ) || {}}, email_frequency => 'Suspended'});
$user_s->set_privileged( 1 );


is(RT->config->get('EmailFrequency' => $user_s), 'Suspended');

# Make a testing queue for ourselves.
my $testq = RT::Model::Queue->new(current_user => RT->system_user );
if( $testq->validate_name( 'EmailDigest-testqueue' ) ) {
    ( $ret, $msg ) = $testq->create( name =>  'EmailDigest-testqueue' );
    ok( $ret, "Our test queue is created: $msg" );
} else {
    $testq->load( 'EmailDigest-testqueue' );
    ok( $testq->id, "Our test queue is loaded" );
}

# Allow anyone to open a ticket on the test queue.
my $everyone = RT::Model::Group->new(current_user => RT->system_user );
( $ret, $msg ) = $everyone->load_system_internal_group( 'Everyone' );
ok( $ret, "Loaded 'everyone' group: $msg" );

( $ret, $msg ) = $everyone->principal_object->grant_right( right => 'CreateTicket',
						      object => $testq );
ok( $ret || $msg =~ /already has/, "Granted everyone CreateTicket on testq: $msg" );

# Make user_d an admincc for the queue.
( $ret, $msg ) = $user_d->principal_object->grant_right( right => 'AdminQueue',
						    object => $testq );
ok( $ret || $msg =~ /already has/, "Granted dduser AdminQueue on testq: $msg" );
( $ret, $msg ) = $testq->add_watcher( type => 'AdminCc',
			     principal_id => $user_d->principal_object->id );
ok( $ret || $msg =~ /already/, "dduser added as a queue watcher: $msg" );

# Give the others queue rights.
( $ret, $msg ) = $user_n->principal_object->grant_right( right => 'AdminQueue',
						    object => $testq );
ok( $ret || $msg =~ /already has/, "Granted emailnormal right on testq: $msg" );
( $ret, $msg ) = $user_w->principal_object->grant_right( right => 'AdminQueue',
						    object => $testq );
ok( $ret || $msg =~ /already has/, "Granted emailweekly right on testq: $msg" );
( $ret, $msg ) = $user_s->principal_object->grant_right( right => 'AdminQueue',
						    object => $testq );
ok( $ret || $msg =~ /already has/, "Granted emailsusp right on testq: $msg" );

# Create a ticket with To: Cc: Bcc: fields using our four users.
my $id;
my $ticket = RT::Model::Ticket->new(current_user => RT->system_user );
( $id, $ret, $msg ) = $ticket->create( queue => $testq->name,
				       requestor => [ $user_w->name ],
				       subject => 'Test ticket for RT::Extension::EmailDigest',
				       );
ok( $ret, "Ticket $id created: $msg" );

# Make the other users ticket watchers.
( $ret, $msg ) = $ticket->add_watcher( type => 'Cc',
		      principal_id => $user_n->principal_object->id );
ok( $ret, "Added user_w as a ticket watcher: $msg" );
( $ret, $msg ) = $ticket->add_watcher( type => 'Cc',
		      principal_id => $user_s->principal_object->id );
ok( $ret, "Added user_s as a ticket watcher: $msg" );

my $obj;
($id, $msg, $obj ) = $ticket->correspond(
	content => "This is a ticket response for CC action" );
ok( $ret, "Transaction created: $msg" );

# Get the deferred notifications that should result.  Should be two for
# email daily, and one apiece for emailweekly and emailsusp.
my @notifications;

my $txns = RT::Model::TransactionCollection->new( current_user => RT->system_user );
$txns->limit_to_ticket( $ticket->id );
my( $c_daily, $c_weekly, $c_susp ) = ( 0, 0, 0 );
while( my $txn = $txns->next ) {
    my @daily_rcpt = $txn->deferred_recipients( 'daily' );
    my @weekly_rcpt = $txn->deferred_recipients('weekly' );
    my @susp_rcpt = $txn->deferred_recipients(  'susp' );

    $c_daily++ if @daily_rcpt;
    $c_weekly++ if @weekly_rcpt;
    $c_susp++ if @susp_rcpt;

    # If the transaction has content...
    if( $txn->content_obj ) {
	# ...none of the deferred folk should be in the header.
	my $headerstr = $txn->content_obj->headers;
	foreach my $rcpt( @daily_rcpt, @weekly_rcpt, @susp_rcpt ) {
	    ok( $headerstr !~ /$rcpt/, "Deferred recipient $rcpt not found in header" );
	}
    }
}

# Finally, check to see that we got the correct number of each sort of
# deferred recipient.
is( $c_daily, 2, "correct number of daily-sent messages" );
is( $c_weekly, 2, "correct number of weekly-sent messages" );
is( $c_susp, 1, "correct number of suspended messages" );





# Now let's actually run the daily and weekly digest tool to make sure we generate those

# the first time get the content
{open (my $digester, "-|", $RT::SbinPath."/rt-email-digest --mode daily --print");
my @results = <$digester>;
my $content = join ('', @results);
like($content, qr/in the last day/);
} {
# The second time run it for real so we make sure that we get RT to mark the txn as sent
open (my $digester, "-|", $RT::SbinPath."/rt-email-digest --mode daily");
my @results = <$digester>;
my $content = join ('', @results);
like($content, qr/maildaily\@/);
close($digester);
}
# now we should have nothing to do, so no content.
{open (my $digester, "-|", $RT::SbinPath."/rt-email-digest --mode daily --print");
my @results = <$digester>;
my $content = join ('', @results);
is ($content, '');
} 

# the first time get the content
{open (my $digester, "-|", $RT::SbinPath."/rt-email-digest --mode weekly --print");
my @results = <$digester>;
my $content = join ('', @results);
like($content, qr/in the last seven days/);
} {
# The second time run it for real so we make sure that we get RT to mark the txn as sent
open (my $digester, "-|", $RT::SbinPath."/rt-email-digest --mode weekly");
my @results = <$digester>;
my $content = join ('', @results);
like($content, qr/mailweekly\@/);
close($digester);
}
# now we should have nothing to do, so no content.
{open (my $digester, "-|", $RT::SbinPath."/rt-email-digest --mode weekly --print");
my @results = <$digester>;
my $content = join ('', @results);
is ($content, '');
} 


