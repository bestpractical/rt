# BEGIN BPS TAGGED BLOCK {{{
#
# COPYRIGHT:
#
# This software is Copyright (c) 1996-2012 Best Practical Solutions, LLC
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

use RT::CachedGroupMember ();
package RT::CachedGroupMember;

use strict;
use warnings;
use warnings FATAL => 'redefine';

use RT::Shredder::Constants;
use RT::Shredder::Exceptions;
use RT::Shredder::Dependency;

sub _AsInsertQuery
{
    my $self = shift;
    return $self->SUPER::_AsInsertQuery( @_ )
        if $self->MemberId == $self->GroupId;

    my $table = $self->Table;
    my $dbh = $RT::Handle->dbh;
    my @quoted = ( map $dbh->quote($self->$_()), qw(GroupId MemberId Disabled) );

    my $query =
        "SELECT ". join( ', ', @quoted ) .' WHERE NOT EXISTS ('
            ."SELECT id FROM $table WHERE GroupId = $quoted[0] AND MemberId = $quoted[1]"
        .')'
    ;
    my $res = $self->BuildInsertFromSelectQuery( $query ) ."\n";

    $query = "SELECT CGM1.GroupId, CGM2.MemberId, CASE WHEN CGM1.Disabled + CGM2.Disabled > 0 THEN 1 ELSE 0 END FROM
        $table CGM1 CROSS JOIN $table CGM2
        LEFT JOIN $table CGM3
            ON CGM3.GroupId = CGM1.GroupId AND CGM3.MemberId = CGM2.MemberId
        WHERE
            CGM1.MemberId = $quoted[0] AND (CGM1.GroupId != CGM1.MemberId OR CGM1.MemberId = $quoted[1])
            AND CGM3.id IS NULL
    ";

    if ( $self->MemberObj->IsGroup ) {
        $query .= "
            AND CGM2.GroupId = $quoted[1]
            AND (CGM2.GroupId != CGM2.MemberId OR CGM2.GroupId = $quoted[1])
        ";
    }
    else {
        $query .= " AND CGM2.GroupId = $quoted[0] AND CGM2.MemberId = $quoted[1]";
    }
    $res .= $self->BuildInsertFromSelectQuery( $query ) ."\n";

    return $res;
}

sub BuildInsertFromSelectQuery {
    my $self = shift;
    my $query = shift;

    my $table = $self->Table;
    if ( RT->Config->Get('DatabaseType') eq 'Oracle' ) {
        $query = "(SELECT ${table}_seq.nextval, insert_from.* FROM ($query) insert_from)";
    }
    return "INSERT INTO $table(GroupId, MemberId, Disabled) $query;";
}

sub __Wipeout {
    my $self = shift;
    return $self->SUPER::__Wipeout( @_ )
        if $self->MemberId == $self->GroupId;

    # GroupMember takes care of wiping other records
    return 1;
}



1;
