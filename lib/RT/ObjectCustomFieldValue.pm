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

package RT::ObjectCustomFieldValue;

use 5.010;
use strict;
use warnings;
use base 'RT::Record';

use RT::Interface::Web;
use Regexp::Common qw(RE_net_IPv4);
use Regexp::IPv6 qw($IPv6_re);
use Regexp::Common::net::CIDR;
require Net::CIDR;

# Allow the empty IPv6 address
$IPv6_re = qr/(?:$IPv6_re|::)/;

use RT::CustomField;

sub Table {'ObjectCustomFieldValues'}




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

    my $cf = RT::CustomField->new( $self->CurrentUser );
    $cf->Load( $args{CustomField} );

    my ($val, $msg) = $cf->_CanonicalizeValue(\%args);
    return ($val, $msg) unless $val;

    my $encoded = Encode::encode("UTF-8", $args{'Content'});
    if ( defined $args{'Content'} && length( $encoded ) > 255 ) {
        if ( defined $args{'LargeContent'} && length $args{'LargeContent'} ) {
            $RT::Logger->error("Content is longer than 255 bytes and LargeContent specified");
        }
        else {
            # _EncodeLOB, and thus LargeContent, takes bytes; Content is
            # in characters.  Encode it; this may replace illegal
            # codepoints (e.g. \x{FDD0}) with \x{FFFD}.
            $args{'LargeContent'} = Encode::encode("UTF-8",$args{'Content'});
            $args{'Content'} = undef;
            $args{'ContentType'} ||= 'text/plain';
        }
    }

    ( $args{'ContentEncoding'}, $args{'LargeContent'} ) =
        $self->_EncodeLOB( $args{'LargeContent'}, $args{'ContentType'} )
            if defined $args{'LargeContent'};

    ( my $id, $msg ) = $self->SUPER::Create(
        CustomField     => $args{'CustomField'},
        ObjectType      => $args{'ObjectType'},
        ObjectId        => $args{'ObjectId'},
        Disabled        => $args{'Disabled'},
        Content         => $args{'Content'},
        LargeContent    => $args{'LargeContent'},
        ContentType     => $args{'ContentType'},
        ContentEncoding => $args{'ContentEncoding'},
    );

    if ( $id ) {
        my $new_value = RT::ObjectCustomFieldValue->new( $self->CurrentUser );
        $new_value->Load( $id );
        my $ocfv_key = $new_value->GetOCFVCacheKey();
        if ( $RT::ObjectCustomFieldValues::_OCFV_CACHE->{$ocfv_key} ) {
            push @{ $RT::ObjectCustomFieldValues::_OCFV_CACHE->{$ocfv_key} },
              {
                'ObjectId'       => $new_value->Id,
                'CustomFieldObj' => $new_value->CustomFieldObj,
                'Content'        => $new_value->_Value('Content'),
                'LargeContent'   => $new_value->LargeContent,
              };
        }
    }

    return wantarray ? ( $id, $msg ) : $id;
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

        my ($ok, $msg) = $cf->_CanonicalizeValue(\%args);
        return ($ok, $msg) unless $ok;
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

    my $cf = $self->CustomFieldObj;
    $cf->{include_set_initial} = $self->{include_set_initial};

    return undef unless $cf->CurrentUserCanSee;

    my $content = $self->_Value('Content');
    if (   $cf->Type eq 'IPAddress'
        || $cf->Type eq 'IPAddressRange' )
    {

        require Net::IP;
        if ( $content =~ /^\s*($re_ip_serialized)\s*$/o ) {
            $content = sprintf "%d.%d.%d.%d", split /\./, $1;
        }
        if ( $content =~ /^\s*($IPv6_re)\s*$/o ) {
            $content = Net::IP::ip_compress_address($1, 6);
        }

        return $content if $cf->Type eq 'IPAddress';

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
            my $eIP = Net::IP::ip_compress_address($1, 6);
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
    my ( $ret, $msg ) = $self->SetDisabled( 1 );
    if ( $ret ) {
        my $ocfv_key = $self->GetOCFVCacheKey();
        if ( $RT::ObjectCustomFieldValues::_OCFV_CACHE->{$ocfv_key} ) {
            @{ $RT::ObjectCustomFieldValues::_OCFV_CACHE->{$ocfv_key} } =
              grep { $_->{'ObjectId'} != $self->Id } @{ $RT::ObjectCustomFieldValues::_OCFV_CACHE->{$ocfv_key} };
        }
    }
    return wantarray ? ( $ret, $msg ) : $ret;
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
        $value //= '';
        # protect from potentially malicious URLs
        if ( $value =~ /^\s*(?:javascript|data):/i ) {
            my $object = $self->Object;
            $RT::Logger->error(
                "Potentially dangerous URL type in custom field '". $self->CustomFieldObj->Name ."'"
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
            $value //= '';
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


=head2 GetOCFVCacheKey

Get the OCFV cache key for this object

=cut

sub GetOCFVCacheKey {
    my $self = shift;
    my $ocfv_key = "CustomField-" . $self->CustomField
        . '-ObjectType-' . $self->ObjectType
        . '-ObjectId-' . $self->ObjectId;
    return $ocfv_key;
}

=head2 id

Returns the current value of id.
(In the database, id is stored as int(11).)


=cut


=head2 CustomField

Returns the current value of CustomField.
(In the database, CustomField is stored as int(11).)



=head2 SetCustomField VALUE


Set CustomField to VALUE.
Returns (1, 'Status message') on success and (0, 'Error Message') on failure.
(In the database, CustomField will be stored as a int(11).)


=cut

=head2 ObjectType

Returns the current value of ObjectType.
(In the database, ObjectType is stored as varchar(255).)



=head2 SetObjectType VALUE


Set ObjectType to VALUE.
Returns (1, 'Status message') on success and (0, 'Error Message') on failure.
(In the database, ObjectType will be stored as a varchar(255).)


=cut


=head2 ObjectId

Returns the current value of ObjectId.
(In the database, ObjectId is stored as int(11).)



=head2 SetObjectId VALUE


Set ObjectId to VALUE.
Returns (1, 'Status message') on success and (0, 'Error Message') on failure.
(In the database, ObjectId will be stored as a int(11).)


=cut


=head2 SortOrder

Returns the current value of SortOrder.
(In the database, SortOrder is stored as int(11).)



=head2 SetSortOrder VALUE


Set SortOrder to VALUE.
Returns (1, 'Status message') on success and (0, 'Error Message') on failure.
(In the database, SortOrder will be stored as a int(11).)


=cut


=head2 Content

Returns the current value of Content.
(In the database, Content is stored as varchar(255).)



=head2 SetContent VALUE


Set Content to VALUE.
Returns (1, 'Status message') on success and (0, 'Error Message') on failure.
(In the database, Content will be stored as a varchar(255).)


=cut


=head2 LargeContent

Returns the current value of LargeContent.
(In the database, LargeContent is stored as longblob.)



=head2 SetLargeContent VALUE


Set LargeContent to VALUE.
Returns (1, 'Status message') on success and (0, 'Error Message') on failure.
(In the database, LargeContent will be stored as a longblob.)


=cut


=head2 ContentType

Returns the current value of ContentType.
(In the database, ContentType is stored as varchar(80).)



=head2 SetContentType VALUE


Set ContentType to VALUE.
Returns (1, 'Status message') on success and (0, 'Error Message') on failure.
(In the database, ContentType will be stored as a varchar(80).)


=cut


=head2 ContentEncoding

Returns the current value of ContentEncoding.
(In the database, ContentEncoding is stored as varchar(80).)



=head2 SetContentEncoding VALUE


Set ContentEncoding to VALUE.
Returns (1, 'Status message') on success and (0, 'Error Message') on failure.
(In the database, ContentEncoding will be stored as a varchar(80).)


=cut


=head2 Creator

Returns the current value of Creator.
(In the database, Creator is stored as int(11).)


=cut


=head2 Created

Returns the current value of Created.
(In the database, Created is stored as datetime.)


=cut


=head2 LastUpdatedBy

Returns the current value of LastUpdatedBy.
(In the database, LastUpdatedBy is stored as int(11).)


=cut


=head2 LastUpdated

Returns the current value of LastUpdated.
(In the database, LastUpdated is stored as datetime.)


=cut


=head2 Disabled

Returns the current value of Disabled.
(In the database, Disabled is stored as smallint(6).)



=head2 SetDisabled VALUE


Set Disabled to VALUE.
Returns (1, 'Status message') on success and (0, 'Error Message') on failure.
(In the database, Disabled will be stored as a smallint(6).)


=cut



sub _CoreAccessible {
    {

        id =>
                {read => 1, sql_type => 4, length => 11,  is_blob => 0,  is_numeric => 1,  type => 'int(11)', default => ''},
        CustomField =>
                {read => 1, write => 1, sql_type => 4, length => 11,  is_blob => 0,  is_numeric => 1,  type => 'int(11)', default => ''},
        ObjectType =>
                {read => 1, write => 1, sql_type => 12, length => 255,  is_blob => 0,  is_numeric => 0,  type => 'varchar(255)', default => ''},
        ObjectId =>
                {read => 1, write => 1, sql_type => 4, length => 11,  is_blob => 0,  is_numeric => 1,  type => 'int(11)', default => ''},
        SortOrder =>
                {read => 1, write => 1, sql_type => 4, length => 11,  is_blob => 0,  is_numeric => 1,  type => 'int(11)', default => '0'},
        Content =>
                {read => 1, write => 1, sql_type => 12, length => 255,  is_blob => 0,  is_numeric => 0,  type => 'varchar(255)', default => ''},
        LargeContent =>
                {read => 1, write => 1, sql_type => -4, length => 0,  is_blob => 1,  is_numeric => 0,  type => 'longblob', default => ''},
        ContentType =>
                {read => 1, write => 1, sql_type => 12, length => 80,  is_blob => 0,  is_numeric => 0,  type => 'varchar(80)', default => ''},
        ContentEncoding =>
                {read => 1, write => 1, sql_type => 12, length => 80,  is_blob => 0,  is_numeric => 0,  type => 'varchar(80)', default => ''},
        Creator =>
                {read => 1, auto => 1, sql_type => 4, length => 11,  is_blob => 0,  is_numeric => 1,  type => 'int(11)', default => '0'},
        Created =>
                {read => 1, auto => 1, sql_type => 11, length => 0,  is_blob => 0,  is_numeric => 0,  type => 'datetime', default => ''},
        LastUpdatedBy =>
                {read => 1, auto => 1, sql_type => 4, length => 11,  is_blob => 0,  is_numeric => 1,  type => 'int(11)', default => '0'},
        LastUpdated =>
                {read => 1, auto => 1, sql_type => 11, length => 0,  is_blob => 0,  is_numeric => 0,  type => 'datetime', default => ''},
        Disabled =>
                {read => 1, write => 1, sql_type => 5, length => 6,  is_blob => 0,  is_numeric => 1,  type => 'smallint(6)', default => '0'},

 }
};

sub FindDependencies {
    my $self = shift;
    my ($walker, $deps) = @_;

    $self->SUPER::FindDependencies($walker, $deps);

    $deps->Add( out => $self->CustomFieldObj );
    $deps->Add( out => $self->Object );
}

sub ShouldStoreExternally {
    my $self = shift;
    my $type = $self->CustomFieldObj->Type;
    my $length = length($self->LargeContent || '');

    return (0, "zero length") if $length == 0;

    return 1 if $type eq "Binary";

    if ($type eq "Image") {
        # We only store externally if it's _large_
        return 1 if $length > RT->Config->Get('ExternalStorageCutoffSize');
        return (0, "image size ($length) does not exceed ExternalStorageCutoffSize (" . RT->Config->Get('ExternalStorageCutoffSize') . ")");
    }

    return (0, "Only custom fields of type Binary or Image go into external storage (not $type)");
}

sub ExternalStoreDigest {
    my $self = shift;

    return undef if $self->ContentEncoding ne 'external';
    return $self->_Value( 'LargeContent' );
}

RT::Base->_ImportOverlays();

1;
