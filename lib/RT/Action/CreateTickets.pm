# Copyright 1996-2002 Jesse Vincent <jesse@bestpractical.com>

package RT::Action::CreateTickets;
require RT::Action::Generic;

@ISA = qw(RT::Action::Generic);

use MIME::Entity;

=head1 NAME

 RT::Action::CreateTickets

Create one or more tickets according to an externally supplied template.


=head1 SYNOPSIS

 ===Create-Ticket: codereview
 Subject: Code review for {$Tickets{'TOP'}->Subject}
 Depended-On-By: {$Tickets{'TOP'}->Id}
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
ScripAction as $Tickets{'TOP'}.  

A simple example:

 ===Create-Ticket: codereview
 Subject: Code review for {$Tickets{'TOP'}->Subject}
 Depended-On-By: {$Tickets{'TOP'}->Id}
 Content: Someone has created a ticket. you should review and approve it,
 so they can finish their work
 ENDOFCONTENT



A convoluted example

 ===Create-Ticket: approval
 { # Find out who the administrators of the group called "HR" 
   # of which the creator of this ticket is a member
    my $name = "HR";
    q
    my $groups = RT::Groups->new($RT::SystemUser);
    $groups->LimitToUserDefinedGroups();
    $groups->Limit(FIELD => "Name", OPERATOR => "=", VALUE => "$name");
    $groups->WithMember($TransactionObj->CreatorObj->Id);
 
    my $groupid = $groups->First->Id;
 
    my $adminccs = RT::Users->new($RT::SystemUser);
    $adminccs->WhoHaveRight(Right => "AdminGroup" ObjectType =>"Group", IncludeSystemRights => undef, IncludeSuperusers => 0, IncludeSubgroupMembers => 0, ObjectId => $groupid);
 
     my @admins;
     while (my $admin = $adminccs->Next) {
         push (@admins, $admin->EmailAddress); 
     }
 }
 Queue: Approvals
 Type: Approval
 AdminCc: {join ("\nAdminCc: ",@admins) }
 Depended-On-By: {$Tickets{"TOP"}->Id}
 Refers-To: {$Tickets{"TOP"}->Id}
 Subject: Approval for ticket: {$Tickets{"TOP"}->Id} - {$Tickets{"TOP"}->Subject}
 Due: {time + 86400}
 Content-Type: text/plain
 Content: Your approval is requested for the ticket {$Tickets{"TOP"}->Id}: {$Tickets{"TOP"}->Subject}
 Blah
 Blah
 ENDOFCONTENT
 ===Create-Ticket: two
 Subject: Manager approval
 Depended-On-By: {$Tickets{"TOP"}->Id}
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
       Status          => A valid status. defaults to 'new'
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
    +  DependsOn       => 
    +  DependedOnBy    =>
    +  RefersTo        =>
    +  ReferredToBy    => 
    +  Members         =>
    +  MemberOf        => 
       Content         => content. Can extend to multiple lines. Everything
                          within a template after a Content: header is treated
                          as content until we hit a line containing only 
                          ENDOFCONTENT
       ContentType     => the content-type of the Content field
       CustomField-<id#> => custom field value

    
     Fields marked with an * are required.
     Fields marked with a + man have multiple values, simply
     by repeating the fieldname on a new line with an additional value
     
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
{  my $name = "HR";
     my $groups = RT::Groups->new($RT::SystemUser);
   $groups->LimitToUserDefinedGroups();
   $groups->Limit(FIELD => "Name", OPERATOR => "=", VALUE => "$name");
   $groups->WithMember($TransactionObj->CreatorObj->Id);

   my $groupid = $groups->First->Id;

   my $adminccs = RT::Users->new($RT::SystemUser);
   $adminccs->WhoHaveRight(Right => "AdminGroup" ObjectType =>"Group", IncludeSystemRights => undef, IncludeSuperusers => 0, IncludeSubgroupMembers => 0, ObjectId => $groupid);

    my @admins;
    while (my $admin = $adminccs->Next) {
        push (@admins, $admin->EmailAddress); 
    }
}
Queue: Approvals
Type: Approval
AdminCc: {join ("\nAdminCc: ",@admins) }
Depended-On-By: {$Tickets{"TOP"}->Id}
Refers-To: {$Tickets{"TOP"}->Id}
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
my ($sval, $smsg) =$scrip->Create( ScripCondition => 'OnTransaction',
                ScripAction => 'CreateTickets',
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

# {{{ Scrip methods (Commit, Prepare)

# {{{ sub Commit 
#Do what we need to do and send it out.
sub Commit {
    my $self = shift;

    # Create all the tickets we care about

    $T::Tickets{'TOP'} = $self->TicketObj;

    foreach my $template_id ( @{ $self->{'template_order'} } ) {
        $RT::Logger->debug("Template id is $template_id");
        $RT::Logger->debug("Template content is ".$self->{'templates'}->{$template_id});

        
        $T::Tickets{$template_id} = RT::Ticket->new($RT::SystemUser);
        my $template = Text::Template->new(
                                  TYPE   => STRING,
                                  SOURCE => $self->{'templates'}->{$template_id}
        );

        my $filled_in = $template->fill_in( PACKAGE => T );
        my %args;
        my @lines = ( split ( /\n/, $filled_in ) );
        while ( my $line = shift @lines ) {
            if ( $line =~ /^(.*?):\s+(.*)$/ ) {
                my $value = $2;
                my $tag = lc ($1);
                $tag =~ s/-//g;
                    if (defined ($args{$tag})) { #if we're about to get a second value, make it an array
                        $args{$tag} = [$args{$tag}];
                    }
                    if (ref($args{$tag})) { #If it's an array, we want to push the value
                        push @{$args{$tag}}, $value;
                    }
                    else { #if there's nothing there, just set the value
                        $args{ $tag } = $value;
                    }

                if ( $tag eq 'content' ) { #just build up the content
                        # convert it to an array
                        $args{$tag} = [$args{$tag}."\n"];
                      while ( my $l =shift @lines) {
                        last if ($l =~  /^ENDOFCONTENT/) ;
                        push @{$args{'content'}}, $l."\n";
                        }
                }
            }
            }

            foreach my $date qw(due starts started resolved) {
                my $dateobj = RT::Date->new($RT::SystemUser);
                if ($args{$date} =~ /^\d+$/) {
                    $dateobj->Set(Format => 'unix', Value => $args{$date});
                } else {
                    $dateobj->Set(Format => 'unknown', Value => $args{$date});
                }
                $args{$date} = $dateobj->ISO;
            }
            my $mimeobj = MIME::Entity->new();
            $mimeobj->build(Type => $args{'contenttype'},
                            Data => $args{'content'});
            # Now we have a %args to work with. 
            # Make sure we have at least the minimum set of 
            # reasonable data and do our thang
            $T::Tickets{$template_id} = RT::Ticket->new($RT::SystemUser);
            %ticketargs = ( Queue => $args{'queue'},
                          Subject=> $args{'subject'},
                        Status => ($args{'status'}||'new'),
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
                        MemberOf => $args{'memberof'},
                        MIMEObj => $mimeobj);

    
            map {
                /^customfield-(\d+)$/
                  && ( $ticketargs{ "CustomField-" . $1 } = $args{$_} );
            } keys(%args);
            my ($id, $transid, $msg) = $T::Tickets{$template_id}->Create(%ticketargs);
             $RT::Logger->debug("Related ticket: $id - $msg");
            unless($id) {
                $RT::Logger->error("Couldn't create a related ticket for ".$self->TicketObj->Id." ".$msg);
            }

        }
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
 

    

my $template_id;
foreach my $line (split(/\n/,$self->TemplateObj->Content)) {
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

