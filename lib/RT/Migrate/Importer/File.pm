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

package RT::Migrate::Importer::File;

use strict;
use warnings;
use base qw(RT::Migrate::Importer);

sub Init {
    my $self = shift;
    my %args = (
        Directory => undef,
        Resume    => undef,
        @_
    );

    # Directory is required
    die "Directory is required" unless $args{Directory};
    die "Invalid path $args{Directory}" unless -d $args{Directory};
    $self->{Directory} = $args{Directory};

    # Load metadata, if present
    if (-e "$args{Directory}/rt-serialized") {
        my $dat = eval { Storable::retrieve("$args{Directory}/rt-serialized"); }
            or die "Failed to load metadata" . ($@ ? ": $@" : "");
        $self->LoadMetadata($dat);
    }

    # Support resuming
    $self->{Statefile}  = $args{Statefile} || "$args{Directory}/partial-import";
    unlink $self->{Statefile}
        if -f $self->{Statefile} and not $args{Resume};

    return $self->SUPER::Init(@_);
}

sub Import {
    my $self = shift;
    my $dir = $self->{Directory};

    if ($self->{Metadata} and $self->{Metadata}{Files}) {
        $self->{Files} = [ map {s|^.*/|$dir/|;$_} @{$self->{Metadata}{Files}} ];
    } else {
        $self->{Files} = [ <$dir/*.dat> ];
    }
    $self->{Files} = [ map {File::Spec->rel2abs($_)} @{ $self->{Files} } ];

    $self->RestoreState( $self->{Statefile} );

    local $SIG{  INT  } = sub { $self->{INT} = 1 };
    local $SIG{__DIE__} = sub { warn "\n", @_; $self->SaveState; exit 1 };

    $self->{Progress}->(undef) if $self->{Progress};
    while (@{$self->{Files}}) {
        $self->{Filename} = shift @{$self->{Files}};
        open(my $fh, "<", $self->{Filename})
            or die "Can't read $self->{Filename}: $!";
        if ($self->{Seek}) {
            seek($fh, $self->{Seek}, 0)
                or die "Can't seek to $self->{Seek} in $self->{Filename}";
            $self->{Seek} = undef;
        }
        while (not eof($fh)) {
            $self->{Position} = tell($fh);

            # Stop when we're at a good stopping point
            die "Caught interrupt, quitting.\n" if $self->{INT};

            $self->ReadStream( $fh );
        }
    }

    $self->CloseStream;

    # Return creation counts
    return $self->ObjectCount;
}

sub List {
    my $self = shift;
    my $dir = $self->{Directory};

    my %found = ( "RT::System" => 1 );
    my @files = ($self->{Metadata} and $self->{Metadata}{Files}) ?
        @{ $self->{Metadata}{Files} } : <$dir/*.dat>;
    @files = map {File::Spec->rel2abs($_)} @files;

    for my $filename (@files) {
        open(my $fh, "<", $filename)
            or die "Can't read $filename: $!";
        while (not eof($fh)) {
            my $loaded = Storable::fd_retrieve($fh);
            if (ref $loaded eq "HASH") {
                $self->LoadMetadata( $loaded );
                next;
            }

            if ($self->{DumpObjects}) {
                print STDERR Data::Dumper::Dumper($loaded), "\n"
                    if $self->{DumpObjects}{ $loaded->[0] };
            }

            my ($class, $uid, $data) = @{$loaded};
            $self->{ObjectCount}{$class}++;
            $found{$uid} = 1;
            delete $self->{Pending}{$uid};
            for (grep {ref $data->{$_}} keys %{$data}) {
                my $uid_ref = ${ $data->{$_} };
                unless (defined $uid_ref) {
                    push @{ $self->{Invalid} }, { uid => $uid, column => $_ };
                    next;
                }
                next if $found{$uid_ref};
                next if $uid_ref =~ /^RT::Principal-/;
                push @{$self->{Pending}{$uid_ref} ||= []}, {uid => $uid};
            }
        }
    }

    return $self->ObjectCount;
}

sub RestoreState {
    my $self = shift;
    my ($statefile) = @_;
    return unless $statefile && -f $statefile;

    my $state = Storable::retrieve( $self->{Statefile} );
    $self->{$_} = $state->{$_} for keys %{$state};
    unlink $self->{Statefile};

    print STDERR "Resuming partial import...\n";
    sleep 2;
    return 1;
}

sub SaveState {
    my $self = shift;

    my %data;
    unshift @{$self->{Files}}, $self->{Filename};
    $self->{Seek} = $self->{Position};
    $data{$_} = $self->{$_} for
        qw/Filename Seek Position Files
           Organization ObjectCount
           NewQueues NewCFs
           SkipTransactions Pending Invalid
           UIDs
           OriginalId ExcludeOrganization Clone
          /;
    Storable::nstore(\%data, $self->{Statefile});

    print STDERR <<EOT;

Importer state has been written to the file:
    $self->{Statefile}

It may be possible to resume the import by re-running rt-importer.
EOT
}

1;
