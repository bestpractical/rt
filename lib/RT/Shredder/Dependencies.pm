# BEGIN BPS TAGGED BLOCK {{{
#
# COPYRIGHT:
#
# This software is Copyright (c) 1996-2018 Best Practical Solutions, LLC
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

package RT::Shredder::Dependencies;

use strict;
use warnings;
use RT::Shredder::Exceptions;
use RT::Shredder::Constants;
use RT::Shredder::Dependency;
use RT::Record;



=head1 METHODS

=head2 new

Creates new empty collection of dependecies.

=cut

sub new
{
    my $proto = shift;
    my $self = bless( {}, ref $proto || $proto );
    $self->{'list'} = [];
    return $self;
}

=head2 _PushDependencies

Put in objects into collection.
Takes
BaseObject - any supported object of RT::Record subclass;
Flags - flags that describe relationship between target and base objects;
TargetObjects - any of RT::SearchBuilder or RT::Record subclassed objects
or array ref on list of this objects;
Shredder - RT::Shredder object.

SeeAlso: _PushDependecy, RT::Shredder::Dependency

=cut

sub _PushDependencies
{
    my $self = shift;
    my %args = ( TargetObjects => undef, Shredder => undef, @_ );
    my @objs = $args{'Shredder'}->CastObjectsToRecords( Objects => delete $args{'TargetObjects'} );
    $self->_PushDependency( %args, TargetObject => $_ ) foreach @objs;
    return;
}

sub _PushDependency
{
    my $self = shift;
    my %args = (
            BaseObject => undef,
            Flags => undef,
            TargetObject => undef,
            Shredder => undef,
            @_
           );
    my $rec = $args{'Shredder'}->PutObject( Object => $args{'TargetObject'} );
    return if $rec->{'State'} & RT::Shredder::Constants::WIPED; # there is no object anymore

    push @{ $self->{'list'} },
        RT::Shredder::Dependency->new(
            BaseObject => $args{'BaseObject'},
            Flags => $args{'Flags'},
            TargetObject => $rec->{'Object'},
        );

    if( scalar @{ $self->{'list'} } > ( $RT::DependenciesLimit || 1000 ) ) {
        RT::Shredder::Exception::Info->throw( 'DependenciesLimit' );
    }
    return;
}

=head2 List


=cut

sub List
{
    my $self = shift;
    my %args = (
        WithFlags => undef,
        WithoutFlags => undef,
        Callback => undef,
        @_
    );

    my $wflags = delete $args{'WithFlags'};
    my $woflags = delete $args{'WithoutFlags'};

    return
        map $args{'Callback'}? $args{'Callback'}->($_): $_,
        grep !defined( $wflags ) || ($_->Flags & $wflags) == $wflags,
        grep !defined( $woflags ) || !($_->Flags & $woflags),
        @{ $self->{'list'} };
}

1;
