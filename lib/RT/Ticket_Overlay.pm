# (c) 1996-2002 Jesse Vincent <jesse@bestpractical.com>
# This software is redistributable under the terms of the GNU GPL

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
                       
ok($testcf->Values->Count == 2);

use_ok(RT::Ticket);

ok(my $t = RT::Ticket->new($RT::SystemUser));
ok(my ($id, $msg) = $t->Create( Queue => $testqueue->Id,
               Subject => 'Testing',
              ));
ok($id != 0);
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
ok($t2->OwnerObj->Id == $RT::Nobody->Id);


=end testing

=cut

no warnings qw(redefine);

use RT::Queue;
use RT::User;
use RT::Record;
use RT::Link;
use RT::Links;
use RT::Date;
use RT::CustomFields;
use RT::TicketCustomFieldValues;

=begin testing


ok(require RT::Ticket, "Loading the RT::Ticket library");

=end testing

=cut

# }}}

# {{{ Routines dealing with ticket creation, deletion, loading 

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
  TimeWorked -- an integer
  TimeLeft -- an integer
  Starts -- an ISO date describing the ticket\'s start date and time in GMT
  Due -- an ISO date describing the ticket\'s due date and time in GMT
  MIMEObj -- a MIME::Entity object with the content of the initial ticket request.



Returns: TICKETID, Transaction Object, Error Message


=begin testing

my $t = RT::Ticket->new($RT::SystemUser);

ok( $t->Create(Queue => 'General', Subject => 'This is a subject'), "Ticket Created");

ok ( my $id = $t->Id, "Got ticket id");

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
                 Owner           => $RT::Nobody->UserObj,
                 Subject         => '[no subject]',
                 InitialPriority => undef,
                 FinalPriority   => undef,
                 Status          => 'new',
                 TimeWorked      => "0",
                 TimeLeft        => 0,
                 Due             => undef,
                 Starts          => undef,
                 MIMEObj         => undef,
                 @_ );

    my ( $ErrStr, $QueueObj, $Owner, $resolved );
    my (@non_fatal_errors);

    my $now = RT::Date->new( $self->CurrentUser );
    $now->SetToNow();

    if ( ( defined( $args{'Queue'} ) ) && ( !ref( $args{'Queue'} ) ) ) {
        $QueueObj = RT::Queue->new($RT::SystemUser);
        $QueueObj->Load( $args{'Queue'} );
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
    unless ( defined($QueueObj) ) {
        $RT::Logger->debug("$self No queue given for ticket creation.");
        return ( 0, 0, $self->loc('Could not create ticket. Queue not set') );
    }

    #Now that we have a queue, Check the ACLS
    unless ( $self->CurrentUser->HasQueueRight( Right    => 'CreateTicket',
                                                QueueObj => $QueueObj )
      ) {
        return ( 0, 0,
                 $self->loc( "No permission to create tickets in the queue '[_1]'", $QueueObj->Name ) );
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

    #TODO we should see what sort of due date we're getting, rather +
    # than assuming it's in ISO format.

    #Set the due date. if we didn't get fed one, use the queue default due in
    my $due = new RT::Date( $self->CurrentUser );
    if ( defined $args{'Due'} ) {
        $due->Set( Format => 'ISO',
                   Value  => $args{'Due'} );
    }
    elsif ( defined( $QueueObj->DefaultDueIn ) ) {
        $due->SetToNow;
        $due->AddDays( $QueueObj->DefaultDueIn );
    }

    my $starts = new RT::Date( $self->CurrentUser );
    if ( defined $args{'Starts'} ) {
        $starts->Set( Format => 'ISO',
                      Value  => $args{'Starts'} );
    }

    # {{{ Deal with setting the owner

    if ( ref( $args{'Owner'} ) eq 'RT::User' ) {
        $Owner = $args{'Owner'};
    }

    #If we've been handed something else, try to load the user.
    elsif ( $args{'Owner'} ) {
        $Owner = new RT::User( $self->CurrentUser );
        $Owner->Load( $args{'Owner'} );

    }

    #If we can't handle it, call it nobody
    else {
        if ( ref( $args{'Owner'} ) ) {
            $RT::Logger->warning(
                           "$ticket ->Create called with an Owner of " . "type "
                             . ref( $args{'Owner'} )
                             . ". Defaulting to nobody.\n" );

            push @non_fatal_errors,
              $self->loc("Invalid owner. Defaulting to 'nobody'.");
        }
        else {
            $RT::Logger->warning( "$self ->Create called with an "
                                  . "unknown datatype for Owner: "
                                  . $args{'Owner'}
                                  . ". Defaulting to Nobody.\n" );
        }
    }

    #If we have a proposed owner and they don't have the right 
    #to own a ticket, scream about it and make them not the owner
    if (     ( defined($Owner) )
         and ( $Owner->Id != $RT::Nobody->Id )
         and ( !$Owner->HasQueueRight( QueueObj => $QueueObj,
                                       Right    => 'OwnTicket' ) )
      ) {

        $RT::Logger->warning( "$self user "
                              . $Owner->Name . "("
                              . $Owner->id
                              . ") was proposed "
                              . "as a ticket owner but has no rights to own "
                              . "tickets in this queue\n" );

        push @non_fatal_errors, $self->loc("Invalid owner. Defaulting to 'nobody'.");

        $Owner = undef;
    }

    #If we haven't been handed a valid owner, make it nobody.
    unless ( defined($Owner) ) {
        $Owner = new RT::User( $self->CurrentUser );
        $Owner->Load( $RT::Nobody->UserObj->Id );
    }

    # }}}

    unless ( $self->ValidateStatus( $args{'Status'} ) ) {
        return ( 0, 0, $self->loc('Invalid value for status') );
    }

    if ( $args{'Status'} eq 'resolved' ) {
        $resolved = $now->ISO;
    }
    else {
        $resolved = undef;
    }

    $RT::Handle->BeginTransaction();

    my $id = $self->SUPER::Create( Queue           => $QueueObj->Id,
                                   Owner           => $Owner->Id,
                                   Subject         => $args{'Subject'},
                                   InitialPriority => $args{'InitialPriority'},
                                   FinalPriority   => $args{'FinalPriority'},
                                   Priority        => $args{'InitialPriority'},
                                   Status          => $args{'Status'},
                                   TimeWorked      => $args{'TimeWorked'},
                                   TimeLeft        => $args{'TimeLeft'},
                                   Type            => $args{'Type'},
                                   Starts          => $starts->ISO,
                                   Resolved        => $resolved,
                                   Due             => $due->ISO );

    #Set the ticket's effective ID now that we've created it.
    my ( $val, $msg ) = $self->__Set( Field => 'EffectiveId', Value => $id );

    unless ($val) {
        $RT::Logger->err("$self ->Create couldn't set EffectiveId: $msg\n");
    }

    my $create_groups_ret = $self->_CreateTicketGroups();
    unless ($create_groups_ret) {
        $RT::Logger->crit( "Couldn't create ticket groups for ticket "
                           . $self->Id
                           . ". aborting Ticket creation." );
        $self->Rollback();
        return ( 0, 0,
                 $self->loc( "Ticket could not be created due to an internal error") );
    }

    # Set the owner in the Groups table
    # We denormalize it into the Ticket table too because doing otherwise would 
    # kill performance, bigtime. It gets kept in lockstep thanks to the magic of transactionalization

    $self->OwnerGroup->_AddMember( $Owner->PrincipalId );

    # Set the requestors in the Groups table

    # Set the Cc in the Groups table

    # Set the ADminCc in the Groups table

    foreach my $watcher ( @{ $args{'Cc'} } ) {
        my ( $wval, $wmsg ) =
          $self->_AddWatcher( Type => 'Cc', Email => $watcher, Silent => 1 );
        push @non_fatal_errors, $wmsg unless ($wval);
    }

    foreach my $watcher ( @{ $args{'Requestor'} } ) {
        my ( $wval, $wmsg ) = $self->_AddWatcher( Type   => 'Requestor',
                                                  Email  => $watcher,
                                                  Silent => 1 );
        push @non_fatal_errors, $wmsg unless ($wval);
    }

    foreach my $watcher ( @{ $args{'AdminCc'} } ) {

        # Note that we're using AddWatcher, rather than _AddWatcher, as we 
        # actually _want_ that ACL check. Otherwise, random ticket creators
        # could make themselves adminccs and maybe get ticket rights. that would
        # be poor
        my ( $wval, $wmsg ) = $self->AddWatcher( Type   => 'AdminCc',
                                                 Email  => $watcher,
                                                 Silent => 1 );
        push @non_fatal_errors, $wmsg unless ($wval);
    }

    #Add a transaction for the create
    my ( $Trans, $Msg, $TransObj ) = $self->_NewTransaction(
                                                     Type      => "Create",
                                                     TimeTaken => 0,
                                                     MIMEObj => $args{'MIMEObj'}
    );

    # Logging
    if ( $self->Id && $Trans ) {
        $ErrStr = $self->loc("Ticket [_1] created in queue '[_2]'", $self->Id, $QueueObj->Name);
        $ErrStr .= join ( "\n", @non_fatal_errors );

        $RT::Logger->info($ErrStr);
    }
    else {
        $RT::Handle->Rollback();

        # TODO where does this get errstr from?
        $RT::Logger->error("Ticket couldn't be created: $ErrStr");
        return ( 0, 0,
                 $self->loc( "Ticket could not be created due to an internal error") );
    }

    $RT::Handle->Commit();
    return ( $self->Id, $TransObj->Id, $ErrStr );
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
        $self->CurrentUser->HasQueueRight(
            Right    => 'CreateTicket',
            QueueObj => $QueueObj
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
            !$Owner->HasQueueRight(
                QueueObj => $QueueObj,
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
        Subject         => $args{'Subject'},
        InitialPriority => $args{'InitialPriority'},
        FinalPriority   => $args{'FinalPriority'},
        Priority        => $args{'InitialPriority'},
        Status          => $args{'Status'},
        TimeWorked      => $args{'TimeWorked'},
        Type            => $args{'Type'},
        Created         => $args{'Created'},
        Told            => $args{'Told'},
        LastUpdated     => $args{'Updated'},
        Due             => $args{'Due'},
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

# {{{ sub Delete

sub Delete {
    my $self = shift;
    return ( 0,
        $self->loc("Deleting this object would violate referential integrity.") );
}

# }}}

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
                Requestor => ['jesse@fsck.com'],
                Queue => '1'
                );
ok ($id, "Ticket $id was created");
ok(my $group = RT::Group->new($RT::SystemUser));
ok($group->LoadTicketGroup(Ticket => $id, Type=> 'Requestor'));
ok ($group->Id, "Found the requestors object for this ticket");

ok(my $jesse = RT::User->new($RT::SystemUser), "Creating a jesse rt::user");
$jesse->LoadByEmail('jesse@fsck.com');
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
ok($group->LoadTicketGroup(Ticket => $id, Type=> 'Cc'));
ok ($group->Id, "Found the cc object for this ticket");
$group = RT::Group->new($RT::SystemUser);
ok($group->LoadTicketGroup(Ticket => $id, Type=> 'AdminCc'));
ok ($group->Id, "Found the AdminCc object for this ticket");
$group = RT::Group->new($RT::SystemUser);
ok($group->LoadTicketGroup(Ticket => $id, Type=> 'Owner'));
ok ($group->Id, "Found the Owner object for this ticket");
ok($group->HasMember($RT::SystemUser->UserObj->PrincipalObj), "the owner group has the member 'RT_System'");

=end testing

=cut


sub _CreateTicketGroups {
    my $self = shift;
    
    my @types = qw(Requestor Owner Cc AdminCc);

    foreach my $type (@types) {
        my $type_obj = RT::Group->new($self->CurrentUser);
        my ($id, $msg) = $type_obj->CreateRoleGroup(Domain => 'TicketRole',
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
    $owner_obj->LoadTicketGroup( Ticket => $self->Id,  Type => 'Owner');
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
    if ($args{'PrincipalId'}) {
        $principal->Load($args{'PrincipalId'});
    } 
    elsif ($args{'Email'}) {

        my $user = RT::User->new($self->CurrentUser);
        $user->LoadByEmail($args{'Email'});

        unless ($user->Id) {
            $user->Load($args{'Email'});
        }
        if ($user->Id) { # If the user exists
            $principal->Load($user->PrincipalId);
        } else {
        
        # if the user doesn't exist, we need to create a new user
             my $new_user = RT::User->new($RT::SystemUser);

            my ( $Val, $Message ) = $new_user->Create(
                Name => $args{'Email'},
                EmailAddress => $args{'Email'},
                RealName     => $args{'Email'},
                Privileged   => 0,
                Comments     => 'Autocreated when added as a watcher');
            unless ($Val) { 
                $RT::Logger->error("Failed to create user ".$args{'Email'} .": " .$Message);
                # Deal with the race condition of two account creations at once
                $new_user->LoadByEmail($args{'Email'});
            }
            $principal->Load($new_user->PrincipalId);
        }
    } 
    # If we can't find this watcher, we need to bail.
    unless ($principal->Id) {
        return(0, $self->loc("Could not find or create that user"));
    }


    my $group = RT::Group->new($self->CurrentUser);
    $group->LoadTicketGroup(Type => $args{'Type'}, Ticket => $self->Id);
    unless ($group->id) {
        return(0,$self->loc("Group not found"));
    }

    if ( $group->HasMember( $principal)) {

        return ( 0, $self->loc('That principal is already a [_1] for this ticket', $args{'Type'}) );
    }


    my ($m_id, $m_msg) = $group->_AddMember($principal->Id);
    unless ($m_id) {
        $RT::Logger->error("Failed to add ".$principal->Id." as a member of group ".$group->Id."\n".$m_msg);

        return ( 0, $self->loc('Could not make that principal a [_1] for this ticket', $args{'Type'}) );
    }

    unless ( $args{'Silent'} ) {
        $self->_NewTransaction(
            Type     => 'AddWatcher',
            NewValue => $principal->Id,
            Field    => $args{'Type'}
        );
    }

        return ( 1, $self->loc('Added principal as a [_1] for this ticket', $args{'Type'}) );
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
                 @_ );

    unless ($args{'PrincipalId'} ) {
        return(0, $self->loc("No principal specified"));
    }
    my $principal = RT::Principal->new($self->CurrentUser);
    $principal->Load($args{'PrincipalId'});

    # If we can't find this watcher, we need to bail.
    unless ($principal->Id) {
        return(0, $self->loc("Could not find that principal"));
    }

    my $group = RT::Group->new($self->CurrentUser);
    $group->LoadTicketGroup(Type => $args{'Type'}, Ticket => $self->Id);
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
            $RT::Logger->warn( "$self -> DelWatcher got passed a bogus type");
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
        $group->LoadTicketGroup(Type => 'Requestor', Ticket => $self->Id);
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
        $group->LoadTicketGroup(Type => 'Cc', Ticket => $self->Id);
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
        $group->LoadTicketGroup(Type => 'AdminCc', Ticket => $self->Id);
    }
    return ($group);

}

# }}}

# }}}

# {{{ IsWatcher,IsRequestor,IsCc, IsAdminCc

# {{{ sub IsWatcher
# a generic routine to be called by IsRequestor, IsCc and IsAdminCc

=head2 IsWatcher { Type => TYPE, PrincipalId => PRINCIPAL_ID }

Takes a param hash with the attributes Type and PrincipalId

Type is one of Requestor, Cc, AdminCc and Owner

PrincipalId is an RT::Principal id 

Returns true if that principal is a member of the group Type for this ticket


=cut

sub IsWatcher {
    my $self = shift;

    my %args = ( Type  => 'Requestor',
        PrincipalId    => undef,
        @_
    );

    # Load the relevant group. 
    my $group = RT::Group->new($self->CurrentUser);
    $group->LoadTicketGroup(Type => $args{'Type'}, Ticket => $self->id);
    # Ask if it has the member in question

    my $principal = RT::Principal->new($self->CurrentUser);
    $principal->Load($args{'PrincipalId'});

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

    #TODO I don't think this should be here. We shouldn't allow anything to have an undef queue,
    if ( !$Value ) {
        $RT::Logger->warning(
" RT:::Queue::ValidateQueue called with a null value. this isn't ok."
        );
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
        $self->CurrentUser->HasQueueRight(
            Right    => 'CreateTicket',
            QueueObj => $NewQueueObj
        )
      )
    {
        return ( 0, $self->loc("You may not create requests in that queue.") );
    }

    unless (
        $self->OwnerObj->HasQueueRight(
            Right    => 'OwnTicket',
            QueueObj => $NewQueueObj
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

# {{{ sub GraceTimeAsString 

=head2 GraceTimeAsString

Return the time until this ticket is due as a string

=cut

# TODO This should be deprecated 

sub GraceTimeAsString {
    my $self = shift;

    if ( $self->Due ) {
        return ( $self->DueObj->AgeAsString() );
    }
    else {
        return "";
    }
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

# {{{ sub LongSinceToldAsString

# TODO this should be deprecated

sub LongSinceToldAsString {
    my $self = shift;

    if ( $self->Told ) {
        return $self->ToldObj->AgeAsString();
    }
    else {
        return "Never";
    }
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
Takes a hashref with the follwoing attributes:

MIMEObj, TimeTaken, CcMessageTo, BccMessageTo

=cut

sub Comment {
    my $self = shift;

    my %args = (
        CcMessageTo  => undef,
        BccMessageTo => undef,
        MIMEObj      => undef,
        TimeTaken    => 0,
        @_
    );

    unless ( ( $self->CurrentUserHasRight('CommentOnTicket') )
        or ( $self->CurrentUserHasRight('ModifyTicket') ) )
    {
        return ( 0, $self->loc("Permission Denied") );
    }

    unless ( $args{'MIMEObj'} ) {
        return ( 0, $self->loc("No correspondence attached") );
    }

    # If we've been passed in CcMessageTo and BccMessageTo fields,
    # add them to the mime object for passing on to the transaction handler
    # The "NotifyOtherRecipients" scripAction will look for RT--Send-Cc: and
    # RT-Send-Bcc: headers

    $args{'MIMEObj'}->head->add( 'RT-Send-Cc',  $args{'CcMessageTo'} );
    $args{'MIMEObj'}->head->add( 'RT-Send-Bcc', $args{'BccMessageTo'} );

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


MIMEObj, TimeTaken, CcMessageTo, BccMessageTo

=cut

sub Correspond {
    my $self = shift;
    my %args = (
        CcMessageTo  => undef,
        BccMessageTo => undef,
        MIMEObj      => undef,
        TimeTaken    => 0,
        @_
    );

    unless ( ( $self->CurrentUserHasRight('ReplyToTicket') )
        or ( $self->CurrentUserHasRight('ModifyTicket') ) )
    {
        return ( 0, $self->loc("Permission Denied") );
    }

    unless ( $args{'MIMEObj'} ) {
        return ( 0, $self->loc("No correspondence attached") );
    }

    # If we've been passed in CcMessageTo and BccMessageTo fields,
    # add them to the mime object for passing on to the transaction handler
    # The "NotifyOtherRecipients" scripAction will look for RT-Send-Cc: and RT-Send-Bcc:
    # headers

    $args{'MIMEObj'}->head->add( 'RT-Send-Cc',  $args{'CcMessageTo'} );
    $args{'MIMEObj'}->head->add( 'RT-Send-Bcc', $args{'BccMessageTo'} );

    #Record the correspondence (write the transaction)
    my ( $Trans, $msg, $TransObj ) = $self->_NewTransaction(
        Type      => 'Correspond',
        Data      => ( $args{'MIMEObj'}->head->get('subject') || 'No Subject' ),
        TimeTaken => $args{'TimeTaken'},
        MIMEObj   => $args{'MIMEObj'}
    );

    # TODO this bit of logic should really become a scrip for 2.2
    my $TicketAsSystem = new RT::Ticket($RT::SystemUser);
    $TicketAsSystem->Load( $self->Id );

    if ( ( $TicketAsSystem->Status ne 'open' )
        and ( $TicketAsSystem->Status ne 'new' ) )
    {

        my $oldstatus = $TicketAsSystem->Status();
        $TicketAsSystem->__Set( Field => 'Status', Value => 'open' );
        $TicketAsSystem->_NewTransaction(
            Type     => 'Set',
            Field    => 'Status',
            OldValue => $oldstatus,
            NewValue => 'open',
            Data     => 'Ticket auto-opened on incoming correspondence'
        );
    }

    unless ($Trans) {
        $RT::Logger->err($self->loc("[_1] couldn't init a transaction ([_2])\n", $self, $msg) );
        return ( $Trans, $self->loc("correspondence (probably) not sent"),
            $args{'MIMEObj'} );
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

            $self->{"$field$type"}->Limit( FIELD => $field,
                VALUE => $self->URI );
            $self->{"$field$type"}->Limit(
                FIELD => 'Type',
                VALUE => $type
              )
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

    if ( $args{'Base'} and $args{'Target'} ) {
        $RT::Logger->debug("$self ->_DeleteLink. got both Base and Target\n");
        return ( 0, $self->loc("Can't specifiy both base and target") );
    }
    elsif ( $args{'Base'} ) {
        $args{'Target'} = $self->Id();
    }
    elsif ( $args{'Target'} ) {
        $args{'Base'} = $self->Id();
    }
    else {
        $RT::Logger->debug("$self: Base or Target must be specified\n");
        return ( 0, $self->loc('Either base or target must be specified') );
    }

    my $link = new RT::Link( $self->CurrentUser );
    $RT::Logger->debug( "Trying to load link: "
          . $args{'Base'} . " "
          . $args{'Type'} . " "
          . $args{'Target'} . "\n" );

    $link->Load( $args{'Base'}, $args{'Type'}, $args{'Target'} );

    #it's a real link. 
    if ( $link->id ) {
        $RT::Logger->debug( "We're going to delete link " . $link->id . "\n" );
        $link->Delete();

        my $TransString =
          "Ticket $args{'Base'} no longer $args{Type} ticket $args{'Target'}.";
        my ( $Trans, $Msg, $TransObj ) = $self->_NewTransaction(
            Type      => 'DeleteLink',
            Field     => $args{'Type'},
            Data      => $TransString,
            TimeTaken => 0
        );

        return ( $linkid, loc("Link deleted ([_1])", $TransString), $transactionid );
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
    my %args = (
        Target => '',
        Base   => '',
        Type   => '',
        @_
    );

    unless ( $self->CurrentUserHasRight('ModifyTicket') ) {
        return ( 0, $self->loc("Permission Denied") );
    }

    if ( $args{'Base'} and $args{'Target'} ) {
        $RT::Logger->debug(
"$self tried to delete a link. both base and target were specified\n"
        );
        return ( 0, $self->loc("Can't specifiy both base and target") );
    }
    elsif ( $args{'Base'} ) {
        $args{'Target'} = $self->Id();
    }
    elsif ( $args{'Target'} ) {
        $args{'Base'} = $self->Id();
    }
    else {
        return ( 0, $self->loc('Either base or target must be specified') );
    }

    # {{{ We don't want references to ourself
    if ( $args{Base} eq $args{Target} ) {
        return ( 0, $self->loc("Can't link a ticket to itself") );
    }

    # }}}

    # If the base isn't a URI, make it a URI. 
    # If the target isn't a URI, make it a URI. 

    # {{{ Check if the link already exists - we don't want duplicates
    my $old_link = new RT::Link( $self->CurrentUser );
    $old_link->Load( $args{'Base'}, $args{'Type'}, $args{'Target'} );
    if ( $old_link->Id ) {
        $RT::Logger->debug("$self Somebody tried to duplicate a link");
        return ( $old_link->id, $self->loc("Link already exists"), 0 );
    }

    # }}}

    # Storing the link in the DB.
    my $link = RT::Link->new( $self->CurrentUser );
    my ($linkid) = $link->Create(
        Target => $args{Target},
        Base   => $args{Base},
        Type   => $args{Type}
    );

    unless ($linkid) {
        return ( 0, $self->loc("Link could not be created") );
    }

    #Write the transaction

    my $TransString =
      "Ticket $args{'Base'} $args{Type} ticket $args{'Target'}.";

    my ( $Trans, $Msg, $TransObj ) = $self->_NewTransaction(
        Type      => 'AddLink',
        Field     => $args{'Type'},
        Data      => $TransString,
        TimeTaken => 0
    );

    return ( $Trans, $self->loc("Link created ([_1])", $TransString) );

}

# }}}

# {{{ sub URI 

=head2 URI

Returns this ticket's URI

=cut

sub URI {
    my $self = shift;
    return $RT::TicketBaseURI . $self->id;
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
        $RT::Logger->err( '$self trying to merge into '
              . $NewTicket->Id
              . ' which is itself merged.\n' );
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

    my ( $status_val, $status_msg ) = $self->__Set(
        Field => 'Status',
        Value => 'resolved'
    );

    unless ($status_val) {
        $RT::Logger->error( $self->loc("[_1] couldn't set status to resolved. RT's Database may be inconsistent.", $self) );
    }

    #make a new link: this ticket is merged into that other ticket.
    $self->AddLink(
        Type   => 'MergedInto',
        Target => $NewTicket->Id()
    );

    #add all of this ticket's watchers to that ticket.
    # TODO: XXX when merging, we need to merge watchers

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

    return ( $TransactionObj, $self->loc("Merge Successful") );
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

    $owner = new RT::User( $self->CurrentUser );
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

=cut

sub SetOwner {
    my $self     = shift;
    my $NewOwner = shift;
    my $Type     = shift || "Give";

    unless ( $self->CurrentUserHasRight('ModifyTicket') ) {
        return ( 0, $self->loc("Permission Denied") );
    }

    my $NewOwnerObj = RT::User->new( $self->CurrentUser );
    my $OldOwnerObj = $self->OwnerObj;

    if ( !$NewOwnerObj->Load($NewOwner) ) {
        return ( 0, $self->loc("That user does not exist") );
    }

    #If thie ticket has an owner and it's not the current user

    if ( ( $Type ne 'Steal' )
        and ( $Type ne 'Force' )
        and    #If we're not stealing
        ( $self->OwnerObj->Id != $RT::Nobody->Id ) and    #and the owner is set
        ( $self->CurrentUser->Id ne $self->OwnerObj->Id() ) )
    {    #and it's not us
        return ( 0,
            $self->loc("You can only reassign tickets that you own or that are unowned") );
    }

    #If we've specified a new owner and that user can't modify the ticket
    elsif (
        ($NewOwnerObj)
        and (
            !$NewOwnerObj->HasQueueRight(
                Right     => 'OwnTicket',
                QueueObj  => $self->QueueObj,
                TicketObj => $self
            )
        )
      )
    {
        return ( 0, $self->loc("That user may not own tickets in that queue") );
    }

    #If the ticket has an owner and it's the new owner, we don't need
    #To do anything
    elsif ( ( $self->OwnerObj )
        and ( $NewOwnerObj->Id eq $self->OwnerObj->Id ) )
    {
        return ( 0, $self->loc("That user already owns that ticket") );
    }

    $RT::Handle->BeginTransaction();

    # Delete the owner in the owner group, then add a new one
    # TODO: is this safe? it's not how we really want the API to work 
    # for most things, but it's fast.
    my ($del_id, $del_msg) = $self->OwnerGroup->Members->First->Delete();
    unless ($del_id) {
        $RT::Handle->Rollback();
        return(0, $self->loc("Could not change owner. "). $del_msg);
    }

    my ($add_id,$add_msg) = $self->OwnerGroup->_AddMember($NewOwnerObj->PrincipalId);
    unless ($add_id) {
        $RT::Handle->Rollback();
        return(0, $self->loc("Could not change owner. "). $add_msg);
    }
    
    my ( $trans, $msg ) = $self->_Set(
        Field           => 'Owner',
        Value           => $NewOwnerObj->Id,
        TimeTaken       => 0,
        TransactionType => $Type
    );

    if ($trans) {
        $msg = "Owner changed from " . $OldOwnerObj->Name . " to " . $NewOwnerObj->Name;
    }
    $RT::Handle->Commit();
    $RT::Logger->crit("RT::Ticket->SetOwner lets a transaction span across scrips. this is DANGEROUS AND MUST CHANGE");
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

Set this ticket\'s status. STATUS can be one of: new, open, stalled, resolved or dead.

=cut

sub SetStatus {
    my $self   = shift;
    my $status = shift;

    #Check ACL
    unless ( $self->CurrentUserHasRight('ModifyTicket') ) {
        return ( 0, $self->loc('Permission Denied') );
    }

    my $now = new RT::Date( $self->CurrentUser );
    $now->SetToNow();

    #If we're changing the status from new, record that we've started
    if ( ( $self->Status =~ /new/ ) && ( $status ne 'new' ) ) {

        #Set the Started time to "now"
        $self->_Set(
            Field             => 'Started',
            Value             => $now->ISO,
            RecordTransaction => 0
        );
    }

    if ( $status eq 'resolved' ) {

        #When we resolve a ticket, set the 'Resolved' attribute to now.
        $self->_Set(
            Field             => 'Resolved',
            Value             => $now->ISO,
            RecordTransaction => 0
        );
    }

    #Actually update the status
    return (
        $self->_Set(
            Field           => 'Status',
            Value           => $status,
            TimeTaken       => 0,
            TransactionType => 'Status'
          )
    );
}

# }}}

# {{{ sub Kill

=head2 Kill

Takes no arguments. Marks this ticket for garbage collection

=cut

sub Kill {
    my $self = shift;
    return ( $self->SetStatus('dead') );

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

=head2

Sets this ticket\'s status to Resolved

=cut

sub Resolve {
    my $self = shift;
    return ( $self->SetStatus('resolved') );
}

# }}}

# }}}

# {{{ Routines dealing with custom fields

# {{{ CustomFieldValues

=item CustomFieldValues FIELD

Return a TicketCustomFieldValues object of all values of CustomField FIELD for this ticket.  
Takes a field id 


=cut

sub CustomFieldValues {
    my $self  = shift;
    my $field = shift;

    my $cf = RT::CustomField->new($self->CurrentUser);
    
    $cf->LoadById($field);

    my $cf_values = RT::TicketCustomFieldValues->new( $self->CurrentUser );
    $cf_values->LimitToCustomField($cf->id);

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
    my %args = (
        Field => undef,
        Value => undef,
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
        return ( 0, loc("Custom field [_1] not found", $args{'Field'}) );
    }

    # Load up a TicketCustomFieldValues object for this custom field and this ticket
    my $values = $cf->ValuesForTicket( $self->id );

    unless ( $cf->ValidateValue( $args{'Value'} ) ) {
        return ( 0, loc("Invalid value for custom field") );
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

        my $value     = $cf->ValuesForTicket( $self->Id )->First;
        my $old_value = $value->Content();

        my ( $new_value_id, $value_msg ) = $cf->AddValueForTicket(
            Ticket  => $self->Id,
            Content => $args{'Value'}
        );

        $RT::Logger->debug ("added a custom field value : $value_msg\n");
        unless ($new_value_id) {
            return ( 0,
                $self->loc("Could not add new custom field value for ticket. [_1] ",
                  ,$value_msg) );
        }

        my $new_value = RT::TicketCustomFieldValue->new( $self->CurrentUser );
        $new_value->Load($value_id);

        # now that adding the new value was successful, delete the old one
        my ($val, $msg) = $cf->DeleteValueForTicket(Ticket => $self->Id, Content => $value->Content);
        unless ($val) { 
                  return (0,$msg);
        }

        my ( $TransactionId, $Msg, $TransactionObj ) = $self->_NewTransaction(
            Type     => 'CustomField',
            Field    => $cf->Id,
            OldValue => $old_value,
            NewValue => $new_value->Content
        );
        return ( 1, $self->loc("Custom field value changed from [_1] to [_2]" , $old_value, $new_value->Content ));

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

        my ( $TransactionId, $Msg, $TransactionObj ) = $self->_NewTransaction(
            Type     => 'CustomField',
            Field    => $cf->Id,
            NewValue => $args{'Value'}
        );
        unless($TransactionId) {
            return(0, $self->loc("Couldn't create a transaction: [_1]", $Msg));
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
          TimeWorked      => { 'read' => 1,  'write' => 1 },
          TimeLeft        => { 'read' => 1,  'write' => 1 },
          Created         => { 'read' => 1,  'auto'  => 1 },
          Creator         => { 'read' => 1,  'auto'  => 1 },
          Told            => { 'read' => 1,  'write' => 1 },
          Resolved        => { 'read' => 1 },
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

    unless ( $self->CurrentUserHasRight('ModifyTicket') ) {
        return ( 0, $self->loc("Permission Denied") );
    }

    my %args = (
        Field             => undef,
        Value             => undef,
        TimeTaken         => 0,
        RecordTransaction => 1,
        TransactionType   => 'Set',
        @_
    );

    #if the user is trying to modify the record

    #Take care of the old value we really don't want to get in an ACL loop.
    # so ask the super::_Value
    my $Old = $self->SUPER::_Value("$args{'Field'}");

    #Set the new value
    my ( $ret, $msg ) = $self->SUPER::_Set(
        Field => $args{'Field'},
        Value => $args{'Value'}
    );

    #If we can't actually set the field to the value, don't record
    # a transaction. instead, get out of here.
    if ( $ret == 0 ) { return ( 0, $msg ); }

    if ( $args{'RecordTransaction'} == 1 ) {

        my ( $Trans, $Msg, $TransObj ) = $self->_NewTransaction(
            Type      => $args{'TransactionType'},
            Field     => $args{'Field'},
            NewValue  => $args{'Value'},
            OldValue  => $Old,
            TimeTaken => $args{'TimeTaken'},
        );
        return ( $Trans, $TransObj->Description );
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
        $args{'Principal'}->HasQueueRight(
            TicketObj => $self,
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

