# BEGIN BPS TAGGED BLOCK {{{
#
# COPYRIGHT:
#
# This software is Copyright (c) 1996-2017 Best Practical Solutions, LLC
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


use RT::Date;
use RT::User;
use RT::Attributes;

our $_TABLE_ATTR = { };
use base RT->Config->Get('RecordBaseClass');
use base 'RT::Base';


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

        return(0, $self->loc("Object could not be deleted"))
    } 
}

=head2 ObjectTypeStr

Returns a string which is this object's type.  The type is the class,
without the "RT::" prefix.


=cut

sub ObjectTypeStr {
    my $self = shift;
    if (ref($self) =~ /^.*::(\w+)$/) {
	return $self->loc($1);
    } else {
	return $self->loc(ref($self));
    }
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

    return $self->SUPER::LoadByCols( @_ ) unless $self->_Handle->CaseSensitive;

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
    return $self->SUPER::LoadByCols( %hash );
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


#
# TODO: This should be deprecated
#
sub AgeAsString {
    my $self = shift;
    return ( $self->CreatedObj->AgeAsString() );
}



# TODO this should be deprecated

sub LastUpdatedAsString {
    my $self = shift;
    if ( $self->LastUpdated ) {
        return ( $self->LastUpdatedObj->AsString() );

    }
    else {
        return "never";
    }
}


#
# TODO This should be deprecated 
#
sub CreatedAsString {
    my $self = shift;
    return ( $self->CreatedObj->AsString() );
}


#
# TODO This should be deprecated
#
sub LongSinceUpdateAsString {
    my $self = shift;
    if ( $self->LastUpdated ) {

        return ( $self->LastUpdatedObj->AgeAsString() );

    }
    else {
        return "never";
    }
}



#
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
    use RT::Date;
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
  return 0 unless defined ($_TABLE_ATTR->{ref($self)}->{$column});
  return $_TABLE_ATTR->{ref($self)}->{$column}->{$attribute} || 0;

}

=head2 _EncodeLOB BODY MIME_TYPE FILENAME

Takes a potentially large attachment. Returns (ContentEncoding,
EncodedBody, MimeType, Filename) based on system configuration and
selected database.  Returns a custom (short) text/plain message if
DropLongAttachments causes an attachment to not be stored.

Encodes your data as base64 or Quoted-Printable as needed based on your
Databases's restrictions and the UTF-8ness of the data being passed in.  Since
we are storing in columns marked UTF8, we must ensure that binary data is
encoded on databases which are strict.

This function expects to receive an octet string in order to properly
evaluate and encode it.  It will return an octet string.

=cut

sub _EncodeLOB {
    my $self = shift;
    my $Body = shift;
    my $MIMEType = shift || '';
    my $Filename = shift;

    my $ContentEncoding = 'none';

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

        # if we're supposed to truncate large attachments
        if (RT->Config->Get('TruncateLongAttachments')) {

            # truncate the attachment to that length.
            $Body = substr( $Body, 0, $MaxSize );

        }

        # elsif we're supposed to drop large attachments on the floor,
        elsif (RT->Config->Get('DropLongAttachments')) {

            # drop the attachment on the floor
            $RT::Logger->info( "$self: Dropped an attachment of size "
                               . length($Body));
            $RT::Logger->info( "It started: " . substr( $Body, 0, 60 ) );
            $Filename .= ".txt" if $Filename;
            return ("none", "Large attachment dropped", "text/plain", $Filename );
        }
    }

    # if we need to mimencode the attachment
    if ( $ContentEncoding eq 'base64' ) {
        # base64 encode the attachment
        $Body = MIME::Base64::encode_base64($Body);

    } elsif ($ContentEncoding eq 'quoted-printable') {
        $Body = MIME::QuotedPrint::encode($Body);
    }

    return ($ContentEncoding, $Body, $MIMEType, $Filename );
}

=head2 _DecodeLOB C<ContentType>, C<ContentEncoding>, C<Content>

Unpacks data stored in the database, which may be base64 or QP encoded
because of our need to store binary and badly encoded data in columns
marked as UTF-8.  Databases such as PostgreSQL and Oracle care that you
are feeding them invalid UTF-8 and will refuse the content.  This
function handles unpacking the encoded data.

It returns textual data as a UTF-8 string which has been processed by Encode's
PERLQQ filter which will replace the invalid bytes with \x{HH} so you can see
the invalid byte but won't run into problems treating the data as UTF-8 later.

This is similar to how we filter all data coming in via the web UI in
RT::Interface::Web::DecodeARGS. This filter should only end up being
applied to old data from less UTF-8-safe versions of RT.

If the passed C<ContentType> includes a character set, that will be used
to decode textual data; the default character set is UTF-8.  This is
necessary because while we attempt to store textual data as UTF-8, the
definition of "textual" has migrated over time, and thus we may now need
to attempt to decode data that was previously not trancoded on insertion.

Important Note - This function expects an octet string and returns a
character string for non-binary data.

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

# A helper table for links mapping to make it easier
# to build and parse links between tickets

use vars '%LINKDIRMAP';

%LINKDIRMAP = (
    MemberOf => { Base => 'MemberOf',
                  Target => 'HasMember', },
    RefersTo => { Base => 'RefersTo',
                Target => 'ReferredToBy', },
    DependsOn => { Base => 'DependsOn',
                   Target => 'DependedOnBy', },
    MergedInto => { Base => 'MergedInto',
                   Target => 'MergedInto', },

);

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
            eval {
                my $object = $attribute . "Obj";
                my $name = $self->$object->Name;
                next if $name eq $value || $name eq ($value || 0);
            };

            my $current = $self->$attribute();
            # RT::Queue->Lifecycle returns a Lifecycle object instead of name
            $current = eval { $current->Name } if ref $current;
            next if $truncated_value eq $current;
            next if ( $truncated_value || 0 ) eq $current;
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
        $deps->Limit( FIELD => 'Type', 
              OPERATOR => '=',
              VALUE => $args{Type}); 
    }
    else {
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

    my @live_statuses = RT::Queue->ActiveStatusArray();
    foreach my $status (@live_statuses) {
        $deps->LimitStatus(VALUE => $status);
    }
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

Returns C<link id>, C<message> and C<exist> flag.


=cut

sub _AddLink {
    my $self = shift;
    my %args = ( Target => '',
                 Base   => '',
                 Type   => '',
                 Silent => undef,
                 @_ );


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

    # Check if the link already exists - we don't want duplicates
    use RT::Link;
    my $old_link = RT::Link->new( $self->CurrentUser );
    $old_link->LoadByParams( Base   => $args{'Base'},
                             Type   => $args{'Type'},
                             Target => $args{'Target'} );
    if ( $old_link->Id ) {
        $RT::Logger->debug("$self Somebody tried to duplicate a link");
        return ( $old_link->id, $self->loc("Link already exists"), 1 );
    }

    # }}}


    # Storing the link in the DB.
    my $link = RT::Link->new( $self->CurrentUser );
    my ($linkid, $linkmsg) = $link->Create( Target => $args{Target},
                                  Base   => $args{Base},
                                  Type   => $args{Type} );

    unless ($linkid) {
        $RT::Logger->error("Link could not be created: ".$linkmsg);
        return ( 0, $self->loc("Link could not be created") );
    }

    my $basetext = $self->FormatLink(Object => $link->BaseObj,
				     FallBack => $args{Base});
    my $targettext = $self->FormatLink(Object => $link->TargetObj,
				       FallBack => $args{Target});
    my $typetext = $self->FormatType(Type => $args{Type});
    my $TransString =
      "$basetext $typetext $targettext.";
    return ( $linkid, $TransString ) ;
}



=head2 _DeleteLink

Delete a link. takes a paramhash of Base, Target and Type.
Either Base or Target must be null. The null value will 
be replaced with this ticket's id

=cut 

sub _DeleteLink {
    my $self = shift;
    my %args = (
        Base   => undef,
        Target => undef,
        Type   => undef,
        @_
    );

    #we want one of base and target. we don't care which
    #but we only want _one_

    my $direction;
    my $remote_link;

    if ( $args{'Base'} and $args{'Target'} ) {
        $RT::Logger->debug("$self ->_DeleteLink. got both Base and Target");
        return ( 0, $self->loc("Can't specify both base and target") );
    }
    elsif ( $args{'Base'} ) {
        $args{'Target'} = $self->URI();
	$remote_link = $args{'Base'};
    	$direction = 'Target';
    }
    elsif ( $args{'Target'} ) {
        $args{'Base'} = $self->URI();
	$remote_link = $args{'Target'};
        $direction='Base';
    }
    else {
        $RT::Logger->error("Base or Target must be specified");
        return ( 0, $self->loc('Either base or target must be specified') );
    }

    my $link = RT::Link->new( $self->CurrentUser );
    $RT::Logger->debug( "Trying to load link: " . $args{'Base'} . " " . $args{'Type'} . " " . $args{'Target'} );


    $link->LoadByParams( Base=> $args{'Base'}, Type=> $args{'Type'}, Target=>  $args{'Target'} );
    #it's a real link. 

    if ( $link->id ) {
        my $basetext = $self->FormatLink(Object => $link->BaseObj,
                                     FallBack => $args{Base});
        my $targettext = $self->FormatLink(Object => $link->TargetObj,
                                       FallBack => $args{Target});
        my $typetext = $self->FormatType(Type => $args{Type});
        my $linkid = $link->id;
        $link->Delete();
        my $TransString = "$basetext no longer $typetext $targettext.";
        return ( 1, $TransString);
    }

    #if it's not a link we can find
    else {
        $RT::Logger->debug("Couldn't find that link");
        return ( 0, $self->loc("Link not found") );
    }
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
        CommitScrips => 1,
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
        CommitScrips => $args{'CommitScrips'},
        SquelchMailTo => $args{'SquelchMailTo'},
    );

    # Rationalize the object since we may have done things to it during the caching.
    $self->Load($self->Id);

    $RT::Logger->warning($msg) unless $transaction;

    $self->_SetLastUpdated;

    if ( defined $args{'TimeTaken'} and $self->can('_UpdateTimeTaken')) {
        $self->_UpdateTimeTaken( $args{'TimeTaken'} );
    }
    if ( RT->Config->Get('UseTransactionBatch') and $transaction ) {
	    push @{$self->{_TransactionBatch}}, $trans if $args{'CommitScrips'};
    }

    RT->DatabaseHandle->Commit unless $in_txn;

    return ( $transaction, $msg, $trans );
}



=head2 Transactions

  Returns an RT::Transactions object of all transactions on this record object

=cut

sub Transactions {
    my $self = shift;

    use RT::Transactions;
    my $transactions = RT::Transactions->new( $self->CurrentUser );

    #If the user has no rights, return an empty object
    $transactions->Limit(
        FIELD => 'ObjectId',
        VALUE => $self->id,
    );
    $transactions->Limit(
        FIELD => 'ObjectType',
        VALUE => ref($self),
    );

    return ($transactions);
}

#

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
        @_
    );

    my $cf = $self->LoadCustomFieldByIdentifier($args{'Field'});
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
        );

        unless ( $new_value_id ) {
            return ( 0, $self->loc( "Could not add new custom field value: [_1]", $value_msg ) );
        }

        my $new_value = RT::ObjectCustomFieldValue->new( $self->CurrentUser );
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
        if ( !$cf->Repeated ) {
            my $values = $cf->ValuesForObject($self);
            if ( my $entry = $values->HasEntry($args{'Value'}, $args{'LargeContent'}) ) {
                return $entry->id;
            }
        }

        my ($new_value_id, $msg) = $cf->AddValueForObject(
            Object       => $self,
            Content      => $args{'Value'},
            LargeContent => $args{'LargeContent'},
            ContentType  => $args{'ContentType'},
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

sub BasicColumns { }

sub WikiBase {
    return RT->Config->Get('WebPath'). "/index.html?q=";
}

RT::Base->_ImportOverlays();

1;
