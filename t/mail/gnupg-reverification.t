use strict;
use warnings;

use RT::Test::GnuPG tests => undef, gnupg_options => { passphrase => 'rt-test' };

diag "load Everyone group";
my $everyone;
{
    $everyone = RT::Group->new( RT->SystemUser );
    $everyone->LoadSystemInternalGroup('Everyone');
    ok $everyone->id, "loaded 'everyone' group";
}

my ($baseurl, $m) = RT::Test->started_ok;
ok $m->login, 'we get log in';

RT::Test->import_gnupg_key('rt-recipient@example.com');

my @ticket_ids;

my $emaildatadir = RT::Test::get_relocatable_dir(File::Spec->updir(),
    qw(data gnupg emails));
my @files = glob("$emaildatadir/*-signed-*");
foreach my $file ( @files ) {
    diag "testing $file";

    my ($eid) = ($file =~ m{(\d+)[^/\\]+$});
    ok $eid, 'figured id of a file';

    my $email_content = RT::Test->file_content( $file );
    ok $email_content, "$eid: got content of email";

    my $warnings;
    my ($status, $id);

    {
        # We don't use Test::Warn here because we get multi-line
        # warnings, which Test::Warn only records the first line of.
        local $SIG{__WARN__} = sub {
            $warnings .= "@_";
        };

        ($status, $id) = RT::Test->send_via_mailgate( $email_content );
    }

    is $status >> 8, 0, "$eid: the mail gateway exited normally";
    ok $id, "$eid: got id of a newly created ticket - $id";

    like($warnings, qr/Public key '0xD328035D84881F1B' is not available/);

    my $ticket = RT::Ticket->new( RT->SystemUser );
    $ticket->Load( $id );
    ok $ticket->id, "$eid: loaded ticket #$id";
    is $ticket->Subject, "Test Email ID:$eid", "$eid: correct subject";

    $m->goto_ticket( $id );
    $m->content_contains(
        "Not possible to check the signature, the reason is missing public key",
        "$eid: signature is not verified",
    );
    $m->content_like(qr/This is .*ID:$eid/ims, "$eid: content is there and message is decrypted");

    $m->next_warning_like(qr/public key not found/);

    # some mails contain multiple signatures
    if ($eid == 5 || $eid == 17 || $eid == 18) {
        $m->next_warning_like(qr/public key not found/);
    }

    $m->no_leftover_warnings_ok;

    push @ticket_ids, $id;
}

diag "import key into keyring";
RT::Test->import_gnupg_key('rt-test@example.com', 'public');

foreach my $id ( @ticket_ids ) {
    diag "testing ticket #$id";

    $m->goto_ticket( $id );
    $m->content_contains(
        "The signature is good",
        "signature is re-verified and now good",
    );

    $m->no_warnings_ok;
}

done_testing;
