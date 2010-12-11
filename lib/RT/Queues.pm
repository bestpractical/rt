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

=head1 NAME

  RT::Queues - a collection of RT::Queue objects

=head1 SYNOPSIS

  use RT::Queues;

=head1 DESCRIPTION


=head1 METHODS



=cut


package RT::Queues;

use strict;
use warnings;


use RT::Queue;

use base 'RT::SearchBuilder';

sub Table { 'Queues'}

# {{{ sub _Init
sub _Init { 
  my $self = shift;
  $self->{'with_disabled_column'} = 1;

  # By default, order by name
  $self->OrderBy( ALIAS => 'main',
		  FIELD => 'Name',
		  ORDER => 'ASC');

  return ($self->SUPER::_Init(@_));
}

sub Limit  {
  my $self = shift;
  my %args = ( ENTRYAGGREGATOR => 'AND',
	       @_);
  $self->SUPER::Limit(%args);
}


=head2 AddRecord

Adds a record object to this collection if this user can see.
This is used for filtering objects for both Next and ItemsArrayRef.

=cut

sub AddRecord {
    my $self = shift;
    my $Queue = shift;
    return if !$self->{'_sql_current_user_can_see_applied'}
        && !$Queue->CurrentUserHasRight('SeeQueue');

    push @{$self->{'items'}}, $Queue;
    $self->{'rows'}++;
}

sub _DoSearch {
    my $self = shift;
    $self->CurrentUserCanSee if RT->Config->Get('UseSQLForACLChecks');
    return $self->SUPER::_DoSearch( @_ );
}

sub _DoCount {
    my $self = shift;
    $self->CurrentUserCanSee if RT->Config->Get('UseSQLForACLChecks');
    return $self->SUPER::_DoCount( @_ );
}


sub CurrentUserCanSee {
    my $self = shift;
    return if $self->{'_sql_current_user_can_see_applied'};

    return $self->{'_sql_current_user_can_see_applied'} = 1
        if $self->CurrentUser->UserObj->HasRight(
            Right => 'SuperUser', Object => $RT::System
        );

    my $id = $self->CurrentUser->id;

    # directly can see in all queues then we have nothing to do
    my %direct = RT::ACL->_ObjectsDirectlyHasRightOn(
        User => $id,
        Right => 'SeeQueue',
    );
    return $self->{'_sql_current_user_can_see_applied'} = 1
        if $direct{'RT::System'};

    # from this point we only interested in queues
    %direct = ('RT::Queue' => $direct{'RT::Queue'} || []);

    my %roles = RT::ACL->_RolesWithRight( Right => 'SeeQueue' );
    {
        my %skip = map { $_ => 1 } @{ $direct{'RT::Queue'} };
        foreach my $role ( keys %roles ) {
            if ( $roles{ $role }{'RT::System'} ) {
                $roles{ $role } = 1;
            } else {
                my @queues = grep !$skip{$_}, @{ $roles{ $role }{'RT::Queue'} || [] };
                if ( @queues ) {
                    $roles{ $role } = \@queues;
                } else {
                    delete $roles{ $role };
                }
            }
        }
    }

    unless ( @{$direct{'RT::Queue'}} || keys %roles ) {
        $self->SUPER::Limit(
            SUBCLAUSE => 'ACL',
            ALIAS => 'main',
            FIELD => 'id',
            VALUE => 0,
            ENTRYAGGREGATOR => 'AND',
        );
        return $self->{'_sql_current_user_can_see_applied'} = 1;
    }

    {
        my ($role_group_alias, $cgm_alias);
        if ( keys %roles ) {
            $role_group_alias = $self->JoinRoleGroups( New => 1 );
            $cgm_alias = $self->JoinGroupMembers( GroupsAlias => $role_group_alias );
            $self->Limit(
                LEFTJOIN   => $cgm_alias,
                FIELD      => 'MemberId',
                OPERATOR   => '=',
                VALUE      => $id,
            );
        }
        my $limit_queues = sub {
            my $ea = shift;
            my @queues = @_;

            return 0 unless @queues;
            $self->Limit(
                SUBCLAUSE => 'ACL',
                ALIAS => 'main',
                FIELD => 'id',
                OPERATOR => 'IN',
                VALUE => '('. join(', ', @queues) .')',
                QUOTEVALUE => 0,
                ENTRYAGGREGATOR => $ea,
            );
            return 1;
        };

        $self->SUPER::_OpenParen('ACL');
        my $ea = 'AND';
        $ea = 'OR' if $limit_queues->( $ea, @{ $direct{'RT::Queue'} } );
        while ( my ($role, $queues) = each %roles ) {
            $self->SUPER::_OpenParen('ACL');
            $self->Limit(
                SUBCLAUSE       => 'ACL',
                ALIAS           => $cgm_alias,
                FIELD           => 'MemberId',
                OPERATOR        => 'IS NOT',
                VALUE           => 'NULL',
                QUOTEVALUE      => 0,
                ENTRYAGGREGATOR => $ea,
            );
            $self->Limit(
                SUBCLAUSE       => 'ACL',
                ALIAS           => $role_group_alias,
                FIELD           => 'Type',
                VALUE           => $role,
                ENTRYAGGREGATOR => 'AND',
            );
            $limit_queues->( 'AND', @$queues ) if ref $queues;
            $ea = 'OR' if $ea eq 'AND';
            $self->SUPER::_CloseParen('ACL');
        }
        $self->SUPER::_CloseParen('ACL');
    }
    return $self->{'_sql_current_user_can_see_applied'} = 1;
}




=head2 NewItem

Returns an empty new RT::Queue item

=cut

sub NewItem {
    my $self = shift;
    return(RT::Queue->new($self->CurrentUser));
}
RT::Base->_ImportOverlays();

1;
