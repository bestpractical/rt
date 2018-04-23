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

sub AccessToken {
    my $self = shift;
    return $self->{AccessToken};
}

sub Init {
    my $self = shift;

    {
        # suppress given/warn is experimental warnings from File::Dropbox 0.6
        # https://rt.cpan.org/Ticket/Display.html?id=108107

        my $original_warn_handler = $SIG{__WARN__};
        local $SIG{__WARN__} = sub {
            return if $_[0] =~ /(given|when) is experimental/;

            # Avoid reporting this anonymous call frame as the source of the warning.
            goto &$original_warn_handler;
        };

        if (not File::Dropbox->require) {
            RT->Logger->error("Required module File::Dropbox is not installed");
            return;
        } elsif (not $self->AccessToken) {
            RT->Logger->error("Required option 'AccessToken' not provided for Dropbox external storage. See the documentation for " . __PACKAGE__ . " for setting up this integration.");
            return;
        }
    }


    my $dropbox = File::Dropbox->new(
        oauth2       => 1,
        access_token => $self->AccessToken,
        root         => 'sandbox',
        furlopts     => { timeout => 60 },
    );
    $self->Dropbox($dropbox);

    return $self;
}

sub Get {
    my $self = shift;
    my ($sha) = @_;

    my $dropbox = $self->Dropbox;

    open( $dropbox, "<", $sha)
        or return (undef, "Failed to retrieve file from dropbox: $!");
    my $content = do {local $/; <$dropbox>};
    close $dropbox;

    return ($content);
}

sub Store {
    my $self = shift;
    my ($sha, $content, $attachment) = @_;

    my $dropbox = $self->Dropbox;

    # No-op if the path exists already.  This forces a metadata read.
    return ($sha) if open( $dropbox, "<", $sha);

    open( $dropbox, ">", $sha )
        or return (undef, "Open for write on dropbox failed: $!");
    print $dropbox $content
        or return (undef, "Write to dropbox failed: $!");
    close $dropbox
        or return (undef, "Flush to dropbox failed: $!");

    return ($sha);
}

sub DownloadURLFor {
    return;
}

=head1 NAME

RT::ExternalStorage::Dropbox - Store files in the Dropbox cloud

=head1 SYNOPSIS

    Set(%ExternalStorage,
        Type => 'Dropbox',
        AccessToken => '...',
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

Choose B<Dropbox API app> as the type of app.

=item 4.

Choose B<Yes>, your application only needs access to files it creates.

=item 5.

Enter a descriptive name -- C<Request Tracker files> is fine.

=item 6.

Under C<Generated access token>, click the C<Generate> button.

=item 7.

Copy the provided value into your F<RT_SiteConfig.pm> file as the
C<AccessToken>:

    Set(%ExternalStorage,
        Type => 'Dropbox',
        AccessToken => '...',   # Replace the value here, between the quotes
    );

=back

=cut

RT::Base->_ImportOverlays();

1;
