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

use RT::User ();
package RT::User;

use strict;
use warnings;
use warnings FATAL => 'redefine';

use RT::Shredder::Constants;
use RT::Shredder::Exceptions;
use RT::Shredder::Dependencies;

my @OBJECTS = qw(
    Attachments
    CachedGroupMembers
    CustomFields
    CustomFieldValues
    GroupMembers
    Groups
    Links
    Principals
    Queues
    ScripActions
    ScripConditions
    Scrips
    Templates
    ObjectCustomFieldValues
    Tickets
    Transactions
    Users
);

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

# Principal
    $deps->_PushDependency(
            BaseObject => $self,
            Flags => DEPENDS_ON | WIPE_AFTER,
            TargetObject => $self->PrincipalObj,
            Shredder => $args{'Shredder'}
        );

# ACL equivalence group
# don't use LoadACLEquivalenceGroup cause it may not exists any more
    my $objs = RT::Groups->new( $self->CurrentUser );
    $objs->Limit( FIELD => 'Domain', VALUE => 'ACLEquivalence' );
    $objs->Limit( FIELD => 'Instance', VALUE => $self->Id );
    push( @$list, $objs );

# Cleanup user's membership
    $objs = RT::GroupMembers->new( $self->CurrentUser );
    $objs->Limit( FIELD => 'MemberId', VALUE => $self->Id );
    push( @$list, $objs );

    $deps->_PushDependencies(
            BaseObject => $self,
            Flags => DEPENDS_ON,
            TargetObjects => $list,
            Shredder => $args{'Shredder'}
        );

# TODO: Almost all objects has Creator, LastUpdatedBy and etc. fields
# which are references on users(Principal actualy)
    my @var_objs;
    foreach( @OBJECTS ) {
        my $class = "RT::$_";
        foreach my $method ( qw(Creator LastUpdatedBy) ) {
            my $objs = $class->new( $self->CurrentUser );
            next unless $objs->NewItem->_Accessible( $method => 'read' );
            $objs->Limit( FIELD => $method, VALUE => $self->id );
            push @var_objs, $objs;
        }
    }
    $deps->_PushDependencies(
            BaseObject => $self,
            Flags => DEPENDS_ON | VARIABLE,
            TargetObjects => \@var_objs,
            Shredder => $args{'Shredder'}
        );

    return $self->SUPER::__DependsOn( %args );
}

sub __Relates
{
    my $self = shift;
    my %args = (
            Shredder => undef,
            Dependencies => undef,
            @_,
           );
    my $deps = $args{'Dependencies'};
    my $list = [];

# Principal
    my $obj = $self->PrincipalObj;
    if( $obj && defined $obj->id ) {
        push( @$list, $obj );
    } else {
        my $rec = $args{'Shredder'}->GetRecord( Object => $self );
        $self = $rec->{'Object'};
        $rec->{'State'} |= INVALID;
        $rec->{'Description'} = "Have no related ACL equivalence Group object";
    }

    $obj = RT::Group->new( RT->SystemUser );
    $obj->LoadACLEquivalenceGroup( $self->PrincipalObj );
    if( $obj && defined $obj->id ) {
        push( @$list, $obj );
    } else {
        my $rec = $args{'Shredder'}->GetRecord( Object => $self );
        $self = $rec->{'Object'};
        $rec->{'State'} |= INVALID;
        $rec->{'Description'} = "Have no related Principal #". $self->id ." object";
    }

    $deps->_PushDependencies(
            BaseObject => $self,
            Flags => RELATES,
            TargetObjects => $list,
            Shredder => $args{'Shredder'}
        );
    return $self->SUPER::__Relates( %args );
}

sub BeforeWipeout
{
    my $self = shift;
    if( $self->Name =~ /^(RT_System|Nobody)$/ ) {
        RT::Shredder::Exception::Info->throw('SystemObject');
    }
    return $self->SUPER::BeforeWipeout( @_ );
}

1;
