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

# Portions Copyright 2000 Tobias Brox <tobix@cpan.org>

package RT::Action::SendEmail;

use strict;
use warnings;

use base qw(RT::Action);

use RT::EmailParser;
use RT::Interface::Email;
use Email::Address;
use List::MoreUtils qw(uniq);
our @EMAIL_RECIPIENT_HEADERS = qw(To Cc Bcc);


=head1 NAME

RT::Action::SendEmail - An Action which users can use to send mail 
or can subclassed for more specialized mail sending behavior. 
RT::Action::AutoReply is a good example subclass.

=head1 SYNOPSIS

  use base 'RT::Action::SendEmail';

=head1 DESCRIPTION

Basically, you create another module RT::Action::YourAction which ISA
RT::Action::SendEmail.

=head1 METHODS

=head2 CleanSlate

Cleans class-wide options, like L</AttachTickets>.

=cut

sub CleanSlate {
    my $self = shift;
    $self->AttachTickets(undef);
}

=head2 Commit

Sends the prepared message and writes outgoing record into DB if the feature is
activated in the config.

=cut

sub Commit {
    my $self = shift;

    return abs $self->SendMessage( $self->TemplateObj->MIMEObj )
        unless RT->Config->Get('RecordOutgoingEmail');

    $self->DeferDigestRecipients();
    my $message = $self->TemplateObj->MIMEObj;

    my $orig_message;
    $orig_message = $message->dup if RT::Interface::Email::WillSignEncrypt(
        Attachment => $self->TransactionObj->Attachments->First,
        Ticket     => $self->TicketObj,
    );

    my ($ret) = $self->SendMessage($message);
    return abs( $ret ) if $ret <= 0;

    if ($orig_message) {
        $message->attach(
            Type        => 'application/x-rt-original-message',
            Disposition => 'inline',
            Data        => $orig_message->as_string,
        );
    }
    $self->RecordOutgoingMailTransaction($message);
    $self->RecordDeferredRecipients();
    return 1;
}

=head2 Prepare

Builds an outgoing email we're going to send using scrip's template.

=cut

sub Prepare {
    my $self = shift;

    unless ( $self->TemplateObj->MIMEObj ) {
        my ( $result, $message ) = $self->TemplateObj->Parse(
            Argument       => $self->Argument,
            TicketObj      => $self->TicketObj,
            TransactionObj => $self->TransactionObj
        );
        if ( !$result ) {
            return (undef);
        }
    }

    my $MIMEObj = $self->TemplateObj->MIMEObj;

    # Header
    $self->SetRTSpecialHeaders();

    my %seen;
    foreach my $type (@EMAIL_RECIPIENT_HEADERS) {
        @{ $self->{$type} }
            = grep defined && length && !$seen{ lc $_ }++,
            @{ $self->{$type} };
    }

    $self->RemoveInappropriateRecipients();

    # Go add all the Tos, Ccs and Bccs that we need to to the message to
    # make it happy, but only if we actually have values in those arrays.

# TODO: We should be pulling the recipients out of the template and shove them into To, Cc and Bcc

    for my $header (@EMAIL_RECIPIENT_HEADERS) {

        $self->SetHeader( $header, join( ', ', @{ $self->{$header} } ) )
          if (!$MIMEObj->head->get($header)
            && $self->{$header}
            && @{ $self->{$header} } );
    }
    # PseudoTo (fake to headers) shouldn't get matched for message recipients.
    # If we don't have any 'To' header (but do have other recipients), drop in
    # the pseudo-to header.
    $self->SetHeader( 'To', join( ', ', @{ $self->{'PseudoTo'} } ) )
        if $self->{'PseudoTo'}
            && @{ $self->{'PseudoTo'} }
            && !$MIMEObj->head->get('To')
            && ( $MIMEObj->head->get('Cc') or $MIMEObj->head->get('Bcc') );

    # For security reasons, we only send out textual mails.
    foreach my $part ( grep !$_->is_multipart, $MIMEObj->parts_DFS ) {
        my $type = $part->mime_type || 'text/plain';
        $type = 'text/plain' unless RT::I18N::IsTextualContentType($type);
        $part->head->mime_attr( "Content-Type" => $type );
        # utf-8 here is for _FindOrGuessCharset in I18N.pm
        # it's not the final charset/encoding sent
        $part->head->mime_attr( "Content-Type.charset" => 'utf-8' );
    }

    RT::I18N::SetMIMEEntityToEncoding(
        Entity        => $MIMEObj,
        Encoding      => RT->Config->Get('EmailOutputEncoding'),
        PreserveWords => 1,
        IsOut         => 1,
    );

    # Build up a MIME::Entity that looks like the original message.
    $self->AddAttachments if ( $MIMEObj->head->get('RT-Attach-Message')
                               && ( $MIMEObj->head->get('RT-Attach-Message') !~ /^(n|no|0|off|false)$/i ) );

    $self->AddTickets;

    my $attachment = $self->TransactionObj->Attachments->First;
    if ($attachment
        && !(
               $attachment->GetHeader('X-RT-Encrypt')
            || $self->TicketObj->QueueObj->Encrypt
        )
        )
    {
        $attachment->SetHeader( 'X-RT-Encrypt' => 1 )
            if ( $attachment->GetHeader("X-RT-Incoming-Encryption") || '' ) eq
            'Success';
    }

    return 1;
}

=head2 To

Returns an array of L<Email::Address> objects containing all the To: recipients for this notification

=cut

sub To {
    my $self = shift;
    return ( $self->AddressesFromHeader('To') );
}

=head2 Cc

Returns an array of L<Email::Address> objects containing all the Cc: recipients for this notification

=cut

sub Cc {
    my $self = shift;
    return ( $self->AddressesFromHeader('Cc') );
}

=head2 Bcc

Returns an array of L<Email::Address> objects containing all the Bcc: recipients for this notification

=cut

sub Bcc {
    my $self = shift;
    return ( $self->AddressesFromHeader('Bcc') );

}

sub AddressesFromHeader {
    my $self      = shift;
    my $field     = shift;
    my $header    = Encode::decode("UTF-8",$self->TemplateObj->MIMEObj->head->get($field));
    my @addresses = Email::Address->parse($header);

    return (@addresses);
}

=head2 SendMessage MIMEObj

sends the message using RT's preferred API.
TODO: Break this out to a separate module

=cut

sub SendMessage {

    # DO NOT SHIFT @_ in this subroutine.  It breaks Hook::LexWrap's
    # ability to pass @_ to a 'post' routine.
    my ( $self, $MIMEObj ) = @_;

    my $msgid = Encode::decode( "UTF-8", $MIMEObj->head->get('Message-ID') );
    chomp $msgid;

    $self->ScripActionObj->{_Message_ID}++;

    $RT::Logger->info( $msgid . " #"
            . $self->TicketObj->id . "/"
            . $self->TransactionObj->id
            . " - Scrip "
            . ($self->ScripObj->id || '#rule'). " "
            . ( $self->ScripObj->Description || '' ) );

    my $status = RT::Interface::Email::SendEmail(
        Entity      => $MIMEObj,
        Ticket      => $self->TicketObj,
        Transaction => $self->TransactionObj,
    );

     
    return $status unless ($status > 0 || exists $self->{'Deferred'});

    my $success = $msgid . " sent ";
    foreach (@EMAIL_RECIPIENT_HEADERS) {
        my $recipients = Encode::decode( "UTF-8", $MIMEObj->head->get($_) );
        $success .= " $_: " . $recipients if $recipients;
    }

    if( exists $self->{'Deferred'} ) {
        for (qw(daily weekly susp)) {
            $success .= "\nBatched email $_ for: ". join(", ", keys %{ $self->{'Deferred'}{ $_ } } )
                if exists $self->{'Deferred'}{ $_ };
        }
    }

    $success =~ s/\n//g;

    $RT::Logger->info($success);

    return (1);
}

=head2 AttachableFromTransaction

Function (not method) that takes an L<RT::Transaction> and returns an
L<RT::Attachments> collection of attachments suitable for attaching to an
email.

=cut

sub AttachableFromTransaction {
    my $txn = shift;

    my $attachments = RT::Attachments->new( RT->SystemUser );
    $attachments->Limit(
        FIELD => 'TransactionId',
        VALUE => $txn->Id
    );

    # Don't attach anything blank
    $attachments->LimitNotEmpty;
    $attachments->OrderBy( FIELD => 'id' );

    # We want to make sure that we don't include the attachment that's
    # being used as the "Content" of this message" unless that attachment's
    # content type is not like text/...
    my $transaction_content_obj = $txn->ContentObj;

    if (   $transaction_content_obj
        && $transaction_content_obj->ContentType =~ m{text/}i )
    {
        # If this was part of a multipart/alternative, skip all of the kids
        my $parent = $transaction_content_obj->ParentObj;
        if ($parent and $parent->Id and $parent->ContentType eq "multipart/alternative") {
            $attachments->Limit(
                ENTRYAGGREGATOR => 'AND',
                FIELD           => 'parent',
                OPERATOR        => '!=',
                VALUE           => $parent->Id,
            );
        } else {
            $attachments->Limit(
                ENTRYAGGREGATOR => 'AND',
                FIELD           => 'id',
                OPERATOR        => '!=',
                VALUE           => $transaction_content_obj->Id,
            );
        }
    }

    return $attachments;
}

=head2 AddAttachments

Takes any attachments to this transaction and attaches them to the message
we're building.

=cut

sub AddAttachments {
    my $self = shift;

    my $MIMEObj = $self->TemplateObj->MIMEObj;

    $MIMEObj->head->delete('RT-Attach-Message');

    my $attachments = AttachableFromTransaction($self->TransactionObj);

    # attach any of this transaction's attachments
    my $seen_attachment = 0;
    while ( my $attach = $attachments->Next ) {
        if ( !$seen_attachment ) {
            $MIMEObj->make_multipart( 'mixed', Force => 1 );
            $seen_attachment = 1;
        }
        $self->AddAttachment($attach);
    }

    # attach any attachments requested by the transaction or template
    # that aren't part of the transaction itself
    $self->AddAttachmentsFromHeaders;
}

=head2 AddAttachmentsFromHeaders

Add attachments requested by the transaction or template that aren't part of
the transaction itself.

This inspects C<RT-Attach> headers, which are expected to contain an
L<RT::Attachment> ID that the transaction's creator can See.

L<RT::Ticket->_RecordNote> accepts an C<AttachExisting> argument which sets
C<RT-Attach> headers appropriately on Comment/Correspond.

=cut

sub AddAttachmentsFromHeaders {
    my $self  = shift;
    my $email = $self->TemplateObj->MIMEObj;

    # Add the RT-Attach headers from the transaction to the email
    if (my $attachment = $self->TransactionObj->Attachments->First) {
        for my $id ($attachment->GetAllHeaders('RT-Attach')) {
            $email->head->add('RT-Attach' => $id);
        }
    }

    # Take all RT-Attach headers and add the attachments to the outgoing mail
    for my $id (uniq $email->head->get_all('RT-Attach')) {
        $id =~ s/(?:^\s*|\s*$)//g;

        my $attach = RT::Attachment->new( $self->TransactionObj->CreatorObj );
        $attach->Load($id);
        next unless $attach->Id
                and $attach->TransactionObj->CurrentUserCanSee;

        $email->make_multipart( 'mixed', Force => 1 )
          unless $email->effective_type eq 'multipart/mixed';
        $self->AddAttachment($attach, $email);
    }
}

=head2 AddAttachment $attachment

Takes one attachment object of L<RT::Attachment> class and attaches it to the message
we're building.

=cut

sub AddAttachment {
    my $self    = shift;
    my $attach  = shift;
    my $MIMEObj = shift || $self->TemplateObj->MIMEObj;

    # $attach->TransactionObj may not always be $self->TransactionObj
    return unless $attach->Id
              and $attach->TransactionObj->CurrentUserCanSee;

    # ->attach expects just the disposition type; extract it if we have the header
    # or default to "attachment"
    my $disp = ($attach->GetHeader('Content-Disposition') || '')
                    =~ /^\s*(inline|attachment)/i ? $1 : "attachment";

    $MIMEObj->attach(
        Type        => $attach->ContentType,
        Charset     => $attach->OriginalEncoding,
        Data        => $attach->OriginalContent,
        Disposition => $disp,
        Filename    => $self->MIMEEncodeString( $attach->Filename ),
        Id          => $attach->GetHeader('Content-ID'),
        'RT-Attachment:' => $self->TicketObj->Id . "/"
            . $self->TransactionObj->Id . "/"
            . $attach->id,
        Encoding => '-SUGGEST',
    );
}

=head2 AttachTickets [@IDs]

Returns or set list of ticket's IDs that should be attached to an outgoing message.

B<Note> this method works as a class method and setup things global, so you have to
clean list by passing undef as argument.

=cut

{
    my $list = [];

    sub AttachTickets {
        my $self = shift;
        $list = [ grep defined, @_ ] if @_;
        return @$list;
    }
}

=head2 AddTickets

Attaches tickets to the current message, list of tickets' ids get from
L</AttachTickets> method.

=cut

sub AddTickets {
    my $self = shift;
    $self->AddTicket($_) foreach $self->AttachTickets;
    return;
}

=head2 AddTicket $ID

Attaches a ticket with ID to the message.

Each ticket is attached as multipart entity and all its messages and attachments
are attached as sub entities in order of creation, but only if transaction type
is Create or Correspond.

=cut

sub AddTicket {
    my $self = shift;
    my $tid  = shift;

    my $attachs   = RT::Attachments->new( $self->TransactionObj->CreatorObj );
    my $txn_alias = $attachs->TransactionAlias;
    $attachs->Limit(
        ALIAS    => $txn_alias,
        FIELD    => 'Type',
        OPERATOR => 'IN',
        VALUE    => [qw(Create Correspond)],
    );
    $attachs->LimitByTicket($tid);
    $attachs->LimitNotEmpty;
    $attachs->OrderBy( FIELD => 'Created' );

    my $ticket_mime = MIME::Entity->build(
        Type        => 'multipart/mixed',
        Top         => 0,
        Description => "ticket #$tid",
    );
    while ( my $attachment = $attachs->Next ) {
        $self->AddAttachment( $attachment, $ticket_mime );
    }
    if ( $ticket_mime->parts ) {
        my $email_mime = $self->TemplateObj->MIMEObj;
        $email_mime->make_multipart;
        $email_mime->add_part($ticket_mime);
    }
    return;
}

=head2 RecordOutgoingMailTransaction MIMEObj

Record a transaction in RT with this outgoing message for future record-keeping purposes

=cut

sub RecordOutgoingMailTransaction {
    my $self    = shift;
    my $MIMEObj = shift;

    my @parts = $MIMEObj->parts;
    my @attachments;
    my @keep;
    foreach my $part (@parts) {
        my $attach = $part->head->get('RT-Attachment');
        if ($attach) {
            $RT::Logger->debug(
                "We found an attachment. we want to not record it.");
            push @attachments, $attach;
        } else {
            $RT::Logger->debug("We found a part. we want to record it.");
            push @keep, $part;
        }
    }
    $MIMEObj->parts( \@keep );
    foreach my $attachment (@attachments) {
        $MIMEObj->head->add( 'RT-Attachment', $attachment );
    }

    RT::I18N::SetMIMEEntityToEncoding( $MIMEObj, 'utf-8', 'mime_words_ok' );

    my $transaction
        = RT::Transaction->new( $self->TransactionObj->CurrentUser );

# XXX: TODO -> Record attachments as references to things in the attachments table, maybe.

    my $type;
    if ( $self->TransactionObj->Type eq 'Comment' ) {
        $type = 'CommentEmailRecord';
    } else {
        $type = 'EmailRecord';
    }

    my $msgid = Encode::decode( "UTF-8", $MIMEObj->head->get('Message-ID') );
    chomp $msgid;

    my ( $id, $msg ) = $transaction->Create(
        Ticket         => $self->TicketObj->Id,
        Type           => $type,
        Data           => $msgid,
        MIMEObj        => $MIMEObj,
        ActivateScrips => 0
    );

    if ($id) {
        $self->{'OutgoingMailTransaction'} = $id;
    } else {
        $RT::Logger->warning(
            "Could not record outgoing message transaction: $msg");
    }
    return $id;
}

=head2 SetRTSpecialHeaders 

This routine adds all the random headers that RT wants in a mail message
that don't matter much to anybody else.

=cut

sub SetRTSpecialHeaders {
    my $self = shift;

    $self->SetSubject();
    $self->SetSubjectToken();
    $self->SetHeaderAsEncoding( 'Subject',
        RT->Config->Get('EmailOutputEncoding') )
        if ( RT->Config->Get('EmailOutputEncoding') );
    $self->SetReturnAddress();
    $self->SetReferencesHeaders();

    unless ( $self->TemplateObj->MIMEObj->head->get('Message-ID') ) {

        # Get Message-ID for this txn
        my $msgid = "";
        if ( my $msg = $self->TransactionObj->Message->First ) {
            $msgid = $msg->GetHeader("RT-Message-ID")
                || $msg->GetHeader("Message-ID");
        }

        # If there is one, and we can parse it, then base our Message-ID on it
        if (    $msgid
            and $msgid
            =~ s/<(rt-.*?-\d+-\d+)\.(\d+)-\d+-\d+\@\QRT->Config->Get('Organization')\E>$/
                         "<$1." . $self->TicketObj->id
                          . "-" . $self->ScripObj->id
                          . "-" . $self->ScripActionObj->{_Message_ID}
                          . "@" . RT->Config->Get('Organization') . ">"/eg
            and $2 == $self->TicketObj->id
            )
        {
            $self->SetHeader( "Message-ID" => $msgid );
        } else {
            $self->SetHeader(
                'Message-ID' => RT::Interface::Email::GenMessageId(
                    Ticket      => $self->TicketObj,
                    Scrip       => $self->ScripObj,
                    ScripAction => $self->ScripActionObj
                ),
            );
        }
    }

    $self->SetHeader( 'X-RT-Loop-Prevention', RT->Config->Get('rtname') );
    $self->SetHeader( 'X-RT-Ticket',
        RT->Config->Get('rtname') . " #" . $self->TicketObj->id() );
    $self->SetHeader( 'X-Managed-by',
        "RT $RT::VERSION (http://www.bestpractical.com/rt/)" );

# XXX, TODO: use /ShowUser/ShowUserEntry(or something like that) when it would be
#            refactored into user's method.
    if ( my $email = $self->TransactionObj->CreatorObj->EmailAddress
         and ! defined $self->TemplateObj->MIMEObj->head->get("RT-Originator")
         and RT->Config->Get('UseOriginatorHeader')
    ) {
        $self->SetHeader( 'X-RT-Originator', $email );
    }

}


sub DeferDigestRecipients {
    my $self = shift;
    $RT::Logger->debug( "Calling SetRecipientDigests for transaction " . $self->TransactionObj . ", id " . $self->TransactionObj->id );

    # The digest attribute will be an array of notifications that need to
    # be sent for this transaction.  The array will have the following
    # format for its objects.
    # $digest_hash -> {daily|weekly|susp} -> address -> {To|Cc|Bcc}
    #                                     -> sent -> {true|false}
    # The "sent" flag will be used by the cron job to indicate that it has
    # run on this transaction.
    # In a perfect world we might move this hash construction to the
    # extension module itself.
    my $digest_hash = {};

    foreach my $mailfield (@EMAIL_RECIPIENT_HEADERS) {
        # If we have a "PseudoTo", the "To" contains it, so we don't need to access it
        next if ( ( $self->{'PseudoTo'} && @{ $self->{'PseudoTo'} } ) && ( $mailfield eq 'To' ) );
        $RT::Logger->debug( "Working on mailfield $mailfield; recipients are " . join( ',', @{ $self->{$mailfield} } ) );

        # Store the 'daily digest' folk in an array.
        my ( @send_now, @daily_digest, @weekly_digest, @suspended );

        # Have to get the list of addresses directly from the MIME header
        # at this point.
        $RT::Logger->debug( Encode::decode( "UTF-8", $self->TemplateObj->MIMEObj->head->as_string ) );
        foreach my $rcpt ( map { $_->address } $self->AddressesFromHeader($mailfield) ) {
            next unless $rcpt;
            my $user_obj = RT::User->new(RT->SystemUser);
            $user_obj->LoadByEmail($rcpt);
            if  ( ! $user_obj->id ) {
                # If there's an email address in here without an associated
                # RT user, pass it on through.
                $RT::Logger->debug( "User $rcpt is not associated with an RT user object.  Send mail.");
                push( @send_now, $rcpt );
                next;
            }

            my $mailpref = RT->Config->Get( 'EmailFrequency', $user_obj ) || '';
            $RT::Logger->debug( "Got user mail preference '$mailpref' for user $rcpt");

            if ( $mailpref =~ /daily/i ) { push( @daily_digest, $rcpt ) }
            elsif ( $mailpref =~ /weekly/i ) { push( @weekly_digest, $rcpt ) }
            elsif ( $mailpref =~ /suspend/i ) { push( @suspended, $rcpt ) }
            else { push( @send_now, $rcpt ) }
        }

        # Reset the relevant mail field.
        $RT::Logger->debug( "Removing deferred recipients from $mailfield: line");
        if (@send_now) {
            $self->SetHeader( $mailfield, join( ', ', @send_now ) );
        } else {    # No recipients!  Remove the header.
            $self->TemplateObj->MIMEObj->head->delete($mailfield);
        }

        # Push the deferred addresses into the appropriate field in
        # our attribute hash, with the appropriate mail header.
        $RT::Logger->debug(
            "Setting deferred recipients for attribute creation");
        $digest_hash->{'daily'}->{$_} = {'header' => $mailfield , _sent => 0}  for (@daily_digest);
        $digest_hash->{'weekly'}->{$_} ={'header' =>  $mailfield, _sent => 0}  for (@weekly_digest);
        $digest_hash->{'susp'}->{$_} = {'header' => $mailfield, _sent =>0 }  for (@suspended);
    }

    if ( scalar keys %$digest_hash ) {

        # Save the hash so that we can add it as an attribute to the
        # outgoing email transaction.
        $self->{'Deferred'} = $digest_hash;
    } else {
        $RT::Logger->debug( "No recipients found for deferred delivery on "
                . "transaction #"
                . $self->TransactionObj->id );
    }
}


    
sub RecordDeferredRecipients {
    my $self = shift;
    return unless exists $self->{'Deferred'};

    my $txn_id = $self->{'OutgoingMailTransaction'};
    return unless $txn_id;

    my $txn_obj = RT::Transaction->new( $self->CurrentUser );
    $txn_obj->Load( $txn_id );
    my( $ret, $msg ) = $txn_obj->AddAttribute(
        Name => 'DeferredRecipients',
        Content => $self->{'Deferred'}
    );
    $RT::Logger->warning( "Unable to add deferred recipients to outgoing transaction: $msg" ) 
        unless $ret;

    return ($ret,$msg);
}

=head2 SquelchMailTo

Returns list of the addresses to squelch on this transaction.

=cut

sub SquelchMailTo {
    my $self = shift;
    return map $_->Content, $self->TransactionObj->SquelchMailTo;
}

=head2 RemoveInappropriateRecipients

Remove addresses that are RT addresses or that are on this transaction's blacklist

=cut

my %squelch_reasons = (
    'not privileged'
        => "because autogenerated messages are configured to only be sent to privileged users (RedistributeAutoGeneratedMessages)",
    'squelch:attachment'
        => "by RT-Squelch-Replies-To header in the incoming message",
    'squelch:transaction'
        => "by notification checkboxes for this transaction",
    'squelch:ticket'
        => "by notification checkboxes on this ticket's People page",
);


sub RemoveInappropriateRecipients {
    my $self = shift;

    my %blacklist = ();

    # If there are no recipients, don't try to send the message.
    # If the transaction has content and has the header RT-Squelch-Replies-To

    my $msgid = Encode::decode( "UTF-8", $self->TemplateObj->MIMEObj->head->get('Message-Id') );
    chomp $msgid;

    if ( my $attachment = $self->TransactionObj->Attachments->First ) {

        if ( $attachment->GetHeader('RT-DetectedAutoGenerated') ) {

            # What do we want to do with this? It's probably (?) a bounce
            # caused by one of the watcher addresses being broken.
            # Default ("true") is to redistribute, for historical reasons.

            my $redistribute = RT->Config->Get('RedistributeAutoGeneratedMessages');

            if ( !$redistribute ) {

                # Don't send to any watchers.
                @{ $self->{$_} } = () for (@EMAIL_RECIPIENT_HEADERS);
                $RT::Logger->info( $msgid
                        . " The incoming message was autogenerated. "
                        . "Not redistributing this message based on site configuration."
                );
            } elsif ( $redistribute eq 'privileged' ) {

                # Only send to "privileged" watchers.
                foreach my $type (@EMAIL_RECIPIENT_HEADERS) {
                    foreach my $addr ( @{ $self->{$type} } ) {
                        my $user = RT::User->new(RT->SystemUser);
                        $user->LoadByEmail($addr);
                        $blacklist{ $addr } ||= 'not privileged'
                            unless $user->id && $user->Privileged;
                    }
                }
                $RT::Logger->info( $msgid
                        . " The incoming message was autogenerated. "
                        . "Not redistributing this message to unprivileged users based on site configuration."
                );
            }
        }

        if ( my $squelch = $attachment->GetHeader('RT-Squelch-Replies-To') ) {
            $blacklist{ $_->address } ||= 'squelch:attachment'
                foreach Email::Address->parse( $squelch );
        }
    }

    # Let's grab the SquelchMailTo attributes and push those entries
    # into the blacklisted
    $blacklist{ $_->Content } ||= 'squelch:transaction'
        foreach $self->TransactionObj->SquelchMailTo;
    $blacklist{ $_->Content } ||= 'squelch:ticket'
        foreach $self->TicketObj->SquelchMailTo;

    # canonicalize emails
    foreach my $address ( keys %blacklist ) {
        my $reason = delete $blacklist{ $address };
        $blacklist{ lc $_ } = $reason
            foreach map RT::User->CanonicalizeEmailAddress( $_->address ),
            Email::Address->parse( $address );
    }

    $self->RecipientFilter(
        Callback => sub {
            return unless RT::EmailParser->IsRTAddress( $_[0] );
            return "$_[0] appears to point to this RT instance. Skipping";
        },
        All => 1,
    );

    $self->RecipientFilter(
        Callback => sub {
            return unless $blacklist{ lc $_[0] };
            return "$_[0] is blacklisted $squelch_reasons{ $blacklist{ lc $_[0] } }. Skipping";
        },
    );


    # Cycle through the people we're sending to and pull out anyone that meets any of the callbacks
    for my $type (@EMAIL_RECIPIENT_HEADERS) {
        my @addrs;

      ADDRESS:
        for my $addr ( @{ $self->{$type} } ) {
            for my $filter ( map {$_->{Callback}} @{$self->{RecipientFilter}} ) {
                my $skip = $filter->($addr);
                next unless $skip;
                $RT::Logger->info( "$msgid $skip" );
                next ADDRESS;
            }
            push @addrs, $addr;
        }

      NOSQUELCH_ADDRESS:
        for my $addr ( @{ $self->{NoSquelch}{$type} } ) {
            for my $filter ( map {$_->{Callback}} grep {$_->{All}} @{$self->{RecipientFilter}} ) {
                my $skip = $filter->($addr);
                next unless $skip;
                $RT::Logger->info( "$msgid $skip" );
                next NOSQUELCH_ADDRESS;
            }
            push @addrs, $addr;
        }

        @{ $self->{$type} } = @addrs;
    }
}

=head2 RecipientFilter Callback => SUB, [All => 1]

Registers a filter to be applied to addresses by
L<RemoveInappropriateRecipients>.  The C<Callback> will be called with
one address at a time, and should return false if the address should
receive mail, or a message explaining why it should not be.  Passing a
true value for C<All> will cause the filter to also be applied to
NoSquelch (one-time Cc and Bcc) recipients as well.

=cut

sub RecipientFilter {
    my $self = shift;
    push @{ $self->{RecipientFilter}}, {@_};
}

=head2 SetReturnAddress is_comment => BOOLEAN

Calculate and set From and Reply-To headers based on the is_comment flag.

=cut

sub SetReturnAddress {

    my $self = shift;
    my %args = (
        is_comment => 0,
        friendly_name => undef,
        @_
    );

    # From and Reply-To
    # $args{is_comment} should be set if the comment address is to be used.
    my $replyto;

    if ( $args{'is_comment'} ) {
        $replyto = $self->TicketObj->QueueObj->CommentAddress
            || RT->Config->Get('CommentAddress');
    } else {
        $replyto = $self->TicketObj->QueueObj->CorrespondAddress
            || RT->Config->Get('CorrespondAddress');
    }

    unless ( $self->TemplateObj->MIMEObj->head->get('From') ) {
        $self->SetFrom( %args, From => $replyto );
    }

    unless ( $self->TemplateObj->MIMEObj->head->get('Reply-To') ) {
        $self->SetHeader( 'Reply-To', "$replyto" );
    }

}

=head2 SetFrom ( From => emailaddress )

Set the From: address for outgoing email

=cut

sub SetFrom {
    my $self = shift;
    my %args = @_;

    if ( RT->Config->Get('UseFriendlyFromLine') ) {
        my $friendly_name = $self->GetFriendlyName(%args);
        $self->SetHeader(
            'From',
            sprintf(
                RT->Config->Get('FriendlyFromLineFormat'),
                $self->MIMEEncodeString(
                    $friendly_name, RT->Config->Get('EmailOutputEncoding')
                ),
                $args{From}
            ),
        );
    } else {
        $self->SetHeader( 'From', $args{From} );
    }
}

=head2 GetFriendlyName

Calculate the proper Friendly Name based on the creator of the transaction

=cut

sub GetFriendlyName {
    my $self = shift;
    my %args = (
        is_comment => 0,
        friendly_name => '',
        @_
    );
    my $friendly_name = $args{friendly_name};

    unless ( $friendly_name ) {
        $friendly_name = $self->TransactionObj->CreatorObj->FriendlyName;
        if ( $friendly_name =~ /^"(.*)"$/ ) {    # a quoted string
            $friendly_name = $1;
        }
    }

    $friendly_name =~ s/"/\\"/g;
    return $friendly_name;

}

=head2 SetHeader FIELD, VALUE

Set the FIELD of the current MIME object into VALUE, which should be in
characters, not bytes.  Returns the new header, in bytes.

=cut

sub SetHeader {
    my $self  = shift;
    my $field = shift;
    my $val   = shift;

    chomp $val;
    chomp $field;
    my $head = $self->TemplateObj->MIMEObj->head;
    $head->fold_length( $field, 10000 );
    $head->replace( $field, Encode::encode( "UTF-8", $val ) );
    return $head->get($field);
}

=head2 SetSubject

This routine sets the subject. it does not add the rt tag. That gets done elsewhere
If subject is already defined via template, it uses that. otherwise, it tries to get
the transaction's subject.

=cut 

sub SetSubject {
    my $self = shift;
    my $subject;

    if ( $self->TemplateObj->MIMEObj->head->get('Subject') ) {
        return ();
    }

    # don't use Transaction->Attachments because it caches
    # and anything which later calls ->Attachments will be hurt
    # by our RowsPerPage() call.  caching is hard.
    my $message = RT::Attachments->new( $self->CurrentUser );
    $message->Limit( FIELD => 'TransactionId', VALUE => $self->TransactionObj->id);
    $message->OrderBy( FIELD => 'id', ORDER => 'ASC' );
    $message->RowsPerPage(1);

    if ( $self->{'Subject'} ) {
        $subject = $self->{'Subject'};
    } elsif ( my $first = $message->First ) {
        my $tmp = $first->GetHeader('Subject');
        $subject = defined $tmp ? $tmp : $self->TicketObj->Subject;
    } else {
        $subject = $self->TicketObj->Subject;
    }
    $subject = '' unless defined $subject;
    chomp $subject;

    $subject =~ s/(\r\n|\n|\s)/ /g;

    $self->SetHeader( 'Subject', $subject );

}

=head2 SetSubjectToken

This routine fixes the RT tag in the subject. It's unlikely that you want to overwrite this.

=cut

sub SetSubjectToken {
    my $self = shift;

    my $head = $self->TemplateObj->MIMEObj->head;
    $self->SetHeader(
        Subject =>
            RT::Interface::Email::AddSubjectTag(
                Encode::decode( "UTF-8", $head->get('Subject') ),
                $self->TicketObj,
            ),
    );
}

=head2 SetReferencesHeaders

Set References and In-Reply-To headers for this message.

=cut

sub SetReferencesHeaders {
    my $self = shift;

    my $top = $self->TransactionObj->Message->First;
    unless ( $top ) {
        $self->SetHeader( References => $self->PseudoReference );
        return (undef);
    }

    my @in_reply_to = split( /\s+/m, $top->GetHeader('In-Reply-To') || '' );
    my @references  = split( /\s+/m, $top->GetHeader('References')  || '' );
    my @msgid       = split( /\s+/m, $top->GetHeader('Message-ID')  || '' );

    # There are two main cases -- this transaction was created with
    # the RT Web UI, and hence we want to *not* append its Message-ID
    # to the References and In-Reply-To.  OR it came from an outside
    # source, and we should treat it as per the RFC
    my $org = RT->Config->Get('Organization');
    if ( "@msgid" =~ /<(rt-.*?-\d+-\d+)\.(\d+)-0-0\@\Q$org\E>/ ) {

        # Make all references which are internal be to version which we
        # have sent out

        for ( @references, @in_reply_to ) {
            s/<(rt-.*?-\d+-\d+)\.(\d+-0-0)\@\Q$org\E>$/
          "<$1." . $self->TicketObj->id .
             "-" . $self->ScripObj->id .
             "-" . $self->ScripActionObj->{_Message_ID} .
             "@" . $org . ">"/eg
        }

        # In reply to whatever the internal message was in reply to
        $self->SetHeader( 'In-Reply-To', join( " ", (@in_reply_to) ) );

        # Default the references to whatever we're in reply to
        @references = @in_reply_to unless @references;

        # References are unchanged from internal
    } else {

        # In reply to that message
        $self->SetHeader( 'In-Reply-To', join( " ", (@msgid) ) );

        # Default the references to whatever we're in reply to
        @references = @in_reply_to unless @references;

        # Push that message onto the end of the references
        push @references, @msgid;
    }

    # Push pseudo-ref to the front
    my $pseudo_ref = $self->PseudoReference;
    @references = ( $pseudo_ref, grep { $_ ne $pseudo_ref } @references );

    # If there are more than 10 references headers, remove all but the
    # first four and the last six (Gotta keep this from growing
    # forever)
    splice( @references, 4, -6 ) if ( $#references >= 10 );

    # Add on the references
    $self->SetHeader( 'References', join( " ", @references ) );
    $self->TemplateObj->MIMEObj->head->fold_length( 'References', 80 );

}

=head2 PseudoReference

Returns a fake Message-ID: header for the ticket to allow a base level of threading

=cut

sub PseudoReference {
    my $self = shift;
    return RT::Interface::Email::PseudoReference( $self->TicketObj );
}

=head2 SetHeaderAsEncoding($field_name, $charset_encoding)

This routine converts the field into specified charset encoding, then
applies the MIME-Header transfer encoding.

=cut

sub SetHeaderAsEncoding {
    my $self = shift;
    my ( $field, $enc ) = ( shift, shift );

    my $head = $self->TemplateObj->MIMEObj->head;

    my $value = Encode::decode("UTF-8", $head->get( $field ));
    $value = $self->MIMEEncodeString( $value, $enc ); # Returns bytes
    $head->replace( $field, $value );

}

=head2 MIMEEncodeString

Takes a perl string and optional encoding pass it over
L<RT::Interface::Email/EncodeToMIME>.

Basicly encode a string using B encoding according to RFC2047, returning
bytes.

=cut

sub MIMEEncodeString {
    my $self  = shift;
    return RT::Interface::Email::EncodeToMIME( String => $_[0], Charset => $_[1] );
}

RT::Base->_ImportOverlays();

1;

