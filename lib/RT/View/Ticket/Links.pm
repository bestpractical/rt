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

package RT::View::Ticket::Links;
use Jifty::View::Declare -base;

__PACKAGE__->use_mason_wrapper;

template '_elements/edit_links' => sub {
    my $ticket = HTML::Mason::Commands::load_ticket( get('id') );

    div { { class is 'ticket-links-current' };
        h3 { _("Current Links") };
        my $delete_links = new_action( class => 'DeleteTicketLinks', moniker => 'delete-links' );
        $delete_links->register
            unless Jifty->web->form->is_open; # don't need this if we open form{} with jifty
        render_param( $delete_links => 'id', default_value => $ticket->id, render_as => 'hidden' );

        table { tbody {

                show( '_edit_link_type', _('Depends on'), 'depends_on', $ticket->depends_on, $delete_links, 'target_uri' );

                show( '_edit_link_type', _('Depended on by'), 'depended_on_by', $ticket->depended_on_by, $delete_links, 'base_uri' );

                show( '_edit_link_type', _('parents'), 'member_of', $ticket->member_of, $delete_links, 'target_uri' );

                show( '_edit_link_type', _('children'), 'has_member', $ticket->members, $delete_links, 'base_uri' );

                show( '_edit_link_type', _('Refers to'), 'refers_to', $ticket->refers_to, $delete_links, 'target_uri' );

                show( '_edit_link_type', _('Referred to by'), 'referred_to_by', $ticket->referred_to_by, $delete_links, 'base_uri' );

                row { cell {}; cell { i { _('(Check box to delete)') } } };
        } };

    };
};

private template '_elements/_edit_link_type' => sub {
    my ($self, $label, $type, $collection, $delete_links, $link_target) = @_;
    row {
        cell { { class is 'labeltop' }; $label };
        cell { { class is 'value' };
            while ( my $link = $collection->next ) {
                Jifty::Web::Form::Field->new(
                    action    => $delete_links,
                    name      => $type,
                    render_as => 'Checkbox',
                    value     => $link_target =~ /base/
                    ? $link->base
                    : $link->target,
                    checked => 0
                )->render_widget;
                render_mason( '/Elements/ShowLink', { uri => $link->$link_target } );
                br {};
            }
        }
    };
};

template '_elements/edit_cfs' => sub {
    my ( $ticket, $queue, $cfs );
    my $id = get('id');
    if ( $id && $id ne 'new' ) {
        $ticket = HTML::Mason::Commands::load_ticket( $id );
        $cfs    = $ticket->custom_fields;
    }
    elsif ( get('queue') ) {
        my $queue = RT::Model::Queue->load( get('queue') );
        $cfs = $queue->ticket_custom_fields;
    }

    my $edit_cfs = new_action(
        class   => 'EditTicketCFs',
        moniker => 'edit-ticket-cfs'
    );
    if ($ticket) {
        render_param(
            $edit_cfs     => 'id',
            default_value => $ticket->id,
            render_as     => 'hidden',
        );
    }

    table {
        tbody {
            while ( my $cf = $cfs->next ) {
                next unless $cf->current_user_has_right('ModifyCustomField');
                row {
                    cell {
                        { class is 'labeltop' };
                        Jifty->web->out( $cf->name );
                        br {};
                        i  { $cf->friendly_type };
                        i  { $cf->type };
                    };
                    cell {
                        { class is 'value' };
                        my $values;
                        if ($ticket) {
                            $values = $ticket->custom_field_values( $cf->id );
                        }

                        if ( $cf->type =~ /text/ ) {
                            if ($values) {
                                while ( my $value = $values->next ) {
                                    Jifty::Web::Form::Field->new(
                                        action        => $edit_cfs,
                                        name          => $cf->id,
                                        render_as     => 'Textarea',
                                        default_value => $value->content,
                                    )->render_widget;
                                    br {};
                                }
                            }
                            if (
                                $cf->max_values == 0
                                || (   $values
                                    && $values->count < $cf->max_values )
                                || !$values
                              )
                            {
                                Jifty::Web::Form::Field->new(
                                    action    => $edit_cfs,
                                    name      => $cf->id,
                                    render_as => 'Textarea',
                                )->render_widget;
                                br {};
                            }
                        }
                        elsif ( $cf->type eq 'Binary' || $cf->type eq 'Image' ) {
                            if ($values) {
                                while ( my $value = $values->next ) {
                                    Jifty::Web::Form::Field->new(
                                        action => $edit_cfs,
                                        name   => 'delete_'
                                          . $cf->id . '_'
                                          . $value->id,
                                        render_as => 'Checkbox',
                                    )->render_widget;
                                    Jifty->web->out( $value->content );
                                    br {};
                                }
                            }

                            if (
                                $cf->max_values == 0
                                || (   $values
                                    && $values->count < $cf->max_values )
                                || !$values
                              )
                            {
                                Jifty::Web::Form::Field->new(
                                    action    => $edit_cfs,
                                    name      => $cf->id,
                                    render_as => 'Upload',
                                )->render_widget;
                                br {};
                            }
                        }
                        elsif ( $cf->type eq 'Freeform' ) {
                            Jifty::Web::Form::Field->new(
                                action    => $edit_cfs,
                                name      => $cf->id,
                                render_as => $cf->max_values == 1 ? 'Text'
                                : 'Textarea',
                                default_value => $values
                                ? (
                                    join "\n",
                                    map $_->content,
                                    @{ $values->items_array_ref }
                                  )
                                : '',
                            )->render_widget;
                            br {};
                        }
                        elsif ( $cf->type eq 'Select' ) {
                            Jifty::Web::Form::Field->new(
                                action        => $edit_cfs,
                                name          => $cf->id,
                                render_as     => 'Select',
                                multiple      => !$cf->single_value,
                                default_value => $values
                                ? (
                                    [
                                        map $_->content,
                                        @{ $values->items_array_ref }
                                    ]
                                  )
                                : '',
                            )->render_widget;
                            br {};
                        }
                        elsif ( $cf->type eq 'Combobox' ) {
                            Jifty::Web::Form::Field->new(
                                action         => $edit_cfs,
                                name           => $cf->id,
                                render_as      => 'Combobox',
                                default_values => $values,
                            )->render_widget;
                            br {};
                        }
                    }
                }
            }
        }
    };
};

1;

