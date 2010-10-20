#!/usr/bin/perl -w
use strict;
use warnings;

use RT::Test::GnuPG tests => 30;

use RT::Action::SendEmail;
use File::Temp qw(tempdir);

RT::Test->set_mail_catcher;

use_ok('RT::Crypt::GnuPG');

RT->Config->Set( GnuPG =>
    Enable => 1,
    OutgoingMessagesFormat => 'RFC',
);

RT->Config->Set( GnuPGOptions =>
    homedir => scalar tempdir( CLEANUP => 1 ),
    passphrase => 'rt-test',
    'no-permission-warning' => undef,
    'trust-model' => 'always',
);
RT->Config->Set( 'MailPlugins' => 'Auth::MailFrom', 'Auth::GnuPG' );

RT::Test->import_gnupg_key('rt-recipient@example.com');
RT::Test->import_gnupg_key('rt-test@example.com', 'public');

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

my @variants = (
    {},
    { Sign => 1 },
    { Encrypt => 1 },
    { Sign => 1, Encrypt => 1 },
);

# collect emails
my %mail = (
    plain            => [],
    signed           => [],
    encrypted        => [],
    signed_encrypted => [],
);

diag "check in read-only mode that queue's props influence create/update ticket pages";
{
    foreach my $variant ( @variants ) {
        set_queue_crypt_options( %$variant );
        $m->goto_create_ticket( $queue );
        $m->form_name('TicketCreate');
        if ( $variant->{'Encrypt'} ) {
            ok $m->value('Encrypt', 2), "encrypt tick box is checked";
        } else {
            ok !$m->value('Encrypt', 2), "encrypt tick box is unchecked";
        }
        if ( $variant->{'Sign'} ) {
            ok $m->value('Sign', 2), "sign tick box is checked";
        } else {
            ok !$m->value('Sign', 2), "sign tick box is unchecked";
        }
    }

    # to avoid encryption/signing during create
    set_queue_crypt_options();

    my $ticket = RT::Ticket->new( RT->SystemUser );
    my ($id) = $ticket->Create(
        Subject   => 'test',
        Queue     => $queue->id,
        Requestor => 'rt-test@example.com',
    );
    ok $id, 'ticket created';

    foreach my $variant ( @variants ) {
        set_queue_crypt_options( %$variant );
        $m->get( $m->rt_base_url . "/Ticket/Update.html?Action=Respond&id=$id" );
        $m->form_number(3);
        if ( $variant->{'Encrypt'} ) {
            ok $m->value('Encrypt', 2), "encrypt tick box is checked";
        } else {
            ok !$m->value('Encrypt', 2), "encrypt tick box is unchecked";
        }
        if ( $variant->{'Sign'} ) {
            ok $m->value('Sign', 2), "sign tick box is checked";
        } else {
            ok !$m->value('Sign', 2), "sign tick box is unchecked";
        }
    }
}


sub create_a_ticket {
    my %args = (@_);

    RT::Test->clean_caught_mails;

    $m->goto_create_ticket( $queue );
    $m->form_name('TicketCreate');
    $m->field( Subject    => 'test' );
    $m->field( Requestors => 'rt-test@example.com' );
    $m->field( Content    => 'Some content' );

    foreach ( qw(Sign Encrypt) ) {
        if ( $args{ $_ } ) {
            $m->tick( $_ => 1 );
        } else {
            $m->untick( $_ => 1 );
        }
    }

    $m->submit;
    is $m->status, 200, "request successful";

    $m->content_lacks('unable to sign outgoing email messages');

    $m->get_ok('/'); # ensure that the mail has been processed

    my @mail = RT::Test->fetch_caught_mails;
    check_text_emails( \%args, @mail );
}

sub set_queue_crypt_options {
    my %args = @_;
    $m->get_ok("/Admin/Queues/Modify.html?id=". $queue->id);
    $m->form_with_fields('Sign', 'Encrypt');
    foreach my $opt ('Sign', 'Encrypt') {
        if ( $args{$opt} ) {
            $m->tick($opt => 1);
        } else {
            $m->untick($opt => 1);
        }
    }
    $m->submit;
}

