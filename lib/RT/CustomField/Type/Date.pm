# BEGIN BPS TAGGED BLOCK {{{
#
# COPYRIGHT:
#
# This software is Copyright (c) 1996-2011 Best Practical Solutions, LLC
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

package RT::CustomField::Type::Date;
use strict;
use warnings;

use base qw(RT::CustomField::Type);

sub CanonicalizeForCreate {
    my ($self, $cf, $ocfv, $args) = @_;

    # in case user input date with time, let's omit it by setting timezone
    # to utc so "hour" won't affect "day"
    my $DateObj = RT::Date->new( $ocfv->CurrentUser );
    $DateObj->Set( Format   => 'unknown',
                   Value    => $args->{'Content'},
                   Timezone => 'UTC',
                 );
    $args->{'Content'} = $DateObj->Date( Timezone => 'UTC' );

    return wantarray ? (1) : 1;
}

sub SearchBuilderUIArguments {
    my ($self, $cf) = @_;

    return (
        Op => {
            Type => 'component',
            Path => '/Elements/SelectDateRelation',
            Arguments => {},
        },
        Value => {
            Type => 'component',
            Path => '/Elements/SelectDate',
            Arguments => { ShowTime => 0 },
        });
}

1;
