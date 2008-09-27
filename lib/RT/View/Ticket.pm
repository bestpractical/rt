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

package RT::View::Ticket;
use Jifty::View::Declare -base;

__PACKAGE__->use_mason_wrapper;

template '_elements/edit_links' => sub {
    my $ticket = HTML::Mason::Commands::load_ticket( get('id') );

    div { { class is 'ticket-links-current' };
        h3 { _("Current Links") };
        my $delete_links = new_action( class => 'BulkUpdateLinks' );
        $delete_links->register; # don't need this if we open form{} with jifty
        render_param( $delete_links => 'delete', default_value => 1, render_as => 'hidden' );
        input { { type is 'hidden', class is 'hidden', name is 'id', value is $ticket->id } }; # remove later.

        table { tbody {

                show( '_edit_link_type', _('Depends on'), $ticket->depends_on, $delete_links, 'target_uri' );

                show( '_edit_link_type', _('Depended on by'), $ticket->depended_on_by, $delete_links, 'base_uri' );

                show( '_edit_link_type', _('Parents'), $ticket->member_of, $delete_links, 'target_uri' );

                show( '_edit_link_type', _('Children'), $ticket->members, $delete_links, 'base_uri' );

                show( '_edit_link_type', _('Refers to'), $ticket->refers_to, $delete_links, 'target_uri' );

                show( '_edit_link_type', _('Referred to by'), $ticket->referred_to_by, $delete_links, 'base_uri' );

                row { cell {}; cell { i { _('(Check box to delete)') } } };
        } };

    };
};

private template '_elements/_edit_link_type' => sub {
    my ($self, $type, $collection, $delete_links, $link_target) = @_;
    row {
        cell { { class is 'labeltop' }; $type };
        cell { { class is 'value' };
            while (my $link = $collection->next) {
                Jifty::Web::Form::Field->new( action => $delete_links,
                                              name => 'ids',
                                              render_as => 'Checkbox',
                                              value => $link->id,
                                              checked => 0 )->render_widget;
                m_comp('/Elements/ShowLink', { uri => $link->$link_target });
                br {};
            }
        }
    };
};

sub m_comp {
    my ($template, $args)= @_;
    my $mason = Jifty->handler->view('Jifty::View::Mason::Handler');
    my $orig_out = $mason->interp->out_method || Jifty::View->can('out_method');

    my $buf = '';
    $mason->interp->out_method(\$buf);
    $mason->handle_comp($template, $args);
    $mason->interp->out_method($orig_out);

    Template::Declare->buffer->append($buf);
    return '';
}

1;
