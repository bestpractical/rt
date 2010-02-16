# BEGIN BPS TAGGED BLOCK {{{
#
# COPYRIGHT:
#
# This software is Copyright (c) 1996-2013 Best Practical Solutions, LLC
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

package RT::Crypt;
use 5.010;

require RT::Crypt::GnuPG;

=head1 NAME

RT::Crypt - encrypt/decrypt and sign/verify subsystem for RT

=head1 DESCRIPTION

This module provides support for encryption and signing of outgoing
messages, as well as the decryption and verification of incoming email.

=head1 METHODS

=head2 Protocols

Returns the complete set of encryption protocols that RT implements; not
all may be supported by this installation.

=cut

our @PROTOCOLS = ('GnuPG');
our %PROTOCOLS = map { lc $_ => $_ } @PROTOCOLS;

sub Protocols {
    return @PROTOCOLS;
}

=head2 LoadImplementation CLASS

Given the name of an encryption implementation (e.g. "GnuPG"), loads the
L<RT::Crypt> class associated with it; return the classname on success,
and undef on failure.

=cut

sub LoadImplementation {
    state %cache;
    my $proto = $PROTOCOLS{ lc $_[1] } or die "Unknown protocol '$_[1]'";
    my $class = 'RT::Crypt::'. $proto;
    return $cache{ $class } if exists $cache{ $class };

    if (eval "require $class; 1") {
        return $cache{ $class } = $class;
    } else {
        RT->Logger->warn( "Could not load $class: $@" );
        return $cache{ $class } = undef;
    }
}

=head2 UseKeyForSigning [KEY]

Returns or sets the identifier of the key that should be used for
signing.  Returns the current value when called without arguments; sets
the new value when called with one argument and unsets if it's undef.

This cache is cleared at the end of every request.

=cut

sub UseKeyForSigning {
    my $self = shift;
    state $key;
    if ( @_ ) {
        $key = $_[0];
    }
    return $key;
}

=head2 UseKeyForEncryption [KEY [, VALUE]]

Gets or sets keys to use for encryption.  When passed no arguments,
clears the cache.  When passed just a key, returns the encryption key
previously stored for that key.  When passed two (or more) keys, stores
them associatively.

This cache is reset at the end of every request.

=cut

sub UseKeyForEncryption {
    my $self = shift;
    state %key;
    unless ( @_ ) {
        %key = ();
    } elsif ( @_ > 1 ) {
        %key = (%key, @_);
        $key{ lc($_) } = delete $key{ $_ } foreach grep lc ne $_, keys %key;
    } else {
        return $key{ $_[0] };
    }
    return ();
}

1;
