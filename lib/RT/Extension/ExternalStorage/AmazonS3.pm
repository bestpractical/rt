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

package RT::Extension::ExternalStorage::AmazonS3;

use Role::Basic qw/with/;
with 'RT::Extension::ExternalStorage::Backend';

our( $S3, $BUCKET);
sub Init {
    my $self = shift;
    my %self = %{$self};

    if (not Amazon::S3->require) {
        RT->Logger->error("Required module Amazon::S3 is not installed");
        return;
    } elsif (not $self{AccessKeyId}) {
        RT->Logger->error("AccessKeyId not provided for AmazonS3");
        return;
    } elsif (not $self{SecretAccessKey}) {
        RT->Logger->error("SecretAccessKey not provided for AmazonS3");
        return;
    } elsif (not $self{Bucket}) {
        RT->Logger->error("Bucket not provided for AmazonS3");
        return;
    }


    $S3 = Amazon::S3->new( {
        aws_access_key_id     => $self{AccessKeyId},
        aws_secret_access_key => $self{SecretAccessKey},
        retry                 => 1,
    } );

    my $buckets = $S3->bucket( $self{Bucket} );
    unless ( $buckets ) {
        RT->Logger->error("Can't list buckets of AmazonS3: ".$S3->errstr);
        return;
    }
    unless ( grep {$_->bucket eq $self{Bucket}} @{$buckets->{buckets}} ) {
        my $ok = $S3->add_bucket( {
            bucket    => $self{Bucket},
            acl_short => 'private',
        } );
        unless ($ok) {
            RT->Logger->error("Can't create new bucket '$self{Bucket}' on AmazonS3: ".$S3->errstr);
            return;
        }
    }

    return $self;
}

sub Get {
    my $self = shift;
    my ($sha) = @_;

    my $ok = $S3->bucket($self->{Bucket})->get_key( $sha );
    return (undef, "Could not retrieve from AmazonS3:" . $S3->errstr)
        unless $ok;
    return ($ok->{value});
}

sub Store {
    my $self = shift;
    my ($sha, $content) = @_;

    # No-op if the path exists already
    return (1) if $S3->bucket($self->{Bucket})->head_key( $sha );

    $S3->bucket($self->{Bucket})->add_key(
        $sha => $content
    ) or return (undef, "Failed to write to AmazonS3: " . $S3->errstr);

    return (1);
}

=head1 NAME

RT::Extension::ExternalStorage::Dropbox - Store files in the Dropbox cloud

=head1 SYNOPSIS

    Set(%ExternalStorage,
        Type => 'Dropbox',
        AccessToken => '...',
    );

=head1 DESCRIPTION

This storage option places attachments in the Dropbox shared file
service.  The files are de-duplicated when they are saved; as such, if
the same file appears in multiple transactions, only one copy will be
stored on in Dropbox.

Files in Dropbox C<must not be modified or removed>; doing so may cause
internal inconsistency.

=head1 SETUP

In order to use this stoage type, a new application must be registered
with Dropbox:

=over

=item 1.

Log into Dropbox as the user you wish to store files as.

=item 2.

Click C<Create app> on L<https://www.dropbox.com/developers/apps>

=item 3.

Choose B<Dropbox API app> as the type of app.

=item 4.

Choose the B<Files and datastores> as the type of data to store.

=item 5.

Choose B<Yes>, your application only needs access to files it creates.

=item 6.

Enter a descriptive name -- C<Request Tracker files> is fine.

=item 7.

Under C<Generated access token>, click the C<Generate> button.

=item 8.

Copy the provided value into your F<RT_SiteConfig.pm> file as the
C<AccessToken>:

    Set(%ExternalStorage,
        Type => 'Dropbox',
        AccessToken => '...',   # Replace the value here, between the quotes
    );

=back

=cut

1;
