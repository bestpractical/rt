# BEGIN BPS TAGGED BLOCK {{{
#
# COPYRIGHT:
#
# This software is Copyright (c) 1996-2023 Best Practical Solutions, LLC
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

package RT::Test::FTS;

require Test::More;
require RT::Test;

=head1 DESCRIPTION

RT::Test::FTS - test suite utilities for testing with Full Text Search enabled

=head1 FUNCTIONS

=head2 setup_indexing

    RT::Test::FTS->setup_indexing;

Runs rt-setup-fulltext-index in silent mode with defaults.

=cut

sub setup_indexing {
    local $Test::Builder::Level = $Test::Builder::Level + 1;

    my $self = shift;
    my %args = (
        'no-ask'       => 1,
        command        => $RT::SbinPath . '/rt-setup-fulltext-index',
        dba            => $ENV{'RT_DBA_USER'},
        'dba-password' => $ENV{'RT_DBA_PASSWORD'},
    );
    my ( $exit_code, $output ) = RT::Test->run_and_capture(%args);
    Test::More::ok( !$exit_code, "setted up index" )
        or Test::More::diag("output: $output");
}

=head2 sync_index

    RT::Test::FTS->sync_index;

Runs rt-fulltext-indexer to update index, run after creating attachments
before executing searches.

=cut

sub sync_index {
    local $Test::Builder::Level = $Test::Builder::Level + 1;

    my $self = shift;
    my %args = ( command => $RT::SbinPath . '/rt-fulltext-indexer', );
    my ( $exit_code, $output ) = RT::Test->run_and_capture(%args);
    Test::More::ok( !$exit_code, "setted up index" )
        or Test::More::diag("output: $output");
}

RT::Base->_ImportOverlays();

1;
