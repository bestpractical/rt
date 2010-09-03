# BEGIN BPS TAGGED BLOCK {{{
#
# COPYRIGHT:
#
# This software is Copyright (c) 1996-2010 Best Practical Solutions, LLC
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

package RT::ObjectCustomFieldValue;

use strict;
use warnings;
use RT::Interface::Web;
use Regexp::Common qw(RE_net_IPv4);
use Regexp::IPv6 qw($IPv6_re);
use Regexp::Common::net::CIDR;
require Net::CIDR;


no warnings qw(redefine);

sub Create {
    my $self = shift;
    my %args = (
        CustomField     => 0,
        ObjectType      => '',
        ObjectId        => 0,
        Disabled        => 0,
        Content         => '',
        LargeContent    => undef,
        ContentType     => '',
        ContentEncoding => '',
        @_,
    );


    my $cf_as_sys = RT::CustomField->new(RT->SystemUser);
    $cf_as_sys->Load($args{'CustomField'});

    if($cf_as_sys->Type eq 'IPAddress') {
        if ( $args{'Content'} ) {
            $args{'Content'} = $self->ParseIP( $args{'Content'} );
        }

        unless ( defined $args{'Content'} ) {
            return
              wantarray
              ? ( 0, $self->loc("Content is an invalid IP address") )
              : 0;
        }
    }

    if($cf_as_sys->Type eq 'IPAddressRange') {
        if ($args{'Content'}) {
            ($args{'Content'}, $args{'LargeContent'}) = $self->ParseIPRange( $args{'Content'} );
        }
        $args{'ContentType'} = 'text/plain';

        unless ( defined $args{'Content'} ) {
            return
              wantarray
              ? ( 0, $self->loc("Content is an invalid IP address range") )
              : 0;
        }
    }

    if ( defined $args{'Content'} && length( Encode::encode_utf8($args{'Content'}) ) > 255 ) {
        if ( defined $args{'LargeContent'} && length $args{'LargeContent'} ) {
            $RT::Logger->error("Content is longer than 255 bytes and LargeContent specified");
        }
        else {
            $args{'LargeContent'} = $args{'Content'};
            $args{'Content'} = '';
            $args{'ContentType'} ||= 'text/plain';
        }
    }

    ( $args{'ContentEncoding'}, $args{'LargeContent'} ) =
        $self->_EncodeLOB( $args{'LargeContent'}, $args{'ContentType'} )
            if defined $args{'LargeContent'};

    return $self->SUPER::Create(
        CustomField     => $args{'CustomField'},
        ObjectType      => $args{'ObjectType'},
        ObjectId        => $args{'ObjectId'},
        Disabled        => $args{'Disabled'},
        Content         => $args{'Content'},
        LargeContent    => $args{'LargeContent'},
        ContentType     => $args{'ContentType'},
        ContentEncoding => $args{'ContentEncoding'},
    );
}


sub LargeContent {
    my $self = shift;
    return $self->_DecodeLOB(
        $self->ContentType,
        $self->ContentEncoding,
        $self->_Value( 'LargeContent', decode_utf8 => 0 )
    );
}


=head2 LoadByCols

=cut

sub LoadByCols {
    my $self = shift;
    my %args = (@_);
    my $cf;
    if ( $args{CustomField} ) {
        $cf = RT::CustomField->new( $self->CurrentUser );
        $cf->Load( $args{CustomField} );
        if ( $cf->Type && $cf->Type eq 'IPAddressRange' ) {

            my ( $sIP, $eIP ) = $cf->ParseIPRange( $args{'Content'} );
            if ( $sIP && $eIP ) {
                $self->SUPER::LoadByCols( %args,
                                          Content      => $sIP,
                                          LargeContent => $eIP
                                        );
            }
        }
    }
    return $self->SUPER::LoadByCols(%args);
}

=head2 LoadByTicketContentAndCustomField { Ticket => TICKET, CustomField => CUSTOMFIELD, Content => CONTENT }

Loads a custom field value by Ticket, Content and which CustomField it's tied to

=cut


sub LoadByTicketContentAndCustomField {
    my $self = shift;
    my %args = (
        Ticket => undef,
        CustomField => undef,
        Content => undef,
        @_
    );

    return $self->LoadByCols(
        Content => $args{'Content'},
        CustomField => $args{'CustomField'},
        ObjectType => 'RT::Ticket',
        ObjectId => $args{'Ticket'},
        Disabled => 0
    );
}

sub LoadByObjectContentAndCustomField {
    my $self = shift;
    my %args = (
        Object => undef,
        CustomField => undef,
        Content => undef,
        @_
    );

    my $obj = $args{'Object'} or return;

    return $self->LoadByCols(
        Content => $args{'Content'},
        CustomField => $args{'CustomField'},
        ObjectType => ref($obj),
        ObjectId => $obj->Id,
        Disabled => 0
    );
}

=head2 CustomFieldObj

Returns the CustomField Object which has the id returned by CustomField

=cut

sub CustomFieldObj {
    my $self = shift;
    my $CustomField = RT::CustomField->new( $self->CurrentUser );
    $CustomField->SetContextObject( $self->Object );
    $CustomField->Load( $self->__Value('CustomField') );
    return $CustomField;
}


=head2 Content

Return this custom field's content. If there's no "regular"
content, try "LargeContent"

=cut

my $re_ip_sunit = qr/[0-1][0-9][0-9]|2[0-4][0-9]|25[0-5]/;
my $re_ip_serialized = qr/$re_ip_sunit(?:\.$re_ip_sunit){3}/;

sub Content {
    my $self = shift;

    my $content = $self->_Value('Content');
    if (   $self->CustomFieldObj->Type eq 'IPAddress'
        || $self->CustomFieldObj->Type eq 'IPAddressRange' )
    {

        if ( $content =~ /^\s*($re_ip_serialized)\s*$/o ) {
            $content = sprintf "%d.%d.%d.%d", split /\./, $1;
        }

        return $content if $self->CustomFieldObj->Type eq 'IPAddress';

        my $large_content = $self->__Value('LargeContent');
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

    if ( !(defined $content && length $content) && $self->ContentType && $self->ContentType eq 'text/plain' ) {
        return $self->LargeContent;
    } else {
        return $content;
    }
}

=head2 Object

Returns the object this value applies to

=cut

sub Object {
    my $self  = shift;
    my $Object = $self->__Value('ObjectType')->new( $self->CurrentUser );
    $Object->LoadById( $self->__Value('ObjectId') );
    return $Object;
}


=head2 Delete

Disable this value. Used to remove "current" values from records while leaving them in the history.

=cut


sub Delete {
    my $self = shift;
    return $self->SetDisabled(1);
}

=head2 _FillInTemplateURL URL

Takes a URL containing placeholders and returns the URL as filled in for this 
ObjectCustomFieldValue. The values for the placeholders will be URI-escaped.

Available placeholders:

=over

=item __id__

The id of the object in question.

=item __CustomField__

The value of this custom field for the object in question.

=item __WebDomain__, __WebPort__, __WebPath__, __WebBaseURL__ and __WebURL__

The value of the config option.

=back

=cut

{
my %placeholders = (
    id          => { value => sub { $_[0]->ObjectId }, escape => 1 },
    CustomField => { value => sub { $_[0]->Content }, escape => 1 },
    WebDomain   => { value => sub { RT->Config->Get('WebDomain') } },
    WebPort     => { value => sub { RT->Config->Get('WebPort') } },
    WebPath     => { value => sub { RT->Config->Get('WebPath') } },
    WebBaseURL  => { value => sub { RT->Config->Get('WebBaseURL') } },
    WebURL      => { value => sub { RT->Config->Get('WebURL') } },
);

sub _FillInTemplateURL {
    my $self = shift;
    my $url = shift;

    return undef unless defined $url && length $url;

    # special case, whole value should be an URL
    if ( $url =~ /^__CustomField__/ ) {
        my $value = $self->Content;
        # protect from javascript: URLs
        if ( $value =~ /^\s*javascript:/i ) {
            my $object = $self->Object;
            $RT::Logger->error(
                "Dangerouse value with JavaScript in custom field '". $self->CustomFieldObj->Name ."'"
                ." on ". ref($object) ." #". $object->id
            );
            return undef;
        }
        $url =~ s/^__CustomField__/$value/;
    }

    # default value, uri-escape
    for my $key (keys %placeholders) {
        $url =~ s{__${key}__}{
            my $value = $placeholders{$key}{'value'}->( $self );
            $value = '' if !defined($value);
            RT::Interface::Web::EscapeURI(\$value) if $placeholders{$key}{'escape'};
            $value
        }gxe;
    }

    return $url;
} }


=head2 ValueLinkURL

Returns a filled in URL template for this ObjectCustomFieldValue, suitable for 
constructing a hyperlink in RT's webui. Returns undef if this custom field doesn't have
a LinkValueTo

=cut

sub LinkValueTo {
    my $self = shift;
    return $self->_FillInTemplateURL($self->CustomFieldObj->LinkValueTo);
}



=head2 ValueIncludeURL

Returns a filled in URL template for this ObjectCustomFieldValue, suitable for 
constructing a hyperlink in RT's webui. Returns undef if this custom field doesn't have
a IncludeContentForValue

=cut

sub IncludeContentForValue {
    my $self = shift;
    return $self->_FillInTemplateURL($self->CustomFieldObj->IncludeContentForValue);
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

1;
