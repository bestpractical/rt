#!/usr/bin/perl -w
use strict;
use warnings;

use Test::More tests => 60;
use RT::Test;
use RT::ScripAction::SendEmail;
use File::Temp qw(tempdir);

RT::Test->set_mail_catcher;

RT->config->set( LogToScreen => 'debug' );
RT->config->set( LogStackTraces => 'error' );

use_ok('RT::Crypt::GnuPG');

RT->config->set( GnuPG =>
    Enable => 1,
    outgoing_messages_format => 'RFC',
);

RT->config->set( GnuPGOptions =>
    homedir => scalar tempdir( CLEANUP => 0 ),
    passphrase => 'rt-test',
    'no-permission-warning' => undef,
);
diag "GnuPG --homedir ". RT->config->get('GnuPGOptions')->{'homedir'};

RT->config->set( 'MailPlugins' => 'Auth::MailFrom', 'Auth::GnuPG' );

my $queue = RT::Test->load_or_create_queue(
    name              => 'Regression',
    correspond_address => 'rt-recipient@example.com',
    comment_address    => 'rt-recipient@example.com',
);
ok $queue && $queue->id, 'loaded or created queue';

RT::Test->set_rights(
    principal => 'Everyone',
    right => ['CreateTicket', 'ShowTicket', 'SeeQueue', 'ReplyToTicket', 'ModifyTicket'],
);

my ($baseurl, $m) = RT::Test->started_ok;
ok $m->login, 'logged in';

diag "check that signing doesn't work if there is no key";
{
    RT::Test->fetch_caught_mails;

    ok $m->goto_create_ticket( $queue ), "UI -> create ticket";
    $m->form_number(3);
    $m->tick( sign => 1 );
    $m->field( Requestors => 'rt-test@example.com' );
    $m->field( Content => 'Some content' );
    $m->submit;
    $m->content_like(
        qr/unable to sign outgoing email messages/i,
        'problems with passphrase'
    );

    my @mail = RT::Test->fetch_caught_mails;
    ok !@mail, 'there are no outgoing emails';
}

{
    RT::Test->import_gnupg_key('rt-recipient@example.com');
    RT::Test->trust_gnupg_key('rt-recipient@example.com');
    my %res = RT::Crypt::GnuPG::get_keys_info('rt-recipient@example.com');
    is $res{'info'}[0]{'TrustTerse'}, 'ultimate', 'ultimately trusted key';
}

diag "check that things don't work if there is no key";
{
    RT::Test->fetch_caught_mails;

    ok $m->goto_create_ticket( $queue ), "UI -> create ticket";
    $m->form_number(3);
    $m->tick( encrypt => 1 );
    $m->field( Requestors => 'rt-test@example.com' );
    $m->field( Content => 'Some content' );
    $m->submit;
    $m->content_like(
        qr/You are going to encrypt outgoing email messages/i,
        'problems with keys'
    );
    $m->content_like(
        qr/There is no key suitable for encryption/i,
        'problems with keys'
    );

    my $form = $m->form_number(3);
    ok !$form->find_input( 'UseKey-rt-test@example.com' ), 'no key selector';

    my @mail = RT::Test->fetch_caught_mails;
    ok !@mail, 'there are no outgoing emails';
}

diag "import first key of rt-test\@example.com";
my $fpr1 = '';
{
    RT::Test->import_gnupg_key('rt-test@example.com', 'public');
    my %res = RT::Crypt::GnuPG::get_keys_info('rt-test@example.com');
    is $res{'info'}[0]{'TrustLevel'}, 0, 'is not trusted key';
    $fpr1 = $res{'info'}[0]{'Fingerprint'};
}

diag "check that things still doesn't work if key is not trusted";
{
    RT::Test->fetch_caught_mails;

    ok $m->goto_create_ticket( $queue ), "UI -> create ticket";
    $m->form_number(3);
    $m->tick( encrypt => 1 );
    $m->field( Requestors => 'rt-test@example.com' );
    $m->field( Content => 'Some content' );
    $m->submit;
    $m->content_like(
        qr/You are going to encrypt outgoing email messages/i,
        'problems with keys'
    );
    $m->content_like(
        qr/There is one suitable key, but trust level is not set/i,
        'problems with keys'
    );

    my $form = $m->form_number(3);
    ok my $input = $form->find_input( 'UseKey-rt-test@example.com' ), 'found key selector';
    is scalar $input->possible_values, 1, 'one option';

    $m->select( 'UseKey-rt-test@example.com' => $fpr1 );
    $m->submit;
    $m->content_like(
        qr/You are going to encrypt outgoing email messages/i,
        'problems with keys'
    );
    $m->content_like(
        qr/Selected key either is not trusted/i,
        'problems with keys'
    );

    my @mail = RT::Test->fetch_caught_mails;
    ok !@mail, 'there are no outgoing emails';
}

diag "import a second key of rt-test\@example.com";
my $fpr2 = '';
{
    RT::Test->import_gnupg_key('rt-test@example.com.2', 'public');
    my %res = RT::Crypt::GnuPG::get_keys_info('rt-test@example.com');
    is $res{'info'}[1]{'TrustLevel'}, 0, 'is not trusted key';
    $fpr2 = $res{'info'}[2]{'Fingerprint'};
}

diag "check that things still doesn't work if two keys are not trusted";
{
    RT::Test->fetch_caught_mails;

    ok $m->goto_create_ticket( $queue ), "UI -> create ticket";
    $m->form_number(3);
    $m->tick( encrypt => 1 );
    $m->field( Requestors => 'rt-test@example.com' );
    $m->field( Content => 'Some content' );
    $m->submit;
    $m->content_like(
        qr/You are going to encrypt outgoing email messages/i,
        'problems with keys'
    );
    $m->content_like(
        qr/There are several keys suitable for encryption/i,
        'problems with keys'
    );

    my $form = $m->form_number(3);
    ok my $input = $form->find_input( 'UseKey-rt-test@example.com' ), 'found key selector';
    is scalar $input->possible_values, 2, 'two options';

    $m->select( 'UseKey-rt-test@example.com' => $fpr1 );
    $m->submit;
    $m->content_like(
        qr/You are going to encrypt outgoing email messages/i,
        'problems with keys'
    );
    $m->content_like(
        qr/Selected key either is not trusted/i,
        'problems with keys'
    );

    my @mail = RT::Test->fetch_caught_mails;
    ok !@mail, 'there are no outgoing emails';
}

{
    RT::Test->lsign_gnupg_key( $fpr1 );
    my %res = RT::Crypt::GnuPG::get_keys_info('rt-test@example.com');
    ok $res{'info'}[0]{'TrustLevel'} > 0, 'trusted key';
    is $res{'info'}[1]{'TrustLevel'}, 0, 'is not trusted key';
}

diag "check that we see key selector even if only one key is trusted but there are more keys";
{
    RT::Test->fetch_caught_mails;

    ok $m->goto_create_ticket( $queue ), "UI -> create ticket";
    $m->form_number(3);
    $m->tick( encrypt => 1 );
    $m->field( Requestors => 'rt-test@example.com' );
    $m->field( Content => 'Some content' );
    $m->submit;
    $m->content_like(
        qr/You are going to encrypt outgoing email messages/i,
        'problems with keys'
    );
    $m->content_like(
        qr/There are several keys suitable for encryption/i,
        'problems with keys'
    );

    my $form = $m->form_number(3);
    ok my $input = $form->find_input( 'UseKey-rt-test@example.com' ), 'found key selector';
    is scalar $input->possible_values, 2, 'two options';

    my @mail = RT::Test->fetch_caught_mails;
    ok !@mail, 'there are no outgoing emails';
}

diag "check that key selector works and we can select trusted key";
{
    RT::Test->fetch_caught_mails;

    ok $m->goto_create_ticket( $queue ), "UI -> create ticket";
    $m->form_number(3);
    $m->tick( encrypt => 1 );
    $m->field( Requestors => 'rt-test@example.com' );
    $m->field( Content => 'Some content' );
    $m->submit;
    $m->content_like(
        qr/You are going to encrypt outgoing email messages/i,
        'problems with keys'
    );
    $m->content_like(
        qr/There are several keys suitable for encryption/i,
        'problems with keys'
    );

    my $form = $m->form_number(3);
    ok my $input = $form->find_input( 'UseKey-rt-test@example.com' ), 'found key selector';
    is scalar $input->possible_values, 2, 'two options';

    $m->select( 'UseKey-rt-test@example.com' => $fpr1 );
    $m->submit;
    $m->content_like( qr/Ticket \d+ created in queue/i, 'ticket created' );

    my @mail = RT::Test->fetch_caught_mails;
    ok @mail, 'there are some emails';
    check_text_emails( { encrypt => 1 }, @mail );
}

diag "check encrypting of attachments";
{
    RT::Test->fetch_caught_mails;

    ok $m->goto_create_ticket( $queue ), "UI -> create ticket";
    $m->form_number(3);
    $m->tick( encrypt => 1 );
    $m->field( Requestors => 'rt-test@example.com' );
    $m->field( Content => 'Some content' );
    $m->field( Attach => $0 );
    $m->submit;
    $m->content_like(
        qr/You are going to encrypt outgoing email messages/i,
        'problems with keys'
    );
    $m->content_like(
        qr/There are several keys suitable for encryption/i,
        'problems with keys'
    );

    my $form = $m->form_number(3);
    ok my $input = $form->find_input( 'UseKey-rt-test@example.com' ), 'found key selector';
    is scalar $input->possible_values, 2, 'two options';

    $m->select( 'UseKey-rt-test@example.com' => $fpr1 );
    $m->submit;
    $m->content_like( qr/Ticket \d+ created in queue/i, 'ticket created' );

    my @mail = RT::Test->fetch_caught_mails;
    ok @mail, 'there are some emails';
    check_text_emails( { encrypt => 1, Attachment => 1 }, @mail );
}

sub check_text_emails {
    my %args = %{ shift @_ };
    my @mail = @_;

    ok scalar @mail, "got some mail";
    for my $mail (@mail) {
        for my $type ('email', 'attachment') {
            next if $type eq 'attachment' && !$args{'Attachment'};

            my $content = $type eq 'email'
                        ? "Some content"
                        : "Attachment content";

            if ( $args{'encrypt'} ) {
                unlike $mail, qr/$content/, "outgoing $type was encrypted";
            } else {
                like $mail, qr/$content/, "outgoing $type was not encrypted";
            } 

            next unless $type eq 'email';

            if ( $args{'sign'} && $args{'encrypt'} ) {
                like $mail, qr/BEGIN PGP MESSAGE/, 'outgoing email was signed';
            } elsif ( $args{'sign'} ) {
                like $mail, qr/SIGNATURE/, 'outgoing email was signed';
            } else {
                unlike $mail, qr/SIGNATURE/, 'outgoing email was not signed';
            }
        }
    }
}

