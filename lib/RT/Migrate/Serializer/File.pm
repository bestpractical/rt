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

package RT::Migrate::Serializer::File;

use strict;
use warnings;

use base 'RT::Migrate::Serializer';

sub Init {
    my $self = shift;

    my %args = (
        Directory   => undef,
        Force       => undef,
        MaxFileSize => 32,

        @_,
    );

    # Set up the output directory we'll be writing to
    my ($y,$m,$d) = (localtime)[5,4,3];
    $args{Directory} = $RT::Organization .
        sprintf(":%d-%02d-%02d",$y+1900,$m+1,$d)
        unless defined $args{Directory};
    system("rm", "-rf", $args{Directory}) if $args{Force};
    die "Output directory $args{Directory} already exists"
        if -d $args{Directory};
    mkdir $args{Directory}
        or die "Can't create output directory $args{Directory}: $!\n";
    $self->{Directory} = delete $args{Directory};

    # How many megabytes each chunk should be, approximitely
    $self->{MaxFileSize} = delete $args{MaxFileSize};

    # Which file we're writing to
    $self->{FileCount} = 1;

    $self->SUPER::Init(@_);
}

sub Metadata {
    my $self = shift;
    return $self->SUPER::Metadata(
        Files => [ $self->Files ],
        @_,
    )
}

sub Export {
    my $self = shift;

    # Set up our output file
    $self->OpenFile;

    # Write the initial metadata
    $self->InitStream;

    # Walk the objects
    $self->Walk( @_ );

    # Close everything back up
    $self->CloseFile;

    # Write the summary file
    Storable::nstore(
        $self->Metadata( Final => 1 ),
        $self->Directory . "/rt-serialized"
    );

    return $self->ObjectCount;
}

sub Visit {
    my $self = shift;

    # Rotate if we get too big
    my $maxsize = 1024 * 1024 * $self->{MaxFileSize};
    $self->RotateFile if tell($self->{Filehandle}) > $maxsize;

    # Serialize it
    $self->SUPER::Visit( @_ );
}


sub Files {
    my $self = shift;
    return @{ $self->{Files} };
}

sub Filename {
    my $self = shift;
    return sprintf(
        "%s/%03d.dat",
        $self->{Directory},
        $self->{FileCount}
    );
}

sub Directory {
    my $self = shift;
    return $self->{Directory};
}

sub OpenFile {
    my $self = shift;
    open($self->{Filehandle}, ">", $self->Filename)
        or die "Can't write to file @{[$self->Filename]}: $!";
    push @{$self->{Files}}, $self->Filename;
}

sub CloseFile {
    my $self = shift;
    close($self->{Filehandle})
        or die "Can't close @{[$self->Filename]}: $!";
    $self->{FileCount}++;
}

sub RotateFile {
    my $self = shift;
    $self->CloseFile;
    $self->OpenFile;
}

1;
