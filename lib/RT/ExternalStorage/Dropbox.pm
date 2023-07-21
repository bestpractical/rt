# BEGIN BPS TAGGED BLOCK {{{
#
# COPYRIGHT:
#
# This software is Copyright (c) 1996-2024 Best Practical Solutions, LLC
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

package RT::ExternalStorage::Dropbox;

use Role::Basic qw/with/;
with 'RT::ExternalStorage::Backend';

sub Dropbox {
    my $self = shift;
    if (@_) {
        $self->{Dropbox} = shift;
    }
    return $self->{Dropbox};
}

sub AppKey {
    my $self = shift;
    return $self->{AppKey};
}

sub AppSecret {
    my $self = shift;
    return $self->{AppSecret};
}

sub RefreshToken {
    my $self = shift;
    return $self->{RefreshToken};
}

sub Init {
    my $self = shift;

    if ( not WebService::Dropbox->require ) {
        RT->Logger->error("Required module WebService::Dropbox is not installed");
        return;
    }
    WebService::Dropbox->import;
    for my $item (qw/AppKey AppSecret RefreshToken/) {
        next if $self->$item;
        RT->Logger->error(
                  "Required option '$item' not provided for Dropbox external storage. See the documentation for "
                . __PACKAGE__
                . " for setting up this integration." );
        return;
    }

    my $dropbox = WebService::Dropbox->new(
        {
            key    => $self->AppKey,
            secret => $self->AppSecret,
        }
    );

    $dropbox->refresh_access_token( $self->RefreshToken );
    $self->Dropbox($dropbox);

    return $self;
}

# Dropbox requires the "/" prefix
sub _FilePath {
    my $self = shift;
    my $sha = shift;
    return "/$sha";
}

sub _PathExists {
    my $self = shift;
    my $path = shift;

    # Get rid of expected warnings when path doesn't exist
    local $SIG{__WARN__} = sub {};
    return $self->Dropbox->get_metadata($path);
}

sub Get {
    my $self = shift;
    my ($sha) = @_;
    my $path = $self->_FilePath($sha);

    my $content;
    open my $fh, '>', \$content;
    $self->Dropbox->download($path, $fh);
    close $fh;
    if ( $content ) {
        return ($content);
    }
    else {
        return ( undef, "Read $sha from dropbox failed: " . $self->Dropbox->error );
    }
}

sub Store {
    my $self = shift;
    my ($sha, $content, $attachment) = @_;

    my $path = $self->_FilePath($sha);

    # No-op if the path exists already.  This forces a metadata read.
    return ($sha) if $self->_PathExists($path);

    if ( $self->Dropbox->upload( $path, $content ) ) {
        return ($sha);
    }
    else {
        return ( undef, "Write $sha to dropbox failed: " . $self->Dropbox->error );
    }
}

sub DownloadURLFor {
    return;
}

=head1 NAME

RT::ExternalStorage::Dropbox - Store files in the Dropbox cloud

=head1 SYNOPSIS

    Set(%ExternalStorage,
        Type         => 'Dropbox',
        AccessKey    => '...',
        AccessSecret => '...',
        RefreshToken => '...',
    );

=head1 DESCRIPTION

This storage option places attachments in the Dropbox shared file
service.  The files are de-duplicated when they are saved; as such, if
the same file appears in multiple transactions, only one copy will be
stored in Dropbox.

Files in Dropbox B<must not be modified or removed>; doing so may cause
internal inconsistency.  It is also important to ensure that the Dropbox
account used has sufficient space for the attachments, and to monitor
its space usage.

=head1 SETUP

In order to use this storage type, a new application must be registered
with Dropbox:

=over

=item 1.

Log into Dropbox as the user you wish to store files as.

=item 2.

Click C<Create app> on L<https://www.dropbox.com/developers/apps>

=item 3.

Choose B<Scoped access> as the API.

=item 4.

Choose B<App folder> as the type of access.

=item 5.

Enter a descriptive name -- C<Request Tracker files> is fine.

=item 6.

After creation, grant the following permissions on Permissions tab:

    files.metadata.write
    files.metadata.read
    files.content.write
    files.content.read

=item 7.

On Settings tab, get C<App key>/C<App secret> and then access the following
URL:

    https://www.dropbox.com/oauth2/authorize?token_access_type=offline&response_type=code&client_id=<App key>

Where <App key> is the one you got earlier.

After a confirmation page, you will receive a code, use it along with C<App
key> and C<App secret> in the following command and run it:

    curl https://api.dropbox.com/oauth2/token -d code=<received code> -d grant_type=authorization_code -u <App key>:<App secret>

The response shall contain C<refresh_token> value.

=item 8.

Copy the provided values into your F<RT_SiteConfig.pm>:

    Set(%ExternalStorage,
        Type         => 'Dropbox',
        AccessKey    => '...',
        AccessSecret => '...',
        RefreshToken => '...',       # Replace the value here, between the quotes
    );

=back

=cut

RT::Base->_ImportOverlays();

1;
