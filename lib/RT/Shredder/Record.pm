# BEGIN BPS TAGGED BLOCK {{{
#
# COPYRIGHT:
#
# This software is Copyright (c) 1996-2016 Best Practical Solutions, LLC
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

package RT::Record;
use RT::Record ();

use strict;
use warnings;
use warnings FATAL => 'redefine';

use RT::Shredder::Constants;
use RT::Shredder::Exceptions;

=head2 _AsInsertQuery

Returns INSERT query string that duplicates current record and
can be used to insert record back into DB after delete.

=cut

sub _AsInsertQuery
{
    my $self = shift;

    my $dbh = $RT::Handle->dbh;

    my $res = "INSERT INTO ". $dbh->quote_identifier( $self->Table );
    my $values = $self->{'values'};
    $res .= "(". join( ",", map { $dbh->quote_identifier( $_ ) } sort keys %$values ) .")";
    $res .= " VALUES";
    $res .= "(". join( ",", map { $dbh->quote( $values->{$_} ) } sort keys %$values ) .")";
    $res .= ";";

    return $res;
}

sub BeforeWipeout { return 1 }

=head2 Dependencies

Returns L<RT::Shredder::Dependencies> object.

=cut

sub Dependencies
{
    my $self = shift;
    my %args = (
            Shredder => undef,
            Flags => RT::Shredder::Constants::DEPENDS_ON,
            @_,
           );

    unless( $self->id ) {
        RT::Shredder::Exception->throw('Object is not loaded');
    }

    my $deps = RT::Shredder::Dependencies->new();
    if( $args{'Flags'} & RT::Shredder::Constants::DEPENDS_ON ) {
        $self->__DependsOn( %args, Dependencies => $deps );
    }
    return $deps;
}

sub __DependsOn
{
    my $self = shift;
    my %args = (
            Shredder => undef,
            Dependencies => undef,
            @_,
           );
    my $deps = $args{'Dependencies'};
    my $list = [];

# Object custom field values
    my $objs = $self->CustomFieldValues;
    $objs->{'find_expired_rows'} = 1;
    push( @$list, $objs );

# Object attributes
    $objs = $self->Attributes;
    push( @$list, $objs );

# Transactions
    $objs = RT::Transactions->new( $self->CurrentUser );
    $objs->Limit( FIELD => 'ObjectType', VALUE => ref $self );
    $objs->Limit( FIELD => 'ObjectId', VALUE => $self->id );
    push( @$list, $objs );

# Links
    if ( $self->can('Links') ) {
        # make sure we don't skip any record
        no warnings 'redefine';
        local *RT::Links::IsValidLink = sub { 1 };

        foreach ( qw(Base Target) ) {
            my $objs = $self->Links( $_ );
            $objs->_DoSearch;
            push @$list, $objs->ItemsArrayRef;
        }
    }

# ACE records
    $objs = RT::ACL->new( $self->CurrentUser );
    $objs->LimitToObject( $self );
    push( @$list, $objs );

    $deps->_PushDependencies(
            BaseObject => $self,
            Flags => RT::Shredder::Constants::DEPENDS_ON,
            TargetObjects => $list,
            Shredder => $args{'Shredder'}
        );
    return;
}

# implement proxy method because some RT classes
# override Delete method
sub __Wipeout
{
    my $self = shift;
    my $msg = $self->UID ." wiped out";
    $self->SUPER::Delete;
    $RT::Logger->info( $msg );
    return;
}

1;
