# BEGIN BPS TAGGED BLOCK {{{
#
# COPYRIGHT:
#
# This software is Copyright (c) 1996-2021 Best Practical Solutions, LLC
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

  RT::Shorteners - Collection of RT::Shortener objects

=head1 SYNOPSIS

  use RT::Shorteners;


=head1 DESCRIPTION


=head1 METHODS


=cut


package RT::Shorteners;

use strict;
use warnings;

use base 'RT::SearchBuilder';

use RT::Shortener;

sub Table { 'Shorteners'}

RT::Base->_ImportOverlays();


=head2 ClearOld TIME

Delete all temporary Shorteners that haven't been accessed for the specified
TIME.

TIME is in the C<< <NUM>[<unit>] >> format. Default unit is D(ays). H(our),
M(onth) and Y(ear) are also supported.

Passing 0 to delete all temporary Shorteners. Default is 1M(i.e. 1 month).

Returns (1, 'Status message') on success and (0, 'Error Message') on failure.

=cut

sub ClearOld {
    my $self  = shift;
    my $older = shift // '1M';

    my $seconds;
    if ($older) {
        unless ( $older =~ /^\s*([0-9]+)\s*(H|D|M|Y)?$/i ) {
            return ( 0, $self->loc("wrong format of the 'older' argumnet") );
        }
        my ( $num, $unit ) = ( $1, uc( $2 || 'D' ) );
        my %factor = ( H => 60 * 60 );
        $factor{'D'} = $factor{'H'} * 24;
        $factor{'M'} = $factor{'D'} * 31;
        $factor{'Y'} = $factor{'D'} * 365;
        $seconds     = $num * $factor{$unit};
    }

    my $dbh = RT->DatabaseHandle->dbh;
    my $rows;
    if ($seconds) {
        require POSIX;
        my $date = POSIX::strftime( "%Y-%m-%d %H:%M", gmtime( time - int $seconds ) );
        my $sth  = $dbh->prepare("DELETE FROM Shorteners WHERE Permanent = ? AND LastAccessed < ?");
        return ( 0, $self->loc( "Couldn't prepare query: [_1]", $dbh->errstr ) ) unless $sth;
        $rows = $sth->execute( 0, $date );
        return ( 0, $self->loc( "Couldn't execute query: [_1]", $dbh->errstr ) ) unless defined $rows;
    }
    else {
        my $sth = $dbh->prepare("DELETE FROM Shorteners WHERE Permanent = ?");
        return ( 0, $self->loc( "Couldn't prepare query: [_1]", $dbh->errstr ) ) unless $sth;
        $rows = $sth->execute(0);
        return ( 0, $self->loc( "Couldn't execute query: [_1]", $dbh->errstr ) ) unless defined $rows;
    }

    # $rows could be 0E0, here we want to show it 0
    $rows = sprintf '%d', $rows;
    if ( $rows == 0 ) {
        return ( 1, $self->loc("No qualified shorteners found, nothing to do") );
    }
    else {
        return ( 1, $self->loc( "Successfully deleted [quant,_1,shortener,shorteners]", $rows ) );
    }
}

1;
