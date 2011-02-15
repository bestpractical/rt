# BEGIN BPS TAGGED BLOCK {{{
#
# COPYRIGHT:
#
# This software is Copyright (c) 1996-2011 Best Practical Solutions, LLC
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

# {{{ Front Material 

=head1 SYNOPSIS

  use RT::Ticket;
  my $ticket = new RT::Ticket($CurrentUser);
  $ticket->Load($ticket_id);

=head1 DESCRIPTION

This module lets you manipulate RT\'s ticket object.


=head1 METHODS


=cut


package RT::Ticket;

use strict;
no warnings qw(redefine);

use RT::Queue;
use RT::User;
use RT::Record;
use RT::Links;
use RT::Date;
use RT::CustomFields;
use RT::Tickets;
use RT::Transactions;
use RT::Reminders;
use RT::URI::fsck_com_rt;
use RT::URI;
use MIME::Entity;


# {{{ LINKTYPEMAP
# A helper table for links mapping to make it easier
# to build and parse links between tickets

our %LINKTYPEMAP = (
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
    MergedInto => { Type => 'MergedInto',
                   Mode => 'Target', },

);

# }}}

# {{{ LINKDIRMAP
# A helper table for links mapping to make it easier
# to build and parse links between tickets

our %LINKDIRMAP = (
    MemberOf => { Base => 'MemberOf',
                  Target => 'HasMember', },
    RefersTo => { Base => 'RefersTo',
                Target => 'ReferredToBy', },
    DependsOn => { Base => 'DependsOn',
                   Target => 'DependedOnBy', },
    MergedInto => { Base => 'MergedInto',
                   Target => 'MergedInto', },

);

# }}}

sub LINKTYPEMAP   { return \%LINKTYPEMAP   }
sub LINKDIRMAP   { return \%LINKDIRMAP   }

our %MERGE_CACHE = (
    effective => {},
    merged => {},
);

# {{{ sub Load

=head2 Load

Takes a single argument. This can be a ticket id, ticket alias or 
local ticket uri.  If the ticket can't be loaded, returns undef.
Otherwise, returns the ticket id.

=cut

sub Load {
    my $self = shift;
    my $id   = shift;
    $id = '' unless defined $id;

    # TODO: modify this routine to look at EffectiveId and
    # do the recursive load thing. be careful to cache all
    # the interim tickets we try so we don't loop forever.

    # FIXME: there is no TicketBaseURI option in config
    my $base_uri = RT->Config->Get('TicketBaseURI') || '';
    #If it's a local URI, turn it into a ticket id
    if ( $base_uri && $id =~ /^$base_uri(\d+)$/ ) {
        $id = $1;
    }

    unless ( $id =~ /^\d+$/ ) {
        $RT::Logger->debug("Tried to load a bogus ticket id: '$id'");
        return (undef);
    }

    $id = $MERGE_CACHE{'effective'}{ $id }
        if $MERGE_CACHE{'effective'}{ $id };

    my ($ticketid, $msg) = $self->LoadById( $id );
    unless ( $self->Id ) {
        $RT::Logger->debug("$self tried to load a bogus ticket: $id");
        return (undef);
    }

    #If we're merged, resolve the merge.
    if ( $self->EffectiveId && $self->EffectiveId != $self->Id ) {
        $RT::Logger->debug(
            "We found a merged ticket. "
            . $self->id ."/". $self->EffectiveId
        );
        my $real_id = $self->Load( $self->EffectiveId );
        $MERGE_CACHE{'effective'}{ $id } = $real_id;
        return $real_id;
    }

    #Ok. we're loaded. lets get outa here.
    return $self->Id;
}

# }}}

# {{{ sub Create

=head2 Create (ARGS)

Arguments: ARGS is a hash of named parameters.  Valid parameters are:

  id 
  Queue  - Either a Queue object or a Queue Name
  Requestor -  A reference to a list of  email addresses or RT user Names
  Cc  - A reference to a list of  email addresses or Names
  AdminCc  - A reference to a  list of  email addresses or Names
  SquelchMailTo - A reference to a list of email addresses - 
                  who should this ticket not mail
  Type -- The ticket\'s type. ignore this for now
  Owner -- This ticket\'s owner. either an RT::User object or this user\'s id
  Subject -- A string describing the subject of the ticket
  Priority -- an integer from 0 to 99
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

Ticket links can be set up during create by passing the link type as a hask key and
the ticket id to be linked to as a value (or a URI when linking to other objects).
Multiple links of the same type can be created by passing an array ref. For example:

  Parents => 45,
  DependsOn => [ 15, 22 ],
  RefersTo => 'http://www.bestpractical.com',

Supported link types are C<MemberOf>, C<HasMember>, C<RefersTo>, C<ReferredToBy>,
C<DependsOn> and C<DependedOnBy>. Also, C<Parents> is alias for C<MemberOf> and
C<Members> and C<Children> are aliases for C<HasMember>.

Returns: TICKETID, Transaction Object, Error Message


=cut

sub Create {
    my $self = shift;

    my %args = (
        id                 => undef,
        EffectiveId        => undef,
        Queue              => undef,
        Requestor          => undef,
        Cc                 => undef,
        AdminCc            => undef,
        SquelchMailTo      => undef,
        Type               => 'ticket',
        Owner              => undef,
        Subject            => '',
        InitialPriority    => undef,
        FinalPriority      => undef,
        Priority           => undef,
        Status             => 'new',
        TimeWorked         => "0",
        TimeLeft           => 0,
        TimeEstimated      => 0,
        Due                => undef,
        Starts             => undef,
        Started            => undef,
        Resolved           => undef,
        MIMEObj            => undef,
        _RecordTransaction => 1,
        DryRun             => 0,
        @_
    );

    my ($ErrStr, @non_fatal_errors);

    my $QueueObj = RT::Queue->new( $RT::SystemUser );
    if ( ref $args{'Queue'} eq 'RT::Queue' ) {
        $QueueObj->Load( $args{'Queue'}->Id );
    }
    elsif ( $args{'Queue'} ) {
        $QueueObj->Load( $args{'Queue'} );
    }
    else {
        $RT::Logger->debug("'". ( $args{'Queue'} ||''). "' not a recognised queue object." );
    }

    #Can't create a ticket without a queue.
    unless ( $QueueObj->Id ) {
        $RT::Logger->debug("$self No queue given for ticket creation.");
        return ( 0, 0, $self->loc('Could not create ticket. Queue not set') );
    }


    #Now that we have a queue, Check the ACLS
    unless (
        $self->CurrentUser->HasRight(
            Right  => 'CreateTicket',
            Object => $QueueObj
        )
      )
    {
        return (
            0, 0,
            $self->loc( "No permission to create tickets in the queue '[_1]'", $QueueObj->Name));
    }

    unless ( $QueueObj->IsValidStatus( $args{'Status'} ) ) {
        return ( 0, 0, $self->loc('Invalid value for status') );
    }

    #Since we have a queue, we can set queue defaults

    #Initial Priority
    # If there's no queue default initial priority and it's not set, set it to 0
    $args{'InitialPriority'} = $QueueObj->InitialPriority || 0
        unless defined $args{'InitialPriority'};

    #Final priority
    # If there's no queue default final priority and it's not set, set it to 0
    $args{'FinalPriority'} = $QueueObj->FinalPriority || 0
        unless defined $args{'FinalPriority'};

    # Priority may have changed from InitialPriority, for the case
    # where we're importing tickets (eg, from an older RT version.)
    $args{'Priority'} = $args{'InitialPriority'}
        unless defined $args{'Priority'};

    # {{{ Dates
    #TODO we should see what sort of due date we're getting, rather +
    # than assuming it's in ISO format.

    #Set the due date. if we didn't get fed one, use the queue default due in
    my $Due = new RT::Date( $self->CurrentUser );
    if ( defined $args{'Due'} ) {
        $Due->Set( Format => 'ISO', Value => $args{'Due'} );
    }
    elsif ( my $due_in = $QueueObj->DefaultDueIn ) {
        $Due->SetToNow;
        $Due->AddDays( $due_in );
    }

    my $Starts = new RT::Date( $self->CurrentUser );
    if ( defined $args{'Starts'} ) {
        $Starts->Set( Format => 'ISO', Value => $args{'Starts'} );
    }

    my $Started = new RT::Date( $self->CurrentUser );
    if ( defined $args{'Started'} ) {
        $Started->Set( Format => 'ISO', Value => $args{'Started'} );
    }
    elsif ( $args{'Status'} ne 'new' ) {
        $Started->SetToNow;
    }

    my $Resolved = new RT::Date( $self->CurrentUser );
    if ( defined $args{'Resolved'} ) {
        $Resolved->Set( Format => 'ISO', Value => $args{'Resolved'} );
    }

    #If the status is an inactive status, set the resolved date
    elsif ( $QueueObj->IsInactiveStatus( $args{'Status'} ) )
    {
        $RT::Logger->debug( "Got a ". $args{'Status'}
            ."(inactive) ticket with undefined resolved date. Setting to now."
        );
        $Resolved->SetToNow;
    }

    # }}}

    # {{{ Dealing with time fields

    $args{'TimeEstimated'} = 0 unless defined $args{'TimeEstimated'};
    $args{'TimeWorked'}    = 0 unless defined $args{'TimeWorked'};
    $args{'TimeLeft'}      = 0 unless defined $args{'TimeLeft'};

    # }}}

    # {{{ Deal with setting the owner

    my $Owner;
    if ( ref( $args{'Owner'} ) eq 'RT::User' ) {
        if ( $args{'Owner'}->id ) {
            $Owner = $args{'Owner'};
        } else {
            $RT::Logger->error('passed not loaded owner object');
            push @non_fatal_errors, $self->loc("Invalid owner object");
            $Owner = undef;
        }
    }

    #If we've been handed something else, try to load the user.
    elsif ( $args{'Owner'} ) {
        $Owner = RT::User->new( $self->CurrentUser );
        $Owner->Load( $args{'Owner'} );
        $Owner->LoadByEmail( $args{'Owner'} )
            unless $Owner->Id;
        unless ( $Owner->Id ) {
            push @non_fatal_errors,
                $self->loc("Owner could not be set.") . " "
              . $self->loc( "User '[_1]' could not be found.", $args{'Owner'} );
            $Owner = undef;
        }
    }

    #If we have a proposed owner and they don't have the right
    #to own a ticket, scream about it and make them not the owner
   
    my $DeferOwner;  
    if ( $Owner && $Owner->Id != $RT::Nobody->Id 
        && !$Owner->HasRight( Object => $QueueObj, Right  => 'OwnTicket' ) )
    {
        $DeferOwner = $Owner;
        $Owner = undef;
        $RT::Logger->debug('going to deffer setting owner');

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
        $args{ $type } = [ $args{ $type } ] unless ref $args{ $type };
        foreach my $watcher ( splice @{ $args{$type} } ) {
            next unless $watcher;
            if ( $watcher =~ /^\d+$/ ) {
                push @{ $args{$type} }, $watcher;
            } else {
                my @addresses = RT::EmailParser->ParseEmailAddress( $watcher );
                foreach my $address( @addresses ) {
                    my $user = RT::User->new( $RT::SystemUser );
                    my ($uid, $msg) = $user->LoadOrCreateByEmail( $address );
                    unless ( $uid ) {
                        push @non_fatal_errors,
                            $self->loc("Couldn't load or create user: [_1]", $msg);
                    } else {
                        push @{ $args{$type} }, $user->id;
                    }
                }
            }
        }
    }

    $RT::Handle->BeginTransaction();

    my %params = (
        Queue           => $QueueObj->Id,
        Owner           => $Owner->Id,
        Subject         => $args{'Subject'},
        InitialPriority => $args{'InitialPriority'},
        FinalPriority   => $args{'FinalPriority'},
        Priority        => $args{'Priority'},
        Status          => $args{'Status'},
        TimeWorked      => $args{'TimeWorked'},
        TimeEstimated   => $args{'TimeEstimated'},
        TimeLeft        => $args{'TimeLeft'},
        Type            => $args{'Type'},
        Starts          => $Starts->ISO,
        Started         => $Started->ISO,
        Resolved        => $Resolved->ISO,
        Due             => $Due->ISO
    );

# Parameters passed in during an import that we probably don't want to touch, otherwise
    foreach my $attr qw(id Creator Created LastUpdated LastUpdatedBy) {
        $params{$attr} = $args{$attr} if $args{$attr};
    }

    # Delete null integer parameters
    foreach my $attr
        qw(TimeWorked TimeLeft TimeEstimated InitialPriority FinalPriority)
    {
        delete $params{$attr}
          unless ( exists $params{$attr} && $params{$attr} );
    }

    # Delete the time worked if we're counting it in the transaction
    delete $params{'TimeWorked'} if $args{'_RecordTransaction'};

    my ($id,$ticket_message) = $self->SUPER::Create( %params );
    unless ($id) {
        $RT::Logger->crit( "Couldn't create a ticket: " . $ticket_message );
        $RT::Handle->Rollback();
        return ( 0, 0,
            $self->loc("Ticket could not be created due to an internal error")
        );
    }

    #Set the ticket's effective ID now that we've created it.
    my ( $val, $msg ) = $self->__Set(
        Field => 'EffectiveId',
        Value => ( $args{'EffectiveId'} || $id )
    );
    unless ( $val ) {
        $RT::Logger->crit("Couldn't set EffectiveId: $msg");
        $RT::Handle->Rollback;
        return ( 0, 0,
            $self->loc("Ticket could not be created due to an internal error")
        );
    }

    my $create_groups_ret = $self->_CreateTicketGroups();
    unless ($create_groups_ret) {
        $RT::Logger->crit( "Couldn't create ticket groups for ticket "
              . $self->Id
              . ". aborting Ticket creation." );
        $RT::Handle->Rollback();
        return ( 0, 0,
            $self->loc("Ticket could not be created due to an internal error")
        );
    }

    # Set the owner in the Groups table
    # We denormalize it into the Ticket table too because doing otherwise would
    # kill performance, bigtime. It gets kept in lockstep thanks to the magic of transactionalization
    $self->OwnerGroup->_AddMember(
        PrincipalId       => $Owner->PrincipalId,
        InsideTransaction => 1
    ) unless $DeferOwner;



    # {{{ Deal with setting up watchers

    foreach my $type ( "Cc", "AdminCc", "Requestor" ) {
        # we know it's an array ref
        foreach my $watcher ( @{ $args{$type} } ) {

            # Note that we're using AddWatcher, rather than _AddWatcher, as we
            # actually _want_ that ACL check. Otherwise, random ticket creators
            # could make themselves adminccs and maybe get ticket rights. that would
            # be poor
            my $method = $type eq 'AdminCc'? 'AddWatcher': '_AddWatcher';

            my ($val, $msg) = $self->$method(
                Type   => $type,
                PrincipalId => $watcher,
                Silent => 1,
            );
            push @non_fatal_errors, $self->loc("Couldn't set [_1] watcher: [_2]", $type, $msg)
                unless $val;
        }
    } 

    if ($args{'SquelchMailTo'}) {
       my @squelch = ref( $args{'SquelchMailTo'} ) ? @{ $args{'SquelchMailTo'} }
        : $args{'SquelchMailTo'};
        $self->_SquelchMailTo( @squelch );
    }


    # }}}

    # {{{ Add all the custom fields

    foreach my $arg ( keys %args ) {
        next unless $arg =~ /^CustomField-(\d+)$/i;
        my $cfid = $1;

        foreach my $value (
            UNIVERSAL::isa( $args{$arg} => 'ARRAY' ) ? @{ $args{$arg} } : ( $args{$arg} ) )
        {
            next unless defined $value && length $value;

            # Allow passing in uploaded LargeContent etc by hash reference
            my ($status, $msg) = $self->_AddCustomFieldValue(
                (UNIVERSAL::isa( $value => 'HASH' )
                    ? %$value
                    : (Value => $value)
                ),
                Field             => $cfid,
                RecordTransaction => 0,
            );
            push @non_fatal_errors, $msg unless $status;
        }
    }

    # }}}

    # {{{ Deal with setting up links

    # TODO: Adding link may fire scrips on other end and those scrips
    # could create transactions on this ticket before 'Create' transaction.
    #
    # We should implement different schema: record 'Create' transaction,
    # create links and only then fire create transaction's scrips.
    #
    # Ideal variant: add all links without firing scrips, record create
    # transaction and only then fire scrips on the other ends of links.
    #
    # //RUZ

    foreach my $type ( keys %LINKTYPEMAP ) {
        next unless ( defined $args{$type} );
        foreach my $link (
            ref( $args{$type} ) ? @{ $args{$type} } : ( $args{$type} ) )
        {
            # Check rights on the other end of the link if we must
            # then run _AddLink that doesn't check for ACLs
            if ( RT->Config->Get( 'StrictLinkACL' ) ) {
                my ($val, $msg, $obj) = $self->__GetTicketFromURI( URI => $link );
                unless ( $val ) {
                    push @non_fatal_errors, $msg;
                    next;
                }
                if ( $obj && !$obj->CurrentUserHasRight('ModifyTicket') ) {
                    push @non_fatal_errors, $self->loc('Linking. Permission denied');
                    next;
                }
            }
            
            my ( $wval, $wmsg ) = $self->_AddLink(
                Type                          => $LINKTYPEMAP{$type}->{'Type'},
                $LINKTYPEMAP{$type}->{'Mode'} => $link,
                Silent                        => !$args{'_RecordTransaction'},
                'Silent'. ( $LINKTYPEMAP{$type}->{'Mode'} eq 'Base'? 'Target': 'Base' )
                                              => 1,
            );

            push @non_fatal_errors, $wmsg unless ($wval);
        }
    }

    # }}}
    # Now that we've created the ticket and set up its metadata, we can actually go and check OwnTicket on the ticket itself. 
    # This might be different than before in cases where extensions like RTIR are doing clever things with RT's ACL system
    if (  $DeferOwner ) { 
            if (!$DeferOwner->HasRight( Object => $self, Right  => 'OwnTicket')) {
    
            $RT::Logger->warning( "User " . $DeferOwner->Name . "(" . $DeferOwner->id 
                . ") was proposed as a ticket owner but has no rights to own "
                . "tickets in " . $QueueObj->Name );
            push @non_fatal_errors, $self->loc(
                "Owner '[_1]' does not have rights to own this ticket.",
                $DeferOwner->Name
            );
        } else {
            $Owner = $DeferOwner;
            $self->__Set(Field => 'Owner', Value => $Owner->id);

        }
        $self->OwnerGroup->_AddMember(
            PrincipalId       => $Owner->PrincipalId,
            InsideTransaction => 1
        );
    }

    if ( $args{'_RecordTransaction'} ) {

        # {{{ Add a transaction for the create
        my ( $Trans, $Msg, $TransObj ) = $self->_NewTransaction(
            Type         => "Create",
            TimeTaken    => $args{'TimeWorked'},
            MIMEObj      => $args{'MIMEObj'},
            CommitScrips => !$args{'DryRun'},
        );

        if ( $self->Id && $Trans ) {

            $TransObj->UpdateCustomFields(ARGSRef => \%args);

            $RT::Logger->info( "Ticket " . $self->Id . " created in queue '" . $QueueObj->Name . "' by " . $self->CurrentUser->Name );
            $ErrStr = $self->loc( "Ticket [_1] created in queue '[_2]'", $self->Id, $QueueObj->Name );
            $ErrStr = join( "\n", $ErrStr, @non_fatal_errors );
        }
        else {
            $RT::Handle->Rollback();

            $ErrStr = join( "\n", $ErrStr, @non_fatal_errors );
            $RT::Logger->error("Ticket couldn't be created: $ErrStr");
            return ( 0, 0, $self->loc( "Ticket could not be created due to an internal error"));
        }

        if ( $args{'DryRun'} ) {
            $RT::Handle->Rollback();
            return ($self->id, $TransObj, $ErrStr);
        }
        $RT::Handle->Commit();
        return ( $self->Id, $TransObj->Id, $ErrStr );

        # }}}
    }
    else {

        # Not going to record a transaction
        $RT::Handle->Commit();
        $ErrStr = $self->loc( "Ticket [_1] created in queue '[_2]'", $self->Id, $QueueObj->Name );
        $ErrStr = join( "\n", $ErrStr, @non_fatal_errors );
        return ( $self->Id, 0, $ErrStr );

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
        if ( defined ($args{$date}) and $args{$date} =~ /^\d+$/ ) {
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
              . $QueueObj->Name . "'" );

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
        Subject         => $args{'Subject'},        # loc
        InitialPriority => $args{'InitialPriority'},    # loc
        FinalPriority   => $args{'FinalPriority'},    # loc
        Priority        => $args{'InitialPriority'},    # loc
        Status          => $args{'Status'},        # loc
        TimeWorked      => $args{'TimeWorked'},        # loc
        Type            => $args{'Type'},        # loc
        Created         => $args{'Created'},        # loc
        Told            => $args{'Told'},        # loc
        LastUpdated     => $args{'Updated'},        # loc
        Resolved        => $args{'Resolved'},        # loc
        Due             => $args{'Due'},        # loc
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
                $self . "->Import couldn't set EffectiveId: $msg" );
        }
    }

    my $create_groups_ret = $self->_CreateTicketGroups();
    unless ($create_groups_ret) {
        $RT::Logger->crit(
            "Couldn't create ticket groups for ticket " . $self->Id );
    }

    $self->OwnerGroup->_AddMember( PrincipalId => $Owner->PrincipalId );

    my $watcher;
    foreach $watcher ( @{ $args{'Cc'} } ) {
        $self->_AddWatcher( Type => 'Cc', Email => $watcher, Silent => 1 );
    }
    foreach $watcher ( @{ $args{'AdminCc'} } ) {
        $self->_AddWatcher( Type => 'AdminCc', Email => $watcher,
            Silent => 1 );
    }
    foreach $watcher ( @{ $args{'Requestor'} } ) {
        $self->_AddWatcher( Type => 'Requestor', Email => $watcher,
            Silent => 1 );
    }

    return ( $self->Id, $ErrStr );
}

# }}}

# {{{ Routines dealing with watchers.

# {{{ _CreateTicketGroups 

=head2 _CreateTicketGroups

Create the ticket groups and links for this ticket. 
This routine expects to be called from Ticket->Create _inside of a transaction_

It will create four groups for this ticket: Requestor, Cc, AdminCc and Owner.

It will return true on success and undef on failure.


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

PrincipalId The RT::Principal id of the user or group that's being added as a watcher

Email       The email address of the new watcher. If a user with this 
            email address can't be found, a new nonprivileged user will be created.

If the watcher you\'re trying to set has an RT account, set the PrincipalId paremeter to their User Id. Otherwise, set the Email parameter to their Email address.

=cut

sub AddWatcher {
    my $self = shift;
    my %args = (
        Type  => undef,
        PrincipalId => undef,
        Email => undef,
        @_
    );

    # ModifyTicket works in any case
    return $self->_AddWatcher( %args )
        if $self->CurrentUserHasRight('ModifyTicket');
    if ( $args{'Email'} ) {
        my ($addr) = RT::EmailParser->ParseEmailAddress( $args{'Email'} );
        return (0, $self->loc("Couldn't parse address from '[_1]' string", $args{'Email'} ))
            unless $addr;

        if ( lc $self->CurrentUser->UserObj->EmailAddress
            eq lc RT::User->CanonicalizeEmailAddress( $addr->address ) )
        {
            $args{'PrincipalId'} = $self->CurrentUser->id;
            delete $args{'Email'};
        }
    }

    # If the watcher isn't the current user then the current user has no right
    # bail
    unless ( $args{'PrincipalId'} && $self->CurrentUser->id == $args{'PrincipalId'} ) {
        return ( 0, $self->loc("Permission Denied") );
    }

    #  If it's an AdminCc and they don't have 'WatchAsAdminCc', bail
    if ( $args{'Type'} eq 'AdminCc' ) {
        unless ( $self->CurrentUserHasRight('WatchAsAdminCc') ) {
            return ( 0, $self->loc('Permission Denied') );
        }
    }

    #  If it's a Requestor or Cc and they don't have 'Watch', bail
    elsif ( $args{'Type'} eq 'Cc' || $args{'Type'} eq 'Requestor' ) {
        unless ( $self->CurrentUserHasRight('Watch') ) {
            return ( 0, $self->loc('Permission Denied') );
        }
    }
    else {
        $RT::Logger->warning( "AddWatcher got passed a bogus type");
        return ( 0, $self->loc('Error in parameters to Ticket->AddWatcher') );
    }

    return $self->_AddWatcher( %args );
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
        if ( RT::EmailParser->IsRTAddress( $args{'Email'} ) ) {
            return (0, $self->loc("[_1] is an address RT receives mail at. Adding it as a '[_2]' would create a mail loop", $args{'Email'}, $self->loc($args{'Type'})));
        }
        my $user = RT::User->new($RT::SystemUser);
        my ($pid, $msg) = $user->LoadOrCreateByEmail( $args{'Email'} );
        $args{'PrincipalId'} = $pid if $pid; 
    }
    if ($args{'PrincipalId'}) {
        $principal->Load($args{'PrincipalId'});
        if ( $principal->id and $principal->IsUser and my $email = $principal->Object->EmailAddress ) {
            return (0, $self->loc("[_1] is an address RT receives mail at. Adding it as a '[_2]' would create a mail loop", $email, $self->loc($args{'Type'})))
                if RT::EmailParser->IsRTAddress( $email );

        }
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
        $RT::Logger->error("Failed to add ".$principal->Id." as a member of group ".$group->Id.": ".$m_msg);

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

    my %args = ( Type        => undef,
                 PrincipalId => undef,
                 Email       => undef,
                 @_ );

    unless ( $args{'PrincipalId'} || $args{'Email'} ) {
        return ( 0, $self->loc("No principal specified") );
    }
    my $principal = RT::Principal->new( $self->CurrentUser );
    if ( $args{'PrincipalId'} ) {

        $principal->Load( $args{'PrincipalId'} );
    }
    else {
        my $user = RT::User->new( $self->CurrentUser );
        $user->LoadByEmail( $args{'Email'} );
        $principal->Load( $user->Id );
    }

    # If we can't find this watcher, we need to bail.
    unless ( $principal->Id ) {
        return ( 0, $self->loc("Could not find that principal") );
    }

    my $group = RT::Group->new( $self->CurrentUser );
    $group->LoadTicketRoleGroup( Type => $args{'Type'}, Ticket => $self->Id );
    unless ( $group->id ) {
        return ( 0, $self->loc("Group not found") );
    }

    # {{{ Check ACLS
    #If the watcher we're trying to add is for the current user
    if ( $self->CurrentUser->PrincipalId == $principal->id ) {

        #  If it's an AdminCc and they don't have
        #   'WatchAsAdminCc' or 'ModifyTicket', bail
        if ( $args{'Type'} eq 'AdminCc' ) {
            unless (    $self->CurrentUserHasRight('ModifyTicket')
                     or $self->CurrentUserHasRight('WatchAsAdminCc') ) {
                return ( 0, $self->loc('Permission Denied') );
            }
        }

        #  If it's a Requestor or Cc and they don't have
        #   'Watch' or 'ModifyTicket', bail
        elsif ( ( $args{'Type'} eq 'Cc' ) or ( $args{'Type'} eq 'Requestor' ) )
        {
            unless (    $self->CurrentUserHasRight('ModifyTicket')
                     or $self->CurrentUserHasRight('Watch') ) {
                return ( 0, $self->loc('Permission Denied') );
            }
        }
        else {
            $RT::Logger->warn("$self -> DeleteWatcher got passed a bogus type");
            return ( 0,
                     $self->loc('Error in parameters to Ticket->DeleteWatcher') );
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

    unless ( $group->HasMember($principal) ) {
        return ( 0,
                 $self->loc( 'That principal is not a [_1] for this ticket',
                             $args{'Type'} ) );
    }

    my ( $m_id, $m_msg ) = $group->_DeleteMember( $principal->Id );
    unless ($m_id) {
        $RT::Logger->error( "Failed to delete "
                            . $principal->Id
                            . " as a member of group "
                            . $group->Id . ": "
                            . $m_msg );

        return (0,
                $self->loc(
                    'Could not remove that principal as a [_1] for this ticket',
                    $args{'Type'} ) );
    }

    unless ( $args{'Silent'} ) {
        $self->_NewTransaction( Type     => 'DelWatcher',
                                OldValue => $principal->Id,
                                Field    => $args{'Type'} );
    }

    return ( 1,
             $self->loc( "[_1] is no longer a [_2] for this ticket.",
                         $principal->Object->Name,
                         $args{'Type'} ) );
}



# }}}


=head2 SquelchMailTo [EMAIL]

Takes an optional email address to never email about updates to this ticket.


Returns an array of the RT::Attribute objects for this ticket's 'SquelchMailTo' attributes.


=cut

sub SquelchMailTo {
    my $self = shift;
    if (@_) {
        unless ( $self->CurrentUserHasRight('ModifyTicket') ) {
            return undef;
        }
    } else {
        unless ( $self->CurrentUserHasRight('ShowTicket') ) {
            return undef;
        }

    }
    return $self->_SquelchMailTo(@_);
}

sub _SquelchMailTo {
    my $self = shift;
    if (@_) {
        my $attr = shift;
        $self->AddAttribute( Name => 'SquelchMailTo', Content => $attr )
            unless grep { $_->Content eq $attr }
                $self->Attributes->Named('SquelchMailTo');
    }
    my @attributes = $self->Attributes->Named('SquelchMailTo');
    return (@attributes);
}


=head2 UnsquelchMailTo ADDRESS

Takes an address and removes it from this ticket's "SquelchMailTo" list. If an address appears multiple times, each instance is removed.

Returns a tuple of (status, message)

=cut

sub UnsquelchMailTo {
    my $self = shift;

    my $address = shift;
    unless ( $self->CurrentUserHasRight('ModifyTicket') ) {
        return ( 0, $self->loc("Permission Denied") );
    }

    my ($val, $msg) = $self->Attributes->DeleteEntry ( Name => 'SquelchMailTo', Content => $address);
    return ($val, $msg);
}


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

XX TODO: This should be Memoized. 

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

    # Ask if it has the member in question
    return $group->HasMember( $args{'PrincipalId'} );
}

# }}}

# {{{ sub IsRequestor

=head2 IsRequestor PRINCIPAL_ID
  
Takes an L<RT::Principal> id.

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
  Returns true if the principal is a Cc of the current ticket.


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
  Returns true if the principal is an AdminCc of the current ticket.

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
    #    return(undef);
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


=head2 TransactionAddresses

Returns a composite hashref of the results of L<RT::Transaction/Addresses> for
all this ticket's Create, Comment or Correspond transactions. The keys are
stringified email addresses. Each value is an L<Email::Address> object.

NOTE: For performance reasons, this method might want to skip transactions and go straight for attachments. But to make that work right, we're going to need to go and walk around the access control in Attachment.pm's sub _Value.

=cut


sub TransactionAddresses {
    my $self = shift;
    my $txns = $self->Transactions;

    my %addresses = ();
    foreach my $type (qw(Create Comment Correspond)) {
    $txns->Limit(FIELD => 'Type', OPERATOR => '=', VALUE => $type , ENTRYAGGREGATOR => 'OR', CASESENSITIVE => 1);
        }

    while (my $txn = $txns->Next) {
        my $txnaddrs = $txn->Addresses; 
        foreach my $addrlist ( values %$txnaddrs ) {
                foreach my $addr (@$addrlist) {
                    # Skip addresses without a phrase (things that are just raw addresses) if we have a phrase
                    next if ($addresses{$addr->address} && $addresses{$addr->address}->phrase && not $addr->phrase);
                    # skips "comment-only" addresses
                    next unless ($addr->address);
                    $addresses{$addr->address} = $addr;
                }
        }
    }

    return \%addresses;

}




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
        my $clone = RT::Ticket->new( $RT::SystemUser );
        $clone->Load( $self->Id );
        unless ( $clone->Id ) {
            return ( 0, $self->loc("Couldn't load copy of ticket #[_1].", $self->Id) );
        }
        my ($status, $msg) = $clone->SetOwner( $RT::Nobody->Id, 'Force' );
        $RT::Logger->error("Couldn't set owner on queue change: $msg") unless $status;
    }

    my ($status, $msg) = $self->_Set( Field => 'Queue', Value => $NewQueueObj->Id() );

    if ( $status ) {
        # On queue change, change queue for reminders too
        my $reminder_collection = $self->Reminders->Collection;
        while ( my $reminder = $reminder_collection->Next ) {
            my ($status, $msg) = $reminder->SetQueue($NewQueue);
            $RT::Logger->error('Queue change failed for reminder #' . $reminder->Id . ': ' . $msg) unless $status;
        }
    }
    
    return ($status, $msg);
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
    if ( my $due = $self->Due ) {
        $time->Set( Format => 'sql', Value => $due );
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
        return ( 0, $self->loc("Permission Denied") );
    }

    #We create a date object to catch date weirdness
    my $time_obj = new RT::Date( $self->CurrentUser() );
    if ( $time ) {
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
    my $value = $self->TimeWorked;

    # return the # of minutes worked turned into seconds and written as
    # a simple text string, this is not really a date object, but if we
    # diff a number of seconds vs the epoch, we'll get a nice description
    # of time worked.
    return "" unless $value;
    return RT::Date->new( $self->CurrentUser )
        ->DurationAsString( $value * 60 );
}

# }}}

# {{{ sub TimeLeftAsString

=head2  TimeLeftAsString

Returns the amount of time left on this ticket as a Text String

=cut

sub TimeLeftAsString {
    my $self = shift;
    my $value = $self->TimeLeft;
    return "" unless $value;
    return RT::Date->new( $self->CurrentUser )
        ->DurationAsString( $value * 60 );
}

# }}}

# {{{ Routines dealing with correspondence/comments

# {{{ sub Comment

=head2 Comment

Comment on this ticket.
Takes a hash with the following attributes:
If MIMEObj is undefined, Content will be used to build a MIME::Entity for this
comment.

MIMEObj, TimeTaken, CcMessageTo, BccMessageTo, Content, DryRun

If DryRun is defined, this update WILL NOT BE RECORDED. Scrips will not be committed.
They will, however, be prepared and you'll be able to access them through the TransactionObj

Returns: Transaction id, Error Message, Transaction Object
(note the different order from Create()!)

=cut

sub Comment {
    my $self = shift;

    my %args = ( CcMessageTo  => undef,
                 BccMessageTo => undef,
                 MIMEObj      => undef,
                 Content      => undef,
                 TimeTaken => 0,
                 DryRun     => 0, 
                 @_ );

    unless (    ( $self->CurrentUserHasRight('CommentOnTicket') )
             or ( $self->CurrentUserHasRight('ModifyTicket') ) ) {
        return ( 0, $self->loc("Permission Denied"), undef );
    }
    $args{'NoteType'} = 'Comment';

    if ($args{'DryRun'}) {
        $RT::Handle->BeginTransaction();
        $args{'CommitScrips'} = 0;
    }

    my @results = $self->_RecordNote(%args);
    if ($args{'DryRun'}) {
        $RT::Handle->Rollback();
    }

    return(@results);
}
# }}}

# {{{ sub Correspond

=head2 Correspond

Correspond on this ticket.
Takes a hashref with the following attributes:


MIMEObj, TimeTaken, CcMessageTo, BccMessageTo, Content, DryRun

if there's no MIMEObj, Content is used to build a MIME::Entity object

If DryRun is defined, this update WILL NOT BE RECORDED. Scrips will not be committed.
They will, however, be prepared and you'll be able to access them through the TransactionObj

Returns: Transaction id, Error Message, Transaction Object
(note the different order from Create()!)


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
        return ( 0, $self->loc("Permission Denied"), undef );
    }

    $args{'NoteType'} = 'Correspond'; 
    if ($args{'DryRun'}) {
        $RT::Handle->BeginTransaction();
        $args{'CommitScrips'} = 0;
    }

    my @results = $self->_RecordNote(%args);

    #Set the last told date to now if this isn't mail from the requestor.
    #TODO: Note that this will wrongly ack mail from any non-requestor as a "told"
    $self->_SetTold unless ( $self->IsRequestor($self->CurrentUser->id));

    if ($args{'DryRun'}) {
        $RT::Handle->Rollback();
    }

    return (@results);

}

# }}}

# {{{ sub _RecordNote

=head2 _RecordNote

the meat of both comment and correspond. 

Performs no access control checks. hence, dangerous.

=cut

sub _RecordNote {
    my $self = shift;
    my %args = ( 
        CcMessageTo  => undef,
        BccMessageTo => undef,
        Encrypt      => undef,
        Sign         => undef,
        MIMEObj      => undef,
        Content      => undef,
        NoteType     => 'Correspond',
        TimeTaken    => 0,
        CommitScrips => 1,
        @_
    );

    unless ( $args{'MIMEObj'} || $args{'Content'} ) {
        return ( 0, $self->loc("No message attached"), undef );
    }

    unless ( $args{'MIMEObj'} ) {
        $args{'MIMEObj'} = MIME::Entity->build(
            Data => ( ref $args{'Content'}? $args{'Content'}: [ $args{'Content'} ] )
        );
    }

    # convert text parts into utf-8
    RT::I18N::SetMIMEEntityToUTF8( $args{'MIMEObj'} );

    # If we've been passed in CcMessageTo and BccMessageTo fields,
    # add them to the mime object for passing on to the transaction handler
    # The "NotifyOtherRecipients" scripAction will look for RT-Send-Cc: and
    # RT-Send-Bcc: headers


    foreach my $type (qw/Cc Bcc/) {
        if ( defined $args{ $type . 'MessageTo' } ) {

            my $addresses = join ', ', (
                map { RT::User->CanonicalizeEmailAddress( $_->address ) }
                    Email::Address->parse( $args{ $type . 'MessageTo' } ) );
            $args{'MIMEObj'}->head->add( 'RT-Send-' . $type, Encode::encode_utf8( $addresses ) );
        }
    }

    foreach my $argument (qw(Encrypt Sign)) {
        $args{'MIMEObj'}->head->add(
            "X-RT-$argument" => Encode::encode_utf8( $args{ $argument } )
        ) if defined $args{ $argument };
    }

    # If this is from an external source, we need to come up with its
    # internal Message-ID now, so all emails sent because of this
    # message have a common Message-ID
    my $org = RT->Config->Get('Organization');
    my $msgid = $args{'MIMEObj'}->head->get('Message-ID');
    unless (defined $msgid && $msgid =~ /<(rt-.*?-\d+-\d+)\.(\d+-0-0)\@\Q$org\E>/) {
        $args{'MIMEObj'}->head->set(
            'RT-Message-ID' => RT::Interface::Email::GenMessageId( Ticket => $self )
        );
    }

    #Record the correspondence (write the transaction)
    my ( $Trans, $msg, $TransObj ) = $self->_NewTransaction(
             Type => $args{'NoteType'},
             Data => ( $args{'MIMEObj'}->head->get('subject') || 'No Subject' ),
             TimeTaken => $args{'TimeTaken'},
             MIMEObj   => $args{'MIMEObj'}, 
             CommitScrips => $args{'CommitScrips'},
    );

    unless ($Trans) {
        $RT::Logger->err("$self couldn't init a transaction $msg");
        return ( $Trans, $self->loc("Message could not be recorded"), undef );
    }

    return ( $Trans, $self->loc("Message recorded"), $TransObj );
}

# }}}

# }}}

# {{{ sub _Links 

sub _Links {
    my $self = shift;

    #TODO: Field isn't the right thing here. but I ahave no idea what mnemonic ---
    #tobias meant by $f
    my $field = shift;
    my $type  = shift || "";

    my $cache_key = "$field$type";
    return $self->{ $cache_key } if $self->{ $cache_key };

    my $links = $self->{ $cache_key }
              = RT::Links->new( $self->CurrentUser );
    unless ( $self->CurrentUserHasRight('ShowTicket') ) {
        $links->Limit( FIELD => 'id', VALUE => 0 );
        return $links;
    }

    # Maybe this ticket is a merge ticket
    my $limit_on = 'Local'. $field;
    # at least to myself
    $links->Limit(
        FIELD           => $limit_on,
        VALUE           => $self->id,
        ENTRYAGGREGATOR => 'OR',
    );
    $links->Limit(
        FIELD           => $limit_on,
        VALUE           => $_,
        ENTRYAGGREGATOR => 'OR',
    ) foreach $self->Merged;
    $links->Limit(
        FIELD => 'Type',
        VALUE => $type,
    ) if $type;

    return $links;
}

# }}}

# {{{ sub DeleteLink 

=head2 DeleteLink

Delete a link. takes a paramhash of Base, Target, Type, Silent,
SilentBase and SilentTarget. Either Base or Target must be null.
The null value will be replaced with this ticket\'s id.

If Silent is true then no transaction would be recorded, in other
case you can control creation of transactions on both base and
target with SilentBase and SilentTarget respectively. By default
both transactions are created.

=cut 

sub DeleteLink {
    my $self = shift;
    my %args = (
        Base   => undef,
        Target => undef,
        Type   => undef,
        Silent => undef,
        SilentBase   => undef,
        SilentTarget => undef,
        @_
    );

    unless ( $args{'Target'} || $args{'Base'} ) {
        $RT::Logger->error("Base or Target must be specified");
        return ( 0, $self->loc('Either base or target must be specified') );
    }

    #check acls
    my $right = 0;
    $right++ if $self->CurrentUserHasRight('ModifyTicket');
    if ( !$right && RT->Config->Get( 'StrictLinkACL' ) ) {
        return ( 0, $self->loc("Permission Denied") );
    }

    # If the other URI is an RT::Ticket, we want to make sure the user
    # can modify it too...
    my ($status, $msg, $other_ticket) = $self->__GetTicketFromURI( URI => $args{'Target'} || $args{'Base'} );
    return (0, $msg) unless $status;
    if ( !$other_ticket || $other_ticket->CurrentUserHasRight('ModifyTicket') ) {
        $right++;
    }
    if ( ( !RT->Config->Get( 'StrictLinkACL' ) && $right == 0 ) ||
         ( RT->Config->Get( 'StrictLinkACL' ) && $right < 2 ) )
    {
        return ( 0, $self->loc("Permission Denied") );
    }

    my ($val, $Msg) = $self->SUPER::_DeleteLink(%args);
    return ( 0, $Msg ) unless $val;

    return ( $val, $Msg ) if $args{'Silent'};

    my ($direction, $remote_link);

    if ( $args{'Base'} ) {
        $remote_link = $args{'Base'};
        $direction = 'Target';
    }
    elsif ( $args{'Target'} ) {
        $remote_link = $args{'Target'};
        $direction = 'Base';
    } 

    my $remote_uri = RT::URI->new( $self->CurrentUser );
    $remote_uri->FromURI( $remote_link );

    unless ( $args{ 'Silent'. $direction } ) {
        my ( $Trans, $Msg, $TransObj ) = $self->_NewTransaction(
            Type      => 'DeleteLink',
            Field     => $LINKDIRMAP{$args{'Type'}}->{$direction},
            OldValue  => $remote_uri->URI || $remote_link,
            TimeTaken => 0
        );
        $RT::Logger->error("Couldn't create transaction: $Msg") unless $Trans;
    }

    if ( !$args{ 'Silent'. ( $direction eq 'Target'? 'Base': 'Target' ) } && $remote_uri->IsLocal ) {
        my $OtherObj = $remote_uri->Object;
        my ( $val, $Msg ) = $OtherObj->_NewTransaction(
            Type           => 'DeleteLink',
            Field          => $direction eq 'Target' ? $LINKDIRMAP{$args{'Type'}}->{Base}
                                            : $LINKDIRMAP{$args{'Type'}}->{Target},
            OldValue       => $self->URI,
            ActivateScrips => !RT->Config->Get('LinkTransactionsRun1Scrip'),
            TimeTaken      => 0,
        );
        $RT::Logger->error("Couldn't create transaction: $Msg") unless $val;
    }

    return ( $val, $Msg );
}

# }}}

# {{{ sub AddLink

=head2 AddLink

Takes a paramhash of Type and one of Base or Target. Adds that link to this ticket.

If Silent is true then no transaction would be recorded, in other
case you can control creation of transactions on both base and
target with SilentBase and SilentTarget respectively. By default
both transactions are created.

=cut

sub AddLink {
    my $self = shift;
    my %args = ( Target       => '',
                 Base         => '',
                 Type         => '',
                 Silent       => undef,
                 SilentBase   => undef,
                 SilentTarget => undef,
                 @_ );

    unless ( $args{'Target'} || $args{'Base'} ) {
        $RT::Logger->error("Base or Target must be specified");
        return ( 0, $self->loc('Either base or target must be specified') );
    }

    my $right = 0;
    $right++ if $self->CurrentUserHasRight('ModifyTicket');
    if ( !$right && RT->Config->Get( 'StrictLinkACL' ) ) {
        return ( 0, $self->loc("Permission Denied") );
    }

    # If the other URI is an RT::Ticket, we want to make sure the user
    # can modify it too...
    my ($status, $msg, $other_ticket) = $self->__GetTicketFromURI( URI => $args{'Target'} || $args{'Base'} );
    return (0, $msg) unless $status;
    if ( !$other_ticket || $other_ticket->CurrentUserHasRight('ModifyTicket') ) {
        $right++;
    }
    if ( ( !RT->Config->Get( 'StrictLinkACL' ) && $right == 0 ) ||
         ( RT->Config->Get( 'StrictLinkACL' ) && $right < 2 ) )
    {
        return ( 0, $self->loc("Permission Denied") );
    }

    return $self->_AddLink(%args);
}

sub __GetTicketFromURI {
    my $self = shift;
    my %args = ( URI => '', @_ );

    # If the other URI is an RT::Ticket, we want to make sure the user
    # can modify it too...
    my $uri_obj = RT::URI->new( $self->CurrentUser );
    $uri_obj->FromURI( $args{'URI'} );

    unless ( $uri_obj->Resolver && $uri_obj->Scheme ) {
        my $msg = $self->loc( "Couldn't resolve '[_1]' into a URI.", $args{'URI'} );
        $RT::Logger->warning( $msg );
        return( 0, $msg );
    }
    my $obj = $uri_obj->Resolver->Object;
    unless ( UNIVERSAL::isa($obj, 'RT::Ticket') && $obj->id ) {
        return (1, 'Found not a ticket', undef);
    }
    return (1, 'Found ticket', $obj);
}

=head2 _AddLink  

Private non-acled variant of AddLink so that links can be added during create.

=cut

sub _AddLink {
    my $self = shift;
    my %args = ( Target       => '',
                 Base         => '',
                 Type         => '',
                 Silent       => undef,
                 SilentBase   => undef,
                 SilentTarget => undef,
                 @_ );

    my ($val, $msg, $exist) = $self->SUPER::_AddLink(%args);
    return ($val, $msg) if !$val || $exist;
    return ($val, $msg) if $args{'Silent'};

    my ($direction, $remote_link);
    if ( $args{'Target'} ) {
        $remote_link  = $args{'Target'};
        $direction    = 'Base';
    } elsif ( $args{'Base'} ) {
        $remote_link  = $args{'Base'};
        $direction    = 'Target';
    }

    my $remote_uri = RT::URI->new( $self->CurrentUser );
    $remote_uri->FromURI( $remote_link );

    unless ( $args{ 'Silent'. $direction } ) {
        my ( $Trans, $Msg, $TransObj ) = $self->_NewTransaction(
            Type      => 'AddLink',
            Field     => $LINKDIRMAP{$args{'Type'}}->{$direction},
            NewValue  =>  $remote_uri->URI || $remote_link,
            TimeTaken => 0
        );
        $RT::Logger->error("Couldn't create transaction: $Msg") unless $Trans;
    }

    if ( !$args{ 'Silent'. ( $direction eq 'Target'? 'Base': 'Target' ) } && $remote_uri->IsLocal ) {
        my $OtherObj = $remote_uri->Object;
        my ( $val, $msg ) = $OtherObj->_NewTransaction(
            Type           => 'AddLink',
            Field          => $direction eq 'Target' ? $LINKDIRMAP{$args{'Type'}}->{Base}
                                            : $LINKDIRMAP{$args{'Type'}}->{Target},
            NewValue       => $self->URI,
            ActivateScrips => !RT->Config->Get('LinkTransactionsRun1Scrip'),
            TimeTaken      => 0,
        );
        $RT::Logger->error("Couldn't create transaction: $msg") unless $val;
    }

    return ( $val, $msg );
}

# }}}


# {{{ sub MergeInto

=head2 MergeInto

MergeInto take the id of the ticket to merge this ticket into.

=cut

sub MergeInto {
    my $self      = shift;
    my $ticket_id = shift;

    unless ( $self->CurrentUserHasRight('ModifyTicket') ) {
        return ( 0, $self->loc("Permission Denied") );
    }

    # Load up the new ticket.
    my $MergeInto = RT::Ticket->new($self->CurrentUser);
    $MergeInto->Load($ticket_id);

    # make sure it exists.
    unless ( $MergeInto->Id ) {
        return ( 0, $self->loc("New ticket doesn't exist") );
    }

    # Make sure the current user can modify the new ticket.
    unless ( $MergeInto->CurrentUserHasRight('ModifyTicket') ) {
        return ( 0, $self->loc("Permission Denied") );
    }

    delete $MERGE_CACHE{'effective'}{ $self->id };
    delete @{ $MERGE_CACHE{'merged'} }{
        $ticket_id, $MergeInto->id, $self->id
    };

    $RT::Handle->BeginTransaction();

    # We use EffectiveId here even though it duplicates information from
    # the links table becasue of the massive performance hit we'd take
    # by trying to do a separate database query for merge info everytime 
    # loaded a ticket. 

    #update this ticket's effective id to the new ticket's id.
    my ( $id_val, $id_msg ) = $self->__Set(
        Field => 'EffectiveId',
        Value => $MergeInto->Id()
    );

    unless ($id_val) {
        $RT::Handle->Rollback();
        return ( 0, $self->loc("Merge failed. Couldn't set EffectiveId") );
    }


    if ( $self->__Value('Status') ne 'resolved' ) {

        my ( $status_val, $status_msg )
            = $self->__Set( Field => 'Status', Value => 'resolved' );

        unless ($status_val) {
            $RT::Handle->Rollback();
            $RT::Logger->error(
                $self->loc(
                    "[_1] couldn't set status to resolved. RT's Database may be inconsistent.",
                    $self
                )
            );
            return ( 0, $self->loc("Merge failed. Couldn't set Status") );
        }
    }

    # update all the links that point to that old ticket
    my $old_links_to = RT::Links->new($self->CurrentUser);
    $old_links_to->Limit(FIELD => 'Target', VALUE => $self->URI);

    my %old_seen;
    while (my $link = $old_links_to->Next) {
        if (exists $old_seen{$link->Base."-".$link->Type}) {
            $link->Delete;
        }   
        elsif ($link->Base eq $MergeInto->URI) {
            $link->Delete;
        } else {
            # First, make sure the link doesn't already exist. then move it over.
            my $tmp = RT::Link->new($RT::SystemUser);
            $tmp->LoadByCols(Base => $link->Base, Type => $link->Type, LocalTarget => $MergeInto->id);
            if ($tmp->id)   {
                    $link->Delete;
            } else { 
                $link->SetTarget($MergeInto->URI);
                $link->SetLocalTarget($MergeInto->id);
            }
            $old_seen{$link->Base."-".$link->Type} =1;
        }

    }

    my $old_links_from = RT::Links->new($self->CurrentUser);
    $old_links_from->Limit(FIELD => 'Base', VALUE => $self->URI);

    while (my $link = $old_links_from->Next) {
        if (exists $old_seen{$link->Type."-".$link->Target}) {
            $link->Delete;
        }   
        if ($link->Target eq $MergeInto->URI) {
            $link->Delete;
        } else {
            # First, make sure the link doesn't already exist. then move it over.
            my $tmp = RT::Link->new($RT::SystemUser);
            $tmp->LoadByCols(Target => $link->Target, Type => $link->Type, LocalBase => $MergeInto->id);
            if ($tmp->id)   {
                    $link->Delete;
            } else { 
                $link->SetBase($MergeInto->URI);
                $link->SetLocalBase($MergeInto->id);
                $old_seen{$link->Type."-".$link->Target} =1;
            }
        }

    }

    # Update time fields
    foreach my $type qw(TimeEstimated TimeWorked TimeLeft) {

        my $mutator = "Set$type";
        $MergeInto->$mutator(
            ( $MergeInto->$type() || 0 ) + ( $self->$type() || 0 ) );

    }
#add all of this ticket's watchers to that ticket.
    foreach my $watcher_type qw(Requestors Cc AdminCc) {

        my $people = $self->$watcher_type->MembersObj;
        my $addwatcher_type =  $watcher_type;
        $addwatcher_type  =~ s/s$//;

        while ( my $watcher = $people->Next ) {
            
           my ($val, $msg) =  $MergeInto->_AddWatcher(
                Type        => $addwatcher_type,
                Silent => 1,
                PrincipalId => $watcher->MemberId
            );
            unless ($val) {
                $RT::Logger->warning($msg);
            }
    }

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
            Value => $MergeInto->Id()
        );
    }

    #make a new link: this ticket is merged into that other ticket.
    $self->AddLink( Type   => 'MergedInto', Target => $MergeInto->Id());

    $MergeInto->_SetLastUpdated;    

    $RT::Handle->Commit();
    return ( 1, $self->loc("Merge Successful") );
}

=head2 Merged

Returns list of tickets' ids that's been merged into this ticket.

=cut

sub Merged {
    my $self = shift;

    my $id = $self->id;
    return @{ $MERGE_CACHE{'merged'}{ $id } }
        if $MERGE_CACHE{'merged'}{ $id };

    my $mergees = RT::Tickets->new( $self->CurrentUser );
    $mergees->Limit(
        FIELD    => 'EffectiveId',
        VALUE    => $id,
    );
    $mergees->Limit(
        FIELD    => 'id',
        OPERATOR => '!=',
        VALUE    => $id,
    );
    return @{ $MERGE_CACHE{'merged'}{ $id } ||= [] }
        = map $_->id, @{ $mergees->ItemsArrayRef || [] };
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


=cut

sub SetOwner {
    my $self     = shift;
    my $NewOwner = shift;
    my $Type     = shift || "Give";

    $RT::Handle->BeginTransaction();

    $self->_SetLastUpdated(); # lock the ticket
    $self->Load( $self->id ); # in case $self changed while waiting for lock

    my $OldOwnerObj = $self->OwnerObj;

    my $NewOwnerObj = RT::User->new( $self->CurrentUser );
    $NewOwnerObj->Load( $NewOwner );
    unless ( $NewOwnerObj->Id ) {
        $RT::Handle->Rollback();
        return ( 0, $self->loc("That user does not exist") );
    }


    # must have ModifyTicket rights
    # or TakeTicket/StealTicket and $NewOwner is self
    # see if it's a take
    if ( $OldOwnerObj->Id == $RT::Nobody->Id ) {
        unless (    $self->CurrentUserHasRight('ModifyTicket')
                 || $self->CurrentUserHasRight('TakeTicket') ) {
            $RT::Handle->Rollback();
            return ( 0, $self->loc("Permission Denied") );
        }
    }

    # see if it's a steal
    elsif (    $OldOwnerObj->Id != $RT::Nobody->Id
            && $OldOwnerObj->Id != $self->CurrentUser->id ) {

        unless (    $self->CurrentUserHasRight('ModifyTicket')
                 || $self->CurrentUserHasRight('StealTicket') ) {
            $RT::Handle->Rollback();
            return ( 0, $self->loc("Permission Denied") );
        }
    }
    else {
        unless ( $self->CurrentUserHasRight('ModifyTicket') ) {
            $RT::Handle->Rollback();
            return ( 0, $self->loc("Permission Denied") );
        }
    }

    # If we're not stealing and the ticket has an owner and it's not
    # the current user
    if ( $Type ne 'Steal' and $Type ne 'Force'
         and $OldOwnerObj->Id != $RT::Nobody->Id
         and $OldOwnerObj->Id != $self->CurrentUser->Id )
    {
        $RT::Handle->Rollback();
        return ( 0, $self->loc("You can only take tickets that are unowned") )
            if $NewOwnerObj->id == $self->CurrentUser->id;
        return (
            0,
            $self->loc("You can only reassign tickets that you own or that are unowned" )
        );
    }

    #If we've specified a new owner and that user can't modify the ticket
    elsif ( !$NewOwnerObj->HasRight( Right => 'OwnTicket', Object => $self ) ) {
        $RT::Handle->Rollback();
        return ( 0, $self->loc("That user may not own tickets in that queue") );
    }

    # If the ticket has an owner and it's the new owner, we don't need
    # To do anything
    elsif ( $NewOwnerObj->Id == $OldOwnerObj->Id ) {
        $RT::Handle->Rollback();
        return ( 0, $self->loc("That user already owns that ticket") );
    }

    # Delete the owner in the owner group, then add a new one
    # TODO: is this safe? it's not how we really want the API to work
    # for most things, but it's fast.
    my ( $del_id, $del_msg );
    for my $owner (@{$self->OwnerGroup->MembersObj->ItemsArrayRef}) {
        ($del_id, $del_msg) = $owner->Delete();
        last unless ($del_id);
    }

    unless ($del_id) {
        $RT::Handle->Rollback();
        return ( 0, $self->loc("Could not change owner: [_1]", $del_msg) );
    }

    my ( $add_id, $add_msg ) = $self->OwnerGroup->_AddMember(
                                       PrincipalId => $NewOwnerObj->PrincipalId,
                                       InsideTransaction => 1 );
    unless ($add_id) {
        $RT::Handle->Rollback();
        return ( 0, $self->loc("Could not change owner: [_1]", $add_msg ) );
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
        return ( 0, $self->loc("Could not change owner: [_1]", $msg) );
    }

    ($val, $msg) = $self->_NewTransaction(
        Type      => $Type,
        Field     => 'Owner',
        NewValue  => $NewOwnerObj->Id,
        OldValue  => $OldOwnerObj->Id,
        TimeTaken => 0,
    );

    if ( $val ) {
        $msg = $self->loc( "Owner changed from [_1] to [_2]",
                           $OldOwnerObj->Name, $NewOwnerObj->Name );
    }
    else {
        $RT::Handle->Rollback();
        return ( 0, $msg );
    }

    $RT::Handle->Commit();

    return ( $val, $msg );
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
    if ( $args{Status} eq 'deleted') {
            unless ($self->CurrentUserHasRight('DeleteTicket')) {
            return ( 0, $self->loc('Permission Denied') );
       }
    } else {
            unless ($self->CurrentUserHasRight('ModifyTicket')) {
            return ( 0, $self->loc('Permission Denied') );
       }
    }

    if (!$args{Force} && ($args{'Status'} eq 'resolved') && $self->HasUnresolvedDependencies) {
        return (0, $self->loc('That ticket has unresolved dependencies'));
    }

    my $now = RT::Date->new( $self->CurrentUser );
    $now->SetToNow();

    #If we're changing the status from new, record that we've started
    if ( $self->Status eq 'new' && $args{Status} ne 'new' ) {

        #Set the Started time to "now"
        $self->_Set( Field             => 'Started',
                     Value             => $now->ISO,
                     RecordTransaction => 0 );
    }

    #When we close a ticket, set the 'Resolved' attribute to now.
    # It's misnamed, but that's just historical.
    if ( $self->QueueObj->IsInactiveStatus($args{Status}) ) {
        $self->_Set( Field             => 'Resolved',
                     Value             => $now->ISO,
                     RecordTransaction => 0 );
    }

    #Actually update the status
   my ($val, $msg)= $self->_Set( Field           => 'Status',
                          Value           => $args{Status},
                          TimeTaken       => 0,
                          CheckACL      => 0,
                          TransactionType => 'Status'  );

    return($val,$msg);
}

# }}}

# {{{ sub Delete

=head2 Delete

Takes no arguments. Marks this ticket for garbage collection

=cut

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

=head2 SeenUpTo


=cut

sub SeenUpTo {
    my $self = shift;
    my $uid = $self->CurrentUser->id;
    my $attr = $self->FirstAttribute( "User-". $uid ."-SeenUpTo" );
    return if $attr && $attr->Content gt $self->LastUpdated;

    my $txns = $self->Transactions;
    $txns->Limit( FIELD => 'Type', VALUE => 'Comment' );
    $txns->Limit( FIELD => 'Type', VALUE => 'Correspond' );
    $txns->Limit( FIELD => 'Creator', OPERATOR => '!=', VALUE => $uid );
    $txns->Limit(
        FIELD => 'Created',
        OPERATOR => '>',
        VALUE => $attr->Content
    ) if $attr;
    $txns->RowsPerPage(1);
    return $txns->First;
}

# }}}

=head2 TransactionBatch

Returns an array reference of all transactions created on this ticket during
this ticket object's lifetime or since last application of a batch, or undef
if there were none.

Only works when the C<UseTransactionBatch> config option is set to true.

=cut

sub TransactionBatch {
    my $self = shift;
    return $self->{_TransactionBatch};
}

=head2 ApplyTransactionBatch

Applies scrips on the current batch of transactions and shinks it. Usually
batch is applied when object is destroyed, but in some cases it's too late.

=cut

sub ApplyTransactionBatch {
    my $self = shift;

    my $batch = $self->TransactionBatch;
    return unless $batch && @$batch;

    $self->_ApplyTransactionBatch;

    $self->{_TransactionBatch} = [];
}

sub _ApplyTransactionBatch {
    my $self = shift;
    my $batch = $self->TransactionBatch;

    my %seen;
    my $types = join ',', grep !$seen{$_}++, grep defined, map $_->Type, grep defined, @{$batch};

    require RT::Scrips;
    RT::Scrips->new($RT::SystemUser)->Apply(
        Stage          => 'TransactionBatch',
        TicketObj      => $self,
        TransactionObj => $batch->[0],
        Type           => $types,
    );

    # Entry point of the rule system
    my $rules = RT::Ruleset->FindAllRules(
        Stage          => 'TransactionBatch',
        TicketObj      => $self,
        TransactionObj => $batch->[0],
        Type           => $types,
    );
    RT::Ruleset->CommitRules($rules);
}

sub DESTROY {
    my $self = shift;

    # DESTROY methods need to localize $@, or it may unset it.  This
    # causes $m->abort to not bubble all of the way up.  See perlbug
    # http://rt.perl.org/rt3/Ticket/Display.html?id=17650
    local $@;

    # The following line eliminates reentrancy.
    # It protects against the fact that perl doesn't deal gracefully
    # when an object's refcount is changed in its destructor.
    return if $self->{_Destroyed}++;

    my $batch = $self->TransactionBatch;
    return unless $batch && @$batch;

    return $self->_ApplyTransactionBatch;
}

# }}}

# {{{ PRIVATE UTILITY METHODS. Mostly needed so Ticket can be a DBIx::Record

# {{{ sub _OverlayAccessible

sub _OverlayAccessible {
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
        return ( 0, $msg ) unless $ret;
    }

    if ( $args{'RecordTransaction'} == 1 ) {

        my ( $Trans, $Msg, $TransObj ) = $self->_NewTransaction(
                                               Type => $args{'TransactionType'},
                                               Field     => $args{'Field'},
                                               NewValue  => $args{'Value'},
                                               OldValue  => $Old,
                                               TimeTaken => $args{'TimeTaken'},
        );
        return ( $Trans, scalar $TransObj->BriefDescription );
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

        #$RT::Logger->debug("Skipping ACL check for $field");
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

    return $self->CurrentUser->PrincipalObj->HasRight(
        Object => $self,
        Right  => $right,
    )
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
        Carp::cluck("Principal attrib undefined for Ticket::HasRight");
        $RT::Logger->crit("Principal attrib undefined for Ticket::HasRight");
        return(undef);
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

=head2 Reminders

Return the Reminders object for this ticket. (It's an RT::Reminders object.)
It isn't acutally a searchbuilder collection itself.

=cut

sub Reminders {
    my $self = shift;
    
    unless ($self->{'__reminders'}) {
        $self->{'__reminders'} = RT::Reminders->new($self->CurrentUser);
        $self->{'__reminders'}->Ticket($self->id);
    }
    return $self->{'__reminders'};

}



# {{{ sub Transactions 

=head2 Transactions

  Returns an RT::Transactions object of all transactions on this ticket

=cut

sub Transactions {
    my $self = shift;

    my $transactions = RT::Transactions->new( $self->CurrentUser );

    #If the user has no rights, return an empty object
    if ( $self->CurrentUserHasRight('ShowTicket') ) {
        $transactions->LimitToTicket($self->id);

        # if the user may not see comments do not return them
        unless ( $self->CurrentUserHasRight('ShowTicketComments') ) {
            $transactions->Limit(
                SUBCLAUSE => 'acl',
                FIELD    => 'Type',
                OPERATOR => '!=',
                VALUE    => "Comment"
            );
            $transactions->Limit(
                SUBCLAUSE => 'acl',
                FIELD    => 'Type',
                OPERATOR => '!=',
                VALUE    => "CommentEmailRecord",
                ENTRYAGGREGATOR => 'AND'
            );

        }
    } else {
        $transactions->Limit(
            SUBCLAUSE => 'acl',
            FIELD    => 'id',
            VALUE    => 0,
            ENTRYAGGREGATOR => 'AND'
        );
    }

    return ($transactions);
}

# }}}


# {{{ TransactionCustomFields

=head2 TransactionCustomFields

    Returns the custom fields that transactions on tickets will have.

=cut

sub TransactionCustomFields {
    my $self = shift;
    return $self->QueueObj->TicketTransactionCustomFields;
}

# }}}

# {{{ sub CustomFieldValues

=head2 CustomFieldValues

# Do name => id mapping (if needed) before falling back to
# RT::Record's CustomFieldValues

See L<RT::Record>

=cut

sub CustomFieldValues {
    my $self  = shift;
    my $field = shift;

    return $self->SUPER::CustomFieldValues( $field ) if !$field || $field =~ /^\d+$/;

    my $cf = RT::CustomField->new( $self->CurrentUser );
    $cf->SetContextObject( $self );
    $cf->LoadByNameAndQueue( Name => $field, Queue => $self->Queue );
    unless ( $cf->id ) {
        $cf->LoadByNameAndQueue( Name => $field, Queue => 0 );
    }

    # If we didn't find a valid cfid, give up.
    return RT::ObjectCustomFieldValues->new( $self->CurrentUser ) unless $cf->id;

    return $self->SUPER::CustomFieldValues( $cf->id );
}

# }}}

# {{{ sub CustomFieldLookupType

=head2 CustomFieldLookupType

Returns the RT::Ticket lookup type, which can be passed to 
RT::CustomField->Create() via the 'LookupType' hash key.

=cut

# }}}

sub CustomFieldLookupType {
    "RT::Queue-RT::Ticket";
}

=head2 ACLEquivalenceObjects

This method returns a list of objects for which a user's rights also apply
to this ticket. Generally, this is only the ticket's queue, but some RT 
extensions may make other objects available too.

This method is called from L<RT::Principal/HasRight>.

=cut

sub ACLEquivalenceObjects {
    my $self = shift;
    return $self->QueueObj;

}


1;

=head1 AUTHOR

Jesse Vincent, jesse@bestpractical.com

=head1 SEE ALSO

RT

=cut

