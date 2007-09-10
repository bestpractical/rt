# BEGIN BPS TAGGED BLOCK {{{
# 
# COPYRIGHT:
#  
# This software is Copyright (c) 1996-2007 Best Practical Solutions, LLC 
#                                          <jesse@bestpractical.com>
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
# http://www.gnu.org/copyleft/gpl.html.
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

  RT::Model::Queue - an RT Queue object

=head1 SYNOPSIS

  use RT::Model::Queue;

=head1 DESCRIPTION


=head1 METHODS

=begin testing 

use RT::Model::Queue;


=cut


package RT::Model::Queue;

use strict;
no warnings qw(redefine);

use RT::Model::GroupCollection;
use RT::Model::ACECollection;
use RT::Interface::Email;


use base qw/RT::Record/;

sub table {'Queues'}

use Jifty::DBI::Schema;
use Jifty::DBI::Record schema {


column        Name => max_length is 200,  type is 'varchar(200)',  default is '';
column        Description => max_length is 255,  type is 'varchar(255)',  default is '';
column        CorrespondAddress => max_length is 120,  type is 'varchar(120)',  default is '';
column        CommentAddress => max_length is 120,  type is 'varchar(120)',  default is '';
column        InitialPriority => max_length is 11,  type is 'int(11)',  default is '0';
column        FinalPriority => max_length is 11,  type is 'int(11)',  default is '0';
column        DefaultDueIn => max_length is 11,  type is 'int(11)',  default is '0';
column        Creator => max_length is 11,  type is 'int(11)',  default is '0';
column        Created =>   type is 'datetime',  default is '';
column        LastUpdatedBy => max_length is 11,  type is 'int(11)',  default is '0';
column        LastUpdated =>   type is 'datetime',  default is '';
column        Disabled => max_length is 6,  type is 'smallint(6)',  default is '0';
};
our @DEFAULT_ACTIVE_STATUS = qw(new open stalled);
our @DEFAULT_INACTIVE_STATUS = qw(resolved rejected deleted);  

# $self->loc('new'); # For the string extractor to get a string to localize
# $self->loc('open'); # For the string extractor to get a string to localize
# $self->loc('stalled'); # For the string extractor to get a string to localize
# $self->loc('resolved'); # For the string extractor to get a string to localize
# $self->loc('rejected'); # For the string extractor to get a string to localize
# $self->loc('deleted'); # For the string extractor to get a string to localize


our $RIGHTS = {
    SeeQueue            => 'Can this principal see this queue',       # loc_pair
    AdminQueue          => 'Create, delete and modify queues',        # loc_pair
    ShowACL             => 'Display Access Control List',             # loc_pair
    ModifyACL           => 'Modify Access Control List',              # loc_pair
    ModifyQueueWatchers => 'Modify the queue watchers',               # loc_pair
    AssignCustomFields  => 'Assign and remove custom fields',         # loc_pair
    ModifyTemplate      => 'Modify Scrip templates for this queue',   # loc_pair
    ShowTemplate        => 'Display Scrip templates for this queue',  # loc_pair

    ModifyScrips => 'Modify Scrips for this queue',                   # loc_pair
    ShowScrips   => 'Display Scrips for this queue',                  # loc_pair

    ShowTicket         => 'See ticket summaries',                    # loc_pair
    ShowTicketComments => 'See ticket private commentary',           # loc_pair
    ShowOutgoingEmail => 'See exact outgoing email messages and their recipeients',           # loc_pair

    Watch => 'Sign up as a ticket Requestor or ticket or queue Cc',   # loc_pair
    WatchAsAdminCc  => 'Sign up as a ticket or queue AdminCc',        # loc_pair
    CreateTicket    => 'Create tickets in this queue',                # loc_pair
    ReplyToTicket   => 'Reply to tickets',                            # loc_pair
    CommentOnTicket => 'Comment on tickets',                          # loc_pair
    OwnTicket       => 'Own tickets',                                 # loc_pair
    ModifyTicket    => 'Modify tickets',                              # loc_pair
    DeleteTicket    => 'Delete tickets',                              # loc_pair
    TakeTicket      => 'Take tickets',                                # loc_pair
    StealTicket     => 'Steal tickets',                               # loc_pair

    ForwardMessage  => 'Forward messages to third person(s)',         # loc_pair

};

# Tell RT::Model::ACE that this sort of object can get acls granted
$RT::Model::ACE::OBJECT_TYPES{'RT::Model::Queue'} = 1;

# TODO: This should be refactored out into an RT::Model::ACECollectionedObject or something
# stuff the rights into a hash of rights that can exist.

foreach my $right ( keys %{$RIGHTS} ) {
    $RT::Model::ACE::LOWERCASERIGHTNAMES{ lc $right } = $right;
}
    

sub AddLink {
    my $self = shift;
    my %args = ( Target => '',
                 Base   => '',
                 Type   => '',
                 Silent => undef,
                 @_ );

    unless ( $self->current_user_has_right('ModifyQueue') ) {
        return ( 0, $self->loc("Permission Denied") );
    }

    return $self->SUPER::_AddLink(%args);
}

sub delete_link {
    my $self = shift;
    my %args = (
        Base   => undef,
        Target => undef,
        Type   => undef,
        @_
    );

    #check acls
    unless ( $self->current_user_has_right('ModifyQueue') ) {
        $RT::Logger->debug("No permission to delete links\n");
        return ( 0, $self->loc('Permission Denied'))
    }

    return $self->SUPER::_delete_link(%args);
}

=head2 AvailableRights

Returns a hash of available rights for this object. The keys are the right names and the values are a description of what the rights do

=cut

sub AvailableRights {
    my $self = shift;
    return($RIGHTS);
}

# {{{ ActiveStatusArray

=head2 ActiveStatusArray

Returns an array of all ActiveStatuses for this queue

=cut

sub ActiveStatusArray {
    my $self = shift;
    if (RT->Config->Get('ActiveStatus')) {
    	return (RT->Config->Get('ActiveStatus'))
    } else {
        $RT::Logger->warning("RT::ActiveStatus undefined, falling back to deprecated defaults");
        return (@DEFAULT_ACTIVE_STATUS);
    }
}

# }}}

# {{{ InactiveStatusArray

=head2 InactiveStatusArray

Returns an array of all InactiveStatuses for this queue

=cut

sub InactiveStatusArray {
    my $self = shift;
    if (RT->Config->Get('InactiveStatus')) {
    	return (RT->Config->Get('InactiveStatus'))
    } else {
        $RT::Logger->warning("RT::InactiveStatus undefined, falling back to deprecated defaults");
        return (@DEFAULT_INACTIVE_STATUS);
    }
}

# }}}

# {{{ StatusArray

=head2 StatusArray

Returns an array of all statuses for this queue

=cut

sub StatusArray {
    my $self = shift;
    return ($self->ActiveStatusArray(), $self->InactiveStatusArray());
}

# }}}

# {{{ IsValidStatus

=head2 IsValidStatus value

Returns true if value is a valid status.  Otherwise, returns 0.


=cut

sub IsValidStatus {
    my $self  = shift;
    my $value = shift;

    my $retval = grep ( $_ eq $value, $self->StatusArray );
    return ($retval);

}

# }}}

# {{{ IsActiveStatus

=head2 IsActiveStatus value

Returns true if value is a Active status.  Otherwise, returns 0


=cut

sub IsActiveStatus {
    my $self  = shift;
    my $value = shift;

    my $retval = grep ( $_ eq $value, $self->ActiveStatusArray );
    return ($retval);

}

# }}}

# {{{ IsInactiveStatus

=head2 IsInactiveStatus value

Returns true if value is a Inactive status.  Otherwise, returns 0


=cut

sub IsInactiveStatus {
    my $self  = shift;
    my $value = shift;

    my $retval = grep ( $_ eq $value, $self->InactiveStatusArray );
    return ($retval);

}

# }}}


# {{{ sub create




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

sub create {
    my $self = shift;
    my %args = (
        Name              => undef,
        CorrespondAddress => '',
        Description       => '',
        CommentAddress    => '',
        InitialPriority   => 0,
        FinalPriority     => 0,
        DefaultDueIn      => 0,
        Sign              => undef,
        Encrypt           => undef,
        @_
    );

    unless ( $self->current_user->has_right(Right => 'AdminQueue', Object => $RT::System) )
    {    #Check them ACLs
        return ( 0, $self->loc("No permission to create queues") );
    }

    unless ( $self->validate_Name( $args{'Name'} ) ) {
        return ( 0, $self->loc('Queue already exists') );
    }

    my %attrs = map {$_ => 1} $self->readable_attributes;

    #TODO better input validation
    Jifty->handle->begin_transaction();
    my $id = $self->SUPER::create( map { $_ => $args{$_} } grep exists $args{$_}, keys %attrs );
    unless ($id) {
        Jifty->handle->rollback();
        return ( 0, $self->loc('Queue could not be Created') );
    }

    my $create_ret = $self->_createQueueGroups();
    unless ($create_ret) {
        Jifty->handle->rollback();
        return ( 0, $self->loc('Queue could not be Created') );
    }
    Jifty->handle->commit;

    if ( defined $args{'Sign'} ) {
        my ($status, $msg) = $self->set_Sign( $args{'Sign'} );
        $RT::Logger->error("Couldn't set attribute 'Sign': $msg")
            unless $status;
    }
    if ( defined $args{'Encrypt'} ) {
        my ($status, $msg) = $self->set_Encrypt( $args{'Encrypt'} );
        $RT::Logger->error("Couldn't set attribute 'Encrypt': $msg")
            unless $status;
    }

    return ( $id, $self->loc("Queue Created") );
}

# }}}

# {{{ sub delete 

sub delete {
    my $self = shift;
    return ( 0,
        $self->loc('Deleting this object would break referential integrity') );
}

# }}}

# {{{ sub set_Disabled

=head2 SetDisabled

Takes a boolean.
1 will cause this queue to no longer be available for tickets.
0 will re-enable this queue.

=cut

# }}}

# {{{ sub load 

=head2 Load

Takes either a numerical id or a textual Name and loads the specified queue.

=cut

sub load {
    my $self = shift;
    my $identifier = shift;
    if ( !$identifier ) {
        return (undef);
    }

    if ( $identifier =~ /^(\d+)$/ ) {
        $self->load_by_cols( id => $identifier);
    }
    else {
        $self->load_by_cols( Name => $identifier );
    }

    return ( $self->id );

}

# }}}

# {{{ sub validate_Name

=head2 ValidateName NAME

Takes a queue name. Returns true if it's an ok name for
a new queue. Returns undef if there's already a queue by that name.

=cut

sub validate_Name {
    my $self = shift;
    my $name = shift;

    my $tempqueue = new RT::Model::Queue($RT::SystemUser);
    $tempqueue->load($name);

    #If this queue exists, return undef
    if ( $tempqueue->Name() && $tempqueue->id != $self->id)  {
        return (undef);
    }

    #If the queue doesn't exist, return 1
    else {
        return ($self->SUPER::validate_Name($name));
    }

}

# }}}

=head2 SetSign

=cut

sub Sign {
    my $self = shift;
    my $value = shift;

    return undef unless $self->current_user_has_right('SeeQueue');
    my $attr = $self->first_attribute('Sign') or return 0;
    return $attr->Content;
}

sub set_Sign {
    my $self = shift;
    my $value = shift;

    return ( 0, $self->loc('Permission Denied') )
        unless $self->current_user_has_right('AdminQueue');

    my ($status, $msg) = $self->set_Attribute(
        Name        => 'Sign',
        Description => 'Sign outgoing messages by default',
        Content     => $value,
    );
    return ($status, $msg) unless $status;
    return ($status, $self->loc('Signing enabled')) if $value;
    return ($status, $self->loc('Signing disabled'));
}

sub Encrypt {
    my $self = shift;
    my $value = shift;

    return undef unless $self->current_user_has_right('SeeQueue');
    my $attr = $self->first_attribute('Encrypt') or return 0;
    return $attr->Content;
}

sub set_Encrypt {
    my $self = shift;
    my $value = shift;

    return ( 0, $self->loc('Permission Denied') )
        unless $self->current_user_has_right('AdminQueue');

    my ($status, $msg) = $self->set_Attribute(
        Name        => 'Encrypt',
        Description => 'Encrypt outgoing messages by default',
        Content     => $value,
    );
    return ($status, $msg) unless $status;
    return ($status, $self->loc('Encrypting enabled')) if $value;
    return ($status, $self->loc('Encrypting disabled'));
}

# {{{ sub Templates

=head2 Templates

Returns an RT::Model::TemplateCollection object of all of this queue's templates.

=cut

sub Templates {
    my $self = shift;

    my $templates = RT::Model::TemplateCollection->new( $self->current_user );

    if ( $self->current_user_has_right('ShowTemplate') ) {
        $templates->LimitToQueue( $self->id );
    }

    return ($templates);
}

# }}}

# {{{ Dealing with custom fields

# {{{  CustomField

=head2 CustomField NAME

Load the queue-specific custom field named NAME

=cut

sub CustomField {
    my $self = shift;
    my $name = shift;
    my $cf = RT::Model::CustomField->new($self->current_user);
    $cf->load_by_name_and_queue(Name => $name, Queue => $self->id); 
    return ($cf);
}


# {{{ TicketCustomFields

=head2 TicketCustomFields

Returns an L<RT::Model::CustomFieldCollection> object containing all global and
queue-specific B<ticket> custom fields.

=cut

sub TicketCustomFields {
    my $self = shift;

    my $cfs = RT::Model::CustomFieldCollection->new( $self->current_user );
    if ( $self->current_user_has_right('SeeQueue') ) {
	$cfs->LimitToGlobalOrObjectId( $self->id );
	$cfs->LimitToLookupType( 'RT::Model::Queue-RT::Model::Ticket' );
    }
    return ($cfs);
}

# }}}

# {{{ TicketTransactionCustomFields

=head2 TicketTransactionCustomFields

Returns an L<RT::Model::CustomFieldCollection> object containing all global and
queue-specific B<transaction> custom fields.

=cut

sub TicketTransactionCustomFields {
    my $self = shift;

    my $cfs = RT::Model::CustomFieldCollection->new( $self->current_user );
    if ( $self->current_user_has_right('SeeQueue') ) {
	$cfs->LimitToGlobalOrObjectId( $self->id );
	$cfs->LimitToLookupType( 'RT::Model::Queue-RT::Model::Ticket-RT::Model::Transaction' );
    }
    return ($cfs);
}

# }}}

# }}}


# {{{ Routines dealing with watchers.

# {{{ _createQueueGroups 

=head2 _createQueueGroups

Create the ticket groups and links for this ticket. 
This routine expects to be called from Ticket->create _inside of a transaction_

It will create four groups for this ticket: Requestor, Cc, AdminCc and Owner.

It will return true on success and undef on failure.


=cut


sub _createQueueGroups {
    my $self = shift;

    my @types = qw(Cc AdminCc Requestor Owner);

    foreach my $type (@types) {
        my $type_obj = RT::Model::Group->new($self->current_user);
        my ($id, $msg) = $type_obj->createRoleGroup(Instance => $self->id, 
                                                     Type => $type,
                                                     Domain => 'RT::Model::Queue-Role');
        unless ($id) {
            $RT::Logger->error("Couldn't create a Queue group of type '$type' for ticket ".
                               $self->id.": ".$msg);
            return(undef);
        }
     }
    return(1);
   
}


# }}}

# {{{ sub AddWatcher

=head2 AddWatcher

AddWatcher takes a parameter hash. The keys are as follows:

Type        One of Requestor, Cc, AdminCc

PrinicpalId The RT::Model::Principal id of the user or group that's being added as a watcher
Email       The email address of the new watcher. If a user with this 
            email address can't be found, a new nonprivileged user will be Created.

If the watcher you\'re trying to set has an RT account, set the Owner paremeter to their User Id. Otherwise, set the Email parameter to their Email address.

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

    # {{{ Check ACLS
    #If the watcher we're trying to add is for the current user
    if ( $self->current_user->PrincipalId  eq $args{'PrincipalId'}) {
        #  If it's an AdminCc and they don't have 
        #   'WatchAsAdminCc' or 'ModifyTicket', bail
        if ( $args{'Type'} eq 'AdminCc' ) {
            unless ( $self->current_user_has_right('ModifyQueueWatchers')
                or $self->current_user_has_right('WatchAsAdminCc') ) {
                return ( 0, $self->loc('Permission Denied'))
            }
        }

        #  If it's a Requestor or Cc and they don't have
        #   'Watch' or 'ModifyTicket', bail
        elsif ( ( $args{'Type'} eq 'Cc' ) or ( $args{'Type'} eq 'Requestor' ) ) {

            unless ( $self->current_user_has_right('ModifyQueueWatchers')
                or $self->current_user_has_right('Watch') ) {
                return ( 0, $self->loc('Permission Denied'))
            }
        }
     else {
            $RT::Logger->warning( "$self -> AddWatcher got passed a bogus type");
            return ( 0, $self->loc('Error in parameters to Queue->AddWatcher') );
        }
    }

    # If the watcher isn't the current user 
    # and the current user  doesn't have 'ModifyQueueWatcher'
    # bail
    else {
        unless ( $self->current_user_has_right('ModifyQueueWatchers') ) {
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


    my $principal = RT::Model::Principal->new($self->current_user);
    if ($args{'PrincipalId'}) {
        $principal->load($args{'PrincipalId'});
    }
    elsif ($args{'Email'}) {

        my $user = RT::Model::User->new($self->current_user);
        $user->load_by_email($args{'Email'});

        unless ($user->id) {
            $user->load($args{'Email'});
        }
        if ($user->id) { # If the user exists
            $principal->load($user->PrincipalId);
        } else {

        # if the user doesn't exist, we need to create a new user
             my $new_user = RT::Model::User->new($RT::SystemUser);

            my ( $Address, $Name ) =  
               RT::Interface::Email::ParseAddressFromHeader($args{'Email'});

            my ( $Val, $Message ) = $new_user->create(
                Name => $Address,
                EmailAddress => $Address,
                RealName     => $Name,
                Privileged   => 0,
                Comments     => 'AutoCreated when added as a watcher');
            unless ($Val) {
                $RT::Logger->error("Failed to create user ".$args{'Email'} .": " .$Message);
                # Deal with the race condition of two account creations at once
                $new_user->load_by_email($args{'Email'});
            }
            $principal->load($new_user->PrincipalId);
        }
    }
    # If we can't find this watcher, we need to bail.
    unless ($principal->id) {
        return(0, $self->loc("Could not find or create that user"));
    }


    my $group = RT::Model::Group->new($self->current_user);
    $group->loadQueueRoleGroup(Type => $args{'Type'}, Queue => $self->id);
    unless ($group->id) {
        return(0,$self->loc("Group not found"));
    }

    if ( $group->has_member( $principal)) {

        return ( 0, $self->loc('That principal is already a [_1] for this queue', $args{'Type'}) );
    }


    my ($m_id, $m_msg) = $group->_AddMember(PrincipalId => $principal->id);
    unless ($m_id) {
        $RT::Logger->error("Failed to add ".$principal->id." as a member of group ".$group->id."\n".$m_msg);

        return ( 0, $self->loc('Could not make that principal a [_1] for this queue', $args{'Type'}) );
    }
    return ( 1, $self->loc('Added principal as a [_1] for this queue', $args{'Type'}) );
}

# }}}

# {{{ sub deleteWatcher

=head2 DeleteWatcher { Type => TYPE, PrincipalId => PRINCIPAL_ID, Email => EMAIL_ADDRESS }


Deletes a queue  watcher.  Takes two arguments:

Type  (one of Requestor,Cc,AdminCc)

and one of

PrincipalId (an RT::Model::Principal Id of the watcher you want to remove)
    OR
Email (the email address of an existing wathcer)


=cut


sub deleteWatcher {
    my $self = shift;

    my %args = ( Type => undef,
                 PrincipalId => undef,
                 @_ );

    unless ($args{'PrincipalId'} ) {
        return(0, $self->loc("No principal specified"));
    }
    my $principal = RT::Model::Principal->new($self->current_user);
    $principal->load($args{'PrincipalId'});

    # If we can't find this watcher, we need to bail.
    unless ($principal->id) {
        return(0, $self->loc("Could not find that principal"));
    }

    my $group = RT::Model::Group->new($self->current_user);
    $group->loadQueueRoleGroup(Type => $args{'Type'}, Queue => $self->id);
    unless ($group->id) {
        return(0,$self->loc("Group not found"));
    }

    # {{{ Check ACLS
    #If the watcher we're trying to add is for the current user
    if ( $self->current_user->PrincipalId  eq $args{'PrincipalId'}) {
        #  If it's an AdminCc and they don't have 
        #   'WatchAsAdminCc' or 'ModifyQueue', bail
  if ( $args{'Type'} eq 'AdminCc' ) {
            unless ( $self->current_user_has_right('ModifyQueueWatchers')
                or $self->current_user_has_right('WatchAsAdminCc') ) {
                return ( 0, $self->loc('Permission Denied'))
            }
        }

        #  If it's a Requestor or Cc and they don't have
        #   'Watch' or 'ModifyQueue', bail
        elsif ( ( $args{'Type'} eq 'Cc' ) or ( $args{'Type'} eq 'Requestor' ) ) {
            unless ( $self->current_user_has_right('ModifyQueueWatchers')
                or $self->current_user_has_right('Watch') ) {
                return ( 0, $self->loc('Permission Denied'))
            }
        }
        else {
            $RT::Logger->warning( "$self -> DeleteWatcher got passed a bogus type");
            return ( 0, $self->loc('Error in parameters to Queue->deleteWatcher') );
        }
    }

    # If the watcher isn't the current user 
    # and the current user  doesn't have 'ModifyQueueWathcers' bail
    else {
        unless ( $self->current_user_has_right('ModifyQueueWatchers') ) {
            return ( 0, $self->loc("Permission Denied") );
        }
    }

    # }}}


    # see if this user is already a watcher.

    unless ( $group->has_member($principal)) {
        return ( 0,
        $self->loc('That principal is not a [_1] for this queue', $args{'Type'}) );
    }

    my ($m_id, $m_msg) = $group->_delete_member($principal->id);
    unless ($m_id) {
        $RT::Logger->error("Failed to delete ".$principal->id.
                           " as a member of group ".$group->id."\n".$m_msg);

        return ( 0,    $self->loc('Could not remove that principal as a [_1] for this queue', $args{'Type'}) );
    }

    return ( 1, $self->loc("[_1] is no longer a [_2] for this queue.", $principal->Object->Name, $args{'Type'} ));
}

# }}}

# {{{ AdminCcAddresses

=head2 AdminCcAddresses

returns String: All queue AdminCc email addresses as a string

=cut

sub AdminCcAddresses {
    my $self = shift;
    
    unless ( $self->current_user_has_right('SeeQueue') ) {
        return undef;
    }   
    
    return ( $self->AdminCc->MemberEmailAddressesAsString )
    
}   

# }}}

# {{{ CcAddresses

=head2 CcAddresses

returns String: All queue Ccs as a string of email addresses

=cut

sub CcAddresses {
    my $self = shift;

    unless ( $self->current_user_has_right('SeeQueue') ) {
        return undef;
    }

    return ( $self->Cc->MemberEmailAddressesAsString);

}
# }}}


# {{{ sub Cc

=head2 Cc

Takes nothing.
Returns an RT::Model::Group object which contains this Queue's Ccs.
If the user doesn't have "ShowQueue" permission, returns an empty group

=cut

sub Cc {
    my $self = shift;

    my $group = RT::Model::Group->new($self->current_user);
    if ( $self->current_user_has_right('SeeQueue') ) {
        $group->loadQueueRoleGroup(Type => 'Cc', Queue => $self->id);
    }
    return ($group);

}

# }}}

# {{{ sub AdminCc

=head2 AdminCc

Takes nothing.
Returns an RT::Model::Group object which contains this Queue's AdminCcs.
If the user doesn't have "ShowQueue" permission, returns an empty group

=cut

sub AdminCc {
    my $self = shift;

    my $group = RT::Model::Group->new($self->current_user);
    if ( $self->current_user_has_right('SeeQueue') ) {
        $group->loadQueueRoleGroup(Type => 'AdminCc', Queue => $self->id);
    }
    return ($group);

}

# }}}

# {{{ IsWatcher, IsCc, IsAdminCc

# {{{ sub IsWatcher
# a generic routine to be called by IsRequestor, IsCc and IsAdminCc

=head2 IsWatcher { Type => TYPE, PrincipalId => PRINCIPAL_ID }

Takes a param hash with the attributes Type and PrincipalId

Type is one of Requestor, Cc, AdminCc and Owner

PrincipalId is an RT::Model::Principal id 

Returns true if that principal is a member of the group Type for this queue


=cut

sub IsWatcher {
    my $self = shift;

    my %args = ( Type  => 'Cc',
        PrincipalId    => undef,
        @_
    );

    # Load the relevant group. 
    my $group = RT::Model::Group->new($self->current_user);
    $group->loadQueueRoleGroup(Type => $args{'Type'}, Queue => $self->id);
    # Ask if it has the member in question

    my $principal = RT::Model::Principal->new($self->current_user);
    $principal->load($args{'PrincipalId'});
    unless ($principal->id) {
        return (undef);
    }

    return ($group->has_member_recursively($principal));
}

# }}}


# {{{ sub IsCc

=head2 IsCc PRINCIPAL_ID

Takes an RT::Model::Principal id.
Returns true if the principal is a requestor of the current queue.


=cut

sub IsCc {
    my $self = shift;
    my $cc   = shift;

    return ( $self->IsWatcher( Type => 'Cc', PrincipalId => $cc ) );

}

# }}}

# {{{ sub IsAdminCc

=head2 IsAdminCc PRINCIPAL_ID

Takes an RT::Model::Principal id.
Returns true if the principal is a requestor of the current queue.

=cut

sub IsAdminCc {
    my $self   = shift;
    my $person = shift;

    return ( $self->IsWatcher( Type => 'AdminCc', PrincipalId => $person ) );

}

# }}}


# }}}





# }}}

# {{{ ACCESS CONTROL

# {{{ sub _set
sub _set {
    my $self = shift;

    unless ( $self->current_user_has_right('AdminQueue') ) {
        return ( 0, $self->loc('Permission Denied') );
    }
    return ( $self->SUPER::_set(@_) );
}

# }}}

# {{{ sub _value

sub _value {
    my $self = shift;

    unless ( $self->current_user_has_right('SeeQueue') ) {
        return (undef);
    }

    return ( $self->__value(@_) );
}

# }}}

# {{{ sub current_user_has_right

=head2 current_user_has_right

Takes one argument. A textual string with the name of the right we want to check.
Returns true if the current user has that right for this queue.
Returns undef otherwise.

=cut

sub current_user_has_right {
    my $self  = shift;
    my $right = shift;

    return (
        $self->has_right(
            Principal => $self->current_user,
            Right     => "$right"
          )
    );

}

# }}}

# {{{ sub has_right

=head2 has_right

Takes a param hash with the fields 'Right' and 'Principal'.
Principal defaults to the current user.
Returns true if the principal has that right for this queue.
Returns undef otherwise.

=cut

# TAKES: Right and optional "Principal" which defaults to the current user
sub has_right {
    my $self = shift;
    my %args = (
        Right     => undef,
        Principal => $self->current_user,
        @_
    );
     my $principal = delete $args{'Principal'};
     unless ( $principal ) {
         $RT::Logger->error("Principal undefined in Queue::has_right");
        return undef;
     }
  
     return $principal->has_right(
         %args,
         Object => ($self->id ? $self : $RT::System),
    );
}

# }}}

# }}}

1;
