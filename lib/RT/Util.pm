# BEGIN BPS TAGGED BLOCK {{{
#
# COPYRIGHT:
#
# This software is Copyright (c) 1996-2016 Best Practical Solutions, LLC
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

package RT::Util;
use strict;
use warnings;


use base 'Exporter';
our @EXPORT = qw/safe_run_child mime_recommended_filename/;

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
    my ($oldv_dbh, $oldv_rth);
    my $dbh = $RT::Handle->dbh;
    $oldv_dbh = $dbh->{'InactiveDestroy'} if $dbh;
    $dbh->{'InactiveDestroy'} = 1 if $dbh;
    $oldv_rth = $RT::Handle->{'DisconnectHandleOnDestroy'};
    $RT::Handle->{'DisconnectHandleOnDestroy'} = 0;

    my ($reader, $writer);
    pipe( $reader, $writer );

    my @res;
    my $want = wantarray;
    eval {
        my $code = shift;
        local @ENV{ 'LANG', 'LC_ALL' } = ( 'C', 'C' );
        unless ( defined $want ) {
            $code->();
        } elsif ( $want ) {
            @res = $code->();
        } else {
            @res = ( scalar $code->() );
        }
        exit 0 if $our_pid != $$;
        1;
    } or do {
        my $err = $@;
        $err =~ s/^Stack:.*$//ms;
        if ( $our_pid == $$ ) {
            $dbh->{'InactiveDestroy'} = $oldv_dbh if $dbh;
            $RT::Handle->{'DisconnectHandleOnDestroy'} = $oldv_rth;
            die "System Error: $err";
        } else {
            print $writer "System Error: $err";
            exit 1;
        }
    };

    close($writer);
    $reader->blocking(0);
    my ($response) = $reader->getline;
    warn $response if $response;

    $dbh->{'InactiveDestroy'} = $oldv_dbh if $dbh;
    $RT::Handle->{'DisconnectHandleOnDestroy'} = $oldv_rth;
    return $want? (@res) : $res[0];
}

=head2 mime_recommended_filename( MIME::Head|MIME::Entity )

# mimic our own recommended_filename
# since MIME-tools 5.501, head->recommended_filename requires the head are
# mime encoded, we don't meet this yet.

=cut

sub mime_recommended_filename {
    my $head = shift;
    $head = $head->head if $head->isa('MIME::Entity');

    for my $attr_name (qw( content-disposition.filename content-type.name )) {
        my $value = Encode::decode("UTF-8",$head->mime_attr($attr_name));
        if ( defined $value && $value =~ /\S/ ) {
            return $value;
        }
    }
    return;
}

sub assert_bytes {
    my $string = shift;
    return unless utf8::is_utf8($string);
    return unless $string =~ /([^\x00-\x7F])/;

    my $msg;
    if (ord($1) > 255) {
        $msg = "Expecting a byte string, but was passed characters";
    } else {
        $msg = "Expecting a byte string, but was possibly passed charcters;"
            ." if the string is actually bytes, please use utf8::downgrade";
    }
    $RT::Logger->warn($msg, Carp::longmess());

}


RT::Base->_ImportOverlays();

1;
