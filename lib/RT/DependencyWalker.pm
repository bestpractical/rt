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

package RT::DependencyWalker;

use strict;
use warnings;

use RT::DependencyWalker::FindDependencies;
use Carp;

sub new {
    my $class = shift;
    my $self = bless {}, $class;
    $self->Init(@_);
    return $self;
}

sub Init {
    my $self = shift;
    my %args = (
        First          => "top",
        GC             => 0,
        Page           => 100,
        Progress       => undef,
        MessageHandler => \&Carp::carp,
        @_
    );

    $self->{first}    = $args{First};
    $self->{GC}       = $args{GC};
    $self->{Page}     = $args{Page};
    $self->{progress} = $args{Progress};
    $self->{msg}      = $args{MessageHandler},
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

    # Ensure that RT::Ticket's ->Load doesn't follow a merged ticket to
    # the ticket it was merged into.
    no warnings 'redefine';
    local *RT::Ticket::Load = sub {
        my $self = shift;
        my $id   = shift;
        $self->LoadById( $id );
        return $self->Id;
    };

    # When we walk ticket links, find deleted tickets as well
    local *RT::Links::IsValidLink = sub {
        my $self = shift;
        my $link = shift;
        return unless $link && ref $link && $link->Target && $link->Base;
        return 1;
    };

    $self->{visited} = {};
    $self->{seen}    = {};
    $self->{gc_count} = 0;

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
                $ref->RowsPerPage( $self->{Page} );
                $ref->FirstPage;
                $ref->{unrolled}++;
            }
            my $last;
            while (my $obj = $ref->DBIx::SearchBuilder::Next) {
                $last = $obj->Id;
                $self->Process(%frame, object => $obj );
            }
            if (defined $last) {
                $self->NextPage($ref => $last);
                push @{$self->{replace}}, \%frame;
            }
        }
        unshift @{$stack}, @{$self->{replace}};
        unshift @{$stack}, @{$self->{top}};
        push    @{$stack}, @{$self->{bottom}};

        if ($self->{GC} > 0 and $self->{gc_count} > $self->{GC}) {
            $self->{gc_count} = 0;
            require Time::HiRes;
            my $start_time = Time::HiRes::time();
            $self->{msg}->("Starting GC pass...");
            my $start_size = @{$self->{stack}};
            @{ $self->{stack} } = grep {
                $_->{object}->isa("RT::Record")
                    ? not exists $self->{visited}{$_->{uid} ||= $_->{object}->UID}
                    : ( $_->{has_results} ||= do {
                        $_->{object}->FindAllRows;
                        $_->{object}->RowsPerPage(1);
                        $_->{object}->Count;
                    } )
            } @{ $self->{stack} };
            my $end_time = Time::HiRes::time();
            my $end_size = @{$self->{stack}};
            my $size = $start_size - $end_size;
            my $time = $end_time - $start_time;
            $self->{msg}->(
                sprintf(
                    "GC -- %d removed, %.2f seconds, %d/s",
                    $size, $time, int($size/$time)
                )
            );
        }
    }
    $self->{progress}->(undef, 'force') if $self->{progress};
}

sub NextPage {
    my $self        = shift;
    my $collection  = shift;

    $collection->NextPage;
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
    unless ($uid) {
        warn "$args{direction} from $args{from} to $obj is an invalid reference";
        return;
    }
    $self->{progress}->($obj) if $self->{progress};
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
        my $deps = RT::DependencyWalker::FindDependencies->new;
        $obj->FindDependencies($self, $deps);
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
        $self->{gc_count}++ if $self->{GC} > 0;
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
        if (not defined $obj) {
            warn "$dir from $from contained an invalid reference";
            next;
        } elsif ($obj->isa("RT::Record")) {
            warn "$dir from $from to $obj is an invalid reference" unless $obj->UID;
            next if $self->{GC} < 0 and exists $self->{seen}{$obj->UID};
        } else {
            $obj->FindAllRows;
            if ($self->{GC} < 0) {
                $obj->RowsPerPage(1);
                next unless $obj->Count;
            }
        }
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
        if (not defined $obj) {
            warn "$dir from $from contained an invalid reference";
            next;
        } elsif ($obj->isa("RT::Record")) {
            warn "$dir from $from to $obj is an invalid reference" unless $obj->UID;
            next if $self->{GC} < 0 and exists $self->{visited}{$obj->UID};
        } else {
            $obj->FindAllRows;
            if ($self->{GC} < 0) {
                $obj->RowsPerPage(1);
                next unless $obj->Count;
            }
        }
        unshift @{$self->{top}}, {
            object    => $obj,
            direction => $dir,
            from      => $from,
        };
    }
}

1;
