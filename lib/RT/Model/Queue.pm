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

=head1 name

  RT::Model::Queue - an RT Queue object

=head1 SYNOPSIS

  use RT::Model::Queue;

=head1 description


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

    column name => max_length is 200, type is 'varchar(200)', default is '';
    column
        description => max_length is 255,
        type is 'varchar(255)', default is '';
    column
        correspond_address => max_length is 120,
        type is 'varchar(120)', default is '';
    column
        comment_address => max_length is 120,
        type is 'varchar(120)', default is '';
    column
        initial_priority => max_length is 11,
        type is 'int(11)', default is '0';
    column
        final_priority => max_length is 11,
        type is 'int(11)', default is '0';
    column
        default_due_in => max_length is 11,
        type is 'int(11)', default is '0';
    column Creator => max_length is 11, type is 'int(11)', default is '0';
    column Created => type is 'datetime', default is '';
    column
        last_updated_by => max_length is 11,
        type is 'int(11)', default is '0';
    column last_updated => type is 'datetime', default is '';
    column disabled => max_length is 6, type is 'smallint(6)', default is '0';
};
our @DEFAULT_ACTIVE_STATUS   = qw(new open stalled);
our @DEFAULT_INACTIVE_STATUS = qw(resolved rejected deleted);

# _('new'); # For the string extractor to get a string to localize
# _('open'); # For the string extractor to get a string to localize
# _('stalled'); # For the string extractor to get a string to localize
# _('resolved'); # For the string extractor to get a string to localize
# _('rejected'); # For the string extractor to get a string to localize
# _('deleted'); # For the string extractor to get a string to localize

our $RIGHTS = {
    SeeQueue            => 'Can this principal see this queue',     # loc_pair
    AdminQueue          => 'Create, delete and modify queues',      # loc_pair
    ShowACL             => 'Display Access Control List',           # loc_pair
    ModifyACL           => 'Modify Access Control List',            # loc_pair
    ModifyQueueWatchers => 'Modify the queue watchers',             # loc_pair
    AssignCustomFields  => 'Assign and remove custom fields',       # loc_pair
    ModifyTemplate      => 'Modify Scrip templates for this queue', # loc_pair
    ShowTemplate => 'Display Scrip templates for this queue',       # loc_pair

    ModifyScrips => 'Modify Scrips for this queue',                 # loc_pair
    ShowScrips   => 'Display Scrips for this queue',                # loc_pair

    ShowTicket         => 'See ticket summaries',                   # loc_pair
    ShowTicketcomments => 'See ticket private commentary',          # loc_pair
    ShowOutgoingEmail =>
        'See exact outgoing email messages and their recipeients',  # loc_pair

    Watch => 'Sign up as a ticket Requestor or ticket or queue Cc', # loc_pair
    WatchAsAdminCc  => 'Sign up as a ticket or queue AdminCc',      # loc_pair
    create_ticket   => 'Create tickets in this queue',              # loc_pair
    ReplyToTicket   => 'Reply to tickets',                          # loc_pair
    commentOnTicket => 'comment on tickets',                        # loc_pair
    OwnTicket       => 'Own tickets',                               # loc_pair
    ModifyTicket    => 'Modify tickets',                            # loc_pair
    DeleteTicket    => 'Delete tickets',                            # loc_pair
    TakeTicket      => 'Take tickets',                              # loc_pair
    StealTicket     => 'Steal tickets',                             # loc_pair

    ForwardMessage => 'Forward messages to third person(s)',        # loc_pair

};

# Tell RT::Model::ACE that this sort of object can get acls granted
$RT::Model::ACE::OBJECT_TYPES{'RT::Model::Queue'} = 1;

# TODO: This should be refactored out into an RT::Model::ACECollectionedObject or something
# stuff the rights into a hash of rights that can exist.

foreach my $right ( keys %{$RIGHTS} ) {
    $RT::Model::ACE::LOWERCASERIGHTNAMES{ lc $right } = $right;
}

sub add_link {
    my $self = shift;
    my %args = (
        Target => '',
        Base   => '',
        type   => '',
        Silent => undef,
        @_
    );

    unless ( $self->current_user_has_right('ModifyQueue') ) {
        return ( 0, _("Permission Denied") );
    }

    return $self->SUPER::_add_link(%args);
}

sub delete_link {
    my $self = shift;
    my %args = (
        Base   => undef,
        Target => undef,
        type   => undef,
        @_
    );

    #check acls
    unless ( $self->current_user_has_right('ModifyQueue') ) {
        Jifty->log->debug("No permission to delete links\n");
        return ( 0, _('Permission Denied') );
    }

    return $self->SUPER::_delete_link(%args);
}

=head2 available_rights

Returns a hash of available rights for this object. The keys are the right names and the values are a description of what the rights do

=cut

sub available_rights {
    my $self = shift;
    return ($RIGHTS);
}

# {{{ active_status_array

=head2 active_status_array

Returns an array of all ActiveStatuses for this queue

=cut

sub active_status_array {
    my $self = shift;
    if ( RT->config->get('ActiveStatus') ) {
        return ( RT->config->get('ActiveStatus') );
    } else {
        Jifty->log->warn(
            "RT::ActiveStatus undefined, falling back to deprecated defaults"
        );
        return (@DEFAULT_ACTIVE_STATUS);
    }
}

# }}}

# {{{ inactive_status_array

=head2 inactive_status_array

Returns an array of all InactiveStatuses for this queue

=cut

sub inactive_status_array {
    my $self = shift;
    if ( RT->config->get('InactiveStatus') ) {
        return ( RT->config->get('InactiveStatus') );
    } else {
        Jifty->log->warn(
            "RT::InactiveStatus undefined, falling back to deprecated defaults"
        );
        return (@DEFAULT_INACTIVE_STATUS);
    }
}

# }}}

# {{{ StatusArray

=head2 status_array

Returns an array of all statuses for this queue

=cut

sub status_array {
    my $self = shift;
    return ( $self->active_status_array(), $self->inactive_status_array() );
}

# }}}

# {{{ is_valid_status

=head2 is_valid_status value

Returns true if value is a valid status.  Otherwise, returns 0.


=cut

sub is_valid_status {
    my $self  = shift;
    my $value = shift;

    my $retval = grep ( $_ eq $value, $self->status_array );
    return ($retval);

}

# }}}

# {{{ is_active_status

=head2 is_active_status value

Returns true if value is a Active status.  Otherwise, returns 0


=cut

sub is_active_status {
    my $self  = shift;
    my $value = shift;

    my $retval = grep ( $_ eq $value, $self->active_status_array );
    return ($retval);

}

# }}}

# {{{ is_inactive_status

=head2 is_inactive_status value

Returns true if value is a Inactive status.  Otherwise, returns 0


=cut

sub is_inactive_status {
    my $self  = shift;
    my $value = shift;

    my $retval = grep ( $_ eq $value, $self->inactive_status_array );
    return ($retval);

}

# }}}

# {{{ sub create

=head2 Create(ARGS)

Arguments: ARGS is a hash of named parameters.  Valid parameters are:

  name (required)
  description
  correspond_address
  comment_address
  initial_priority
  final_priority
  default_due_in
 
If you pass the ACL check, it creates the queue and returns its queue id.


=cut

sub create {
    my $self = shift;
    my %args = (
        name               => undef,
        correspond_address => '',
        description        => '',
        comment_address    => '',
        initial_priority   => 0,
        final_priority     => 0,
        default_due_in       => 0,
        Sign               => undef,
        Encrypt            => undef,
        @_
    );

    unless (
        $self->current_user->has_right(
            Right  => 'AdminQueue',
            Object => RT->system
        )
        )
    {    #Check them ACLs
        return ( 0, _("No permission to create queues") );
    }

    unless ( $self->validate_name( $args{'name'} ) ) {
        return ( 0, _('Queue already exists') );
    }

    my %attrs = map { $_ => 1 } $self->readable_attributes;

    #TODO better input validation
    Jifty->handle->begin_transaction();
    my $id
        = $self->SUPER::create( map { $_ => $args{$_} } grep exists $args{$_},
        keys %attrs );
    unless ($id) {
        Jifty->handle->rollback();
        return ( 0, _('Queue could not be Created') );
    }

    my $create_ret = $self->create_queue_groups();
    unless ($create_ret) {
        Jifty->handle->rollback();
        return ( 0, _('Queue could not be Created') );
    }
    Jifty->handle->commit;

    if ( defined $args{'Sign'} ) {
        my ( $status, $msg ) = $self->set_sign( $args{'Sign'} );
        Jifty->log->error("Couldn't set attribute 'Sign': $msg")
            unless $status;
    }
    if ( defined $args{'Encrypt'} ) {
        my ( $status, $msg ) = $self->set_encrypt( $args{'Encrypt'} );
        Jifty->log->error("Couldn't set attribute 'Encrypt': $msg")
            unless $status;
    }

    return ( $id, _("Queue Created") );
}

# }}}

# {{{ sub delete

sub delete {
    my $self = shift;
    return ( 0, _('Deleting this object would break referential integrity') );
}

# }}}

# {{{ sub set_disabled

=head2 Setdisabled

Takes a boolean.
1 will cause this queue to no longer be available for tickets.
0 will re-enable this queue.

=cut

# }}}

# {{{ sub load

=head2 Load

Takes either a numerical id or a textual name and loads the specified queue.

=cut

sub load {
    my $self       = shift;
    my $identifier = shift;
    if ( !$identifier ) {
        return (undef);
    }

    if ( $identifier =~ /^(\d+)$/ ) {
        $self->load_by_cols( id => $identifier );
    } else {
        $self->load_by_cols( name => $identifier );
    }

    return ( $self->id );

}

# }}}

# {{{ sub validate_name

=head2 Validatename name

Takes a queue name. Returns true if it's an ok name for
a new queue. Returns undef if there's already a queue by that name.

=cut

sub validate_name {
    my $self = shift;
    my $name = shift;

    my $tempqueue = RT::Model::Queue->new( current_user => RT->system_user );
    $tempqueue->load($name);

    #If this queue exists, return undef
    if ( $tempqueue->name() && $tempqueue->id != $self->id ) {
        return (undef);
    }

    #If the queue doesn't exist, return 1
    else {
        return ( $self->SUPER::validate_name($name) );
    }

}

# }}}

=head2 set_sign

=cut

sub sign {
    my $self  = shift;
    my $value = shift;

    return undef unless $self->current_user_has_right('SeeQueue');
    my $attr = $self->first_attribute('Sign') or return 0;
    return $attr->content;
}

sub set_sign {
    my $self  = shift;
    my $value = shift;

    return ( 0, _('Permission Denied') )
        unless $self->current_user_has_right('AdminQueue');

    my ( $status, $msg ) = $self->set_attribute(
        name        => 'Sign',
        description => 'Sign outgoing messages by default',
        content     => $value,
    );
    return ( $status, $msg ) unless $status;
    return ( $status, _('Signing enabled') ) if $value;
    return ( $status, _('Signing disabled') );
}

sub encrypt {
    my $self  = shift;
    my $value = shift;

    return undef unless $self->current_user_has_right('SeeQueue');
    my $attr = $self->first_attribute('Encrypt') or return 0;
    return $attr->content;
}

sub set_encrypt {
    my $self  = shift;
    my $value = shift;

    return ( 0, _('Permission Denied') )
        unless $self->current_user_has_right('AdminQueue');

    my ( $status, $msg ) = $self->set_attribute(
        name        => 'Encrypt',
        description => 'Encrypt outgoing messages by default',
        content     => $value,
    );
    return ( $status, $msg ) unless $status;
    return ( $status, _('Encrypting enabled') ) if $value;
    return ( $status, _('Encrypting disabled') );
}

# {{{ sub Templates

=head2 Templates

Returns an RT::Model::TemplateCollection object of all of this queue's templates.

=cut

sub templates {
    my $self = shift;

    my $templates = RT::Model::TemplateCollection->new;

    if ( $self->current_user_has_right('ShowTemplate') ) {
        $templates->limit_to_queue( $self->id );
    }

    return ($templates);
}

# }}}

# {{{ Dealing with custom fields

# {{{  CustomField

=head2 CustomField name

Load the queue-specific custom field named name

=cut

sub custom_field {
    my $self = shift;
    my $name = shift;
    my $cf   = RT::Model::CustomField->new;
    $cf->load_by_name_and_queue( name => $name, Queue => $self->id );
    return ($cf);
}

# {{{ ticket_custom_fields

=head2 ticket_custom_fields

Returns an L<RT::Model::CustomFieldCollection> object containing all global and
queue-specific B<ticket> custom fields.

=cut

sub ticket_custom_fields {
    my $self = shift;

    my $cfs = RT::Model::CustomFieldCollection->new;
    if ( $self->current_user_has_right('SeeQueue') ) {
        $cfs->limit_to_global_orobject_id( $self->id );
        $cfs->limit_to_lookup_type('RT::Model::Queue-RT::Model::Ticket');
    }
    return ($cfs);
}

# }}}

# {{{ TicketTransactionCustomFields

=head2 TicketTransactionCustomFields

Returns an L<RT::Model::CustomFieldCollection> object containing all global and
queue-specific B<transaction> custom fields.

=cut

sub ticket_transaction_custom_fields {
    my $self = shift;

    my $cfs = RT::Model::CustomFieldCollection->new;
    if ( $self->current_user_has_right('SeeQueue') ) {
        $cfs->limit_to_global_orobject_id( $self->id );
        $cfs->limit_to_lookup_type(
            'RT::Model::Queue-RT::Model::Ticket-RT::Model::Transaction');
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

sub create_queue_groups {
    my $self = shift;

    my @types = qw(Cc AdminCc Requestor Owner);

    foreach my $type (@types) {
        my $type_obj = RT::Model::Group->new;
        my ( $id, $msg ) = $type_obj->create_role_group(
            instance => $self->id,
            type     => $type,
            domain   => 'RT::Model::Queue-Role'
        );
        unless ($id) {
            Jifty->log->error(
                "Couldn't create a Queue group of type '$type' for ticket "
                    . $self->id . ": "
                    . $msg );
            return (undef);
        }
    }
    return (1);

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

sub add_watcher {
    my $self = shift;
    my %args = (
        type         => undef,
        principal_id => undef,
        Email        => undef,
        @_
    );

    # {{{ Check ACLS
    #If the watcher we're trying to add is for the current user
    if ( defined $args{'principal_id'}
        && $self->current_user->id eq $args{'principal_id'} )
    {

        #  If it's an AdminCc and they don't have
        #   'WatchAsAdminCc' or 'ModifyTicket', bail
        if ( defined $args{'type'} && ( $args{'type'} eq 'AdminCc' ) ) {
            unless ( $self->current_user_has_right('ModifyQueueWatchers')
                or $self->current_user_has_right('WatchAsAdminCc') )
            {
                return ( 0, _('Permission Denied') );
            }
        }

        #  If it's a Requestor or Cc and they don't have
        #   'Watch' or 'ModifyTicket', bail
        elsif (( $args{'type'} eq 'Cc' )
            or ( $args{'type'} eq 'Requestor' ) )
        {

            unless ( $self->current_user_has_right('ModifyQueueWatchers')
                or $self->current_user_has_right('Watch') )
            {
                return ( 0, _('Permission Denied') );
            }
        } else {
            Jifty->log->warn("$self -> AddWatcher got passed a bogus type");
            return ( 0, _('Error in parameters to Queue->add_watcher') );
        }
    }

    # If the watcher isn't the current user
    # and the current user  doesn't have 'ModifyQueueWatcher'
    # bail
    else {
        unless ( $self->current_user_has_right('ModifyQueueWatchers') ) {
            return ( 0, _("Permission Denied") );
        }
    }

    # }}}

    return ( $self->_add_watcher(%args) );
}

#This contains the meat of AddWatcher. but can be called from a routine like
# Create, which doesn't need the additional acl check
sub _add_watcher {
    my $self = shift;
    my %args = (
        type         => undef,
        Silent       => undef,
        principal_id => undef,
        Email        => undef,
        @_
    );

    my $principal = RT::Model::Principal->new;
    if ( $args{'principal_id'} ) {
        $principal->load( $args{'principal_id'} );
    } elsif ( $args{'Email'} ) {

        my $user = RT::Model::User->new;
        $user->load_by_email( $args{'Email'} );

        unless ( $user->id ) {
            $user->load( $args{'Email'} );
        }
        if ( $user->id ) {    # If the user exists
            $principal->load( $user->principal_id );
        } else {

            # if the user doesn't exist, we need to create a new user
            my $new_user
                = RT::Model::User->new( current_user => RT->system_user );

            my ( $Address, $name )
                = RT::Interface::Email::parse_address_from_header(
                $args{'Email'} );

            my ( $Val, $Message ) = $new_user->create(
                name       => $Address,
                email      => $Address,
                real_name  => $name,
                privileged => 0,
                comments   => 'AutoCreated when added as a watcher'
            );
            unless ($Val) {
                Jifty->log->error( "Failed to create user "
                        . $args{'Email'} . ": "
                        . $Message );

               # Deal with the race condition of two account creations at once
                $new_user->load_by_email( $args{'Email'} );
            }
            $principal->load( $new_user->principal_id );
        }
    }

    # If we can't find this watcher, we need to bail.
    unless ( $principal->id ) {
        return ( 0, _("Could not find or create that user") );
    }

    my $group = RT::Model::Group->new;
    $group->load_queue_role_group(
        type  => $args{'type'},
        queue => $self->id
    );
    unless ( $group->id ) {
        return ( 0, _("Group not found") );
    }

    if ( $group->has_member($principal) ) {

        return (
            0,
            _(  'That principal is already a %1 for this queue',
                $args{'type'}
            )
        );
    }

    my ( $m_id, $m_msg )
        = $group->_add_member( principal_id => $principal->id );
    unless ($m_id) {
        Jifty->log->error( "Failed to add "
                . $principal->id
                . " as a member of group "
                . $group->id . "\n"
                . $m_msg );

        return (
            0,
            _(  'Could not make that principal a %1 for this queue',
                $args{'type'}
            )
        );
    }
    return ( 1,
        _( 'Added principal as a %1 for this queue', $args{'type'} ) );
}

# }}}

# {{{ sub delete_watcher

=head2 DeleteWatcher { type => TYPE, principal_id => PRINCIPAL_ID }


Deletes a queue  watcher.  Takes two arguments:

Type  (one of Requestor,Cc,AdminCc)

and one of

principal_id (an RT::Model::Principal id of the watcher you want to remove)
    OR
Email (the email address of an existing wathcer)


=cut

sub delete_watcher {
    my $self = shift;

    my %args = (
        type         => undef,
        principal_id => undef,
        @_
    );

    unless ( $args{'principal_id'} ) {
        return ( 0, _("No principal specified") );
    }
    my $principal = RT::Model::Principal->new;
    $principal->load( $args{'principal_id'} );

    # If we can't find this watcher, we need to bail.
    unless ( $principal->id ) {
        return ( 0, _("Could not find that principal") );
    }

    my $group = RT::Model::Group->new;
    $group->load_queue_role_group(
        type  => $args{'type'},
        queue => $self->id
    );
    unless ( $group->id ) {
        return ( 0, _("Group not found") );
    }

    # {{{ Check ACLS
    #If the watcher we're trying to add is for the current user
    if ( $self->current_user->id eq $args{'principal_id'} ) {

        #  If it's an AdminCc and they don't have
        #   'WatchAsAdminCc' or 'ModifyQueue', bail
        if ( $args{'type'} eq 'AdminCc' ) {
            unless ( $self->current_user_has_right('ModifyQueueWatchers')
                or $self->current_user_has_right('WatchAsAdminCc') )
            {
                return ( 0, _('Permission Denied') );
            }
        }

        #  If it's a Requestor or Cc and they don't have
        #   'Watch' or 'ModifyQueue', bail
        elsif (( $args{'type'} eq 'Cc' )
            or ( $args{'type'} eq 'Requestor' ) )
        {
            unless ( $self->current_user_has_right('ModifyQueueWatchers')
                or $self->current_user_has_right('Watch') )
            {
                return ( 0, _('Permission Denied') );
            }
        } else {
            Jifty->log->warn(
                "$self -> DeleteWatcher got passed a bogus type");
            return ( 0, _('Error in parameters to Queue->delete_watcher') );
        }
    }

    # If the watcher isn't the current user
    # and the current user  doesn't have 'ModifyQueueWathcers' bail
    else {
        unless ( $self->current_user_has_right('ModifyQueueWatchers') ) {
            return ( 0, _("Permission Denied") );
        }
    }

    # }}}

    # see if this user is already a watcher.

    unless ( $group->has_member($principal) ) {
        return ( 0,
            _( 'That principal is not a %1 for this queue', $args{'type'} ) );
    }

    my ( $m_id, $m_msg ) = $group->_delete_member( $principal->id );
    unless ($m_id) {
        Jifty->log->error( "Failed to delete "
                . $principal->id
                . " as a member of group "
                . $group->id . "\n"
                . $m_msg );

        return (
            0,
            _(  'Could not remove that principal as a %1 for this queue',
                $args{'type'}
            )
        );
    }

    return (
        1,
        _(  "%1 is no longer a %2 for this queue.",
            $principal->object->name,
            $args{'type'}
        )
    );
}

# }}}

# {{{ admin_cc_addresses

=head2 admin_cc_addresses

returns String: All queue AdminCc email addresses as a string

=cut

sub admin_cc_addresses {
    my $self = shift;

    unless ( $self->current_user_has_right('SeeQueue') ) {
        return undef;
    }

    return ( $self->admin_cc->member_emails_as_string )

}

# }}}

# {{{ CcAddresses

=head2 CcAddresses

returns String: All queue Ccs as a string of email addresses

=cut

sub cc_addresses {
    my $self = shift;

    unless ( $self->current_user_has_right('SeeQueue') ) {
        return undef;
    }

    return ( $self->cc->member_emails_as_string );

}

# }}}

# {{{ sub Cc

=head2 Cc

Takes nothing.
Returns an RT::Model::Group object which contains this Queue's Ccs.
If the user doesn't have "ShowQueue" permission, returns an empty group

=cut

sub cc {
    my $self = shift;

    my $group = RT::Model::Group->new;
    if ( $self->current_user_has_right('SeeQueue') ) {
        $group->load_queue_role_group( type => 'Cc', queue => $self->id );
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

sub admin_cc {
    my $self = shift;

    my $group = RT::Model::Group->new;
    if ( $self->current_user_has_right('SeeQueue') ) {
        $group->load_queue_role_group(
            type  => 'AdminCc',
            queue => $self->id
        );
    }
    return ($group);

}

# }}}

# {{{ IsWatcher, IsCc, is_admin_cc

# {{{ sub IsWatcher
# a generic routine to be called by IsRequestor, IsCc and is_admin_cc

=head2 IsWatcher { type => TYPE, principal_id => PRINCIPAL_ID }

Takes a param hash with the attributes type and principal_id

Type is one of Requestor, Cc, AdminCc and Owner

principal_id is an RT::Model::Principal id 

Returns true if that principal is a member of the group type for this queue


=cut

sub is_watcher {
    my $self = shift;

    my %args = (
        type         => 'Cc',
        principal_id => undef,
        @_
    );

    # Load the relevant group.
    my $group = RT::Model::Group->new;
    $group->load_queue_role_group(
        type  => $args{'type'},
        queue => $self->id
    );

    # Ask if it has the member in question

    my $principal = RT::Model::Principal->new;
    $principal->load( $args{'principal_id'} );
    unless ( $principal->id ) {
        return (undef);
    }

    return ( $group->has_member_recursively($principal) );
}

# }}}

# {{{ sub IsCc

=head2 IsCc PRINCIPAL_ID

Takes an RT::Model::Principal id.
Returns true if the principal is a requestor of the current queue.


=cut

sub is_cc {
    my $self = shift;
    my $cc   = shift;

    return ( $self->is_watcher( type => 'Cc', principal_id => $cc ) );

}

# }}}

# {{{ sub is_admin_cc

=head2 is_admin_cc PRINCIPAL_ID

Takes an RT::Model::Principal id.
Returns true if the principal is a requestor of the current queue.

=cut

sub is_admin_cc {
    my $self   = shift;
    my $person = shift;

    return (
        $self->is_watcher( type => 'AdminCc', principal_id => $person ) );

}

# }}}

# }}}

# }}}

# {{{ ACCESS CONTROL

# {{{ sub _set
sub _set {
    my $self = shift;

    unless ( $self->current_user_has_right('AdminQueue') ) {
        return ( 0, _('Permission Denied') );
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
    unless ($principal) {
        Jifty->log->error("Principal undefined in Queue::has_right");
        return undef;
    }

    return $principal->has_right( %args,
        Object => ( $self->id ? $self : RT->system ), );
}

# }}}

# }}}

1;
