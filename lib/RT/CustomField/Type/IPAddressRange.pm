# BEGIN BPS TAGGED BLOCK {{{
#
# COPYRIGHT:
#
# This software is Copyright (c) 1996-2011 Best Practical Solutions, LLC
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

package RT::CustomField::Type::IPAddressRange;
use strict;
use warnings;

use base qw(RT::CustomField::Type::IPAddress);

use Regexp::Common qw(RE_net_IPv4);
use Regexp::IPv6 qw($IPv6_re);
use Regexp::Common::net::CIDR;
require Net::CIDR;

$IPv6_re = qr/(?:$IPv6_re|::)/;

sub CanonicalizeForCreate {
    my ($self, $cf, $ocfv, $args) = @_;

    if ($args->{'Content'}) {
        ($args->{'Content'}, $args->{'LargeContent'}) =
            $self->ParseIPRange( $args->{'Content'} );
    }
    $args->{'ContentType'} = 'text/plain';

    unless ( defined $args->{'Content'} ) {
        return wantarray
                ? ( 0, "Content is an invalid IP address range" ) # loc
                : 0;
    }

    return wantarray ? ( 1 ) : 1;
}

sub CanonicalizeForSearch {
    my ($self, $cf, $value, $op) = @_;

    if ( $value =~ /^\s*$RE{net}{CIDR}{IPv4}{-keep}\s*$/o ) {

        # convert incomplete 192.168/24 to 192.168.0.0/24 format
        $value =
            join( '.', map $_ || 0, ( split /\./, $1 )[ 0 .. 3 ] ) . "/$2"
            || $value;
    }

    my ( $start_ip, $end_ip ) =
        $self->ParseIPRange($value);
    if ( $start_ip && $end_ip ) {
        if ( $op =~ /^([<>])=?$/ ) {
            my $is_less = $1 eq '<' ? 1 : 0;
            if ( $is_less ) {
                $value = $start_ip;
            }
            else {
                $value = $end_ip;
            }
        }
        else {
            $value = join '-', $start_ip, $end_ip;
        }
    }
    else {
        $RT::Logger->warn("$value is not a valid IPAddressRange");
    }
    return $value;
}

my $re_ip_sunit = qr/[0-1][0-9][0-9]|2[0-4][0-9]|25[0-5]/;
my $re_ip_serialized = qr/$re_ip_sunit(?:\.$re_ip_sunit){3}/;
use Regexp::IPv6 qw($IPv6_re);

sub Stringify {
    my ($self, $ocfv) = @_;
    my $content = $self->SUPER::Stringify($ocfv);

    my $large_content = $ocfv->__Value('LargeContent');
    if ( $large_content =~ /^\s*($re_ip_serialized)\s*$/o ) {
        my $eIP = sprintf "%d.%d.%d.%d", split /\./, $1;
        if ( $content eq $eIP ) {
            return $content;
        }
        else {
            return $content . "-" . $eIP;
        }
    }
    elsif ( $large_content =~ /^\s*($IPv6_re)\s*$/o ) {
        my $eIP = $1;
        if ( $content eq $eIP ) {
            return $content;
        }
        else {
            return $content . "-" . $eIP;
        }
    }
    else {
        return $content;
    }
}

sub ParseIPRange {
    my $self = shift;
    my $value = shift or return;
    $value = lc $value;
    $value =~ s!^\s+!!;
    $value =~ s!\s+$!!;
    
    if ( $value =~ /^$RE{net}{CIDR}{IPv4}{-keep}$/go ) {
        my $cidr = join( '.', map $_||0, (split /\./, $1)[0..3] ) ."/$2";
        $value = (Net::CIDR::cidr2range( $cidr ))[0] || $value;
    }
    elsif ( $value =~ /^$IPv6_re(?:\/\d+)?$/o ) {
        $value = (Net::CIDR::cidr2range( $value ))[0] || $value;
    }
    
    my ($sIP, $eIP);
    if ( $value =~ /^($RE{net}{IPv4})$/o ) {
        $sIP = $eIP = sprintf "%03d.%03d.%03d.%03d", split /\./, $1;
    }
    elsif ( $value =~ /^($RE{net}{IPv4})-($RE{net}{IPv4})$/o ) {
        $sIP = sprintf "%03d.%03d.%03d.%03d", split /\./, $1;
        $eIP = sprintf "%03d.%03d.%03d.%03d", split /\./, $2;
    }
    elsif ( $value =~ /^($IPv6_re)$/o ) {
        $sIP = $self->ParseIP( $1 );
        $eIP = $sIP;
    }
    elsif ( $value =~ /^($IPv6_re)-($IPv6_re)$/o ) {
        ($sIP, $eIP) = ( $1, $2 );
        $sIP = $self->ParseIP( $sIP );
        $eIP = $self->ParseIP( $eIP );
    }
    else {
        return;
    }

    ($sIP, $eIP) = ($eIP, $sIP) if $sIP gt $eIP;
    
    return $sIP, $eIP;
}

sub Limit {
    my ($self, $tickets, $field, $value, $op, %rest) = @_;

    return if $op =~ /^[<>]=?$/;

    my ($start_ip, $end_ip) = split /-/, $value;

    $tickets->_OpenParen;

    if ( $op !~ /NOT|!=|<>/i ) { # positive equation
        $tickets->_CustomFieldLimit(
            'CF', '<=', $end_ip, %rest,
            SUBKEY => $rest{'SUBKEY'}. '.Content',
        );
        $tickets->_CustomFieldLimit(
            'CF', '>=', $start_ip, %rest,
            SUBKEY          => $rest{'SUBKEY'}. '.LargeContent',
            ENTRYAGGREGATOR => 'AND',
        );
        # as well limit borders so DB optimizers can use better
        # estimations and scan less rows
        # have to disable this tweak because of ipv6
        #            $tickets->_CustomFieldLimit(
        #                $field, '>=', '000.000.000.000', %rest,
        #                SUBKEY          => $rest{'SUBKEY'}. '.Content',
        #                ENTRYAGGREGATOR => 'AND',
        #            );
        #            $tickets->_CustomFieldLimit(
        #                $field, '<=', '255.255.255.255', %rest,
        #                SUBKEY          => $rest{'SUBKEY'}. '.LargeContent',
        #                ENTRYAGGREGATOR => 'AND',
        #            );
    }
    else { # negative equation
        $tickets->_CustomFieldLimit($field, '>', $end_ip, %rest);
        $tickets->_CustomFieldLimit(
            $field, '<', $start_ip, %rest,
            SUBKEY          => $rest{'SUBKEY'}. '.LargeContent',
            ENTRYAGGREGATOR => 'OR',
        );
        # TODO: as well limit borders so DB optimizers can use better
        # estimations and scan less rows, but it's harder to do
        # as we have OR aggregator
    }
    $tickets->_CloseParen;

    return 1;
}


1;
