use strict;
use warnings;

use RT::Test::GnuPG
  tests         => 53,
  actual_server => 1,
  gnupg_options => {
    passphrase => 'rt-test',
  };

copy_test_keyring_to_homedir(use_legacy_keys => 1);

use String::ShellQuote 'shell_quote';
use IPC::Run3 'run3';
use MIME::Base64;
use MIME::Entity;
use Encode;

my ($baseurl, $m) = RT::Test->started_ok;

# configure key for General queue
ok( $m->login, 'we did log in' );
$m->get( $baseurl.'/Admin/Queues/');
$m->follow_link_ok( {text => 'General'} );
$m->submit_form( form_number => 3,
                 fields      => { CorrespondAddress => 'general@example.com' } );

$m->content_like(qr/general\@example.com.* - never/, 'has key info.');

ok(my $user = RT::User->new(RT->SystemUser));
ok($user->Load('root'), "Loaded user 'root'");
$user->SetEmailAddress('recipient@example.com');

# test simple mail.  supposedly this should fail when
# 1. the queue requires signature
# 2. the from is not what the key is associated with
my $mail = RT::Test->open_mailgate_ok($baseurl);
print $mail <<EOF;
From: recipient\@example.com
To: general\@$RT::rtname
Subject: This is a test of new ticket creation as root

Blah!
Foob!
EOF
RT::Test->close_mailgate_ok($mail);

{
    my $tick = RT::Test->last_ticket;
    is( $tick->Subject,
        'This is a test of new ticket creation as root',
        "Created the ticket"
    );
    my $txn = $tick->Transactions->First;
    like(
        $txn->Attachments->First->Headers,
        qr/^X-RT-Incoming-Encryption: Not encrypted/m,
        'recorded incoming mail that is not encrypted'
    );
    like( $txn->Attachments->First->Content, qr/Blah/);
}

# test for signed mail
{
    my $gnupg = get_test_gnupg_interface();
    my ($handles, $tmp_fh, $tmp_fn) = get_test_gnupg_handles(temp_file_output=>1);
    $handles->stdout($tmp_fh);
    $gnupg->options->default_key('recipient@example.com');
    $gnupg->passphrase( "recipient" );

    my $entity = MIME::Entity->build(
        From    => 'recipient@example.com',
        To      => "general\@$RT::rtname",
        Subject => 'signed message for queue',
        Data    => ['fnord'],
    );


    my $signed_entity = mime_sign(gpg => $gnupg, handles => $handles, entity => $entity);
    my $mail = RT::Test->open_mailgate_ok($baseurl);
    $signed_entity->print($mail);

    RT::Test->close_mailgate_ok($mail);

    my $tick = RT::Test->last_ticket;
    is( $tick->Subject, 'signed message for queue',
        "Created the ticket"
    );

    my $txn = $tick->Transactions->First;
    my ($msg, $attach) = @{$txn->Attachments->ItemsArrayRef};

    is( $msg->GetHeader('X-RT-Incoming-Encryption'),
        'Not encrypted',
        'recorded incoming mail that is encrypted'
    );
    # test for some kind of PGP-Signed-By: Header
    like( $attach->Content, qr/fnord/);
}


# test for clear-signed mail
{
    my $gnupg = get_test_gnupg_interface();
    my ($handles, $tmp_fh, $tmp_fn) = get_test_gnupg_handles(temp_file_output=>1);
    $handles->stdout($tmp_fh);
    $gnupg->options->default_key('recipient@example.com');
    $gnupg->passphrase( "recipient" );

    my $entity = MIME::Entity->build(
        From    => 'recipient@example.com',
        To      => "general\@$RT::rtname",
        Subject => 'clear signed message for queue',
        Data    => ['clearfnord'],
    );

    my $signed_entity = mime_clear_sign(gpg => $gnupg, handles => $handles,
                                        entity => $entity);

    my $mail = RT::Test->open_mailgate_ok($baseurl);
    $signed_entity->print($mail);
    RT::Test->close_mailgate_ok($mail);

    my $tick = RT::Test->last_ticket;
    is( $tick->Subject, 'clear signed message for queue',
        "Created the ticket"
    );

    my $txn = $tick->Transactions->First;
    my ($msg, $attach) = @{$txn->Attachments->ItemsArrayRef};
    is( $msg->GetHeader('X-RT-Incoming-Encryption'),
        'Not encrypted',
        'recorded incoming mail that is encrypted'
    );

    # test for some kind of PGP-Signed-By: Header
    like( $attach->Content, qr/clearfnord/);
 }


# test for signed and encrypted mail
{
    my $gnupg = get_test_gnupg_interface();
    my ($handles, $tmp_fh, $tmp_fn) = get_test_gnupg_handles(temp_file_output=>1);
    $handles->stdout($tmp_fh);
    $gnupg->options->recipients(["general\@$RT::rtname"]);
    $gnupg->options->default_key('recipient@example.com');
    $gnupg->passphrase( "recipient" );


    my $entity = MIME::Entity->build(
        From    => 'recipient@example.com',
        To      => "general\@$RT::rtname",
        Subject => 'Encrypted message for queue',
        Data    => [],
    );

    $entity->attach(
            Type        => "application/octet-stream",
            Disposition => "inline",
            Data        => [ 'orzzzzzz_cipher\r\n' ],
            Encoding    => "base64",
        );

    my $signed_entity = mime_sign_encrypt(gpg => $gnupg, handles => $handles,
                                          entity => $entity, recipients => ["general\@$RT::rtname"]);

    my $mail = RT::Test->open_mailgate_ok($baseurl);
    $signed_entity->print($mail);
    RT::Test->close_mailgate_ok($mail);

    my $tick = RT::Test->last_ticket;
    is( $tick->Subject, 'Encrypted message for queue',
        "Created the ticket"
    );

    my $txn = $tick->Transactions->First;
    my ($msg, $attach1, $attach2, $orig, @other_attachments) = @{$txn->Attachments->ItemsArrayRef};

    is( $msg->GetHeader('X-RT-Incoming-Encryption'),
        'Success',
        'recorded incoming mail that is encrypted'
    );
    is( $msg->GetHeader('X-RT-Privacy'),
        'GnuPG',
        'recorded incoming mail that is encrypted'
    );

    is( $orig->GetHeader('Content-Type'), 'application/x-rt-original-message');
    ok(index($orig->Content, $signed_entity->parts(1)->as_string) != -1, 'found original msg');
}


# # test that if it gets base64 transfer-encoded, we still get the content out
# $buf = encode_base64($buf);
# $mail = RT::Test->open_mailgate_ok($baseurl);
# print $mail <<"EOF";
# From: recipient\@example.com
# To: general\@$RT::rtname
# Content-transfer-encoding: base64
# Subject: Encrypted message for queue

# $buf
# EOF
# RT::Test->close_mailgate_ok($mail);

# {
#     my $tick = RT::Test->last_ticket;
#     is( $tick->Subject, 'Encrypted message for queue',
#         "Created the ticket"
#     );

#     my $txn = $tick->Transactions->First;
#     my ($msg, $attach, $orig) = @{$txn->Attachments->ItemsArrayRef};

#     is( $msg->GetHeader('X-RT-Incoming-Encryption'),
#         'Success',
#         'recorded incoming mail that is encrypted'
#     );
#     is( $msg->GetHeader('X-RT-Privacy'),
#         'GnuPG',
#         'recorded incoming mail that is encrypted'
#     );
#     like( $attach->Content, qr/orz/);

#     is( $orig->GetHeader('Content-Type'), 'application/x-rt-original-message');
#     ok(index($orig->Content, $buf) != -1, 'found original msg');
# }

# # test for signed mail by other key
# $buf = '';

# run3(
#     shell_quote(
#         qw(gpg --batch --no-tty --armor --sign),
#         '--default-key' => 'rt@example.com',
#         '--homedir'     => $homedir,
#         '--passphrase'  => 'test',
#         '--no-permission-warning',
#     ),
#     \"alright\r\n",
#     \$buf,
#     \*STDOUT
# );

# $mail = RT::Test->open_mailgate_ok($baseurl);
# print $mail <<"EOF";
# From: recipient\@example.com
# To: general\@$RT::rtname
# Subject: signed message for queue

# $buf
# EOF
# RT::Test->close_mailgate_ok($mail);

# {
#     my $tick = RT::Test->last_ticket;
#     my $txn = $tick->Transactions->First;
#     my ($msg, $attach) = @{$txn->Attachments->ItemsArrayRef};
#     # XXX: in this case, which credential should we be using?
#     is( $msg->GetHeader('X-RT-Incoming-Signature'),
#         'Test User <rt@example.com>',
#         'recorded incoming mail signed by others'
#     );
# }

# # test for encrypted mail with key not associated to the queue
# $buf = '';

# run3(
#     shell_quote(
#         qw(gpg --batch --no-tty --armor --encrypt),
#         '--recipient'   => 'random@localhost',
#         '--homedir'     => $homedir,
#         '--no-permission-warning',
#     ),
#     \"should not be there either\r\n",
#     \$buf,
#     \*STDOUT
# );

# $mail = RT::Test->open_mailgate_ok($baseurl);
# print $mail <<"EOF";
# From: recipient\@example.com
# To: general\@$RT::rtname
# Subject: encrypted message for queue

# $buf
# EOF
# RT::Test->close_mailgate_ok($mail);

# {
#     my $tick = RT::Test->last_ticket;
#     my $txn = $tick->Transactions->First;
#     my ($msg, $attach) = @{$txn->Attachments->ItemsArrayRef};
    
#     TODO:
#     {
#         local $TODO = "this test requires keys associated with queues";
#         unlike( $attach->Content, qr/should not be there either/);
#     }
# }

# # test for badly encrypted mail
# {
# $buf = '';

# run3(
#     shell_quote(
#         qw(gpg --batch --no-tty --armor --encrypt),
#         '--recipient'   => 'rt@example.com',
#         '--homedir'     => $homedir,
#         '--no-permission-warning',
#     ),
#     \"really should not be there either\r\n",
#     \$buf,
#     \*STDOUT
# );

# $buf =~ s/PGP MESSAGE/SCREWED UP/g;

# RT::Test->fetch_caught_mails;

# $mail = RT::Test->open_mailgate_ok($baseurl);
# print $mail <<"EOF";
# From: recipient\@example.com
# To: general\@$RT::rtname
# Subject: encrypted message for queue

# $buf
# EOF
# RT::Test->close_mailgate_ok($mail);
# my @mail = RT::Test->fetch_caught_mails;
# is(@mail, 1, 'caught outgoing mail.');
# }

# {
#     my $tick = RT::Test->last_ticket;
#     my $txn = $tick->Transactions->First;
#     my ($msg, $attach) = @{$txn->Attachments->ItemsArrayRef};
#     unlike( ($attach ? $attach->Content : ''), qr/really should not be there either/);
# }


# # test that if it gets base64 transfer-encoded long mail then it doesn't hang
# {
#     local $SIG{ALRM} = sub {
#         ok 0, "timed out, web server is probably in deadlock";
#         exit;
#     };
#     alarm 30;
#     $buf = encode_base64('a'x(250*1024));
#     $mail = RT::Test->open_mailgate_ok($baseurl);
#     print $mail <<"EOF";
# From: recipient\@example.com
# To: general\@$RT::rtname
# Content-transfer-encoding: base64
# Subject: Long not encrypted message for queue

# $buf
# EOF
#     RT::Test->close_mailgate_ok($mail);
#     alarm 0;

#     my $tick = RT::Test->last_ticket;
#     is( $tick->Subject, 'Long not encrypted message for queue',
#         "Created the ticket"
#     );
#     my $content = $tick->Transactions->First->Content;
#     like $content, qr/a{1024,}/, 'content is not lost';
# }


sub write_gpg_input {
    my ($handles, @input_value) = @_;
    my $input = $handles->stdin;
    print $input @input_value;
    close $input;
    return;
}

sub read_gpg_output {
    my ($handles) = @_;
    my $buf;
    my $output = $handles->stdout;
    while (1) {
        my $read_ok = $output->read($buf, 64, length($buf));
        last if not $read_ok;
    }
    close $output;
    return $buf;
}

sub read_gpg_errors {
    my ($handles) = @_;
    my $error = $handles->stderr;
    my @error_output = <$error>;   # reading the error
    close $error;
    return @error_output;
}


####

# functions based on Mail::GPG cpan module

sub mime_sign {
    my %opts  = @_;
    my  ($gpg, $handles, $entity ) = @opts{qw/gpg handles entity/};

    #-- build entity for signed version
    #-- (only the 2nd part with the signature data
    #--  needs to be added later)
    my ( $signed_entity, $sign_part ) = build_rfc3156_multipart_entity(
        entity => $entity,
        method => "sign",
    );
  
    #-- execute gpg for signing
    my $pid = $gpg->detach_sign( handles => $handles );
 
    #-- put encoded entity data into temporary file
    #-- (faster than in-memory operation)
    my ( $data_fh, $data_file ) = File::Temp::tempfile();
    unlink $data_file;
    $sign_part->print($data_fh);
 
    #-- perform I/O (multiplexed to prevent blocking)
    my ( $output_stdout, $output_stderr ) = ("", "");
    perform_multiplexed_gpg_io(
        data_fh       => $data_fh,
        data_canonify => 1,
        stdin_fh      => $handles->stdin,
        stderr_fh     => $handles->stderr,
        stdout_fh     => $handles->stdout,
        stderr_sref   => \$output_stderr,
        stdout_sref   => \$output_stdout,
    );
 
    #-- close reader filehandles (stdin was closed
    #-- by perform_multiplexed_gpg_io())
    close $handles->stdout;
    close $handles->stderr;
 
    #-- fetch zombie
    waitpid $pid, 0;
    die $output_stderr if $?;
 
    #-- attach OpenPGP signature as second part
    $signed_entity->attach(
        Type        => "application/pgp-signature",
        Disposition => "inline",
        Data        => [$output_stdout],
        Encoding    => "7bit",
    );
  
    #-- close temporary data filehandle
    close $data_fh;
 
    #-- return signed entity
    return $signed_entity;
}

sub mime_clear_sign {
    my %opts  = @_;
    my  ($gpg, $handles, $entity ) = @opts{qw/gpg handles entity/};

    #-- we parse gpg's output and rely on english
    local $ENV{LC_ALL} = "C";
 
    #-- execute gpg for signing
    my $pid = $gpg->clearsign( handles => $handles );
 
    #-- put encoded entity data into temporary file
    #-- (faster than in-memory operation)
    my ( $data_fh, $data_file ) = File::Temp::tempfile();
    unlink $data_file;
    $entity->print($data_fh);
 
    #-- perform I/O (multiplexed to prevent blocking)
    my ( $output_stdout, $output_stderr ) = ("", "");
    perform_multiplexed_gpg_io(
        data_fh       => $data_fh,
        data_canonify => 1,
        stdin_fh      => $handles->stdin,
        stderr_fh     => $handles->stderr,
        stdout_fh     => $handles->stdout,
        stderr_sref   => \$output_stderr,
        stdout_sref   => \$output_stdout,
    );
 
    #-- close reader filehandles (stdin was closed
    #-- by perform_multiplexed_gpg_io())
    close $handles->stdout;
    close $handles->stderr;

    #-- fetch zombie
    waitpid $pid, 0;
    die $output_stderr if $?;
 
    #-- build entity for encrypted version
    my $signed_entity = MIME::Entity->build( Data => [$output_stdout], );
 
    #-- copy all header fields from original entity
    foreach my $tag ( $entity->head->tags ) {
        my @values = $entity->head->get($tag);
        for ( my $i = 0; $i < @values; ++$i ) {
            $signed_entity->head->replace( $tag, $values[$i], $i );
        }
    }
 
    #-- return the signed entity
    return $signed_entity;
}

sub mime_encrypt {
    my %par  = @_;
    my ($gpg, $handles, $entity, $recipients) = @par{qw/gpg handles entity recipients/};
 
    #-- call mime_sign_encrypt() with no_sign option
    return mime_sign_encrypt(
        gpg        => $gpg,
        handles    => $handles,
        entity     => $entity,
        recipients => $recipients,
        _no_sign   => 1,
    );
}
 
sub mime_sign_encrypt {
    my %opts  = @_;
    my  ($gpg, $handles, $entity, $recipients, $_no_sign) = @opts{qw/gpg handles entity recipients _no_sign/};
 
    #-- ignore any PIPE signals, in case of gpg exited
    #-- early before we fed our data into it.
    local $SIG{PIPE} = 'IGNORE';
 
    #-- we parse gpg's output and rely on english
    local $ENV{LC_ALL} = "C";
  
    #-- build entity for encrypted version
    #-- (only the 2nd part with the encrypted data
    #--  needs to be added later)
    my ( $encrypted_entity, $encrypt_part )
        = build_rfc3156_multipart_entity(
        entity => $entity,
        method => "encrypt",
        );
 
    #-- add recipients, but first extract the mail-adress
    #-- part, otherwise gpg couldn't find keys for adresses
    #-- with quoted printable encodings in the name part-
    $gpg->options->push_recipients($_) for @{$recipients};
 
    #-- execute gpg for encryption
    my $pid;
    if ($_no_sign) {
        $pid = $gpg->encrypt( handles => $handles );
    }
    else {
        $pid = $gpg->sign_and_encrypt( handles => $handles );
    }
    
    #-- put encoded entity data into temporary file
    #-- (faster than in-memory operation)
    my ( $data_fh, $data_file ) = File::Temp::tempfile();
    unlink $data_file;
    $encrypt_part->print($data_fh);
 
    #-- perform I/O (multiplexed to prevent blocking)
    my ( $output_stdout, $output_stderr ) = ("", "");
    perform_multiplexed_gpg_io(
        data_fh       => $data_fh,
        data_canonify => 1,
        stdin_fh      => $handles->stdin,
        stderr_fh     => $handles->stderr,
        stdout_fh     => $handles->stdout,
        stderr_sref   => \$output_stderr,
        stdout_sref   => \$output_stdout,
    );
 
    #-- close reader filehandles (stdin was closed
    #-- by perform_multiplexed_gpg_io())
    close $handles->stdout;
    close $handles->stderr;
 
    #-- fetch zombie
    waitpid $pid, 0;
    die $output_stderr if $?;
 
    #-- attach second part with the encrytped text
    $encrypted_entity->attach(
        Type        => "application/octet-stream",
        Disposition => "inline",
        Data        => [$output_stdout],
        Encoding    => "7bit",
    );

    #-- close temporary data filehandle
    close $data_fh;
 
    #-- return encrytped entity
    return $encrypted_entity;
}


sub build_rfc3156_multipart_entity {
    my %par  = @_;
    my ($entity, $method, $digest) = @par{'entity','method','digest'};

    $digest //= "RIPEMD160";

    #-- build entity for signed/encrypted version; first make
    #-- a copy of the given entity (deep copy of body
    #-- files isn't necessary, body data isn't modified
    #-- here).
    my $rfc_entity = $entity->dup;
 
    #-- determine the part, which is to be signed/encrypted
    my ( $work_part, $multipart );
    if ( $rfc_entity->parts > 1 ) {
 
        #-- the entity is multipart, so we need to build
        #-- a new version of it with all parts, but without
        #-- the rfc822 mail headers of the original entity
        #-- (according RFC 3156 the signed/encrypted parts
        #--  need MIME content headers only)
        $work_part = MIME::Entity->build( Type => "multipart/mixed" );
        $work_part->add_part($_) for $rfc_entity->parts;
        $rfc_entity->parts( [] );
        $multipart = 1;
    }
    else {
 
        #-- the entity is single part, so just make it
        #-- multipart and take the first (and only) part
        $rfc_entity->make_multipart;
        $work_part = $rfc_entity->parts(0);
        $multipart = 0;
    }
 
    #-- configure headers and add first part to the entity
    if ( $method eq 'sign' ) {
        #-- set correct MIME OpenPGP header für multipart/signed
        $rfc_entity->head->mime_attr( "Content-Type", "multipart/signed" );
        $rfc_entity->head->mime_attr( "Content-Type.protocol",
            "application/pgp-signature" );
        $rfc_entity->head->mime_attr( "Content-Type.micalg",
            "pgp-" . lc( $digest ) );
        #-- add content part as first part
        $rfc_entity->add_part($work_part) if $multipart;
    }
    else {
        #-- set correct MIME OpenPGP header für multipart/encrypted
        $rfc_entity->head->mime_attr( "Content-Type", "multipart/encrypted" );
        $rfc_entity->head->mime_attr( "Content-Type.protocol",
            "application/pgp-encrypted" );
 
        #-- remove all parts
        $rfc_entity->parts( [] );
 
        #-- and add OpenPGP version part as first part
        $rfc_entity->attach(
            Type        => "application/pgp-encrypted",
            Disposition => "inline",
            Data        => ["Version: 1\n"],
            Encoding    => "7bit",
        );
    }
 
    #-- return the newly created entitiy and the part to work on
    return ( $rfc_entity, $work_part );
}

sub perform_multiplexed_gpg_io {
    my %par  = @_;
    my  ($data_fh, $data_canonify, $stdin_fh, $stderr_fh) =
    @par{'data_fh','data_canonify','stdin_fh','stderr_fh'};
    my  ($stdout_fh, $status_fh, $stderr_sref, $stdout_sref) =
    @par{'stdout_fh','status_fh','stderr_sref','stdout_sref'};
    my  ($status_sref) =
    $par{'status_sref'};
 
    require IO::Select;
 
    #-- perl < 5.6 compatibility: seek() and read() work
    #-- on native GLOB filehandle only, so dertmine type
    #-- of filehandle here
    my $data_fh_glob = ref $data_fh eq 'GLOB';
 
    #-- rewind the data filehandle
    if ($data_fh_glob) {
        seek $data_fh, 0, 0;
    }
    else {
        $data_fh->seek( 0, 0 );
    }
 
    #-- create IO::Select objects for all
    #-- filehandles in question
    my $stdin  = IO::Select->new($stdin_fh);
    my $stderr = IO::Select->new($stderr_fh);
    my $stdout = IO::Select->new($stdout_fh);
    my $status = $status_fh ? IO::Select->new($status_fh) : undef;
 
    my $buffer;
    while (1) {
 
        #-- as long we has data try to write
        #-- it into gpg
        while ( $data_fh && $stdin->can_write(0.001) ) {
            if ( $data_fh_glob
                ? read $data_fh,
                $buffer, 1024
                : $data_fh->read( $buffer, 1024 ) ) {
 
                #-- ok, got a block of data
                if ($data_canonify) {
 
                    #-- canonify it if requested
                    $buffer =~ s/\x0A/\x0D\x0A/g;
                    $buffer =~ s/\x0D\x0D\x0A/\x0D\x0A/g;
                }
 
                #-- feed it into gpg
                print $stdin_fh $buffer;
            }
            else {
 
                #-- no data read, close gpg's stdin
                #-- and set the data filehandle to false
                close $stdin_fh;
                $data_fh = 0;
            }
        }
 
        #-- probably we can read from gpg's stdout
        while ( $stdout->can_read(0.001) ) {
            last if eof($stdout_fh);
            $$stdout_sref .= <$stdout_fh>;
        }
 
        #-- probably we can read from gpg's stderr
        while ( $stderr->can_read(0.001) ) {
            last if eof($stderr_fh);
            $$stderr_sref .= <$stderr_fh>;
        }
 
        #-- probably we can read from gpg's status
        if ($status) {
            while ( $status->can_read(0.001) ) {
                last if eof($status_fh);
                $$status_sref .= <$status_fh>;
            }
        }
 
        #-- we're finished if no more data left
        #-- and both gpg's stdout and stderr
        #-- are at eof.
        return
            if !$data_fh
            && eof($stderr_fh)
            && eof($stdout_fh)
            && ( !$status_fh || eof($status_fh) );
    }
 
    1;
}
