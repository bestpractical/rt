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

package RT::ExternalStorage;

require RT::ExternalStorage::Backend;

=head1 NAME

RT::ExternalStorage - Store attachments outside the database

=head1 SYNOPSIS

    Set(%ExternalStorage,
        Type => 'Disk',
        Path => '/opt/rt4/var/attachments',
    );

=head1 DESCRIPTION

By default, RT stores attachments in the database.  ExternalStorage moves
all attachments that RT does not need efficient access to (which include
textual content and images) to outside of the database.  This may either
be on local disk, or to a cloud storage solution.  This decreases the
size of RT's database, in turn decreasing the burden of backing up RT's
database, at the cost of adding additional locations which must be
configured or backed up.  Attachment storage paths are calculated based
on file contents; this provides de-duplication.

The files are initially stored in the database when RT receives
them; this guarantees that the user does not need to wait for
the file to be transferred to disk or to the cloud, and makes it
durable to transient failures of cloud connectivity.  The provided
C<sbin/rt-externalize-attachments> script, to be run regularly via cron,
takes care of moving attachments out of the database at a later time.

=head1 SETUP

=head2 Edit F</opt/rt4/etc/RT_SiteConfig.pm>

You will need to configure the C<%ExternalStorage> option,
depending on how and where you want your data stored.

RT comes with a number of possible storage backends; see the
documentation in each for necessary configuration details:

=over

=item L<RT::ExternalStorage::Disk>

=item L<RT::ExternalStorage::Dropbox>

=item L<RT::ExternalStorage::AmazonS3>

=back

=head2 Restart your webserver

Restarting the webserver before the next step (extracting existing
attachments) is important to ensure that files remain available as they
are extracted.

=head2 Extract existing attachments

Run C<sbin/rt-externalize-attachments>; this may take some time, depending
on the existing size of the database.  This task may be safely cancelled
and re-run to resume.

=head2 Schedule attachments extraction

Schedule C<sbin/rt-externalize-attachments> to run at regular intervals via
cron.  For instance, the following F</etc/cron.d/rt> entry will run it
daily, which may be good to concentrate network or disk usage to times
when RT is less in use:

    0 0 * * * root /opt/rt4/sbin/rt-externalize-attachments

=head1 CAVEATS

This feature is not currently compatible with RT's C<shredder> tool;
attachments which are shredded will not be removed from external
storage.

=cut

RT::Base->_ImportOverlays();

1;
