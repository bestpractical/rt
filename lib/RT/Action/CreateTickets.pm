# Copyright 1996-2002 Jesse Vincent <jesse@bestpractical.com>

package RT::Action::CreateTickets;
require RT::Action::Generic;

@ISA = qw(RT::Action::Generic);


=head1 NAME

  RT::Action::CreateTickets - An Action which users can use to send mail 
  or can subclassed for more specialized mail sending behavior. 
  RT::Action::AutoReply is a good example subclass.


=head1 SYNOPSIS

  require RT::Action::CreateTickets;
  @ISA  = qw(RT::Action::CreateTickets);


=head1 DESCRIPTION

Create one or more tickets according to an externally supplied template.



=head2 FORMAT

===Create-Ticket: <identifier>
Subject: Some subject
Owner: <username>
Requestor: <username>
Requestor: <username2>
Requestor: <username3>
Cc: <username4>
Cc: <username5>
AdminCc: <username6>
AdminCc: <username7>
CustomField-<Name>: <value>
Starts: <date>
Started: <date>
Due: <date>
DependsOn: <id>
DependedOnBy: <id>
RefersTo: <id>
ReferredToBy: <id>
Content-Type: <content-type>
Content:.....
...
ENDCONTENT






=begin testing

ok (require RT::Action::CreateTickets);

=end testing


=head1 AUTHOR

Jesse Vincent <jesse@bestpractical.com> 

=head1 SEE ALSO

perl(1).

=cut

# {{{ Scrip methods (Commit, Prepare)

# {{{ sub Commit 
#Do what we need to do and send it out.
sub Commit {
    my $self = shift;

    # Create all the tickets we care about

    $T::Tickets{'TOP'} = $self->TicketObj;

    foreach my $template_id ( @{ $self->{'template_order'} } ) {
        $T::Tickets{$template_id} = RT::Ticket->new($RT::SystemUser);
        my $template = Text::Template->new(
                                  TYPE   => STRING,
                                  SOURCE => $self->{'templates'}->{$template_id}
        );

        my $retval = $template->fill_in( PACKAGE => T );
        my %args;
        my @lines = ( split ( /\n/, $template ) );
        while ( my $line = shift @lines ) {
            if ( $line =~ /^(.*?):\s+(.*)$/ ) {
                my $tag = lc ($1);
                    if (defined ($args{$tag})) { #if we're about to get a second value, make it an array
                        $args{$tag} = [$args{$tag}];
                    }
                    if (ref($args{$tag})) { #If it's an array, we want to push the value
                        push @{$args{$tag}}, $2;
                    }
                    else { #if there's nothing there, just set the value
                        $args{ $tag } = $2;
                    }

                if ( $tag eq 'content' ) { #just build up the content
                    $args{'content'} .= $_
                      while ( shift (@lines) && $_ ne 'ENDOFCONTENT' );
                }
            }
            }
            # Now we have a %args to work with. 
            # Make sure we have at least the minimum set of 
            # reasonable data and do our thang
            $T::Tickets{$template_id} = RT::Ticket->new($RT::SystemUser);
            %ticketargs = (Queue => $args{'queue'},
                          Subject=> $args{'subject'},
                        Status => $args{'status'},
                        Due => $args{'due'},
                        Starts => $args{'starts'},
                        Started => $args{'started'},
                        Resolved => $args{'resolved'},
                        Owner => $args{'owner'},
                        Requestor => $args{'requestor'},
                        Cc => $args{'cc'},
                        AdminCc=> $args{'admincc'},
                        TimeWorked =>$args{'timeworked'},
                        TimeEstimated =>$args{'timeestimated'},
                        TimeLeft =>$args{'timeleft'},
                        InitialPriority => $args{'initialpriority'},
                        FinalPriority => $args{'finalpriority'},
                        Type => $args{'type'}, 
                        DependsOn => $args{'dependson'},
                        DependedOnBy => $args{'dependedonby'},
                        RefersTo=>$args{'refersto'},
                        ReferredToBy => $args{'referredtoby'},
                        Members => $args{'members'},
                        MemberOf => $args{'memberof'});

    
            map {
                /^customfield-(\d+)$/
                  && ( $ticketargs{ "CustomField-" . $1 } = $args{$_} );
            } keys(%args);
            my ($id, $transid, $msg) = $T::Tickets{$template_id}->Create(%ticketargs);


        }

}
# }}}

# {{{ sub Prepare 

sub Prepare  {
  my $self = shift;
  
  unless ($self->TemplateObj) {
    $RT::Logger->warning("No template object handed to $self\n");
  }
  
  unless ($self->TransactionObj) {
    $RT::Logger->warning("No transaction object handed to $self\n");
    
  }
  
  unless ($self->TicketObj) {
    $RT::Logger->warning("No ticket object handed to $self\n");
      
  }
 

    

foreach my $line (split(/\n/,$self->TemplateObj->Content)) {
        my $template_id;
        if ($line =~ /^===Create-Ticket: (.*)$/) {
                $template_id = $1;
                push @{$self->{'template_order'}},$template_id;
        } else {
                $self->{'templates'}->{$template_id} .= $line."\n";
        }       
        
        
}
  
  return 1;
  
}

# }}}

# }}}

1;

