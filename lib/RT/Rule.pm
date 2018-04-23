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

package RT::Rule;
use strict;
use warnings;

use base 'RT::Action';

use constant _Stage => 'TransactionCreate';
use constant _Queue => undef;



sub Prepare {
    my $self = shift;
    if ( $self->_Queue ) {
        my $queue = RT::Queue->new( RT->SystemUser );
        $queue->Load( $self->TicketObj->__Value('Queue') );
        if ( $queue->Name ne $self->_Queue ) {
            return (0);
        }
        return 1;
    }
}

sub Commit  {
    my $self = shift;
    return(0, $self->loc("Commit Stubbed"));
}

sub Describe {
    my $self = shift;
    return $self->loc( $self->Description );
}

sub OnStatusChange {
    my ($self, $value) = @_;

    $self->TransactionObj->Type eq 'Status' and
    $self->TransactionObj->Field eq 'Status' and
    $self->TransactionObj->NewValue eq $value
}

sub RunScripAction {
    my ($self, $scrip_action, $template, %args) = @_;
    my $ScripAction = RT::ScripAction->new($self->CurrentUser);
    $ScripAction->Load($scrip_action) or die ;

    unless (ref($template)) {
        # XXX: load per-queue template
        #    $template->LoadQueueTemplate( Queue => ..., ) || $template->LoadGlobalTemplate(...)

        my $t = RT::Template->new($self->CurrentUser);
        $t->Load($template) or die;
        $template = $t;
    }

    my $action = $ScripAction->LoadAction( TransactionObj => $self->TransactionObj,
                                           TicketObj => $self->TicketObj,
                                           TemplateObj => $template,
                                           %args,
                                       );

    $action->{'ScripObj'} = RT::Scrip->new($self->CurrentUser); # Stub. sendemail action really wants a scripobj available
    $action->Prepare or return;
    $action->Commit;

}

RT::Base->_ImportOverlays();

1;
