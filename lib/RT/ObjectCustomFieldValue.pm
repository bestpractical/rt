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

package RT::ObjectCustomFieldValue;

use strict;
use warnings;

use RT::Interface::Web;



use RT::CustomField;
use base 'RT::Record';

sub Table {'ObjectCustomFieldValues'}


sub _CanonicalizeForCreate {
    my ($self, $cf_as_sys, $args) = @_;
    my $class = $cf_as_sys->GetTypeClass;# or return;
    my ($ret, $msg) = $class->CanonicalizeForCreate( $cf_as_sys, $self, $args );
    unless ($ret) {
        return (0, $self->loc($msg));
    }

    return wantarray ? (1) : 1;
}

sub _CanonicalizeForSearch {
    my ($self, $cf, $value, $op) = @_;

    return unless $cf;

    my $class = $cf->GetTypeClass;

    $value = $class->CanonicalizeForSearch( $cf, $value, $op );

    return $value;
}

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

    if ( defined $args{'Content'} ) {
        my ($ret, $msg) = $self->_CanonicalizeForCreate( $cf_as_sys, \%args );
        unless ( $ret ) {
            return wantarray
                ? ( 0, $msg )
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

        if ( exists $args{'Content'} && defined $args{'Content'} ) {
            my ($ret, $msg) = $self->_CanonicalizeForCreate( $cf, \%args );
            if ($ret) {
                $self->SUPER::LoadByCols( %args );
            }
            else {
                return wantarray
                ? ( 0, $msg )
                : 0;
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

sub Content {
    my $self = shift;

    my $class = $self->CustomFieldObj->GetTypeClass;

    return $class->Stringify( $self );
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

RT::Base->_ImportOverlays();

1;
