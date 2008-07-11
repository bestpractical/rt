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
package RT::Reminders;

use base qw/RT::Base/;

our $REMINDER_QUEUE = 'General';

sub new {
    my $class = shift;
    my $self  = {};
    bless $self, $class;
    $self->current_user(@_);
    return ($self);
}

sub ticket {
    my $self = shift;
    $self->{'_ticket'} = shift if (@_);
    return ( $self->{'_ticket'} );
}

sub ticket_obj {
    my $self = shift;
    unless ( $self->{'_ticketobj'} ) {
        $self->{'_ticketobj'} = RT::Model::Ticket->new;
        $self->{'_ticketobj'}->load( $self->ticket );
    }
    return $self->{'_ticketobj'};
}

=head2 collection

Returns an RT::Model::TicketCollection object containing reminders for this object's "Ticket"

=cut

sub collection {
    my $self = shift;
    my $col  = RT::Model::TicketCollection->new;

    my $query = 'type = "reminder" AND RefersTo = "' . $self->ticket . '"';

    $col->from_sql($query);

    return ($col);
}

=head2 add

Add a reminder for this ticket.

Takes

    subject
    Owner
    Due


=cut

sub add {
    my $self = shift;
    my %args = (
        subject => undef,
        owner   => undef,
        due     => undef,
        @_
    );

    my $reminder = RT::Model::Ticket->new;
    $reminder->create(
        subject  => $args{'subject'},
        owner    => $args{'Owner'},
        due      => $args{'Due'},
        RefersTo => $self->ticket,
        type     => 'reminder',
        queue    => $self->ticket_obj->queue,

    );
    $self->ticket_obj->_new_transaction(
        type      => 'AddReminder',
        field     => 'RT::Model::Ticket',
        new_value => $reminder->id
    );

}

sub open {
    my $self     = shift;
    my $reminder = shift;

    $reminder->set_status('open');
    $self->ticket_obj->_new_transaction(
        type      => 'OpenReminder',
        field     => 'RT::Model::Ticket',
        new_value => $reminder->id
    );
}

sub resolve {
    my $self     = shift;
    my $reminder = shift;
    $reminder->set_status('resolved');
    $self->ticket_obj->_new_transaction(
        type      => 'ResolveReminder',
        field     => 'RT::Model::Ticket',
        new_value => $reminder->id
    );
}

eval "require RT::Reminders_Vendor";
if ( $@ && $@ !~ qr{^Can't locate RT/Reminders_Vendor.pm} ) {
    die $@;
}

eval "require RT::Reminders_Local";
if ( $@ && $@ !~ qr{^Can't locate RT/Reminders_Local.pm} ) {
    die $@;
}

1;
