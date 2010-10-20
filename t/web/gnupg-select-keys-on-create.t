#!/usr/bin/perl -w
use strict;
use warnings;

use RT::Test::GnuPG tests => 78;

use RT::Action::SendEmail;
use File::Temp qw(tempdir);

RT::Test->set_mail_catcher;

use_ok('RT::Crypt::GnuPG');

RT->Config->Set( GnuPG =>
    Enable => 1,
    OutgoingMessagesFormat => 'RFC',
);

RT->Config->Set( GnuPGOptions =>
    homedir => scalar tempdir( CLEANUP => 0 ),
    passphrase => 'rt-test',
    'no-permission-warning' => undef,
);
diag "GnuPG --homedir ". RT->Config->Get('GnuPGOptions')->{'homedir'};

RT->Config->Set( 'MailPlugins' => 'Auth::MailFrom', 'Auth::GnuPG' );

my $queue = RT::Test->load_or_create_queue(
    Name              => 'Regression',
    CorrespondAddress => 'rt-recipient@example.com',
    CommentAddress    => 'rt-recipient@example.com',
);
ok $queue && $queue->id, 'loaded or created queue';

RT::Test->set_rights(
    Principal => 'Everyone',
    Right => ['CreateTicket', 'ShowTicket', 'SeeQueue', 'ReplyToTicket', 'ModifyTicket'],
);

my ($baseurl, $m) = RT::Test->started_ok;
ok $m->login, 'logged in';

diag "check that signing doesn't work if there is no key";
{
    RT::Test->clean_caught_mails;

    ok $m->goto_create_ticket( $queue ), "UI -> create ticket";
    $m->form_number(3);
    $m->tick( Sign => 1 );
    $m->field( Requestors => 'rt-test@example.com' );
    $m->field( Content => 'Some content' );
    $m->submit;
    $m->content_contains(
        'unable to sign outgoing email messages',
        'problems with passphrase'
    );
    $m->warning_like(qr/signing failed: secret key not available/);

    my @mail = RT::Test->fetch_caught_mails;
    ok !@mail, 'there are no outgoing emails';
}

{
    RT::Test->import_gnupg_key('rt-recipient@example.com');
    RT::Test->trust_gnupg_key('rt-recipient@example.com');
    my %res = RT::Crypt::GnuPG::GetKeysInfo('rt-recipient@example.com');
    is $res{'info'}[0]{'TrustTerse'}, 'ultimate', 'ultimately trusted key';
}

diag "check that things don't work if there is no key";
{
    RT::Test->clean_caught_mails;

    ok $m->goto_create_ticket( $queue ), "UI -> create ticket";
    $m->form_number(3);
    $m->tick( Encrypt => 1 );
    $m->field( Requestors => 'rt-test@example.com' );
    $m->field( Content => 'Some content' );
    $m->submit;
    $m->content_contains(
        'You are going to encrypt outgoing email messages',
        'problems with keys'
    );
    $m->content_contains(
        'There is no key suitable for encryption',
        'problems with keys'
    );

    my $form = $m->form_number(3);
    ok !$form->find_input( 'UseKey-rt-test@example.com' ), 'no key selector';

    my @mail = RT::Test->fetch_caught_mails;
    ok !@mail, 'there are no outgoing emails';

    $m->next_warning_like(qr/public key not found/) for 1 .. 4;
    $m->no_leftover_warnings_ok;
}

diag "import first key of rt-test\@example.com";
my $fpr1 = '';
{
    RT::Test->import_gnupg_key('rt-test@example.com', 'public');
    my %res = RT::Crypt::GnuPG::GetKeysInfo('rt-test@example.com');
    is $res{'info'}[0]{'TrustLevel'}, 0, 'is not trusted key';
    $fpr1 = $res{'info'}[0]{'Fingerprint'};
}

diag "check that things still doesn't work if key is not trusted";
{
    RT::Test->clean_caught_mails;

    ok $m->goto_create_ticket( $queue ), "UI -> create ticket";
    $m->form_number(3);
    $m->tick( Encrypt => 1 );
    $m->field( Requestors => 'rt-test@example.com' );
    $m->field( Content => 'Some content' );
    $m->submit;
    $m->content_contains(
        'You are going to encrypt outgoing email messages',
        'problems with keys'
    );
    $m->content_contains(
        'There is one suitable key, but trust level is not set',
        'problems with keys'
    );

    my $form = $m->form_number(3);
    ok my $input = $form->find_input( 'UseKey-rt-test@example.com' ), 'found key selector';
    is scalar $input->possible_values, 1, 'one option';

    $m->select( 'UseKey-rt-test@example.com' => $fpr1 );
    $m->submit;
    $m->content_contains(
        'You are going to encrypt outgoing email messages',
        'problems with keys'
    );
    $m->content_contains(
        'Selected key either is not trusted',
        'problems with keys'
    );

    my @mail = RT::Test->fetch_caught_mails;
    ok !@mail, 'there are no outgoing emails';

    $m->no_warnings_ok;
}

diag "import a second key of rt-test\@example.com";
my $fpr2 = '';
{
    RT::Test->import_gnupg_key('rt-test@example.com.2', 'public');
    my %res = RT::Crypt::GnuPG::GetKeysInfo('rt-test@example.com');
    is $res{'info'}[1]{'TrustLevel'}, 0, 'is not trusted key';
    $fpr2 = $res{'info'}[2]{'Fingerprint'};
}

diag "check that things still doesn't work if two keys are not trusted";
{
    RT::Test->clean_caught_mails;

    ok $m->goto_create_ticket( $queue ), "UI -> create ticket";
    $m->form_number(3);
    $m->tick( Encrypt => 1 );
    $m->field( Requestors => 'rt-test@example.com' );
    $m->field( Content => 'Some content' );
    $m->submit;
    $m->content_contains(
        'You are going to encrypt outgoing email messages',
        'problems with keys'
    );
    $m->content_contains(
        'There are several keys suitable for encryption',
        'problems with keys'
    );

    my $form = $m->form_number(3);
    ok my $input = $form->find_input( 'UseKey-rt-test@example.com' ), 'found key selector';
    is scalar $input->possible_values, 2, 'two options';

    $m->select( 'UseKey-rt-test@example.com' => $fpr1 );
    $m->submit;
    $m->content_contains(
        'You are going to encrypt outgoing email messages',
        'problems with keys'
    );
    $m->content_contains(
        'Selected key either is not trusted',
        'problems with keys'
    );

    my @mail = RT::Test->fetch_caught_mails;
    ok !@mail, 'there are no outgoing emails';

    $m->no_warnings_ok;
}

{
    RT::Test->lsign_gnupg_key( $fpr1 );
    my %res = RT::Crypt::GnuPG::GetKeysInfo('rt-test@example.com');
    ok $res{'info'}[0]{'TrustLevel'} > 0, 'trusted key';
    is $res{'info'}[1]{'TrustLevel'}, 0, 'is not trusted key';
}

diag "check that we see key selector even if only one key is trusted but there are more keys";
{
    RT::Test->clean_caught_mails;

    ok $m->goto_create_ticket( $queue ), "UI -> create ticket";
    $m->form_number(3);
    $m->tick( Encrypt => 1 );
    $m->field( Requestors => 'rt-test@example.com' );
    $m->field( Content => 'Some content' );
    $m->submit;
    $m->content_contains(
        'You are going to encrypt outgoing email messages',
        'problems with keys'
    );
    $m->content_contains(
        'There are several keys suitable for encryption',
        'problems with keys'
    );

    my $form = $m->form_number(3);
    ok my $input = $form->find_input( 'UseKey-rt-test@example.com' ), 'found key selector';
    is scalar $input->possible_values, 2, 'two options';

    my @mail = RT::Test->fetch_caught_mails;
    ok !@mail, 'there are no outgoing emails';

    $m->no_warnings_ok;
}

diag "check that key selector works and we can select trusted key";
{
    RT::Test->clean_caught_mails;

    ok $m->goto_create_ticket( $queue ), "UI -> create ticket";
    $m->form_number(3);
    $m->tick( Encrypt => 1 );
    $m->field( Requestors => 'rt-test@example.com' );
    $m->field( Content => 'Some content' );
    $m->submit;
    $m->content_contains(
        'You are going to encrypt outgoing email messages',
        'problems with keys'
    );
    $m->content_contains(
        'There are several keys suitable for encryption',
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
    check_text_emails( { Encrypt => 1 }, @mail );

    $m->no_warnings_ok;
}

diag "check encrypting of attachments";
{
    RT::Test->clean_caught_mails;

    ok $m->goto_create_ticket( $queue ), "UI -> create ticket";
    $m->form_number(3);
    $m->tick( Encrypt => 1 );
    $m->field( Requestors => 'rt-test@example.com' );
    $m->field( Content => 'Some content' );
    $m->field( Attach => $0 );
    $m->submit;
    $m->content_contains(
        'You are going to encrypt outgoing email messages',
        'problems with keys'
    );
    $m->content_contains(
        'There are several keys suitable for encryption',
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
    check_text_emails( { Encrypt => 1, Attachment => 1 }, @mail );

    $m->no_warnings_ok;
}

