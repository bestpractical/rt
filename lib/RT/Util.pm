# BEGIN BPS TAGGED BLOCK {{{
# 
# COPYRIGHT:
# 
# This software is Copyright (c) 1996-2009 Best Practical Solutions, LLC
#                                          <jesse@bestpractical.com>
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

package RT::Util;
use strict;
use warnings;

use base 'Exporter';
our @EXPORT = qw/safe_run_child/;

sub safe_run_child (&) {
    my $our_pid = $$;

    # situation here is wierd, running external app
    # involves fork+exec. At some point after fork,
    # but before exec (or during) code can die in a
    # child. Local is no help here as die throws
    # error out of scope and locals are reset to old
    # values. Instead we set values, eval code, check pid
    # on failure and reset values only in our original
    # process
    my $dbh = $RT::Handle->dbh;
    $dbh->{'InactiveDestroy'} = 1 if $dbh;
    $RT::Handle->{'DisconnectHandleOnDestroy'} = 0;

    my @res;
    my $want = wantarray;
    eval {
        unless ( defined $want ) {
            _safe_run_child( @_ );
        } elsif ( $want ) {
            @res = _safe_run_child( @_ );
        } else {
            @res = ( scalar _safe_run_child( @_ ) );
        }
        1;
    } or do {
        if ( $our_pid == $$ ) {
            $dbh->{'InactiveDestroy'} = 0 if $dbh;
            $RT::Handle->{'DisconnectHandleOnDestroy'} = 1;
        }
        die $@;
    };
    return $want? (@res) : $res[0];
}

sub _safe_run_child {
    local @ENV{ 'LANG', 'LC_ALL' } = ( 'C', 'C' );

    return shift->() if $ENV{'MOD_PERL'} || $CGI::SpeedyCGI::i_am_speedy;

    # We need to reopen stdout temporarily, because in FCGI
    # environment, stdout is tied to FCGI::Stream, and the child
    # of the run3 wouldn't be able to reopen STDOUT properly.
    my $stdin = IO::Handle->new;
    $stdin->fdopen( 0, 'r' );
    local *STDIN = $stdin;

    my $stdout = IO::Handle->new;
    $stdout->fdopen( 1, 'w' );
    local *STDOUT = $stdout;

    my $stderr = IO::Handle->new;
    $stderr->fdopen( 2, 'w' );
    local *STDERR = $stderr;

    return shift->();
}

eval "require RT::Util_Vendor";
if ($@ && $@ !~ qr{^Can't locate RT/Util_Vendor.pm}) {
    die $@;
};

eval "require RT::Util_Local";
if ($@ && $@ !~ qr{^Can't locate RT/Util_Local.pm}) {
    die $@;
};

1;
