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

package RT::Importer;

use strict;
use warnings;

use Storable qw//;

sub new {
    my $class = shift;
    my $self = bless {}, $class;
    $self->Init(@_);
    return $self;
}

sub Init {
    my $self = shift;
    # Objects we've created
    $self->{UIDs} = {};

    # Columns we need to update when an object is later created
    $self->{Pending} = {};

    # What we created
    $self->{ObjectCount} = {};
}

sub Resolve {
    my $self = shift;
    my ($uid, $class, $id) = @_;
    $self->{UIDs}{$uid} = [ $class, $id ];
    return unless $self->{Pending}{$uid};

    for my $ref (@{$self->{Pending}{$uid}}) {
        my ($pclass, $pid) = @{ $self->{UIDs}{ $ref->{uid} } };
        my $obj = $pclass->new( RT->SystemUser );
        $obj->LoadByCols( Id => $pid );
        $obj->__Set(
            Field => $ref->{column},
            Value => $id,
        );
        $obj->__Set(
            Field => $ref->{classcolumn},
            Value => $class,
        ) if $ref->{classcolumn};
    }
    delete $self->{Pending}{$uid};
}

sub Lookup {
    my $self = shift;
    my ($uid) = @_;
    return $self->{UIDs}{$uid};
}

sub Postpone {
    my $self = shift;
    my %args = (
        for         => undef,
        uid         => undef,
        column      => undef,
        classcolumn => undef,
        @_,
    );
    my $uid = delete $args{for};
    push @{$self->{Pending}{$uid}}, \%args;
}

sub Import {
    my $self = shift;
    my @files = @_;

    no warnings 'redefine';
    local *RT::Ticket::Load = sub {
        my $self = shift;
        my $id   = shift;
        $self->LoadById( $id );
        return $self->Id;
    };

    for my $f (@files) {
        open(my $fh, "<", $f) or die "Can't read $f: $!";
        while (not eof($fh)) {
            my $loaded = Storable::fd_retrieve($fh);
            my ($class, $uid, $data) = @{$loaded};

            next unless $class->PreInflate( $self, $uid, $data );

            my $obj = $class->new( RT->SystemUser );
            my ($id, $msg) = $obj->DBIx::SearchBuilder::Record::Create(
                %{$data}
            );
            unless ($id) {
                require Data::Dumper;
                warn "Failed to create $uid: $msg\n" . Dumper($data);
                next;
            }

            $self->{ObjectCount}{$class}++;
            $self->Resolve( $uid => $class, $id );
        }
    }

    # Anything we didn't see is an error
    if (keys %{$self->{Pending}}) {
        my @missing = sort keys %{$self->{Pending}};
        warn "The following UIDs were expected but never observed: @missing";
    }

    # Return creation counts
    return %{ $self->{ObjectCount} };
}

1;
