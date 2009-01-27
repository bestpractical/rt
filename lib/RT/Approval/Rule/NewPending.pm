# BEGIN BPS TAGGED BLOCK {{{
# 
# COPYRIGHT:
# 
# This software is Copyright (c) 1996-2009 Best Practical Solutions, LLC
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

package RT::Approval::Rule::NewPending;
use strict;
use warnings;
use base 'RT::Approval::Rule';

use constant Description => "When an approval ticket is created, notify the Owner and AdminCc of the item awaiting their approval"; # loc

sub prepare {
    my $self = shift;
    return unless $self->SUPER::prepare();

    $self->on_status_change('open') and
    eval { $T::Approving = ($self->ticket_obj->all_depended_on_by( type => 'ticket' ))[0] }
}

sub commit {
    my $self = shift;
    my ($top) = $self->ticket_obj->all_depended_on_by( type => 'ticket' );
    my $t = $self->ticket_obj->transactions;
    my $to;
    while ( my $o = $t->next ) {
        $to = $o, last if $o->type eq 'Create';
    }

    # XXX: this makes the owner incorrect so notify owner won't work
    # local $self->{ticket_obj} = $top;

    # first txn entry of the approval ticket
    local $self->{transaction_obj} = $to;
    $self->run_scrip_action('Notify Owner', 'New Pending Approval', @_);

    return;

    # this generates more correct content of the message, but not sure
    # if ccmessageto is the right way to do this.
    my $template = $self->get_template('New Pending Approval',
                                      ticket_obj => $top,
                                      transaction_obj => $to)
        or return;

    my ( $result, $msg ) = $template->parse(
        ticket_obj => $top,
    );
    $self->ticket_obj->comment( cc_message_to => $self->ticket_obj->owner_obj->email, mime_obj => $template->mime_obj );

}

1;
