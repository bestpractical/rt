# BEGIN LICENSE BLOCK
# 
# Copyright (c) 1996-2003 Jesse Vincent <jesse@bestpractical.com>
# 
# (Except where explictly superceded by other copyright notices)
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
# Unless otherwise specified, all modifications, corrections or
# extensions to this work which alter its source code become the
# property of Best Practical Solutions, LLC when submitted for
# inclusion in the work.
# 
# 
# END LICENSE BLOCK
# Portions Copyright 2000 Tobias Brox <tobix@cpan.org>

package RT::Action::SendEmail;
require RT::Action::Generic;

use strict;
use vars qw/@ISA/;
@ISA = qw(RT::Action::Generic);

use MIME::Words qw(encode_mimeword);

use RT::EmailParser;

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

If you want to set the recipients of the mail to something other than
the addresses mentioned in the To, Cc, Bcc and headers in
the template, you should subclass RT::Action::SendEmail and override
either the SetRecipients method or the SetTo, SetCc, etc methods (see
the comments for the SetRecipients sub).


=begin testing

ok (require RT::Action::SendEmail);

=end testing


=head1 AUTHOR

Jesse Vincent <jesse@bestpractical.com> and Tobias Brox <tobix@cpan.org>

=head1 SEE ALSO

perl(1).

=cut

# {{{ Scrip methods (_Init, Commit, Prepare, IsApplicable)

# {{{ sub _Init
# We use _Init from RT::Action
# }}}

# {{{ sub Commit
#Do what we need to do and send it out.
sub Commit {
    my $self = shift;

    my $MIMEObj = $self->TemplateObj->MIMEObj;
    my $msgid = $MIMEObj->head->get('Message-Id');
    chomp $msgid;
    $RT::Logger->info($msgid." #".$self->TicketObj->id."/".$self->TransactionObj->id." - Scrip ". $self->ScripObj->id ." ".$self->ScripObj->Description);
    #send the email

        # Weed out any RT addresses. We really don't want to talk to ourselves!
        @{$self->{'To'}} = RT::EmailParser::CullRTAddresses("", @{$self->{'To'}});
        @{$self->{'Cc'}} = RT::EmailParser::CullRTAddresses("", @{$self->{'Cc'}});
        @{$self->{'Bcc'}} = RT::EmailParser::CullRTAddresses("", @{$self->{'Bcc'}});
    # If there are no recipients, don't try to send the message.
    # If the transaction has content and has the header RT-Squelch-Replies-To

    if ( defined $self->TransactionObj->Attachments->First() ) {

        my $squelch = $self->TransactionObj->Attachments->First->GetHeader( 'RT-Squelch-Replies-To');

        if ($squelch) {
            my @blacklist = split ( /,/, $squelch );

            # Cycle through the people we're sending to and pull out anyone on the
            # system blacklist

            foreach my $person_to_yank (@blacklist) {
                $person_to_yank =~ s/\s//g;
                @{ $self->{'To'} } =
                  grep ( !/^$person_to_yank$/, @{ $self->{'To'} } );
                @{ $self->{'Cc'} } =
                  grep ( !/^$person_to_yank$/, @{ $self->{'Cc'} } );
                @{ $self->{'Bcc'} } =
                  grep ( !/^$person_to_yank$/, @{ $self->{'Bcc'} } );
            }
        }
    }

    # Go add all the Tos, Ccs and Bccs that we need to to the message to
    # make it happy, but only if we actually have values in those arrays.

    $self->SetHeader( 'To', join ( ',', @{ $self->{'To'} } ) )
      if ( $self->{'To'} && @{ $self->{'To'} } );
    $self->SetHeader( 'Cc', join ( ',', @{ $self->{'Cc'} } ) )
      if ( $self->{'Cc'} && @{ $self->{'Cc'} } );
    $self->SetHeader( 'Bcc', join ( ',', @{ $self->{'Bcc'} } ) )
      if ( $self->{'Cc'} && @{ $self->{'Bcc'} } );


    $self->SetHeader('MIME-Version', '1.0');

    # try to convert message body from utf-8 to $RT::EmailOutputEncoding
    $self->SetHeader( 'Content-Type', 'text/plain; charset="utf-8"' );

    RT::I18N::SetMIMEEntityToEncoding( $MIMEObj, $RT::EmailOutputEncoding, 'mime_words_ok' );
    $self->SetHeader( 'Content-Type', 'text/plain; charset="' . $RT::EmailOutputEncoding . '"' );


    # Build up a MIME::Entity that looks like the original message.

    my $do_attach = $self->TemplateObj->MIMEObj->head->get('RT-Attach-Message');

    if ($do_attach) {
        $self->TemplateObj->MIMEObj->head->delete('RT-Attach-Message');

        my $attachments = RT::Attachments->new($RT::SystemUser);
        $attachments->Limit( FIELD => 'TransactionId',
                             VALUE => $self->TransactionObj->Id );
        $attachments->OrderBy('id');

        my $transaction_content_obj = $self->TransactionObj->ContentObj;

        # attach any of this transaction's attachments
        while ( my $attach = $attachments->Next ) {

            # Don't attach anything blank
            next unless ( $attach->ContentLength );

            # We want to make sure that we don't include the attachment that's being sued as the "Content" of this message"
            next
              if (    $transaction_content_obj
                   && $transaction_content_obj->Id == $attach->Id 
                   && $transaction_content_obj->ContentType =~ qr{text/plain}i
                );
            $MIMEObj->make_multipart('mixed');
            $MIMEObj->attach( Type => $attach->ContentType,
                              Charset => $attach->OriginalEncoding,
                              Data => $attach->OriginalContent,
                              Filename => $self->MIMEEncodeString( $attach->Filename, $RT::EmailOutputEncoding ),
                              Encoding    => '-SUGGEST');
        }

    }


    my $retval = $self->SendMessage($MIMEObj);


    return ($retval);
}

# }}}

# {{{ sub Prepare

sub Prepare {
    my $self = shift;

    # This actually populates the MIME::Entity fields in the Template Object

    unless ( $self->TemplateObj ) {
        $RT::Logger->warning("No template object handed to $self\n");
    }

    unless ( $self->TransactionObj ) {
        $RT::Logger->warning("No transaction object handed to $self\n");

    }

    unless ( $self->TicketObj ) {
        $RT::Logger->warning("No ticket object handed to $self\n");

    }

    my ( $result, $message ) = $self->TemplateObj->Parse(
                                         Argument       => $self->Argument,
                                         TicketObj      => $self->TicketObj,
                                         TransactionObj => $self->TransactionObj
    );
    if ($result) {

        # Header
        $self->SetSubject();
        $self->SetSubjectToken();
        $self->SetRecipients();
        $self->SetReturnAddress();
        $self->SetRTSpecialHeaders();
        if ($RT::EmailOutputEncoding) {

            # l10n related header
            $self->SetHeaderAsEncoding( 'Subject', $RT::EmailOutputEncoding );
        }
    }

    return $result;

}

# }}}

# }}}

# {{{ SendMessage
=head2 SendMessage MIMEObj

sends the message using RT's preferred API.
TODO: Break this out to a seperate module

=cut

sub SendMessage {
    my $self = shift;
    my $MIMEObj = shift;

    my $msgid = $MIMEObj->head->get('Message-Id');


    #If we don't have any recipients to send to, don't send a message;
    unless (    $MIMEObj->head->get('To')
             || $MIMEObj->head->get('Cc')
             || $MIMEObj->head->get('Bcc') ) {
        $RT::Logger->info($msgid.  " No recipients found. Not sending.\n");
        return (1);
    }

    # PseudoTo	(fake to headers) shouldn't get matched for message recipients.
    # If we don't have any 'To' header, drop in the pseudo-to header.

    $self->SetHeader( 'To', join ( ',', @{ $self->{'PseudoTo'} } ) )
      if ( $self->{'PseudoTo'} && ( @{ $self->{'PseudoTo'} } )
           and ( !$MIMEObj->head->get('To') ) );
    if ( $RT::MailCommand eq 'sendmailpipe' ) {
        eval {
            open( MAIL, "|$RT::SendmailPath $RT::SendmailArguments" );
            print MAIL $MIMEObj->as_string;
            close(MAIL);
          };
          if ($@) {
            $RT::Logger->crit($msgid.  "Could not send mail. -".$@ );
        }
    }
    else {
	my @mailer_args = ($RT::MailCommand);
	local $ENV{MAILADDRESS};

        if ( $RT::MailCommand eq 'sendmail' ) {
	    push @mailer_args, $RT::SendmailArguments;
        }
        elsif ( $RT::MailCommand eq 'smtp' ) {
	    $ENV{MAILADDRESS} = $RT::SMTPFrom || $MIMEObj->head->get('From');
	    push @mailer_args, (Server => $RT::SMTPServer);
	    push @mailer_args, (Debug => $RT::SMTPDebug);
        }
	else {
	    push @mailer_args, $RT::MailParams;
	}

        unless ( $MIMEObj->send( @mailer_args ) ) {
            $RT::Logger->crit($msgid.  "Could not send mail." );
            return (0);
        }
    }


     my $success = ($msgid. " sent To: ".$MIMEObj->head->get('To') . " Cc: ".$MIMEObj->head->get('Cc') . " Bcc: ".$MIMEObj->head->get('Bcc'));
    $success =~ s/\n//gi;
    $RT::Logger->info($success);

    return (1);
}

# }}}

# {{{ Deal with message headers (Set* subs, designed for  easy overriding)

# {{{ sub SetRTSpecialHeaders

=head2 SetRTSpecialHeaders 

This routine adds all the random headers that RT wants in a mail message
that don't matter much to anybody else.

=cut

sub SetRTSpecialHeaders {
    my $self = shift;

    $self->SetReferences();

    $self->SetMessageID();

    $self->SetPrecedence();

    $self->SetHeader( 'X-RT-Loop-Prevention', $RT::rtname );
    $self->SetHeader( 'RT-Ticket',
                      $RT::rtname . " #" . $self->TicketObj->id() );
    $self->SetHeader( 'Managed-by',
                      "RT $RT::VERSION (http://www.bestpractical.com/rt/)" );

    $self->SetHeader( 'RT-Originator',
                      $self->TransactionObj->CreatorObj->EmailAddress );
    return ();

}

# {{{ sub SetReferences

=head2 SetReferences 
  
  # This routine will set the References: and In-Reply-To headers,
# autopopulating it with all the correspondence on this ticket so
# far. This should make RT responses threadable.

=cut

sub SetReferences {
    my $self = shift;

    # TODO: this one is broken.  What is this email really a reply to?
    # If it's a reply to an incoming message, we'll need to use the
    # actual message-id from the appropriate Attachment object.  For
    # incoming mails, we would like to preserve the In-Reply-To and/or
    # References.

    $self->SetHeader( 'In-Reply-To',
                   "<rt-" . $self->TicketObj->id() . "\@" . $RT::rtname . ">" );

    # TODO We should always add References headers for all message-ids
    # of previous messages related to this ticket.
}

# }}}

# {{{ sub SetMessageID

=head2 SetMessageID 

Without this one, threading won't work very nice in email agents.
Anyway, I'm not really sure it's that healthy if we need to send
several separate/different emails about the same transaction.

=cut

sub SetMessageID {
    my $self = shift;

    # TODO this one might be sort of broken.  If we have several scrips +++
    # sending several emails to several different persons, we need to
    # pull out different message-ids.  I'd suggest message ids like
    # "rt-ticket#-transaction#-scrip#-receipient#"

    $self->SetHeader( 'Message-ID',
                      "<rt-"
                        . $RT::VERSION ."-"
                        . $self->TicketObj->id() . "-"
                        . $self->TransactionObj->id() . "."
                        . rand(20) . "\@"
                        . $RT::Organization . ">" )
      unless $self->TemplateObj->MIMEObj->head->get('Message-ID');
}

# }}}

# }}}

# {{{ sub SetReturnAddress

=head2 SetReturnAddress is_comment => BOOLEAN

Calculate and set From and Reply-To headers based on the is_comment flag.

=cut

sub SetReturnAddress {

    my $self = shift;
    my %args = ( is_comment => 0,
                 @_ );

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
	    $self->SetHeader( 'From',
		        sprintf($RT::FriendlyFromLineFormat, 
                $self->MIMEEncodeString( $friendly_name, $RT::EmailOutputEncoding ), $replyto),
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

# {{{ sub SetRecipients

=head2 SetRecipients

Dummy method to be overriden by subclasses which want to set the recipients.

=cut

sub SetRecipients {
    my $self = shift;
    return ();
}

# }}}

# {{{ sub SetTo

=head2 SetTo

Takes a string that is the addresses you want to send mail to

=cut

sub SetTo {
    my $self      = shift;
    my $addresses = shift;
    return $self->SetHeader( 'To', $addresses );
}

# }}}

# {{{ sub SetCc

=head2 SetCc

Takes a string that is the addresses you want to Cc

=cut

sub SetCc {
    my $self      = shift;
    my $addresses = shift;

    return $self->SetHeader( 'Cc', $addresses );
}

# }}}

# {{{ sub SetBcc

=head2 SetBcc

Takes a string that is the addresses you want to Bcc

=cut

sub SetBcc {
    my $self      = shift;
    my $addresses = shift;

    return $self->SetHeader( 'Bcc', $addresses );
}

# }}}

# {{{ sub SetPrecedence

sub SetPrecedence {
    my $self = shift;

    unless ( $self->TemplateObj->MIMEObj->head->get("Precedence") ) {
        $self->SetHeader( 'Precedence', "bulk" );
    }
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

    unless ( $self->TemplateObj->MIMEObj->head->get('Subject') ) {
        my $message = $self->TransactionObj->Attachments;
        my $ticket  = $self->TicketObj->Id;

        if ( $self->{'Subject'} ) {
            $subject = $self->{'Subject'};
        }
        elsif (    ( $message->First() )
                && ( $message->First->Headers ) ) {
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
    return ($subject);
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

# {{{

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

# {{{ MIMENcodeString

=head2 MIMEEncodeString STRING ENCODING

Takes a string and a possible encoding and returns the string wrapped in MIME goo.

=cut

sub MIMEEncodeString {
    my  $self = shift;
    my $value = shift;
    my $enc = shift;

    chomp $value;
    return ($value) unless $value =~ /[^\x20-\x7e]/;

    $value =~ s/\s*$//;
    Encode::_utf8_off($value);
    my $res = Encode::from_to( $value, "utf-8", $enc );
    $value = encode_mimeword( $value,  'B', $enc );
}

# }}}

eval "require RT::Action::SendEmail_Vendor";
die $@ if ($@ && $@ !~ qr{^Can't locate RT/Action/SendEmail_Vendor.pm});
eval "require RT::Action::SendEmail_Local";
die $@ if ($@ && $@ !~ qr{^Can't locate RT/Action/SendEmail_Local.pm});

1;

