use strict;
use warnings;

use RT::Test tests => undef;

RT->Config->Set( MailCommand  => 'sendmailpipe' );
RT->Config->Set( SetOutgoingMailFrom => 1 );
RT->Config->Set( OverrideOutgoingMailFrom  => { Default => 'queue@example.invalid' } );

# Ensure that the fake sendmail knows where to write to
$ENV{RT_MAILLOGFILE} = RT::Test->temp_directory . "/sendmailpipe.log";
my $fake = File::Spec->rel2abs( File::Spec->catfile(
        't', 'mail', 'fake-sendmail' ) );
RT->Config->Set( SendmailPath => $fake);

my $message = <<EOM;
From: doesnotexist\@willbounce.invalid
Subject: This is a test of new ticket creation

Bounce bounce bounce
EOM

{
    # by default, MailError wants to crit or error the email message
    # out to Screen, which scribbles all over the test output
    no warnings 'redefine';
    my $orig_mail_error = RT::Interface::Email->can('MailError');
    local *RT::Interface::Email::MailError = sub { $orig_mail_error->( @_, LogLevel => undef ) };
    RT::Test->send_via_mailgate($message);
}


open(LOG, "<", $ENV{RT_MAILLOGFILE}) or die "Can't open log file: $!";
my $fcount;
while (my $line = <LOG>) {
    $fcount++ if $line =~ /^-f/;
}
close(LOG);
# RT_MAILLOGFILE will contain all the command line flags if you need them
is($fcount,1,"Only one -f specified to sendmail command");

done_testing;
