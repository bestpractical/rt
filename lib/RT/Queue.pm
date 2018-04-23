# BEGIN BPS TAGGED BLOCK {{{
#
# COPYRIGHT:
#
# This software is Copyright (c) 1996-2018 Best Practical Solutions, LLC
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

use Role::Basic 'with';
with "RT::Record::Role::Lifecycle",
     "RT::Record::Role::Links" => { -excludes => ["_AddLinksOnCreate"] },
     "RT::Record::Role::Roles",
     "RT::Record::Role::Rights";

sub Table {'Queues'}

sub LifecycleType { "ticket" }

sub ModifyLinkRight { "AdminQueue" }

require RT::ACE;
RT::ACE->RegisterCacheHandler(sub {
    my %args = (
        Action      => "",
        RightName   => "",
        @_
    );

    return unless $args{Action}    =~ /^(Grant|Revoke)$/i
              and $args{RightName} =~ /^(SeeQueue|CreateTicket)$/;

    RT->System->QueueCacheNeedsUpdate(1);
});

use RT::Groups;
use RT::CustomRoles;
use RT::ACL;
use RT::Interface::Email;

__PACKAGE__->AddRight( General => SeeQueue              => 'View queue' ); # loc
__PACKAGE__->AddRight( Admin   => AdminQueue            => 'Create, modify and delete queue' ); # loc
__PACKAGE__->AddRight( Admin   => ShowACL               => 'Display Access Control List' ); # loc
__PACKAGE__->AddRight( Admin   => ModifyACL             => 'Create, modify and delete Access Control List entries' ); # loc
__PACKAGE__->AddRight( Admin   => ModifyQueueWatchers   => 'Modify queue watchers' ); # loc
__PACKAGE__->AddRight( General => SeeCustomField        => 'View custom field values' ); # loc
__PACKAGE__->AddRight( Staff   => ModifyCustomField     => 'Modify custom field values' ); # loc
__PACKAGE__->AddRight( Staff   => SetInitialCustomField => 'Add custom field values only at object creation time'); # loc
__PACKAGE__->AddRight( Admin   => AssignCustomFields    => 'Assign and remove queue custom fields' ); # loc
__PACKAGE__->AddRight( Admin   => ModifyTemplate        => 'Modify Scrip templates' ); # loc
__PACKAGE__->AddRight( Admin   => ShowTemplate          => 'View Scrip templates' ); # loc

__PACKAGE__->AddRight( Admin   => ModifyScrips        => 'Modify Scrips' ); # loc
__PACKAGE__->AddRight( Admin   => ShowScrips          => 'View Scrips' ); # loc

__PACKAGE__->AddRight( General => ShowTicket          => 'View ticket summaries' ); # loc
__PACKAGE__->AddRight( Staff   => ShowTicketComments  => 'View ticket private commentary' ); # loc
__PACKAGE__->AddRight( Staff   => ShowOutgoingEmail   => 'View exact outgoing email messages and their recipients' ); # loc

__PACKAGE__->AddRight( General => Watch               => 'Sign up as a ticket Requestor or ticket or queue Cc' ); # loc
__PACKAGE__->AddRight( Staff   => WatchAsAdminCc      => 'Sign up as a ticket or queue AdminCc' ); # loc
__PACKAGE__->AddRight( General => CreateTicket        => 'Create tickets' ); # loc
__PACKAGE__->AddRight( General => ReplyToTicket       => 'Reply to tickets' ); # loc
__PACKAGE__->AddRight( General => CommentOnTicket     => 'Comment on tickets' ); # loc
__PACKAGE__->AddRight( Staff   => OwnTicket           => 'Own tickets' ); # loc
__PACKAGE__->AddRight( Staff   => ModifyTicket        => 'Modify tickets' ); # loc
__PACKAGE__->AddRight( Staff   => DeleteTicket        => 'Delete tickets' ); # loc
__PACKAGE__->AddRight( Staff   => TakeTicket          => 'Take tickets' ); # loc
__PACKAGE__->AddRight( Staff   => StealTicket         => 'Steal tickets' ); # loc
__PACKAGE__->AddRight( Staff   => ReassignTicket      => 'Modify ticket owner on owned tickets' ); # loc

__PACKAGE__->AddRight( Staff   => ForwardMessage      => 'Forward messages outside of RT' ); # loc

=head2 Create(ARGS)

Arguments: ARGS is a hash of named parameters.  Valid parameters are:

  Name (required)
  Description
  CorrespondAddress
  CommentAddress
 
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
        Sign              => undef,
        SignAuto          => undef,
        Encrypt           => undef,
        SLA               => undef,
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

    my $create_ret = $self->_CreateRoleGroups();
    unless ($create_ret) {
        $RT::Handle->Rollback();
        return ( 0, $self->loc('Queue could not be created') );
    }
    if ( $args{'_RecordTransaction'} ) {
        $self->_NewTransaction( Type => "Create" );
    }
    $RT::Handle->Commit;

    for my $attr (qw/Sign SignAuto Encrypt SLA/) {
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

    my ( undef, undef, $TransObj ) = $self->_NewTransaction(
        Field => 'Signing', #loc
        Type  => $value ? "Enabled" : "Disabled"
    );

    return ($status, scalar $TransObj->BriefDescription);
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

    my ( undef, undef, $TransObj ) = $self->_NewTransaction(
        Field => 'AutoSigning', #loc
        Type  => $value ? "Enabled" : "Disabled"
    );

    return ($status, scalar $TransObj->BriefDescription);
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

    my ( undef, undef, $TransObj ) = $self->_NewTransaction(
        Field => 'Encrypting', #loc
        Type  => $value ? "Enabled" : "Disabled"
    );

    return ($status, scalar $TransObj->BriefDescription);
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

Load the Ticket Custom Field applied to this Queue named NAME.
Does not load Global custom fields.

=cut

sub CustomField {
    my $self = shift;
    my $name = shift;
    my $cf = RT::CustomField->new($self->CurrentUser);
    $cf->LoadByName(
        Name       => $name,
        LookupType => RT::Ticket->CustomFieldLookupType,
        ObjectId   => $self->id,
    );
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

=head2 CustomRoles

Returns an L<RT::CustomRoles> object containing all queue-specific roles.

=cut

sub CustomRoles {
    my $self = shift;

    my $roles = RT::CustomRoles->new( $self->CurrentUser );
    if ( $self->CurrentUserHasRight('SeeQueue') ) {
        $roles->LimitToObjectId( $self->Id );
        $roles->ApplySortOrder;
    }
    return ($roles);
}

=head2 ManageableRoleGroupTypes

Returns a list of the names of the various role group types for Queues,
excluding ones used only for ACLs such as Requestor and Owner. If you want
them, see L</Roles>.

=cut

sub ManageableRoleGroupTypes {
    shift->Roles( ACLOnly => 0 )
}

=head2 IsManageableRoleGroupType

Returns whether the passed-in type is a manageable role group type.

=cut

sub IsManageableRoleGroupType {
    my $self = shift;
    my $type = shift;
    return grep { $type eq $_ } $self->ManageableRoleGroupTypes;
}


sub _HasModifyWatcherRight {
    my $self = shift;
    my ($type, $principal) = @_;

    # ModifyQueueWatchers works in any case
    return 1 if $self->CurrentUserHasRight('ModifyQueueWatchers');
    # If the watcher isn't the current user then the current user has no right
    return 0 unless $self->CurrentUser->PrincipalId == $principal->id;
    # If it's an AdminCc and they don't have 'WatchAsAdminCc', bail
    return 0 if $type eq 'AdminCc' and not $self->CurrentUserHasRight('WatchAsAdminCc');
    # If it's a Requestor or Cc and they don't have 'Watch', bail
    return 0 if ($type eq "Cc" or $type eq 'Requestor')
        and not $self->CurrentUserHasRight('Watch');
    return 1;
}


=head2 AddWatcher

Applies access control checking, then calls
L<RT::Record::Role::Roles/AddRoleMember>.  Additionally, C<Email> is
accepted as an alternative argument name for C<User>.

Returns a tuple of (status, message).

=cut

sub AddWatcher {
    my $self = shift;
    my %args = (
        Type  => undef,
        PrincipalId => undef,
        Email => undef,
        @_
    );

    $args{ACL} = sub { $self->_HasModifyWatcherRight( @_ ) };
    $args{User} ||= delete $args{Email};
    my ($principal, $msg) = $self->AddRoleMember( %args );
    return ( 0, $msg) unless $principal;

    my $group = $self->RoleGroup( $args{Type} );
    return ( 1, $self->loc("Added [_1] as [_2] for this queue",
                           $principal->Object->Name, $group->Label ));
}


=head2 DeleteWatcher

Applies access control checking, then calls
L<RT::Record::Role::Roles/DeleteRoleMember>.  Additionally, C<Email> is
accepted as an alternative argument name for C<User>.

Returns a tuple of (status, message).

=cut

sub DeleteWatcher {
    my $self = shift;

    my %args = (
        Type => undef,
        PrincipalId => undef,
        Email => undef,
        @_
    );

    $args{ACL} = sub { $self->_HasModifyWatcherRight( @_ ) };
    $args{User} ||= delete $args{Email};
    my ($principal, $msg) = $self->DeleteRoleMember( %args );
    return ( 0, $msg) unless $principal;

    my $group = $self->RoleGroup( $args{Type} );
    return ( 1, $self->loc("[_1] is no longer [_2] for this queue",
                           $principal->Object->Name, $group->Label ));
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

    return $self->RoleGroup( 'Cc', CheckRight => 'SeeQueue' );
}



=head2 AdminCc

Takes nothing.
Returns an RT::Group object which contains this Queue's AdminCcs.
If the user doesn't have "ShowQueue" permission, returns an empty group

=cut

sub AdminCc {
    my $self = shift;

    return $self->RoleGroup( 'AdminCc', CheckRight => 'SeeQueue' );
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
    my $group = $self->RoleGroup( $args{'Type'} );
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

    my %args = (
        Field             => undef,
        Value             => undef,
        TransactionType   => 'Set',
        RecordTransaction => 1,
        @_
    );

    unless ( $self->CurrentUserHasRight('AdminQueue') ) {
        return ( 0, $self->loc('Permission Denied') );
    }

    my $Old = $self->SUPER::_Value("$args{'Field'}");

    my ($ret, $msg) = $self->SUPER::_Set(
        Field => $args{'Field'},
        Value => $args{'Value'},
    );

    if ( $ret == 0 ) { return ( 0, $msg ); }

    RT->System->QueueCacheNeedsUpdate(1);

    if ( $args{'RecordTransaction'} == 1 ) {
        if ($args{'Field'} eq 'Disabled') {
            $args{'TransactionType'} = ($args{'Value'} == 1) ? "Disabled" : "Enabled";
            delete $args{'Field'};
        }
        my ( undef, undef, $TransObj ) = $self->_NewTransaction(
            Type      => $args{'TransactionType'},
            Field     => $args{'Field'},
            NewValue  => $args{'Value'},
            OldValue  => $Old,
            TimeTaken => $args{'TimeTaken'},
        );
    }

    return ( $ret, $msg );
}



sub _Value {
    my $self = shift;

    unless ( $self->CurrentUserHasRight('SeeQueue') ) {
        return (undef);
    }

    return ( $self->__Value(@_) );
}

=head2 CurrentUserCanSee

Returns true if the current user can see the queue, using SeeQueue

=cut

sub CurrentUserCanSee {
    my $self = shift;

    return $self->CurrentUserHasRight('SeeQueue');
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

=head2 SortOrder

Returns the current value of SortOrder. 
(In the database, SortOrder is stored as int(11).)


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
        SortOrder => 
        {read => 1, write => 1, sql_type => 4, length => 11,  is_blob => 0,  is_numeric => 1,  type => 'int(11)', default => '0'},
        Creator => 
        {read => 1, auto => 1, sql_type => 4, length => 11,  is_blob => 0,  is_numeric => 1,  type => 'int(11)', default => '0'},
        Created => 
        {read => 1, auto => 1, sql_type => 11, length => 0,  is_blob => 0,  is_numeric => 0,  type => 'datetime', default => ''},
        LastUpdatedBy => 
        {read => 1, auto => 1, sql_type => 4, length => 11,  is_blob => 0,  is_numeric => 1,  type => 'int(11)', default => '0'},
        LastUpdated => 
        {read => 1, auto => 1, sql_type => 11, length => 0,  is_blob => 0,  is_numeric => 0,  type => 'datetime', default => ''},
        SLADisabled => 
        {read => 1, write => 1, sql_type => 5, length => 6,  is_blob => 0,  is_numeric => 1,  type => 'smallint(6)', default => '1'},
        Disabled => 
        {read => 1, write => 1, sql_type => 5, length => 6,  is_blob => 0,  is_numeric => 1,  type => 'smallint(6)', default => '0'},

 }
};

sub FindDependencies {
    my $self = shift;
    my ($walker, $deps) = @_;

    $self->SUPER::FindDependencies($walker, $deps);

    # Queue role groups( Cc, AdminCc )
    my $objs = RT::Groups->new( $self->CurrentUser );
    $objs->Limit( FIELD => 'Domain', VALUE => 'RT::Queue-Role', CASESENSITIVE => 0 );
    $objs->Limit( FIELD => 'Instance', VALUE => $self->Id );
    $deps->Add( in => $objs );

    # Scrips
    $objs = RT::ObjectScrips->new( $self->CurrentUser );
    $objs->Limit( FIELD           => 'ObjectId',
                  OPERATOR        => '=',
                  VALUE           => $self->id,
                  ENTRYAGGREGATOR => 'OR' );
    $objs->Limit( FIELD           => 'ObjectId',
                  OPERATOR        => '=',
                  VALUE           => 0,
                  ENTRYAGGREGATOR => 'OR' );
    $deps->Add( in => $objs );

    # Templates (global ones have already been dealt with)
    $objs = RT::Templates->new( $self->CurrentUser );
    $objs->Limit( FIELD => 'Queue', VALUE => $self->Id);
    $deps->Add( in => $objs );

    # Custom Fields on things _in_ this queue (CFs on the queue itself
    # have already been dealt with)
    $objs = RT::ObjectCustomFields->new( $self->CurrentUser );
    $objs->Limit( FIELD           => 'ObjectId',
                  OPERATOR        => '=',
                  VALUE           => $self->id,
                  ENTRYAGGREGATOR => 'OR' );
    $objs->Limit( FIELD           => 'ObjectId',
                  OPERATOR        => '=',
                  VALUE           => 0,
                  ENTRYAGGREGATOR => 'OR' );
    my $cfs = $objs->Join(
        ALIAS1 => 'main',
        FIELD1 => 'CustomField',
        TABLE2 => 'CustomFields',
        FIELD2 => 'id',
    );
    $objs->Limit( ALIAS    => $cfs,
                  FIELD    => 'LookupType',
                  OPERATOR => 'STARTSWITH',
                  VALUE    => 'RT::Queue-' );
    $deps->Add( in => $objs );

    # Tickets
    $objs = RT::Tickets->new( $self->CurrentUser );
    $objs->Limit( FIELD => "Queue", VALUE => $self->Id );
    $objs->{allow_deleted_search} = 1;
    $deps->Add( in => $objs );

    # Object Custom Roles
    $objs = RT::ObjectCustomRoles->new( $self->CurrentUser );
    $objs->LimitToObjectId($self->Id);
    $deps->Add( in => $objs );
}

sub __DependsOn {
    my $self = shift;
    my %args = (
        Shredder => undef,
        Dependencies => undef,
        @_,
    );
    my $deps = $args{'Dependencies'};
    my $list = [];

# Tickets
    my $objs = RT::Tickets->new( $self->CurrentUser );
    $objs->{'allow_deleted_search'} = 1;
    $objs->Limit( FIELD => 'Queue', VALUE => $self->Id );
    push( @$list, $objs );

# Queue role groups( Cc, AdminCc )
    $objs = RT::Groups->new( $self->CurrentUser );
    $objs->Limit( FIELD => 'Domain', VALUE => 'RT::Queue-Role', CASESENSITIVE => 0 );
    $objs->Limit( FIELD => 'Instance', VALUE => $self->Id );
    push( @$list, $objs );

# Scrips
    $objs = RT::Scrips->new( $self->CurrentUser );
    $objs->LimitToQueue( $self->id );
    push( @$list, $objs );

# Templates
    $objs = $self->Templates;
    push( @$list, $objs );

# Custom Fields
    $objs = RT::CustomFields->new( $self->CurrentUser );
    $objs->SetContextObject( $self );
    $objs->LimitToQueue( $self->id );
    push( @$list, $objs );

# Object Custom Roles
    $objs = RT::ObjectCustomRoles->new( $self->CurrentUser );
    $objs->LimitToObjectId($self->Id);
    push( @$list, $objs );

    $deps->_PushDependencies(
        BaseObject => $self,
        Flags => RT::Shredder::Constants::DEPENDS_ON,
        TargetObjects => $list,
        Shredder => $args{'Shredder'}
    );
    return $self->SUPER::__DependsOn( %args );
}


sub PreInflate {
    my $class = shift;
    my ($importer, $uid, $data) = @_;

    $class->SUPER::PreInflate( $importer, $uid, $data );

    $data->{Name} = $importer->Qualify($data->{Name})
        if $data->{Name} ne "___Approvals";

    return if $importer->MergeBy( "Name", $class, $uid, $data );

    return 1;
}

sub DefaultValue {
    my $self = shift;
    my $field = shift;
    my $attr = $self->FirstAttribute('DefaultValues');
    return undef unless $attr && $attr->Content;
    return $attr->Content->{$field};
}

sub SetDefaultValue {
    my $self = shift;
    my %args = (
        Name  => undef,
        Value => undef,
        @_
    );
    my $field = shift;
    my $attr = $self->FirstAttribute('DefaultValues');

    my ($old_value, $old_content, $new_value);
    if ( $attr && $attr->Content ) {
        $old_content = $attr->Content;
        $old_value = $old_content->{$args{Name}};
    }

    unless ( defined $old_value && length $old_value ) {
        $old_value = $self->loc('(no value)');
    }

    $new_value = $args{Value};
    unless ( defined $new_value && length $new_value ) {
        $new_value = $self->loc( '(no value)' );
    }

    return 1 if $new_value eq $old_value;

    my ($ret, $msg) = $self->SetAttribute(
        Name    => 'DefaultValues',
        Content => {
            %{ $old_content || {} }, $args{Name} => $args{Value},
        },
    );

    if ( $ret ) {
        return ( $ret, $self->loc( 'Default value of [_1] changed from [_2] to [_3]', $args{Name}, $old_value, $new_value ) );
    }
    else {
        return ( $ret, $self->loc( "Can't change default value of [_1] from [_2] to [_3]: [_4]", $args{Name}, $old_value, $new_value, $msg ) );
    }
}

sub SLA {
    my $self = shift;
    my $value = shift;
    return undef unless $self->CurrentUserHasRight('SeeQueue');

    my $attr = $self->FirstAttribute('SLA') or return undef;
    return $attr->Content;
}

sub SetSLA {
    my $self = shift;
    my $value = shift;

    return ( 0, $self->loc('Permission Denied') )
        unless $self->CurrentUserHasRight('AdminQueue');

    my ($status, $msg) = $self->SetAttribute(
        Name        => 'SLA',
        Description => 'Default Queue SLA',
        Content     => $value,
    );
    return ($status, $msg) unless $status;
    return ($status, $self->loc("Queue's default service level has been changed"));
}

sub InitialPriority {
    my $self = shift;
    RT->Deprecated( Instead => "DefaultValue('InitialPriority')", Remove => '4.6' );
    return $self->DefaultValue('InitialPriority');
}

sub FinalPriority {
    my $self = shift;
    RT->Deprecated( Instead => "DefaultValue('FinalPriority')", Remove => '4.6' );
    return $self->DefaultValue('FinalPriority');
}

sub DefaultDueIn {
    my $self = shift;
    RT->Deprecated( Instead => "DefaultValue('Due')", Remove => '4.6' );

    # DefaultDueIn used to be a number of days; so if the DefaultValue is,
    # say, "3 days" then return 3
    my $due = $self->DefaultValue('Due');
    if (defined($due) && $due =~ /^(\d+) days?$/i) {
        return $1;
    }

    return $due;
}

sub SetInitialPriority {
    my $self = shift;
    my $value = shift;
    RT->Deprecated( Instead => "SetDefaultValue", Remove => '4.6' );
    return $self->SetDefaultValue(
        Name => 'InitialPriority',
        Value => $value,
    );
}

sub SetFinalPriority {
    my $self = shift;
    my $value = shift;
    RT->Deprecated( Instead => "SetDefaultValue", Remove => '4.6' );
    return $self->SetDefaultValue(
        Name => 'FinalPriority',
        Value => $value,
    );
}

sub SetDefaultDueIn {
    my $self = shift;
    my $value = shift;

    # DefaultDueIn used to be a number of days; so if we're setting to,
    # say, "3" then add the word "days" to match the way the new
    # DefaultValues works
    $value .= " days" if defined($value) && $value =~ /^\d+$/;

    RT->Deprecated( Instead => "SetDefaultValue", Remove => '4.6' );
    return $self->SetDefaultValue(
        Name => 'Due',
        Value => $value,
    );
}

RT::Base->_ImportOverlays();

1;
