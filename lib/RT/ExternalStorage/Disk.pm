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

use warnings;
use strict;

package RT::ExternalStorage::Disk;

use File::Path qw//;

use Role::Basic qw/with/;
with 'RT::ExternalStorage::Backend';

sub Path {
    my $self = shift;
    return $self->{Path};
}

sub Init {
    my $self = shift;

    if (not $self->Path) {
        RT->Logger->error("Required option 'Path' not provided for Disk external storage.");
        return;
    } elsif (not -e $self->Path) {
        RT->Logger->error("Path provided for Disk external storage (".$self->Path.") does not exist");
        return;
    }

    return $self;
}

sub IsWriteable {
    my $self = shift;

    if (not -w $self->Path) {
        return (undef, "Path provided for local storage (".$self->Path.") is not writable");
    }

    return (1);
}

sub Get {
    my $self = shift;
    my ($sha) = @_;

    $sha =~ m{^(...)(...)(.*)};
    my $path = $self->Path . "/$1/$2/$3";

    return (undef, "File does not exist") unless -e $path;

    open(my $fh, "<", $path) or return (undef, "Cannot read file on disk: $!");
    my $content = do {local $/; <$fh>};
    $content = "" unless defined $content;
    close $fh;

    return ($content);
}

sub Store {
    my $self = shift;
    my ($sha, $content, $attachment) = @_;

    # fan out to avoid one gigantic directory which slows down all file access
    $sha =~ m{^(...)(...)(.*)};
    my $dir  = $self->Path . "/$1/$2";
    my $path = "$dir/$3";

    return ($sha) if -f $path;

    File::Path::make_path($dir, {error => \my $err});
    return (undef, "Making directory failed") if @{$err};

    open( my $fh, ">:raw", $path ) or return (undef, "Cannot write file on disk: $!");
    print $fh $content or return (undef, "Cannot write file to disk: $!");
    close $fh or return (undef, "Cannot write file to disk: $!");

    return ($sha);
}

sub DownloadURLFor {
    return;
}

=head1 NAME

RT::ExternalStorage::Disk - On-disk storage of attachments

=head1 SYNOPSIS

    Set(%ExternalStorage,
        Type => 'Disk',
        Path => '/opt/rt4/var/attachments',
    );

=head1 DESCRIPTION

This storage option places attachments on disk under the given C<Path>,
uncompressed.  The files are de-duplicated when they are saved; as such,
if the same file appears in multiple transactions, only one copy will be
stored on disk.

The C<Path> must be readable by the web server, and writable by the
C<sbin/rt-externalize-attachments> script.  Because the majority of the
attachments are in the filesystem, a simple database backup is thus
incomplete.  It is B<extremely important> that I<backups include the
on-disk attachments directory>.

Files also C<must not be modified or removed>; doing so may cause
internal inconsistency.

=cut

RT::Base->_ImportOverlays();

1;
