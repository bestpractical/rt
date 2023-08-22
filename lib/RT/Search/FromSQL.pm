# BEGIN BPS TAGGED BLOCK {{{
#
# COPYRIGHT:
#
# This software is Copyright (c) 1996-2022 Best Practical Solutions, LLC
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

=head1 NAME

RT::Search::FromSQL

=head1 SYNOPSIS

    rt-crontool --search RT::Search::FromSQL \
        --search-arg "Owner = 'root'" \
        --action RT::Action \
        --verbose \
        --log debug

=head1 DESCRIPTION

The FromSQL search performs a ticket search using the same
mechanism as the RT Query Builder.

It expects one Argument which is a TicketSQL string. Since the
search is the same as the RT Query Builder, you can paste in
a search directly from the Advanced tab. The search is then
performed on the L<RT::Tickets> object associated with the running
search.

When running with a command-line utility such as
rt-crontool, you may need to apply shell escapes or make
other format changes to correctly pass special characters
through the shell.

=head1 METHODS

=cut

package RT::Search::FromSQL;

use strict;
use warnings;
use base qw(RT::Search);

=head2 Describe

Returns a localized string describing the module's function.

=cut

sub Describe  {
    my $self = shift;
    return ($self->loc("TicketSQL search module", ref $self));
}

=head2 Prepare

Runs a search on the associated L<RT::Tickets> object, using
the TicketSQL string provided in the Argument.

The search is performed in the context of the user running the
command. For rt-crontool searches, this is the L<RT::User> account
associated with the Linux account running rt-crontool via the
"Unix login" setting.

=cut

sub Prepare  {
    my $self = shift;

    $self->TicketsObj->FromSQL($self->Argument);
    return(1);
}

RT::Base->_ImportOverlays();

1;
