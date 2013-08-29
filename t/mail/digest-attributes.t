
use warnings;
use strict;
use RT;
use RT::Test tests => 31;
my @users = qw/ emailnormal@example.com emaildaily@example.com emailweekly@example.com emailsusp@example.com /;

my( $ret, $msg );
my $user_n = RT::User->new( RT->SystemUser );
( $ret, $msg ) = $user_n->LoadOrCreateByEmail( $users[0] );
ok( $ret, "user with default email prefs created: $msg" );
$user_n->SetPrivileged( 1 );

my $user_d = RT::User->new( RT->SystemUser );
( $ret, $msg ) = $user_d->LoadOrCreateByEmail( $users[1] );
ok( $ret, "user with daily digest email prefs created: $msg" );
# Set a username & password for testing the interface.
$user_d->SetPrivileged( 1 );
$user_d->SetPreferences($RT::System => { %{ $user_d->Preferences( $RT::System ) || {}}, EmailFrequency => 'Daily digest'});



my $user_w = RT::User->new( RT->SystemUser );
( $ret, $msg ) = $user_w->LoadOrCreateByEmail( $users[2] );
ok( $ret, "user with weekly digest email prefs created: $msg" );
$user_w->SetPrivileged( 1 );
$user_w->SetPreferences($RT::System => { %{ $user_w->Preferences( $RT::System ) || {}}, EmailFrequency => 'Weekly digest'});

my $user_s = RT::User->new( RT->SystemUser );
( $ret, $msg ) = $user_s->LoadOrCreateByEmail( $users[3] );
ok( $ret, "user with suspended email prefs created: $msg" );
$user_s->SetPreferences($RT::System => { %{ $user_s->Preferences( $RT::System ) || {}}, EmailFrequency => 'Suspended'});
$user_s->SetPrivileged( 1 );


is(RT::Config->Get('EmailFrequency' => $user_s), 'Suspended');

# Make a testing queue for ourselves.
my $testq = RT::Queue->new( RT->SystemUser );
if( $testq->ValidateName( 'EmailDigest-testqueue' ) ) {
    ( $ret, $msg ) = $testq->Create( Name => 'EmailDigest-testqueue' );
    ok( $ret, "Our test queue is created: $msg" );
} else {
    $testq->Load( 'EmailDigest-testqueue' );
    ok( $testq->id, "Our test queue is loaded" );
}

# Allow anyone to open a ticket on the test queue.
my $everyone = RT::Group->new( RT->SystemUser );
( $ret, $msg ) = $everyone->LoadSystemInternalGroup( 'Everyone' );
ok( $ret, "Loaded 'everyone' group: $msg" );

( $ret, $msg ) = $everyone->PrincipalObj->GrantRight( Right => 'CreateTicket',
                                                      Object => $testq );
ok( $ret || $msg =~ /already has/, "Granted everyone CreateTicket on testq: $msg" );

# Make user_d an admincc for the queue.
( $ret, $msg ) = $user_d->PrincipalObj->GrantRight( Right => 'AdminQueue',
                                                    Object => $testq );
ok( $ret || $msg =~ /already has/, "Granted dduser AdminQueue on testq: $msg" );
( $ret, $msg ) = $testq->AddWatcher( Type => 'AdminCc',
                             PrincipalId => $user_d->PrincipalObj->id );
ok( $ret || $msg =~ /already/, "dduser added as a queue watcher: $msg" );

# Give the others queue rights.
( $ret, $msg ) = $user_n->PrincipalObj->GrantRight( Right => 'AdminQueue',
                                                    Object => $testq );
ok( $ret || $msg =~ /already has/, "Granted emailnormal right on testq: $msg" );
( $ret, $msg ) = $user_w->PrincipalObj->GrantRight( Right => 'AdminQueue',
                                                    Object => $testq );
ok( $ret || $msg =~ /already has/, "Granted emailweekly right on testq: $msg" );
( $ret, $msg ) = $user_s->PrincipalObj->GrantRight( Right => 'AdminQueue',
                                                    Object => $testq );
ok( $ret || $msg =~ /already has/, "Granted emailsusp right on testq: $msg" );

# Create a ticket with To: Cc: Bcc: fields using our four users.
my $id;
my $ticket = RT::Ticket->new( RT->SystemUser );
( $id, $ret, $msg ) = $ticket->Create( Queue => $testq->Name,
                                       Requestor => [ $user_w->Name ],
                                       Subject => 'Test ticket for RT::Extension::EmailDigest',
                                       );
ok( $ret, "Ticket $id created: $msg" );

# Make the other users ticket watchers.
( $ret, $msg ) = $ticket->AddWatcher( Type => 'Cc',
                      PrincipalId => $user_n->PrincipalObj->id );
ok( $ret, "Added user_n as a ticket watcher: $msg" );
( $ret, $msg ) = $ticket->AddWatcher( Type => 'Cc',
                      PrincipalId => $user_s->PrincipalObj->id );
ok( $ret, "Added user_s as a ticket watcher: $msg" );

my $obj;
($id, $msg, $obj ) = $ticket->Correspond(
    Content => "This is a ticket response for CC action" );
ok( $ret, "Transaction created: $msg" );

# Get the deferred notifications that should result.  Should be two for
# email daily, and one apiece for emailweekly and emailsusp.
my @notifications;

my $txns = RT::Transactions->new( RT->SystemUser );
$txns->LimitToTicket( $ticket->id );
my( $c_daily, $c_weekly, $c_susp ) = ( 0, 0, 0 );
while( my $txn = $txns->Next ) {
    my @daily_rcpt = $txn->DeferredRecipients( 'daily' );
    my @weekly_rcpt = $txn->DeferredRecipients('weekly' );
    my @susp_rcpt = $txn->DeferredRecipients(  'susp' );

    $c_daily++ if @daily_rcpt;
    $c_weekly++ if @weekly_rcpt;
    $c_susp++ if @susp_rcpt;

    # If the transaction has content...
    if( $txn->ContentObj ) {
        # ...none of the deferred folk should be in the header.
        my $headerstr = $txn->ContentObj->Headers;
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
email_digest_like( '--mode daily --print', qr/in the last day/ );
# The second time run it for real so we make sure that we get RT to mark the txn as sent
email_digest_like( '--mode daily --verbose', qr/maildaily\@/ );
# now we should have nothing to do, so no content.
email_digest_like( '--mode daily --print', '' );

# the first time get the content
email_digest_like( '--mode weekly --print', qr/in the last seven days/ );
# The second time run it for real so we make sure that we get RT to mark the txn as sent
email_digest_like( '--mode weekly --verbose', qr/mailweekly\@/ );
# now we should have nothing to do, so no content.
email_digest_like( '--mode weekly --print', '' );

sub email_digest_like {
    my $arg = shift;
    my $pattern = shift;

    local $Test::Builder::Level = $Test::Builder::Level + 1;

    my $perl = $^X . ' ' . join ' ', map { "-I$_" } @INC;
    open my $digester, "-|", "$perl $RT::SbinPath/rt-email-digest $arg";
    my @results = <$digester>;
    my $content = join '', @results;
    if ( ref $pattern && ref $pattern eq 'Regexp' ) {
        like($content, $pattern);
    }
    else {
        is( $content, $pattern );
    }
    close $digester;
}
