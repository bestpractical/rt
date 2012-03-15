# BEGIN BPS TAGGED BLOCK {{{
#
# COPYRIGHT:
#
# This software is Copyright (c) 1996-2013 Best Practical Solutions, LLC
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

package RT::CachedGroupMember;

use strict;
use warnings;


use base 'RT::Record';

sub Table {'CachedGroupMembers'}

=head1 NAME

  RT::CachedGroupMember

=head1 SYNOPSIS

  use RT::CachedGroupMember;

=head1 DESCRIPTION

=head1 METHODS

=cut

# {{ Create

=head2 Create PARAMHASH

Create takes a hash of values and creates a row in the database:

  'Group' is the "top level" group we're building the cache for. This 
  is an RT::Principal object

  'Member' is the RT::Principal  of the user or group we're adding to 
  the cache.

  This routine should _only_ be called by GroupMember->Create

=cut

sub Create {
    my $self = shift;
    my %args = (
        Group           => undef,
        Member          => undef,
        @_
    );

    unless (    $args{'Member'}
             && UNIVERSAL::isa( $args{'Member'}, 'RT::Principal' )
             && $args{'Member'}->Id ) {
        $RT::Logger->debug("$self->Create: bogus Member argument");
    }

    unless (    $args{'Group'}
             && UNIVERSAL::isa( $args{'Group'}, 'RT::Principal' )
             && $args{'Group'}->Id ) {
        $RT::Logger->debug("$self->Create: bogus Group argument");
    }

    $args{'Disabled'} = $args{'Group'}->Disabled? 1 : 0;

    $self->LoadByCols(
        GroupId           => $args{'Group'}->Id,
        MemberId          => $args{'Member'}->Id,
    );

    my $id;
    if ( $id = $self->id ) {
        if ( $self->Disabled != $args{'Disabled'} && $args{'Disabled'} == 0 ) {
            my ($status) = $self->SetDisabled( 0 );
            return undef unless $status;
        }
        return $id;
    }

    ($id) = $self->SUPER::Create(
        GroupId           => $args{'Group'}->Id,
        MemberId          => $args{'Member'}->Id,
        Disabled          => $args{'Disabled'},
    );
    unless ($id) {
        $RT::Logger->warning(
            "Couldn't create ". $args{'Member'} ." as a cached member of "
            . $args{'Group'}
        );
        return (undef);
    }
    return $id if $args{'Member'}->id == $args{'Group'}->id;

    my $table = $self->Table;
    if ( !$args{'Disabled'} && $args{'Member'}->IsGroup ) {
        # update existing records, in case we activated some paths
        my $query = "
            SELECT CGM3.id FROM
                $table CGM1 CROSS JOIN $table CGM2
                JOIN $table CGM3
                    ON CGM3.GroupId = CGM1.GroupId AND CGM3.MemberId = CGM2.MemberId
            WHERE
                CGM1.MemberId = ? AND (CGM1.GroupId != CGM1.MemberId OR CGM1.MemberId = ?)
                AND CGM2.GroupId = ? AND (CGM2.GroupId != CGM2.MemberId OR CGM2.GroupId = ?)
                AND CGM1.Disabled = 0 AND CGM2.Disabled = 0 AND CGM3.Disabled > 0
        ";
        $RT::Handle->SimpleUpdateFromSelect(
            $table, { Disabled => 0 }, $query,
            $args{'Group'}->id, $args{'Group'}->id,
            $args{'Member'}->id, $args{'Member'}->id
        ) or return undef;
    }

    my @binds;

    my $disabled_clause;
    if ( $args{'Disabled'} ) {
        $disabled_clause = '?';
        push @binds, $args{'Disabled'};
    } else {
        $disabled_clause = 'CASE WHEN CGM1.Disabled + CGM2.Disabled > 0 THEN 1 ELSE 0 END';
    }

    my $query = "SELECT CGM1.GroupId, CGM2.MemberId, $disabled_clause FROM
        $table CGM1 CROSS JOIN $table CGM2
        LEFT JOIN $table CGM3
            ON CGM3.GroupId = CGM1.GroupId AND CGM3.MemberId = CGM2.MemberId
        WHERE
            CGM1.MemberId = ? AND (CGM1.GroupId != CGM1.MemberId OR CGM1.MemberId = ?)
            AND CGM3.id IS NULL
    ";
    push @binds, $args{'Group'}->id, $args{'Group'}->id;

    if ( $args{'Member'}->IsGroup ) {
        $query .= "
            AND CGM2.GroupId = ?
            AND (CGM2.GroupId != CGM2.MemberId OR CGM2.GroupId = ?)
        ";
        push @binds, $args{'Member'}->id, $args{'Member'}->id;
    }
    else {
        $query .= " AND CGM2.id = ?";
        push @binds, $id;
    }
    $RT::Handle->InsertFromSelect(
        $table, ['GroupId', 'MemberId', 'Disabled'], $query, @binds,
    );

    return $id;
}

=head2 Delete

Deletes the current CachedGroupMember from the group it's in and cascades 
the delete to all submembers. This routine could be completely excised if
mysql supported foreign keys with cascading deletes.

=cut

sub Delete {
    my $self = shift;

    if ( $self->MemberId == $self->GroupId ) {
        # deleting self-referenced means that we're deleting a principal
        # itself and all records where it's a parent or member should
        # be deleted beforehead
        return $self->SUPER::Delete( @_ );
    }

    my $table = $self->Table;

    my $member_is_group = $self->MemberObj->IsGroup;

    my $query;
    if ( $member_is_group ) {
        $query = "
            SELECT CGM1.id FROM
                CachedGroupMembers CGM1
                JOIN CachedGroupMembers CGMA ON CGMA.MemberId = ?
                JOIN CachedGroupMembers CGMD ON CGMD.GroupId = ?
                LEFT JOIN GroupMembers GM1
                    ON GM1.GroupId = CGM1.GroupId AND GM1.MemberId = CGM1.MemberId
            WHERE
                CGM1.GroupId = CGMA.GroupId AND CGM1.MemberId = CGMD.MemberId
                AND CGM1.GroupId != CGM1.MemberId
                AND GM1.id IS NULL
        ";
    }
    else {
        $query = "
            SELECT CGM1.id FROM
                CachedGroupMembers CGM1
                JOIN CachedGroupMembers CGMA ON CGMA.MemberId = ?
                LEFT JOIN GroupMembers GM1
                    ON GM1.GroupId = CGM1.GroupId AND GM1.MemberId = CGM1.MemberId
            WHERE
                CGM1.GroupId = CGMA.GroupId
                AND CGM1.MemberId = ?
                AND GM1.id IS NULL
        ";
    }

    my $res = $RT::Handle->DeleteFromSelect(
        $table, $query,
        $self->GroupId, $self->MemberId,
    );
    return $res unless $res;

    my @binds;
    if ( $member_is_group ) {
        $query =
            "SELECT DISTINCT CGM1.GroupId, CGM2.MemberId, 1
            FROM $table CGM1 CROSS JOIN $table CGM2
            JOIN $table CGM3 ON CGM3.GroupId != CGM3.MemberId AND CGM3.GroupId = CGM1.GroupId
            JOIN $table CGM4 ON CGM4.GroupId != CGM4.MemberId AND CGM4.MemberId = CGM2.MemberId
                AND CGM3.MemberId = CGM4.GroupId
            LEFT JOIN $table CGM5
                ON CGM5.GroupId = CGM1.GroupId AND CGM5.MemberId = CGM2.MemberId
            WHERE
                CGM1.MemberId = ?
                AND CGM2.GroupId = ?
                AND CGM5.id IS NULL
        ";
        @binds = ($self->GroupId, $self->MemberId);

    } else {
        $query =
            "SELECT DISTINCT CGM1.GroupId, ?, 1
            FROM $table CGM1
            JOIN $table CGM3 ON CGM3.GroupId != CGM3.MemberId AND CGM3.GroupId = CGM1.GroupId
            JOIN $table CGM4 ON CGM4.GroupId != CGM4.MemberId AND CGM4.MemberId = ?
                AND CGM3.MemberId = CGM4.GroupId
            LEFT JOIN $table CGM5
                ON CGM5.GroupId = CGM1.GroupId AND CGM5.MemberId = ?
            WHERE
                CGM1.MemberId = ?
                AND CGM5.id IS NULL
        ";
        @binds = (
            ($self->MemberId)x3,
            $self->GroupId,
        );
    }

    $res = $RT::Handle->InsertFromSelect(
        $table, ['GroupId', 'MemberId', 'Disabled'], $query, @binds
    );
    return $res unless $res;

    if ( $res > 0 && $member_is_group ) {
        $query =
            "SELECT main.id
            FROM $table main
            JOIN $table CGMA ON CGMA.MemberId = ?
            JOIN $table CGMD ON CGMD.GroupId = ?

            JOIN $table CGM3 ON CGM3.GroupId != CGM3.MemberId
                AND CGM3.GroupId = main.GroupId
                AND CGM3.Disabled = 0
            JOIN $table CGM4 ON CGM4.GroupId != CGM4.MemberId
                AND CGM4.MemberId = main.MemberId
                AND CGM4.Disabled = 0
                AND CGM3.MemberId = CGM4.GroupId
            WHERE
                main.GroupId = CGMA.GroupId
                AND main.MemberId = CGMD.MemberId
                AND main.Disabled = 1
        ";
    }
    elsif ( $res > 0 ) {
        $query =
            "SELECT main.id
            FROM $table main
            JOIN $table CGMA ON CGMA.MemberId = ?

            JOIN $table CGM3 ON CGM3.GroupId != CGM3.MemberId
                AND CGM3.GroupId = main.GroupId
                AND CGM3.Disabled = 0
            JOIN $table CGM4 ON CGM4.GroupId != CGM4.MemberId
                AND CGM4.MemberId = main.MemberId
                AND CGM4.Disabled = 0
                AND CGM3.MemberId = CGM4.GroupId
            WHERE
                main.GroupId = CGMA.GroupId
                AND main.MemberId = ?
                AND main.Disabled = 1
        ";
    }

    $res = $RT::Handle->SimpleUpdateFromSelect(
        $table, { Disabled => 0 }, $query,
        $self->GroupId,
        $self->MemberId,
    ) if $res > 0;
    return $res unless $res;

    if ( my $m = $self->can('_FlushKeyCache') ) { $m->($self) };

    return 1;
}

=head2 SetDisabled

SetDisableds the current CachedGroupMember from the group it's in and cascades 
the SetDisabled to all submembers. This routine could be completely excised if
mysql supported foreign keys with cascading SetDisableds.

=cut

sub SetDisabled {
    my $self = shift;
    my $val = shift;
    $val = $val ? 1 : 0;

    # if it's already disabled, we're good.
    return (1) if $self->__Value('Disabled') == $val;

    if ( $val ) {
        unless ( $self->GroupId == $self->MemberId ) {
            $RT::Logger->error("SetDisabled should only be applied to (G->G) records");
            return undef;
        }

        my $query = "SELECT main.id FROM CachedGroupMembers main
            WHERE main.Disabled = 0 AND main.GroupId = ?";

        $RT::Handle->SimpleUpdateFromSelect(
            $self->Table, { Disabled => 1 }, $query,
            $self->GroupId,
        ) or return undef;

        $query = "SELECT main.id FROM CachedGroupMembers main
            JOIN CachedGroupMembers CGM1 ON main.GroupId = CGM1.GroupId
                AND CGM1.MemberId = ?
            JOIN CachedGroupMembers CGM2 ON main.MemberId = CGM2.MemberId
                AND CGM2.GroupId = ? AND CGM2.GroupId != CGM2.MemberId

            WHERE main.Disabled = 0
                AND NOT EXISTS (
                    SELECT CGM3.id
                    FROM CachedGroupMembers CGM3, CachedGroupMembers CGM4
                    WHERE CGM3.Disabled = 0 AND CGM4.Disabled = 0
                        AND CGM3.GroupId = main.GroupId
                        AND CGM3.MemberId = CGM4.GroupId
                        AND CGM4.MemberId = main.MemberId
                        AND CGM3.id != main.id
                        AND CGM4.id != main.id
                )
        ";



        $RT::Handle->SimpleUpdateFromSelect(
            $self->Table, { Disabled => 1 }, $query,
            ($self->GroupId)x2,
        ) or return undef;
    }
    else {
        my ($status, $msg) = $self->_Set(Field => 'Disabled', Value => $val);
        unless ( $status ) {
            $RT::Logger->error(
                "Couldn't SetDisabled CachedGroupMember #" . $self->Id .": $msg"
            );
            return $status;
        }
        REDO:
        my $query = "SELECT main.id FROM CachedGroupMembers main
            JOIN CachedGroupMembers CGM1 ON main.GroupId = CGM1.GroupId
                AND CGM1.MemberId = ?
            JOIN CachedGroupMembers CGM2 ON main.MemberId = CGM2.MemberId
                AND CGM2.GroupId = ?
            WHERE main.Disabled = 1";

        my $res = $RT::Handle->SimpleUpdateFromSelect(
            $self->Table, { Disabled => 0 }, $query,
            $self->GroupId, $self->MemberId
        ) or return undef;
        goto REDO if $res > 0;
    }
    if ( my $m = $self->can('_FlushKeyCache') ) { $m->($self) };
    return (1);
}



=head2 GroupObj  

Returns the RT::Principal object for this group Group

=cut

sub GroupObj {
    my $self      = shift;
    my $principal = RT::Principal->new( $self->CurrentUser );
    $principal->Load( $self->GroupId );
    return ($principal);
}



=head2 MemberObj

Returns the RT::Principal object for this group member

=cut

sub MemberObj {
    my $self      = shift;
    my $principal = RT::Principal->new( $self->CurrentUser );
    $principal->Load( $self->MemberId );
    return ($principal);
}

# }}}






=head2 id

Returns the current value of id.
(In the database, id is stored as int(11).)


=cut


=head2 GroupId

Returns the current value of GroupId.
(In the database, GroupId is stored as int(11).)



=head2 SetGroupId VALUE


Set GroupId to VALUE.
Returns (1, 'Status message') on success and (0, 'Error Message') on failure.
(In the database, GroupId will be stored as a int(11).)


=cut


=head2 MemberId

Returns the current value of MemberId.
(In the database, MemberId is stored as int(11).)



=head2 SetMemberId VALUE


Set MemberId to VALUE.
Returns (1, 'Status message') on success and (0, 'Error Message') on failure.
(In the database, MemberId will be stored as a int(11).)


=cut

=head2 Disabled

Returns the current value of Disabled.
(In the database, Disabled is stored as smallint(6).)

=head2 SetDisabled VALUE

Set Disabled to VALUE.
Returns (1, 'Status message') on success and (0, 'Error Message') on failure.
(In the database, Disabled will be stored as a smallint(6).)

=cut


=head1 FOR DEVELOPERS

=head2 New structure without Via and ImmediateParent

We have id, GroupId, MemberId, Disabled. In this schema
we have unique index on GroupId and MemberId that will
improve selects.

Disabled column is complex as it's reflects all possible
paths between group and member. If at least one active path
exists then the record is active.

When a GM record is added we do only two queries: insert
new CGM records and update Disabled on old paths.

When a GM record is deleted we update CGM in two steps:
delete all potential candidates and re-insert them. We
do this within one transaction.

=head2 SQL behind maintaining CGM table

=head3 Terminology

=over 4

=item * An(E) - all ancestors of E including E itself

=item * De(E) - all descendants of E including E itself

=back

=head3 Adding a (G -> M) record

When a new (G -> M) record added we should connect all An(G)
to all De(M). The following select fetches all new records:

    SELECT CGM1.GroupId, CGM2.MemberId FROM
        CachedGroupMembers CGM1
        CROSS JOIN CachedGroupMembers CGM2
    WHERE
        CGM1.MemberId = G
        AND CGM2.GroupId = M
    ;

It handles G and M itself as we always have (E->E) records
for groups.

Some of this records may exist in the table, so we should skip existing:

    SELECT CGM1.GroupId, CGM2.MemberId FROM
        CachedGroupMembers CGM1
        CROSS JOIN CachedGroupMembers CGM2
        LEFT JOIN CachedGroupMembers CGM3
            ON CGM3.GroupId = CGM1.GroupId AND CGM3.MemberId = CGM2.MemberId
    WHERE
        CGM1.MemberId = G
        AND CGM2.GroupId = M
        AND CGM3.id IS NULL
    ;

In order to do less checks we should skip (E->E) records, but not those
that touch our G and M:

    SELECT CGM1.GroupId, CGM2.MemberId FROM
        CachedGroupMembers CGM1
        CROSS JOIN CachedGroupMembers CGM2
        LEFT JOIN CachedGroupMembers CGM3
            ON CGM3.GroupId = CGM1.GroupId AND CGM3.MemberId = CGM2.MemberId
    WHERE
        CGM1.MemberId = G AND (CGM1.GroupId != CGM1.MemberId OR CGM1.MemberId = G)
        AND CGM2.GroupId = M AND (CGM2.GroupId != CGM2.MemberId OR CGM2.GroupId = M)
        AND CGM3.id IS NULL
    ;

=head4 Disabled column on insert

We should handle properly Disabled column.

If the GM record we're adding is disabled then all new paths we add as well
disabled and existing one are not affected.

Otherwise activity of new paths depends on entries that got connected and existing
paths have to be updated.

New paths:

    SELECT CGM1.GroupId, CGM2.MemberId, IF(CGM1.Disabled+CGM2.Disabled > 0, 1, 0) FROM
    ...

Updating old paths, the following records should be activated:

    SELECT CGM3.id FROM
        CachedGroupMembers CGM1
        CROSS JOIN CachedGroupMembers CGM2
        JOIN CachedGroupMembers CGM3
            ON CGM3.GroupId = CGM1.GroupId AND CGM3.MemberId = CGM2.MemberId
    WHERE
        CGM1.MemberId = G AND (CGM1.GroupId != CGM1.MemberId OR CGM1.MemberId = G)
        AND CGM2.GroupId = M AND (CGM2.GroupId != CGM2.MemberId OR CGM2.GroupId = M)
        AND CGM1.Disabled = 0 AND CGM2.Disabled = 0 AND CGM3.Disabled > 0
    ;

It's better to do this before we insert new records, so we scan less records
to find things we need updating.

=head3 mysql performance

Sample results:

    10k  - 0.4x seconds
    100k - 4.x seconds
    1M   - 4x.x seconds

As long as innodb_buffer_pool_size is big enough to store insert buffer,
and MIN(tmp_table_size, max_heap_table_size) allow us to store tmp table
in the memory. For 100k records we need less than 15 MBytes. Disk I/O
heavily degrades performance.

=head2 Deleting a (G->M) record

In case record is deleted from GM table we should re-evaluate records in CGM.

Candidates for deletion are any records An(G) -> De(M):

    SELECT CGM3.id FROM
        CachedGroupMembers CGM1
        CROSS JOIN CachedGroupMembers CGM2
        JOIN CachedGroupMembers CGM3
            ON CGM3.GroupId = CGM1.GroupId AND CGM3.MemberId = CGM2.MemberId
    WHERE
        CGM1.MemberId = G
        AND CGM2.GroupId = M
    ;

Some of these records may still have alternative routes. A candidate (G', M')
stays in the table if following records exist in GM and CGM tables.
(G', X) in CGM, (X,Y) in GM and (Y,M') in CGM, where X ~ An(G) and Y !~ An(G).
And here is SQL to select records that should be deleted:

    SELECT CGM3.id FROM
        CachedGroupMembers CGM1
        CROSS JOIN CachedGroupMembers CGM2
        JOIN CachedGroupMembers CGM3
            ON CGM3.GroupId = CGM1.GroupId AND CGM3.MemberId = CGM2.MemberId

    WHERE
        CGM1.MemberId = G
        AND CGM2.GroupId = M
        AND NOT EXISTS (
            SELECT CGM4.GroupId FROM
                CachedGroupMembers CGM4
                    ON CGM4.GroupId = CGM3.GroupId
                JOIN GroupMembers GM1
                    ON GM1.GroupId = CGM4.MemberId
                JOIN GroupMembers CGM5
                    ON CGM4.GroupId = GM1.MemberId
                    AND CGM4.MemberId = CGM3.MemberId
                JOIN CachedGroupMembers CGM6
                    ON CGM6.GroupId = CGM4.MemberId
                    AND CGM6.MemberId = G
                LEFT JOIN CachedGroupMembers CGM7
                    ON CGM7.GroupId = CGM5.GroupId
                    AND CGM7.MemberId = G
            WHERE
                CGM7.id IS NULL
        )
    ;

Fun.

=head3 mysql performance

    10k  - 4.x seconds
    100k - 13x seconds
    1M   - not tested

Sadly this query perform much worth comparing to the insert operation. Problem is
in the select.

=head3 Delete all candidates and re-insert missing (our method)

We can delete all candidates (An(G)->De(M)) from CGM table that are not
real GM records: then insert records once again.

    SELECT CGM1.id FROM
        CachedGroupMembers CGM1
        JOIN CachedGroupMembers CGMA ON CGMA.MemberId = G
        JOIN CachedGroupMembers CGMD ON CGMD.GroupId = M
        LEFT JOIN GroupMembers GM1
            ON GM1.GroupId = CGM1.GroupId AND GM1.MemberId = CGM1.MemberId
    WHERE
        CGM1.GroupId = CGMA.GroupId AND CGM1.MemberId = CGMD.MemberId
        AND CGM1.GroupId != CGM1.MemberId
        AND GM1.id IS NULL
    ;

Then we can re-insert data back with insert from select described above.

=head4 Disabled column on delete

We delete all (An(G)->De(M)) and then re-insert survivors, so no other
records except inserted can gain or loose activity. See this is the same
as how we deal with it during insert.

=head4 mysql performance

This solution is faster than previous variant, 4-5 times slower than
create operation, behaves linear.

=head3 Recursive delete

Alternative solution.

Again, some (An(G), De(M)) pairs should be deleted, but some may stay. If
delete any pair from the set then An(G) and De(M) sets don't change, so
we can delete things step by step. Run delete operation, if any was deleted
then run it once again, do it until operation deletes no rows. We shouldn't
delete records where:

=over 4

=item * GroupId == MemberId

=item * exists matching GM

=item * exists equivalent GM->CGM pair

=item * exists equivalent CGM->GM pair

=back

Query with most conditions in one NOT EXISTS subquery:

    SELECT CGM1.id FROM
        CachedGroupMembers CGM1
        JOIN CachedGroupMembers CGMA ON CGMA.MemberId = G
        JOIN CachedGroupMembers CGMD ON CGMD.GroupId = M
    WHERE
        CGM1.GroupId = CGMA.GroupId AND CGM1.MemberId = CGMD.MemberId
        AND CGM1.GroupId != CGM1.MemberId
        AND NOT EXISTS (
            SELECT * FROM
                CachedGroupMembers CGML
                CROSS JOIN GroupMembers GM
                CROSS JOIN CachedGroupMembers CGMR
            WHERE
                CGML.GroupId = CGM1.GroupId
                AND GM.GroupId = CGML.MemberId
                AND CGMR.GroupId = GM.MemberId
                AND CGMR.MemberId = CGM1.MemberId
                AND (
                    (CGML.GroupId = CGML.MemberId AND CGMR.GroupId != CGMR.MemberId)
                    OR 
                    (CGML.GroupId != CGML.MemberId AND CGMR.GroupId = CGMR.MemberId)
                )
        )
    ;

=head4 mysql performance

It's better than first solution, but still it's not linear. Problem is that
NOT EXISTS means that for every link that should be deleted we have to check too
many conditions (too many rows to scan). Still delete + insert behave better and
linear.

=head3 Alternative ways

Store additional info in a table, similar to Via and IP we had. Then we can
do iterative delete like in the last solution. However, this will slowdown
insert, probably not that much as I suspect we would be able to push new data
in one query.

=head2 Disabling a (G->G) record

We're interested only in (G->G) records as CGM path is disabled if group
is disabled. Disabled users don't affect CGM records.

When (G->G) gets Disabled, 1) (G->De(G)) gets Disabled 2) all active
(An(G)->De(G)) get disabled unless record has an alternative active path.

First can be done without much problem:

    UPDATE CGM SET Disabled => 1 WHERE GroupId = G;

Second part is harder. Finding an alternative path is harder and similar to
performing delete in one query.

Instead we disable all candidates and then re-enable required. Selecting
candidates is simple:

    SELECT main.id FROM CachedGroupMembers main
        JOIN CachedGroupMembers CGM1 ON main.GroupId = CGM1.GroupId AND CGM1.MemberId = G
        JOIN CachedGroupMembers CGM2 ON main.MemberId = CGM2.MemberId AND CGM2.GroupId = G
    WHERE main.Disabled = 0;

We can narrow it down. If (G'->G) is disabled where G'~An(G) then activity
of (G'->M') where M'~De(G) isn't affected by activity of (G->G):

    SELECT main.id FROM CachedGroupMembers main
        JOIN CachedGroupMembers CGM1 ON main.GroupId = CGM1.GroupId AND CGM1.MemberId = G
            AND CGM1.Disabled = 0
        JOIN CachedGroupMembers CGM2 ON main.MemberId = CGM2.MemberId AND CGM2.GroupId = G
    WHERE main.Disabled = 0;

Now we can re-enable disabled records which still have active alternative paths:

    SELECT main.id FROM CachedGroupMembers main
        JOIN CachedGroupMembers CGM1 ON main.GroupId = CGM1.GroupId AND CGM1.MemberId = G
            AND CGM1.Disabled = 0
        JOIN CachedGroupMembers CGM2 ON main.MemberId = CGM2.MemberId AND CGM2.GroupId = G

        JOIN CachedGroupMembers CGM3 ON CGM3.Disabled = 0 AND main.GroupId = CGM3.GroupID
        JOIN CachedGroupMembers CGM4 ON CGM4.Disabled = 0 AND main.MemberId = CGM4.MemberId
            AND CGM4.GroupId = CGM3.MemberId

    WHERE main.Disabled = 1;

Enabling records is much easier, just update all candidates.

=head2 INDEXING

=head3 Access patterns

We either have group and want members, have member and want groups or
have both and check existance.

Disabled column has low selectivity.

=head3 Index access without table access

Some databases can access index by prefix and use rest as data source, so
multi column indexes improve performance.

This works on L<mysql (see "using index")|http://dev.mysql.com/doc/refman/5.1/en/explain-output.html#explain-output-columns>
and L<Oracle|http://docs.oracle.com/cd/A58617_01/server.804/a58246/access.htm#2174>.

This doesn't work for Pg, but L<comes in 9.2|http://rhaas.blogspot.com/2011/10/fast-counting.html>.

=head3 Indexes

For Oracle, mysql and SQLite:

    UNIQUE ON (GroupId, MemberId, Disabled)
    UNIQUE ON (MemberId, GroupId, Disabled)

For Pg:

    UNIQUE ON (GroupId, MemberId)
    (MemberId)

=head2 What's next

We don't create self-referencing records for users and it complicates
a few code paths in this module. However, we have ACL equiv groups for
every user and these groups have (G->G) records and (G->U) record. So
we have one additional group per user and two CGM records.

We can give user's id to ACL equiv group, so G.id = U.id. In this case
we get (G, G) pair that is at the same time (U->U) and (G->U) pairs.
It simplifies code in this module and CGM table smaller by one record
per user.

=cut

sub _CoreAccessible {
    {
        id =>
                {read => 1, sql_type => 4, length => 11,  is_blob => 0,  is_numeric => 1,  type => 'int(11)', default => ''},
        GroupId =>
                {read => 1, write => 1, sql_type => 4, length => 11,  is_blob => 0,  is_numeric => 1,  type => 'int(11)', default => ''},
        MemberId =>
                {read => 1, write => 1, sql_type => 4, length => 11,  is_blob => 0,  is_numeric => 1,  type => 'int(11)', default => ''},
        Disabled =>
                {read => 1, write => 1, sql_type => 5, length => 6,  is_blob => 0,  is_numeric => 1,  type => 'smallint(6)', default => '0'},
    }
};

sub Serialize {
    die "CachedGroupMembers should never be serialized";
}

RT::Base->_ImportOverlays();

1;
