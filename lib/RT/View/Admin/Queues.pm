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
use base 'RT::View::CRUD';

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

private template view_item_controls  => sub {
    my $self = shift;
    my $record = shift;

    if ( $record->current_user_can('update') ) {
        hyperlink(
            label   => _("Edit"),
            class   => "editlink",
            onclick => {
                popout => $self->fragment_for('update'),
                args   => { id => $record->id },
            },
        );
    }
};

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

    my $id = get('id');
    unless ( $id ) {
        Jifty->log->fatal( "need queue id parameter" );
        return;
    }

    my $queue = RT::Model::Queue->new( current_user =>
            Jifty->web->current_user );
    my ( $ret, $msg ) = $queue->load( $id );
    unless ( $ret ) {
        Jifty->log->fatal( "failed to load queue $id: $msg" );
        return;
    }

    my $class   = 'Edit' . ucfirst($type) . 'Rights';
    my $moniker = 'modify_' . $type . '_rights';

    my $rights = new_action(
        class   => $class,
        moniker => $moniker,
    );

    $rights->object($queue);

    with ( name => $moniker ), form {
        input { type is 'hidden'; name is 'id'; value is $id };
        render_action($rights);
        form_submit( label => _('Save') );
    };
};

template 'user_rights.html' => page { title => _('Modify user rights') } content {
    show( 'rights', 'user' );
};

template 'group_rights.html' => page { title => _('Modify group rights') } content {
    show( 'rights', 'group' );
};

template 'people.html' => page { title => _('Modify people') } content {
    my $self = shift;
    my $id = get('id');
    unless ( $id ) {
        Jifty->log->fatal( "need queue id parameter" );
        return;
    }

    my $queue = RT::Model::Queue->new( current_user =>
            Jifty->web->current_user );
    my ( $ret, $msg ) = $queue->load( $id );
    unless ( $ret ) {
        Jifty->log->fatal( "failed to load queue $id: $msg" );
        return;
    }

    my $action = new_action(
        class   => 'EditWatchers',
        moniker => 'modify_people',
    );

    $action->object($queue);

    with ( name => 'modify_people' ), form {
        input { type is 'hidden'; name is 'id'; value is $id };
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

1;

