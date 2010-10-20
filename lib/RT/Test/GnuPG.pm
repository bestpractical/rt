package RT::Test::GnuPG;
use strict;
use Test::More;
use base qw(Exporter);

our @EXPORT = qw(create_a_ticket update_ticket check_text_emails cleanup_headers set_queue_crypt_options);

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
    check_text_emails($mail, \%args, @mail );
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
    $m->content_contains("Message recorded", 'Message recorded') or diag $m->content;


    my @mail = RT::Test->fetch_caught_mails;
    check_text_emails($mail, \%args, @mail );
}

sub check_text_emails {
    my %mail = %{ shift @_ };
    my %args = %{ shift @_ };
    my @mail = @_;

    ok scalar @mail, "got some mail";
    for my $mail (@mail) {
        if ( $args{'Encrypt'} ) {
            unlike $mail, qr/Some content/, "outgoing email was encrypted";
        } else {
            like $mail, qr/Some content/, "outgoing email was not encrypted";
        } 
        if ( $args{'Sign'} && $args{'Encrypt'} ) {
            like $mail, qr/BEGIN PGP MESSAGE/, 'outgoing email was signed';
        } elsif ( $args{'Sign'} ) {
            like $mail, qr/SIGNATURE/, 'outgoing email was signed';
        } else {
            unlike $mail, qr/SIGNATURE/, 'outgoing email was not signed';
        }
    }
    if ( $args{'Sign'} && $args{'Encrypt'} ) {
        push @{ $mail{'signed_encrypted'} }, @mail;
    } elsif ( $args{'Sign'} ) {
        push @{ $mail{'signed'} }, @mail;
    } elsif ( $args{'Encrypt'} ) {
        push @{ $mail{'encrypted'} }, @mail;
    } else {
        push @{ $mail{'plain'} }, @mail;
    }
}

sub cleanup_headers {
    my $mail = shift;
    # strip id from subject to create new ticket
    $mail =~ s/^(Subject:)\s*\[.*?\s+#\d+\]\s*/$1 /m;
    # strip several headers
    foreach my $field ( qw(Message-ID X-RT-Original-Encoding RT-Originator RT-Ticket X-RT-Loop-Prevention) ) {
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

