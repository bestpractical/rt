# BEGIN BPS TAGGED BLOCK {{{
#
# COPYRIGHT:
#
# This software is Copyright (c) 1996-2007 Best Practical Solutions, LLC
#                                          <jesse@bestpractical.com>
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
# http://www.gnu.org/copyleft/gpl.html.
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
use RT::Shredder::Exceptions;
use RT::Shredder::Constants;
use RT::Shredder::Dependency;
use RT::Record;

=head1 METHODS

=head2 new

Creates new empty collection of dependecies.

=cut

sub new {
    my $proto = shift;
    my $self = bless( {}, ref $proto || $proto );
    $self->{'list'} = [];
    return $self;
}

=head2 _push_dependencies

Put in objects into collection.
Takes
base_object - any supported object of RT::Record subclass;
Flags - flags that describe relationship between target and base objects;
target_objects - any of RT::SearchBuilder or RT::Record subclassed objects
or array ref on list of this objects;
Shredder - RT::Shredder object.

SeeAlso: _PushDependecy, RT::Shredder::Dependency

=cut

sub _push_dependencies {
    my $self = shift;
    my %args = ( target_objects => undef, shredder => undef, @_ );
    my @objs = $args{'shredder'}->cast_objects_to_records( objects => delete $args{'target_objects'} );
    $self->_push_dependency( %args, target_object => $_ ) foreach @objs;
    return;
}

sub _push_dependency {
    my $self = shift;
    my %args = (
        base_object   => undef,
        flags         => undef,
        target_object => undef,
        shredder      => undef,
        @_
    );
    my $rec = $args{'shredder'}->put_object( object => $args{'target_object'} );
    return if $rec->{'state'} & WIPED;    # there is no object anymore

    push @{ $self->{'list'} },
        RT::Shredder::Dependency->new(
        base_object   => $args{'base_object'},
        flags         => $args{'flags'},
        target_object => $rec->{'object'},
        );

    if ( scalar @{ $self->{'list'} } > ( $RT::DependenciesLimit || 1000 ) ) {
        RT::Shredder::Exception::Info->throw('DependenciesLimit');
    }
    return;
}

=head2 list


=cut

sub list {
    my $self = shift;
    my %args = (
        with_flags    => undef,
        without_flags => undef,
        callback      => undef,
        @_
    );

    my $wflags  = delete $args{'with_flags'};
    my $woflags = delete $args{'without_flags'};

    return map $args{'callback'} ? $args{'callback'}->($_) : $_,
        grep !defined($wflags)  || ( $_->flags & $wflags ) == $wflags,
        grep !defined($woflags) || !( $_->flags & $woflags ),
        @{ $self->{'list'} };
}

1;
