use strict;
use warnings;

use RT::Test tests => undef;

RT->Config->Set( MailCommand => 'sendmailpipe' );
RT->Config->Set( SetOutgoingMailFrom => 'rt@example.com' );
RT->Config->Set( OverrideOutgoingMailFrom => { Test => 'rt-test@example.com' } );

# Ensure that the fake sendmail knows where to write to
$ENV{RT_MAILLOGFILE} = RT::Test->temp_directory . "/sendmailpipe.log";
my $fake = File::Spec->rel2abs( File::Spec->catfile(
        't', 'mail', 'fake-sendmail' ) );
RT->Config->Set( SendmailPath => $fake);

{
    my $queue = RT::Test->load_or_create_queue( Name => 'General' );
    ok $queue && $queue->id, 'loaded or created queue General';

    my $ticket = RT::Ticket->new( RT->SystemUser );
    $ticket->Create(
        Queue     => $queue->id,
        Subject   => 'test',
        Requestor => 'root@localhost',
    );

    open(my $fh, "<", $ENV{RT_MAILLOGFILE}) or die "Can't open log file: $!";
    my $ok = 0;
    while (my $line = <$fh>) {
        $ok++ if $line =~ /^-f rt\@example.com/;
    }
    close($fh);
    is($ok,1,"'-f rt\@example.com' specified to sendmail command");
}

{
    my $queue = RT::Test->load_or_create_queue( Name => 'Test' );
    ok $queue && $queue->id, 'loaded or created queue Test';

    my $ticket = RT::Ticket->new( RT->SystemUser );
    $ticket->Create(
        Queue     => $queue->id,
        Subject   => 'test',
        Requestor => 'root@localhost',
    );

    open(my $fh, "<", $ENV{RT_MAILLOGFILE}) or die "Can't open log file: $!";
    my $ok = 0;
    while (my $line = <$fh>) {
        $ok++ if $line =~ /^-f rt-test\@example.com/;
    }
    close($fh);
    is($ok,1,"'-f rt-test\@example.com' specified to sendmail command");
}

done_testing;
