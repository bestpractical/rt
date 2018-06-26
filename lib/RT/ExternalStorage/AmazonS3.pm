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

package RT::ExternalStorage::AmazonS3;

use Role::Basic qw/with/;
with 'RT::ExternalStorage::Backend';

sub S3 {
    my $self = shift;
    if (@_) {
        $self->{S3} = shift;
    }
    return $self->{S3};
}

sub Bucket {
    my $self = shift;
    return $self->{Bucket};
}

sub AccessKeyId {
    my $self = shift;
    return $self->{AccessKeyId};
}

sub SecretAccessKey {
    my $self = shift;
    return $self->{SecretAccessKey};
}

sub BucketObj {
    my $self = shift;
    return $self->S3->bucket($self->Bucket);
}

sub Init {
    my $self = shift;

    if (not Amazon::S3->require) {
        RT->Logger->error("Required module Amazon::S3 is not installed");
        return;
    }

    for my $key (qw/AccessKeyId SecretAccessKey Bucket/) {
        if (not $self->$key) {
            RT->Logger->error("Required option '$key' not provided for AmazonS3 external storage. See the documentation for " . __PACKAGE__ . " for setting up this integration.");
            return;
        }
    }

    my %args = (
        aws_access_key_id     => $self->AccessKeyId,
        aws_secret_access_key => $self->SecretAccessKey,
        retry                 => 1,
    );
    $args{host} = $self->{Host} if $self->{Host};

    my $S3 = Amazon::S3->new(\%args);
    $self->S3($S3);

    my $buckets = $S3->bucket( $self->Bucket );
    unless ( $buckets ) {
        RT->Logger->error("Can't list buckets of AmazonS3: ".$S3->errstr);
        return;
    }

    my @buckets = $buckets->{buckets} ? @{$buckets->{buckets}} : ($buckets);

    unless ( grep {$_->bucket eq $self->Bucket} @buckets ) {
        my $ok = $S3->add_bucket( {
            bucket    => $self->Bucket,
            acl_short => 'private',
        } );
        if ($ok) {
            RT->Logger->debug("Created new bucket '".$self->Bucket."' on AmazonS3");
        }
        else {
            RT->Logger->error("Can't create new bucket '".$self->Bucket."' on AmazonS3: ".$S3->errstr);
            return;
        }
    }

    return $self;
}

sub Get {
    my $self = shift;
    my ($sha) = @_;

    my $ok = $self->BucketObj->get_key( $sha );
    return (undef, "Could not retrieve from AmazonS3:" . $self->S3->errstr)
        unless $ok;
    return ($ok->{value});
}

sub Store {
    my $self = shift;
    my ($sha, $content, $attachment) = @_;

    # No-op if the path exists already
    return ($sha) if $self->BucketObj->head_key( $sha );

    # Without content_type, S3 can guess wrong and cause attachments downloaded
    # via a link to have a content type of binary/octet-stream
    $self->BucketObj->add_key(
        $sha => $content,
        { content_type => $attachment->ContentType }
    ) or return (undef, "Failed to write to AmazonS3: " . $self->S3->errstr);

    return ($sha);
}

sub DownloadURLFor {
    my $self = shift;
    my $object = shift;

    my $column = $object->isa('RT::Attachment') ? 'Content' : 'LargeContent';
    my $digest = $object->__Value($column);

    # "If you make a request to the http://BUCKET.s3.amazonaws.com
    # endpoint, the DNS has sufficient information to route your request
    # directly to the region where your bucket resides."
    return "https://" . $self->Bucket . ".s3.amazonaws.com/" . $digest;
}

=head1 NAME

RT::ExternalStorage::AmazonS3 - Store files in Amazon's S3 cloud

=head1 SYNOPSIS

    Set(%ExternalStorage,
        Type            => 'AmazonS3',
        AccessKeyId     => '...',
        SecretAccessKey => '...',
        Bucket          => '...',
    );

=head1 DESCRIPTION

This storage option places attachments in the S3 cloud file storage
service.  The files are de-duplicated when they are saved; as such, if
the same file appears in multiple transactions, only one copy will be
stored in S3.

Files in S3 B<must not be modified or removed>; doing so may cause
internal inconsistency.  It is also important to ensure that the S3
account used maintains sufficient funds for your RT's B<storage and
bandwidth> needs.

=head1 SETUP

In order to use this storage type, you must grant RT access to your
S3 account.

=over

=item 1.

Log into Amazon S3, L<https://aws.amazon.com/s3/>, as the account you wish
to store files under.

=item 2.

Navigate to "Security Credentials" under your account name in the menu bar.

=item 3.

Open the "Access Keys" pane.

=item 4.

Click "Create New Access Key".

=item 5.

Copy the provided values for Access Key ID and Secret Access Key into
 your F<RT_SiteConfig.pm> file:

    Set(%ExternalStorage,
        Type            => 'AmazonS3',
        AccessKeyId     => '...', # Put Access Key ID between quotes
        SecretAccessKey => '...', # Put Secret Access Key between quotes
        Bucket          => '...',
    );

=item 6.

Set up a Bucket for RT to use. You can either create and configure it
in the S3 web interface, or let RT create one itself. Either way, tell
RT what bucket name to use in your F<RT_SiteConfig.pm> file:

    Set(%ExternalStorage,
        Type            => 'AmazonS3',
        AccessKeyId     => '...',
        SecretAccessKey => '...',
        Bucket          => '...', # Put bucket name between quotes
    );

=item 7.

You may specify a C<Host> option in C<Set(%ExternalStorage, ...);> to connect
to an endpoint other than L<Amazon::S3>'s default of C<s3.amazonaws.com>.

=back

=head2 Direct Linking

This storage engine supports direct linking. This means that RT can link
I<directly> to S3 when listing attachments, showing image previews, etc.
This relieves some bandwidth pressure from RT because ordinarily it would
have to download each attachment from S3 to be able to serve it.

To enable direct linking you must first make all content in your bucket
publicly viewable.

B<Beware that this could have serious implications for billing and
privacy>. RT cannot enforce its access controls for content on S3. This
is tempered somewhat by the fact that users must be able to guess the
SHA-256 digest of the file to be able to access it. But there is nothing
stopping someone from tweeting a URL to a file hosted on your S3. These
concerns do not arise when using an RT-mediated link to S3, since RT
uses an access key to upload to and download from S3.

To make all content in an S3 bucket publicly viewable, navigate to
the bucket in the S3 web UI. Select the "Properties" tab and inside
"Permissions" there is a button to "Add bucket policy". Paste the
following content in the provided textbox:

    {
        "Version": "2008-10-17",
        "Statement": [
            {
                "Sid": "AllowPublicRead",
                "Effect": "Allow",
                "Principal": {
                    "AWS": "*"
                },
                "Action": "s3:GetObject",
                "Resource": "arn:aws:s3:::BUCKET/*"
            }
        ]
    }

Replace C<BUCKET> with the bucket name that is used by your RT instance.

Finally, set C<$ExternalStorageDirectLink> to 1 in your
F<RT_SiteConfig.pm> file:

    Set($ExternalStorageDirectLink, 1);

=head1 TROUBLESHOOTING

=head2 Issues Connecting to the Amazon Bucket

Here are some things to check if you receive errors connecting to Amazon S3.

=over

=item *

Double check all of the configuration parameters, including the bucket name. Remember to restart
the server after changing values for RT to load new settings.

=item *

If you manually created a bucket, make sure it is in your default region. Trying to access
a bucket in a different region may result in 400 errors.

=item *

Check the permissions on the bucket and make sure they are sufficient for the user RT is
connecting as to upload and access files. If you are using the direct link option, you will
need to open permissions further for users to access the attachment via the direct link.

=back

=cut

RT::Base->_ImportOverlays();

1;
