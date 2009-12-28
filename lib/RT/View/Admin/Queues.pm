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
use warnings;
use strict;

package RT::View::Admin::Queues;
use Jifty::View::Declare -base;
use RT::View::Helpers qw/show_key_info/;
use base 'RT::View::CRUD';

require RT::View::Admin::Queues::Templates;
alias RT::View::Admin::Queues::Templates under 'templates/';

use constant page_title      => 'Queue Management';
use constant object_type     => 'Queue';

use constant display_columns => qw(id name description correspond_address
        comment_address status_schema 
        initial_priority final_priority default_due_in disabled);

sub view_field_status_schema {
    my $self = shift;
    my %args = @_;
    my $action = $args{action};
    return $action->record->status_schema->name;
}

template 'index.html' => page {
    title => shift->page_title,
} content {
    my $self = shift;

    form {
        render_region(
            name     => $self->object_type.'-list',
            path     => $self->fragment_base_path.'/list',
        );
    }

    my $include_disabled = get('include_disabled');
    hyperlink(
        label => _(
            ( $include_disabled ? 'Exclude' : 'Include' )
            . ' disabled queues in listing.'
        ),
        url => '/admin/queues',
        $include_disabled
        ? ()
        : ( parameters => { include_disabled => 1, } ),
    );
};

private template 'rights' => sub {
    my $self = shift;
    my $type = shift || 'user';

    my $queue = $self->queue;
    my $class   = 'Edit' . ucfirst($type) . 'Rights';
    my $moniker = 'modify_' . $type . '_rights';

    my $rights = new_action(
        class   => $class,
        moniker => $moniker,
    );

    $rights->object($queue);

    with ( name => $moniker ), form {
        input { type is 'hidden'; name is 'id'; value is $queue->id };
        render_action($rights);
        form_submit( label => _('Save') );
    };
};

template 'user_rights' => page { title => _('Modify User Rights') } content {
    show( 'rights', 'user' );
};

template 'group_rights' => page { title => _('Modify Group Rights') } content {
    show( 'rights', 'group' );
};

template 'people' => page { title => _('Modify People') } content {
    my $self = shift;
    my $queue = $self->queue;
    return unless $queue;

    my $action = new_action(
        class   => 'EditWatchers',
        moniker => 'modify_people',
    );

    $action->object($queue);

    with ( name => 'modify_people' ), form {
        input { type is 'hidden'; name is 'id'; value is $queue->id };
        render_action($action);
        form_submit( label => _('Save') );
    };
};

template 'select_custom_fields' => page { title => _('Select CustomFields') } content {
    my $self  = shift;
    my $queue = $self->queue;
    return unless $queue;

    my $action = new_action(
        class   => 'SelectCustomFields',
        moniker => 'select_cfs',
    );

    $action->object($queue);
    # set it to RT::Model::Queue-RT::Model::Ticket-RT::Model::Transaction
    # to select transaction cfs

    my $lookup_type = get('lookup_type')
      || 'RT::Model::Queue-RT::Model::Ticket';
    $action->lookup_type($lookup_type);

    with( name => 'select_cfs' ), form {
        input { type is 'hidden'; name is 'id'; value is $queue->id };
        input { type is 'hidden'; name is 'lookup_type'; value is $lookup_type };
        render_action($action);
        form_submit( label => _('Save') );
    };
};

sub _current_collection {
    my $self = shift; 
    my $collection = $self->SUPER::_current_collection( @_ );
    $collection->{'find_disabled_rows'} = get('include_disabled');
    return $collection;    
}

sub queue {
    my $self = shift;
    my $id = get('id');
    unless ( $id ) {
        Jifty->log->fatal( "need queue id parameter" );
        return;
    }

    my $queue = RT::Model::Queue->new;
    my ( $ret, $msg ) = $queue->load( $id );
    unless ( $ret ) {
        Jifty->log->fatal( "failed to load queue $id: $msg" );
        return;
    }
    return $queue;
}

template 'gnupg' => page { title => _('Queue GnuPG') } content {
    my $self = shift;

    # TODO move the following line to Dispatcher
    return unless RT->config->get('gnupg')->{'enable'};

    require RT::Crypt::GnuPG;

    my $queue = RT::Model::Queue->new;
    $queue->load(get('id'));

    my $moniker = 'modify_queue_gnupg';
    my $action = new_action(
        class   => 'EditQueueGnuPG',
        moniker => $moniker,
    );
    $action->queue($queue);

    with( name => $moniker ), form {
        input {
            type is 'hidden';
            name is 'id';
            value is get('id');
        };
        render_action($action);
        form_submit( label => _('Save') );
    };

    if ( $queue->correspond_address ) {
        show_key_info( $queue->correspond_address, 'private' );
    }

    if ( $queue->comment_address ) {
        show_key_info( $queue->comment_address, 'private' );
    }


};


1;

