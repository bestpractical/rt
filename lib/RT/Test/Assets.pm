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

use strict;
use warnings;

package RT::Test::Assets;
use base 'RT::Test';

our @EXPORT = qw(create_catalog create_asset create_assets create_cf apply_cfs);

sub import {
    my $class = shift;
    my %args  = @_;

    $class->SUPER::import( %args );
    __PACKAGE__->export_to_level(1);
}

sub diag {
    Test::More::diag(@_) if $ENV{TEST_VERBOSE};
}

sub create_catalog {
    my %info  = @_;
    my $catalog = RT::Catalog->new( RT->SystemUser );
    my ($id, $msg) = $catalog->Create( %info );
    if ($id) {
        diag("Created catalog #$id: " . $catalog->Name);
        return $catalog;
    } else {
        my $spec = join "/", map { "$_=$info{$_}" } keys %info;
        RT->Logger->error("Failed to create catalog ($spec): $msg");
        return;
    }
}

sub create_asset {
    my %info  = @_;
    my $asset = RT::Asset->new( RT->SystemUser );
    my ($id, $msg) = $asset->Create( %info );
    if ($id) {
        diag("Created asset #$id: " . $asset->Name);
        return $asset;
    } else {
        my $spec = join "/", map { "$_=$info{$_}" } keys %info;
        RT->Logger->error("Failed to create asset ($spec): $msg");
        return;
    }
}

sub create_assets {
    my $error = 0;
    for my $info (@_) {
        create_asset(%$info)
            or $error++;
    }
    return not $error;
}

sub create_cf {
    my %args = (
        Name        => "Test Asset CF ".($$ + rand(1024)),
        Type        => "FreeformSingle",
        LookupType  => RT::Asset->CustomFieldLookupType,
        @_,
    );
    my $cf = RT::CustomField->new( RT->SystemUser );
    my ($ok, $msg) = $cf->Create(%args);
    RT->Logger->error("Can't create CF: $msg") unless $ok;
    return $cf;
}

sub apply_cfs {
    my $success = 1;
    for my $cf (@_) {
        my ($ok, $msg) = $cf->AddToObject( RT::Catalog->new(RT->SystemUser) );
        if (not $ok) {
            RT->Logger->error("Couldn't apply CF: $msg");
            $success = 0;
        }
    }
    return $success;
}

1;
