# BEGIN BPS TAGGED BLOCK {{{
#
# COPYRIGHT:
#
# This software is Copyright (c) 1996-2019 Best Practical Solutions, LLC
#                                          <sales@bestpractical.com>
#
# (Except where explicitly superseded by other copyright notices)
#
#
# LICENSE:
#
# This work is made available to you under the terms of Version 2 of
# the GNU General Public License. A copy of that license should have
# been provided with this software, but in any event can be snarfed
# from www.gnu.org.
#
# This work is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA
# 02110-1301 or visit their web page on the internet at
# http://www.gnu.org/licenses/old-licenses/gpl-2.0.html.
#
#
# CONTRIBUTION SUBMISSION POLICY:
#
# (The following paragraph is not intended to limit the rights granted
# to you to modify and distribute this software under the terms of
# the GNU General Public License and is only of importance to you if
# you choose to contribute your changes and enhancements to the
# community by submitting them to Best Practical Solutions, LLC.)
#
# By intentionally submitting any modifications, corrections or
# derivatives to this work, or any other work intended for use with
# Request Tracker, to Best Practical Solutions, LLC, you confirm that
# you are the copyright holder for those contributions and you grant
# Best Practical Solutions,  LLC a nonexclusive, worldwide, irrevocable,
# royalty-free, perpetual, license to use, copy, create derivative
# works based on those contributions, and sublicense and distribute
# those contributions and any derivatives thereof.
#
# END BPS TAGGED BLOCK }}}

package RT::Test::GnuPG;
use strict;
use warnings;
use Test::More;
use base qw(RT::Test);
use File::Temp qw(tempdir);
use Cwd;
use File::Path qw (make_path);
use File::Copy;
use GnuPG::Interface;
use RT::Crypt::GnuPG;

our @EXPORT =
  qw(create_a_ticket update_ticket cleanup_headers set_queue_crypt_options
          check_text_emails send_email_and_check_trangnsaction
          create_and_test_outgoing_emails
          copy_test_keys_to_homedir copy_test_keyring_to_homedir
          get_test_gnupg_interface get_test_data_dir
          $homedir $gnupg_version $using_legacy_gnupg
          );

no warnings qw(redefine once);

BEGIN {
    use vars qw($homedir $gnupg_version $using_legacy_gnupg);
    my $tempdir_template = 'test_gnupg_XXXXXXXXX';
    $homedir = tempdir( $tempdir_template, DIR => '/tmp', CLEANUP => 1);

    $ENV{'GNUPGHOME'} =  $homedir;

    my %supported_opt = map { $_ => 1 } qw(
       always_trust
       armor
       batch
       comment
       compress_algo
       default_key
       encrypt_to
       extra_args
       force_v3_sigs
       homedir
       logger_fd
       no_greeting
       no_options
       no_verbose
       openpgp
       options
       passphrase_fd
       quiet
       recipients
       rfc1991
       status_fd
       textmode
       verbose
                                      );

    *RT::Crypt::GnuPG::_PrepareGnuPGOptions = sub {
        my %opt = @_;
        $opt{homedir} = $homedir;
        my %res = map { lc $_ => $opt{ $_ } } grep $supported_opt{ lc $_ }, keys %opt;
        $res{'extra_args'} ||= [];
        foreach my $o ( grep !$supported_opt{ lc $_ }, keys %opt ) {
            push @{ $res{'extra_args'} }, '--'. lc $o;
            push @{ $res{'extra_args'} }, $opt{ $o }
                if defined $opt{ $o };
        }
        return %res;
    };

    make_path($homedir, { mode => 0700 });
    my $data_path = RT::Test::get_abs_relocatable_dir( File::Spec->updir(), 'data');
    copy('$data_path/gpg.conf', $homedir . '/gpg.conf');

    my $gnupg = GnuPG::Interface->new;
    $gnupg->options->hash_init(
       RT::Crypt::GnuPG::_PrepareGnuPGOptions( ),
    );

    $gnupg_version = $gnupg->version;
    $using_legacy_gnupg = 1;

    if ($gnupg->cmp_version($gnupg_version, '2.2') >= 0 ) {
        $using_legacy_gnupg = 0;

        my $agentconf = IO::File->new( "> " . $homedir . "/gpg-agent.conf" );
        # Classic gpg can't use loopback pinentry programs like fake-pinentry.pl.

        # default to empty passphrase pinentry
        # passphrase in "pinentry-program $data_path/gnupg2/bin/fake-pinentry.pl\n"
        $agentconf->write(
            "allow-preset-passphrase\n".
                "allow-loopback-pinentry\n".
                "pinentry-program $data_path/gnupg2/bin/empty-pinentry.pl\n"
            );

        $agentconf->close();

        my $error = system("gpg-connect-agent", "--homedir", "$homedir", '/bye');
        if ($error) {
            warn "gpg-connect-agent returned error : $error";
        }

        $error = system('gpg-connect-agent', "--homedir", "$homedir", 'reloadagent', '/bye');
        if ($error) {
            warn "gpg-connect-agent returned error : $error";
        }

        $error = system("gpg-agent", '--homedir', "$homedir");
        if ($error) {
            warn "gpg-agent returned error : $error";
        }
    }
}


END {
    unless ($using_legacy_gnupg) {
        system('gpgconf', '--homedir', $homedir,'--quiet', '--kill', 'gpg-agent');
        delete $ENV{'GNUPGHOME'};
    }
}

sub import {
    my $class = shift;
    my %args  = @_;
    my $t     = $class->builder;

    RT::Test::plan( skip_all => 'GnuPG required.' )
      unless GnuPG::Interface->require;
    RT::Test::plan( skip_all => 'gpg executable is required.' )
      unless RT::Test->find_executable('gpg');

    $class->SUPER::import(%args);
    return $class->export_to_level(1)
        if $^C;

    RT::Test::diag "GnuPG --homedir over-ridden for tests : " . $ENV{'GNUPGHOME'};
    RT::Test::diag "GnuPG --homedir from config " . RT->Config->Get('GnuPGOptions')->{'homedir'};

    $class->set_rights(
        Principal => 'Everyone',
        Right => ['CreateTicket', 'ShowTicket', 'SeeQueue', 'ReplyToTicket', 'ModifyTicket'],
    );

    $class->export_to_level(1);
}

sub bootstrap_more_config {
    my $self = shift;
    my $handle = shift;
    my $args = shift;

    $self->SUPER::bootstrap_more_config($handle, $args, @_);

    my %gnupg_options = (
        'no-permission-warning' => undef,
        $args->{gnupg_options} ? %{ $args->{gnupg_options} } : (),
    );
    $gnupg_options{homedir} ||= scalar tempdir( CLEANUP => 1 );

    use Data::Dumper;
    local $Data::Dumper::Terse = 1; # "{...}" instead of "$VAR1 = {...};"
    my $dumped_gnupg_options = Dumper(\%gnupg_options);

    print $handle qq{
Set(\%GnuPG, (
    Enable                 => 1,
    OutgoingMessagesFormat => 'RFC',
));
Set(\%GnuPGOptions => \%{ $dumped_gnupg_options });
};

}

sub create_a_ticket {
    my $queue = shift;
    my $mail = shift;
    my $m = shift;
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

    $m->click('SubmitTicket');
    is $m->status, 200, "request successful";

    $m->content_lacks("unable to sign outgoing email messages");


    my @mail = RT::Test->fetch_caught_mails;
    check_text_emails(\%args, @mail );
    categorize_emails($mail, \%args, @mail );
}

sub update_ticket {
    my $tid = shift;
    my $mail = shift;
    my $m = shift;
    my %args = (@_);

    RT::Test->clean_caught_mails;

    $m->get( $m->rt_base_url . "/Ticket/Update.html?Action=Respond&id=$tid" );
    $m->form_number(3);
    $m->field( UpdateContent => 'Some content' );

    foreach ( qw(Sign Encrypt) ) {
        if ( $args{ $_ } ) {
            $m->tick( $_ => 1 );
        } else {
            $m->untick( $_ => 1 );
        }
    }

    $m->click('SubmitTicket');
    is $m->status, 200, "request successful";
    $m->content_contains("Correspondence added", 'Correspondence added') or diag $m->content;


    my @mail = RT::Test->fetch_caught_mails;
    check_text_emails(\%args, @mail );
    categorize_emails($mail, \%args, @mail );
}

sub categorize_emails {
    my $mail = shift;
    my $args = shift;
    my @mail = @_;

    if ( $args->{'Sign'} && $args->{'Encrypt'} ) {
        push @{ $mail->{'signed_encrypted'} }, @mail;
    }
    elsif ( $args->{'Sign'} ) {
        push @{ $mail->{'signed'} }, @mail;
    }
    elsif ( $args->{'Encrypt'} ) {
        push @{ $mail->{'encrypted'} }, @mail;
    }
    else {
        push @{ $mail->{'plain'} }, @mail;
    }
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
                        : $args{Attachment};

            if ( $args{'Encrypt'} ) {
                unlike $mail, qr/$content/, "outgoing $type is not in plaintext";
                my $entity = RT::Test::parse_mail($mail);
                my @res = RT::Crypt->VerifyDecrypt(Entity => $entity);
                like $res[0]{'status'}, qr/DECRYPTION_OKAY/, "Decrypts OK";
                like $entity->as_string, qr/$content/, "outgoing decrypts to contain $type content";
            } else {
                like $mail, qr/$content/, "outgoing $type was not encrypted";
            }

            next unless $type eq 'email';

            if ( $args{'Sign'} && $args{'Encrypt'} ) {
                like $mail, qr/BEGIN PGP MESSAGE/, 'outgoing email was signed';
            } elsif ( $args{'Sign'} ) {
                like $mail, qr/SIGNATURE/, 'outgoing email was signed';
            } else {
                unlike $mail, qr/SIGNATURE/, 'outgoing email was not signed';
            }
        }
    }
}

sub cleanup_headers {
    my $mail = shift;
    # strip id from subject to create new ticket
    $mail =~ s/^(Subject:)\s*\[.*?\s+#\d+\]\s*/$1 /m;
    # strip several headers
    foreach my $field ( qw(Message-ID RT-Originator RT-Ticket X-RT-Loop-Prevention) ) {
        $mail =~ s/^$field:.*?\n(?! |\t)//gmsi;
    }
    return $mail;
}

sub set_queue_crypt_options {
    my $queue = shift;
    my %args = @_;
    $queue->SetEncrypt($args{'Encrypt'});
    $queue->SetSign($args{'Sign'});
}

sub send_email_and_check_transaction {
    my $mail = shift;
    my $type = shift;

    my ( $status, $id ) = RT::Test->send_via_mailgate($mail);
    is( $status >> 8, 0, "The mail gateway exited normally" );
    ok( $id, "got id of a newly created ticket - $id" );

    my $tick = RT::Ticket->new( RT->SystemUser );
    $tick->Load($id);
    ok( $tick->id, "loaded ticket #$id" );

    my $txn = $tick->Transactions->First;
    my ( $msg, @attachments ) = @{ $txn->Attachments->ItemsArrayRef };

    if ( $attachments[0] ) {
        like $attachments[0]->Content, qr/Some content/,
          "RT's mail includes copy of ticket text";
    }
    else {
        like $msg->Content, qr/Some content/,
          "RT's mail includes copy of ticket text";
    }

    if ( $type eq 'plain' ) {
        ok !$msg->GetHeader('X-RT-Privacy'), "RT's outgoing mail has no crypto";
        is $msg->GetHeader('X-RT-Incoming-Encryption'), 'Not encrypted',
          "RT's outgoing mail looks not encrypted";
        ok !$msg->GetHeader('X-RT-Incoming-Signature'),
          "RT's outgoing mail looks not signed";
    }
    elsif ( $type eq 'signed' ) {
        is $msg->GetHeader('X-RT-Privacy'), 'GnuPG',
          "RT's outgoing mail has crypto";
        is $msg->GetHeader('X-RT-Incoming-Encryption'), 'Not encrypted',
          "RT's outgoing mail looks not encrypted";
        like $msg->GetHeader('X-RT-Incoming-Signature'),
          qr/<rt-recipient\@example.com>/,
          "RT's outgoing mail looks signed";
    }
    elsif ( $type eq 'encrypted' ) {
        is $msg->GetHeader('X-RT-Privacy'), 'GnuPG',
          "RT's outgoing mail has crypto";
        is $msg->GetHeader('X-RT-Incoming-Encryption'), 'Success',
          "RT's outgoing mail looks encrypted";
        ok !$msg->GetHeader('X-RT-Incoming-Signature'),
          "RT's outgoing mail looks not signed";

    }
    elsif ( $type eq 'signed_encrypted' ) {
        is $msg->GetHeader('X-RT-Privacy'), 'GnuPG',
          "RT's outgoing mail has crypto";
        is $msg->GetHeader('X-RT-Incoming-Encryption'), 'Success',
          "RT's outgoing mail looks encrypted";
        like $msg->GetHeader('X-RT-Incoming-Signature'),
          qr/<rt-recipient\@example.com>/,
          "RT's outgoing mail looks signed";
    }
    else {
        die "unknown type: $type";
    }
}

sub create_and_test_outgoing_emails {
    my $queue = shift;
    my $m     = shift;
    my @variants =
      ( {}, { Sign => 1 }, { Encrypt => 1 }, { Sign => 1, Encrypt => 1 }, );

    # collect emails
    my %mail;

    # create a ticket for each combination
    foreach my $ticket_set (@variants) {
        create_a_ticket( $queue, \%mail, $m, %$ticket_set );
    }

    my $tid;
    {
        my $ticket = RT::Ticket->new( RT->SystemUser );
        ($tid) = $ticket->Create(
            Subject   => 'test',
            Queue     => $queue->id,
            Requestor => 'rt-test@example.com',
        );
        ok $tid, 'ticket created';
    }

    # again for each combination add a reply message
    foreach my $ticket_set (@variants) {
        update_ticket( $tid, \%mail, $m, %$ticket_set );
    }

# ------------------------------------------------------------------------------
# now delete all keys from the keyring and put back secret/pub pair for rt-test@
# and only public key for rt-recipient@ so we can verify signatures and decrypt
# like we are on another side recieve emails
# ------------------------------------------------------------------------------

    unlink $_
      foreach glob( RT->Config->Get('GnuPGOptions')->{'homedir'} . "/*" );
    RT::Test->import_gnupg_key( 'rt-recipient@example.com', 'public' );
    RT::Test->import_gnupg_key('rt-test@example.com');

    $queue = RT::Test->load_or_create_queue(
        Name              => 'Regression',
        CorrespondAddress => 'rt-test@example.com',
        CommentAddress    => 'rt-test@example.com',
    );
    ok $queue && $queue->id, 'changed props of the queue';

    for my $type ( keys %mail ) {
        for my $mail ( map cleanup_headers($_), @{ $mail{$type} } ) {
            send_email_and_check_transaction( $mail, $type );
        }
    }
}

sub copy_test_keyring_to_homedir {
    my (%args) = @_;
    my $srcdir;
    if ($using_legacy_gnupg || $args{use_legacy_keys}) {
        $srcdir =
            RT::Test::get_abs_relocatable_dir( File::Spec->updir(),
                                               qw/data gnupg keyrings/ );
    }
    else {
        $srcdir =
            RT::Test::get_abs_relocatable_dir( File::Spec->updir(),
                                               qw/data gnupg2 keyrings/ );
    }
    opendir(my $DIR, $srcdir) || die "can't opendir $srcdir: $!";
    my @files = readdir($DIR);
    foreach my $file (@files) {
        if(-f "$srcdir/$file" ) {
            copy "$srcdir/$file", "$homedir/$file";
        }
    }
    closedir($DIR);
}

sub copy_test_keys_to_homedir {
    my (%args) = @_;
    my $srcdir;
    if ($using_legacy_gnupg || $args{use_legacy_keys}) {
        $srcdir =
            RT::Test::get_abs_relocatable_dir( File::Spec->updir(),
                                               qw/data gnupg keys/ );
    }
    else {
        $srcdir =
            RT::Test::get_abs_relocatable_dir( File::Spec->updir(),
                                               qw/data gnupg2 keys/ );
    }

    opendir(my $DIR, $srcdir) || die "can't opendir $srcdir: $!";
    my @files = readdir($DIR);
    foreach my $file (@files) {
        if(-f "$srcdir/$file" ) {
            copy "$srcdir/$file", "$homedir/$file";
        }
    }
    closedir($DIR);
}

sub get_test_data_dir {
    my (%args) = @_;
    my $test_data_dir;
    if ($using_legacy_gnupg || $args{use_legacy_keys}) {
        $test_data_dir = RT::Test::get_abs_relocatable_dir( File::Spec->updir(),
                                                        qw(data gnupg keyrings) );

    }
    else {
        $test_data_dir = RT::Test::get_abs_relocatable_dir( File::Spec->updir(),
                                                            qw(data gnupg2 keyrings) );

    }
    return $test_data_dir;

}

sub get_test_gnupg_interface {
    my $gnupg = GnuPG::Interface->new;
    $gnupg->options->hash_init(
       RT::Crypt::GnuPG::_PrepareGnuPGOptions( ),
    );
    return $gnupg;
}

1;
