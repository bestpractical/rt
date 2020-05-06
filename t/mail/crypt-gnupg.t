
use strict;
use warnings;

use RT::Test::GnuPG tests => 100;
use Test::Warn;

copy_test_keyring_to_homedir(use_legacy_keys => 1);

use_ok('RT::Crypt');
use_ok('MIME::Entity');

diag 'only signing. missing passphrase';
{
    my $entity = MIME::Entity->build(
        From    => 'rt@example.com',
        Subject => 'test',
        Data    => ['test'],
    );
    my %res;

    # We don't use Test::Warn here, because it apparently only captures up
    # to the first newline -- and the meat of this message is on the fourth
    # line.

    my @warnings;
    {
        local $SIG{__WARN__} = sub {
            push @warnings, map { split("\n", $_) } @_;
        };

        %res = RT::Crypt->SignEncrypt(
            Entity     => $entity,
            Encrypt    => 0,
            Passphrase => ''
        );
        ok( scalar @warnings, "Got warnings" );
        ok (grep { m/(no default secret key|can't query passphrase in batch mode|No passphrase given)/ } @warnings );
    }
    ok( $res{'exit_code'}, "couldn't sign without passphrase");
    ok( $res{'error'} || $res{'logger'}, "error is here" );

    my @status = RT::Crypt->ParseStatus(
        Protocol => $res{'Protocol'}, Status => $res{'status'}
    );
    is( scalar @status, 1, 'one record');
    like( $status[0]->{'Operation'}, qr/(Sign|PassphraseCheck)/, 'operation is correct');
    like( $status[0]->{'Status'}, qr/(ERROR|MISSING)/, 'missing passphrase');
}

diag 'only signing. wrong passphrase';
{
    my $entity = MIME::Entity->build(
        From    => 'rt@example.com',
        Subject => 'test',
        Data    => ['test'],
    );

    my %res;
    my @warnings;
    {
        local $SIG{__WARN__} = sub {
            push @warnings, map { split("\n", $_) } @_;
        };

        %res = RT::Crypt->SignEncrypt(
            Entity     => $entity,
            Encrypt    => 0,
            Passphrase => 'wrong',
        );
        ok( scalar @warnings, "Got warnings" );
        ok (grep { m/bad passphrase/i } @warnings );
    }
    ok( $res{'exit_code'}, "couldn't sign with bad passphrase");
    ok( $res{'error'} || $res{'logger'}, "error is here" );

    my @status = RT::Crypt->ParseStatus(
        Protocol => $res{'Protocol'}, Status => $res{'status'}
    );
    is( scalar @status, 1, 'one record');

    like( $status[0]->{'Operation'}, qr/(Sign|PassphraseCheck)/, 'operation is correct');
    like( $status[0]->{'Status'}, qr/(ERROR|BAD)/, 'wrong passphrase');
}

diag 'only signing. correct passphrase';
{
    my $entity = MIME::Entity->build(
        From    => 'rt@example.com',
        Subject => 'test',
        Data    => ['test'],
    );
    my %res = RT::Crypt->SignEncrypt( Entity => $entity, Encrypt => 0, Passphrase => 'test' );
    ok( $entity, 'signed entity');
    my @status = RT::Crypt->ParseStatus(
        Protocol => $res{'Protocol'}, Status => $res{'status'}
    );

    if ($using_legacy_gnupg) {
        ok( !$res{'logger'}, "log is here as well" ) or diag $res{'logger'};
        is( scalar @status, 2, 'two records: passphrase, signing');
        is( $status[0]->{'Operation'}, 'PassphraseCheck', 'operation is correct');
        is( $status[0]->{'Status'}, 'DONE', 'good passphrase');
        is( $status[1]->{'Operation'}, 'Sign', 'operation is correct');
        is( $status[1]->{'Status'}, 'DONE', 'done');
        is( $status[1]->{'User'}->{'EmailAddress'}, 'rt@example.com', 'correct email');
    }
    else {
        is( scalar @status, 1, 'one record: signing');
        is( $status[0]->{'Operation'}, 'Sign', 'operation is correct');
        is( $status[0]->{'Status'}, 'DONE', 'done');
        is( $status[0]->{'Message'}, 'Signed message', 'message is correct');
        is( $status[0]->{'KeyFingerprint'}, 'F23574193C1BA40ACB8DC6A4B5A462194345F7A5', 'signing key is correct');
    }

    ok( $entity->is_multipart, 'signed message is multipart' );
    is( $entity->parts, 2, 'two parts' );

    my @parts = RT::Crypt->FindProtectedParts( Entity => $entity );
    is( scalar @parts, 1, 'one protected part' );
    is( $parts[0]->{'Type'}, 'signed', "have signed part" );
    is( $parts[0]->{'Format'}, 'RFC3156', "RFC3156 format" );
    is( $parts[0]->{'Top'}, $entity, "it's the same entity" );

    my @res = RT::Crypt->VerifyDecrypt( Entity => $entity );
    is scalar @res, 1, 'one operation';
    @status = RT::Crypt->ParseStatus(
        Protocol => $res[0]{'Protocol'}, Status => $res[0]{'status'}
    );
    is( scalar @status, 1, 'one record');
    is( $status[0]->{'Operation'}, 'Verify', 'operation is correct');
    is( $status[0]->{'Status'}, 'DONE', 'good passphrase');
    is( $status[0]->{'Trust'}, 'ULTIMATE', 'have trust value');
}



diag 'encryption only';
{
    my $entity = MIME::Entity->build(
        From    => 'rt@example.com',
        To      => 'rt@example.com',
        Subject => 'test',
        Data    => ['test'],
    );
    my %res = RT::Crypt->SignEncrypt( Entity => $entity, Sign => 0 );
    ok( !$res{'exit_code'}, "successful encryption" );
    ok( !$res{'logger'}, "no records in logger" );

    my @status = RT::Crypt->ParseStatus(
        Protocol => $res{'Protocol'}, Status => $res{'status'}
    );
    is( scalar @status, 1, 'one record');
    is( $status[0]->{'Operation'}, 'Encrypt', 'operation is correct');
    is( $status[0]->{'Status'}, 'DONE', 'done');

    ok($entity, 'get an encrypted part');

    my @parts = RT::Crypt->FindProtectedParts( Entity => $entity );
    is( scalar @parts, 1, 'one protected part' );
    is( $parts[0]->{'Type'}, 'encrypted', "have encrypted part" );
    is( $parts[0]->{'Format'}, 'RFC3156', "RFC3156 format" );
    is( $parts[0]->{'Top'}, $entity, "it's the same entity" );
}

diag 'encryption only, bad recipient';
{
    my $entity = MIME::Entity->build(
        From    => 'rt@example.com',
        To      => 'keyless@example.com',
        Subject => 'test',
        Data    => ['test'],
    );

    my %res;
    my @warnings;
    {
        local $SIG{__WARN__} = sub {
            push @warnings, map { split("\n", $_) } @_;
        };

        %res = RT::Crypt->SignEncrypt(
            Entity => $entity,
            Sign   => 0,
        );
        ok( scalar @warnings, "Got warnings" );
        ok (grep { m/(public key not found|No public key|No Data)/i } @warnings );
    }
    ok( $res{'exit_code'}, 'no way to encrypt without keys of recipients');
    ok( $res{'logger'}, "errors are in logger" );

    my @status = RT::Crypt->ParseStatus(
        Protocol => $res{'Protocol'}, Status => $res{'status'}
    );
    ok( scalar @status, 'have records');
    is( $status[0]->{'Keyword'}, 'INV_RECP', 'invalid recipient');
}

diag 'encryption and signing with combined method';
{
    my $entity = MIME::Entity->build(
        From    => 'rt@example.com',
        To      => 'rt@example.com',
        Subject => 'test',
        Data    => ['test'],
    );
    my %res = RT::Crypt->SignEncrypt( Entity => $entity, Passphrase => 'test' );
    ok( !$res{'exit_code'}, "successful encryption with signing" );
    if ($using_legacy_gnupg) {
        ok( !$res{'logger'}, "no records in logger" );
    }
    else {
        ok(1);
    }

    my @status = RT::Crypt->ParseStatus(
        Protocol => $res{'Protocol'}, Status => $res{'status'}
    );
    if ($using_legacy_gnupg) {
        is( scalar @status, 3, 'three records: passphrase, sign and encrypt');
        is( $status[0]->{'Operation'}, 'PassphraseCheck', 'operation is correct');
        is( $status[0]->{'Status'}, 'DONE', 'done');
        is( $status[1]->{'Operation'}, 'Sign', 'operation is correct');
        is( $status[1]->{'Status'}, 'DONE', 'done');
        is( $status[2]->{'Operation'}, 'Encrypt', 'operation is correct');
        is( $status[2]->{'Status'}, 'DONE', 'done');
    }
    else {
        is( scalar @status, 2, 'two records: sign and encrypt');
        is( $status[0]->{'Operation'}, 'Sign', 'operation is correct');
        is( $status[0]->{'Status'}, 'DONE', 'done');
        is( $status[1]->{'Operation'}, 'Encrypt', 'operation is correct');
        is( $status[1]->{'Status'}, 'DONE', 'done');
        ok(1);
    }

    ok($entity, 'get an encrypted and signed part');

    my @parts = RT::Crypt->FindProtectedParts( Entity => $entity );
    is( scalar @parts, 1, 'one protected part' );
    is( $parts[0]->{'Type'}, 'encrypted', "have encrypted part" );
    is( $parts[0]->{'Format'}, 'RFC3156', "RFC3156 format" );
    is( $parts[0]->{'Top'}, $entity, "it's the same entity" );
}

diag 'encryption and signing with cascading, sign on encrypted';
{
    my $entity = MIME::Entity->build(
        From    => 'rt@example.com',
        To      => 'rt@example.com',
        Subject => 'test',
        Data    => ['test'],
    );
    my %res = RT::Crypt->SignEncrypt( Entity => $entity, Sign => 0 );
    ok( !$res{'exit_code'}, 'successful encryption' );
    ok( !$res{'logger'}, "no records in logger" );
    %res = RT::Crypt->SignEncrypt( Entity => $entity, Encrypt => 0, Passphrase => 'test' );
    ok( !$res{'exit_code'}, 'successful signing' );

    if ($using_legacy_gnupg) {
        ok( !$res{'logger'}, "no records in logger" );
    }
    else {
        ok(1);
    }


    my @parts = RT::Crypt->FindProtectedParts( Entity => $entity );
    is( scalar @parts, 1, 'one protected part, top most' );
    is( $parts[0]->{'Type'}, 'signed', "have signed part" );
    is( $parts[0]->{'Format'}, 'RFC3156', "RFC3156 format" );
    is( $parts[0]->{'Top'}, $entity, "it's the same entity" );
}

diag 'find signed/encrypted part deep inside';
{
    my $entity = MIME::Entity->build(
        From    => 'rt@example.com',
        To      => 'rt@example.com',
        Subject => 'test',
        Data    => ['test'],
    );
    my %res = RT::Crypt->SignEncrypt( Entity => $entity, Sign => 0 );
    ok( !$res{'exit_code'}, "success" );
    $entity->make_multipart( 'mixed', Force => 1 );
    $entity->attach(
        Type => 'text/plain',
        Data => ['-'x76, 'this is mailing list'],
    );

    my @parts = RT::Crypt->FindProtectedParts( Entity => $entity );
    is( scalar @parts, 1, 'one protected part' );
    is( $parts[0]->{'Type'}, 'encrypted', "have encrypted part" );
    is( $parts[0]->{'Format'}, 'RFC3156', "RFC3156 format" );
    is( $parts[0]->{'Top'}, $entity->parts(0), "it's the same entity" );
}

diag 'wrong signed/encrypted parts: no protocol';
{
    my $entity = MIME::Entity->build(
        From    => 'rt@example.com',
        To      => 'rt@example.com',
        Subject => 'test',
        Data    => ['test'],
    );

    my %res = RT::Crypt->SignEncrypt(
        Entity => $entity,
        Sign   => 0,
    );

    ok( !$res{'exit_code'}, 'success' );
    $entity->head->mime_attr( 'Content-Type.protocol' => undef );

    my @parts;
    warning_like { @parts = RT::Crypt->FindProtectedParts( Entity => $entity ) }
        qr{Entity is 'multipart/encrypted', but has no protocol defined. Checking for PGP part};
    is( scalar @parts, 1, 'one protected part' );
    is( $parts[0]->{'Type'}, 'encrypted', "have encrypted part" );
    is( $parts[0]->{'Format'}, 'RFC3156', "RFC3156 format" );
    is( $parts[0]->{'Top'}, $entity, "it's the same entity" );
}

diag 'wrong signed/encrypted parts: not enought parts';
{
    my $entity = MIME::Entity->build(
        From    => 'rt@example.com',
        To      => 'rt@example.com',
        Subject => 'test',
        Data    => ['test'],
    );

    my %res = RT::Crypt->SignEncrypt(
        Entity => $entity,
        Sign   => 0,
    );

    ok( !$res{'exit_code'}, 'success' );
    $entity->parts([ $entity->parts(0) ]);

    my @parts;
    warning_like {
        @parts = RT::Crypt->FindProtectedParts( Entity => $entity );
    } qr/Encrypted or signed entity must has two subparts. Skipped/;
    is( scalar @parts, 0, 'no protected parts' );
}

diag 'wrong signed/encrypted parts: wrong proto';
{
    my $entity = MIME::Entity->build(
        From    => 'rt@example.com',
        To      => 'rt@example.com',
        Subject => 'test',
        Data    => ['test'],
    );
    my %res = RT::Crypt->SignEncrypt( Entity => $entity, Sign => 0 );
    ok( !$res{'exit_code'}, 'success' );
    $entity->head->mime_attr( 'Content-Type.protocol' => 'application/bad-proto' );

    my @parts = RT::Crypt->FindProtectedParts( Entity => $entity );
    is( scalar @parts, 0, 'no protected parts' );
}

diag 'wrong signed/encrypted parts: wrong proto';
{
    my $entity = MIME::Entity->build(
        From    => 'rt@example.com',
        To      => 'rt@example.com',
        Subject => 'test',
        Data    => ['test'],
    );
    my %res = RT::Crypt->SignEncrypt( Entity => $entity, Encrypt => 0, Passphrase => 'test' );
    ok( !$res{'exit_code'}, 'success' );
    $entity->head->mime_attr( 'Content-Type.protocol' => 'application/bad-proto' );

    my @parts = RT::Crypt->FindProtectedParts( Entity => $entity );
    is( scalar @parts, 0, 'no protected parts' );
}

diag 'verify inline and in attachment signatures';
{
    my $email_dir = get_test_data_dir(use_legacy_keys => 1);
    open( my $fh, '<', "$email_dir/signed_old_style_with_attachment.eml" ) or die $!;
    my $parser = new MIME::Parser;
    my $entity = $parser->parse( $fh );

    my @parts = RT::Crypt->FindProtectedParts( Entity => $entity );
    is( scalar @parts, 2, 'two protected parts' );
    is( $parts[1]->{'Type'}, 'signed', "have signed part" );
    is( $parts[1]->{'Format'}, 'Inline', "inline format" );
    is( $parts[1]->{'Data'}, $entity->parts(0), "it's first part" );

    is( $parts[0]->{'Type'}, 'signed', "have signed part" );
    is( $parts[0]->{'Format'}, 'Attachment', "attachment format" );
    is( $parts[0]->{'Data'}, $entity->parts(1), "data in second part" );
    is( $parts[0]->{'Signature'}, $entity->parts(2), "file's signature in third part" );

    my @res = RT::Crypt->VerifyDecrypt( Entity => $entity );
    my @status = RT::Crypt->ParseStatus(
        Protocol => $res[0]{'Protocol'}, Status => $res[0]{'status'}
    );
    is( scalar @status, 1, 'one record');
    is( $status[0]->{'Operation'}, 'Verify', 'operation is correct');
    is( $status[0]->{'Status'}, 'DONE', 'good passphrase');
    is( $status[0]->{'Trust'}, 'ULTIMATE', 'have trust value');

    $parser->filer->purge();
}

