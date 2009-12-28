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

package RT::View::Admin::Groups;
use Jifty::View::Declare -base;
use base 'RT::View::CRUD';

use constant page_title     => 'Group Management';
use constant object_type    => 'Group';

use constant display_columns => qw(id name description);

sub _current_collection {
    my $self = shift;
    my $c    = $self->SUPER::_current_collection();
    $c->limit_to_user_defined_groups();
    return $c;
}

template 'select_custom_fields' =>
page { title => _('Select Custom Fields for Group') } content {
    my $self  = shift;
    my $group = RT::Model::Group->new;
    $group->load( get('id') );
    my $moniker = 'group_select_cfs',
    my $action = new_action(
        class   => 'SelectCustomFields',
    );

    $action->record($group);
    $action->lookup_type( $group->custom_field_lookup_type );

    with( name => $moniker ), form {
        render_action($action);
        form_submit( label => _('Save') );
    };
};

template 'members' => page { title => _('Group Members') } content {
    my $self  = shift;
    my $group = RT::Model::Group->new;
    $group->load( get('id') );
    my $moniker = 'group_edit_members';
    my $action = new_action(
        class   => 'EditGroupMembers',
        moniker => $moniker,
    );

    $action->record($group);

    with( name => $moniker ), form {
        render_action($action);
        form_submit( label => _('Save') );
    };

};

template 'history' => page { title => _('Group History') } content {
    my $self = shift;
    my $group = RT::Model::Group->new;
    $group->load(get('id'));
    my $txns = $group->transactions;
    $txns->order_by(
        {
            column => 'Created',
            order  => 'ASC',
        },
        {
            column => 'id',
            order  => 'ASC',
        },
    );
    my $row_num = 1;
    div {
        attr { id => 'ticket-history' };
        while ( my $txn = $txns->next ) {
            div {
                attr { class => $row_num++ % 2 ? 'odd' : 'even' };
                div {
                    attr { class => 'metadata' }
                      span { attr { class => 'date' }; $txn->created };
                    span {
                        attr { class => 'description' };
                        $txn->creator->name . ' - ' . $txn->brief_description;
                    };
                };
            };
        }
    };

    # removed txn attachments and txn cfs that were here in mason pages

};

template 'group_rights' => page { title => _('Group Rights for Group') }
content {
    my $self = shift;
    show( 'rights', 'group' );

};

template 'user_rights' => page { title => _('User Rights for Group') } content {
    my $self = shift;
    show( 'rights', 'user' );

};

private template 'rights' => sub {
    my $self = shift;
    my $type = shift || 'user';

    my $class   = 'Edit' . ucfirst($type) . 'Rights';
    my $moniker = 'group_edit_' . $type . '_rights';

    my $rights = new_action(
        class   => $class,
        moniker => $moniker,
    );

    my $group = RT::Model::Group->new;
    $group->load(get('id'));
    $rights->record( $group );

    with( name => $moniker ), form {
        render_action($rights);
        form_submit( label => _('Save') );
    };
};


1;

