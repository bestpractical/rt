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

package RT::CustomField::Type::DateTime;
use strict;
use warnings;

use base qw(RT::CustomField::Type);

sub CanonicalizeForCreate {
    my ($self, $cf, $ocfv, $args) = @_;

    my $DateObj = RT::Date->new( $ocfv->CurrentUser );
    $DateObj->Set( Format => 'unknown',
                   Value  => $args->{'Content'} );
    $args->{'Content'} = $DateObj->ISO;

    return wantarray ? (1) : 1;
}

sub Limit {
    my ($self, $tickets, $field, $value, $op, %rest) = @_;
    return unless $op eq '=';
    if ( $value =~ /:/ ) {
        # there is time speccified.
        my $date = RT::Date->new( $tickets->CurrentUser );
        $date->Set( Format => 'unknown', Value => $value );

        $tickets->_CustomFieldLimit(
            'CF', '=', $date->ISO, %rest,
            SUBKEY => $rest{'SUBKEY'}. '.Content',
        );
    }
    else {
        # no time specified, that means we want everything on a
        # particular day.  in the database, we need to check for >
        # and < the edges of that day.
        my $date = RT::Date->new( $tickets->CurrentUser );
        $date->Set( Format => 'unknown', Value => $value );
        $date->SetToMidnight( Timezone => 'server' );
        my $daystart = $date->ISO;
        $date->AddDay;
        my $dayend = $date->ISO;

        $tickets->_OpenParen;


        $tickets->_CustomFieldLimit(
            'CF', '>=', $daystart, %rest,
            SUBKEY => $rest{'SUBKEY'}. '.Content',
        );

        $tickets->_CustomFieldLimit(
            'CF', '<=', $dayend, %rest,
            SUBKEY => $rest{'SUBKEY'}. '.Content',
            ENTRYAGGREGATOR => 'AND',
        );

        $tickets->_CloseParen;
    }
    return 1;

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
            Arguments => { ShowTime => 1 },
        });
}

sub StringifyForDisplay {
    my ($self, $ocfv) = @_;
    my $content = $ocfv->_Value('Content');
    my $DateObj = RT::Date->new( $ocfv->CurrentUser );
    $DateObj->Set(
        Format => 'ISO',
        Value  => $content,
    );
    return $DateObj->AsString;
}


1;
