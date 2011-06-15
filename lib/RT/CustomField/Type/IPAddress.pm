package RT::CustomField::Type::IPAddress;
use strict;
use warnings;

use base qw(RT::CustomField::Type);

use Regexp::Common qw(RE_net_IPv4);
use Regexp::IPv6 qw($IPv6_re);

$IPv6_re = qr/(?:$IPv6_re|::)/;

sub CanonicalizeForCreate {
    my ($self, $cf, $ocfv, $args) = @_;

    if ( $args->{'Content'} ) {
        $args->{'Content'} = $self->ParseIP( $args->{'Content'} );
    }


    unless ( defined $args->{'Content'} ) {
        return wantarray
              ? ( 0, "Content is an invalid IP address" ) # loc
              : 0;
    }

    return wantarray ? ( 1 ) : 1;
}

sub CanonicalizeForSearch {
    my ($self, $cf, $value, $op ) = @_;

    my $parsed = $self->ParseIP($value);
    if ($parsed) {
        $value = $parsed;
    }
    else {
        $RT::Logger->warn("$value is not a valid IPAddress");
    }
    return $value;
}

my $re_ip_sunit = qr/[0-1][0-9][0-9]|2[0-4][0-9]|25[0-5]/;
my $re_ip_serialized = qr/$re_ip_sunit(?:\.$re_ip_sunit){3}/;

sub Stringify {
    my ($self, $ocfv) = @_;
    my $content = $ocfv->_Value('Content');

    if ( $content =~ /^\s*($re_ip_serialized)\s*$/o ) {
        $content = sprintf "%d.%d.%d.%d", split /\./, $1;
    }

    return $content
}

sub ParseIP {
    my $self = shift;
    my $value = shift or return;
    $value = lc $value;
    $value =~ s!^\s+!!;
    $value =~ s!\s+$!!;

    if ( $value =~ /^($RE{net}{IPv4})$/o ) {
        return sprintf "%03d.%03d.%03d.%03d", split /\./, $1;
    }
    elsif ( $value =~ /^$IPv6_re$/o ) {

        # up_fields are before '::'
        # low_fields are after '::' but without v4
        # v4_fields are the v4
        my ( @up_fields, @low_fields, @v4_fields );
        my $v6;
        if ( $value =~ /(.*:)(\d+\..*)/ ) {
            ( $v6, my $v4 ) = ( $1, $2 );
            chop $v6 unless $v6 =~ /::$/;
            while ( $v4 =~ /(\d+)\.(\d+)/g ) {
                push @v4_fields, sprintf '%.2x%.2x', $1, $2;
            }
        }
        else {
            $v6 = $value;
        }

        my ( $up, $low );
        if ( $v6 =~ /::/ ) {
            ( $up, $low ) = split /::/, $v6;
        }
        else {
            $up = $v6;
        }

        @up_fields = split /:/, $up;
        @low_fields = split /:/, $low if $low;

        my @zero_fields =
          ('0000') x ( 8 - @v4_fields - @up_fields - @low_fields );
        my @fields = ( @up_fields, @zero_fields, @low_fields, @v4_fields );

        return join ':', map { sprintf "%.4x", hex "0x$_" } @fields;
    }
    return;
}

sub SearchBuilderUIArguments {
    my ($self, $cf) = @_;
    return (
        Op => {
            Type => 'component',
            Path => '/Elements/SelectIPRelation',
            Arguments => {},
        });
}

1;
