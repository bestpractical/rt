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

package RT::View::Admin::Users;
use Jifty::View::Declare -base;
use base 'RT::View::CRUD';

use constant page_title      => 'User Management';
use constant object_type     => 'User';
use constant display_columns => qw(id name real_name email);

use constant edit_columns => qw(name email real_name nickname gecos lang
  freeform_contact_info
  organization address1 address2 city state zip country
  home_phone work_phone mobile_phone pager_phone
  password comments signature );

# unused columns:
#  email_encoding web_encoding external_contact_info_id
#  contact_info_system external_auth_id auth_system 
#  time_zone

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

# limit to privileged users
sub _current_collection {
    my $self = shift;
    my $collection = $self->SUPER::_current_collection(@_);
    $collection->limit_to_privileged;
    return $collection;
}

# XXX TODO 
# the following pages don't valid $id, we should/can check that in Dispatcher

template 'select_custom_fields' => page { title => _('Select Custom Fields for User') } content {
    my $self = shift;
    my $user = RT::Model::User->new;
    $user->load( get('id') );
    my $action = new_action(
        class   => 'SelectCustomFields',
        moniker => 'select_cfs',
    );

    $action->object($user);
    $action->lookup_type($user->custom_field_lookup_type);

    with( name => 'select_cfs' ), form {
        input {
            type is 'hidden';
            name is 'id';
            value is get('id');
        };
        render_action($action);
        form_submit( label => _('Save') );
    };
};

template 'memberships' => page { title => _('User Memberships') } content {
    my $self = shift;
    my $user = RT::Model::User->new;
    $user->load( get('id') );
    my $moniker = 'modify_user_memberships';
    my $action = new_action(
        class   => 'EditUserMemberships',
        moniker => $moniker,
    );

    $action->object($user);

    with( name => $moniker ), form {
        input {
            type is 'hidden';
            name is 'id';
            value is get('id');
        };
        render_action($action);
        form_submit( label => _('Save') );
    };
};

template 'gnupg' => page { title => _('User GnuPG') } content {
    my $self = shift;

    # TODO move the following line to Dispatcher
    return unless RT->config->get('gnupg')->{'enable'};

    require RT::Crypt::GnuPG;

    my $user = RT::Model::User->new;
    $user->load(get('id'));

    unless ( $user->email ) {
        h2 { _("User has empty email address") };
        return;
    }

    my %res = RT::Crypt::GnuPG::get_key_info( $user->email, 'public' );

    if ( $res{'exit_code'} || !keys %{ $res{'info'} } ) {
        outs( _('No keys for this address') );
    }
    else {
        h3 { _('GnuPG public key for %1', $user->email) };
        table {
            row {
                th { _( 'Trust' . ':' ) };
                cell {
                    _( $res{'info'}{'trust'} );
                };
            };
            row {
                th { _( 'Created' . ':' ) };
                cell {
                    $res{'info'}{'created'}
                      ? $res{'info'}{'created'}->date
                      : _('never');
                };
            };

            row {
                th { _('Expire') . ':' };
                cell {
                    $res{'info'}{'expire'}
                      ? $res{'info'}{'expire'}->date
                      : _('never');
                };
            };

            for my $uinfo ( @{ $res{'info'}{'user'} } ) {
                row {
                    th { _('User (Created - expire)') . ':' };
                    cell {
                        $uinfo->{'string'}
                          . '(' . (
                            $uinfo->{'created'} ? $uinfo->{'created'}->date
                            : _('never') . ' - ' 
                          )
                          . (
                            $uinfo->{'expire'} ? $uinfo->{'expire'}->date
                            : _('never')
                          ) . ')';
                    };
                };
            }
        };
    }

    my %keys_meta =
      RT::Crypt::GnuPG::get_keys_for_signing( $user->email, 'force' );

    my $moniker = 'select_private_key';
    my $action = new_action(
        class   => 'SelectPrivateKey',
        moniker => $moniker,
    );

    $action->object($user);

    with( name => $moniker ), form {
        input {
            type is 'hidden';
            name is 'id';
            value is get('id');
        };
        render_action($action);
        form_submit( label => _('Save') );
    };

};

template 'history' => page { title => _('User History') } content {
    my $self = shift;
    my $user = RT::Model::User->new;
    $user->load(get('id'));
    my $txns = $user->transactions;
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

template 'my_rt' => page { title => _('MyRT for User') } content {
    my $self = shift;
    my $moniker = 'config_my_rt';
    my $action = new_action(
        class   => 'ConfigMyRT',
        moniker => $moniker,
    );

    my $user = RT::Model::User->new;
    $user->load(get('id'));
    $action->object( $user );

    with( name => $moniker ), form {
        input {
            type is 'hidden';
            name is 'id';
            value is get('id');
        };
        render_action($action);
        form_submit( label => _('Save') );
    };

};

1;

