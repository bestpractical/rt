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
# {{{ Front Material 

=head1 SYNOPSIS

  use RT::Ticket;
  my $ticket = new RT::Ticket($CurrentUser);
  $ticket->Load($ticket_id);

=head1 DESCRIPTION

This module lets you manipulate RT\'s ticket object.


=head1 METHODS

=begin testing

use_ok ( RT::Queue);
ok(my $testqueue = RT::Queue->new($RT::SystemUser));
ok($testqueue->Create( Name => 'ticket tests'));
ok($testqueue->Id != 0);
use_ok(RT::CustomField);
ok(my $testcf = RT::CustomField->new($RT::SystemUser));
ok($testcf->Create( Name => 'selectmulti',
                    Queue => $testqueue->id,
                               Type => 'SelectMultiple'));
ok($testcf->AddValue ( Name => 'Value1',
                        SortOrder => '1',
                        Description => 'A testing value'));
ok($testcf->AddValue ( Name => 'Value2',
                        SortOrder => '2',
                        Description => 'Another testing value'));
ok($testcf->AddValue ( Name => 'Value3',
                        SortOrder => '3',
                        Description => 'Yet Another testing value'));
                       
ok($testcf->Values->Count == 3);

use_ok(RT::Ticket);

my $u = RT::User->new($RT::SystemUser);
$u->Load("root");
ok ($u->Id, "Found the root user");
ok(my $t = RT::Ticket->new($RT::SystemUser));
ok(my ($id, $msg) = $t->Create( Queue => $testqueue->Id,
               Subject => 'Testing',
               Owner => $u->Id
              ));
ok($id != 0);
ok ($t->OwnerObj->Id == $u->Id, "Root is the ticket owner");
ok(my ($cfv, $cfm) =$t->AddCustomFieldValue(Field => $testcf->Id,
                           Value => 'Value1'));
ok($cfv != 0, "Custom field creation didn't return an error: $cfm");
ok($t->CustomFieldValues($testcf->Id)->Count == 1);
ok($t->CustomFieldValues($testcf->Id)->First &&
    $t->CustomFieldValues($testcf->Id)->First->Content eq 'Value1');;

ok(my ($cfdv, $cfdm) = $t->DeleteCustomFieldValue(Field => $testcf->Id,
                        Value => 'Value1'));
ok ($cfdv != 0, "Deleted a custom field value: $cfdm");
ok($t->CustomFieldValues($testcf->Id)->Count == 0);

ok(my $t2 = RT::Ticket->new($RT::SystemUser));
ok($t2->Load($id));
ok($t2->Subject eq 'Testing');
ok($t2->QueueObj->Id eq $testqueue->id);
ok($t2->OwnerObj->Id == $u->Id);

my $t3 = RT::Ticket->new($RT::SystemUser);
my ($id3, $msg3) = $t3->Create( Queue => $testqueue->Id,
                                Subject => 'Testing',
                                Owner => $u->Id);
my ($cfv1, $cfm1) = $t->AddCustomFieldValue(Field => $testcf->Id,
 Value => 'Value1');
ok($cfv1 != 0, "Adding a custom field to ticket 1 is successful: $cfm");
my ($cfv2, $cfm2) = $t3->AddCustomFieldValue(Field => $testcf->Id,
 Value => 'Value2');
ok($cfv2 != 0, "Adding a custom field to ticket 2 is successful: $cfm");
my ($cfv3, $cfm3) = $t->AddCustomFieldValue(Field => $testcf->Id,
 Value => 'Value3');
ok($cfv3 != 0, "Adding a custom field to ticket 1 is successful: $cfm");
ok($t->CustomFieldValues($testcf->Id)->Count == 2,
   "This ticket has 2 custom field values");
ok($t3->CustomFieldValues($testcf->Id)->Count == 1,
   "This ticket has 1 custom field value");

=end testing

=cut

use strict;
no warnings qw(redefine);

use RT::Queue;
use RT::User;
use RT::Record;
use RT::Links;
use RT::Date;
use RT::CustomFields;
use RT::TicketCustomFieldValues;
use RT::Tickets;
use RT::URI::fsck_com_rt;
use RT::URI;

=begin testing


ok(require RT::Ticket, "Loading the RT::Ticket library");

=end testing

=cut

# }}}

# {{{ LINKTYPEMAP
# A helper table for relationships mapping to make it easier
# to build and parse links between tickets

use vars '%LINKTYPEMAP';

%LINKTYPEMAP = (
    MemberOf => { Type => 'MemberOf',
                  Mode => 'Target', },
    Members => { Type => 'MemberOf',
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

# }}}

# {{{ LINKDIRMAP
# A helper table for relationships mapping to make it easier
# to build and parse links between tickets

use vars '%LINKDIRMAP';

%LINKDIRMAP = (
    MemberOf => { Base => 'MemberOf',
                  Target => 'HasMember', },
    RefersTo => { Base => 'RefersTo',
                Target => 'ReferredToBy', },
    DependsOn => { Base => 'DependsOn',
                   Target => 'DependedOnBy', },

);

# }}}

# {{{ sub Load

=head2 Load

Takes a single argument. This can be a ticket id, ticket alias or 
local ticket uri.  If the ticket can't be loaded, returns undef.
Otherwise, returns the ticket id.

=cut

sub Load {
    my $self = shift;
    my $id   = shift;

    #TODO modify this routine to look at EffectiveId and do the recursive load
    # thing. be careful to cache all the interim tickets we try so we don't loop forever.

    #If it's a local URI, turn it into a ticket id
    if ( $id =~ /^$RT::TicketBaseURI(\d+)$/ ) {
        $id = $1;
    }

    #If it's a remote URI, we're going to punt for now
    elsif ( $id =~ '://' ) {
        return (undef);
    }

    #If we have an integer URI, load the ticket
    if ( $id =~ /^\d+$/ ) {
        my $ticketid = $self->LoadById($id);

        unless ($ticketid) {
            $RT::Logger->debug("$self tried to load a bogus ticket: $id\n");
            return (undef);
        }
    }

    #It's not a URI. It's not a numerical ticket ID. Punt!
    else {
        return (undef);
    }

    #If we're merged, resolve the merge.
    if ( ( $self->EffectiveId ) and ( $self->EffectiveId != $self->Id ) ) {
        return ( $self->Load( $self->EffectiveId ) );
    }

    #Ok. we're loaded. lets get outa here.
    return ( $self->Id );

}

# }}}

# {{{ sub LoadByURI

=head2 LoadByURI

Given a local ticket URI, loads the specified ticket.

=cut

sub LoadByURI {
    my $self = shift;
    my $uri  = shift;

    if ( $uri =~ /^$RT::TicketBaseURI(\d+)$/ ) {
        my $id = $1;
        return ( $self->Load($id) );
    }
    else {
        return (undef);
    }
}

# }}}

# {{{ sub Create

=head2 Create (ARGS)

Arguments: ARGS is a hash of named parameters.  Valid parameters are:

  id 
  Queue  - Either a Queue object or a Queue Name
  Requestor -  A reference to a list of RT::User objects, email addresses or RT user Names
  Cc  - A reference to a list of RT::User objects, email addresses or Names
  AdminCc  - A reference to a  list of RT::User objects, email addresses or Names
  Type -- The ticket\'s type. ignore this for now
  Owner -- This ticket\'s owner. either an RT::User object or this user\'s id
  Subject -- A string describing the subject of the ticket
  InitialPriority -- an integer from 0 to 99
  FinalPriority -- an integer from 0 to 99
  Status -- any valid status (Defined in RT::Queue)
  TimeEstimated -- an integer. estimated time for this task in minutes
  TimeWorked -- an integer. time worked so far in minutes
  TimeLeft -- an integer. time remaining in minutes
  Starts -- an ISO date describing the ticket\'s start date and time in GMT
  Due -- an ISO date describing the ticket\'s due date and time in GMT
  MIMEObj -- a MIME::Entity object with the content of the initial ticket request.
  CustomField-<n> -- a scalar or array of values for the customfield with the id <n>


Returns: TICKETID, Transaction Object, Error Message


=begin testing

my $t = RT::Ticket->new($RT::SystemUser);

ok( $t->Create(Queue => 'General', Due => '2002-05-21 00:00:00', ReferredToBy => 'http://www.cpan.org', RefersTo => 'http://fsck.com', Subject => 'This is a subject'), "Ticket Created");

ok ( my $id = $t->Id, "Got ticket id");
ok ($t->RefersTo->First->Target =~ /fsck.com/, "Got refers to");
ok ($t->ReferredToBy->First->Base =~ /cpan.org/, "Got referredtoby");
ok ($t->ResolvedObj->Unix == -1, "It hasn't been resolved - ". $t->ResolvedObj->Unix);

=end testing

=cut

sub Create {
    my $self = shift;

    my %args = ( id              => undef,
                 Queue           => undef,
                 Requestor       => undef,
                 Cc              => undef,
                 AdminCc         => undef,
                 Type            => 'ticket',
                 Owner           => undef,
                 Subject         => '',
                 InitialPriority => undef,
                 FinalPriority   => undef,
                 Status          => 'new',
                 TimeWorked      => "0",
                 TimeLeft        => 0,
                 TimeEstimated        => 0,
                 Due             => undef,
                 Starts          => undef,
                 Started         => undef,
                 Resolved        => undef,
                 MIMEObj         => undef,
                 _RecordTransaction => 1,
                 


                 @_ );

    my ( $ErrStr, $Owner, $resolved );
    my (@non_fatal_errors);

    my $QueueObj = RT::Queue->new($RT::SystemUser);

    
    if ( ( defined( $args{'Queue'} ) ) && ( !ref( $args{'Queue'} ) ) ) {
        $QueueObj->Load( $args{'Queue'} );
    }
    elsif ( ref( $args{'Queue'} ) eq 'RT::Queue' ) {
        $QueueObj->Load( $args{'Queue'}->Id );
    }
    else {
        $RT::Logger->debug( $args{'Queue'} . " not a recognised queue object.");
    }
;

    #Can't create a ticket without a queue.
    unless ( defined($QueueObj) && $QueueObj->Id ) {
        $RT::Logger->debug("$self No queue given for ticket creation.");
        return ( 0, 0, $self->loc('Could not create ticket. Queue not set') );
    }

    #Now that we have a queue, Check the ACLS
    unless ( $self->CurrentUser->HasRight( Right    => 'CreateTicket',
                                                Object => $QueueObj )
      ) {
        return ( 0, 0,
                 $self->loc( "No permission to create tickets in the queue '[_1]'", $QueueObj->Name ) );
    }

    unless ( $QueueObj->IsValidStatus( $args{'Status'} ) ) {
        return ( 0, 0, $self->loc('Invalid value for status') );
    }


    #Since we have a queue, we can set queue defaults
    #Initial Priority

    # If there's no queue default initial priority and it's not set, set it to 0
    $args{'InitialPriority'} = ( $QueueObj->InitialPriority || 0 )
      unless ( defined $args{'InitialPriority'} );

    #Final priority 

    # If there's no queue default final priority and it's not set, set it to 0
    $args{'FinalPriority'} = ( $QueueObj->FinalPriority || 0 )
      unless ( defined $args{'FinalPriority'} );

    # {{{ Dates
    #TODO we should see what sort of due date we're getting, rather +
    # than assuming it's in ISO format.

    #Set the due date. if we didn't get fed one, use the queue default due in
    my $Due = new RT::Date( $self->CurrentUser );

    if ( $args{'Due'} ) {
        $Due->Set( Format => 'ISO', Value  => $args{'Due'} );
    }
    elsif (  $QueueObj->DefaultDueIn  ) {
        $Due->SetToNow;
        $Due->AddDays( $QueueObj->DefaultDueIn );
    }

    my $Starts = new RT::Date( $self->CurrentUser );
    if ( defined $args{'Starts'} ) {
        $Starts->Set( Format => 'ISO', Value  => $args{'Starts'} );
    }

    my $Started = new RT::Date( $self->CurrentUser );
    if ( defined $args{'Started'} ) {
        $Started->Set( Format => 'ISO', Value  => $args{'Started'} );
    }

    my $Resolved = new RT::Date( $self->CurrentUser );
    if ( defined $args{'Resolved'} ) {
        $Resolved->Set( Format => 'ISO', Value  => $args{'Resolved'} );
    }


    #If the status is an inactive status, set the resolved date
    if ($QueueObj->IsInactiveStatus($args{'Status'}) && !$args{'Resolved'}) {
        $RT::Logger->debug("Got a ".$args{'Status'} . "ticket with a resolved of ".$args{'Resolved'});
        $Resolved->SetToNow;
    }

    # }}}

    # {{{ Dealing with time fields

    $args{'TimeEstimated'} = 0 unless defined $args{'TimeEstimated'};
    $args{'TimeWorked'}    = 0 unless defined $args{'TimeWorked'};
    $args{'TimeLeft'}      = 0 unless defined $args{'TimeLeft'};

    # }}}

    # {{{ Deal with setting the owner

    if ( ref( $args{'Owner'} ) eq 'RT::User' ) {
        $Owner = $args{'Owner'};
    }

    #If we've been handed something else, try to load the user.
    elsif ( defined $args{'Owner'} ) {
        $Owner = RT::User->new( $self->CurrentUser );
        $Owner->Load( $args{'Owner'} );

    }

    #If we have a proposed owner and they don't have the right 
    #to own a ticket, scream about it and make them not the owner
    if (     ( defined($Owner) )
         and ( $Owner->Id )
         and ( $Owner->Id != $RT::Nobody->Id )
         and ( !$Owner->HasRight( Object => $QueueObj,
                                       Right    => 'OwnTicket' ) )
      ) {

        $RT::Logger->warning( "User "
                              . $Owner->Name . "("
                              . $Owner->id
                              . ") was proposed "
                              . "as a ticket owner but has no rights to own "
                              . "tickets in ".$QueueObj->Name );

        push @non_fatal_errors, $self->loc("Invalid owner. Defaulting to 'nobody'.");

        $Owner = undef;
    }

    #If we haven't been handed a valid owner, make it nobody.
    unless ( defined($Owner) && $Owner->Id ) {
        $Owner = new RT::User( $self->CurrentUser );
        $Owner->Load( $RT::Nobody->Id );
    }

    # }}}

    # We attempt to load or create each of the people who might have a role for this ticket
    # _outside_ the transaction, so we don't get into ticket creation races
    foreach my $type ( "Cc", "AdminCc", "Requestor" ) {
     next unless (defined $args{$type});
        foreach my $watcher ( ref( $args{$type} ) ? @{ $args{$type} } : ( $args{$type} ) ) {
        my $user = RT::User->new($RT::SystemUser);
        $user->LoadOrCreateByEmail($watcher) if ($watcher !~ /^\d+$/);
        }
    }


    $RT::Handle->BeginTransaction();

    my %params =( Queue           => $QueueObj->Id,
                                   Owner           => $Owner->Id,
                                   Subject         => $args{'Subject'},
                                   InitialPriority => $args{'InitialPriority'},
                                   FinalPriority   => $args{'FinalPriority'},
                                   Priority        => $args{'InitialPriority'},
                                   Status          => $args{'Status'},
                                   TimeWorked      => $args{'TimeWorked'},
                                   TimeEstimated   => $args{'TimeEstimated'},
                                   TimeLeft        => $args{'TimeLeft'},
                                   Type            => $args{'Type'},
                                   Starts          => $Starts->ISO,
                                   Started         => $Started->ISO,
                                   Resolved        => $Resolved->ISO,
                                   Due             => $Due->ISO );

    # Parameters passed in during an import that we probably don't want to touch, otherwise
    foreach my $attr qw(id Creator Created LastUpdated LastUpdatedBy) {
        $params{$attr} = $args{$attr} if ($args{$attr});
    }

    # Delete null integer parameters
    foreach my $attr qw(TimeWorked TimeLeft TimeEstimated InitialPriority FinalPriority) {
        delete $params{$attr}  unless (exists $params{$attr} && $params{$attr});
    }


    my $id = $self->SUPER::Create( %params);
    unless ($id) {
        $RT::Logger->crit( "Couldn't create a ticket");
        $RT::Handle->Rollback();
        return ( 0, 0, $self->loc( "Ticket could not be created due to an internal error") );
    }

    #Set the ticket's effective ID now that we've created it.
    my ( $val, $msg ) = $self->__Set( Field => 'EffectiveId', Value => $id );

    unless ($val) {
        $RT::Logger->crit("$self ->Create couldn't set EffectiveId: $msg\n");
        $RT::Handle->Rollback();
        return ( 0, 0, $self->loc( "Ticket could not be created due to an internal error") );
    }

    my $create_groups_ret = $self->_CreateTicketGroups();
    unless ($create_groups_ret) {
        $RT::Logger->crit( "Couldn't create ticket groups for ticket "
                           . $self->Id
                           . ". aborting Ticket creation." );
        $RT::Handle->Rollback();
        return ( 0, 0,
                 $self->loc( "Ticket could not be created due to an internal error") );
    }

    # Set the owner in the Groups table
    # We denormalize it into the Ticket table too because doing otherwise would 
    # kill performance, bigtime. It gets kept in lockstep thanks to the magic of transactionalization

    $self->OwnerGroup->_AddMember( PrincipalId => $Owner->PrincipalId , InsideTransaction => 1);

    # {{{ Deal with setting up watchers


    foreach my $type ( "Cc", "AdminCc", "Requestor" ) {
        next unless (defined $args{$type});
        foreach my $watcher ( ref( $args{$type} ) ? @{ $args{$type} } : ( $args{$type} ) ) {

	    # we reason that all-digits number must be a principal id, not email
	    # this is the only way to can add
	    my $field = 'Email';
	    $field = 'PrincipalId' if $watcher =~ /^\d+$/;

	    my ( $wval, $wmsg );

            if ( $type eq 'AdminCc' ) {

                # Note that we're using AddWatcher, rather than _AddWatcher, as we 
                # actually _want_ that ACL check. Otherwise, random ticket creators
                # could make themselves adminccs and maybe get ticket rights. that would
                # be poor
                ( $wval, $wmsg ) = $self->AddWatcher( Type   => $type,
                                                         $field => $watcher,
                                                         Silent => 1 );
            }
            else {
                ( $wval, $wmsg ) = $self->_AddWatcher( Type   => $type,
                                                          $field => $watcher,
                                                          Silent => 1 );
            }

            push @non_fatal_errors, $wmsg unless ($wval);
        }
    }

    # }}}
    # {{{ Deal with setting up links


    foreach my $type ( keys %LINKTYPEMAP ) {
        next unless (defined $args{$type});
        foreach my $link (
            ref( $args{$type} ) ? @{ $args{$type} } : ( $args{$type} ) )
        {
            my ( $wval, $wmsg ) = $self->AddLink(
                Type                          => $LINKTYPEMAP{$type}->{'Type'},
                $LINKTYPEMAP{$type}->{'Mode'} => $link,
                Silent                        => 1
            );

            push @non_fatal_errors, $wmsg unless ($wval);
        }
    }

    # }}}

   # {{{ Add all the custom fields 

    foreach my $arg ( keys %args ) {
    next unless ( $arg =~ /^CustomField-(\d+)$/i );
    my $cfid = $1;
    foreach
      my $value ( ref( $args{$arg} ) ? @{ $args{$arg} } : ( $args{$arg} ) ) {
        next unless ($value);
        $self->_AddCustomFieldValue( Field => $cfid,
                                     Value => $value,
                                     RecordTransaction => 0
                                 );
    }
    }
    # }}}

    if ( $args{'_RecordTransaction'} ) {
        # {{{ Add a transaction for the create
        my ( $Trans, $Msg, $TransObj ) = $self->_NewTransaction(
                                                     Type      => "Create",
                                                     TimeTaken => 0,
                                                     MIMEObj => $args{'MIMEObj'}
        );


        if ( $self->Id && $Trans ) {
            $ErrStr = $self->loc( "Ticket [_1] created in queue '[_2]'", $self->Id, $QueueObj->Name );
            $ErrStr = join ( "\n", $ErrStr, @non_fatal_errors );

            $RT::Logger->info("Ticket ".$self->Id. " created in queue '".$QueueObj->Name."' by ".$self->CurrentUser->Name);
        }
        else {
            $RT::Handle->Rollback();

            # TODO where does this get errstr from?
            $RT::Logger->error("Ticket couldn't be created: $ErrStr");
            return ( 0, 0, $self->loc( "Ticket could not be created due to an internal error"));
        }

        $RT::Handle->Commit();
        return ( $self->Id, $TransObj->Id, $ErrStr );
        # }}}
    }
    else {

        # Not going to record a transaction
        $RT::Handle->Commit();
        $ErrStr = $self->loc( "Ticket [_1] created in queue '[_2]'", $self->Id, $QueueObj->Name );
        $ErrStr = join ( "\n", $ErrStr, @non_fatal_errors );
        return ( $self->Id, $0, $ErrStr );

    }
}


# }}}

# {{{ sub CreateFromEmailMessage


=head2 CreateFromEmailMessage { Message, Queue, ExtractActorFromHeaders } 

This code replaces what was once a large part of the email gateway.
It takes an email message as a parameter, parses out the sender, subject
and a MIME object. It then creates a ticket based on those attributes

=cut

sub CreateFromEmailMessage {
    my $self = shift;
    my %args = ( Message => undef,
                 Queue => undef,
                 ExtractActorFromSender => undef,
                 @_ );

    
    # Pull out requestor

    # Pull out Cc?

    # 


}

# }}}


# {{{ CreateFrom822

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
by repeating the fieldname on a new line with an additional value.


When parsed, field names are converted to lowercase and have -s stripped.
Refers-To, RefersTo, refersto, refers-to and r-e-f-er-s-tO will all 
be treated as the same thing.


=begin testing

use_ok(RT::Ticket);

=end testing


=cut

sub CreateFrom822 {
    my $self    = shift;
    my $content = shift;



    my %args = $self->_Parse822HeadersForAttributes($content);

    # Now we have a %args to work with.
    # Make sure we have at least the minimum set of
    # reasonable data and do our thang
    my $ticket = RT::Ticket->new($RT::SystemUser);

    my %ticketargs = (
        Queue           => $args{'queue'},
        Subject         => $args{'subject'},
        Status          => $args{'status'},
        Due             => $args{'due'},
        Starts          => $args{'starts'},
        Started         => $args{'started'},
        Resolved        => $args{'resolved'},
        Owner           => $args{'owner'},
        Requestor       => $args{'requestor'},
        Cc              => $args{'cc'},
        AdminCc         => $args{'admincc'},
        TimeWorked      => $args{'timeworked'},
        TimeEstimated   => $args{'timeestimated'},
        TimeLeft        => $args{'timeleft'},
        InitialPriority => $args{'initialpriority'},
        FinalPriority   => $args{'finalpriority'},
        Type            => $args{'type'},
        DependsOn       => $args{'dependson'},
        DependedOnBy    => $args{'dependedonby'},
        RefersTo        => $args{'refersto'},
        ReferredToBy    => $args{'referredtoby'},
        Members         => $args{'members'},
        MemberOf        => $args{'memberof'},
        MIMEObj         => $args{'mimeobj'}
    );

    # Add custom field entries to %ticketargs.
    # TODO: allow named custom fields
    map {
        /^customfield-(\d+)$/
          && ( $ticketargs{ "CustomField-" . $1 } = $args{$_} );
    } keys(%args);

    my ( $id, $transid, $msg ) = $ticket->Create(%ticketargs);
    unless ($id) {
        $RT::Logger->error( "Couldn't create a related ticket for "
              . $self->TicketObj->Id . " "
              . $msg );
    }

    return (1);
}

# }}}

# {{{ UpdateFrom822 

=head2 UpdateFrom822 $MESSAGE

Takes an RFC822 format message as a string and uses it to make a bunch of changes to a ticket.
Returns an um. ask me again when the code exists


=begin testing

my $simple_update = <<EOF;
Subject: target
AddRequestor: jesse\@example.com
EOF

my $ticket = RT::Ticket->new($RT::SystemUser);
$ticket->Create(Subject => 'first', Queue => 'general');
ok($ticket->Id, "Created the test ticket");
$ticket->UpdateFrom822($simple_update);
is($ticket->Subject, 'target', "changed the subject");
my $jesse = RT::User->new($RT::SystemUser);
$jesse->LoadByEmail('jesse@example.com');
ok ($jesse->Id, "There's a user for jesse");
ok($ticket->Requestors->HasMember( $jesse->PrincipalObj), "It has the jesse principal object as a requestor ");

=end testing


=cut

sub UpdateFrom822 {
        my $self = shift;
        my $content = shift;
        my %args = $self->_Parse822HeadersForAttributes($content);

        
    my %ticketargs = (
        Queue           => $args{'queue'},
        Subject         => $args{'subject'},
        Status          => $args{'status'},
        Due             => $args{'due'},
        Starts          => $args{'starts'},
        Started         => $args{'started'},
        Resolved        => $args{'resolved'},
        Owner           => $args{'owner'},
        Requestor       => $args{'requestor'},
        Cc              => $args{'cc'},
        AdminCc         => $args{'admincc'},
        TimeWorked      => $args{'timeworked'},
        TimeEstimated   => $args{'timeestimated'},
        TimeLeft        => $args{'timeleft'},
        InitialPriority => $args{'initialpriority'},
        Priority => $args{'priority'},
        FinalPriority   => $args{'finalpriority'},
        Type            => $args{'type'},
        DependsOn       => $args{'dependson'},
        DependedOnBy    => $args{'dependedonby'},
        RefersTo        => $args{'refersto'},
        ReferredToBy    => $args{'referredtoby'},
        Members         => $args{'members'},
        MemberOf        => $args{'memberof'},
        MIMEObj         => $args{'mimeobj'}
    );

    foreach my $type qw(Requestor Cc Admincc) {

        foreach my $action ( 'Add', 'Del', '' ) {

            my $lctag = lc($action) . lc($type);
            foreach my $list ( $args{$lctag}, $args{ $lctag . 's' } ) {

                foreach my $entry ( ref($list) ? @{$list} : ($list) ) {
                    push @{$ticketargs{ $action . $type }} , split ( /\s*,\s*/, $entry );
                }

            }

            # Todo: if we're given an explicit list, transmute it into a list of adds/deletes

        }
    }

    # Add custom field entries to %ticketargs.
    # TODO: allow named custom fields
    map {
        /^customfield-(\d+)$/
          && ( $ticketargs{ "CustomField-" . $1 } = $args{$_} );
    } keys(%args);

# for each ticket we've been told to update, iterate through the set of
# rfc822 headers and perform that update to the ticket.


    # {{{ Set basic fields 
    my @attribs = qw(
      Subject
      FinalPriority
      Priority
      TimeEstimated
      TimeWorked
      TimeLeft
      Status
      Queue
      Type
    );


    # Resolve the queue from a name to a numeric id.
    if ( $ticketargs{'Queue'} and ( $ticketargs{'Queue'} !~ /^(\d+)$/ ) ) {
        my $tempqueue = RT::Queue->new($RT::SystemUser);
        $tempqueue->Load( $ticketargs{'Queue'} );
        $ticketargs{'Queue'} = $tempqueue->Id() if ( $tempqueue->id );
    }

    # die "updaterecordobject is a webui thingy";
    my @results;

    foreach my $attribute (@attribs) {
        my $value = $ticketargs{$attribute};

        if ( $value ne $self->$attribute() ) {

            my $method = "Set$attribute";
            my ( $code, $msg ) = $self->$method($value);

            push @results, $self->loc($attribute) . ': ' . $msg;

        }
    }

    # We special case owner changing, so we can use ForceOwnerChange
    if ( $ticketargs{'Owner'} && ( $self->Owner != $ticketargs{'Owner'} ) ) {
        my $ChownType = "Give";
        $ChownType = "Force" if ( $ticketargs{'ForceOwnerChange'} );

        my ( $val, $msg ) = $self->SetOwner( $ticketargs{'Owner'}, $ChownType );
        push ( @results, $msg );
    }

    # }}}
# Deal with setting watchers


# Acceptable arguments:
#  Requestor
#  Requestors
#  AddRequestor
#  AddRequestors
#  DelRequestor
 
 foreach my $type qw(Requestor Cc AdminCc) {

        # If we've been given a number of delresses to del, do it.
                foreach my $address (@{$ticketargs{'Del'.$type}}) {
                my ($id, $msg) = $self->DelWatcher( Type => $type, Email => $address);
                push (@results, $msg) ;
                }

        # If we've been given a number of addresses to add, do it.
                foreach my $address (@{$ticketargs{'Add'.$type}}) {
                $RT::Logger->debug("Adding $address as a $type");
                my ($id, $msg) = $self->AddWatcher( Type => $type, Email => $address);
                push (@results, $msg) ;

        }


}


}
# }}}

# {{{ _Parse822HeadersForAttributes Content

=head2 _Parse822HeadersForAttributes Content

Takes an RFC822 style message and parses its attributes into a hash.

=cut

sub _Parse822HeadersForAttributes {
    my $self    = shift;
    my $content = shift;
    my %args;

    my @lines = ( split ( /\n/, $content ) );
    while ( defined( my $line = shift @lines ) ) {
        if ( $line =~ /^(.*?):(?:\s+(.*))?$/ ) {
            my $value = $2;
            my $tag   = lc($1);

            $tag =~ s/-//g;
            if ( defined( $args{$tag} ) )
            {    #if we're about to get a second value, make it an array
                $args{$tag} = [ $args{$tag} ];
            }
            if ( ref( $args{$tag} ) )
            {    #If it's an array, we want to push the value
                push @{ $args{$tag} }, $value;
            }
            else {    #if there's nothing there, just set the value
                $args{$tag} = $value;
            }
        } elsif ($line =~ /^$/) {

            #TODO: this won't work, since "" isn't of the form "foo:value"

                while ( defined( my $l = shift @lines ) ) {
                    push @{ $args{'content'} }, $l;
                }
            }
        
    }

    foreach my $date qw(due starts started resolved) {
        my $dateobj = RT::Date->new($RT::SystemUser);
        if ( $args{$date} =~ /^\d+$/ ) {
            $dateobj->Set( Format => 'unix', Value => $args{$date} );
        }
        else {
            $dateobj->Set( Format => 'unknown', Value => $args{$date} );
        }
        $args{$date} = $dateobj->ISO;
    }
    $args{'mimeobj'} = MIME::Entity->new();
    $args{'mimeobj'}->build(
        Type => ( $args{'contenttype'} || 'text/plain' ),
        Data => ($args{'content'} || '')
    );

    return (%args);
}

# }}}

# {{{ sub Import

=head2 Import PARAMHASH

Import a ticket. 
Doesn\'t create a transaction. 
Doesn\'t supply queue defaults, etc.

Returns: TICKETID

=cut

sub Import {
    my $self = shift;
    my ( $ErrStr, $QueueObj, $Owner );

    my %args = (
        id              => undef,
        EffectiveId     => undef,
        Queue           => undef,
        Requestor       => undef,
        Type            => 'ticket',
        Owner           => $RT::Nobody->Id,
        Subject         => '[no subject]',
        InitialPriority => undef,
        FinalPriority   => undef,
        Status          => 'new',
        TimeWorked      => "0",
        Due             => undef,
        Created         => undef,
        Updated         => undef,
        Resolved        => undef,
        Told            => undef,
        @_
    );

    if ( ( defined( $args{'Queue'} ) ) && ( !ref( $args{'Queue'} ) ) ) {
        $QueueObj = RT::Queue->new($RT::SystemUser);
        $QueueObj->Load( $args{'Queue'} );

        #TODO error check this and return 0 if it\'s not loading properly +++
    }
    elsif ( ref( $args{'Queue'} ) eq 'RT::Queue' ) {
        $QueueObj = RT::Queue->new($RT::SystemUser);
        $QueueObj->Load( $args{'Queue'}->Id );
    }
    else {
        $RT::Logger->debug(
            "$self " . $args{'Queue'} . " not a recognised queue object." );
    }

    #Can't create a ticket without a queue.
    unless ( defined($QueueObj) and $QueueObj->Id ) {
        $RT::Logger->debug("$self No queue given for ticket creation.");
        return ( 0, $self->loc('Could not create ticket. Queue not set') );
    }

    #Now that we have a queue, Check the ACLS
    unless (
        $self->CurrentUser->HasRight(
            Right    => 'CreateTicket',
            Object => $QueueObj
        )
      )
    {
        return ( 0,
            $self->loc("No permission to create tickets in the queue '[_1]'"
              , $QueueObj->Name));
    }

    # {{{ Deal with setting the owner

    # Attempt to take user object, user name or user id.
    # Assign to nobody if lookup fails.
    if ( defined( $args{'Owner'} ) ) {
        if ( ref( $args{'Owner'} ) ) {
            $Owner = $args{'Owner'};
        }
        else {
            $Owner = new RT::User( $self->CurrentUser );
            $Owner->Load( $args{'Owner'} );
            if ( !defined( $Owner->id ) ) {
                $Owner->Load( $RT::Nobody->id );
            }
        }
    }

    #If we have a proposed owner and they don't have the right 
    #to own a ticket, scream about it and make them not the owner
    if (
        ( defined($Owner) )
        and ( $Owner->Id != $RT::Nobody->Id )
        and (
            !$Owner->HasRight(
                Object => $QueueObj,
                Right    => 'OwnTicket'
            )
        )
      )
    {

        $RT::Logger->warning( "$self user "
              . $Owner->Name . "("
              . $Owner->id
              . ") was proposed "
              . "as a ticket owner but has no rights to own "
              . "tickets in '"
              . $QueueObj->Name . "'\n" );

        $Owner = undef;
    }

    #If we haven't been handed a valid owner, make it nobody.
    unless ( defined($Owner) ) {
        $Owner = new RT::User( $self->CurrentUser );
        $Owner->Load( $RT::Nobody->UserObj->Id );
    }

    # }}}

    unless ( $self->ValidateStatus( $args{'Status'} ) ) {
        return ( 0, $self->loc("'[_1]' is an invalid value for status", $args{'Status'}) );
    }

    $self->{'_AccessibleCache'}{Created}       = { 'read' => 1, 'write' => 1 };
    $self->{'_AccessibleCache'}{Creator}       = { 'read' => 1, 'auto'  => 1 };
    $self->{'_AccessibleCache'}{LastUpdated}   = { 'read' => 1, 'write' => 1 };
    $self->{'_AccessibleCache'}{LastUpdatedBy} = { 'read' => 1, 'auto'  => 1 };

    # If we're coming in with an id, set that now.
    my $EffectiveId = undef;
    if ( $args{'id'} ) {
        $EffectiveId = $args{'id'};

    }

    my $id = $self->SUPER::Create(
        id              => $args{'id'},
        EffectiveId     => $EffectiveId,
        Queue           => $QueueObj->Id,
        Owner           => $Owner->Id,
        Subject         => $args{'Subject'},		# loc
        InitialPriority => $args{'InitialPriority'},	# loc
        FinalPriority   => $args{'FinalPriority'},	# loc
        Priority        => $args{'InitialPriority'},	# loc
        Status          => $args{'Status'},		# loc
        TimeWorked      => $args{'TimeWorked'},		# loc
        Type            => $args{'Type'},		# loc
        Created         => $args{'Created'},		# loc
        Told            => $args{'Told'},		# loc
        LastUpdated     => $args{'Updated'},		# loc
        Resolved        => $args{'Resolved'},		# loc
        Due             => $args{'Due'},		# loc
    );

    # If the ticket didn't have an id
    # Set the ticket's effective ID now that we've created it.
    if ( $args{'id'} ) {
        $self->Load( $args{'id'} );
    }
    else {
        my ( $val, $msg ) =
          $self->__Set( Field => 'EffectiveId', Value => $id );

        unless ($val) {
            $RT::Logger->err(
                $self . "->Import couldn't set EffectiveId: $msg\n" );
        }
    }

    my $watcher;
    foreach $watcher ( @{ $args{'Cc'} } ) {
        $self->_AddWatcher( Type => 'Cc', Person => $watcher, Silent => 1 );
    }
    foreach $watcher ( @{ $args{'AdminCc'} } ) {
        $self->_AddWatcher( Type => 'AdminCc', Person => $watcher,
            Silent => 1 );
    }
    foreach $watcher ( @{ $args{'Requestor'} } ) {
        $self->_AddWatcher( Type => 'Requestor', Person => $watcher,
            Silent => 1 );
    }

    return ( $self->Id, $ErrStr );
}

# }}}


# {{{ Routines dealing with watchers.

# {{{ _CreateTicketGroups 

=head2 _CreateTicketGroups

Create the ticket groups and relationships for this ticket. 
This routine expects to be called from Ticket->Create _inside of a transaction_

It will create four groups for this ticket: Requestor, Cc, AdminCc and Owner.

It will return true on success and undef on failure.

=begin testing

my $ticket = RT::Ticket->new($RT::SystemUser);
my ($id, $msg) = $ticket->Create(Subject => "Foo",
                Owner => $RT::SystemUser->Id,
                Status => 'open',
                Requestor => ['jesse@example.com'],
                Queue => '1'
                );
ok ($id, "Ticket $id was created");
ok(my $group = RT::Group->new($RT::SystemUser));
ok($group->LoadTicketRoleGroup(Ticket => $id, Type=> 'Requestor'));
ok ($group->Id, "Found the requestors object for this ticket");

ok(my $jesse = RT::User->new($RT::SystemUser), "Creating a jesse rt::user");
$jesse->LoadByEmail('jesse@example.com');
ok($jesse->Id,  "Found the jesse rt user");


ok ($ticket->IsWatcher(Type => 'Requestor', PrincipalId => $jesse->PrincipalId), "The ticket actually has jesse at fsck.com as a requestor");
ok ((my $add_id, $add_msg) = $ticket->AddWatcher(Type => 'Requestor', Email => 'bob@fsck.com'), "Added bob at fsck.com as a requestor");
ok ($add_id, "Add succeeded: ($add_msg)");
ok(my $bob = RT::User->new($RT::SystemUser), "Creating a bob rt::user");
$bob->LoadByEmail('bob@fsck.com');
ok($bob->Id,  "Found the bob rt user");
ok ($ticket->IsWatcher(Type => 'Requestor', PrincipalId => $bob->PrincipalId), "The ticket actually has bob at fsck.com as a requestor");;
ok ((my $add_id, $add_msg) = $ticket->DeleteWatcher(Type =>'Requestor', Email => 'bob@fsck.com'), "Added bob at fsck.com as a requestor");
ok (!$ticket->IsWatcher(Type => 'Requestor', Principal => $bob->PrincipalId), "The ticket no longer has bob at fsck.com as a requestor");;


$group = RT::Group->new($RT::SystemUser);
ok($group->LoadTicketRoleGroup(Ticket => $id, Type=> 'Cc'));
ok ($group->Id, "Found the cc object for this ticket");
$group = RT::Group->new($RT::SystemUser);
ok($group->LoadTicketRoleGroup(Ticket => $id, Type=> 'AdminCc'));
ok ($group->Id, "Found the AdminCc object for this ticket");
$group = RT::Group->new($RT::SystemUser);
ok($group->LoadTicketRoleGroup(Ticket => $id, Type=> 'Owner'));
ok ($group->Id, "Found the Owner object for this ticket");
ok($group->HasMember($RT::SystemUser->UserObj->PrincipalObj), "the owner group has the member 'RT_System'");

=end testing

=cut


sub _CreateTicketGroups {
    my $self = shift;
    
    my @types = qw(Requestor Owner Cc AdminCc);

    foreach my $type (@types) {
        my $type_obj = RT::Group->new($self->CurrentUser);
        my ($id, $msg) = $type_obj->CreateRoleGroup(Domain => 'RT::Ticket-Role',
                                                       Instance => $self->Id, 
                                                       Type => $type);
        unless ($id) {
            $RT::Logger->error("Couldn't create a ticket group of type '$type' for ticket ".
                               $self->Id.": ".$msg);     
            return(undef);
        }
     }
    return(1);
    
}

# }}}

# {{{ sub OwnerGroup

=head2 OwnerGroup

A constructor which returns an RT::Group object containing the owner of this ticket.

=cut

sub OwnerGroup {
    my $self = shift;
    my $owner_obj = RT::Group->new($self->CurrentUser);
    $owner_obj->LoadTicketRoleGroup( Ticket => $self->Id,  Type => 'Owner');
    return ($owner_obj);
}

# }}}


# {{{ sub AddWatcher

=head2 AddWatcher

AddWatcher takes a parameter hash. The keys are as follows:

Type        One of Requestor, Cc, AdminCc

PrinicpalId The RT::Principal id of the user or group that's being added as a watcher

Email       The email address of the new watcher. If a user with this 
            email address can't be found, a new nonprivileged user will be created.

If the watcher you\'re trying to set has an RT account, set the Owner paremeter to their User Id. Otherwise, set the Email parameter to their Email address.

=cut

sub AddWatcher {
    my $self = shift;
    my %args = (
        Type  => undef,
        PrincipalId => undef,
        Email => undef,
        @_
    );

    # {{{ Check ACLS
    #If the watcher we're trying to add is for the current user
    if ( $self->CurrentUser->PrincipalId  eq $args{'PrincipalId'}) {
        #  If it's an AdminCc and they don't have 
        #   'WatchAsAdminCc' or 'ModifyTicket', bail
        if ( $args{'Type'} eq 'AdminCc' ) {
            unless ( $self->CurrentUserHasRight('ModifyTicket')
                or $self->CurrentUserHasRight('WatchAsAdminCc') ) {
                return ( 0, $self->loc('Permission Denied'))
            }
        }

        #  If it's a Requestor or Cc and they don't have
        #   'Watch' or 'ModifyTicket', bail
        elsif ( ( $args{'Type'} eq 'Cc' ) or ( $args{'Type'} eq 'Requestor' ) ) {

            unless ( $self->CurrentUserHasRight('ModifyTicket')
                or $self->CurrentUserHasRight('Watch') ) {
                return ( 0, $self->loc('Permission Denied'))
            }
        }
        else {
            $RT::Logger->warn( "$self -> AddWatcher got passed a bogus type");
            return ( 0, $self->loc('Error in parameters to Ticket->AddWatcher') );
        }
    }

    # If the watcher isn't the current user 
    # and the current user  doesn't have 'ModifyTicket'
    # bail
    else {
        unless ( $self->CurrentUserHasRight('ModifyTicket') ) {
            return ( 0, $self->loc("Permission Denied") );
        }
    }

    # }}}

    return ( $self->_AddWatcher(%args) );
}

#This contains the meat of AddWatcher. but can be called from a routine like
# Create, which doesn't need the additional acl check
sub _AddWatcher {
    my $self = shift;
    my %args = (
        Type   => undef,
        Silent => undef,
        PrincipalId => undef,
        Email => undef,
        @_
    );


    my $principal = RT::Principal->new($self->CurrentUser);
    if ($args{'Email'}) {
        my $user = RT::User->new($RT::SystemUser);
        my ($pid, $msg) = $user->LoadOrCreateByEmail($args{'Email'});
        if ($pid) {
            $args{'PrincipalId'} = $pid; 
        }
    }
    if ($args{'PrincipalId'}) {
        $principal->Load($args{'PrincipalId'});
    } 

 
    # If we can't find this watcher, we need to bail.
    unless ($principal->Id) {
            $RT::Logger->error("Could not load create a user with the email address '".$args{'Email'}. "' to add as a watcher for ticket ".$self->Id);
        return(0, $self->loc("Could not find or create that user"));
    }


    my $group = RT::Group->new($self->CurrentUser);
    $group->LoadTicketRoleGroup(Type => $args{'Type'}, Ticket => $self->Id);
    unless ($group->id) {
        return(0,$self->loc("Group not found"));
    }

    if ( $group->HasMember( $principal)) {

        return ( 0, $self->loc('That principal is already a [_1] for this ticket', $self->loc($args{'Type'})) );
    }


    my ( $m_id, $m_msg ) = $group->_AddMember( PrincipalId => $principal->Id,
                                               InsideTransaction => 1 );
    unless ($m_id) {
        $RT::Logger->error("Failed to add ".$principal->Id." as a member of group ".$group->Id."\n".$m_msg);

        return ( 0, $self->loc('Could not make that principal a [_1] for this ticket', $self->loc($args{'Type'})) );
    }

    unless ( $args{'Silent'} ) {
        $self->_NewTransaction(
            Type     => 'AddWatcher',
            NewValue => $principal->Id,
            Field    => $args{'Type'}
        );
    }

        return ( 1, $self->loc('Added principal as a [_1] for this ticket', $self->loc($args{'Type'})) );
}

# }}}


# {{{ sub DeleteWatcher

=head2 DeleteWatcher { Type => TYPE, PrincipalId => PRINCIPAL_ID, Email => EMAIL_ADDRESS }


Deletes a Ticket watcher.  Takes two arguments:

Type  (one of Requestor,Cc,AdminCc)

and one of

PrincipalId (an RT::Principal Id of the watcher you want to remove)
    OR
Email (the email address of an existing wathcer)


=cut


sub DeleteWatcher {
    my $self = shift;

    my %args = ( Type => undef,
                 PrincipalId => undef,
                 Email => undef,
                 @_ );

    unless ($args{'PrincipalId'} || $args{'Email'} ) {
        return(0, $self->loc("No principal specified"));
    }
    my $principal = RT::Principal->new($self->CurrentUser);
    if ($args{'PrincipalId'} ) {

        $principal->Load($args{'PrincipalId'});
    } else {
        my $user = RT::User->new($self->CurrentUser);
        $user->LoadByEmail($args{'Email'});
        $principal->Load($user->Id);
    }
    # If we can't find this watcher, we need to bail.
    unless ($principal->Id) {
        return(0, $self->loc("Could not find that principal"));
    }

    my $group = RT::Group->new($self->CurrentUser);
    $group->LoadTicketRoleGroup(Type => $args{'Type'}, Ticket => $self->Id);
    unless ($group->id) {
        return(0,$self->loc("Group not found"));
    }

    # {{{ Check ACLS
    #If the watcher we're trying to add is for the current user
    if ( $self->CurrentUser->PrincipalId  eq $args{'PrincipalId'}) {
        #  If it's an AdminCc and they don't have 
        #   'WatchAsAdminCc' or 'ModifyTicket', bail
        if ( $args{'Type'} eq 'AdminCc' ) {
            unless ( $self->CurrentUserHasRight('ModifyTicket')
                or $self->CurrentUserHasRight('WatchAsAdminCc') ) {
                return ( 0, $self->loc('Permission Denied'))
            }
        }

        #  If it's a Requestor or Cc and they don't have
        #   'Watch' or 'ModifyTicket', bail
        elsif ( ( $args{'Type'} eq 'Cc' ) or ( $args{'Type'} eq 'Requestor' ) ) {
            unless ( $self->CurrentUserHasRight('ModifyTicket')
                or $self->CurrentUserHasRight('Watch') ) {
                return ( 0, $self->loc('Permission Denied'))
            }
        }
        else {
            $RT::Logger->warn( "$self -> DeleteWatcher got passed a bogus type");
            return ( 0, $self->loc('Error in parameters to Ticket->DelWatcher') );
        }
    }

    # If the watcher isn't the current user 
    # and the current user  doesn't have 'ModifyTicket' bail
    else {
        unless ( $self->CurrentUserHasRight('ModifyTicket') ) {
            return ( 0, $self->loc("Permission Denied") );
        }
    }

    # }}}


    # see if this user is already a watcher.

    unless ( $group->HasMember($principal)) {
        return ( 0, 
        $self->loc('That principal is not a [_1] for this ticket', $args{'Type'}) );
    }

    my ($m_id, $m_msg) = $group->_DeleteMember($principal->Id);
    unless ($m_id) {
        $RT::Logger->error("Failed to delete ".$principal->Id.
                           " as a member of group ".$group->Id."\n".$m_msg);

        return ( 0,    $self->loc('Could not remove that principal as a [_1] for this ticket', $args{'Type'}) );
    }

    unless ( $args{'Silent'} ) {
        $self->_NewTransaction(
            Type     => 'DelWatcher',
            OldValue => $principal->Id,
            Field    => $args{'Type'}
        );
    }

    return ( 1, $self->loc("[_1] is no longer a [_2] for this ticket.", $principal->Object->Name, $args{'Type'} ));
}




# }}}


# {{{ a set of  [foo]AsString subs that will return the various sorts of watchers for a ticket/queue as a comma delineated string

=head2 RequestorAddresses

 B<Returns> String: All Ticket Requestor email addresses as a string.

=cut

sub RequestorAddresses {
    my $self = shift;

    unless ( $self->CurrentUserHasRight('ShowTicket') ) {
        return undef;
    }

    return ( $self->Requestors->MemberEmailAddressesAsString );
}


=head2 AdminCcAddresses

returns String: All Ticket AdminCc email addresses as a string

=cut

sub AdminCcAddresses {
    my $self = shift;

    unless ( $self->CurrentUserHasRight('ShowTicket') ) {
        return undef;
    }

    return ( $self->AdminCc->MemberEmailAddressesAsString )

}

=head2 CcAddresses

returns String: All Ticket Ccs as a string of email addresses

=cut

sub CcAddresses {
    my $self = shift;

    unless ( $self->CurrentUserHasRight('ShowTicket') ) {
        return undef;
    }

    return ( $self->Cc->MemberEmailAddressesAsString);

}

# }}}

# {{{ Routines that return RT::Watchers objects of Requestors, Ccs and AdminCcs

# {{{ sub Requestors

=head2 Requestors

Takes nothing.
Returns this ticket's Requestors as an RT::Group object

=cut

sub Requestors {
    my $self = shift;

    my $group = RT::Group->new($self->CurrentUser);
    if ( $self->CurrentUserHasRight('ShowTicket') ) {
        $group->LoadTicketRoleGroup(Type => 'Requestor', Ticket => $self->Id);
    }
    return ($group);

}

# }}}

# {{{ sub Cc

=head2 Cc

Takes nothing.
Returns an RT::Group object which contains this ticket's Ccs.
If the user doesn't have "ShowTicket" permission, returns an empty group

=cut

sub Cc {
    my $self = shift;

    my $group = RT::Group->new($self->CurrentUser);
    if ( $self->CurrentUserHasRight('ShowTicket') ) {
        $group->LoadTicketRoleGroup(Type => 'Cc', Ticket => $self->Id);
    }
    return ($group);

}

# }}}

# {{{ sub AdminCc

=head2 AdminCc

Takes nothing.
Returns an RT::Group object which contains this ticket's AdminCcs.
If the user doesn't have "ShowTicket" permission, returns an empty group

=cut

sub AdminCc {
    my $self = shift;

    my $group = RT::Group->new($self->CurrentUser);
    if ( $self->CurrentUserHasRight('ShowTicket') ) {
        $group->LoadTicketRoleGroup(Type => 'AdminCc', Ticket => $self->Id);
    }
    return ($group);

}

# }}}

# }}}

# {{{ IsWatcher,IsRequestor,IsCc, IsAdminCc

# {{{ sub IsWatcher
# a generic routine to be called by IsRequestor, IsCc and IsAdminCc

=head2 IsWatcher { Type => TYPE, PrincipalId => PRINCIPAL_ID, Email => EMAIL }

Takes a param hash with the attributes Type and either PrincipalId or Email

Type is one of Requestor, Cc, AdminCc and Owner

PrincipalId is an RT::Principal id, and Email is an email address.

Returns true if the specified principal (or the one corresponding to the
specified address) is a member of the group Type for this ticket.

=cut

sub IsWatcher {
    my $self = shift;

    my %args = ( Type  => 'Requestor',
        PrincipalId    => undef,
        Email          => undef,
        @_
    );

    # Load the relevant group. 
    my $group = RT::Group->new($self->CurrentUser);
    $group->LoadTicketRoleGroup(Type => $args{'Type'}, Ticket => $self->id);

    # Find the relevant principal.
    my $principal = RT::Principal->new($self->CurrentUser);
    if (!$args{PrincipalId} && $args{Email}) {
        # Look up the specified user.
        my $user = RT::User->new($self->CurrentUser);
        $user->LoadByEmail($args{Email});
        if ($user->Id) {
            $args{PrincipalId} = $user->PrincipalId;
        }
        else {
            # A non-existent user can't be a group member.
            return 0;
        }
    }
    $principal->Load($args{'PrincipalId'});

    # Ask if it has the member in question
    return ($group->HasMember($principal));
}

# }}}

# {{{ sub IsRequestor

=head2 IsRequestor PRINCIPAL_ID
  
  Takes an RT::Principal id
  Returns true if the principal is a requestor of the current ticket.


=cut

sub IsRequestor {
    my $self   = shift;
    my $person = shift;

    return ( $self->IsWatcher( Type => 'Requestor', PrincipalId => $person ) );

};

# }}}

# {{{ sub IsCc

=head2 IsCc PRINCIPAL_ID

  Takes an RT::Principal id.
  Returns true if the principal is a requestor of the current ticket.


=cut

sub IsCc {
    my $self = shift;
    my $cc   = shift;

    return ( $self->IsWatcher( Type => 'Cc', PrincipalId => $cc ) );

}

# }}}

# {{{ sub IsAdminCc

=head2 IsAdminCc PRINCIPAL_ID

  Takes an RT::Principal id.
  Returns true if the principal is a requestor of the current ticket.

=cut

sub IsAdminCc {
    my $self   = shift;
    my $person = shift;

    return ( $self->IsWatcher( Type => 'AdminCc', PrincipalId => $person ) );

}

# }}}

# {{{ sub IsOwner

=head2 IsOwner

  Takes an RT::User object. Returns true if that user is this ticket's owner.
returns undef otherwise

=cut

sub IsOwner {
    my $self   = shift;
    my $person = shift;

    # no ACL check since this is used in acl decisions
    # unless ($self->CurrentUserHasRight('ShowTicket')) {
    #	return(undef);
    #   }	

    #Tickets won't yet have owners when they're being created.
    unless ( $self->OwnerObj->id ) {
        return (undef);
    }

    if ( $person->id == $self->OwnerObj->id ) {
        return (1);
    }
    else {
        return (undef);
    }
}

# }}}

# }}}

# }}}

# {{{ Routines dealing with queues 

# {{{ sub ValidateQueue

sub ValidateQueue {
    my $self  = shift;
    my $Value = shift;

    if ( !$Value ) {
        $RT::Logger->warning( " RT:::Queue::ValidateQueue called with a null value. this isn't ok.");
        return (1);
    }

    my $QueueObj = RT::Queue->new( $self->CurrentUser );
    my $id       = $QueueObj->Load($Value);

    if ($id) {
        return (1);
    }
    else {
        return (undef);
    }
}

# }}}

# {{{ sub SetQueue  

sub SetQueue {
    my $self     = shift;
    my $NewQueue = shift;

    #Redundant. ACL gets checked in _Set;
    unless ( $self->CurrentUserHasRight('ModifyTicket') ) {
        return ( 0, $self->loc("Permission Denied") );
    }

    my $NewQueueObj = RT::Queue->new( $self->CurrentUser );
    $NewQueueObj->Load($NewQueue);

    unless ( $NewQueueObj->Id() ) {
        return ( 0, $self->loc("That queue does not exist") );
    }

    if ( $NewQueueObj->Id == $self->QueueObj->Id ) {
        return ( 0, $self->loc('That is the same value') );
    }
    unless (
        $self->CurrentUser->HasRight(
            Right    => 'CreateTicket',
            Object => $NewQueueObj
        )
      )
    {
        return ( 0, $self->loc("You may not create requests in that queue.") );
    }

    unless (
        $self->OwnerObj->HasRight(
            Right    => 'OwnTicket',
            Object => $NewQueueObj
        )
      )
    {
        $self->Untake();
    }

    return ( $self->_Set( Field => 'Queue', Value => $NewQueueObj->Id() ) );

}

# }}}

# {{{ sub QueueObj

=head2 QueueObj

Takes nothing. returns this ticket's queue object

=cut

sub QueueObj {
    my $self = shift;

    my $queue_obj = RT::Queue->new( $self->CurrentUser );

    #We call __Value so that we can avoid the ACL decision and some deep recursion
    my ($result) = $queue_obj->Load( $self->__Value('Queue') );
    return ($queue_obj);
}

# }}}

# }}}

# {{{ Date printing routines

# {{{ sub DueObj

=head2 DueObj

  Returns an RT::Date object containing this ticket's due date

=cut

sub DueObj {
    my $self = shift;

    my $time = new RT::Date( $self->CurrentUser );

    # -1 is RT::Date slang for never
    if ( $self->Due ) {
        $time->Set( Format => 'sql', Value => $self->Due );
    }
    else {
        $time->Set( Format => 'unix', Value => -1 );
    }

    return $time;
}

# }}}

# {{{ sub DueAsString 

=head2 DueAsString

Returns this ticket's due date as a human readable string

=cut

sub DueAsString {
    my $self = shift;
    return $self->DueObj->AsString();
}

# }}}

# {{{ sub ResolvedObj

=head2 ResolvedObj

  Returns an RT::Date object of this ticket's 'resolved' time.

=cut

sub ResolvedObj {
    my $self = shift;

    my $time = new RT::Date( $self->CurrentUser );
    $time->Set( Format => 'sql', Value => $self->Resolved );
    return $time;
}

# }}}

# {{{ sub SetStarted

=head2 SetStarted

Takes a date in ISO format or undef
Returns a transaction id and a message
The client calls "Start" to note that the project was started on the date in $date.
A null date means "now"

=cut

sub SetStarted {
    my $self = shift;
    my $time = shift || 0;

    unless ( $self->CurrentUserHasRight('ModifyTicket') ) {
        return ( 0, self->loc("Permission Denied") );
    }

    #We create a date object to catch date weirdness
    my $time_obj = new RT::Date( $self->CurrentUser() );
    if ( $time != 0 ) {
        $time_obj->Set( Format => 'ISO', Value => $time );
    }
    else {
        $time_obj->SetToNow();
    }

    #Now that we're starting, open this ticket
    #TODO do we really want to force this as policy? it should be a scrip

    #We need $TicketAsSystem, in case the current user doesn't have
    #ShowTicket
    #
    my $TicketAsSystem = new RT::Ticket($RT::SystemUser);
    $TicketAsSystem->Load( $self->Id );
    if ( $TicketAsSystem->Status eq 'new' ) {
        $TicketAsSystem->Open();
    }

    return ( $self->_Set( Field => 'Started', Value => $time_obj->ISO ) );

}

# }}}

# {{{ sub StartedObj

=head2 StartedObj

  Returns an RT::Date object which contains this ticket's 
'Started' time.

=cut

sub StartedObj {
    my $self = shift;

    my $time = new RT::Date( $self->CurrentUser );
    $time->Set( Format => 'sql', Value => $self->Started );
    return $time;
}

# }}}

# {{{ sub StartsObj

=head2 StartsObj

  Returns an RT::Date object which contains this ticket's 
'Starts' time.

=cut

sub StartsObj {
    my $self = shift;

    my $time = new RT::Date( $self->CurrentUser );
    $time->Set( Format => 'sql', Value => $self->Starts );
    return $time;
}

# }}}

# {{{ sub ToldObj

=head2 ToldObj

  Returns an RT::Date object which contains this ticket's 
'Told' time.

=cut

sub ToldObj {
    my $self = shift;

    my $time = new RT::Date( $self->CurrentUser );
    $time->Set( Format => 'sql', Value => $self->Told );
    return $time;
}

# }}}

# {{{ sub ToldAsString

=head2 ToldAsString

A convenience method that returns ToldObj->AsString

TODO: This should be deprecated

=cut

sub ToldAsString {
    my $self = shift;
    if ( $self->Told ) {
        return $self->ToldObj->AsString();
    }
    else {
        return ("Never");
    }
}

# }}}

# {{{ sub TimeWorkedAsString

=head2 TimeWorkedAsString

Returns the amount of time worked on this ticket as a Text String

=cut

sub TimeWorkedAsString {
    my $self = shift;
    return "0" unless $self->TimeWorked;

    #This is not really a date object, but if we diff a number of seconds 
    #vs the epoch, we'll get a nice description of time worked.

    my $worked = new RT::Date( $self->CurrentUser );

    #return the  #of minutes worked turned into seconds and written as
    # a simple text string

    return ( $worked->DurationAsString( $self->TimeWorked * 60 ) );
}

# }}}

# }}}

# {{{ Routines dealing with correspondence/comments

# {{{ sub Comment

=head2 Comment

Comment on this ticket.
Takes a hashref with the following attributes:
If MIMEObj is undefined, Content will be used to build a MIME::Entity for this
commentl

MIMEObj, TimeTaken, CcMessageTo, BccMessageTo, Content.

=cut

## Please see file perltidy.ERR
sub Comment {
    my $self = shift;

    my %args = ( CcMessageTo  => undef,
                 BccMessageTo => undef,
                 MIMEObj      => undef,
                 Content      => undef,
                 TimeTaken => 0,
                 @_ );

    unless (    ( $self->CurrentUserHasRight('CommentOnTicket') )
             or ( $self->CurrentUserHasRight('ModifyTicket') ) ) {
        return ( 0, $self->loc("Permission Denied") );
    }

    unless ( $args{'MIMEObj'} ) {
        if ( $args{'Content'} ) {
            use MIME::Entity;
            $args{'MIMEObj'} = MIME::Entity->build(
		Data => ( ref $args{'Content'} ? $args{'Content'} : [ $args{'Content'} ] )
	    );
        }
        else {

            return ( 0, $self->loc("No correspondence attached") );
        }
    }

    RT::I18N::SetMIMEEntityToUTF8($args{'MIMEObj'}); # convert text parts into utf-8

    # If we've been passed in CcMessageTo and BccMessageTo fields,
    # add them to the mime object for passing on to the transaction handler
    # The "NotifyOtherRecipients" scripAction will look for RT--Send-Cc: and
    # RT-Send-Bcc: headers

    $args{'MIMEObj'}->head->add( 'RT-Send-Cc',  $args{'CcMessageTo'} )
	if defined $args{'CcMessageTo'};
    $args{'MIMEObj'}->head->add( 'RT-Send-Bcc', $args{'BccMessageTo'} )
	if defined $args{'BccMessageTo'};

    #Record the correspondence (write the transaction)
    my ( $Trans, $Msg, $TransObj ) = $self->_NewTransaction(
        Type      => 'Comment',
        Data      => ( $args{'MIMEObj'}->head->get('subject') || 'No Subject' ),
        TimeTaken => $args{'TimeTaken'},
        MIMEObj   => $args{'MIMEObj'}
    );

    return ( $Trans, $self->loc("The comment has been recorded") );
}

# }}}

# {{{ sub Correspond

=head2 Correspond

Correspond on this ticket.
Takes a hashref with the following attributes:


MIMEObj, TimeTaken, CcMessageTo, BccMessageTo, Content

if there's no MIMEObj, Content is used to build a MIME::Entity object


=cut

sub Correspond {
    my $self = shift;
    my %args = ( CcMessageTo  => undef,
                 BccMessageTo => undef,
                 MIMEObj      => undef,
                 Content      => undef,
                 TimeTaken    => 0,
                 @_ );

    unless (    ( $self->CurrentUserHasRight('ReplyToTicket') )
             or ( $self->CurrentUserHasRight('ModifyTicket') ) ) {
        return ( 0, $self->loc("Permission Denied") );
    }

    unless ( $args{'MIMEObj'} ) {
        if ( $args{'Content'} ) {
            use MIME::Entity;
            $args{'MIMEObj'} = MIME::Entity->build(
		Data => ( ref $args{'Content'} ?  $args{'Content'} : [ $args{'Content'} ] )
	    );

        }
        else {

            return ( 0, $self->loc("No correspondence attached") );
        }
    }

    RT::I18N::SetMIMEEntityToUTF8($args{'MIMEObj'}); # convert text parts into utf-8

    # If we've been passed in CcMessageTo and BccMessageTo fields,
    # add them to the mime object for passing on to the transaction handler
    # The "NotifyOtherRecipients" scripAction will look for RT-Send-Cc: and RT-Send-Bcc:
    # headers

    $args{'MIMEObj'}->head->add( 'RT-Send-Cc',  $args{'CcMessageTo'} )
	if defined $args{'CcMessageTo'};
    $args{'MIMEObj'}->head->add( 'RT-Send-Bcc', $args{'BccMessageTo'} )
	if defined $args{'BccMessageTo'};

    #Record the correspondence (write the transaction)
    my ( $Trans, $msg, $TransObj ) = $self->_NewTransaction(
             Type => 'Correspond',
             Data => ( $args{'MIMEObj'}->head->get('subject') || 'No Subject' ),
             TimeTaken => $args{'TimeTaken'},
             MIMEObj   => $args{'MIMEObj'} );

    unless ($Trans) {
        $RT::Logger->err( "$self couldn't init a transaction $msg");
        return ( $Trans, $self->loc("correspondence (probably) not sent"), $args{'MIMEObj'} );
    }

    #Set the last told date to now if this isn't mail from the requestor.
    #TODO: Note that this will wrongly ack mail from any non-requestor as a "told"

    unless ( $TransObj->IsInbound ) {
        $self->_SetTold;
    }

    return ( $Trans, $self->loc("correspondence sent") );
}

# }}}

# }}}

# {{{ Routines dealing with Links and Relations between tickets

# {{{ Link Collections

# {{{ sub Members

=head2 Members

  This returns an RT::Links object which references all the tickets 
which are 'MembersOf' this ticket

=cut

sub Members {
    my $self = shift;
    return ( $self->_Links( 'Target', 'MemberOf' ) );
}

# }}}

# {{{ sub MemberOf

=head2 MemberOf

  This returns an RT::Links object which references all the tickets that this
ticket is a 'MemberOf'

=cut

sub MemberOf {
    my $self = shift;
    return ( $self->_Links( 'Base', 'MemberOf' ) );
}

# }}}

# {{{ RefersTo

=head2 RefersTo

  This returns an RT::Links object which shows all references for which this ticket is a base

=cut

sub RefersTo {
    my $self = shift;
    return ( $self->_Links( 'Base', 'RefersTo' ) );
}

# }}}

# {{{ ReferredToBy

=head2 ReferredToBy

  This returns an RT::Links object which shows all references for which this ticket is a target

=cut

sub ReferredToBy {
    my $self = shift;
    return ( $self->_Links( 'Target', 'RefersTo' ) );
}

# }}}

# {{{ DependedOnBy

=head2 DependedOnBy

  This returns an RT::Links object which references all the tickets that depend on this one

=cut

sub DependedOnBy {
    my $self = shift;
    return ( $self->_Links( 'Target', 'DependsOn' ) );
}

# }}}



=head2 HasUnresolvedDependencies

  Takes a paramhash of Type (default to '__any').  Returns true if
$self->UnresolvedDependencies returns an object with one or more members
of that type.  Returns false otherwise


=begin testing

my $t1 = RT::Ticket->new($RT::SystemUser);
my ($id, $trans, $msg) = $t1->Create(Subject => 'DepTest1', Queue => 'general');
ok($id, "Created dep test 1 - $msg");

my $t2 = RT::Ticket->new($RT::SystemUser);
my ($id2, $trans, $msg2) = $t2->Create(Subject => 'DepTest2', Queue => 'general');
ok($id2, "Created dep test 2 - $msg2");
my $t3 = RT::Ticket->new($RT::SystemUser);
my ($id3, $trans, $msg3) = $t3->Create(Subject => 'DepTest3', Queue => 'general', Type => 'approval');
ok($id3, "Created dep test 3 - $msg3");

ok ($t1->AddLink( Type => 'DependsOn', Target => $t2->id));
ok ($t1->AddLink( Type => 'DependsOn', Target => $t3->id));

ok ($t1->HasUnresolvedDependencies, "Ticket ".$t1->Id." has unresolved deps");
ok (!$t1->HasUnresolvedDependencies( Type => 'blah' ), "Ticket ".$t1->Id." has no unresolved blahs");
ok ($t1->HasUnresolvedDependencies( Type => 'approval' ), "Ticket ".$t1->Id." has unresolved approvals");
ok (!$t2->HasUnresolvedDependencies, "Ticket ".$t2->Id." has no unresolved deps");
my ($rid, $rmsg)= $t1->Resolve();
ok(!$rid, $rmsg);
ok($t2->Resolve);
($rid, $rmsg)= $t1->Resolve();
ok(!$rid, $rmsg);
ok($t3->Resolve);
($rid, $rmsg)= $t1->Resolve();
ok($rid, $rmsg);


=end testing

=cut

sub HasUnresolvedDependencies {
    my $self = shift;
    my %args = (
        Type   => undef,
        @_
    );

    my $deps = $self->UnresolvedDependencies;

    if ($args{Type}) {
        $deps->Limit( FIELD => 'Type', 
              OPERATOR => '=',
              VALUE => $args{Type}); 
    }
    else {
	    $deps->IgnoreType;
    }

    if ($deps->Count > 0) {
        return 1;
    }
    else {
        return (undef);
    }
}


# {{{ UnresolvedDependencies 

=head2 UnresolvedDependencies

Returns an RT::Tickets object of tickets which this ticket depends on
and which have a status of new, open or stalled. (That list comes from
RT::Queue->ActiveStatusArray

=cut


sub UnresolvedDependencies {
    my $self = shift;
    my $deps = RT::Tickets->new($self->CurrentUser);

    my @live_statuses = RT::Queue->ActiveStatusArray();
    foreach my $status (@live_statuses) {
        $deps->LimitStatus(VALUE => $status);
    }
    $deps->LimitDependedOnBy($self->Id);

    return($deps);

}

# }}}

# {{{ AllDependedOnBy

=head2 AllDependedOnBy

Returns an array of RT::Ticket objects which (directly or indirectly)
depends on this ticket; takes an optional 'Type' argument in the param
hash, which will limit returned tickets to that type, as well as cause
tickets with that type to serve as 'leaf' nodes that stops the recursive
dependency search.

=cut

sub AllDependedOnBy {
    my $self = shift;
    my $dep = $self->DependedOnBy;
    my %args = (
        Type   => undef,
	_found => {},
	_top   => 1,
        @_
    );

    while (my $link = $dep->Next()) {
	next unless ($link->BaseURI->IsLocal());
	next if $args{_found}{$link->BaseObj->Id};

	if (!$args{Type}) {
	    $args{_found}{$link->BaseObj->Id} = $link->BaseObj;
	    $link->BaseObj->AllDependedOnBy( %args, _top => 0 );
	}
	elsif ($link->BaseObj->Type eq $args{Type}) {
	    $args{_found}{$link->BaseObj->Id} = $link->BaseObj;
	}
	else {
	    $link->BaseObj->AllDependedOnBy( %args, _top => 0 );
	}
    }

    if ($args{_top}) {
	return map { $args{_found}{$_} } sort keys %{$args{_found}};
    }
    else {
	return 1;
    }
}

# }}}

# {{{ DependsOn

=head2 DependsOn

  This returns an RT::Links object which references all the tickets that this ticket depends on

=cut

sub DependsOn {
    my $self = shift;
    return ( $self->_Links( 'Base', 'DependsOn' ) );
}

# }}}




# {{{ sub _Links 

sub _Links {
    my $self = shift;

    #TODO: Field isn't the right thing here. but I ahave no idea what mnemonic ---
    #tobias meant by $f
    my $field = shift;
    my $type  = shift || "";

    unless ( $self->{"$field$type"} ) {
        $self->{"$field$type"} = new RT::Links( $self->CurrentUser );
        if ( $self->CurrentUserHasRight('ShowTicket') ) {
            # Maybe this ticket is a merged ticket
            my $Tickets = new RT::Tickets( $self->CurrentUser );
            # at least to myself
            $self->{"$field$type"}->Limit( FIELD => $field,
                                           VALUE => $self->URI,
                                           ENTRYAGGREGATOR => 'OR' );
            $Tickets->Limit( FIELD => 'EffectiveId',
                             VALUE => $self->EffectiveId );
            while (my $Ticket = $Tickets->Next) {
                $self->{"$field$type"}->Limit( FIELD => $field,
                                               VALUE => $Ticket->URI,
                                               ENTRYAGGREGATOR => 'OR' );
            }
            $self->{"$field$type"}->Limit( FIELD => 'Type',
                                           VALUE => $type )
              if ($type);
        }
    }
    return ( $self->{"$field$type"} );
}

# }}}

# }}}

# {{{ sub DeleteLink 

=head2 DeleteLink

Delete a link. takes a paramhash of Base, Target and Type.
Either Base or Target must be null. The null value will 
be replaced with this ticket\'s id

=cut 

sub DeleteLink {
    my $self = shift;
    my %args = (
        Base   => undef,
        Target => undef,
        Type   => undef,
        @_
    );

    #check acls
    unless ( $self->CurrentUserHasRight('ModifyTicket') ) {
        $RT::Logger->debug("No permission to delete links\n");
        return ( 0, $self->loc('Permission Denied'))

    }

    #we want one of base and target. we don't care which
    #but we only want _one_

    my $direction;
    my $remote_link;

    if ( $args{'Base'} and $args{'Target'} ) {
        $RT::Logger->debug("$self ->_DeleteLink. got both Base and Target\n");
        return ( 0, $self->loc("Can't specifiy both base and target") );
    }
    elsif ( $args{'Base'} ) {
        $args{'Target'} = $self->URI();
	$remote_link = $args{'Base'};
    	$direction = 'Target';
    }
    elsif ( $args{'Target'} ) {
        $args{'Base'} = $self->URI();
	$remote_link = $args{'Target'};
        $direction='Base';
    }
    else {
        $RT::Logger->debug("$self: Base or Target must be specified\n");
        return ( 0, $self->loc('Either base or target must be specified') );
    }

    my $link = new RT::Link( $self->CurrentUser );
    $RT::Logger->debug( "Trying to load link: " . $args{'Base'} . " " . $args{'Type'} . " " . $args{'Target'} . "\n" );


    $link->LoadByParams( Base=> $args{'Base'}, Type=> $args{'Type'}, Target=>  $args{'Target'} );
    #it's a real link. 
    if ( $link->id ) {

        my $linkid = $link->id;
        $link->Delete();

        my $TransString = "Ticket $args{'Base'} no longer $args{Type} ticket $args{'Target'}.";
	my $remote_uri = RT::URI->new( $RT::SystemUser );
    	$remote_uri->FromURI( $remote_link );

        my ( $Trans, $Msg, $TransObj ) = $self->_NewTransaction(
            Type      => 'DeleteLink',
            Field => $LINKDIRMAP{$args{'Type'}}->{$direction},
	    OldValue =>  $remote_uri->URI || $remote_link,
            TimeTaken => 0
        );

        return ( $Trans, $self->loc("Link deleted ([_1])", $TransString));
    }

    #if it's not a link we can find
    else {
        $RT::Logger->debug("Couldn't find that link\n");
        return ( 0, $self->loc("Link not found") );
    }
}

# }}}

# {{{ sub AddLink

=head2 AddLink

Takes a paramhash of Type and one of Base or Target. Adds that link to this ticket.


=cut

sub AddLink {
    my $self = shift;
    my %args = ( Target => '',
                 Base   => '',
                 Type   => '',
                 Silent => undef,
                 @_ );

    unless ( $self->CurrentUserHasRight('ModifyTicket') ) {
        return ( 0, $self->loc("Permission Denied") );
    }

    # Remote_link is the URI of the object that is not this ticket
    my $remote_link;
    my $direction;

    if ( $args{'Base'} and $args{'Target'} ) {
        $RT::Logger->debug(
"$self tried to delete a link. both base and target were specified\n" );
        return ( 0, $self->loc("Can't specifiy both base and target") );
    }
    elsif ( $args{'Base'} ) {
        $args{'Target'} = $self->URI();
	$remote_link = $args{'Base'};
    	$direction = 'Target';
    }
    elsif ( $args{'Target'} ) {
        $args{'Base'} = $self->URI();
	$remote_link = $args{'Target'};
        $direction='Base';
    }
    else {
        return ( 0, $self->loc('Either base or target must be specified') );
    }

    # If the base isn't a URI, make it a URI. 
    # If the target isn't a URI, make it a URI. 

    # {{{ Check if the link already exists - we don't want duplicates
    use RT::Link;
    my $old_link = RT::Link->new( $self->CurrentUser );
    $old_link->LoadByParams( Base   => $args{'Base'},
                             Type   => $args{'Type'},
                             Target => $args{'Target'} );
    if ( $old_link->Id ) {
        $RT::Logger->debug("$self Somebody tried to duplicate a link");
        return ( $old_link->id, $self->loc("Link already exists"), 0 );
    }

    # }}}

    # Storing the link in the DB.
    my $link = RT::Link->new( $self->CurrentUser );
    my ($linkid) = $link->Create( Target => $args{Target},
                                  Base   => $args{Base},
                                  Type   => $args{Type} );

    unless ($linkid) {
        return ( 0, $self->loc("Link could not be created") );
    }

    my $TransString =
      "Ticket $args{'Base'} $args{Type} ticket $args{'Target'}.";

    # Don't write the transaction if we're doing this on create
    if ( $args{'Silent'} ) {
        return ( 1, $self->loc( "Link created ([_1])", $TransString ) );
    }
    else {
	my $remote_uri = RT::URI->new( $RT::SystemUser );
    	$remote_uri->FromURI( $remote_link );

        #Write the transaction
        my ( $Trans, $Msg, $TransObj ) = $self->_NewTransaction(
                                                         Type  => 'AddLink',
                                                         Field => $LINKDIRMAP{$args{'Type'}}->{$direction},
							                             NewValue =>  $remote_uri->URI || $remote_link,
                                                         TimeTaken => 0 );
        return ( $Trans, $self->loc( "Link created ([_1])", $TransString ) );
    }

}

# }}}

# {{{ sub URI 

=head2 URI

Returns this ticket's URI

=cut

sub URI {
    my $self = shift;
    my $uri = RT::URI::fsck_com_rt->new($self->CurrentUser);
    return($uri->URIForObject($self));
}

# }}}

# {{{ sub MergeInto

=head2 MergeInto
MergeInto take the id of the ticket to merge this ticket into.

=cut

sub MergeInto {
    my $self      = shift;
    my $MergeInto = shift;

    unless ( $self->CurrentUserHasRight('ModifyTicket') ) {
        return ( 0, $self->loc("Permission Denied") );
    }

    # Load up the new ticket.
    my $NewTicket = RT::Ticket->new($RT::SystemUser);
    $NewTicket->Load($MergeInto);

    # make sure it exists.
    unless ( defined $NewTicket->Id ) {
        return ( 0, $self->loc("New ticket doesn't exist") );
    }

    # Make sure the current user can modify the new ticket.
    unless ( $NewTicket->CurrentUserHasRight('ModifyTicket') ) {
        $RT::Logger->debug("failed...");
        return ( 0, $self->loc("Permission Denied") );
    }

    $RT::Logger->debug(
        "checking if the new ticket has the same id and effective id...");
    unless ( $NewTicket->id == $NewTicket->EffectiveId ) {
        $RT::Logger->err( "$self trying to merge into "
              . $NewTicket->Id
              . " which is itself merged.\n" );
        return ( 0,
            $self->loc("Can't merge into a merged ticket. You should never get this error") );
    }

    # We use EffectiveId here even though it duplicates information from
    # the links table becasue of the massive performance hit we'd take
    # by trying to do a seperate database query for merge info everytime 
    # loaded a ticket. 

    #update this ticket's effective id to the new ticket's id.
    my ( $id_val, $id_msg ) = $self->__Set(
        Field => 'EffectiveId',
        Value => $NewTicket->Id()
    );

    unless ($id_val) {
        $RT::Logger->error(
            "Couldn't set effective ID for " . $self->Id . ": $id_msg" );
        return ( 0, $self->loc("Merge failed. Couldn't set EffectiveId") );
    }

    my ( $status_val, $status_msg ) = $self->__Set( Field => 'Status', Value => 'resolved');

    unless ($status_val) {
        $RT::Logger->error( $self->loc("[_1] couldn't set status to resolved. RT's Database may be inconsistent.", $self) );
    }


    # update all the links that point to that old ticket
    my $old_links_to = RT::Links->new($self->CurrentUser);
    $old_links_to->Limit(FIELD => 'Target', VALUE => $self->URI);

    while (my $link = $old_links_to->Next) {
        if ($link->Base eq $NewTicket->URI) {
            $link->Delete;
        } else {
            $link->SetTarget($NewTicket->URI);
        }

    }

    my $old_links_from = RT::Links->new($self->CurrentUser);
    $old_links_from->Limit(FIELD => 'Base', VALUE => $self->URI);

    while (my $link = $old_links_from->Next) {
        if ($link->Target eq $NewTicket->URI) {
            $link->Delete;
        } else {
            $link->SetBase($NewTicket->URI);
        }

    }


    #make a new link: this ticket is merged into that other ticket.
    $self->AddLink( Type   => 'MergedInto', Target => $NewTicket->Id());

    #add all of this ticket's watchers to that ticket.
    my $requestors = $self->Requestors->MembersObj;
    while (my $watcher = $requestors->Next) { 
        $NewTicket->_AddWatcher( Type => 'Requestor',
                                  Silent => 1,
                                  PrincipalId => $watcher->MemberId);
    }

    my $Ccs = $self->Cc->MembersObj;
    while (my $watcher = $Ccs->Next) { 
        $NewTicket->_AddWatcher( Type => 'Cc',
                                  Silent => 1,
                                  PrincipalId => $watcher->MemberId);
    }

    my $AdminCcs = $self->AdminCc->MembersObj;
    while (my $watcher = $AdminCcs->Next) { 
        $NewTicket->_AddWatcher( Type => 'AdminCc',
                                  Silent => 1,
                                  PrincipalId => $watcher->MemberId);
    }


    #find all of the tickets that were merged into this ticket. 
    my $old_mergees = new RT::Tickets( $self->CurrentUser );
    $old_mergees->Limit(
        FIELD    => 'EffectiveId',
        OPERATOR => '=',
        VALUE    => $self->Id
    );

    #   update their EffectiveId fields to the new ticket's id
    while ( my $ticket = $old_mergees->Next() ) {
        my ( $val, $msg ) = $ticket->__Set(
            Field => 'EffectiveId',
            Value => $NewTicket->Id()
        );
    }

    $NewTicket->_SetLastUpdated;

    return ( 1, $self->loc("Merge Successful") );
}

# }}}

# }}}

# {{{ Routines dealing with ownership

# {{{ sub OwnerObj

=head2 OwnerObj

Takes nothing and returns an RT::User object of 
this ticket's owner

=cut

sub OwnerObj {
    my $self = shift;

    #If this gets ACLed, we lose on a rights check in User.pm and
    #get deep recursion. if we need ACLs here, we need
    #an equiv without ACLs

    my $owner = new RT::User( $self->CurrentUser );
    $owner->Load( $self->__Value('Owner') );

    #Return the owner object
    return ($owner);
}

# }}}

# {{{ sub OwnerAsString 

=head2 OwnerAsString

Returns the owner's email address

=cut

sub OwnerAsString {
    my $self = shift;
    return ( $self->OwnerObj->EmailAddress );

}

# }}}

# {{{ sub SetOwner

=head2 SetOwner

Takes two arguments:
     the Id or Name of the owner 
and  (optionally) the type of the SetOwner Transaction. It defaults
to 'Give'.  'Steal' is also a valid option.

=begin testing

my $root = RT::User->new($RT::SystemUser);
$root->Load('root');
ok ($root->Id, "Loaded the root user");
my $t = RT::Ticket->new($RT::SystemUser);
$t->Load(1);
$t->SetOwner('root');
ok ($t->OwnerObj->Name eq 'root' , "Root owns the ticket");
$t->Steal();
ok ($t->OwnerObj->id eq $RT::SystemUser->id , "SystemUser owns the ticket");
my $txns = RT::Transactions->new($RT::SystemUser);
$txns->OrderBy(FIELD => 'id', ORDER => 'DESC');
$txns->Limit(FIELD => 'Ticket', VALUE => '1');
my $steal  = $txns->First;
ok($steal->OldValue == $root->Id , "Stolen from root");
ok($steal->NewValue == $RT::SystemUser->Id , "Stolen by the systemuser");

=end testing

=cut

sub SetOwner {
    my $self     = shift;
    my $NewOwner = shift;
    my $Type     = shift || "Give";

    # must have ModifyTicket rights
    # or TakeTicket/StealTicket and $NewOwner is self
    # see if it's a take
    if ( $self->OwnerObj->Id == $RT::Nobody->Id ) {
        unless (    $self->CurrentUserHasRight('ModifyTicket')
                 || $self->CurrentUserHasRight('TakeTicket') ) {
            return ( 0, $self->loc("Permission Denied") );
        }
    }

    # see if it's a steal
    elsif (    $self->OwnerObj->Id != $RT::Nobody->Id
            && $self->OwnerObj->Id != $self->CurrentUser->id ) {

        unless (    $self->CurrentUserHasRight('ModifyTicket')
                 || $self->CurrentUserHasRight('StealTicket') ) {
            return ( 0, $self->loc("Permission Denied") );
        }
    }
    else {
        unless ( $self->CurrentUserHasRight('ModifyTicket') ) {
            return ( 0, $self->loc("Permission Denied") );
        }
    }
    my $NewOwnerObj = RT::User->new( $self->CurrentUser );
    my $OldOwnerObj = $self->OwnerObj;

    $NewOwnerObj->Load($NewOwner);
    if ( !$NewOwnerObj->Id ) {
        return ( 0, $self->loc("That user does not exist") );
    }

    #If thie ticket has an owner and it's not the current user

    if (    ( $Type ne 'Steal' )
        and ( $Type ne 'Force' )
        and    #If we're not stealing
        ( $self->OwnerObj->Id != $RT::Nobody->Id ) and    #and the owner is set
        ( $self->CurrentUser->Id ne $self->OwnerObj->Id() )
      ) {                                                 #and it's not us
        return ( 0,
                 $self->loc(
"You can only reassign tickets that you own or that are unowned" ) );
    }

    #If we've specified a new owner and that user can't modify the ticket
    elsif ( ( $NewOwnerObj->Id )
            and ( !$NewOwnerObj->HasRight( Right  => 'OwnTicket',
                                           Object => $self ) )
      ) {
        return ( 0, $self->loc("That user may not own tickets in that queue") );
    }

    #If the ticket has an owner and it's the new owner, we don't need
    #To do anything
    elsif (     ( $self->OwnerObj )
            and ( $NewOwnerObj->Id eq $self->OwnerObj->Id ) ) {
        return ( 0, $self->loc("That user already owns that ticket") );
    }

    $RT::Handle->BeginTransaction();

    # Delete the owner in the owner group, then add a new one
    # TODO: is this safe? it's not how we really want the API to work
    # for most things, but it's fast.
    my ( $del_id, $del_msg ) = $self->OwnerGroup->MembersObj->First->Delete();
    unless ($del_id) {
        $RT::Handle->Rollback();
        return ( 0, $self->loc("Could not change owner. ") . $del_msg );
    }

    my ( $add_id, $add_msg ) = $self->OwnerGroup->_AddMember(
                                       PrincipalId => $NewOwnerObj->PrincipalId,
                                       InsideTransaction => 1 );
    unless ($add_id) {
        $RT::Handle->Rollback();
        return ( 0, $self->loc("Could not change owner. ") . $add_msg );
    }

    # We call set twice with slightly different arguments, so
    # as to not have an SQL transaction span two RT transactions

    my ( $val, $msg ) = $self->_Set(
                      Field             => 'Owner',
                      RecordTransaction => 0,
                      Value             => $NewOwnerObj->Id,
                      TimeTaken         => 0,
                      TransactionType   => $Type,
                      CheckACL          => 0,                  # don't check acl
    );

    unless ($val) {
        $RT::Handle->Rollback;
        return ( 0, $self->loc("Could not change owner. ") . $msg );
    }

    $RT::Handle->Commit();

    my ( $trans, $msg, undef ) = $self->_NewTransaction(
                                                   Type     => $Type,
                                                   Field    => 'Owner',
                                                   NewValue => $NewOwnerObj->Id,
                                                   OldValue => $OldOwnerObj->Id,
                                                   TimeTaken => 0 );

    if ($trans) {
        $msg = $self->loc( "Owner changed from [_1] to [_2]",
                           $OldOwnerObj->Name, $NewOwnerObj->Name );

        # TODO: make sure the trans committed properly
    }
    return ( $trans, $msg );

}

# }}}

# {{{ sub Take

=head2 Take

A convenince method to set the ticket's owner to the current user

=cut

sub Take {
    my $self = shift;
    return ( $self->SetOwner( $self->CurrentUser->Id, 'Take' ) );
}

# }}}

# {{{ sub Untake

=head2 Untake

Convenience method to set the owner to 'nobody' if the current user is the owner.

=cut

sub Untake {
    my $self = shift;
    return ( $self->SetOwner( $RT::Nobody->UserObj->Id, 'Untake' ) );
}

# }}}

# {{{ sub Steal 

=head2 Steal

A convenience method to change the owner of the current ticket to the
current user. Even if it's owned by another user.

=cut

sub Steal {
    my $self = shift;

    if ( $self->IsOwner( $self->CurrentUser ) ) {
        return ( 0, $self->loc("You already own this ticket") );
    }
    else {
        return ( $self->SetOwner( $self->CurrentUser->Id, 'Steal' ) );

    }

}

# }}}

# }}}

# {{{ Routines dealing with status

# {{{ sub ValidateStatus 

=head2 ValidateStatus STATUS

Takes a string. Returns true if that status is a valid status for this ticket.
Returns false otherwise.

=cut

sub ValidateStatus {
    my $self   = shift;
    my $status = shift;

    #Make sure the status passed in is valid
    unless ( $self->QueueObj->IsValidStatus($status) ) {
        return (undef);
    }

    return (1);

}

# }}}

# {{{ sub SetStatus

=head2 SetStatus STATUS

Set this ticket\'s status. STATUS can be one of: new, open, stalled, resolved, rejected or deleted.

Alternatively, you can pass in a list of named parameters (Status => STATUS, Force => FORCE).  If FORCE is true, ignore unresolved dependencies and force a status change.

=begin testing

my $tt = RT::Ticket->new($RT::SystemUser);
my ($id, $tid, $msg)= $tt->Create(Queue => 'general',
            Subject => 'test');
ok($id, $msg);
ok($tt->Status eq 'new', "New ticket is created as new");

($id, $msg) = $tt->SetStatus('open');
ok($id, $msg);
ok ($msg =~ /open/i, "Status message is correct");
($id, $msg) = $tt->SetStatus('resolved');
ok($id, $msg);
ok ($msg =~ /resolved/i, "Status message is correct");
($id, $msg) = $tt->SetStatus('resolved');
ok(!$id,$msg);


=end testing


=cut

sub SetStatus {
    my $self   = shift;
    my %args;

    if (@_ == 1) {
	$args{Status} = shift;
    }
    else {
	%args = (@_);
    }

    #Check ACL
    unless ( $self->CurrentUserHasRight('ModifyTicket') ) {
        return ( 0, $self->loc('Permission Denied') );
    }

    if (!$args{Force} && ($args{'Status'} eq 'resolved') && $self->HasUnresolvedDependencies) {
        return (0, $self->loc('That ticket has unresolved dependencies'));
    }

    my $now = RT::Date->new( $self->CurrentUser );
    $now->SetToNow();

    #If we're changing the status from new, record that we've started
    if ( ( $self->Status =~ /new/ ) && ( $args{Status} ne 'new' ) ) {

        #Set the Started time to "now"
        $self->_Set( Field             => 'Started',
                     Value             => $now->ISO,
                     RecordTransaction => 0 );
    }

    if ( $args{Status} =~ /^(resolved|rejected|dead)$/ ) {

        #When we resolve a ticket, set the 'Resolved' attribute to now.
        $self->_Set( Field             => 'Resolved',
                     Value             => $now->ISO,
                     RecordTransaction => 0 );
    }

    #Actually update the status
   my ($val, $msg)= $self->_Set( Field           => 'Status',
                          Value           => $args{Status},
                          TimeTaken       => 0,
                          TransactionType => 'Status'  );

    return($val,$msg);
}

# }}}

# {{{ sub Kill

=head2 Kill

Takes no arguments. Marks this ticket for garbage collection

=cut

sub Kill {
    my $self = shift;
    $RT::Logger->crit("'Kill' is deprecated. use 'Delete' instead.");
    return $self->Delete;
}

sub Delete {
    my $self = shift;
    return ( $self->SetStatus('deleted') );

    # TODO: garbage collection
}

# }}}

# {{{ sub Stall

=head2 Stall

Sets this ticket's status to stalled

=cut

sub Stall {
    my $self = shift;
    return ( $self->SetStatus('stalled') );
}

# }}}

# {{{ sub Reject

=head2 Reject

Sets this ticket's status to rejected

=cut

sub Reject {
    my $self = shift;
    return ( $self->SetStatus('rejected') );
}

# }}}

# {{{ sub Open

=head2 Open

Sets this ticket\'s status to Open

=cut

sub Open {
    my $self = shift;
    return ( $self->SetStatus('open') );
}

# }}}

# {{{ sub Resolve

=head2 Resolve

Sets this ticket\'s status to Resolved

=cut

sub Resolve {
    my $self = shift;
    return ( $self->SetStatus('resolved') );
}

# }}}

# }}}

# {{{ Routines dealing with custom fields


# {{{ FirstCustomFieldValue

=item FirstCustomFieldValue FIELD

Return the content of the first value of CustomField FIELD for this ticket
Takes a field id or name

=cut

sub FirstCustomFieldValue {
    my $self = shift;
    my $field = shift;
    my $values = $self->CustomFieldValues($field);
    if ($values->First) {
        return $values->First->Content;
    } else {
        return undef;
    }

}



# {{{ CustomFieldValues

=item CustomFieldValues FIELD

Return a TicketCustomFieldValues object of all values of CustomField FIELD for this ticket.  
Takes a field id or name.


=cut

sub CustomFieldValues {
    my $self  = shift;
    my $field = shift;

    my $cf = RT::CustomField->new($self->CurrentUser);

    if ($field =~ /^\d+$/) {
        $cf->LoadById($field);
    } else {
        $cf->LoadByNameAndQueue(Name => $field, Queue => $self->QueueObj->Id);
    }
    my $cf_values = RT::TicketCustomFieldValues->new( $self->CurrentUser );
    $cf_values->LimitToCustomField($cf->id);
    $cf_values->LimitToTicket($self->Id());

    # @values is a CustomFieldValues object;
    return ($cf_values);
}

# }}}

# {{{ AddCustomFieldValue

=item AddCustomFieldValue { Field => FIELD, Value => VALUE }

VALUE can either be a CustomFieldValue object or a string.
FIELD can be a CustomField object OR a CustomField ID.


Adds VALUE as a value of CustomField FIELD.  If this is a single-value custom field,
deletes the old value. 
If VALUE isn't a valid value for the custom field, returns 
(0, 'Error message' ) otherwise, returns (1, 'Success Message')

=cut

sub AddCustomFieldValue {
    my $self = shift;
    unless ( $self->CurrentUserHasRight('ModifyTicket') ) {
        return ( 0, $self->loc("Permission Denied") );
    }
    $self->_AddCustomFieldValue(@_);
}

sub _AddCustomFieldValue {
    my $self = shift;
    my %args = (
        Field => undef,
        Value => undef,
	RecordTransaction => 1,
        @_
    );

    my $cf = RT::CustomField->new( $self->CurrentUser );
    if ( UNIVERSAL::isa( $args{'Field'}, "RT::CustomField" ) ) {
        $cf->Load( $args{'Field'}->id );
    }
    else {
        $cf->Load( $args{'Field'} );
    }

    unless ( $cf->Id ) {
        return ( 0, $self->loc("Custom field [_1] not found", $args{'Field'}) );
    }

    # Load up a TicketCustomFieldValues object for this custom field and this ticket
    my $values = $cf->ValuesForTicket( $self->id );

    unless ( $cf->ValidateValue( $args{'Value'} ) ) {
        return ( 0, $self->loc("Invalid value for custom field") );
    }

    # If the custom field only accepts a single value, delete the existing
    # value and record a "changed from foo to bar" transaction
    if ( $cf->SingleValue ) {

        # We need to whack any old values here.  In most cases, the custom field should
        # only have one value to delete.  In the pathalogical case, this custom field
        # used to be a multiple and we have many values to whack....
        my $cf_values = $values->Count;

        if ( $cf_values > 1 ) {
            my $i = 0;   #We want to delete all but the last one, so we can then
                 # execute the same code to "change" the value from old to new
            while ( my $value = $values->Next ) {
                $i++;
                if ( $i < $cf_values ) {
                    my $old_value = $value->Content;
                    my ($val, $msg) = $cf->DeleteValueForTicket(Ticket => $self->Id, Content => $value->Content);
                    unless ($val) {
                        return (0,$msg);
                    }
                    my ( $TransactionId, $Msg, $TransactionObj ) =
                      $self->_NewTransaction(
                        Type     => 'CustomField',
                        Field    => $cf->Id,
                        OldValue => $old_value
                      );
                }
            }
        }

        my $old_value;
        if (my $value = $cf->ValuesForTicket( $self->Id )->First) {
	    $old_value = $value->Content();
	    return (1) if $old_value eq $args{'Value'};
	}

        my ( $new_value_id, $value_msg ) = $cf->AddValueForTicket(
            Ticket  => $self->Id,
            Content => $args{'Value'}
        );

        unless ($new_value_id) {
            return ( 0,
                $self->loc("Could not add new custom field value for ticket. [_1] ",
                  ,$value_msg) );
        }

        my $new_value = RT::TicketCustomFieldValue->new( $self->CurrentUser );
        $new_value->Load($new_value_id);

        # now that adding the new value was successful, delete the old one
	if ($old_value) {
	    my ($val, $msg) = $cf->DeleteValueForTicket(Ticket => $self->Id, Content => $old_value);
	    unless ($val) { 
	    		return (0,$msg);
	    }
	}

	if ($args{'RecordTransaction'}) {
        my ( $TransactionId, $Msg, $TransactionObj ) = $self->_NewTransaction(
            Type     => 'CustomField',
            Field    => $cf->Id,
            OldValue => $old_value,
            NewValue => $new_value->Content
        );
	}

        if ( $old_value eq '' ) {
            return ( 1, $self->loc("[_1] [_2] added", $cf->Name, $new_value->Content) );
        }
        elsif ( $new_value->Content eq '' ) {
            return ( 1, $self->loc("[_1] [_2] deleted", $cf->Name, $old_value) );
        }
        else {
            return ( 1, $self->loc("[_1] [_2] changed to [_3]", $cf->Name, $old_value, $new_value->Content ) );
        }

    }

    # otherwise, just add a new value and record "new value added"
    else {
        my ( $new_value_id ) = $cf->AddValueForTicket(
            Ticket  => $self->Id,
            Content => $args{'Value'}
        );

        unless ($new_value_id) {
            return ( 0,
                $self->loc("Could not add new custom field value for ticket. "));
        }
    if ( $args{'RecordTransaction'} ) {
        my ( $TransactionId, $Msg, $TransactionObj ) = $self->_NewTransaction(
            Type     => 'CustomField',
            Field    => $cf->Id,
            NewValue => $args{'Value'}
        );
        unless ($TransactionId) {
            return ( 0,
                $self->loc( "Couldn't create a transaction: [_1]", $Msg ) );
        }
    }
        return ( 1, $self->loc("[_1] added as a value for [_2]",$args{'Value'}, $cf->Name));
    }

}

# }}}

# {{{ DeleteCustomFieldValue

=item DeleteCustomFieldValue { Field => FIELD, Value => VALUE }

Deletes VALUE as a value of CustomField FIELD. 

VALUE can be a string, a CustomFieldValue or a TicketCustomFieldValue.

If VALUE isn't a valid value for the custom field, returns 
(0, 'Error message' ) otherwise, returns (1, 'Success Message')

=cut

sub DeleteCustomFieldValue {
    my $self = shift;
    my %args = (
        Field => undef,
        Value => undef,
        @_);

    unless ( $self->CurrentUserHasRight('ModifyTicket') ) {
        return ( 0, $self->loc("Permission Denied") );
    }
    my $cf = RT::CustomField->new( $self->CurrentUser );
    if ( UNIVERSAL::isa( $args{'Field'}, "RT::CustomField" ) ) {
        $cf->LoadById( $args{'Field'}->id );
    }
    else {
        $cf->LoadById( $args{'Field'} );
    }

    unless ( $cf->Id ) {
        return ( 0, $self->loc("Custom field not found") );
    }


     my ($val, $msg) = $cf->DeleteValueForTicket(Ticket => $self->Id, Content => $args{'Value'});
     unless ($val) { 
            return (0,$msg);
     }
        my ( $TransactionId, $Msg, $TransactionObj ) = $self->_NewTransaction(
            Type     => 'CustomField',
            Field    => $cf->Id,
            OldValue => $args{'Value'}
        );
        unless($TransactionId) {
            return(0, $self->loc("Couldn't create a transaction: [_1]", $Msg));
        } 

        return($TransactionId, $self->loc("[_1] is no longer a value for custom field [_2]", $args{'Value'}, $cf->Name));
}

# }}}

# }}}

# {{{ Actions + Routines dealing with transactions

# {{{ sub SetTold and _SetTold

=head2 SetTold ISO  [TIMETAKEN]

Updates the told and records a transaction

=cut

sub SetTold {
    my $self = shift;
    my $told;
    $told = shift if (@_);
    my $timetaken = shift || 0;

    unless ( $self->CurrentUserHasRight('ModifyTicket') ) {
        return ( 0, $self->loc("Permission Denied") );
    }

    my $datetold = new RT::Date( $self->CurrentUser );
    if ($told) {
        $datetold->Set( Format => 'iso',
                        Value  => $told );
    }
    else {
        $datetold->SetToNow();
    }

    return ( $self->_Set( Field           => 'Told',
                          Value           => $datetold->ISO,
                          TimeTaken       => $timetaken,
                          TransactionType => 'Told' ) );
}

=head2 _SetTold

Updates the told without a transaction or acl check. Useful when we're sending replies.

=cut

sub _SetTold {
    my $self = shift;

    my $now = new RT::Date( $self->CurrentUser );
    $now->SetToNow();

    #use __Set to get no ACLs ;)
    return ( $self->__Set( Field => 'Told',
                           Value => $now->ISO ) );
}

# }}}

# {{{ sub Transactions 

=head2 Transactions

  Returns an RT::Transactions object of all transactions on this ticket

=cut

sub Transactions {
    my $self = shift;

    use RT::Transactions;
    my $transactions = RT::Transactions->new( $self->CurrentUser );

    #If the user has no rights, return an empty object
    if ( $self->CurrentUserHasRight('ShowTicket') ) {
        my $tickets = $transactions->NewAlias('Tickets');
        $transactions->Join(
            ALIAS1 => 'main',
            FIELD1 => 'Ticket',
            ALIAS2 => $tickets,
            FIELD2 => 'id'
        );
        $transactions->Limit(
            ALIAS => $tickets,
            FIELD => 'EffectiveId',
            VALUE => $self->id()
        );

        # if the user may not see comments do not return them
        unless ( $self->CurrentUserHasRight('ShowTicketComments') ) {
            $transactions->Limit(
                FIELD    => 'Type',
                OPERATOR => '!=',
                VALUE    => "Comment"
            );
        }
    }

    return ($transactions);
}

# }}}

# {{{ sub _NewTransaction

sub _NewTransaction {
    my $self = shift;
    my %args = (
        TimeTaken => 0,
        Type      => undef,
        OldValue  => undef,
        NewValue  => undef,
        Data      => undef,
        Field     => undef,
        MIMEObj   => undef,
        @_
    );

    require RT::Transaction;
    my $trans = new RT::Transaction( $self->CurrentUser );
    my ( $transaction, $msg ) = $trans->Create(
        Ticket    => $self->Id,
        TimeTaken => $args{'TimeTaken'},
        Type      => $args{'Type'},
        Data      => $args{'Data'},
        Field     => $args{'Field'},
        NewValue  => $args{'NewValue'},
        OldValue  => $args{'OldValue'},
        MIMEObj   => $args{'MIMEObj'}
    );


    $self->Load($self->Id);

    $RT::Logger->warning($msg) unless $transaction;

    $self->_SetLastUpdated;

    if ( defined $args{'TimeTaken'} ) {
        $self->_UpdateTimeTaken( $args{'TimeTaken'} );
    }
    return ( $transaction, $msg, $trans );
}

# }}}

# }}}

# {{{ PRIVATE UTILITY METHODS. Mostly needed so Ticket can be a DBIx::Record

# {{{ sub _ClassAccessible

sub _ClassAccessible {
    {
        EffectiveId       => { 'read' => 1,  'write' => 1,  'public' => 1 },
          Queue           => { 'read' => 1,  'write' => 1 },
          Requestors      => { 'read' => 1,  'write' => 1 },
          Owner           => { 'read' => 1,  'write' => 1 },
          Subject         => { 'read' => 1,  'write' => 1 },
          InitialPriority => { 'read' => 1,  'write' => 1 },
          FinalPriority   => { 'read' => 1,  'write' => 1 },
          Priority        => { 'read' => 1,  'write' => 1 },
          Status          => { 'read' => 1,  'write' => 1 },
          TimeEstimated      => { 'read' => 1,  'write' => 1 },
          TimeWorked      => { 'read' => 1,  'write' => 1 },
          TimeLeft        => { 'read' => 1,  'write' => 1 },
          Created         => { 'read' => 1,  'auto'  => 1 },
          Creator         => { 'read' => 1,  'auto'  => 1 },
          Told            => { 'read' => 1,  'write' => 1 },
          Resolved        => { 'read' => 1 },
          Type            => { 'read' => 1 },
          Starts        => { 'read' => 1, 'write' => 1 },
          Started       => { 'read' => 1, 'write' => 1 },
          Due           => { 'read' => 1, 'write' => 1 },
          Creator       => { 'read' => 1, 'auto'  => 1 },
          Created       => { 'read' => 1, 'auto'  => 1 },
          LastUpdatedBy => { 'read' => 1, 'auto'  => 1 },
          LastUpdated   => { 'read' => 1, 'auto'  => 1 }
    };

}

# }}}

# {{{ sub _Set

sub _Set {
    my $self = shift;

    my %args = ( Field             => undef,
                 Value             => undef,
                 TimeTaken         => 0,
                 RecordTransaction => 1,
                 UpdateTicket      => 1,
                 CheckACL          => 1,
                 TransactionType   => 'Set',
                 @_ );

    if ($args{'CheckACL'}) {
      unless ( $self->CurrentUserHasRight('ModifyTicket')) {
          return ( 0, $self->loc("Permission Denied"));
      }
   }

    unless ($args{'UpdateTicket'} || $args{'RecordTransaction'}) {
        $RT::Logger->error("Ticket->_Set called without a mandate to record an update or update the ticket");
        return(0, $self->loc("Internal Error"));
    }

    #if the user is trying to modify the record

    #Take care of the old value we really don't want to get in an ACL loop.
    # so ask the super::_Value
    my $Old = $self->SUPER::_Value("$args{'Field'}");
    
    my ($ret, $msg);
    if ( $args{'UpdateTicket'}  ) {

        #Set the new value
        ( $ret, $msg ) = $self->SUPER::_Set( Field => $args{'Field'},
                                                Value => $args{'Value'} );
    
        #If we can't actually set the field to the value, don't record
        # a transaction. instead, get out of here.
        if ( $ret == 0 ) { return ( 0, $msg ); }
    }

    if ( $args{'RecordTransaction'} == 1 ) {

        my ( $Trans, $Msg, $TransObj ) = $self->_NewTransaction(
                                               Type => $args{'TransactionType'},
                                               Field     => $args{'Field'},
                                               NewValue  => $args{'Value'},
                                               OldValue  => $Old,
                                               TimeTaken => $args{'TimeTaken'},
        );
        return ( $Trans, scalar $TransObj->Description );
    }
    else {
        return ( $ret, $msg );
    }
}

# }}}

# {{{ sub _Value 

=head2 _Value

Takes the name of a table column.
Returns its value as a string, if the user passes an ACL check

=cut

sub _Value {

    my $self  = shift;
    my $field = shift;

    #if the field is public, return it.
    if ( $self->_Accessible( $field, 'public' ) ) {

        #$RT::Logger->debug("Skipping ACL check for $field\n");
        return ( $self->SUPER::_Value($field) );

    }

    #If the current user doesn't have ACLs, don't let em at it.  

    unless ( $self->CurrentUserHasRight('ShowTicket') ) {
        return (undef);
    }
    return ( $self->SUPER::_Value($field) );

}

# }}}

# {{{ sub _UpdateTimeTaken

=head2 _UpdateTimeTaken

This routine will increment the timeworked counter. it should
only be called from _NewTransaction 

=cut

sub _UpdateTimeTaken {
    my $self    = shift;
    my $Minutes = shift;
    my ($Total);

    $Total = $self->SUPER::_Value("TimeWorked");
    $Total = ( $Total || 0 ) + ( $Minutes || 0 );
    $self->SUPER::_Set(
        Field => "TimeWorked",
        Value => $Total
    );

    return ($Total);
}

# }}}

# }}}

# {{{ Routines dealing with ACCESS CONTROL

# {{{ sub CurrentUserHasRight 

=head2 CurrentUserHasRight

  Takes the textual name of a Ticket scoped right (from RT::ACE) and returns
1 if the user has that right. It returns 0 if the user doesn't have that right.

=cut

sub CurrentUserHasRight {
    my $self  = shift;
    my $right = shift;

    return (
        $self->HasRight(
            Principal => $self->CurrentUser->UserObj(),
            Right     => "$right"
          )
    );

}

# }}}

# {{{ sub HasRight 

=head2 HasRight

 Takes a paramhash with the attributes 'Right' and 'Principal'
  'Right' is a ticket-scoped textual right from RT::ACE 
  'Principal' is an RT::User object

  Returns 1 if the principal has the right. Returns undef if not.

=cut

sub HasRight {
    my $self = shift;
    my %args = (
        Right     => undef,
        Principal => undef,
        @_
    );

    unless ( ( defined $args{'Principal'} ) and ( ref( $args{'Principal'} ) ) )
    {
        $RT::Logger->warning("Principal attrib undefined for Ticket::HasRight");
    }

    return (
        $args{'Principal'}->HasRight(
            Object => $self,
            Right     => $args{'Right'}
          )
    );
}

# }}}

# }}}

1;

=head1 AUTHOR

Jesse Vincent, jesse@bestpractical.com

=head1 SEE ALSO

RT

=cut

