# BEGIN BPS TAGGED BLOCK {{{
#
# COPYRIGHT:
#
# This software is Copyright (c) 1996-2015 Best Practical Solutions, LLC
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

use 5.008003;
use warnings;
use strict;

package RT::Extension::ExternalStorage;

our $VERSION = '0.61';

use Digest::SHA qw//;

require RT::Extension::ExternalStorage::Backend;

=head1 NAME

RT::Extension::ExternalStorage - Store attachments outside the database

=head1 SYNOPSIS

    Set( @Plugins, 'RT::Extension::ExternalStorage' );

    Set(%ExternalStorage,
        Type => 'Disk',
        Path => '/opt/rt4/var/attachments',
    );

=head1 DESCRIPTION

By default, RT stores attachments in the database.  This extension moves
all attachments that RT does not need efficient access to (which include
textual content and images) to outside of the database.  This may either
be on local disk, or to a cloud storage solution.  This decreases the
size of RT's database, in turn decreasing the burden of backing up RT's
database, at the cost of adding additional locations which must be
configured or backed up.  Attachment storage paths are calculated based
on file contents; this provides de-duplication.

The files are initially stored in the database when RT receives them;
this guarantees that the user does not need to wait for the file to be
transferred to disk or to the cloud, and makes it durable to transient
failures of cloud connectivity.  The provided C<bin/extract-attachments>
script, to be run regularly via cron, takes care of moving attachments
out of the database at a later time.

=head1 INSTALLATION

=over

=item C<perl Makefile.PL>

=item C<make>

=item C<make install>

May need root permissions

=item Edit your F</opt/rt4/etc/RT_SiteConfig.pm>

If you are using RT 4.2 or greater, add this line:

    Plugin('RT::Extension::ExternalStorage');

For RT 4.0, add this line:

    Set(@Plugins, qw(RT::Extension::ExternalStorage));

or add C<RT::Extension::ExternalStorage> to your existing C<@Plugins> line.

You will also need to configure the C<%ExternalStorage> option,
depending on how and where you want your data stored; see
L</CONFIGURATION>.

=item Restart your webserver

Restarting the webserver before the next step (extracting existing
attachments) is important to ensure that files remain available as they
are extracted.

=item Extract existing attachments

Run C<bin/extract-attachments>; this may take some time, depending on
the existing size of the database.  This task may be safely cancelled
and re-run to resume.

=item Schedule attachments extraction

Schedule C<bin/extract-attachments> to run at regular intervals via
cron.  For instance, the following F</etc/cron.d/rt> entry will run it
daily, which may be good to concentrate network or disk usage to times
when RT is less in use:

    0 0 * * * root /opt/rt4/local/plugins/RT-Extension-ExternalStorage/bin/extract-attachments

=back

=head1 CONFIGURATION

This module comes with a number of possible backends; see the
documentation in each for necessary configuration details:

=over

=item L<RT::Extension::ExternalStorage::Disk>

=item L<RT::Extension::ExternalStorage::Dropbox>

=item L<RT::Extension::ExternalStorage::AmazonS3>

=back

=head1 CAVEATS

This extension is not currently compatibile with RT's C<shredder> tool;
attachments which are shredded will not be removed from external
storage.

=cut

our $BACKEND;
our $WRITE;
$RT::Config::META{ExternalStorage} = {
    Type => 'HASH',
    PostLoadCheck => sub {
        my $self = shift;
        my %hash = $self->Get('ExternalStorage');
        return unless keys %hash;
        $hash{Write} = $WRITE;
        $BACKEND = RT::Extension::ExternalStorage::Backend->new( %hash );
    },
};

sub Store {
    my $class = shift;
    my $content = shift;

    my $key = Digest::SHA::sha256_hex( $content );
    my ($ok, $msg) = $BACKEND->Store( $key => $content );
    return ($ok, $msg) unless defined $ok;

    return ($key);
}


package RT::Record;

no warnings 'redefine';
my $__DecodeLOB = __PACKAGE__->can('_DecodeLOB');
*_DecodeLOB = sub {
    my $self            = shift;
    my $ContentType     = shift || '';
    my $ContentEncoding = shift || 'none';
    my $Content         = shift;
    my $Filename        = @_;

    return $__DecodeLOB->($self, $ContentType, $ContentEncoding, $Content, $Filename)
        unless $ContentEncoding eq "external";

    unless ($BACKEND) {
        RT->Logger->error( "Failed to load $Content; external storage not configured" );
        return ("");
    };

    my ($ok, $msg) = $BACKEND->Get( $Content );
    unless (defined $ok) {
        RT->Logger->error( "Failed to load $Content from external storage: $msg" );
        return ("");
    }

    return $__DecodeLOB->($self, $ContentType, 'none', $ok, $Filename);
};

package RT::ObjectCustomFieldValue;

sub StoreExternally {
    my $self = shift;
    my $type = $self->CustomFieldObj->Type;
    my $length = length($self->LargeContent || '');

    return 0 if $length == 0;

    return 1 if $type eq "Binary";

    return 1 if $type eq "Image" and $length > 10 * 1024 * 1024;

    return 0;
}

package RT::Attachment;

sub StoreExternally {
    my $self = shift;
    my $type = $self->ContentType;
    my $length = $self->ContentLength;

    return 0 if $length == 0;

    if ($type =~ m{^multipart/}) {
        return 0;
    } elsif ($type =~ m{^(text|message)/}) {
        # If textual, we only store externally if it's _large_ (> 10M)
        return 1 if $length > 10 * 1024 * 1024;
        return 0;
    } elsif ($type =~ m{^image/}) {
        # Ditto images, which may be displayed inline
        return 1 if $length > 10 * 1024 * 1024;
        return 0;
    } else {
        return 1;
    }
}

=head1 AUTHOR

Best Practical Solutions, LLC E<lt>modules@bestpractical.comE<gt>

=head1 BUGS

All bugs should be reported via email to

    L<bug-RT-Extension-ExternalStorage@rt.cpan.org|mailto:bug-RT-Extension-ExternalStorage@rt.cpan.org>

or via the web at

    L<rt.cpan.org|http://rt.cpan.org/Public/Dist/Display.html?Name=RT-Extension-ExternalStorage>.

=head1 COPYRIGHT

This extension is Copyright (C) 2009-2015 Best Practical Solutions, LLC.

This is free software, licensed under:

  The GNU General Public License, Version 2, June 1991

=cut

1;
