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

=head1 NAME

  RT::Record - Base class for RT record objects

=head1 SYNOPSIS


=head1 DESCRIPTION



=head1 METHODS

=cut

package RT::Record;

use strict;
use warnings;

use RT;
use base RT->Config->Get('RecordBaseClass');
use base 'RT::Base';

require RT::Date;
require RT::User;
require RT::Attributes;
require RT::Transactions;
require RT::Link;
use RT::Shredder::Dependencies;
use RT::Shredder::Constants;
use RT::Shredder::Exceptions;

our $_TABLE_ATTR = { };


sub _Init {
    my $self = shift;
    $self->_BuildTableAttributes unless ($_TABLE_ATTR->{ref($self)});
    $self->CurrentUser(@_);
}



=head2 _PrimaryKeys

The primary keys for RT classes is 'id'

=cut

sub _PrimaryKeys { return ['id'] }
# short circuit many, many thousands of calls from searchbuilder
sub _PrimaryKey { 'id' }

=head2 Id

Override L<DBIx::SearchBuilder/Id> to avoid a few lookups RT doesn't do
on a very common codepath

C<id> is an alias to C<Id> and is the preferred way to call this method.

=cut

sub Id {
    return shift->{'values'}->{id};
}

*id = \&Id;

=head2 Delete

Delete this record object from the database.

=cut

sub Delete {
    my $self = shift;
    my ($rv) = $self->SUPER::Delete;
    if ($rv) {
        return ($rv, $self->loc("Object deleted"));
    } else {
        return (0, $self->loc("Object could not be deleted"));
    }
}

=head2 RecordType

Returns a string which is this record's type. It's not localized and by
default last part (everything after last ::) of class name is returned.

=cut

sub RecordType {
    my $res = ref($_[0]) || $_[0];
    $res =~ s/.*:://;
    return $res;
}

=head2 Attributes

Return this object's attributes as an RT::Attributes object

=cut

sub Attributes {
    my $self = shift;
    unless ($self->{'attributes'}) {
        $self->{'attributes'} = RT::Attributes->new($self->CurrentUser);
        $self->{'attributes'}->LimitToObject($self);
        $self->{'attributes'}->OrderByCols({FIELD => 'id'});
    }
    return ($self->{'attributes'});
}


=head2 AddAttribute { Name, Description, Content }

Adds a new attribute for this object.

=cut

sub AddAttribute {
    my $self = shift;
    my %args = ( Name        => undef,
                 Description => undef,
                 Content     => undef,
                 @_ );

    my $attr = RT::Attribute->new( $self->CurrentUser );
    my ( $id, $msg ) = $attr->Create( 
                                      Object    => $self,
                                      Name        => $args{'Name'},
                                      Description => $args{'Description'},
                                      Content     => $args{'Content'} );


    # XXX TODO: Why won't RedoSearch work here?                                     
    $self->Attributes->_DoSearch;
    
    return ($id, $msg);
}


=head2 SetAttribute { Name, Description, Content }

Like AddAttribute, but replaces all existing attributes with the same Name.

=cut

sub SetAttribute {
    my $self = shift;
    my %args = ( Name        => undef,
                 Description => undef,
                 Content     => undef,
                 @_ );

    my @AttributeObjs = $self->Attributes->Named( $args{'Name'} )
        or return $self->AddAttribute( %args );

    my $AttributeObj = pop( @AttributeObjs );
    $_->Delete foreach @AttributeObjs;

    $AttributeObj->SetDescription( $args{'Description'} );
    $AttributeObj->SetContent( $args{'Content'} );

    $self->Attributes->RedoSearch;
    return 1;
}

=head2 DeleteAttribute NAME

Deletes all attributes with the matching name for this object.

=cut

sub DeleteAttribute {
    my $self = shift;
    my $name = shift;
    my ($val,$msg) =  $self->Attributes->DeleteEntry( Name => $name );
    $self->ClearAttributes;
    return ($val,$msg);
}

=head2 FirstAttribute NAME

Returns the first attribute with the matching name for this object (as an
L<RT::Attribute> object), or C<undef> if no such attributes exist.
If there is more than one attribute with the matching name on the
object, the first value that was set is returned.

=cut

sub FirstAttribute {
    my $self = shift;
    my $name = shift;
    return ($self->Attributes->Named( $name ))[0];
}


sub ClearAttributes {
    my $self = shift;
    delete $self->{'attributes'};

}

sub _Handle { return $RT::Handle }



=head2  Create PARAMHASH

Takes a PARAMHASH of Column -> Value pairs.
If any Column has a Validate$PARAMNAME subroutine defined and the 
value provided doesn't pass validation, this routine returns
an error.

If this object's table has any of the following atetributes defined as
'Auto', this routine will automatically fill in their values.

=over

=item Created

=item Creator

=item LastUpdated

=item LastUpdatedBy

=back

=cut

sub Create {
    my $self    = shift;
    my %attribs = (@_);
    foreach my $key ( keys %attribs ) {
        if (my $method = $self->can("Validate$key")) {
        if (! $method->( $self, $attribs{$key} ) ) {
            if (wantarray) {
                return ( 0, $self->loc('Invalid value for [_1]', $key) );
            }
            else {
                return (0);
            }
        }
        }
    }



    my ($sec,$min,$hour,$mday,$mon,$year,$wday,$ydaym,$isdst,$offset) = gmtime();

    my $now_iso =
     sprintf("%04d-%02d-%02d %02d:%02d:%02d", ($year+1900), ($mon+1), $mday, $hour, $min, $sec);

    $attribs{'Created'} = $now_iso if ( $self->_Accessible( 'Created', 'auto' ) && !$attribs{'Created'});

    if ($self->_Accessible( 'Creator', 'auto' ) && !$attribs{'Creator'}) {
         $attribs{'Creator'} = $self->CurrentUser->id || '0'; 
    }
    $attribs{'LastUpdated'} = $now_iso
      if ( $self->_Accessible( 'LastUpdated', 'auto' ) && !$attribs{'LastUpdated'});

    $attribs{'LastUpdatedBy'} = $self->CurrentUser->id || '0'
      if ( $self->_Accessible( 'LastUpdatedBy', 'auto' ) && !$attribs{'LastUpdatedBy'});

    my $id = $self->SUPER::Create(%attribs);
    if ( UNIVERSAL::isa( $id, 'Class::ReturnValue' ) ) {
        if ( $id->errno ) {
            if (wantarray) {
                return ( 0,
                    $self->loc( "Internal Error: [_1]", $id->{error_message} ) );
            }
            else {
                return (0);
            }
        }
    }
    # If the object was created in the database, 
    # load it up now, so we're sure we get what the database 
    # has.  Arguably, this should not be necessary, but there
    # isn't much we can do about it.

   unless ($id) { 
    if (wantarray) {
        return ( $id, $self->loc('Object could not be created') );
    }
    else {
        return ($id);
    }

   }

    if  (UNIVERSAL::isa('errno',$id)) {
        return(undef);
    }

    $self->Load($id) if ($id);



    if (wantarray) {
        return ( $id, $self->loc('Object created') );
    }
    else {
        return ($id);
    }

}



=head2 LoadByCols

Override DBIx::SearchBuilder::LoadByCols to do case-insensitive loads if the 
DB is case sensitive

=cut

sub LoadByCols {
    my $self = shift;

    # We don't want to hang onto this
    $self->ClearAttributes;

    unless ( $self->_Handle->CaseSensitive ) {
        my ( $ret, $msg ) = $self->SUPER::LoadByCols( @_ );
        return wantarray ? ( $ret, $msg ) : $ret;
    }

    # If this database is case sensitive we need to uncase objects for
    # explicit loading
    my %hash = (@_);
    foreach my $key ( keys %hash ) {

        # If we've been passed an empty value, we can't do the lookup. 
        # We don't need to explicitly downcase integers or an id.
        if ( $key ne 'id' && defined $hash{ $key } && $hash{ $key } !~ /^\d+$/ ) {
            my ($op, $val, $func);
            ($key, $op, $val, $func) =
                $self->_Handle->_MakeClauseCaseInsensitive( $key, '=', delete $hash{ $key } );
            $hash{$key}->{operator} = $op;
            $hash{$key}->{value}    = $val;
            $hash{$key}->{function} = $func;
        }
    }
    my ( $ret, $msg ) = $self->SUPER::LoadByCols( %hash );
    return wantarray ? ( $ret, $msg ) : $ret;
}



# There is room for optimizations in most of those subs:


sub LastUpdatedObj {
    my $self = shift;
    my $obj  = RT::Date->new( $self->CurrentUser );

    $obj->Set( Format => 'sql', Value => $self->LastUpdated );
    return $obj;
}



sub CreatedObj {
    my $self = shift;
    my $obj  = RT::Date->new( $self->CurrentUser );

    $obj->Set( Format => 'sql', Value => $self->Created );

    return $obj;
}


sub LastUpdatedAsString {
    my $self = shift;
    if ( $self->LastUpdated ) {
        return ( $self->LastUpdatedObj->AsString() );
    } else {
        return "never";
    }
}

sub CreatedAsString {
    my $self = shift;
    return ( $self->CreatedObj->AsString() );
}

sub _Set {
    my $self = shift;

    my %args = (
        Field => undef,
        Value => undef,
        IsSQL => undef,
        @_
    );

    #if the user is trying to modify the record
    # TODO: document _why_ this code is here

    if ( ( !defined( $args{'Field'} ) ) || ( !defined( $args{'Value'} ) ) ) {
        $args{'Value'} = 0;
    }

    my $old_val = $self->__Value($args{'Field'});
     $self->_SetLastUpdated();
    my $ret = $self->SUPER::_Set(
        Field => $args{'Field'},
        Value => $args{'Value'},
        IsSQL => $args{'IsSQL'}
    );
        my ($status, $msg) =  $ret->as_array();

        # @values has two values, a status code and a message.

    # $ret is a Class::ReturnValue object. as such, in a boolean context, it's a bool
    # we want to change the standard "success" message
    if ($status) {
        if ($self->SQLType( $args{'Field'}) =~ /text/) {
            $msg = $self->loc(
                "[_1] updated",
                $self->loc( $args{'Field'} ),
            );
        } else {
            $msg = $self->loc(
                "[_1] changed from [_2] to [_3]",
                $self->loc( $args{'Field'} ),
                ( $old_val ? '"' . $old_val . '"' : $self->loc("(no value)") ),
                '"' . $self->__Value( $args{'Field'}) . '"',
            );
        }
    } else {
        $msg = $self->CurrentUser->loc_fuzzy($msg);
    }

    return wantarray ? ($status, $msg) : $ret;
}



=head2 _SetLastUpdated

This routine updates the LastUpdated and LastUpdatedBy columns of the row in question
It takes no options. Arguably, this is a bug

=cut

sub _SetLastUpdated {
    my $self = shift;
    my $now = RT::Date->new( $self->CurrentUser );
    $now->SetToNow();

    if ( $self->_Accessible( 'LastUpdated', 'auto' ) ) {
        my ( $msg, $val ) = $self->__Set(
            Field => 'LastUpdated',
            Value => $now->ISO
        );
    }
    if ( $self->_Accessible( 'LastUpdatedBy', 'auto' ) ) {
        my ( $msg, $val ) = $self->__Set(
            Field => 'LastUpdatedBy',
            Value => $self->CurrentUser->id
        );
    }
}



=head2 CreatorObj

Returns an RT::User object with the RT account of the creator of this row

=cut

sub CreatorObj {
    my $self = shift;
    unless ( exists $self->{'CreatorObj'} ) {

        $self->{'CreatorObj'} = RT::User->new( $self->CurrentUser );
        $self->{'CreatorObj'}->Load( $self->Creator );
    }
    return ( $self->{'CreatorObj'} );
}



=head2 LastUpdatedByObj

  Returns an RT::User object of the last user to touch this object

=cut

sub LastUpdatedByObj {
    my $self = shift;
    unless ( exists $self->{LastUpdatedByObj} ) {
        $self->{'LastUpdatedByObj'} = RT::User->new( $self->CurrentUser );
        $self->{'LastUpdatedByObj'}->Load( $self->LastUpdatedBy );
    }
    return $self->{'LastUpdatedByObj'};
}



=head2 URI

Returns this record's URI

=cut

sub URI {
    my $self = shift;
    my $uri = RT::URI::fsck_com_rt->new($self->CurrentUser);
    return($uri->URIForObject($self));
}


=head2 ValidateName NAME

Validate the name of the record we're creating. Mostly, just make sure it's not a numeric ID, which is invalid for Name

=cut

sub ValidateName {
    my $self = shift;
    my $value = shift;
    if (defined $value && $value=~ /^\d+$/) {
        return(0);
    } else  {
        return(1);
    }
}



=head2 SQLType attribute

return the SQL type for the attribute 'attribute' as stored in _ClassAccessible

=cut

sub SQLType {
    my $self = shift;
    my $field = shift;

    return ($self->_Accessible($field, 'type'));


}

sub __Value {
    my $self  = shift;
    my $field = shift;
    my %args  = ( decode_utf8 => 1, @_ );

    unless ($field) {
        $RT::Logger->error("__Value called with undef field");
    }

    my $value = $self->SUPER::__Value($field);
    return $value if ref $value;

    return undef if (!defined $value);

    # Pg returns character columns as character strings; mysql and
    # sqlite return them as bytes.  While mysql can be made to return
    # characters, using the mysql_enable_utf8 flag, the "Content" column
    # is bytes on mysql and characters on Postgres, making true
    # consistency impossible.
    if ( $args{'decode_utf8'} ) {
        if ( !utf8::is_utf8($value) ) { # mysql/sqlite
            utf8::decode($value);
        }
    } else {
        if ( utf8::is_utf8($value) ) {
            utf8::encode($value);
        }
    }

    return $value;

}

# Set up defaults for DBIx::SearchBuilder::Record::Cachable

sub _CacheConfig {
  {
     'cache_for_sec'  => 30,
  }
}



sub _BuildTableAttributes {
    my $self = shift;
    my $class = ref($self) || $self;

    my $attributes;
    if ( UNIVERSAL::can( $self, '_CoreAccessible' ) ) {
       $attributes = $self->_CoreAccessible();
    } elsif ( UNIVERSAL::can( $self, '_ClassAccessible' ) ) {
       $attributes = $self->_ClassAccessible();

    }

    foreach my $column (keys %$attributes) {
        foreach my $attr ( keys %{ $attributes->{$column} } ) {
            $_TABLE_ATTR->{$class}->{$column}->{$attr} = $attributes->{$column}->{$attr};
        }
    }
    foreach my $method ( qw(_OverlayAccessible _VendorAccessible _LocalAccessible) ) {
        next unless UNIVERSAL::can( $self, $method );
        $attributes = $self->$method();

        foreach my $column ( keys %$attributes ) {
            foreach my $attr ( keys %{ $attributes->{$column} } ) {
                $_TABLE_ATTR->{$class}->{$column}->{$attr} = $attributes->{$column}->{$attr};
            }
        }
    }
}


=head2 _ClassAccessible 

Overrides the "core" _ClassAccessible using $_TABLE_ATTR. Behaves identical to the version in
DBIx::SearchBuilder::Record

=cut

sub _ClassAccessible {
    my $self = shift;
    return $_TABLE_ATTR->{ref($self) || $self};
}

=head2 _Accessible COLUMN ATTRIBUTE

returns the value of ATTRIBUTE for COLUMN


=cut 

sub _Accessible  {
  my $self = shift;
  my $column = shift;
  my $attribute = lc(shift);

  my $class =  ref($self) || $self;
  $class->_BuildTableAttributes unless ($_TABLE_ATTR->{$class});

  return 0 unless defined ($_TABLE_ATTR->{$class}->{$column});
  return $_TABLE_ATTR->{$class}->{$column}->{$attribute} || 0;

}

=head2 _EncodeLOB BODY MIME_TYPE FILENAME

Takes a potentially large attachment. Returns (ContentEncoding,
EncodedBody, MimeType, Filename, NoteArgs) based on system configuration and
selected database.  Returns a custom (short) text/plain message if
DropLongAttachments causes an attachment to not be stored.

Encodes your data as base64 or Quoted-Printable as needed based on your
Databases's restrictions and the UTF-8ness of the data being passed in.  Since
we are storing in columns marked UTF8, we must ensure that binary data is
encoded on databases which are strict.

This function expects to receive an octet string in order to properly
evaluate and encode it.  It will return an octet string.

NoteArgs is currently used to indicate caller that the message is too long and
is truncated or dropped. It's a hashref which is expected to be passed to
L<RT::Record/_NewTransaction>.

=cut

sub _EncodeLOB {
    my $self = shift;
    my $Body = shift;
    my $MIMEType = shift || '';
    my $Filename = shift;

    my $ContentEncoding = 'none';
    my $note_args;

    RT::Util::assert_bytes( $Body );

    #get the max attachment length from RT
    my $MaxSize = RT->Config->Get('MaxAttachmentSize');

    #if the current attachment contains nulls and the
    #database doesn't support embedded nulls

    if ( ( !$RT::Handle->BinarySafeBLOBs ) && ( $Body =~ /\x00/ ) ) {

        # set a flag telling us to mimencode the attachment
        $ContentEncoding = 'base64';

        #cut the max attchment size by 25% (for mime-encoding overhead.
        $RT::Logger->debug("Max size is $MaxSize");
        $MaxSize = $MaxSize * 3 / 4;
    # Some databases (postgres) can't handle non-utf8 data
    } elsif (    !$RT::Handle->BinarySafeBLOBs
              && $Body =~ /\P{ASCII}/
              && !Encode::is_utf8( $Body, 1 ) ) {
          $ContentEncoding = 'quoted-printable';
    }

    #if the attachment is larger than the maximum size
    if ( ($MaxSize) and ( $MaxSize < length($Body) ) ) {

        my $size = length $Body;
        # if we're supposed to truncate large attachments
        if (RT->Config->Get('TruncateLongAttachments')) {

            $RT::Logger->info("$self: Truncated an attachment of size $size");

            # truncate the attachment to that length.
            $Body = substr( $Body, 0, $MaxSize );
            $note_args = {
                Type           => 'AttachmentTruncate',
                Data           => $Filename,
                OldValue       => $size,
                NewValue       => $MaxSize,
                ActivateScrips => 0,
            };

        }

        # elsif we're supposed to drop large attachments on the floor,
        elsif (RT->Config->Get('DropLongAttachments')) {

            # drop the attachment on the floor
            $RT::Logger->info( "$self: Dropped an attachment of size $size" );
            $RT::Logger->info( "It started: " . substr( $Body, 0, 60 ) );
            $note_args = {
                Type           => 'AttachmentDrop',
                Data           => $Filename,
                OldValue       => $size,
                NewValue       => $MaxSize,
                ActivateScrips => 0,
            };
            $Filename .= ".txt" if $Filename && $Filename !~ /\.txt$/;
            return ("none", "Large attachment dropped", "text/plain", $Filename, $note_args );
        }
    }

    # if we need to mimencode the attachment
    if ( $ContentEncoding eq 'base64' ) {
        # base64 encode the attachment
        $Body = MIME::Base64::encode_base64($Body);

    } elsif ($ContentEncoding eq 'quoted-printable') {
        $Body = MIME::QuotedPrint::encode($Body);
    }


    return ($ContentEncoding, $Body, $MIMEType, $Filename, $note_args );
}

=head2 _DecodeLOB C<ContentType>, C<ContentEncoding>, C<Content>

This function reverses the effects of L</_EncodeLOB>, by unpacking the
data, provided as bytes (not characters!), from the database.  This
data may also be Base64 or Quoted-Printable encoded, as given by
C<Content-Encoding>.  This encoding layer exists because the
underlying database column is "text", which rejects non-UTF-8 byte
sequences.

Alternatively, if the data lives in external storage, it will be read
(or downloaded) and returned.

This function differs in one important way from being the inverse of
L</_EncodeLOB>: for textual data (as judged via
L<RT::I18N/IsTextualContentType> applied to the given C<ContentType>),
C<_DecodeLOB> returns character strings, not bytes.  The character set
used in decoding is taken from the C<ContentType>, or UTF-8 if not
provided; however, for all textual content inserted by current code,
the character set used for storage is always UTF-8.

This decoding step is done using L<Encode>'s PERLQQ filter, which
replaces invalid byte sequences with C<\x{HH}>.  This mirrors how data
from query parameters are parsed in L<RT::Interface::Web/DecodeARGS>.
Since RT is now strict about the bytes it inserts, substitution
characters should only be needed for data inserted by older versions
of RT, or for C<ContentType>s which are now believed to be textual,
but were not considered so on insertion (and thus not transcoded).

=cut

sub _DecodeLOB {
    my $self            = shift;
    my $ContentType     = shift || '';
    my $ContentEncoding = shift || 'none';
    my $Content         = shift;

    RT::Util::assert_bytes( $Content );

    if ( $ContentEncoding eq 'base64' ) {
        $Content = MIME::Base64::decode_base64($Content);
    }
    elsif ( $ContentEncoding eq 'quoted-printable' ) {
        $Content = MIME::QuotedPrint::decode($Content);
    }
    elsif ( $ContentEncoding eq 'external' ) {
        my $Digest = $Content;
        my $Storage = RT->System->ExternalStorage;
        unless ($Storage) {
            RT->Logger->error( "Failed to load $Content; external storage not configured" );
            return ("");
        };

        ($Content, my $msg) = $Storage->Get( $Digest );
        unless (defined $Content) {
            RT->Logger->error( "Failed to load $Digest from external storage: $msg" );
            return ("");
        }
    }
    elsif ( $ContentEncoding && $ContentEncoding ne 'none' ) {
        return ( $self->loc( "Unknown ContentEncoding [_1]", $ContentEncoding ) );
    }

    if ( RT::I18N::IsTextualContentType($ContentType) ) {
        my $entity = MIME::Entity->new();
        $entity->head->add("Content-Type", $ContentType);
        $entity->bodyhandle( MIME::Body::Scalar->new( $Content ) );
        my $charset = RT::I18N::_FindOrGuessCharset($entity);
        $charset = 'utf-8' if not $charset or not Encode::find_encoding($charset);

        $Content = Encode::decode($charset,$Content,Encode::FB_PERLQQ);
    }
    return ($Content);
}

=head2 Update  ARGSHASH

Updates fields on an object for you using the proper Set methods,
skipping unchanged values.

 ARGSRef => a hashref of attributes => value for the update
 AttributesRef => an arrayref of keys in ARGSRef that should be updated
 AttributePrefix => a prefix that should be added to the attributes in AttributesRef
                    when looking up values in ARGSRef
                    Bare attributes are tried before prefixed attributes

Returns a list of localized results of the update

=cut

sub Update {
    my $self = shift;

    my %args = (
        ARGSRef         => undef,
        AttributesRef   => undef,
        AttributePrefix => undef,
        @_
    );

    my $attributes = $args{'AttributesRef'};
    my $ARGSRef    = $args{'ARGSRef'};
    my %new_values;

    # gather all new values
    foreach my $attribute (@$attributes) {
        my $value;
        if ( defined $ARGSRef->{$attribute} ) {
            $value = $ARGSRef->{$attribute};
        }
        elsif (
            defined( $args{'AttributePrefix'} )
            && defined(
                $ARGSRef->{ $args{'AttributePrefix'} . "-" . $attribute }
            )
          ) {
            $value = $ARGSRef->{ $args{'AttributePrefix'} . "-" . $attribute };

        }
        else {
            next;
        }

        $value =~ s/\r\n/\n/gs;

        my $truncated_value = $self->TruncateValue($attribute, $value);

        # If Queue is 'General', we want to resolve the queue name for
        # the object.

        # This is in an eval block because $object might not exist.
        # and might not have a Name method. But "can" won't find autoloaded
        # items. If it fails, we don't care
        do {
            no warnings "uninitialized";
            local $@;
            my $name = eval {
                my $object = $attribute . "Obj";
                $self->$object->Name;
            };
            unless ($@) {
                next if $name eq $value || $name eq ($value || 0);
            }

            next if $truncated_value eq $self->$attribute();
            next if ( $truncated_value || 0 ) eq $self->$attribute();
        };

        $new_values{$attribute} = $value;
    }

    return $self->_UpdateAttributes(
        Attributes => $attributes,
        NewValues  => \%new_values,
    );
}

sub _UpdateAttributes {
    my $self = shift;
    my %args = (
        Attributes => [],
        NewValues  => {},
        @_,
    );

    my @results;

    foreach my $attribute (@{ $args{Attributes} }) {
        next if !exists($args{NewValues}{$attribute});

        my $value = $args{NewValues}{$attribute};
        my $method = "Set$attribute";
        my ( $code, $msg ) = $self->$method($value);
        my ($prefix) = ref($self) =~ /RT(?:.*)::(\w+)/;

        # Default to $id, but use name if we can get it.
        my $label = $self->id;
        $label = $self->Name if (UNIVERSAL::can($self,'Name'));
        # this requires model names to be loc'ed.

=for loc

    "Ticket" # loc
    "User" # loc
    "Group" # loc
    "Queue" # loc

=cut

        push @results, $self->loc( $prefix ) . " $label: ". $msg;

=for loc

                                   "[_1] could not be set to [_2].",       # loc
                                   "That is already the current value",    # loc
                                   "No value sent to _Set!",               # loc
                                   "Illegal value for [_1]",               # loc
                                   "The new value has been set.",          # loc
                                   "No column specified",                  # loc
                                   "Immutable field",                      # loc
                                   "Nonexistant field?",                   # loc
                                   "Invalid data",                         # loc
                                   "Couldn't find row",                    # loc
                                   "Missing a primary key?: [_1]",         # loc
                                   "Found Object",                         # loc

=cut

    }

    return @results;
}




=head2 Members

  This returns an RT::Links object which references all the tickets 
which are 'MembersOf' this ticket

=cut

sub Members {
    my $self = shift;
    return ( $self->_Links( 'Target', 'MemberOf' ) );
}



=head2 MemberOf

  This returns an RT::Links object which references all the tickets that this
ticket is a 'MemberOf'

=cut

sub MemberOf {
    my $self = shift;
    return ( $self->_Links( 'Base', 'MemberOf' ) );
}



=head2 RefersTo

  This returns an RT::Links object which shows all references for which this ticket is a base

=cut

sub RefersTo {
    my $self = shift;
    return ( $self->_Links( 'Base', 'RefersTo' ) );
}



=head2 ReferredToBy

This returns an L<RT::Links> object which shows all references for which this ticket is a target

=cut

sub ReferredToBy {
    my $self = shift;
    return ( $self->_Links( 'Target', 'RefersTo' ) );
}



=head2 DependedOnBy

  This returns an RT::Links object which references all the tickets that depend on this one

=cut

sub DependedOnBy {
    my $self = shift;
    return ( $self->_Links( 'Target', 'DependsOn' ) );
}




=head2 HasUnresolvedDependencies

Takes a paramhash of Type (default to '__any').  Returns the number of
unresolved dependencies, if $self->UnresolvedDependencies returns an
object with one or more members of that type.  Returns false
otherwise.

=cut

sub HasUnresolvedDependencies {
    my $self = shift;
    my %args = (
        Type   => undef,
        @_
    );

    my $deps = $self->UnresolvedDependencies;

    if ($args{Type}) {
        $deps->LimitType( VALUE => $args{Type} );
    } else {
        $deps->IgnoreType;
    }

    if ($deps->Count > 0) {
        return $deps->Count;
    }
    else {
        return (undef);
    }
}



=head2 UnresolvedDependencies

Returns an RT::Tickets object of tickets which this ticket depends on
and which have a status of new, open or stalled. (That list comes from
RT::Queue->ActiveStatusArray

=cut


sub UnresolvedDependencies {
    my $self = shift;
    my $deps = RT::Tickets->new($self->CurrentUser);

    $deps->LimitToActiveStatus;
    $deps->LimitDependedOnBy($self->Id);

    return($deps);

}



=head2 AllDependedOnBy

Returns an array of RT::Ticket objects which (directly or indirectly)
depends on this ticket; takes an optional 'Type' argument in the param
hash, which will limit returned tickets to that type, as well as cause
tickets with that type to serve as 'leaf' nodes that stops the recursive
dependency search.

=cut

sub AllDependedOnBy {
    my $self = shift;
    return $self->_AllLinkedTickets( LinkType => 'DependsOn',
                                     Direction => 'Target', @_ );
}

=head2 AllDependsOn

Returns an array of RT::Ticket objects which this ticket (directly or
indirectly) depends on; takes an optional 'Type' argument in the param
hash, which will limit returned tickets to that type, as well as cause
tickets with that type to serve as 'leaf' nodes that stops the
recursive dependency search.

=cut

sub AllDependsOn {
    my $self = shift;
    return $self->_AllLinkedTickets( LinkType => 'DependsOn',
                                     Direction => 'Base', @_ );
}

sub _AllLinkedTickets {
    my $self = shift;

    my %args = (
        LinkType  => undef,
        Direction => undef,
        Type   => undef,
        _found => {},
        _top   => 1,
        @_
    );

    my $dep = $self->_Links( $args{Direction}, $args{LinkType});
    while (my $link = $dep->Next()) {
        my $uri = $args{Direction} eq 'Target' ? $link->BaseURI : $link->TargetURI;
        next unless ($uri->IsLocal());
        my $obj = $args{Direction} eq 'Target' ? $link->BaseObj : $link->TargetObj;
        next if $args{_found}{$obj->Id};

        if (!$args{Type}) {
            $args{_found}{$obj->Id} = $obj;
            $obj->_AllLinkedTickets( %args, _top => 0 );
        }
        elsif ($obj->Type and $obj->Type eq $args{Type}) {
            $args{_found}{$obj->Id} = $obj;
        }
        else {
            $obj->_AllLinkedTickets( %args, _top => 0 );
        }
    }

    if ($args{_top}) {
        return map { $args{_found}{$_} } sort keys %{$args{_found}};
    }
    else {
        return 1;
    }
}



=head2 DependsOn

  This returns an RT::Links object which references all the tickets that this ticket depends on

=cut

sub DependsOn {
    my $self = shift;
    return ( $self->_Links( 'Base', 'DependsOn' ) );
}






=head2 Links DIRECTION [TYPE]

Return links (L<RT::Links>) to/from this object.

DIRECTION is either 'Base' or 'Target'.

TYPE is a type of links to return, it can be omitted to get
links of any type.

=cut

sub Links { shift->_Links(@_) }

sub _Links {
    my $self = shift;

    #TODO: Field isn't the right thing here. but I ahave no idea what mnemonic ---
    #tobias meant by $f
    my $field = shift;
    my $type  = shift || "";

    unless ( $self->{"$field$type"} ) {
        $self->{"$field$type"} = RT::Links->new( $self->CurrentUser );
            # at least to myself
            $self->{"$field$type"}->Limit( FIELD => $field,
                                           VALUE => $self->URI,
                                           ENTRYAGGREGATOR => 'OR' );
            $self->{"$field$type"}->Limit( FIELD => 'Type',
                                           VALUE => $type )
              if ($type);
    }
    return ( $self->{"$field$type"} );
}




=head2 FormatType

Takes a Type and returns a string that is more human readable.

=cut

sub FormatType{
    my $self = shift;
    my %args = ( Type => '',
                 @_
               );
    $args{Type} =~ s/([A-Z])/" " . lc $1/ge;
    $args{Type} =~ s/^\s+//;
    return $args{Type};
}




=head2 FormatLink

Takes either a Target or a Base and returns a string of human friendly text.

=cut

sub FormatLink {
    my $self = shift;
    my %args = ( Object => undef,
                 FallBack => '',
                 @_
               );
    my $text = "URI " . $args{FallBack};
    if ($args{Object} && $args{Object}->isa("RT::Ticket")) {
        $text = "Ticket " . $args{Object}->id;
    }
    return $text;
}

=head2 _AddLink

Takes a paramhash of Type and one of Base or Target. Adds that link to this object.

If Silent is true then no transactions will be recorded.  You can individually
control transactions on both base and target and with SilentBase and
SilentTarget respectively. By default both transactions are created.

If the link destination is a local object and does the
L<RT::Record::Role::Status> role, this method ensures object Status is not
"deleted".  Linking to deleted objects is forbidden.

If the link destination (i.e. not C<$self>) is a local object and the
C<$StrictLinkACL> option is enabled, this method checks the appropriate right
on the destination object (if any, as returned by the L</ModifyLinkRight>
method).  B<< The subclass is expected to check the appropriate right on the
source object (i.e.  C<$self>) before calling this method. >>  This allows a
different right to be used on the source object during creation, for example.

Returns a tuple of (link ID, message, flag if link already existed).

=cut

sub _AddLink {
    my $self = shift;
    my %args = (
        Target       => '',
        Base         => '',
        Type         => '',
        Silent       => undef,
        Silent       => undef,
        SilentBase   => undef,
        SilentTarget => undef,
        @_
    );

    # Remote_link is the URI of the object that is not this ticket
    my $remote_link;
    my $direction;

    if ( $args{'Base'} and $args{'Target'} ) {
        $RT::Logger->debug( "$self tried to create a link. both base and target were specified" );
        return ( 0, $self->loc("Can't specify both base and target") );
    }
    elsif ( $args{'Base'} ) {
        $args{'Target'} = $self->URI();
        $remote_link    = $args{'Base'};
        $direction      = 'Target';
    }
    elsif ( $args{'Target'} ) {
        $args{'Base'} = $self->URI();
        $remote_link  = $args{'Target'};
        $direction    = 'Base';
    }
    else {
        return ( 0, $self->loc('Either base or target must be specified') );
    }

    my $remote_uri = RT::URI->new( $self->CurrentUser );
    if ($remote_uri->FromURI( $remote_link )) {
        my $remote_obj = $remote_uri->IsLocal ? $remote_uri->Object : undef;
        if ($remote_obj and $remote_obj->id) {
            # Enforce the remote end of StrictLinkACL
            if (RT->Config->Get("StrictLinkACL")) {
                my $right = $remote_obj->ModifyLinkRight;

                return (0, $self->loc("Permission denied"))
                    if $right and
                   not $self->CurrentUser->HasRight( Right => $right, Object => $remote_obj );
            }

            # Prevent linking to deleted objects
            if ($remote_obj->DOES("RT::Record::Role::Status")
                and $remote_obj->Status eq "deleted") {
                return (0, $self->loc("Linking to a deleted [_1] is not allowed", $self->loc(lc($remote_obj->RecordType))));
            }
        }
    } else {
        return (0, $self->loc("Couldn't resolve '[_1]' into a link.", $remote_link));
    }

    # Check if the link already exists - we don't want duplicates
    my $old_link = RT::Link->new( $self->CurrentUser );
    $old_link->LoadByParams( Base   => $args{'Base'},
                             Type   => $args{'Type'},
                             Target => $args{'Target'} );
    if ( $old_link->Id ) {
        $RT::Logger->debug("$self Somebody tried to duplicate a link");
        return ( $old_link->id, $self->loc("Link already exists"), 1 );
    }

    if ( $args{'Type'} =~ /^(?:DependsOn|MemberOf)$/ ) {

        my @tickets = $self->_AllLinkedTickets(
            LinkType  => $args{'Type'},
            Direction => $direction eq 'Target' ? 'Base' : 'Target',
        );
        if ( grep { $_->id == ( $direction eq 'Target' ? $args{'Base'} : $args{'Target'} ) } @tickets ) {
            return ( 0, $self->loc("Refused to add link which would create a circular relationship") );
        }
    }

    # Storing the link in the DB.
    my $link = RT::Link->new( $self->CurrentUser );
    my ($linkid, $linkmsg) = $link->Create( Target => $args{Target},
                                            Base   => $args{Base},
                                            Type   => $args{Type} );

    unless ($linkid) {
        $RT::Logger->error("Link could not be created: ".$linkmsg);
        return ( 0, $self->loc("Link could not be created: [_1]", $linkmsg) );
    }

    my $basetext = $self->FormatLink(Object   => $link->BaseObj,
                                     FallBack => $args{Base});
    my $targettext = $self->FormatLink(Object   => $link->TargetObj,
                                       FallBack => $args{Target});
    my $typetext = $self->FormatType(Type => $args{Type});
    my $TransString = "$basetext $typetext $targettext.";

    # No transactions for you!
    return ($linkid, $TransString) if $args{'Silent'};

    my $opposite_direction = $direction eq 'Target' ? 'Base': 'Target';

    # Some transactions?
    unless ( $args{ 'Silent'. $direction } ) {
        my ( $Trans, $Msg, $TransObj ) = $self->_NewTransaction(
            Type      => 'AddLink',
            Field     => $RT::Link::DIRMAP{$args{'Type'}}->{$direction},
            NewValue  => $remote_uri->URI || $remote_link,
            TimeTaken => 0
        );
        $RT::Logger->error("Couldn't create transaction: $Msg") unless $Trans;
    }

    if ( !$args{"Silent$opposite_direction"} && $remote_uri->IsLocal ) {
        my $OtherObj = $remote_uri->Object;
        my ( $val, $msg ) = $OtherObj->_NewTransaction(
            Type           => 'AddLink',
            Field          => $RT::Link::DIRMAP{$args{'Type'}}->{$opposite_direction},
            NewValue       => $self->URI,
            TimeTaken      => 0,
        );
        $RT::Logger->error("Couldn't create transaction: $msg") unless $val;
    }

    return ($linkid, $TransString);
}

=head2 _DeleteLink

Takes a paramhash of Type and one of Base or Target. Removes that link from this object.

If Silent is true then no transactions will be recorded.  You can individually
control transactions on both base and target and with SilentBase and
SilentTarget respectively. By default both transactions are created.

If the link destination (i.e. not C<$self>) is a local object and the
C<$StrictLinkACL> option is enabled, this method checks the appropriate right
on the destination object (if any, as returned by the L</ModifyLinkRight>
method).  B<< The subclass is expected to check the appropriate right on the
source object (i.e.  C<$self>) before calling this method. >>

Returns a tuple of (status flag, message).

=cut 

sub _DeleteLink {
    my $self = shift;
    my %args = (
        Base         => undef,
        Target       => undef,
        Type         => undef,
        Silent       => undef,
        SilentBase   => undef,
        SilentTarget => undef,
        @_
    );

    # We want one of base and target. We don't care which but we only want _one_.
    my $direction;
    my $remote_link;

    if ( $args{'Base'} and $args{'Target'} ) {
        $RT::Logger->debug("$self ->_DeleteLink. got both Base and Target");
        return ( 0, $self->loc("Can't specify both base and target") );
    }
    elsif ( $args{'Base'} ) {
        $args{'Target'} = $self->URI();
        $remote_link    = $args{'Base'};
        $direction      = 'Target';
    }
    elsif ( $args{'Target'} ) {
        $args{'Base'} = $self->URI();
        $remote_link  = $args{'Target'};
        $direction    = 'Base';
    }
    else {
        $RT::Logger->error("Base or Target must be specified");
        return ( 0, $self->loc('Either base or target must be specified') );
    }

    my $remote_uri = RT::URI->new( $self->CurrentUser );
    if ($remote_uri->FromURI( $remote_link )) {
        # Enforce the remote end of StrictLinkACL
        my $remote_obj = $remote_uri->IsLocal ? $remote_uri->Object : undef;
        if ($remote_obj and $remote_obj->id and RT->Config->Get("StrictLinkACL")) {
            my $right = $remote_obj->ModifyLinkRight;

            return (0, $self->loc("Permission denied"))
                if $right and
               not $self->CurrentUser->HasRight( Right => $right, Object => $remote_obj );
        }
    } else {
        return (0, $self->loc("Couldn't resolve '[_1]' into a link.", $remote_link));
    }

    my $link = RT::Link->new( $self->CurrentUser );
    $RT::Logger->debug( "Trying to load link: "
            . $args{'Base'} . " "
            . $args{'Type'} . " "
            . $args{'Target'} );

    $link->LoadByParams(
        Base   => $args{'Base'},
        Type   => $args{'Type'},
        Target => $args{'Target'}
    );

    unless ($link->id) {
        $RT::Logger->debug("Couldn't find that link");
        return ( 0, $self->loc("Link not found") );
    }

    my $basetext = $self->FormatLink(Object   => $link->BaseObj,
                                     FallBack => $args{Base});
    my $targettext = $self->FormatLink(Object   => $link->TargetObj,
                                       FallBack => $args{Target});
    my $typetext = $self->FormatType(Type => $args{Type});
    my $TransString = "$basetext no longer $typetext $targettext.";

    my ($ok, $msg) = $link->Delete();
    unless ($ok) {
        RT->Logger->error("Link could not be deleted: $msg");
        return ( 0, $self->loc("Link could not be deleted: [_1]", $msg) );
    }

    # No transactions for you!
    return (1, $TransString) if $args{'Silent'};

    my $opposite_direction = $direction eq 'Target' ? 'Base': 'Target';

    # Some transactions?
    unless ( $args{ 'Silent'. $direction } ) {
        my ( $Trans, $Msg, $TransObj ) = $self->_NewTransaction(
            Type      => 'DeleteLink',
            Field     => $RT::Link::DIRMAP{$args{'Type'}}->{$direction},
            OldValue  => $remote_uri->URI || $remote_link,
            TimeTaken => 0
        );
        $RT::Logger->error("Couldn't create transaction: $Msg") unless $Trans;
    }

    if ( !$args{"Silent$opposite_direction"} && $remote_uri->IsLocal ) {
        my $OtherObj = $remote_uri->Object;
        my ( $val, $msg ) = $OtherObj->_NewTransaction(
            Type           => 'DeleteLink',
            Field          => $RT::Link::DIRMAP{$args{'Type'}}->{$opposite_direction},
            OldValue       => $self->URI,
            TimeTaken      => 0,
        );
        $RT::Logger->error("Couldn't create transaction: $msg") unless $val;
    }

    return (1, $TransString);
}

=head1 LockForUpdate

In a database transaction, gains an exclusive lock on the row, to
prevent race conditions.  On SQLite, this is a "RESERVED" lock on the
entire database.

=cut

sub LockForUpdate {
    my $self = shift;

    my $pk = $self->_PrimaryKey;
    my $id = @_ ? $_[0] : $self->$pk;
    $self->_expire if $self->isa("DBIx::SearchBuilder::Record::Cachable");
    if (RT->Config->Get('DatabaseType') eq "SQLite") {
        # SQLite does DB-level locking, upgrading the transaction to
        # "RESERVED" on the first UPDATE/INSERT/DELETE.  Do a no-op
        # UPDATE to force the upgade.
        return RT->DatabaseHandle->dbh->do(
            "UPDATE " .$self->Table.
                " SET $pk = $pk WHERE 1 = 0");
    } else {
        return $self->_LoadFromSQL(
            "SELECT * FROM ".$self->Table
                ." WHERE $pk = ? FOR UPDATE",
            $id,
        );
    }
}

=head2 _NewTransaction  PARAMHASH

Private function to create a new RT::Transaction object for this ticket update

=cut

sub _NewTransaction {
    my $self = shift;
    my %args = (
        TimeTaken => undef,
        Type      => undef,
        OldValue  => undef,
        NewValue  => undef,
        OldReference  => undef,
        NewReference  => undef,
        ReferenceType => undef,
        Data      => undef,
        Field     => undef,
        MIMEObj   => undef,
        ActivateScrips => 1,
        SquelchMailTo => undef,
        @_
    );

    my $in_txn = RT->DatabaseHandle->TransactionDepth;
    RT->DatabaseHandle->BeginTransaction unless $in_txn;

    $self->LockForUpdate;

    my $old_ref = $args{'OldReference'};
    my $new_ref = $args{'NewReference'};
    my $ref_type = $args{'ReferenceType'};
    if ($old_ref or $new_ref) {
        $ref_type ||= ref($old_ref) || ref($new_ref);
        if (!$ref_type) {
            $RT::Logger->error("Reference type not specified for transaction");
            return;
        }
        $old_ref = $old_ref->Id if ref($old_ref);
        $new_ref = $new_ref->Id if ref($new_ref);
    }

    require RT::Transaction;
    my $trans = RT::Transaction->new( $self->CurrentUser );
    my ( $transaction, $msg ) = $trans->Create(
        ObjectId  => $self->Id,
        ObjectType => ref($self),
        TimeTaken => $args{'TimeTaken'},
        Type      => $args{'Type'},
        Data      => $args{'Data'},
        Field     => $args{'Field'},
        NewValue  => $args{'NewValue'},
        OldValue  => $args{'OldValue'},
        NewReference  => $new_ref,
        OldReference  => $old_ref,
        ReferenceType => $ref_type,
        MIMEObj   => $args{'MIMEObj'},
        ActivateScrips => $args{'ActivateScrips'},
        DryRun => $self->{DryRun},
        SquelchMailTo => $args{'SquelchMailTo'} || $self->{TransSquelchMailTo},
    );

    # Rationalize the object since we may have done things to it during the caching.
    $self->Load($self->Id);

    $RT::Logger->warning($msg) unless $transaction;

    $self->_SetLastUpdated;

    if ( defined $args{'TimeTaken'} and $self->can('_UpdateTimeTaken')) {
        $self->_UpdateTimeTaken( $args{'TimeTaken'}, Transaction => $trans );
    }
    if ( RT->Config->Get('UseTransactionBatch') and $transaction ) {
        push @{$self->{_TransactionBatch}}, $trans;
    }

    RT->DatabaseHandle->Commit unless $in_txn;

    return ( $transaction, $msg, $trans );
}



=head2 Transactions

Returns an L<RT::Transactions> object of all transactions on this record object

=cut

sub Transactions {
    my $self = shift;

    my $transactions = RT::Transactions->new( $self->CurrentUser );
    $transactions->Limit(
        FIELD => 'ObjectId',
        VALUE => $self->id,
    );
    $transactions->Limit(
        FIELD => 'ObjectType',
        VALUE => ref($self),
    );

    return $transactions;
}

=head2 SortedTransactions

Returns the result of L</Transactions> ordered per the
I<OldestTransactionsFirst> preference/option.

=cut

sub SortedTransactions {
    my $self  = shift;
    my $txns  = $self->Transactions;
    my $order = RT->Config->Get("OldestTransactionsFirst", $self->CurrentUser)
        ? 'ASC' : 'DESC';
    $txns->OrderByCols(
        { FIELD => 'Created',   ORDER => $order },
        { FIELD => 'id',        ORDER => $order },
    );
    return $txns;
}

our %TRANSACTION_CLASSIFICATION = (
    Create     => 'message',
    Correspond => 'message',
    Comment    => 'message',

    AddWatcher => 'people',
    DelWatcher => 'people',

    Take       => 'people',
    Untake     => 'people',
    Force      => 'people',
    Steal      => 'people',
    Give       => 'people',

    AddLink    => 'links',
    DeleteLink => 'links',

    Status     => 'basics',
    Set        => {
        __default => 'basics',
        map( { $_ => 'dates' } qw(
            Told Starts Started Due LastUpdated Created LastUpdated
        ) ),
        map( { $_ => 'people' } qw(
            Owner Creator LastUpdatedBy
        ) ),
    },
    SystemError => 'error',
    AttachmentTruncate => 'attachment-truncate',
    AttachmentDrop => 'attachment-drop',
    AttachmentError => 'error',
    __default => 'other',
);

sub ClassifyTransaction {
    my $self = shift;
    my $txn = shift;

    my $type = $txn->Type;

    my $res = $TRANSACTION_CLASSIFICATION{ $type };
    return $res || $TRANSACTION_CLASSIFICATION{ '__default' }
        unless ref $res;

    return $res->{ $txn->Field } || $res->{'__default'}
        || $TRANSACTION_CLASSIFICATION{ '__default' }; 
}

=head2 Attachments

Returns an L<RT::Attachments> object of all attachments on this record object
(for all its L</Transactions>).

By default Content and Headers of attachments are not fetched right away from
database. Use C<WithContent> and C<WithHeaders> options to override this.

=cut

sub Attachments {
    my $self = shift;
    my %args = (
        WithHeaders => 0,
        WithContent => 0,
        @_
    );
    my @columns = grep { not /^(Headers|Content)$/ }
                       RT::Attachment->ReadableAttributes;
    push @columns, 'Headers' if $args{'WithHeaders'};
    push @columns, 'Content' if $args{'WithContent'};

    my $res = RT::Attachments->new( $self->CurrentUser );
    $res->Columns( @columns );
    my $txn_alias = $res->TransactionAlias;
    $res->Limit(
        ALIAS => $txn_alias,
        FIELD => 'ObjectType',
        VALUE => ref($self),
    );
    $res->Limit(
        ALIAS => $txn_alias,
        FIELD => 'ObjectId',
        VALUE => $self->id,
    );
    return $res;
}

=head2 TextAttachments

Returns an L<RT::Attachments> object of all attachments, like L<Attachments>,
but only those that are text.

By default Content and Headers are fetched. Use C<WithContent> and
C<WithHeaders> options to override this.

=cut

sub TextAttachments {
    my $self = shift;
    my $res = $self->Attachments(
        WithHeaders => 1,
        WithContent => 1,
        @_
    );
    $res->Limit( FIELD => 'ContentType', OPERATOR => '=', VALUE => 'text/plain');
    $res->Limit( FIELD => 'ContentType', OPERATOR => 'STARTSWITH', VALUE => 'message/');
    $res->Limit( FIELD => 'ContentType', OPERATOR => '=', VALUE => 'text');
    $res->Limit( FIELD => 'Filename', OPERATOR => 'IS', VALUE => 'NULL')
        if RT->Config->Get( 'SuppressInlineTextFiles', $self->CurrentUser );
    return $res;
}

sub CustomFields {
    my $self = shift;
    my $cfs  = RT::CustomFields->new( $self->CurrentUser );
    
    $cfs->SetContextObject( $self );
    # XXX handle multiple types properly
    $cfs->LimitToLookupType( $self->CustomFieldLookupType );
    $cfs->LimitToGlobalOrObjectId( $self->CustomFieldLookupId );
    $cfs->ApplySortOrder;

    return $cfs;
}

# TODO: This _only_ works for RT::Foo classes. it doesn't work, for
# example, for RT::IR::Foo classes.

sub CustomFieldLookupId {
    my $self = shift;
    my $lookup = shift || $self->CustomFieldLookupType;
    my @classes = ($lookup =~ /RT::(\w+)-/g);

    # Work on "RT::Queue", for instance
    return $self->Id unless @classes;

    my $object = $self;
    # Save a ->Load call by not calling ->FooObj->Id, just ->Foo
    my $final = shift @classes;
    foreach my $class (reverse @classes) {
        my $method = "${class}Obj";
        $object = $object->$method;
    }

    my $id = $object->$final;
    unless (defined $id) {
        my $method = "${final}Obj";
        $id = $object->$method->Id;
    }
    return $id;
}


=head2 CustomFieldLookupType 

Returns the path RT uses to figure out which custom fields apply to this object.

=cut

sub CustomFieldLookupType {
    my $self = shift;
    return ref($self) || $self;
}


=head2 AddCustomFieldValue { Field => FIELD, Value => VALUE }

VALUE should be a string. FIELD can be any identifier of a CustomField
supported by L</LoadCustomFieldByIdentifier> method.

Adds VALUE as a value of CustomField FIELD. If this is a single-value custom field,
deletes the old value.
If VALUE is not a valid value for the custom field, returns 
(0, 'Error message' ) otherwise, returns ($id, 'Success Message') where
$id is ID of created L<ObjectCustomFieldValue> object.

=cut

sub AddCustomFieldValue {
    my $self = shift;
    $self->_AddCustomFieldValue(@_);
}

sub _AddCustomFieldValue {
    my $self = shift;
    my %args = (
        Field             => undef,
        Value             => undef,
        LargeContent      => undef,
        ContentType       => undef,
        RecordTransaction => 1,
        ForCreation       => 0,
        @_
    );

    my $cf = $self->LoadCustomFieldByIdentifier($args{'Field'});
    $cf->{include_set_initial} = 1 if $args{'ForCreation'};

    unless ( $cf->Id ) {
        return ( 0, $self->loc( "Custom field [_1] not found", $args{'Field'} ) );
    }

    my $OCFs = $self->CustomFields;
    $OCFs->Limit( FIELD => 'id', VALUE => $cf->Id );
    unless ( $OCFs->Count ) {
        return (
            0,
            $self->loc(
                "Custom field [_1] does not apply to this object",
                ref $args{'Field'} ? $args{'Field'}->id : $args{'Field'}
            )
        );
    }

    # empty string is not correct value of any CF, so undef it
    foreach ( qw(Value LargeContent) ) {
        $args{ $_ } = undef if defined $args{ $_ } && !length $args{ $_ };
    }

    unless ( $cf->ValidateValue( $args{'Value'} ) ) {
        return ( 0, $self->loc("Invalid value for custom field") );
    }

    # If the custom field only accepts a certain # of values, delete the existing
    # value and record a "changed from foo to bar" transaction
    unless ( $cf->UnlimitedValues ) {

        # Load up a ObjectCustomFieldValues object for this custom field and this ticket
        my $values = $cf->ValuesForObject($self);

        # We need to whack any old values here.  In most cases, the custom field should
        # only have one value to delete.  In the pathalogical case, this custom field
        # used to be a multiple and we have many values to whack....
        my $cf_values = $values->Count;

        if ( $cf_values > $cf->MaxValues ) {
            my $i = 0;   #We want to delete all but the max we can currently have , so we can then
                 # execute the same code to "change" the value from old to new
            while ( my $value = $values->Next ) {
                $i++;
                if ( $i < $cf_values ) {
                    my ( $val, $msg ) = $cf->DeleteValueForObject(
                        Object => $self,
                        Id     => $value->id,
                    );
                    unless ($val) {
                        return ( 0, $msg );
                    }
                    my ( $TransactionId, $Msg, $TransactionObj ) =
                      $self->_NewTransaction(
                        Type         => 'CustomField',
                        Field        => $cf->Id,
                        OldReference => $value,
                      );
                }
            }
            $values->RedoSearch if $i; # redo search if have deleted at least one value
        }

        if ( my $entry = $values->HasEntry($args{'Value'}, $args{'LargeContent'}) ) {
            return $entry->id;
        }

        my $old_value = $values->First;
        my $old_content;
        $old_content = $old_value->Content if $old_value;

        my ( $new_value_id, $value_msg ) = $cf->AddValueForObject(
            Object       => $self,
            Content      => $args{'Value'},
            LargeContent => $args{'LargeContent'},
            ContentType  => $args{'ContentType'},
            ForCreation  => $args{'ForCreation'},
        );

        unless ( $new_value_id ) {
            return ( 0, $self->loc( "Could not add new custom field value: [_1]", $value_msg ) );
        }

        my $new_value = RT::ObjectCustomFieldValue->new( $self->CurrentUser );
        $new_value->{include_set_initial} = 1 if $args{'ForCreation'};
        $new_value->Load( $new_value_id );

        # now that adding the new value was successful, delete the old one
        if ( $old_value ) {
            my ( $val, $msg ) = $old_value->Delete();
            return ( 0, $msg ) unless $val;
        }

        if ( $args{'RecordTransaction'} ) {
            my ( $TransactionId, $Msg, $TransactionObj ) =
              $self->_NewTransaction(
                Type         => 'CustomField',
                Field        => $cf->Id,
                OldReference => $old_value,
                NewReference => $new_value,
              );
        }

        my $new_content = $new_value->Content;

        # For datetime, we need to display them in "human" format in result message
        #XXX TODO how about date without time?
        if ($cf->Type eq 'DateTime') {
            my $DateObj = RT::Date->new( $self->CurrentUser );
            $DateObj->Set(
                Format => 'ISO',
                Value  => $new_content,
            );
            $new_content = $DateObj->AsString;

            if ( defined $old_content && length $old_content ) {
                $DateObj->Set(
                    Format => 'ISO',
                    Value  => $old_content,
                );
                $old_content = $DateObj->AsString;
            }
        }

        unless ( defined $old_content && length $old_content ) {
            return ( $new_value_id, $self->loc( "[_1] [_2] added", $cf->Name, $new_content ));
        }
        elsif ( !defined $new_content || !length $new_content ) {
            return ( $new_value_id,
                $self->loc( "[_1] [_2] deleted", $cf->Name, $old_content ) );
        }
        else {
            return ( $new_value_id, $self->loc( "[_1] [_2] changed to [_3]", $cf->Name, $old_content, $new_content));
        }

    }

    # otherwise, just add a new value and record "new value added"
    else {
        my $values = $cf->ValuesForObject($self);
        if ( my $entry = $values->HasEntry($args{'Value'}, $args{'LargeContent'}) ) {
            return $entry->id;
        }

        my ($new_value_id, $msg) = $cf->AddValueForObject(
            Object       => $self,
            Content      => $args{'Value'},
            LargeContent => $args{'LargeContent'},
            ContentType  => $args{'ContentType'},
            ForCreation  => $args{'ForCreation'},
        );

        unless ( $new_value_id ) {
            return ( 0, $self->loc( "Could not add new custom field value: [_1]", $msg ) );
        }

        if ( $args{'RecordTransaction'} ) {
            my ( $tid, $msg ) = $self->_NewTransaction(
                Type          => 'CustomField',
                Field         => $cf->Id,
                NewReference  => $new_value_id,
                ReferenceType => 'RT::ObjectCustomFieldValue',
            );
            unless ( $tid ) {
                return ( 0, $self->loc( "Couldn't create a transaction: [_1]", $msg ) );
            }
        }
        return ( $new_value_id, $self->loc( "[_1] added as a value for [_2]", $args{'Value'}, $cf->Name ) );
    }
}

=head2 AddCustomFieldDefaultValues

Add default values to object's empty custom fields.

=cut

sub AddCustomFieldDefaultValues {
    my $self = shift;
    my $cfs  = $self->CustomFields;
    my @msgs;
    while ( my $cf = $cfs->Next ) {
        next if $self->CustomFieldValues($cf->id)->Count || !$cf->SupportDefaultValues;
        my ( $on ) = grep { $_->isa( $cf->RecordClassFromLookupType ) } $cf->ACLEquivalenceObjects;
        my $values = $cf->DefaultValues( Object => $on || RT->System );
        foreach my $value ( UNIVERSAL::isa( $values => 'ARRAY' ) ? @$values : $values ) {
            next if $self->CustomFieldValueIsEmpty(
                Field => $cf,
                Value => $value,
            );

            my ( $status, $msg ) = $self->_AddCustomFieldValue(
                Field             => $cf->id,
                Value             => $value,
                RecordTransaction => 0,
            );
            push @msgs, $msg unless $status;
        }
    }
    return ( 0, @msgs ) if @msgs;
    return 1;
}

=head2 CustomFieldValueIsEmpty { Field => FIELD, Value => VALUE }

Check if the custom field value is empty.

Some custom fields could have other special empty values, e.g. "1970-01-01" is empty for Date cf

Return 1 if it is empty, 0 otherwise.

=cut


sub CustomFieldValueIsEmpty {
    my $self = shift;
    my %args = (
        Field => undef,
        Value => undef,
        @_
    );
    my $value = $args{Value};
    return 1 unless defined $value  && length $value;

    my $cf = ref($args{'Field'})
           ? $args{'Field'}
           : $self->LoadCustomFieldByIdentifier( $args{'Field'} );

    if ($cf) {
        if ( $cf->Type =~ /^Date(?:Time)?$/ ) {
            my $DateObj = RT::Date->new( $self->CurrentUser );
            $DateObj->Set(
                Format => 'unknown',
                Value  => $value,
                $cf->Type eq 'Date' ? ( Timezone => 'UTC' ) : (),
            );
            return 1 unless $DateObj->IsSet;
        }
    }
    return 0;
}

=head2 DeleteCustomFieldValue { Field => FIELD, Value => VALUE }

Deletes VALUE as a value of CustomField FIELD. 

VALUE can be a string, a CustomFieldValue or a ObjectCustomFieldValue.

If VALUE is not a valid value for the custom field, returns 
(0, 'Error message' ) otherwise, returns (1, 'Success Message')

=cut

sub DeleteCustomFieldValue {
    my $self = shift;
    my %args = (
        Field   => undef,
        Value   => undef,
        ValueId => undef,
        @_
    );

    my $cf = $self->LoadCustomFieldByIdentifier($args{'Field'});
    unless ( $cf->Id ) {
        return ( 0, $self->loc( "Custom field [_1] not found", $args{'Field'} ) );
    }

    my ( $val, $msg ) = $cf->DeleteValueForObject(
        Object  => $self,
        Id      => $args{'ValueId'},
        Content => $args{'Value'},
    );
    unless ($val) {
        return ( 0, $msg );
    }

    my ( $TransactionId, $Msg, $TransactionObj ) = $self->_NewTransaction(
        Type          => 'CustomField',
        Field         => $cf->Id,
        OldReference  => $val,
        ReferenceType => 'RT::ObjectCustomFieldValue',
    );
    unless ($TransactionId) {
        return ( 0, $self->loc( "Couldn't create a transaction: [_1]", $Msg ) );
    }

    my $old_value = $TransactionObj->OldValue;
    # For datetime, we need to display them in "human" format in result message
    if ( $cf->Type eq 'DateTime' ) {
        my $DateObj = RT::Date->new( $self->CurrentUser );
        $DateObj->Set(
            Format => 'ISO',
            Value  => $old_value,
        );
        $old_value = $DateObj->AsString;
    }
    return (
        $TransactionId,
        $self->loc(
            "[_1] is no longer a value for custom field [_2]",
            $old_value, $cf->Name
        )
    );
}



=head2 FirstCustomFieldValue FIELD

Return the content of the first value of CustomField FIELD for this ticket
Takes a field id or name

=cut

sub FirstCustomFieldValue {
    my $self = shift;
    my $field = shift;

    my $values = $self->CustomFieldValues( $field );
    return undef unless my $first = $values->First;
    return $first->Content;
}

=head2 CustomFieldValuesAsString FIELD

Return the content of the CustomField FIELD for this ticket.
If this is a multi-value custom field, values will be joined with newlines.

Takes a field id or name as the first argument

Takes an optional Separator => "," second and third argument
if you want to join the values using something other than a newline

=cut

sub CustomFieldValuesAsString {
    my $self  = shift;
    my $field = shift;
    my %args  = @_;
    my $separator = $args{Separator} || "\n";

    my $values = $self->CustomFieldValues( $field );
    return join ($separator, grep { defined $_ }
                 map { $_->Content } @{$values->ItemsArrayRef});
}



=head2 CustomFieldValues FIELD

Return a ObjectCustomFieldValues object of all values of the CustomField whose 
id or Name is FIELD for this record.

Returns an RT::ObjectCustomFieldValues object

=cut

sub CustomFieldValues {
    my $self  = shift;
    my $field = shift;

    if ( $field ) {
        my $cf = $self->LoadCustomFieldByIdentifier( $field );

        # we were asked to search on a custom field we couldn't find
        unless ( $cf->id ) {
            $RT::Logger->warning("Couldn't load custom field by '$field' identifier");
            return RT::ObjectCustomFieldValues->new( $self->CurrentUser );
        }
        return ( $cf->ValuesForObject($self) );
    }

    # we're not limiting to a specific custom field;
    my $ocfs = RT::ObjectCustomFieldValues->new( $self->CurrentUser );
    $ocfs->LimitToObject( $self );
    return $ocfs;
}

=head2 LoadCustomFieldByIdentifier IDENTIFER

Find the custom field has id or name IDENTIFIER for this object.

If no valid field is found, returns an empty RT::CustomField object.

=cut

sub LoadCustomFieldByIdentifier {
    my $self = shift;
    my $field = shift;
    
    my $cf;
    if ( UNIVERSAL::isa( $field, "RT::CustomField" ) ) {
        $cf = RT::CustomField->new($self->CurrentUser);
        $cf->SetContextObject( $self );
        $cf->LoadById( $field->id );
    }
    elsif ($field =~ /^\d+$/) {
        $cf = RT::CustomField->new($self->CurrentUser);
        $cf->SetContextObject( $self );
        $cf->LoadById($field);
    } else {

        my $cfs = $self->CustomFields($self->CurrentUser);
        $cfs->SetContextObject( $self );
        $cfs->Limit(FIELD => 'Name', VALUE => $field, CASESENSITIVE => 0);
        $cf = $cfs->First || RT::CustomField->new($self->CurrentUser);
    }
    return $cf;
}

sub ACLEquivalenceObjects { } 

=head2 HasRight

 Takes a paramhash with the attributes 'Right' and 'Principal'
  'Right' is a ticket-scoped textual right from RT::ACE 
  'Principal' is an RT::User object

  Returns 1 if the principal has the right. Returns undef if not.

=cut

sub HasRight {
    my $self = shift;
    my %args = (
        Right     => undef,
        Principal => undef,
        @_
    );

    $args{Principal} ||= $self->CurrentUser->PrincipalObj;

    return $args{'Principal'}->HasRight(
        Object => $self->Id ? $self : $RT::System,
        Right  => $args{'Right'}
    );
}

sub CurrentUserHasRight {
    my $self = shift;
    return $self->HasRight( Right => @_ );
}

sub ModifyLinkRight { }

=head2 ColumnMapClassName

ColumnMap needs a massaged collection class name to load the correct list
display.  Equivalent to L<RT::SearchBuilder/ColumnMapClassName>, but provided
for a record instead of a collection.

Returns a string.  May be called as a package method.

=cut

sub ColumnMapClassName {
    my $self  = shift;
    my $Class = ref($self) || $self;
       $Class =~ s/:/_/g;
    return $Class;
}

sub BasicColumns { }

sub WikiBase {
    return RT->Config->Get('WebPath'). "/index.html?q=";
}

sub UID {
    my $self = shift;
    return undef unless defined $self->Id;
    return "@{[ref $self]}-$RT::Organization-@{[$self->Id]}";
}

sub FindDependencies {
    my $self = shift;
    my ($walker, $deps) = @_;
    for my $col (qw/Creator LastUpdatedBy/) {
        if ( $self->_Accessible( $col, 'read' ) ) {
            next unless $self->$col;
            my $obj = RT::Principal->new( $self->CurrentUser );
            $obj->Load( $self->$col );
            $deps->Add( out => $obj->Object );
        }
    }

    # Object attributes, we have to check on every object
    my $objs = $self->Attributes;
    $deps->Add( in => $objs );

    # Transactions
    if (   $self->isa("RT::Ticket")
        or $self->isa("RT::User")
        or $self->isa("RT::Group")
        or $self->isa("RT::Article")
        or $self->isa("RT::Asset")
        or $self->isa("RT::Catalog")
        or $self->isa("RT::Queue") )
    {
        $objs = RT::Transactions->new( $self->CurrentUser );
        $objs->Limit( FIELD => 'ObjectType', VALUE => ref $self );
        $objs->Limit( FIELD => 'ObjectId', VALUE => $self->id );
        $deps->Add( in => $objs );
    }

    # Object custom field values
    if ((   $self->isa("RT::Transaction")
         or $self->isa("RT::Ticket")
         or $self->isa("RT::User")
         or $self->isa("RT::Group")
         or $self->isa("RT::Asset")
         or $self->isa("RT::Queue")
         or $self->isa("RT::Article") )
            and $self->can("CustomFieldValues") )
    {
        $objs = $self->CustomFieldValues; # Actually OCFVs
        $objs->{find_disabled_rows} = 1;
        $deps->Add( in => $objs );
    }

    # ACE records
    if (   $self->isa("RT::Group")
        or $self->isa("RT::Class")
        or $self->isa("RT::Queue")
        or $self->isa("RT::CustomField") )
    {
        $objs = RT::ACL->new( $self->CurrentUser );
        $objs->LimitToObject( $self );
        $deps->Add( in => $objs );
    }
}

sub Serialize {
    my $self = shift;
    my %args = (
        Methods => {},
        UIDs    => 1,
        @_,
    );
    my %methods = (
        Creator       => "CreatorObj",
        LastUpdatedBy => "LastUpdatedByObj",
        %{ $args{Methods} || {} },
    );

    my %values = %{$self->{values}};

    my %ca = %{ $self->_ClassAccessible };
    my @cols = grep {exists $values{lc $_} and defined $values{lc $_}} keys %ca;

    my %store;
    $store{$_} = $values{lc $_} for @cols;
    $store{id} = $values{id}; # Explicitly necessary in some cases

    # Un-apply the _transfer_ encoding, but don't mess with the octets
    # themselves.  Calling ->Content directly would, in some cases,
    # decode from some mostly-unknown character set -- which reversing
    # on the far end would be complicated.
    if ($ca{ContentEncoding} and $ca{ContentType}) {
        my ($content_col) = grep {exists $ca{$_}} qw/LargeContent Content/;
        $store{$content_col} = $self->_DecodeLOB(
            "application/octet-stream", # Lie so that we get bytes, not characters
            $self->ContentEncoding,
            $self->_Value( $content_col, decode_utf8 => 0 )
        );
        delete $store{ContentEncoding};
    }
    return %store unless $args{UIDs};

    # Use FooObj to turn Foo into a reference to the UID
    for my $col ( grep {$store{$_}} @cols ) {
        my $method = $methods{$col};
        if (not $method) {
            $method = $col;
            $method =~ s/(Id)?$/Obj/;
        }
        next unless $self->can($method);

        my $obj = $self->$method;
        next unless $obj and $obj->isa("RT::Record");
        $store{$col} = \($obj->UID);
    }

    # Anything on an object should get the UID stored instead
    if ($store{ObjectType} and $store{ObjectId} and $self->can("Object")) {
        delete $store{$_} for qw/ObjectType ObjectId/;
        $store{Object} = \($self->Object->UID);
    }

    return %store;
}

sub PreInflate {
    my $class = shift;
    my ($importer, $uid, $data) = @_;

    my $ca = $class->_ClassAccessible;
    my %ca = %{ $ca };

    if ($ca{ContentEncoding} and $ca{ContentType}) {
        my ($content_col) = grep {exists $ca{$_}} qw/LargeContent Content/;
        if (defined $data->{$content_col}) {
            my ($ContentEncoding, $Content) = $class->_EncodeLOB(
                $data->{$content_col}, $data->{ContentType},
            );
            $data->{ContentEncoding} = $ContentEncoding;
            $data->{$content_col} = $Content;
        }
    }

    if ($data->{Object} and not $ca{Object}) {
        my $ref_uid = ${ delete $data->{Object} };
        my $ref = $importer->Lookup( $ref_uid );
        if ($ref) {
            my ($class, $id) = @{$ref};
            $data->{ObjectId} = $id;
            $data->{ObjectType} = $class;
        } else {
            $data->{ObjectId} = 0;
            $data->{ObjectType} = "";
            $importer->Postpone(
                for => $ref_uid,
                uid => $uid,
                column => "ObjectId",
                classcolumn => "ObjectType",
            );
        }
    }

    for my $col (keys %{$data}) {
        if (ref $data->{$col}) {
            my $ref_uid = ${ $data->{$col} };
            my $ref = $importer->Lookup( $ref_uid );
            if ($ref) {
                my (undef, $id) = @{$ref};
                $data->{$col} = $id;
            } else {
                $data->{$col} = 0;
                $importer->Postpone(
                    for => $ref_uid,
                    uid => $uid,
                    column => $col,
                );
            }
        }
    }

    return 1;
}

sub PostInflate {
}

=head2 _AsInsertQuery

Returns INSERT query string that duplicates current record and
can be used to insert record back into DB after delete.

=cut

sub _AsInsertQuery
{
    my $self = shift;

    my $dbh = $RT::Handle->dbh;

    my $res = "INSERT INTO ". $dbh->quote_identifier( $self->Table );
    my $values = $self->{'values'};
    $res .= "(". join( ",", map { $dbh->quote_identifier( $_ ) } sort keys %$values ) .")";
    $res .= " VALUES";
    $res .= "(". join( ",", map { $dbh->quote( $values->{$_} ) } sort keys %$values ) .")";
    $res .= ";";

    return $res;
}

sub BeforeWipeout { return 1 }

=head2 Dependencies

Returns L<RT::Shredder::Dependencies> object.

=cut

sub Dependencies
{
    my $self = shift;
    my %args = (
            Shredder => undef,
            Flags => RT::Shredder::Constants::DEPENDS_ON,
            @_,
           );

    unless( $self->id ) {
        RT::Shredder::Exception->throw('Object is not loaded');
    }

    my $deps = RT::Shredder::Dependencies->new();
    if( $args{'Flags'} & RT::Shredder::Constants::DEPENDS_ON ) {
        $self->__DependsOn( %args, Dependencies => $deps );
    }
    return $deps;
}

sub __DependsOn
{
    my $self = shift;
    my %args = (
            Shredder => undef,
            Dependencies => undef,
            @_,
           );
    my $deps = $args{'Dependencies'};
    my $list = [];

# Object custom field values
    my $objs = $self->CustomFieldValues;
    $objs->{'find_disabled_rows'} = 1;
    push( @$list, $objs );

# Object attributes
    $objs = $self->Attributes;
    push( @$list, $objs );

# Transactions
    $objs = RT::Transactions->new( $self->CurrentUser );
    $objs->Limit( FIELD => 'ObjectType', VALUE => ref $self );
    $objs->Limit( FIELD => 'ObjectId', VALUE => $self->id );
    push( @$list, $objs );

# Links
    if ( $self->can('Links') ) {
        # make sure we don't skip any record
        no warnings 'redefine';
        local *RT::Links::IsValidLink = sub { 1 };

        foreach ( qw(Base Target) ) {
            my $objs = $self->Links( $_ );
            $objs->_DoSearch;
            push @$list, $objs->ItemsArrayRef;
        }
    }

# ACE records
    $objs = RT::ACL->new( $self->CurrentUser );
    $objs->LimitToObject( $self );
    push( @$list, $objs );

    $deps->_PushDependencies(
            BaseObject => $self,
            Flags => RT::Shredder::Constants::DEPENDS_ON,
            TargetObjects => $list,
            Shredder => $args{'Shredder'}
        );
    return;
}

# implement proxy method because some RT classes
# override Delete method
sub __Wipeout
{
    my $self = shift;
    my $msg = $self->UID ." wiped out";
    $self->SUPER::Delete;
    $RT::Logger->info( $msg );
    return;
}

RT::Base->_ImportOverlays();

1;
