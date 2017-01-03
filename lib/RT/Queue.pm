# BEGIN BPS TAGGED BLOCK {{{
#
# COPYRIGHT:
#
# This software is Copyright (c) 1996-2017 Best Practical Solutions, LLC
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

=head1 NAME

  RT::Queue - an RT Queue object

=head1 SYNOPSIS

  use RT::Queue;

=head1 DESCRIPTION

An RT queue object.

=head1 METHODS

=cut


package RT::Queue;

use strict;
use warnings;
use base 'RT::Record';

sub Table {'Queues'}



use RT::Groups;
use RT::ACL;
use RT::Interface::Email;

our @DEFAULT_ACTIVE_STATUS = qw(new open stalled);
our @DEFAULT_INACTIVE_STATUS = qw(resolved rejected deleted);  

# $self->loc('new'); # For the string extractor to get a string to localize
# $self->loc('open'); # For the string extractor to get a string to localize
# $self->loc('stalled'); # For the string extractor to get a string to localize
# $self->loc('resolved'); # For the string extractor to get a string to localize
# $self->loc('rejected'); # For the string extractor to get a string to localize
# $self->loc('deleted'); # For the string extractor to get a string to localize


our $RIGHTS = {
    SeeQueue            => 'View queue',                                                # loc_pair
    AdminQueue          => 'Create, modify and delete queue',                           # loc_pair
    ShowACL             => 'Display Access Control List',                               # loc_pair
    ModifyACL           => 'Create, modify and delete Access Control List entries',     # loc_pair
    ModifyQueueWatchers => 'Modify queue watchers',                                     # loc_pair
    SeeCustomField      => 'View custom field values',                                  # loc_pair
    ModifyCustomField   => 'Modify custom field values',                                # loc_pair
    AssignCustomFields  => 'Assign and remove queue custom fields',                     # loc_pair
    ModifyTemplate      => 'Modify Scrip templates',                                    # loc_pair
    ShowTemplate        => 'View Scrip templates',                                      # loc_pair

    ModifyScrips        => 'Modify Scrips',                                             # loc_pair
    ShowScrips          => 'View Scrips',                                               # loc_pair

    ShowTicket          => 'View ticket summaries',                                     # loc_pair
    ShowTicketComments  => 'View ticket private commentary',                            # loc_pair
    ShowOutgoingEmail   => 'View exact outgoing email messages and their recipients',   # loc_pair

    Watch               => 'Sign up as a ticket Requestor or ticket or queue Cc',       # loc_pair
    WatchAsAdminCc      => 'Sign up as a ticket or queue AdminCc',                      # loc_pair
    CreateTicket        => 'Create tickets',                                            # loc_pair
    ReplyToTicket       => 'Reply to tickets',                                          # loc_pair
    CommentOnTicket     => 'Comment on tickets',                                        # loc_pair
    OwnTicket           => 'Own tickets',                                               # loc_pair
    ModifyTicket        => 'Modify tickets',                                            # loc_pair
    DeleteTicket        => 'Delete tickets',                                            # loc_pair
    TakeTicket          => 'Take tickets',                                              # loc_pair
    StealTicket         => 'Steal tickets',                                             # loc_pair

    ForwardMessage      => 'Forward messages outside of RT',                            # loc_pair
};

our $RIGHT_CATEGORIES = {
    SeeQueue            => 'General',
    AdminQueue          => 'Admin',
    ShowACL             => 'Admin',
    ModifyACL           => 'Admin',
    ModifyQueueWatchers => 'Admin',
    SeeCustomField      => 'General',
    ModifyCustomField   => 'Staff',
    AssignCustomFields  => 'Admin',
    ModifyTemplate      => 'Admin',
    ShowTemplate        => 'Admin',
    ModifyScrips        => 'Admin',
    ShowScrips          => 'Admin',
    ShowTicket          => 'General',
    ShowTicketComments  => 'Staff',
    ShowOutgoingEmail   => 'Staff',
    Watch               => 'General',
    WatchAsAdminCc      => 'Staff',
    CreateTicket        => 'General',
    ReplyToTicket       => 'General',
    CommentOnTicket     => 'General',
    OwnTicket           => 'Staff',
    ModifyTicket        => 'Staff',
    DeleteTicket        => 'Staff',
    TakeTicket          => 'Staff',
    StealTicket         => 'Staff',
    ForwardMessage      => 'Staff',
};

# Tell RT::ACE that this sort of object can get acls granted
$RT::ACE::OBJECT_TYPES{'RT::Queue'} = 1;

# TODO: This should be refactored out into an RT::ACLedObject or something
# stuff the rights into a hash of rights that can exist.

__PACKAGE__->AddRights(%$RIGHTS);
__PACKAGE__->AddRightCategories(%$RIGHT_CATEGORIES);
require RT::Lifecycle;

=head2 AddRights C<RIGHT>, C<DESCRIPTION> [, ...]

Adds the given rights to the list of possible rights.  This method
should be called during server startup, not at runtime.

=cut

sub AddRights {
    my $self = shift;
    my %new = @_;
    $RIGHTS = { %$RIGHTS, %new };
    %RT::ACE::LOWERCASERIGHTNAMES = ( %RT::ACE::LOWERCASERIGHTNAMES,
                                      map { lc($_) => $_ } keys %new);
}

=head2 AddRightCategories C<RIGHT>, C<CATEGORY> [, ...]

Adds the given right and category pairs to the list of right categories.  This
method should be called during server startup, not at runtime.

=cut

sub AddRightCategories {
    my $self = shift if ref $_[0] or $_[0] eq __PACKAGE__;
    my %new = @_;
    $RIGHT_CATEGORIES = { %$RIGHT_CATEGORIES, %new };
}

sub AddLink {
    my $self = shift;
    my %args = ( Target => '',
                 Base   => '',
                 Type   => '',
                 Silent => undef,
                 @_ );

    unless ( $self->CurrentUserHasRight('ModifyQueue') ) {
        return ( 0, $self->loc("Permission Denied") );
    }

    return $self->SUPER::_AddLink(%args);
}

sub DeleteLink {
    my $self = shift;
    my %args = (
        Base   => undef,
        Target => undef,
        Type   => undef,
        @_
    );

    #check acls
    unless ( $self->CurrentUserHasRight('ModifyQueue') ) {
        $RT::Logger->debug("No permission to delete links");
        return ( 0, $self->loc('Permission Denied'))
    }

    return $self->SUPER::_DeleteLink(%args);
}

=head2 AvailableRights

Returns a hash of available rights for this object. The keys are the right names and the values are a description of what the rights do

=cut

sub AvailableRights {
    my $self = shift;
    return($RIGHTS);
}

=head2 RightCategories

Returns a hashref where the keys are rights for this type of object and the
values are the category (General, Staff, Admin) the right falls into.

=cut

sub RightCategories {
    return $RIGHT_CATEGORIES;
}


sub Lifecycle {
    my $self = shift;
    unless (ref $self && $self->id) { 
        return RT::Lifecycle->Load('')
    }

    my $name = $self->_Value( Lifecycle => @_ );
    $name ||= 'default';

    my $res = RT::Lifecycle->Load( $name );
    unless ( $res ) {
        $RT::Logger->error("Lifecycle '$name' for queue '".$self->Name."' doesn't exist");
        return RT::Lifecycle->Load('default');
    }
    return $res;
}

sub SetLifecycle {
    my $self = shift;
    my $value = shift || 'default';

    return ( 0, $self->loc( '[_1] is not a valid lifecycle', $value ) )
      unless $self->ValidateLifecycle($value);

    return $self->_Set( Field => 'Lifecycle', Value => $value, @_ );
}

=head2 ValidateLifecycle NAME

Takes a lifecycle name. Returns true if it's an ok name and such
lifecycle is configured. Returns undef otherwise.

=cut

sub ValidateLifecycle {
    my $self = shift;
    my $value = shift;
    return undef unless RT::Lifecycle->Load( $value );
    return 1;
}


=head2 ActiveStatusArray

Returns an array of all ActiveStatuses for this queue

=cut

sub ActiveStatusArray {
    my $self = shift;
    return $self->Lifecycle->Valid('initial', 'active');
}

=head2 InactiveStatusArray

Returns an array of all InactiveStatuses for this queue

=cut

sub InactiveStatusArray {
    my $self = shift;
    return $self->Lifecycle->Inactive;
}

=head2 StatusArray

Returns an array of all statuses for this queue

=cut

sub StatusArray {
    my $self = shift;
    return $self->Lifecycle->Valid( @_ );
}

=head2 IsValidStatus value

Returns true if value is a valid status.  Otherwise, returns 0.

=cut

sub IsValidStatus {
    my $self  = shift;
    return $self->Lifecycle->IsValid( shift );
}

=head2 IsActiveStatus value

Returns true if value is a Active status.  Otherwise, returns 0

=cut

sub IsActiveStatus {
    my $self  = shift;
    return $self->Lifecycle->IsValid( shift, 'initial', 'active');
}



=head2 IsInactiveStatus value

Returns true if value is a Inactive status.  Otherwise, returns 0


=cut

sub IsInactiveStatus {
    my $self  = shift;
    return $self->Lifecycle->IsInactive( shift );
}






=head2 Create(ARGS)

Arguments: ARGS is a hash of named parameters.  Valid parameters are:

  Name (required)
  Description
  CorrespondAddress
  CommentAddress
  InitialPriority
  FinalPriority
  DefaultDueIn
 
If you pass the ACL check, it creates the queue and returns its queue id.


=cut

sub Create {
    my $self = shift;
    my %args = (
        Name              => undef,
        Description       => '',
        CorrespondAddress => '',
        CommentAddress    => '',
        Lifecycle         => 'default',
        SubjectTag        => undef,
        InitialPriority   => 0,
        FinalPriority     => 0,
        DefaultDueIn      => 0,
        Sign              => undef,
        SignAuto          => undef,
        Encrypt           => undef,
        _RecordTransaction => 1,
        @_
    );

    unless ( $self->CurrentUser->HasRight(Right => 'AdminQueue', Object => $RT::System) )
    {    #Check them ACLs
        return ( 0, $self->loc("No permission to create queues") );
    }

    {
        my ($val, $msg) = $self->_ValidateName( $args{'Name'} );
        return ($val, $msg) unless $val;
    }

    $args{'Lifecycle'} ||= 'default';

    return ( 0, $self->loc('[_1] is not a valid lifecycle', $args{'Lifecycle'} ) )
      unless $self->ValidateLifecycle( $args{'Lifecycle'} );

    my %attrs = map {$_ => 1} $self->ReadableAttributes;

    #TODO better input validation
    $RT::Handle->BeginTransaction();
    my $id = $self->SUPER::Create( map { $_ => $args{$_} } grep exists $args{$_}, keys %attrs );
    unless ($id) {
        $RT::Handle->Rollback();
        return ( 0, $self->loc('Queue could not be created') );
    }

    my $create_ret = $self->_CreateQueueGroups();
    unless ($create_ret) {
        $RT::Handle->Rollback();
        return ( 0, $self->loc('Queue could not be created') );
    }
    if ( $args{'_RecordTransaction'} ) {
        $self->_NewTransaction( Type => "Create" );
    }
    $RT::Handle->Commit;

    for my $attr (qw/Sign SignAuto Encrypt/) {
        next unless defined $args{$attr};
        my $set = "Set" . $attr;
        my ($status, $msg) = $self->$set( $args{$attr} );
        $RT::Logger->error("Couldn't set attribute '$attr': $msg")
            unless $status;
    }

    RT->System->QueueCacheNeedsUpdate(1);

    return ( $id, $self->loc("Queue created") );
}



sub Delete {
    my $self = shift;
    return ( 0,
        $self->loc('Deleting this object would break referential integrity') );
}



=head2 SetDisabled

Takes a boolean.
1 will cause this queue to no longer be available for tickets.
0 will re-enable this queue.

=cut

sub SetDisabled {
    my $self = shift;
    my $val = shift;

    $RT::Handle->BeginTransaction();
    my $set_err = $self->_Set( Field =>'Disabled', Value => $val);
    unless ($set_err) {
        $RT::Handle->Rollback();
        $RT::Logger->warning("Couldn't ".($val == 1) ? "disable" : "enable"." queue ".$self->PrincipalObj->Id);
        return (undef);
    }
    $self->_NewTransaction( Type => ($val == 1) ? "Disabled" : "Enabled" );

    $RT::Handle->Commit();

    RT->System->QueueCacheNeedsUpdate(1);

    if ( $val == 1 ) {
        return (1, $self->loc("Queue disabled"));
    } else {
        return (1, $self->loc("Queue enabled"));
    }

}



=head2 Load

Takes either a numerical id or a textual Name and loads the specified queue.

=cut

sub Load {
    my $self = shift;

    my $identifier = shift;
    if ( !$identifier ) {
        return (undef);
    }

    if ( $identifier =~ /^(\d+)$/ ) {
        $self->SUPER::LoadById($identifier);
    }
    else {
        $self->LoadByCols( Name => $identifier );
    }

    return ( $self->Id );

}



=head2 ValidateName NAME

Takes a queue name. Returns true if it's an ok name for
a new queue. Returns undef if there's already a queue by that name.

=cut

sub ValidateName {
    my $self = shift;
    my $name = shift;

    my ($ok, $msg) = $self->_ValidateName($name);

    return $ok ? 1 : 0;
}

sub _ValidateName {
    my $self = shift;
    my $name = shift;

    return (undef, "Queue name is required") unless length $name;

    # Validate via the superclass first
    # Case: short circuit if it's an integer so we don't have
    # fale negatives when loading a temp queue
    unless ( my $q = $self->SUPER::ValidateName($name) ) {
        return ($q, $self->loc("'[_1]' is not a valid name.", $name));
    }

    my $tempqueue = RT::Queue->new(RT->SystemUser);
    $tempqueue->Load($name);

    #If this queue exists, return undef
    if ( $tempqueue->Name() && $tempqueue->id != $self->id)  {
        return (undef, $self->loc("Queue already exists") );
    }

    return (1);
}


=head2 SetSign

=cut

sub Sign {
    my $self = shift;
    my $value = shift;

    return undef unless $self->CurrentUserHasRight('SeeQueue');
    my $attr = $self->FirstAttribute('Sign') or return 0;
    return $attr->Content;
}

sub SetSign {
    my $self = shift;
    my $value = shift;

    return ( 0, $self->loc('Permission Denied') )
        unless $self->CurrentUserHasRight('AdminQueue');

    my ($status, $msg) = $self->SetAttribute(
        Name        => 'Sign',
        Description => 'Sign outgoing messages by default',
        Content     => $value,
    );
    return ($status, $msg) unless $status;
    return ($status, $self->loc('Signing enabled')) if $value;
    return ($status, $self->loc('Signing disabled'));
}

sub SignAuto {
    my $self = shift;
    my $value = shift;

    return undef unless $self->CurrentUserHasRight('SeeQueue');
    my $attr = $self->FirstAttribute('SignAuto') or return 0;
    return $attr->Content;
}

sub SetSignAuto {
    my $self = shift;
    my $value = shift;

    return ( 0, $self->loc('Permission Denied') )
        unless $self->CurrentUserHasRight('AdminQueue');

    my ($status, $msg) = $self->SetAttribute(
        Name        => 'SignAuto',
        Description => 'Sign auto-generated outgoing messages',
        Content     => $value,
    );
    return ($status, $msg) unless $status;
    return ($status, $self->loc('Signing enabled')) if $value;
    return ($status, $self->loc('Signing disabled'));
}

sub Encrypt {
    my $self = shift;
    my $value = shift;

    return undef unless $self->CurrentUserHasRight('SeeQueue');
    my $attr = $self->FirstAttribute('Encrypt') or return 0;
    return $attr->Content;
}

sub SetEncrypt {
    my $self = shift;
    my $value = shift;

    return ( 0, $self->loc('Permission Denied') )
        unless $self->CurrentUserHasRight('AdminQueue');

    my ($status, $msg) = $self->SetAttribute(
        Name        => 'Encrypt',
        Description => 'Encrypt outgoing messages by default',
        Content     => $value,
    );
    return ($status, $msg) unless $status;
    return ($status, $self->loc('Encrypting enabled')) if $value;
    return ($status, $self->loc('Encrypting disabled'));
}

=head2 Templates

Returns an RT::Templates object of all of this queue's templates.

=cut

sub Templates {
    my $self = shift;

    my $templates = RT::Templates->new( $self->CurrentUser );

    if ( $self->CurrentUserHasRight('ShowTemplate') ) {
        $templates->LimitToQueue( $self->id );
    }

    return ($templates);
}




=head2 CustomField NAME

Load the queue-specific custom field named NAME

=cut

sub CustomField {
    my $self = shift;
    my $name = shift;
    my $cf = RT::CustomField->new($self->CurrentUser);
    $cf->LoadByNameAndQueue(Name => $name, Queue => $self->Id); 
    return ($cf);
}



=head2 TicketCustomFields

Returns an L<RT::CustomFields> object containing all global and
queue-specific B<ticket> custom fields.

=cut

sub TicketCustomFields {
    my $self = shift;

    my $cfs = RT::CustomFields->new( $self->CurrentUser );
    if ( $self->CurrentUserHasRight('SeeQueue') ) {
        $cfs->SetContextObject( $self );
	$cfs->LimitToGlobalOrObjectId( $self->Id );
	$cfs->LimitToLookupType( 'RT::Queue-RT::Ticket' );
        $cfs->ApplySortOrder;
    }
    return ($cfs);
}



=head2 TicketTransactionCustomFields

Returns an L<RT::CustomFields> object containing all global and
queue-specific B<transaction> custom fields.

=cut

sub TicketTransactionCustomFields {
    my $self = shift;

    my $cfs = RT::CustomFields->new( $self->CurrentUser );
    if ( $self->CurrentUserHasRight('SeeQueue') ) {
        $cfs->SetContextObject( $self );
	$cfs->LimitToGlobalOrObjectId( $self->Id );
	$cfs->LimitToLookupType( 'RT::Queue-RT::Ticket-RT::Transaction' );
        $cfs->ApplySortOrder;
    }
    return ($cfs);
}





=head2 AllRoleGroupTypes

Returns a list of the names of the various role group types that this queue
has, including Requestor and Owner. If you don't want them, see
L</ManageableRoleGroupTypes>.

=cut

sub AllRoleGroupTypes {
    my $self = shift;
    return ($self->ManageableRoleGroupTypes, qw(Requestor Owner));
}

=head2 IsRoleGroupType

Returns whether the passed-in type is a role group type.

=cut

sub IsRoleGroupType {
    my $self = shift;
    my $type = shift;

    for my $valid_type ($self->AllRoleGroupTypes) {
        return 1 if $type eq $valid_type;
    }

    return 0;
}

=head2 ManageableRoleGroupTypes

Returns a list of the names of the various role group types that this queue
has, excluding Requestor and Owner. If you want them, see L</AllRoleGroupTypes>.

=cut

sub ManageableRoleGroupTypes {
    return qw(Cc AdminCc);
}

=head2 IsManageableRoleGroupType

Returns whether the passed-in type is a manageable role group type.

=cut

sub IsManageableRoleGroupType {
    my $self = shift;
    my $type = shift;

    for my $valid_type ($self->ManageableRoleGroupTypes) {
        return 1 if $type eq $valid_type;
    }

    return 0;
}


=head2 _CreateQueueGroups

Create the ticket groups and links for this ticket. 
This routine expects to be called from Ticket->Create _inside of a transaction_

It will create four groups for this ticket: Requestor, Cc, AdminCc and Owner.

It will return true on success and undef on failure.


=cut

sub _CreateQueueGroups {
    my $self = shift;

    my @types = $self->AllRoleGroupTypes;

    foreach my $type (@types) {
        my $ok = $self->_CreateQueueRoleGroup($type);
        return undef if !$ok;
    }

    return 1;
}

sub _CreateQueueRoleGroup {
    my $self = shift;
    my $type = shift;

    my $type_obj = RT::Group->new($self->CurrentUser);
    my ($id, $msg) = $type_obj->CreateRoleGroup(Instance => $self->Id, 
                                                    Type => $type,
                                                    Domain => 'RT::Queue-Role');
    unless ($id) {
        $RT::Logger->error("Couldn't create a Queue group of type '$type' for queue ".
                            $self->Id.": ".$msg);
        return(undef);
    }

    return $id;
}



# _HasModifyWatcherRight {{{
sub _HasModifyWatcherRight {
    my $self = shift;
    my %args = (
        Type  => undef,
        PrincipalId => undef,
        Email => undef,
        @_
    );

    return 1 if $self->CurrentUserHasRight('ModifyQueueWatchers');

    #If the watcher we're trying to add is for the current user
    if ( defined $args{'PrincipalId'} && $self->CurrentUser->PrincipalId  eq $args{'PrincipalId'}) {
        if ( $args{'Type'} eq 'AdminCc' ) {
            return 1 if $self->CurrentUserHasRight('WatchAsAdminCc');
        }
        elsif ( $args{'Type'} eq 'Cc' or $args{'Type'} eq 'Requestor' ) {
            return 1 if $self->CurrentUserHasRight('Watch');
        }
        else {
            $RT::Logger->warning( "$self -> _HasModifyWatcher got passed a bogus type $args{Type}");
            return ( 0, $self->loc('Invalid queue role group type [_1]', $args{Type}) );
        }
    }

    return ( 0, $self->loc("Permission Denied") );
}


=head2 AddWatcher

AddWatcher takes a parameter hash. The keys are as follows:

Type        One of Requestor, Cc, AdminCc

PrinicpalId The RT::Principal id of the user or group that's being added as a watcher
Email       The email address of the new watcher. If a user with this 
            email address can't be found, a new nonprivileged user will be created.

If the watcher you're trying to set has an RT account, set the Owner parameter to their User Id. Otherwise, set the Email parameter to their Email address.

Returns a tuple of (status/id, message).

=cut

sub AddWatcher {
    my $self = shift;
    my %args = (
        Type  => undef,
        PrincipalId => undef,
        Email => undef,
        @_
    );

    return ( 0, "No principal specified" )
        unless $args{'Email'} or $args{'PrincipalId'};

    if ( !$args{'PrincipalId'} && $args{'Email'} ) {
        my $user = RT::User->new( $self->CurrentUser );
        $user->LoadByEmail( $args{'Email'} );
        $args{'PrincipalId'} = $user->PrincipalId if $user->id;
    }

    return ( 0, "Unknown watcher type [_1]", $args{Type} )
        unless $self->IsRoleGroupType($args{Type});

    my ($ok, $msg) = $self->_HasModifyWatcherRight(%args);
    return ($ok, $msg) if !$ok;

    return $self->_AddWatcher(%args);
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


    my $principal = RT::Principal->new( $self->CurrentUser );
    if ( $args{'PrincipalId'} ) {
        $principal->Load( $args{'PrincipalId'} );
        if ( $principal->id and $principal->IsUser and my $email = $principal->Object->EmailAddress ) {
            return (0, $self->loc("[_1] is an address RT receives mail at. Adding it as a '[_2]' would create a mail loop", $email, $self->loc($args{'Type'})))
                if RT::EmailParser->IsRTAddress( $email );
        }
    }
    elsif ( $args{'Email'} ) {
        if ( RT::EmailParser->IsRTAddress( $args{'Email'} ) ) {
            return (0, $self->loc("[_1] is an address RT receives mail at. Adding it as a '[_2]' would create a mail loop", $args{'Email'}, $self->loc($args{'Type'})));
        }
        my $user = RT::User->new($self->CurrentUser);
        $user->LoadByEmail( $args{'Email'} );
        $user->Load( $args{'Email'} )
            unless $user->id;

        if ( $user->Id ) { # If the user exists
            $principal->Load( $user->PrincipalId );
        } else {
            # if the user doesn't exist, we need to create a new user
            my $new_user = RT::User->new(RT->SystemUser);

            my ( $Address, $Name ) =  
               RT::Interface::Email::ParseAddressFromHeader($args{'Email'});

            my ( $Val, $Message ) = $new_user->Create(
                Name         => $Address,
                EmailAddress => $Address,
                RealName     => $Name,
                Privileged   => 0,
                Comments     => 'Autocreated when added as a watcher'
            );
            unless ($Val) {
                $RT::Logger->error("Failed to create user ".$args{'Email'} .": " .$Message);
                # Deal with the race condition of two account creations at once
                $new_user->LoadByEmail( $args{'Email'} );
            }
            $principal->Load( $new_user->PrincipalId );
        }
    }
    # If we can't find this watcher, we need to bail.
    unless ( $principal->Id ) {
        return(0, $self->loc("Could not find or create that user"));
    }

    my $group = RT::Group->new($self->CurrentUser);
    $group->LoadQueueRoleGroup(Type => $args{'Type'}, Queue => $self->Id);
    unless ($group->id) {
        return(0,$self->loc("Group not found"));
    }

    if ( $group->HasMember( $principal)) {

        return ( 0, $self->loc('[_1] is already a [_2] for this queue',
                    $principal->Object->Name, $args{'Type'}) );
    }


    my ($m_id, $m_msg) = $group->_AddMember(PrincipalId => $principal->Id);
    unless ($m_id) {
        $RT::Logger->error("Failed to add ".$principal->Id." as a member of group ".$group->Id.": ".$m_msg);

        return ( 0, $self->loc('Could not make [_1] a [_2] for this queue',
                    $principal->Object->Name, $args{'Type'}) );
    }
    return ( 1, $self->loc("Added [_1] to members of [_2] for this queue.", $principal->Object->Name, $args{'Type'} ));
}



=head2 DeleteWatcher { Type => TYPE, PrincipalId => PRINCIPAL_ID, Email => EMAIL_ADDRESS }


Deletes a queue  watcher.  Takes two arguments:

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

    unless ( $args{'PrincipalId'} || $args{'Email'} ) {
        return ( 0, $self->loc("No principal specified") );
    }

    if ( !$args{PrincipalId} and $args{Email} ) {
        my $user = RT::User->new( $self->CurrentUser );
        my ($rv, $msg) = $user->LoadByEmail( $args{Email} );
        $args{PrincipalId} = $user->PrincipalId if $rv;
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

    my $group = RT::Group->new($self->CurrentUser);
    $group->LoadQueueRoleGroup(Type => $args{'Type'}, Queue => $self->Id);
    unless ($group->id) {
        return(0,$self->loc("Group not found"));
    }

    return ( 0, $self->loc('Unknown watcher type [_1]', $args{Type}) )
        unless $self->IsRoleGroupType($args{Type});

    my ($ok, $msg) = $self->_HasModifyWatcherRight(%args);
    return ($ok, $msg) if !$ok;

    # see if this user is already a watcher.

    unless ( $group->HasMember($principal)) {
        return ( 0, $self->loc('[_1] is not a [_2] for this queue',
            $principal->Object->Name, $args{'Type'}) );
    }

    my ($m_id, $m_msg) = $group->_DeleteMember($principal->Id);
    unless ($m_id) {
        $RT::Logger->error("Failed to delete ".$principal->Id.
                           " as a member of group ".$group->Id.": ".$m_msg);

        return ( 0, $self->loc('Could not remove [_1] as a [_2] for this queue',
                    $principal->Object->Name, $args{'Type'}) );
    }

    return ( 1, $self->loc("Removed [_1] from members of [_2] for this queue.", $principal->Object->Name, $args{'Type'} ));
}



=head2 AdminCcAddresses

returns String: All queue AdminCc email addresses as a string

=cut

sub AdminCcAddresses {
    my $self = shift;
    
    unless ( $self->CurrentUserHasRight('SeeQueue') ) {
        return undef;
    }   
    
    return ( $self->AdminCc->MemberEmailAddressesAsString )
    
}   



=head2 CcAddresses

returns String: All queue Ccs as a string of email addresses

=cut

sub CcAddresses {
    my $self = shift;

    unless ( $self->CurrentUserHasRight('SeeQueue') ) {
        return undef;
    }

    return ( $self->Cc->MemberEmailAddressesAsString);

}



=head2 Cc

Takes nothing.
Returns an RT::Group object which contains this Queue's Ccs.
If the user doesn't have "ShowQueue" permission, returns an empty group

=cut

sub Cc {
    my $self = shift;

    my $group = RT::Group->new($self->CurrentUser);
    if ( $self->CurrentUserHasRight('SeeQueue') ) {
        $group->LoadQueueRoleGroup(Type => 'Cc', Queue => $self->Id);
    }
    return ($group);

}



=head2 AdminCc

Takes nothing.
Returns an RT::Group object which contains this Queue's AdminCcs.
If the user doesn't have "ShowQueue" permission, returns an empty group

=cut

sub AdminCc {
    my $self = shift;

    my $group = RT::Group->new($self->CurrentUser);
    if ( $self->CurrentUserHasRight('SeeQueue') ) {
        $group->LoadQueueRoleGroup(Type => 'AdminCc', Queue => $self->Id);
    }
    return ($group);

}



# a generic routine to be called by IsRequestor, IsCc and IsAdminCc

=head2 IsWatcher { Type => TYPE, PrincipalId => PRINCIPAL_ID }

Takes a param hash with the attributes Type and PrincipalId

Type is one of Requestor, Cc, AdminCc and Owner

PrincipalId is an RT::Principal id 

Returns true if that principal is a member of the group Type for this queue


=cut

sub IsWatcher {
    my $self = shift;

    my %args = ( Type  => 'Cc',
        PrincipalId    => undef,
        @_
    );

    # Load the relevant group. 
    my $group = RT::Group->new($self->CurrentUser);
    $group->LoadQueueRoleGroup(Type => $args{'Type'}, Queue => $self->id);
    # Ask if it has the member in question

    my $principal = RT::Principal->new($self->CurrentUser);
    $principal->Load($args{'PrincipalId'});
    unless ($principal->Id) {
        return (undef);
    }

    return ($group->HasMemberRecursively($principal));
}




=head2 IsCc PRINCIPAL_ID

Takes an RT::Principal id.
Returns true if the principal is a requestor of the current queue.


=cut

sub IsCc {
    my $self = shift;
    my $cc   = shift;

    return ( $self->IsWatcher( Type => 'Cc', PrincipalId => $cc ) );

}



=head2 IsAdminCc PRINCIPAL_ID

Takes an RT::Principal id.
Returns true if the principal is a requestor of the current queue.

=cut

sub IsAdminCc {
    my $self   = shift;
    my $person = shift;

    return ( $self->IsWatcher( Type => 'AdminCc', PrincipalId => $person ) );

}










sub _Set {
    my $self = shift;

    unless ( $self->CurrentUserHasRight('AdminQueue') ) {
        return ( 0, $self->loc('Permission Denied') );
    }
    RT->System->QueueCacheNeedsUpdate(1);
    return ( $self->SUPER::_Set(@_) );
}



sub _Value {
    my $self = shift;

    unless ( $self->CurrentUserHasRight('SeeQueue') ) {
        return (undef);
    }

    return ( $self->__Value(@_) );
}



=head2 CurrentUserHasRight

Takes one argument. A textual string with the name of the right we want to check.
Returns true if the current user has that right for this queue.
Returns undef otherwise.

=cut

sub CurrentUserHasRight {
    my $self  = shift;
    my $right = shift;

    return (
        $self->HasRight(
            Principal => $self->CurrentUser,
            Right     => "$right"
          )
    );

}

=head2 CurrentUserCanSee

Returns true if the current user can see the queue, using SeeQueue

=cut

sub CurrentUserCanSee {
    my $self = shift;

    return $self->CurrentUserHasRight('SeeQueue');
}


=head2 HasRight

Takes a param hash with the fields 'Right' and 'Principal'.
Principal defaults to the current user.
Returns true if the principal has that right for this queue.
Returns undef otherwise.

=cut

# TAKES: Right and optional "Principal" which defaults to the current user
sub HasRight {
    my $self = shift;
    my %args = (
        Right     => undef,
        Principal => $self->CurrentUser,
        @_
    );
    my $principal = delete $args{'Principal'};
    unless ( $principal ) {
        $RT::Logger->error("Principal undefined in Queue::HasRight");
        return undef;
    }

    return $principal->HasRight(
        %args,
        Object => ($self->Id ? $self : $RT::System),
    );
}




=head2 id

Returns the current value of id. 
(In the database, id is stored as int(11).)


=cut


=head2 Name

Returns the current value of Name. 
(In the database, Name is stored as varchar(200).)



=head2 SetName VALUE


Set Name to VALUE. 
Returns (1, 'Status message') on success and (0, 'Error Message') on failure.
(In the database, Name will be stored as a varchar(200).)


=cut


=head2 Description

Returns the current value of Description. 
(In the database, Description is stored as varchar(255).)



=head2 SetDescription VALUE


Set Description to VALUE. 
Returns (1, 'Status message') on success and (0, 'Error Message') on failure.
(In the database, Description will be stored as a varchar(255).)


=cut


=head2 CorrespondAddress

Returns the current value of CorrespondAddress. 
(In the database, CorrespondAddress is stored as varchar(120).)



=head2 SetCorrespondAddress VALUE


Set CorrespondAddress to VALUE. 
Returns (1, 'Status message') on success and (0, 'Error Message') on failure.
(In the database, CorrespondAddress will be stored as a varchar(120).)


=cut


=head2 CommentAddress

Returns the current value of CommentAddress. 
(In the database, CommentAddress is stored as varchar(120).)



=head2 SetCommentAddress VALUE


Set CommentAddress to VALUE. 
Returns (1, 'Status message') on success and (0, 'Error Message') on failure.
(In the database, CommentAddress will be stored as a varchar(120).)


=cut


=head2 Lifecycle

Returns the current value of Lifecycle. 
(In the database, Lifecycle is stored as varchar(32).)



=head2 SetLifecycle VALUE


Set Lifecycle to VALUE. 
Returns (1, 'Status message') on success and (0, 'Error Message') on failure.
(In the database, Lifecycle will be stored as a varchar(32).)


=cut

=head2 SubjectTag

Returns the current value of SubjectTag. 
(In the database, SubjectTag is stored as varchar(120).)



=head2 SetSubjectTag VALUE


Set SubjectTag to VALUE. 
Returns (1, 'Status message') on success and (0, 'Error Message') on failure.
(In the database, SubjectTag will be stored as a varchar(120).)


=cut


=head2 InitialPriority

Returns the current value of InitialPriority. 
(In the database, InitialPriority is stored as int(11).)



=head2 SetInitialPriority VALUE


Set InitialPriority to VALUE. 
Returns (1, 'Status message') on success and (0, 'Error Message') on failure.
(In the database, InitialPriority will be stored as a int(11).)


=cut


=head2 FinalPriority

Returns the current value of FinalPriority. 
(In the database, FinalPriority is stored as int(11).)



=head2 SetFinalPriority VALUE


Set FinalPriority to VALUE. 
Returns (1, 'Status message') on success and (0, 'Error Message') on failure.
(In the database, FinalPriority will be stored as a int(11).)


=cut


=head2 DefaultDueIn

Returns the current value of DefaultDueIn. 
(In the database, DefaultDueIn is stored as int(11).)



=head2 SetDefaultDueIn VALUE


Set DefaultDueIn to VALUE. 
Returns (1, 'Status message') on success and (0, 'Error Message') on failure.
(In the database, DefaultDueIn will be stored as a int(11).)


=cut


=head2 Creator

Returns the current value of Creator. 
(In the database, Creator is stored as int(11).)


=cut


=head2 Created

Returns the current value of Created. 
(In the database, Created is stored as datetime.)


=cut


=head2 LastUpdatedBy

Returns the current value of LastUpdatedBy. 
(In the database, LastUpdatedBy is stored as int(11).)


=cut


=head2 LastUpdated

Returns the current value of LastUpdated. 
(In the database, LastUpdated is stored as datetime.)


=cut


=head2 Disabled

Returns the current value of Disabled. 
(In the database, Disabled is stored as smallint(6).)



=head2 SetDisabled VALUE


Set Disabled to VALUE. 
Returns (1, 'Status message') on success and (0, 'Error Message') on failure.
(In the database, Disabled will be stored as a smallint(6).)


=cut



sub _CoreAccessible {
    {
     
        id =>
        {read => 1, sql_type => 4, length => 11,  is_blob => 0,  is_numeric => 1,  type => 'int(11)', default => ''},
        Name => 
        {read => 1, write => 1, sql_type => 12, length => 200,  is_blob => 0,  is_numeric => 0,  type => 'varchar(200)', default => ''},
        Description => 
        {read => 1, write => 1, sql_type => 12, length => 255,  is_blob => 0,  is_numeric => 0,  type => 'varchar(255)', default => ''},
        CorrespondAddress => 
        {read => 1, write => 1, sql_type => 12, length => 120,  is_blob => 0,  is_numeric => 0,  type => 'varchar(120)', default => ''},
        CommentAddress => 
        {read => 1, write => 1, sql_type => 12, length => 120,  is_blob => 0,  is_numeric => 0,  type => 'varchar(120)', default => ''},
        SubjectTag => 
        {read => 1, write => 1, sql_type => 12, length => 120,  is_blob => 0,  is_numeric => 0,  type => 'varchar(120)', default => ''},
        Lifecycle => 
        {read => 1, write => 1, sql_type => 12, length => 32,  is_blob => 0, is_numeric => 0,  type => 'varchar(32)', default => 'default'},
        InitialPriority => 
        {read => 1, write => 1, sql_type => 4, length => 11,  is_blob => 0,  is_numeric => 1,  type => 'int(11)', default => '0'},
        FinalPriority => 
        {read => 1, write => 1, sql_type => 4, length => 11,  is_blob => 0,  is_numeric => 1,  type => 'int(11)', default => '0'},
        DefaultDueIn => 
        {read => 1, write => 1, sql_type => 4, length => 11,  is_blob => 0,  is_numeric => 1,  type => 'int(11)', default => '0'},
        Creator => 
        {read => 1, auto => 1, sql_type => 4, length => 11,  is_blob => 0,  is_numeric => 1,  type => 'int(11)', default => '0'},
        Created => 
        {read => 1, auto => 1, sql_type => 11, length => 0,  is_blob => 0,  is_numeric => 0,  type => 'datetime', default => ''},
        LastUpdatedBy => 
        {read => 1, auto => 1, sql_type => 4, length => 11,  is_blob => 0,  is_numeric => 1,  type => 'int(11)', default => '0'},
        LastUpdated => 
        {read => 1, auto => 1, sql_type => 11, length => 0,  is_blob => 0,  is_numeric => 0,  type => 'datetime', default => ''},
        Disabled => 
        {read => 1, write => 1, sql_type => 5, length => 6,  is_blob => 0,  is_numeric => 1,  type => 'smallint(6)', default => '0'},

 }
};



RT::Base->_ImportOverlays();

1;
