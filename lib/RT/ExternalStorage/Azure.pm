# BEGIN BPS TAGGED BLOCK {{{
#
# COPYRIGHT:
#
# This software is Copyright (c) 1996-2019 Best Practical Solutions, LLC
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

package RT::ExternalStorage::Azure;

use Role::Basic qw/with/;
with 'RT::ExternalStorage::Backend';

sub Azure {
    my $self = shift;
    if (@_) {
        $self->{Azure} = shift;
    }
    return $self->{Azure};
}

sub AccountName {
    my $self = shift;
    return $self->{AccountName};
}

sub AccountKey {
    my $self = shift;
    return $self->{AccountKey};
}

sub ContainerName {
    my $self = shift;
    return $self->{ContainerName};
}

sub Init {
    my $self = shift;

    if (not Net::Azure::StorageClient->require) {
        RT->Logger->error("Required module Net::Azure::StorageClient is not installed");
        return;
    }

    for my $key (qw/AccountName AccountKey ContainerName/) {
        if (not $self->$key) {
            RT->Logger->error("Required option '$key' not provided for Azure external storage. See the documentation for " . __PACKAGE__ . " for setting up this integration.");
            return;
        }
    }

    my %args = (
        type => 'Blob',
        account_name  => $self->AccountName,
        primary_access_key => $self->AccountKey,
        container_name => $self->ContainerName,
        protocol => 'https',
        api_version => '2012-02-12',
    );

    my $Azure = Net::Azure::StorageClient->new(%args);
    $self->Azure($Azure);

    return $self;
}

sub Get {
    my $self = shift;
    my ($sha) = @_;

    my $response = $self->Azure->get_blob( $sha );
    return (undef, "Could not retrieve from Azure: " . $response->message)
        if $response->is_error;
    return ($response->content);
}

sub Store {
    my $self = shift;
    my ($sha, $content, $attachment) = @_;

    # No-op if the path exists already
    my $response = $self->Azure->get_blob_properties( $sha );
    return ($sha) unless $response->is_error;

    # Without content_type, Azure can guess wrong and cause attachments downloaded
    # via a link to have a content type of application/octet-stream
    $response = $self->Azure->put_blob(
        $sha => $content,
        { 'content-type' => $attachment->ContentType },
    );
    return (undef, "Failed to write to Azure: " . $response->message)
        if $response->is_error;

    return ($sha);
}

sub DownloadURLFor {
    return;
}

=head1 NAME

RT::ExternalStorage::Azure - Store files in Azure cloud

=head1 SYNOPSIS

    Set(%ExternalStorage,
        Type            => 'Azure',
        AccountName     => '...',
        AccountKey      => '...',
        ContainerName   => '...',
    );

=head1 DESCRIPTION

This storage option places attachments in the Azure cloud file storage
service.  The files are de-duplicated when they are saved; as such, if
the same file appears in multiple transactions, only one copy will be
stored in Azure.

Files in Azure B<must not be modified or removed>; doing so may cause
internal inconsistency.  It is also important to ensure that the Azure
account used maintains sufficient funds for your RT's B<storage and
bandwidth> needs.

=head1 SETUP

In order to use this storage type, you must grant RT access to your
Azure Storage account.

=over

=item 1.

Log into Azure, L<https://portal.azure.com/>, and create or open a
"Storage account" you wish to store files under.

=item 2.

Navigate to "Access Keys" in the Settings for the Storage account.

=item 3.

Open the "Access Keys" pane.

=item 4.

Read about key generation and if necessary, generate a key.

=item 5.

Copy the "Storage account name" and one of the provided "Key" values into
 your F<RT_SiteConfig.pm> file:

    Set(%ExternalStorage,
        Type            => 'Azure',
        AccountName     => '...', # Put Storage ccount name between quotes
        AccountKey      => '...', # Put Secret Access Key between quotes
        ContainerName   => '...',
    );

=item 6.

Set up a Container for RT to use. You can either create and configure it
in the Azure web interface, or let RT create one itself. Either way, tell
RT what Container name to use in your F<RT_SiteConfig.pm> file:

    Set(%ExternalStorage,
        Type            => 'Azure',
        AccountName     => '...',
        AccountKey      => '...',
        ContainerName   => '...', # Put Container name between quotes
    );

=back

=head1 TROUBLESHOOTING

=head2 Issues Connecting to the Azure storage cloud

Here are some things to check if you receive errors connecting to Azure.

=over

=item *

Double check all of the configuration parameters, including the container name. Remember to restart
the server after changing values for RT to load new settings.

=item *

Check the permissions on the container and make sure they are sufficient for the user RT is
connecting as to upload and access files.

=back

=cut

RT::Base->_ImportOverlays();

1;
