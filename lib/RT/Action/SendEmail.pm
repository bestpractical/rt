# {{{ BEGIN BPS TAGGED BLOCK
# 
# COPYRIGHT:
#  
# This software is Copyright (c) 1996-2004 Best Practical Solutions, LLC 
#                                          <jesse@bestpractical.com>
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
# Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
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
# }}} END BPS TAGGED BLOCK
# Portions Copyright 2000 Tobias Brox <tobix@cpan.org>

package RT::Action::SendEmail;
require RT::Action::Generic;

use strict;
use vars qw/@ISA/;
@ISA = qw(RT::Action::Generic);

use MIME::Words qw(encode_mimeword);

use RT::EmailParser;
use Mail::Address;

=head1 NAME

RT::Action::SendEmail - An Action which users can use to send mail 
or can subclassed for more specialized mail sending behavior. 
RT::Action::AutoReply is a good example subclass.

=head1 SYNOPSIS

  require RT::Action::SendEmail;
  @ISA  = qw(RT::Action::SendEmail);


=head1 DESCRIPTION

Basically, you create another module RT::Action::YourAction which ISA
RT::Action::SendEmail.

=begin testing

ok (require RT::Action::SendEmail);

=end testing


=head1 AUTHOR

Jesse Vincent <jesse@bestpractical.com> and Tobias Brox <tobix@cpan.org>

=head1 SEE ALSO

perl(1).

=cut

# {{{ Scrip methods (_Init, Commit, Prepare, IsApplicable)


# {{{ sub Commit

sub Commit {
    my $self = shift;

    return($self->SendMessage($self->TemplateObj->MIMEObj));
}

# }}}

# {{{ sub Prepare

sub Prepare {
    my $self = shift;

    my ( $result, $message ) = $self->TemplateObj->Parse(
        Argument       => $self->Argument,
        TicketObj      => $self->TicketObj,
        TransactionObj => $self->TransactionObj
    );
    if ( !$result ) {
        return (undef);
    }

    my $MIMEObj = $self->TemplateObj->MIMEObj;

    # Header
    $self->SetRTSpecialHeaders();

    $self->RemoveInappropriateRecipients();

    # Go add all the Tos, Ccs and Bccs that we need to to the message to
    # make it happy, but only if we actually have values in those arrays.

    # TODO: We should be pulling the recipients out of the template and shove them into To, Cc and Bcc

    $self->SetHeader( 'To', join ( ', ', @{ $self->{'To'} } ) )
      if ( ! $MIMEObj->head->get('To') &&  $self->{'To'} && @{ $self->{'To'} } );
    $self->SetHeader( 'Cc', join ( ', ', @{ $self->{'Cc'} } ) )
      if ( !$MIMEObj->head->get('Cc') && $self->{'Cc'} && @{ $self->{'Cc'} } );
    $self->SetHeader( 'Bcc', join ( ', ', @{ $self->{'Bcc'} } ) )
      if ( !$MIMEObj->head->get('Bcc') && $self->{'Bcc'} && @{ $self->{'Bcc'} } );

    # PseudoTo	(fake to headers) shouldn't get matched for message recipients.
    # If we don't have any 'To' header (but do have other recipients), drop in
    # the pseudo-to header.
    $self->SetHeader( 'To', join ( ', ', @{ $self->{'PseudoTo'} } ) )
      if ( $self->{'PseudoTo'} && ( @{ $self->{'PseudoTo'} } )
        and ( !$MIMEObj->head->get('To') ) ) and ( $MIMEObj->head->get('Cc') or $MIMEObj->head->get('Bcc'));

    # We should never have to set the MIME-Version header
    $self->SetHeader( 'MIME-Version', '1.0' );

    # try to convert message body from utf-8 to $RT::EmailOutputEncoding
    $self->SetHeader( 'Content-Type', 'text/plain; charset="utf-8"' );

    RT::I18N::SetMIMEEntityToEncoding( $MIMEObj, $RT::EmailOutputEncoding,
        'mime_words_ok' );
    $self->SetHeader( 'Content-Type', 'text/plain; charset="' . $RT::EmailOutputEncoding . '"' );

    # Build up a MIME::Entity that looks like the original message.
    $self->AddAttachments() if ( $MIMEObj->head->get('RT-Attach-Message') );

    return $result;

}

# }}}

# }}}



=head2 To

Returns an array of Mail::Address objects containing all the To: recipients for this notification

=cut

sub To {
    my $self = shift;
    return ($self->_AddressesFromHeader('To'));
}

=head2 Cc

Returns an array of Mail::Address objects containing all the Cc: recipients for this notification

=cut

sub Cc { 
    my $self = shift;
    return ($self->_AddressesFromHeader('Cc'));
}

=head2 Bcc

Returns an array of Mail::Address objects containing all the Bcc: recipients for this notification

=cut


sub Bcc {
    my $self = shift;
    return ($self->_AddressesFromHeader('Bcc'));

}

sub _AddressesFromHeader  {
    my $self = shift;
    my $field = shift;
    my $header = $self->TemplateObj->MIMEObj->head->get($field);
    my @addresses = Mail::Address->parse($header);

    return (@addresses);
}


# {{{ SendMessage

=head2 SendMessage MIMEObj

sends the message using RT's preferred API.
TODO: Break this out to a separate module

=cut

sub SendMessage {
    my $self    = shift;
    my $MIMEObj = shift;

    my $msgid = $MIMEObj->head->get('Message-Id');
    chomp $msgid;

    $RT::Logger->info( $msgid . " #"
        . $self->TicketObj->id . "/"
        . $self->TransactionObj->id
        . " - Scrip "
        . $self->ScripObj->id . " "
        . $self->ScripObj->Description );

    #If we don't have any recipients to send to, don't send a message;
    unless ( $MIMEObj->head->get('To')
        || $MIMEObj->head->get('Cc')
        || $MIMEObj->head->get('Bcc') )
    {
        $RT::Logger->info( $msgid . " No recipients found. Not sending.\n" );
        return (1);
    }


    if ( $RT::MailCommand eq 'sendmailpipe' ) {
        eval {
            open( MAIL, "|$RT::SendmailPath $RT::SendmailArguments" ) || die $!;
            print MAIL $MIMEObj->as_string;
            close(MAIL);
        };
        if ($@) {
            $RT::Logger->crit( $msgid . "Could not send mail. -" . $@ );
        }
    }
    else {
        my @mailer_args = ($RT::MailCommand);

        local $ENV{MAILADDRESS};

        if ( $RT::MailCommand eq 'sendmail' ) {
            push @mailer_args, split(/\s+/, $RT::SendmailArguments);
        }
        elsif ( $RT::MailCommand eq 'smtp' ) {
            $ENV{MAILADDRESS} = $RT::SMTPFrom || $MIMEObj->head->get('From');
            push @mailer_args, ( Server => $RT::SMTPServer );
            push @mailer_args, ( Debug  => $RT::SMTPDebug );
        }
        else {
            push @mailer_args, $RT::MailParams;
        }

        unless ( $MIMEObj->send(@mailer_args) ) {
            $RT::Logger->crit( $msgid . "Could not send mail." );
            return (0);
        }
    }

    my $success =
      ( $msgid
      . " sent To: "
      . $MIMEObj->head->get('To') . " Cc: "
      . $MIMEObj->head->get('Cc') . " Bcc: "
      . $MIMEObj->head->get('Bcc') );
    $success =~ s/\n//gi;

    $self->RecordOutgoingMailTransaction($MIMEObj) if ($RT::RecordOutgoingEmail);

    $RT::Logger->info($success);

    return (1);
}

# }}}

# {{{ AddAttachments 

=head2 AddAttachments

Takes any attachments to this transaction and attaches them to the message
we're building.

=cut


sub AddAttachments {
    my $self = shift;

    my $MIMEObj = $self->TemplateObj->MIMEObj;

    $MIMEObj->head->delete('RT-Attach-Message');

    my $attachments = RT::Attachments->new($RT::SystemUser);
    $attachments->Limit(
        FIELD => 'TransactionId',
        VALUE => $self->TransactionObj->Id
    );
    $attachments->OrderBy('id');

    my $transaction_content_obj = $self->TransactionObj->ContentObj;

    # attach any of this transaction's attachments
    while ( my $attach = $attachments->Next ) {

        # Don't attach anything blank
        next unless ( $attach->ContentLength );

# We want to make sure that we don't include the attachment that's being sued as the "Content" of this message"
        next
          if ( $transaction_content_obj
            && $transaction_content_obj->Id == $attach->Id
            && $transaction_content_obj->ContentType =~ qr{text/plain}i );
        $MIMEObj->make_multipart('mixed');
        $MIMEObj->attach(
            Type     => $attach->ContentType,
            Charset  => $attach->OriginalEncoding,
            Data     => $attach->OriginalContent,
            Filename => $self->MIMEEncodeString( $attach->Filename,
                $RT::EmailOutputEncoding ),
            'RT-Attachment:' => $self->TicketObj->Id."/".$self->TransactionObj->Id."/".$attach->id,
            Encoding => '-SUGGEST'
        );
    }

}

# }}}

# {{{ RecordOutgoingMailTransaction

=head2 RecordOutgoingMailTransaction MIMEObj

Record a transaction in RT with this outgoing message for future record-keeping purposes

=cut



sub RecordOutgoingMailTransaction {
    my $self = shift;
    my $MIMEObj = shift;
           

    my @parts = $MIMEObj->parts;
    my @attachments;
    my @keep;
    foreach my $part (@parts) {
        my $attach = $part->head->get('RT-Attachment');
        if ($attach) {
            $RT::Logger->debug("We found an attachment. we want to not record it.");
            push @attachments, $attach;
        } else {
            $RT::Logger->debug("We found a part. we want to record it.");
            push @keep, $part;
        }
    }
    $MIMEObj->parts(\@keep);
    foreach my $attachment (@attachments) {
        $MIMEObj->head->add('RT-Attachment', $attachment);
    }

    RT::I18N::SetMIMEEntityToEncoding( $MIMEObj, 'utf-8', 'mime_words_ok' );

    my $transaction = RT::Transaction->new($self->TransactionObj->CurrentUser);

    # XXX: TODO -> Record attachments as references to things in the attachments table, maybe.

    my $type;
    if ($self->TransactionObj->Type eq 'Comment') {
        $type = 'CommentEmailRecord';
    } else {
        $type = 'EmailRecord';
    }


      
    my ( $id, $msg ) = $transaction->Create(
        Ticket         => $self->TicketObj->Id,
        Type           => $type,
        Data           => $MIMEObj->head->get('Message-Id'),
        MIMEObj        => $MIMEObj,
        ActivateScrips => 0
    );


}

# }}}
#

# {{{ sub SetRTSpecialHeaders

=head2 SetRTSpecialHeaders 

This routine adds all the random headers that RT wants in a mail message
that don't matter much to anybody else.

=cut

sub SetRTSpecialHeaders {
    my $self = shift;

    $self->SetSubject();
    $self->SetSubjectToken();
    $self->SetHeaderAsEncoding( 'Subject', $RT::EmailOutputEncoding )
      if ($RT::EmailOutputEncoding);
    $self->SetReturnAddress();

    # TODO: this one is broken.  What is this email really a reply to?
    # If it's a reply to an incoming message, we'll need to use the
    # actual message-id from the appropriate Attachment object.  For
    # incoming mails, we would like to preserve the In-Reply-To and/or
    # References.

    $self->SetHeader( 'In-Reply-To',
        "<rt-" . $self->TicketObj->id() . "\@" . $RT::rtname . ">" );

    # TODO We should always add References headers for all message-ids
    # of previous messages related to this ticket.

    $self->SetHeader( 'Message-ID',
        "<rt-"
        . $RT::VERSION . "-"
        . $self->TicketObj->id() . "-"
        . $self->TransactionObj->id() . "-"
        . $self->ScripObj->Id . "."
        . rand(20) . "\@"
        . $RT::Organization . ">" )
      unless $self->TemplateObj->MIMEObj->head->get('Message-ID');

    $self->SetHeader( 'Precedence', "bulk" )
      unless ( $self->TemplateObj->MIMEObj->head->get("Precedence") );

    $self->SetHeader( 'X-RT-Loop-Prevention', $RT::rtname );
    $self->SetHeader( 'RT-Ticket',
        $RT::rtname . " #" . $self->TicketObj->id() );
    $self->SetHeader( 'Managed-by',
        "RT $RT::VERSION (http://www.bestpractical.com/rt/)" );

    $self->SetHeader( 'RT-Originator',
        $self->TransactionObj->CreatorObj->EmailAddress );

}

# }}}


# }}}

# {{{ RemoveInappropriateRecipients

=head2 RemoveInappropriateRecipients

Remove addresses that are RT addresses or that are on this transaction's blacklist

=cut

sub RemoveInappropriateRecipients {
    my $self = shift;

    my @blacklist;

    # Weed out any RT addresses. We really don't want to talk to ourselves!
    @{ $self->{'To'} } =
      RT::EmailParser::CullRTAddresses( "", @{ $self->{'To'} } );
    @{ $self->{'Cc'} } =
      RT::EmailParser::CullRTAddresses( "", @{ $self->{'Cc'} } );
    @{ $self->{'Bcc'} } =
      RT::EmailParser::CullRTAddresses( "", @{ $self->{'Bcc'} } );

    # If there are no recipients, don't try to send the message.
    # If the transaction has content and has the header RT-Squelch-Replies-To

    if ( defined $self->TransactionObj->Attachments->First() ) {
        my $squelch =
          $self->TransactionObj->Attachments->First->GetHeader(
            'RT-Squelch-Replies-To');

        if ($squelch) {
            @blacklist = split ( /,/, $squelch );
        }
    }

# Let's grab the SquelchMailTo attribue and push those entries into the @blacklist
    my @non_recipients = $self->TicketObj->SquelchMailTo;
    foreach my $attribute (@non_recipients) {
        push @blacklist, $attribute->Content;
    }

    # Cycle through the people we're sending to and pull out anyone on the
    # system blacklist

    foreach my $person_to_yank (@blacklist) {
        $person_to_yank =~ s/\s//g;
        @{ $self->{'To'} } = grep ( !/^$person_to_yank$/, @{ $self->{'To'} } );
        @{ $self->{'Cc'} } = grep ( !/^$person_to_yank$/, @{ $self->{'Cc'} } );
        @{ $self->{'Bcc'} } =
          grep ( !/^$person_to_yank$/, @{ $self->{'Bcc'} } );
    }
}

# }}}
# {{{ sub SetReturnAddress

=head2 SetReturnAddress is_comment => BOOLEAN

Calculate and set From and Reply-To headers based on the is_comment flag.

=cut

sub SetReturnAddress {

    my $self = shift;
    my %args = (
        is_comment => 0,
        @_
    );

    # From and Reply-To
    # $args{is_comment} should be set if the comment address is to be used.
    my $replyto;

    if ( $args{'is_comment'} ) {
        $replyto = $self->TicketObj->QueueObj->CommentAddress
          || $RT::CommentAddress;
    }
    else {
        $replyto = $self->TicketObj->QueueObj->CorrespondAddress
          || $RT::CorrespondAddress;
    }

    unless ( $self->TemplateObj->MIMEObj->head->get('From') ) {
        if ($RT::UseFriendlyFromLine) {
            my $friendly_name = $self->TransactionObj->CreatorObj->RealName;
            if ( $friendly_name =~ /^"(.*)"$/ ) {    # a quoted string
                $friendly_name = $1;
            }

            $friendly_name =~ s/"/\\"/g;
            $self->SetHeader(
                'From',
                sprintf(
                    $RT::FriendlyFromLineFormat,
                    $self->MIMEEncodeString( $friendly_name,
                        $RT::EmailOutputEncoding ),
                    $replyto
                ),
            );
        }
        else {
            $self->SetHeader( 'From', $replyto );
        }
    }

    unless ( $self->TemplateObj->MIMEObj->head->get('Reply-To') ) {
        $self->SetHeader( 'Reply-To', "$replyto" );
    }

}

# }}}

# {{{ sub SetHeader

=head2 SetHeader FIELD, VALUE

Set the FIELD of the current MIME object into VALUE.

=cut

sub SetHeader {
    my $self  = shift;
    my $field = shift;
    my $val   = shift;

    chomp $val;
    chomp $field;
    $self->TemplateObj->MIMEObj->head->fold_length( $field, 10000 );
    $self->TemplateObj->MIMEObj->head->replace( $field,     $val );
    return $self->TemplateObj->MIMEObj->head->get($field);
}

# }}}


# {{{ sub SetSubject

=head2 SetSubject

This routine sets the subject. it does not add the rt tag. that gets done elsewhere
If $self->{'Subject'} is already defined, it uses that. otherwise, it tries to get
the transaction's subject.

=cut 

sub SetSubject {
    my $self = shift;
    my $subject;

    my $message = $self->TransactionObj->Attachments;
    if ( $self->TemplateObj->MIMEObj->head->get('Subject') ) {
        return ();
    }
    if ( $self->{'Subject'} ) {
        $subject = $self->{'Subject'};
    }
    elsif ( ( $message->First() ) && ( $message->First->Headers ) ) {
        my $header = $message->First->Headers();
        $header =~ s/\n\s+/ /g;
        if ( $header =~ /^Subject: (.*?)$/m ) {
            $subject = $1;
        }
        else {
            $subject = $self->TicketObj->Subject();
        }

    }
    else {
        $subject = $self->TicketObj->Subject();
    }

    $subject =~ s/(\r\n|\n|\s)/ /gi;

    chomp $subject;
    $self->SetHeader( 'Subject', $subject );

}

# }}}

# {{{ sub SetSubjectToken

=head2 SetSubjectToken

This routine fixes the RT tag in the subject. It's unlikely that you want to overwrite this.

=cut

sub SetSubjectToken {
    my $self = shift;
    my $tag  = "[$RT::rtname #" . $self->TicketObj->id . "]";
    my $sub  = $self->TemplateObj->MIMEObj->head->get('Subject');
    unless ( $sub =~ /\Q$tag\E/ ) {
        $sub =~ s/(\r\n|\n|\s)/ /gi;
        chomp $sub;
        $self->TemplateObj->MIMEObj->head->replace( 'Subject', "$tag $sub" );
    }
}

# }}}

# }}}

# {{{ SetHeadingAsEncoding

=head2 SetHeaderAsEncoding($field_name, $charset_encoding)

This routine converts the field into specified charset encoding.

=cut

sub SetHeaderAsEncoding {
    my $self = shift;
    my ( $field, $enc ) = ( shift, shift );

    if ($field eq 'From' and $RT::SMTPFrom) {
        $self->TemplateObj->MIMEObj->head->replace( $field, $RT::SMTPFrom );
	return;
    }

    my $value = $self->TemplateObj->MIMEObj->head->get($field);

    # don't bother if it's us-ascii

    # See RT::I18N, 'NOTES:  Why Encode::_utf8_off before Encode::from_to'

    $value =  $self->MIMEEncodeString($value, $enc);

    $self->TemplateObj->MIMEObj->head->replace( $field, $value );


} 
# }}}

# {{{ MIMEEncodeString

=head2 MIMEEncodeString STRING ENCODING

Takes a string and a possible encoding and returns the string wrapped in MIME goo.

=cut

sub MIMEEncodeString {
    my  $self = shift;
    my $value = shift;
    # using RFC2047 notation, sec 2.
    # encoded-word = "=?" charset "?" encoding "?" encoded-text "?="
    my $charset = shift;
    my $encoding = 'B';
    # An 'encoded-word' may not be more than 75 characters long
    #
    # MIME encoding increases 4/3*(number of bytes), and always in multiples
    # of 4. Thus we have to find the best available value of bytes available
    # for each chunk.
    #
    # First we get the integer max which max*4/3 would fit on space.
    # Then we find the greater multiple of 3 lower or equal than $max.
    my $max = int(((75-length('=?'.$charset.'?'.$encoding.'?'.'?='))*3)/4);
    $max = int($max/3)*3;

    chomp $value;
    return ($value) unless $value =~ /[^\x20-\x7e]/;

    $value =~ s/\s*$//;
    Encode::_utf8_off($value);
    my $res = Encode::from_to( $value, "utf-8", $charset );
   
    if ($max > 0) {
      # copy value and split in chuncks
      my $str=$value;
      my @chunks = unpack("a$max" x int(length($str)/$max 
                                  + ((length($str) % $max) ? 1:0)), $str);
      # encode an join chuncks
      $value = join " ", 
                     map encode_mimeword( $_, $encoding, $charset ), @chunks ;
      return($value); 
    } else {
      # gives an error...
      $RT::Logger->crit("Can't encode! Charset or encoding too big.\n");
    }
}

# }}}

eval "require RT::Action::SendEmail_Vendor";
die $@ if ($@ && $@ !~ qr{^Can't locate RT/Action/SendEmail_Vendor.pm});
eval "require RT::Action::SendEmail_Local";
die $@ if ($@ && $@ !~ qr{^Can't locate RT/Action/SendEmail_Local.pm});

1;

