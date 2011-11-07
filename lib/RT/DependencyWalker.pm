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

package RT::DependencyWalker;

use strict;
use warnings;

use RT::DependencyWalker::Dependencies;

sub new {
    my $class = shift;
    my $self = bless {}, $class;
    $self->Init(@_);
    return $self;
}

sub Init {
    my $self = shift;
    my %args = (
        First         => "top",
        @_
    );

    $self->{first}    = $args{First};
    $self->{stack}    = [];
}

sub PushObj {
    my $self = shift;
    push @{$self->{stack}}, { object => $_ }
        for @_;
}

sub Walk {
    my $self = shift;

    $self->PushObj( @_ );

    $self->{visited} = {};
    $self->{seen}    = {};

    my $stack = $self->{stack};
    while (@{$stack}) {
        my %frame = %{ shift @{$stack} };
        $self->{top}     = [];
        $self->{replace} = [];
        $self->{bottom}  = [];
        my $ref = $frame{object};
        if ($ref->isa("RT::Record")) {
            $self->Process(%frame);
        } else {
            unless ($ref->{unrolled}) {
                $ref->FindAllRows;
                $ref->RowsPerPage( 100 );
                $ref->FirstPage;
                $ref->{unrolled}++;
            }
            my $last;
            while (my $obj = $ref->Next) {
                $last = $obj->Id;
                $self->Process(%frame, object => $obj );
            }
            if (defined $last) {
                $ref->NextPage;
                push @{$self->{replace}}, \%frame;
            }
        }
        unshift @{$stack}, @{$self->{replace}};
        unshift @{$stack}, @{$self->{top}};
        push    @{$stack}, @{$self->{bottom}};
    }
}

sub Process {
    my $self = shift;
    my %args = (
        object    => undef,
        direction => undef,
        from      => undef,
        @_
    );

    my $obj = $args{object};
    return if $obj->isa("RT::System");

    my $uid = $obj->UID;
    if (exists $self->{visited}{$uid}) {
        # Already visited -- no-op
        $self->Again(%args);
    } elsif (exists $obj->{satisfied}) {
        # All dependencies visited -- time to visit
        $self->Visit(%args);
        $self->{visited}{$uid}++;
    } elsif (exists $self->{seen}{$uid}) {
        # All of the dependencies are on the stack already.  We may not
        # have gotten to them, but we will eventually.  This _may_ be a
        # cycle, but true cycle detection is too memory-intensive, as it
        # requires keeping track of the history of how each dep got
        # added to the stack, all of the way back.
        $self->ForcedVisit(%args);
        $self->{visited}{$uid}++;
    } else {
        # Nothing known about this previously; add its deps to the
        # stack, then objects it refers to.
        return if defined $args{from}
            and not $self->Observe(%args);
        my $deps = RT::DependencyWalker::Dependencies->new;
        $obj->Dependencies($self, $deps);
        # Shove it back for later
        push @{$self->{replace}}, \%args;
        if ($self->{first} eq "top") {
            # Top-first; that is, visit things we point to first,
            # then deal with us, then deal with things that point to
            # us.  For serialization.
            $self->PrependDeps( out => $deps, $uid );
            $self->AppendDeps(  in  => $deps, $uid );
        } else {
            # Bottom-first; that is, deal with things that point to
            # us first, then deal with us, then deal with things we
            # point to.  For removal.
            $self->PrependDeps( in => $deps, $uid );
            $self->AppendDeps( out => $deps, $uid );
        }
        $obj->{satisfied}++;
        $self->{seen}{$uid}++;
    }
}

sub Observe { 1 }

sub Again {}

sub Visit {}

sub ForcedVisit {
    my $self = shift;
    $self->Visit( @_ );
}

sub AppendDeps {
    my $self = shift;
    my ($dir, $deps, $from) = @_;
    for my $obj (@{$deps->{$dir}}) {
        next if $obj->isa("RT::Record") and not $obj->id;
        push @{$self->{bottom}}, {
            object    => $obj,
            direction => $dir,
            from      => $from,
        };
    }
}

sub PrependDeps {
    my $self = shift;
    my ($dir, $deps, $from) = @_;
    for my $obj (@{$deps->{$dir}}) {
        next if $obj->isa("RT::Record") and not $obj->id;
        unshift @{$self->{top}}, {
            object    => $obj,
            direction => $dir,
            from      => $from,
        };
    }
}

1;
