# BEGIN BPS TAGGED BLOCK {{{
#
# COPYRIGHT:
#
# This software is Copyright (c) 1996-2023 Best Practical Solutions, LLC
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

package RT::Shredder::RawRecord;

use strict;
use warnings FATAL => 'all';

sub new {
    my $proto = shift;
    my $self  = bless( {}, ref $proto || $proto );
    $self->Set(@_);
    return $self;
}

sub Set {
    my $self = shift;
    my %args = (@_);
    my @keys = qw(Table Columns);
    @$self{@keys} = @args{@keys};

    $self->Load;

    return;
}

sub UID {
    my $self = shift;
    return $self->{'UID'} if $self->{'UID'};

    my $cols = map { "$_:" . $self->{'Columns'}{$_} }
        sort keys %{ $self->{'Columns'} };
    my $uid = join '-', ref $self, $RT::Organization, $self->Table, $cols;
    return $self->{'UID'} = $uid;
}

sub Load {
    my $self = shift;

    my @cols = keys %{ $self->{'Columns'} };

    my $dbh = $RT::Handle->dbh;
    my $res = $dbh->selectall_arrayref(
        "SELECT * FROM "
            . $self->Table
            . " WHERE "
            . join( " AND ", map $dbh->quote_identifier($_) . " = ?", @cols ),
        { Slice => {} },
        @{ $self->{'Columns'} }{@cols},
    );
    unless ($res) {
        die "Failed to load " . $self->UID . ": " . $dbh->errstr;
    }

    $self->{'records'} = $res;
}

sub _AsInsertQuery {
    my $self = shift;
    return "" unless $self->{'records'} && scalar @{ $self->{'records'} };

    my $dbh  = $RT::Handle->dbh;
    my @cols = keys %{ $self->{'records'}[0] };

    my $res = "INSERT INTO " . $self->Table;
    $res .= "(" . join( ", ", map $dbh->quote_identifier($_), @cols ) . ")";
    $res .= " VALUES\n";
    for my $rec ( @{ $self->{'records'} } ) {
        $res .= "\t("
            . join( ", ", map { $dbh->quote( $rec->{$_} ) } @cols ) . "),\n";
    }
    $res =~ s/,\n$/;\n/;

    return $res;
}

sub BeforeWipeout {
    return 1;
}

sub Dependencies {
    return RT::Shredder::Dependencies->new();
}

sub __Wipeout {
    my $self = shift;
    my $msg  = $self->UID . " wiped out";

    my $dbh   = $RT::Handle->dbh;
    my $query = "DELETE FROM " . $self->Table . " WHERE " . join(
        " AND ",
        map {
                  $dbh->quote_identifier($_) . "="
                . $dbh->quote( $self->{'Columns'}{$_} )
        } keys %{ $self->{'Columns'} }
        )
        . ";";

    $dbh->do($query);

    $RT::Logger->info($msg);
}

sub Table { return $_[0]->{'Table'} }

RT::Base->_ImportOverlays();

1;
