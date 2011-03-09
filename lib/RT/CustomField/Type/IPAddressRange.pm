package RT::CustomField::Type::IPAddressRange;
use strict;
use warnings;

use base qw(RT::CustomField::Type::IPAddress);

use Regexp::Common qw(RE_net_IPv4);
use Regexp::IPv6 qw($IPv6_re);
use Regexp::Common::net::CIDR;
require Net::CIDR;

sub CanonicalizeForCreate {
    my ($self, $cf, $args) = @_;

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


1;
