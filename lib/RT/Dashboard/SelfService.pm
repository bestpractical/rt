# BEGIN BPS TAGGED BLOCK {{{
#
# COPYRIGHT:
#
# This software is Copyright (c) 1996-2020 Best Practical Solutions, LLC
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

  RT::Dashboard::SelfService - dashboard for the Self-Service Home Page

=head1 SYNOPSIS

  See RT::Dashboard

=cut

package RT::Dashboard::SelfService;

use strict;
use warnings;

use base qw/RT::Dashboard/;

=head2 ObjectName

An object of this class is called "selfservicedashboard"

=cut

sub ObjectName { "selfservicedashboard" } # loc

=head2 PostLoadValidate

Ensure that the ID corresponds to an actual dashboard object, since it's all
attributes under the hood.

=cut

sub PostLoadValidate {
    my $self = shift;
    return (0, "Invalid object type") unless $self->{'Attribute'}->Name eq 'SelfServiceDashboard';
    return 1;
}

sub SaveAttribute {
    my $self   = shift;
    my $object = shift;
    my $args   = shift;

    return $object->AddAttribute(
        'Name'        => 'SelfServiceDashboard',
        'Description' => $args->{'Name'},
        'Content'     => {Panes => $args->{'Panes'}},
    );
}

# All users can use SelfServiceDashboard
sub CurrentUserCanSee { return 1 }

RT::Base->_ImportOverlays();

1;
