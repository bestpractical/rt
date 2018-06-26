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

package RT::Util;
use strict;
use warnings;


use base 'Exporter';
our @EXPORT = qw/safe_run_child mime_recommended_filename EntityLooksLikeEmailMessage/;

use Encode qw/encode/;

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
    my $dbh = $RT::Handle ? $RT::Handle->dbh : undef;
    $oldv_dbh = $dbh->{'InactiveDestroy'} if $dbh;
    $dbh->{'InactiveDestroy'} = 1 if $dbh;
    $oldv_rth = $RT::Handle->{'DisconnectHandleOnDestroy'} if $RT::Handle;
    $RT::Handle->{'DisconnectHandleOnDestroy'} = 0 if $RT::Handle;

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
            $RT::Handle->{'DisconnectHandleOnDestroy'} = $oldv_rth if $RT::Handle;
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
    $RT::Handle->{'DisconnectHandleOnDestroy'} = $oldv_rth if $RT::Handle;
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


=head2 C<constant_time_eq($a, $b)>

Compares two strings for equality in constant-time. Replacement for the C<eq>
operator designed to avoid timing side-channel vulnerabilities. Returns zero
or one.

This is intended for use in cryptographic subsystems for comparing well-formed
data such as hashes - not for direct use with user input or as a general
replacement for the C<eq> operator.

The two string arguments B<MUST> be of equal length. If the lengths differ,
this function will call C<die()>, as proceeding with execution would create
a timing vulnerability. Length is defined by characters, not bytes.

Strings that should be treated as binary octets rather than Unicode text
should pass a true value for the binary flag.

This code has been tested to do what it claims. Do not change it without
thorough statistical timing analysis to validate the changes.

Added to resolve CVE-2017-5361

For more on timing attacks, see this Wikipedia article:
B<https://en.wikipedia.org/wiki/Timing_attack>

=cut

sub constant_time_eq {
    my ($a, $b, $binary) = @_;

    my $result = 0;

    # generic error message avoids potential information leaks
    my $generic_error = "Cannot compare values";
    die $generic_error unless defined $a and defined $b;
    die $generic_error unless length $a == length $b;
    die $generic_error if ref($a) or ref($b);

    for (my $i = 0; $i < length($a); $i++) {
        my $a_char = substr($a, $i, 1);
        my $b_char = substr($b, $i, 1);

        my (@a_octets, @b_octets);

        if ($binary) {
            @a_octets = ord($a_char);
            @b_octets = ord($b_char);
        }
        else {
            # encode() is set to die on malformed
            @a_octets = unpack("C*", encode('UTF-8', $a_char, Encode::FB_CROAK));
            @b_octets = unpack("C*", encode('UTF-8', $b_char, Encode::FB_CROAK));
        }

        die $generic_error if (scalar @a_octets) != (scalar @b_octets);

        for (my $j = 0; $j < scalar @a_octets; $j++) {
            $result |= $a_octets[$j] ^ $b_octets[$j];
        }
    }
    return 0 + not $result;
}

=head2 EntityLooksLikeEmailMessage( MIME::Entity )

Check MIME type headers for entities that look like email.

=cut

sub EntityLooksLikeEmailMessage {
    my $entity = shift;

    return unless $entity;

    # Use mime_type instead of effective_type to get the same headers
    # MIME::Parser used.
    my $mime_type = $entity->mime_type();

    # This is the same list of MIME types MIME::Parser uses. The partial and
    # external-body types are unlikely to produce usable attachments, but they
    # are still recognized as email for the purposes of this function.

    my @email_types = ('message/rfc822', 'message/partial', 'message/external-body');

    return 1 if grep { $mime_type eq $_ } @email_types;
    return 0;
}

RT::Base->_ImportOverlays();

1;
