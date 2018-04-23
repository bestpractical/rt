# BEGIN BPS TAGGED BLOCK {{{
#
# COPYRIGHT:
#
# This software is Copyright (c) 1996-2018 Best Practical Solutions, LLC
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

our @EXPORT =
  qw(create_a_ticket update_ticket cleanup_headers set_queue_crypt_options 
          check_text_emails send_email_and_check_transaction
          create_and_test_outgoing_emails
          );

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

    RT::Test::diag "GnuPG --homedir " . RT->Config->Get('GnuPGOptions')->{'homedir'};

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

    $m->submit;
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
