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
package RT::Action::CreateTickets;
require RT::Action::Generic;

use strict;
use warnings;
use vars qw/@ISA/;
@ISA = qw(RT::Action::Generic);

use MIME::Entity;

=head1 NAME

 RT::Action::CreateTickets

Create one or more tickets according to an externally supplied template.


=head1 SYNOPSIS

 ===Create-Ticket codereview
 Subject: Code review for {$Tickets{'TOP'}->Subject}
 Depended-On-By: TOP
 Content: Someone has created a ticket. you should review and approve it,
 so they can finish their work
 ENDOFCONTENT

=head1 DESCRIPTION


Using the "CreateTickets" ScripAction and mandatory dependencies, RT now has 
the ability to model complex workflow. When a ticket is created in a queue
that has a "CreateTickets" scripaction, that ScripAction parses its "Template"



=head2 FORMAT

CreateTickets uses the template as a template for an ordered set of tickets 
to create. The basic format is as follows:


 ===Create-Ticket: identifier
 Param: Value
 Param2: Value
 Param3: Value
 Content: Blah
 blah
 blah
 ENDOFCONTENT
 ===Create-Ticket: id2
 Param: Value
 Content: Blah
 ENDOFCONTENT


Each ===Create-Ticket: section is evaluated as its own 
Text::Template object, which means that you can embed snippets
of perl inside the Text::Template using {} delimiters, but that 
such sections absolutely can not span a ===Create-Ticket boundary.

After each ticket is created, it's stuffed into a hash called %Tickets
so as to be available during the creation of other tickets during the same 
ScripAction.  The hash is prepopulated with the ticket which triggered the 
ScripAction as $Tickets{'TOP'}; you can also access that ticket using the
shorthand TOP.

A simple example:

 ===Create-Ticket: codereview
 Subject: Code review for {$Tickets{'TOP'}->Subject}
 Depended-On-By: TOP
 Content: Someone has created a ticket. you should review and approve it,
 so they can finish their work
 ENDOFCONTENT



A convoluted example

 ===Create-Ticket: approval
 { # Find out who the administrators of the group called "HR" 
   # of which the creator of this ticket is a member
    my $name = "HR";
   
    my $groups = RT::Groups->new($RT::SystemUser);
    $groups->LimitToUserDefinedGroups();
    $groups->Limit(FIELD => "Name", OPERATOR => "=", VALUE => "$name");
    $groups->WithMember($TransactionObj->CreatorObj->Id);
 
    my $groupid = $groups->First->Id;
 
    my $adminccs = RT::Users->new($RT::SystemUser);
    $adminccs->WhoHaveRight(
	Right => "AdminGroup",
	Object =>$groups->First,
	IncludeSystemRights => undef,
	IncludeSuperusers => 0,
	IncludeSubgroupMembers => 0,
    );
 
     my @admins;
     while (my $admin = $adminccs->Next) {
         push (@admins, $admin->EmailAddress); 
     }
 }
 Queue: Approvals
 Type: Approval
 AdminCc: {join ("\nAdminCc: ",@admins) }
 Depended-On-By: TOP
 Refers-To: TOP
 Subject: Approval for ticket: {$Tickets{"TOP"}->Id} - {$Tickets{"TOP"}->Subject}
 Due: {time + 86400}
 Content-Type: text/plain
 Content: Your approval is requested for the ticket {$Tickets{"TOP"}->Id}: {$Tickets{"TOP"}->Subject}
 Blah
 Blah
 ENDOFCONTENT
 ===Create-Ticket: two
 Subject: Manager approval
 Depended-On-By: TOP
 Refers-On: {$Tickets{"approval"}->Id}
 Queue: Approvals
 Content-Type: text/plain
 Content: 
 Your approval is requred for this ticket, too.
 ENDOFCONTENT
 
=head2 Acceptable fields

A complete list of acceptable fields for this beastie:


    *  Queue           => Name or id# of a queue
       Subject         => A text string
     ! Status          => A valid status. defaults to 'new'
       Due             => Dates can be specified in seconds since the epoch
                          to be handled literally or in a semi-free textual
                          format which RT will attempt to parse.
                        
                          
                          
       Starts          => 
       Started         => 
       Resolved        => 
       Owner           => Username or id of an RT user who can and should own 
                          this ticket
   +   Requestor       => Email address
   +   Cc              => Email address 
   +   AdminCc         => Email address 
       TimeWorked      => 
       TimeEstimated   => 
       TimeLeft        => 
       InitialPriority => 
       FinalPriority   => 
       Type            => 
    +! DependsOn       => 
    +! DependedOnBy    =>
    +! RefersTo        =>
    +! ReferredToBy    => 
    +! Members         =>
    +! MemberOf        => 
       Content         => content. Can extend to multiple lines. Everything
                          within a template after a Content: header is treated
                          as content until we hit a line containing only 
                          ENDOFCONTENT
       ContentType     => the content-type of the Content field
       CustomField-<id#> => custom field value

Fields marked with an * are required.

Fields marked with a + man have multiple values, simply
by repeating the fieldname on a new line with an additional value.

Fields marked with a ! are postponed to be processed after all
tickets in the same actions are created.  Except for 'Status', those
field can also take a ticket name within the same action (i.e.
the identifiers after ==Create-Ticket), instead of raw Ticket ID
numbers.

When parsed, field names are converted to lowercase and have -s stripped.
Refers-To, RefersTo, refersto, refers-to and r-e-f-er-s-tO will all 
be treated as the same thing.


=begin testing

ok (require RT::Action::CreateTickets);
use_ok(RT::Scrip);
use_ok(RT::Template);
use_ok(RT::ScripAction);
use_ok(RT::ScripCondition);
use_ok(RT::Ticket);

my $approvalsq = RT::Queue->new($RT::SystemUser);
$approvalsq->Create(Name => 'Approvals');
ok ($approvalsq->Id, "Created Approvals test queue");


my $approvals = 
'===Create-Ticket: approval
Queue: Approvals
Type: Approval
AdminCc: root@localhost
Depended-On-By: TOP
Refers-To: TOP
Subject: Approval for ticket: {$Tickets{"TOP"}->Id} - {$Tickets{"TOP"}->Subject}
Due: {time + 86400}
Content-Type: text/plain
Content: Your approval is requested for the ticket {$Tickets{"TOP"}->Id}: {$Tickets{"TOP"}->Subject}
Blah
Blah
ENDOFCONTENT
===Create-Ticket: two
Subject: Manager approval.
Depends-On: {$Tickets{"approval"}->Id}
Queue: Approvals
Content-Type: text/plain
Content: 
Your minion approved this ticket. you ok with that?
ENDOFCONTENT
';

ok ($approvals =~ /Content/, "Read in the approvals template");

my $apptemp = RT::Template->new($RT::SystemUser);
$apptemp->Create( Content => $approvals, Name => "Approvals", Queue => "0");

ok ($apptemp->Id);

my $q = RT::Queue->new($RT::SystemUser);
$q->Create(Name => 'WorkflowTest');
ok ($q->Id, "Created workflow test queue");

my $scrip = RT::Scrip->new($RT::SystemUser);
my ($sval, $smsg) =$scrip->Create( ScripCondition => 'On Transaction',
                ScripAction => 'Create Tickets',
                Template => 'Approvals',
                Queue => $q->Id);
ok ($sval, $smsg);
ok ($scrip->Id, "Created the scrip");
ok ($scrip->TemplateObj->Id, "Created the scrip template");
ok ($scrip->ConditionObj->Id, "Created the scrip condition");
ok ($scrip->ActionObj->Id, "Created the scrip action");

my $t = RT::Ticket->new($RT::SystemUser);
$t->Create(Subject => "Sample workflow test",
           Owner => "root",
           Queue => $q->Id);


=end testing


=head1 AUTHOR

Jesse Vincent <jesse@bestpractical.com> 

=head1 SEE ALSO

perl(1).

=cut

my %LINKTYPEMAP = (
    MemberOf => { Type => 'MemberOf',
                  Mode => 'Target', },
    Parents => { Type => 'MemberOf',
		 Mode => 'Target', },
    Members => { Type => 'MemberOf',
                 Mode => 'Base', },
    Children => { Type => 'MemberOf',
		  Mode => 'Base', },
    HasMember => { Type => 'MemberOf',
                   Mode => 'Base', },
    RefersTo => { Type => 'RefersTo',
                  Mode => 'Target', },
    ReferredToBy => { Type => 'RefersTo',
                      Mode => 'Base', },
    DependsOn => { Type => 'DependsOn',
                   Mode => 'Target', },
    DependedOnBy => { Type => 'DependsOn',
                      Mode => 'Base', },

);

# {{{ Scrip methods (Commit, Prepare)

# {{{ sub Commit 
#Do what we need to do and send it out.
sub Commit {
    my $self = shift;

    # Create all the tickets we care about
    return(1) unless $self->TicketObj->Type eq 'ticket';

    $self->CreateByTemplate($self->TicketObj);
    $self->UpdateByTemplate($self->TicketObj);
    return(1);
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
 
  $self->Parse($self->TemplateObj->Content);
  return 1;
  
}

# }}}

# }}}

sub CreateByTemplate {
    my $self = shift;
    my $top = shift;

    my @results;

    # XXX: cargo cult programming that works. i'll be back.
    use bytes;

    %T::Tickets = ();

    my $ticketargs;
    my (@links, @postponed);
    foreach my $template_id ( @{ $self->{'create_tickets'} } ) {
	$T::Tickets{'TOP'} = $T::TOP = $top if $top;
	$RT::Logger->debug("Workflow: processing $template_id of $T::TOP") if $T::TOP;

	$T::ID = $template_id;
	@T::AllID = @{ $self->{'create_tickets'} };

	($T::Tickets{$template_id}, $ticketargs) = $self->ParseLines($template_id, 
								     \@links, \@postponed);

	# Now we have a %args to work with. 
	# Make sure we have at least the minimum set of 
	# reasonable data and do our thang

	my ($id, $transid, $msg) = $T::Tickets{$template_id}->Create(%$ticketargs);

	foreach my $res (split('\n', $msg)) {
	    push @results, $T::Tickets{$template_id}->loc("Ticket [_1]", $T::Tickets{$template_id}->Id) . ': ' .$res;
	}
	if (!$id) {
	    if ($self->TicketObj) {
		$msg = "Couldn't create related ticket $template_id for ".
		    $self->TicketObj->Id ." ".$msg;
	    } else {
		$msg = "Couldn't create ticket $template_id " . $msg;
	    }

	    $RT::Logger->error($msg);
	    next;
	}

	$RT::Logger->debug("Assigned $template_id with $id");
	$T::Tickets{$template_id}->SetOriginObj($self->TicketObj)
	    if $self->TicketObj && 
		$T::Tickets{$template_id}->can('SetOriginObj');	

    }

    $self->PostProcess(\@links, \@postponed);

    return @results;
}

sub UpdateByTemplate {
    my $self = shift;
    my $top = shift;

    # XXX: cargo cult programming that works. i'll be back.
    use bytes;

    my @results;
    %T::Tickets = ();

    my $ticketargs;
    my (@links, @postponed);
    foreach my $template_id ( @{ $self->{'update_tickets'} } ) {
	$RT::Logger->debug("Update Workflow: processing $template_id");

	$T::ID = $template_id;
	@T::AllID = @{ $self->{'update_tickets'} };

	($T::Tickets{$template_id}, $ticketargs) = $self->ParseLines($template_id, 
								     \@links, \@postponed);

	# Now we have a %args to work with. 
	# Make sure we have at least the minimum set of 
	# reasonable data and do our thang

	my @attribs = qw(
			 Subject
			 FinalPriority
			 Priority
			 TimeEstimated
			 TimeWorked
			 TimeLeft
			 Status
			 Queue
			 Due
			 Starts
			 Started
			 Resolved
			 );

	my $id = $template_id;
	$id =~ s/update-(\d+).*/$1/;
	$T::Tickets{$template_id}->Load($id);

	my $msg;
	if (!$T::Tickets{$template_id}->Id) {
	    $msg = "Couldn't update ticket $template_id " . $msg;

	    $RT::Logger->error($msg);
	    next;
	}

	my $current = $self->GetBaseTemplate($T::Tickets{$template_id});

	$template_id =~ m/^update-(.*)/;
	my $base_id = "base-$1";
	my $base = $self->{'templates'}->{$base_id};
	$base =~ s/\r//g;
	$base =~ s/\n+$//;
	$current =~ s/\n+$//;

	if ($base ne $current) {
	    push @results, "Could not update ticket " . $T::Tickets{$template_id}->Id . ": Ticket has changed";
	    next;
	}

	push @results,
	    $T::Tickets{$template_id}->Update(AttributesRef => \@attribs,
					      ARGSRef => $ticketargs);

	push @results, $self->UpdateWatchers($T::Tickets{$template_id}, $ticketargs);

	next unless exists $ticketargs->{'UpdateType'};
        if ( $ticketargs->{'UpdateType'} =~ /^(private|public)$/ ) {
            my ( $Transaction, $Description, $Object ) = $T::Tickets{$template_id}->Comment(
                CcMessageTo  => $ticketargs->{'Cc'},
                BccMessageTo => $ticketargs->{'Bcc'},
                MIMEObj      => $ticketargs->{'MIMEObj'},
                TimeTaken    => $ticketargs->{'TimeWorked'}
            );
            push ( @results, 
		   $T::Tickets{$template_id}->loc("Ticket [_1]", $T::Tickets{$template_id}->id) . ': ' . $Description );
        }
        elsif ( $ticketargs->{'UpdateType'} eq 'response' ) {
            my ( $Transaction, $Description, $Object ) = $T::Tickets{$template_id}->Correspond(
                CcMessageTo  => $ticketargs->{'Cc'},
                BccMessageTo => $ticketargs->{'Bcc'},
                MIMEObj      => $ticketargs->{'MIMEObj'},
                TimeTaken    => $ticketargs->{'TimeWorked'}
            );
            push ( @results,
		   $T::Tickets{$template_id}->loc("Ticket [_1]", $T::Tickets{$template_id}->id) . ': ' . $Description );
        }
        else {
            push ( @results,
                $T::Tickets{$template_id}->loc("Update type was neither correspondence nor comment.").
                " ".
                $T::Tickets{$template_id}->loc("Update not recorded.")
            );
        }
    }

    $self->PostProcess(\@links, \@postponed);

    return @results;
}

sub Parse {
    my $self = shift;
    my $content = shift;

    my @template_order;
    my $template_id;
    foreach my $line (split(/\n/, $content)) {
	$line =~ s/\r$//;
	$RT::Logger->debug("Line: $line");
	if ($line =~ /^===Create-Ticket: (.*)$/) {
	    $template_id = "create-$1";
	    $RT::Logger->debug("****  Create ticket: $template_id");
	    push @{$self->{'create_tickets'}},$template_id;
        } elsif ($line =~ /^===Update-Ticket: (.*)$/) {
	    $template_id = "update-$1";
	    $RT::Logger->debug("****  Update ticket: $template_id");
	    push @{$self->{'update_tickets'}},$template_id;
        } elsif ($line =~ /^===Base-Ticket: (.*)$/) {
	    $template_id = "base-$1";
	    $RT::Logger->debug("****  Base ticket: $template_id");
	    push @{$self->{'base_tickets'}},$template_id;
	} elsif ($line =~ /^===#.*$/) { # a comment
	    next;
        } else {
	    $self->{'templates'}->{$template_id} .= $line."\n";
        }
    }
}

sub ParseLines {
    my $self = shift;
    my $template_id = shift;
    my $links = shift;
    my $postponed = shift;

    $RT::Logger->debug("Workflow: evaluating\n$self->{templates}{$template_id}");

    my $template = Text::Template->new(
				       TYPE   => 'STRING',
				       SOURCE => $self->{'templates'}->{$template_id}
				       );

    my $err;
    my $filled_in = $template->fill_in( PACKAGE => 'T', BROKEN => sub {
	$err = { @_ }->{error};
    } );
    
    $RT::Logger->debug("Workflow: yielding\n$filled_in");
    
    if ($err) {
	$RT::Logger->error("Ticket creation failed: ".$err);
	while (my ($k, $v) = each %T::X) {
	    $RT::Logger->debug("Eliminating $template_id from ${k}'s parents.");
	    delete $v->{$template_id};
	}
	next;
    }
    
    my $TicketObj ||= RT::Ticket->new($RT::SystemUser);

    my %args;
    my @lines = ( split ( /\n/, $filled_in ) );
    while ( defined(my $line = shift @lines) ) {
	if ( $line =~ /^(.*?):(?:\s+(.*))?$/ ) {
	    my $value = $2;
	    my $tag = lc ($1);
	    $tag =~ s/-//g;
	    
	    if (ref($args{$tag})) { #If it's an array, we want to push the value
		push @{$args{$tag}}, $value;
	    }
	    elsif (defined ($args{$tag})) { #if we're about to get a second value, make it an array
		$args{$tag} = [$args{$tag}, $value];
	    }
	    else { #if there's nothing there, just set the value
		$args{ $tag } = $value;
	    }
	    
	    if ( $tag eq 'content' ) { #just build up the content
		# convert it to an array
		$args{$tag} = defined($value) ? [ $value."\n" ] : [];
		while ( defined(my $l = shift @lines) ) {
		    last if ($l =~  /^ENDOFCONTENT\s*$/) ;
		    push @{$args{'content'}}, $l."\n";
		}
	    } else {
		# if it's not content, strip leading and trailing spaces
		$args{ $tag } =~ s/^\s+//g;
		$args{ $tag } =~ s/\s+$//g;
	    }
	}
    }

    foreach my $date qw(due starts started resolved) {
	my $dateobj = RT::Date->new($RT::SystemUser);
	next unless $args{$date};
	if ($args{$date} =~ /^\d+$/) {
	    $dateobj->Set(Format => 'unix', Value => $args{$date});
	} else {
	    $dateobj->Set(Format => 'unknown', Value => $args{$date});
	}
	$args{$date} = $dateobj->ISO;
    }

    $args{'requestor'} ||= $self->TicketObj->Requestors->MemberEmailAddresses 
	if $self->TicketObj;

    $args{'type'} ||= 'ticket';

    my %ticketargs = ( Queue => $args{'queue'},
		       Subject=> $args{'subject'},
		       Status => 'new',
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
		       InitialPriority => $args{'initialpriority'} || 0,
		       FinalPriority => $args{'finalpriority'} || 0,
		       Type => $args{'type'}, 
		       );

    my $content = $args{'content'};
    if ($content) {
	my $mimeobj = MIME::Entity->new();
	$mimeobj->build(Type => $args{'contenttype'},
			Data => $args{'content'});
	$ticketargs{MIMEObj} = $mimeobj;
	$ticketargs{UpdateType} = $args{'updatetype'} if $args{'updatetype'};
    }
    
    foreach my $key (keys(%args)) {
	$key =~ /^customfield(\d+)$/ or next;
	$ticketargs{ "CustomField-" . $1 } = $args{$key};
    }

    $self->GetDeferred(\%args, $template_id, $links, $postponed);

    return $TicketObj, \%ticketargs;
}

sub GetDeferred {
    my $self = shift;
    my $args = shift;
    my $id = shift;
    my $links = shift;
    my $postponed = shift;

    # Deferred processing	
    push @$links, (
		  $id, {
		      DependsOn => $args->{'dependson'},
		      DependedOnBy => $args->{'dependedonby'},
		      RefersTo	=> $args->{'refersto'},
		      ReferredToBy => $args->{'referredtoby'},
		      Members => $args->{'members'},
		      MemberOf => $args->{'memberof'},
		  }
		  );

    push @$postponed, (
		      # Status is postponed so we don't violate dependencies
		      $id, {
			  Status => $args->{'status'},
		      }
		      );
}

sub GetUpdateTemplate {
    my $self = shift;
    my $t = shift;

    my $string;
    $string .= "Queue: " . $t->QueueObj->Name . "\n";
    $string .= "Subject: " . $t->Subject . "\n";
    $string .= "Status: " . $t->Status . "\n";
    $string .= "UpdateType: response\n";
    $string .= "Content: \n";
    $string .= "ENDOFCONTENT\n";
    $string .= "Due: " . $t->DueObj->AsString . "\n";
    $string .= "Starts: " . $t->StartsObj->AsString . "\n";
    $string .= "Started: " . $t->StartedObj->AsString . "\n";
    $string .= "Resolved: " . $t->ResolvedObj->AsString . "\n";
    $string .= "Owner: " . $t->OwnerObj->Name . "\n";
    $string .= "Requestor: " . $t->RequestorAddresses . "\n";
    $string .= "Cc: " . $t->CcAddresses . "\n";
    $string .= "AdminCc: " . $t->AdminCcAddresses . "\n";
    $string .= "TimeWorked: " . $t->TimeWorked . "\n";
    $string .= "TimeEstimated: " . $t->TimeEstimated . "\n";
    $string .= "TimeLeft: " . $t->TimeLeft . "\n";
    $string .= "InitialPriority: " . $t->Priority . "\n";
    $string .= "FinalPriority: " . $t->FinalPriority . "\n";

    foreach my $type (sort keys %LINKTYPEMAP) {
	# don't display duplicates
	if ($type eq "HasMember" || $type eq "Members"
	    || $type eq "MemberOf") {
	    next;
	}
	$string .= "$type: ";

	my $mode = $LINKTYPEMAP{$type}->{Mode};

	my $links;
	while (my $link = $t->$type->Next) {
	    $links .= ", " if $links;

	    my $method = $mode . "Obj";
	    my $member = $link->$method;
	    $links .= $member->Id;
	}
	$string .= $links;
	$string .= "\n";
    }

    return $string;
}

sub GetBaseTemplate {
    my $self = shift;
    my $t = shift;

    my $string;
    $string .= "Queue: " . $t->Queue . "\n";
    $string .= "Subject: " . $t->Subject . "\n";
    $string .= "Status: " . $t->Status . "\n";
    $string .= "Due: " . $t->DueObj->Unix . "\n";
    $string .= "Starts: " . $t->StartsObj->Unix . "\n";
    $string .= "Started: " . $t->StartedObj->Unix . "\n";
    $string .= "Resolved: " . $t->ResolvedObj->Unix . "\n";
    $string .= "Owner: " . $t->Owner . "\n";
    $string .= "Requestor: " . $t->RequestorAddresses . "\n";
    $string .= "Cc: " . $t->CcAddresses . "\n";
    $string .= "AdminCc: " . $t->AdminCcAddresses . "\n";
    $string .= "TimeWorked: " . $t->TimeWorked . "\n";
    $string .= "TimeEstimated: " . $t->TimeEstimated . "\n";
    $string .= "TimeLeft: " . $t->TimeLeft . "\n";
    $string .= "InitialPriority: " . $t->Priority . "\n";
    $string .= "FinalPriority: " . $t->FinalPriority . "\n";

    return $string;
}

sub GetCreateTemplate {
    my $self = shift;

    my $string;

    $string .= "Queue: General\n";
    $string .= "Subject: \n";
    $string .= "Status: new\n";
    $string .= "Content: \n";
    $string .= "ENDOFCONTENT\n";
    $string .= "Due: \n";
    $string .= "Starts: \n";
    $string .= "Started: \n";
    $string .= "Resolved: \n";
    $string .= "Owner: \n";
    $string .= "Requestor: \n";
    $string .= "Cc: \n";
    $string .= "AdminCc:\n"; 
    $string .= "TimeWorked: \n";
    $string .= "TimeEstimated: \n";
    $string .= "TimeLeft: \n";
    $string .= "InitialPriority: \n";
    $string .= "FinalPriority: \n";

    foreach my $type (keys %LINKTYPEMAP) {
	# don't display duplicates
	if ($type eq "HasMember" || $type eq 'Members' 
	    || $type eq 'MemberOf') {
	    next;
	}
	$string .= "$type: \n";
    }
    return $string;
}

sub UpdateWatchers {
    my $self = shift;
    my $ticket = shift;
    my $args = shift;

    my @results;

    foreach my $type qw(Requestor Cc AdminCc) {
	my $method = $type.'Addresses';
	my $oldaddr = $ticket->$method;
	my $newaddr = $args->{$type};
	
	my @old = split (', ', $oldaddr);
	my @new = split (', ', $newaddr);
	my %oldhash = map {$_ => 1} @old;
	my %newhash = map {$_ => 1} @new;
	
	my @add = grep(!defined $oldhash{$_}, @new);
	my @delete = grep(!defined $newhash{$_}, @old);
	
	foreach (@add) {
	    my ($val, $msg) =
		$ticket->AddWatcher(Type => $type,
				    Email => $_);
	    
	    push @results, $ticket->loc("Ticket [_1]", $ticket->Id) . 
		': ' . $msg;
	}
	
	foreach (@delete) {
	    my ($val, $msg) =
		$ticket->DeleteWatcher(Type => $type,
				       Email => $_);
	    push @results, $ticket->loc("Ticket [_1]", $ticket->Id) . 
		': ' . $msg;
	}
    }
    return @results;
}

sub PostProcess {
    my $self = shift;
    my $links = shift;
    my $postponed = shift;

    # postprocessing: add links

    while (my $template_id = shift(@$links)) {
	my $ticket = $T::Tickets{$template_id};
	$RT::Logger->debug("Handling links for " . $ticket->Id);
	my %args = %{shift(@$links)};

	foreach my $type ( keys %LINKTYPEMAP ) {
	    next unless (defined $args{$type});
	    foreach my $link (
		ref( $args{$type} ) ? @{ $args{$type} } : ( $args{$type} ) )
	    {
		next unless $link;
		if ($link !~ m/^\d+$/) {
		    my $key = "create-$link";
		    if (!exists $T::Tickets{$key}) {
			$RT::Logger->debug("Skipping $type link for $key (non-existent)");
			next;
		    }
		    $RT::Logger->debug("Building $type link for $link: " . $T::Tickets{$key}->Id);
		    $link = $T::Tickets{$key}->Id;
		} else {
		    $RT::Logger->debug("Building $type link for $link")
		}
		
		my ( $wval, $wmsg ) = $ticket->AddLink(
		    Type                          => $LINKTYPEMAP{$type}->{'Type'},
		    $LINKTYPEMAP{$type}->{'Mode'} => $link,
		    Silent                        => 1
		);

		$RT::Logger->warning("AddLink thru $link failed: $wmsg") unless $wval;
		# push @non_fatal_errors, $wmsg unless ($wval);
	    }

	}
    }

    # postponed actions -- Status only, currently
    while (my $template_id = shift(@$postponed)) {
	my $ticket = $T::Tickets{$template_id};
	$RT::Logger->debug("Handling postponed actions for $ticket");
	my %args = %{shift(@$postponed)};
	$ticket->SetStatus($args{Status}) if defined $args{Status};
    }

}

eval "require RT::Action::CreateTickets_Vendor";
die $@ if ($@ && $@ !~ qr{^Can't locate RT/Action/CreateTickets_Vendor.pm});
eval "require RT::Action::CreateTickets_Local";
die $@ if ($@ && $@ !~ qr{^Can't locate RT/Action/CreateTickets_Local.pm});

1;

