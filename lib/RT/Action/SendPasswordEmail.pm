# $Header: /raid/cvsroot/rt/lib/RT/Action/SendPasswordEmail.pm,v 1.2 2001/11/06 23:04:17 jesse Exp $
# Copyright 2001  Jesse Vincent <jesse@fsck.com>
# Released under the terms of the GNU Public License

package RT::Action::SendPasswordEmail;
require RT::Action::Generic;

@ISA = qw(RT::Action::Generic);


=head1 NAME

  RT::Action::SendGenericEmail - An Action which users can use to send mail 
  or can subclassed for more specialized mail sending behavior. 



=head1 SYNOPSIS

  require RT::Action::SendPasswordEmail;


=head1 DESCRIPTION

Basically, you create another module RT::Action::YourAction which ISA
RT::Action::SendEmail.

If you want to set the recipients of the mail to something other than
the addresses mentioned in the To, Cc, Bcc and headers in
the template, you should subclass RT::Action::SendEmail and override
either the SetRecipients method or the SetTo, SetCc, etc methods (see
the comments for the SetRecipients sub).


=begin testing

ok (require RT::TestHarness);
ok (require RT::Action::SendPasswordEmail);

=end testing


=head1 AUTHOR

Jesse Vincent <jesse@bestpractical.com>

=head1 SEE ALSO

perl(1).

=cut

# {{{ Scrip methods (_Init, Commit, Prepare, IsApplicable)

# {{{ sub Commit 

#Do what we need to do and send it out.

sub Commit  {
    my $self = shift;
    #send the email
    
    
    

    
    my $MIMEObj = $self->TemplateObj->MIMEObj;
    
    
    $MIMEObj->make_singlepart;
    
    #If we don\'t have any recipients to send to, don\'t send a message;
    unless ($MIMEObj->head->get('To')) {
	$RT::Logger->debug("$self: No recipients found. Not sending.\n");
	return(1);
    }
    
    if ($RT::MailCommand eq 'sendmailpipe') {
	open (MAIL, "|$RT::SendmailPath $RT::SendmailArguments") || return(0);
	print MAIL $MIMEObj->as_string;
	close(MAIL);
    }
    else {
	unless ($MIMEObj->send($RT::MailCommand, $RT::MailParams)) {
	    $RT::Logger->crit("$self: Could not send mail for ".$self->TransactionObj."\n ");
	    return(0);
	}
    }
    
    return (1);
    
}
# }}}

# {{{ sub Prepare 

sub Prepare  {
    my $self = shift;
    
    # This actually populates the MIME::Entity fields in the Template Object
    
    unless ($self->TemplateObj) {
	$RT::Logger->warning("No template object handed to $self\n");
    }
    
    
    unless ($self->TemplateObj->MIMEObj->head->get('Reply-To')) {
	$self->SetHeader('Reply-To',$RT::CorrespondAddress );
    }

    
    $self->SetHeader('Precedence', "bulk");
    $self->SetHeader('X-RT-Loop-Prevention', $RT::rtname); 
    $self->SetHeader
      ('Managed-by',"Request Tracker $RT::VERSION (http://www.fsck.com/projects/rt/)");
    
    $self->TemplateObj->Parse(Argument => $self->Argument);
    
    
    return 1;
}

# }}}

# }}}


# {{{ sub SetTo

=head2 SetTo EMAIL

Sets this message's "To" field to EMAIL

=cut

sub SetTo {
    my $self = shift;
    my $to = shift;
    $self->SetHeader('To',$to);
}

# }}}

# {{{ sub SetHeader

sub SetHeader {
  my $self = shift;
  my $field = shift;
  my $val = shift;

  chomp $val;                                                                  
  chomp $field;                                                                
  $self->TemplateObj->MIMEObj->head->fold_length($field,10000);     
  $self->TemplateObj->MIMEObj->head->add($field, $val);
  return $self->TemplateObj->MIMEObj->head->get($field);
}

# }}}



__END__

# {{{ POD

# }}}

1;

