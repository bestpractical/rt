use strict;
use warnings;

use RT::Test tests => undef,
    config => 'Set( $TreatAttachedEmailAsFiles, 1);'
;

use File::Spec ();
use Email::Abstract;

# We're not testing acls here.
my $everyone = RT::Group->new(RT->SystemUser);
$everyone->LoadSystemInternalGroup('Everyone');
$everyone->PrincipalObj->GrantRight( Right =>'SuperUser' );

# some utils
sub first_txn    { return $_[0]->Transactions->First }
sub count_attachs { return first_txn($_[0])->Attachments->Count }

sub mail_in_ticket {
    my ($filename) = @_;
    my $path = RT::Test::get_relocatable_file($filename,
        (File::Spec->updir(), 'data', 'emails'));
    my $content = RT::Test->file_content($path);

    RT::Test->clean_caught_mails;
    my ($status, $id) = RT::Test->send_via_mailgate( $content );
    ok( !$status, "Fed $filename into mailgate");

    my $ticket = RT::Ticket->new(RT->SystemUser);
    $ticket->Load($id);
    ok( $ticket->Id, "Successfully created ticket ".$ticket->Id);

    my @mail = map {Email::Abstract->new($_)->cast('MIME::Entity')}
        RT::Test->fetch_caught_mails;
    return ($ticket, @mail);
}

diag "Process email with an email file attached";
{
    my ($ticket) = mail_in_ticket('email-file-attachment.eml');
    like( first_txn($ticket)->Content , qr/This is a test with an email file attachment/, "Parsed the email body");
    is( count_attachs($ticket), 3,
        "Has three attachments, presumably multipart/mixed, text-plain, message");

    my $attachments = $ticket->Transactions->First->Attachments;

    my $attachment = $attachments->Next;
    is( $attachment->Subject, 'This is a test', 'Subject is correct' );

    $attachment = $attachments->Next;
    is( $attachment->ContentType, 'text/plain', 'Got the first part of the main email' );

    $attachment = $attachments->Next;
    is( $attachment->Filename, 'test-email.eml', 'Got a filename for the attached email file' );
}

done_testing();
