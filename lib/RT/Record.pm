# BEGIN BPS TAGGED BLOCK {{{
# 
# COPYRIGHT:
#  
# This software is Copyright (c) 1996-2007 Best Practical Solutions, LLC 
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
# http://www.gnu.org/copyleft/gpl.html.
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


=begin testing

ok (require RT::Record);

=end testing

=head1 METHODS

=cut

package RT::Record;

use strict;
use warnings;

our @ISA;
use base qw(RT::Base);

use RT::Date;
use RT::User;
use RT::Attributes;
use DBIx::SearchBuilder::Record::Cachable;
use Encode qw();

our $_TABLE_ATTR = { };


if ( $RT::DontCacheSearchBuilderRecords ) {
    push (@ISA, 'DBIx::SearchBuilder::Record');
} else {
    push (@ISA, 'DBIx::SearchBuilder::Record::Cachable');

}

# {{{ sub _Init 

sub _Init {
    my $self = shift;
    $self->_BuildTableAttributes unless ($_TABLE_ATTR->{ref($self)});
    $self->CurrentUser(@_);
}

# }}}

# {{{ _PrimaryKeys

=head2 _PrimaryKeys

The primary keys for RT classes is 'id'

=cut

sub _PrimaryKeys {
    my $self = shift;
    return ( ['id'] );
}

# }}}

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

=begin testing

my $ticket = RT::Ticket->new($RT::SystemUser);
my $group = RT::Group->new($RT::SystemUser);
is($ticket->ObjectTypeStr, 'Ticket', "Ticket returns correct typestring");
is($group->ObjectTypeStr, 'Group', "Group returns correct typestring");

=end testing

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
    return $self->Attributes->DeleteEntry( Name => $name );
}

=head2 FirstAttribute NAME

Returns the first attribute with the matching name for this object (as an
L<RT::Attribute> object), or C<undef> if no such attributes exist.

Note that if there is more than one attribute with the matching name on the
object, the choice of which one to return is basically arbitrary.  This may be
made well-defined in the future.

=cut

sub FirstAttribute {
    my $self = shift;
    my $name = shift;
    return ($self->Attributes->Named( $name ))[0];
}


# {{{ sub _Handle 
sub _Handle {
    my $self = shift;
    return ($RT::Handle);
}

# }}}

# {{{ sub Create 

=head2  Create PARAMHASH

Takes a PARAMHASH of Column -> Value pairs.
If any Column has a Validate$PARAMNAME subroutine defined and the 
value provided doesn't pass validation, this routine returns
an error.

If this object's table has any of the following atetributes defined as
'Auto', this routine will automatically fill in their values.

=cut

sub Create {
    my $self    = shift;
    my %attribs = (@_);
    foreach my $key ( keys %attribs ) {
        my $method = "Validate$key";
        unless ( $self->$method( $attribs{$key} ) ) {
            if (wantarray) {
                return ( 0, $self->loc('Invalid value for [_1]', $key) );
            }
            else {
                return (0);
            }
        }
    }
    my $now = RT::Date->new( $self->CurrentUser );
    $now->Set( Format => 'unix', Value => time );
    $attribs{'Created'} = $now->ISO() if ( $self->_Accessible( 'Created', 'auto' ) && !$attribs{'Created'});

    if ($self->_Accessible( 'Creator', 'auto' ) && !$attribs{'Creator'}) {
         $attribs{'Creator'} = $self->CurrentUser->id || '0'; 
    }
    $attribs{'LastUpdated'} = $now->ISO()
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
        exit(0);
       warn "It's here!";
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

# }}}

# {{{ sub LoadByCols

=head2 LoadByCols

Override DBIx::SearchBuilder::LoadByCols to do case-insensitive loads if the 
DB is case sensitive

=cut

sub LoadByCols {
    my $self = shift;
    my %hash = (@_);

    # We don't want to hang onto this
    delete $self->{'attributes'};

    # If this database is case sensitive we need to uncase objects for
    # explicit loading
    if ( $self->_Handle->CaseSensitive ) {
        my %newhash;
        foreach my $key ( keys %hash ) {

            # If we've been passed an empty value, we can't do the lookup. 
            # We don't need to explicitly downcase integers or an id.
            if ( $key =~ '^id$'
                || !defined( $hash{$key} )
                || $hash{$key} =~ /^\d+$/
                 )
            {
                $newhash{$key} = $hash{$key};
            }
            else {
                my ($op, $val, $func);
                ($key, $op, $val, $func) = $self->_Handle->_MakeClauseCaseInsensitive($key, '=', $hash{$key});
                $newhash{$key}->{operator} = $op;
                $newhash{$key}->{value} = $val;
                $newhash{$key}->{function} = $func;
            }
        }

        # We've clobbered everything we care about. bash the old hash
        # and replace it with the new hash
        %hash = %newhash;
    }
    $self->SUPER::LoadByCols(%hash);
}

# }}}

# {{{ Datehandling

# There is room for optimizations in most of those subs:

# {{{ LastUpdatedObj

sub LastUpdatedObj {
    my $self = shift;
    my $obj  = new RT::Date( $self->CurrentUser );

    $obj->Set( Format => 'sql', Value => $self->LastUpdated );
    return $obj;
}

# }}}

# {{{ CreatedObj

sub CreatedObj {
    my $self = shift;
    my $obj  = new RT::Date( $self->CurrentUser );

    $obj->Set( Format => 'sql', Value => $self->Created );

    return $obj;
}

# }}}

# {{{ AgeAsString
#
# TODO: This should be deprecated
#
sub AgeAsString {
    my $self = shift;
    return ( $self->CreatedObj->AgeAsString() );
}

# }}}

# {{{ LastUpdatedAsString

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

# }}}

# {{{ CreatedAsString
#
# TODO This should be deprecated 
#
sub CreatedAsString {
    my $self = shift;
    return ( $self->CreatedObj->AsString() );
}

# }}}

# {{{ LongSinceUpdateAsString
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

# }}}

# }}} Datehandling

# {{{ sub _Set 
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
        $msg =
          $self->loc(
            "[_1] changed from [_2] to [_3]",
            $args{'Field'},
            ( $old_val ? "'$old_val'" : $self->loc("(no value)") ),
            '"' . $self->__Value( $args{'Field'}) . '"' 
          );
      } else {

          $msg = $self->CurrentUser->loc_fuzzy($msg);
    }
    return wantarray ? ($status, $msg) : $ret;     

}

# }}}

# {{{ sub _SetLastUpdated

=head2 _SetLastUpdated

This routine updates the LastUpdated and LastUpdatedBy columns of the row in question
It takes no options. Arguably, this is a bug

=cut

sub _SetLastUpdated {
    my $self = shift;
    use RT::Date;
    my $now = new RT::Date( $self->CurrentUser );
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

# }}}

# {{{ sub CreatorObj 

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

# }}}

# {{{ sub LastUpdatedByObj

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

# }}}

# {{{ sub URI 

=head2 URI

Returns this record's URI

=cut

sub URI {
    my $self = shift;
    my $uri = RT::URI::fsck_com_rt->new($self->CurrentUser);
    return($uri->URIForObject($self));
}

# }}}

=head2 ValidateName NAME

Validate the name of the record we're creating. Mostly, just make sure it's not a numeric ID, which is invalid for Name

=cut

sub ValidateName {
    my $self = shift;
    my $value = shift;
    if ($value && $value=~ /^\d+$/) {
        return(0);
    } else  {
         return (1);
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
    my %args = ( decode_utf8 => 1,
                 @_ );

    unless (defined $field && $field) {
        $RT::Logger->error("$self __Value called with undef field");
    }
    my $value = $self->SUPER::__Value($field);

    return('') if ( !defined($value) || $value eq '');

    if( $args{'decode_utf8'} ) {
    	# XXX: is_utf8 check should be here unless Encode bug would be fixed
        # see http://rt.cpan.org/NoAuth/Bug.html?id=14559 
        return Encode::decode_utf8($value) unless Encode::is_utf8($value);
    } else {
        # check is_utf8 here just to be shure
        return Encode::encode_utf8($value) if Encode::is_utf8($value);
    }
    return $value;
}

# Set up defaults for DBIx::SearchBuilder::Record::Cachable

sub _CacheConfig {
  {
     'cache_p'        => 1,
     'cache_for_sec'  => 30,
  }
}



sub _BuildTableAttributes {
    my $self = shift;

    my $attributes;
    if ( UNIVERSAL::can( $self, '_CoreAccessible' ) ) {
       $attributes = $self->_CoreAccessible();
    } elsif ( UNIVERSAL::can( $self, '_ClassAccessible' ) ) {
       $attributes = $self->_ClassAccessible();

    }

    foreach my $column (%$attributes) {
        foreach my $attr ( %{ $attributes->{$column} } ) {
            $_TABLE_ATTR->{ref($self)}->{$column}->{$attr} = $attributes->{$column}->{$attr};
        }
    }
    if ( UNIVERSAL::can( $self, '_OverlayAccessible' ) ) {
        $attributes = $self->_OverlayAccessible();

        foreach my $column (%$attributes) {
            foreach my $attr ( %{ $attributes->{$column} } ) {
                $_TABLE_ATTR->{ref($self)}->{$column}->{$attr} = $attributes->{$column}->{$attr};
            }
        }
    }
    if ( UNIVERSAL::can( $self, '_VendorAccessible' ) ) {
        $attributes = $self->_VendorAccessible();

        foreach my $column (%$attributes) {
            foreach my $attr ( %{ $attributes->{$column} } ) {
                $_TABLE_ATTR->{ref($self)}->{$column}->{$attr} = $attributes->{$column}->{$attr};
            }
        }
    }
    if ( UNIVERSAL::can( $self, '_LocalAccessible' ) ) {
        $attributes = $self->_LocalAccessible();

        foreach my $column (%$attributes) {
            foreach my $attr ( %{ $attributes->{$column} } ) {
                $_TABLE_ATTR->{ref($self)}->{$column}->{$attr} = $attributes->{$column}->{$attr};
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
    return $_TABLE_ATTR->{ref($self)};
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

=head2 _EncodeLOB BODY MIME_TYPE

Takes a potentially large attachment. Returns (ContentEncoding, EncodedBody) based on system configuration and selected database

=cut

sub _EncodeLOB {
        my $self = shift;
        my $Body = shift;
        my $MIMEType = shift;

        my $ContentEncoding = 'none';

        #get the max attachment length from RT
        my $MaxSize = $RT::MaxAttachmentSize;

        #if the current attachment contains nulls and the
        #database doesn't support embedded nulls

        if ( $RT::AlwaysUseBase64 or
             ( !$RT::Handle->BinarySafeBLOBs ) && ( $Body =~ /\x00/ ) ) {

            # set a flag telling us to mimencode the attachment
            $ContentEncoding = 'base64';

            #cut the max attchment size by 25% (for mime-encoding overhead.
            $RT::Logger->debug("Max size is $MaxSize\n");
            $MaxSize = $MaxSize * 3 / 4;
        # Some databases (postgres) can't handle non-utf8 data
        } elsif (    !$RT::Handle->BinarySafeBLOBs
                  && $MIMEType !~ /text\/plain/gi
                  && !Encode::is_utf8( $Body, 1 ) ) {
              $ContentEncoding = 'quoted-printable';
        }

        #if the attachment is larger than the maximum size
        if ( ($MaxSize) and ( $MaxSize < length($Body) ) ) {

            # if we're supposed to truncate large attachments
            if ($RT::TruncateLongAttachments) {

                # truncate the attachment to that length.
                $Body = substr( $Body, 0, $MaxSize );

            }

            # elsif we're supposed to drop large attachments on the floor,
            elsif ($RT::DropLongAttachments) {

                # drop the attachment on the floor
                $RT::Logger->info( "$self: Dropped an attachment of size "
                                   . length($Body) . "\n"
                                   . "It started: " . substr( $Body, 0, 60 ) . "\n"
                                 );
                return ("none", "Large attachment dropped" );
            }
        }

        # if we need to mimencode the attachment
        if ( $ContentEncoding eq 'base64' ) {

            # base64 encode the attachment
            Encode::_utf8_off($Body);
            $Body = MIME::Base64::encode_base64($Body);

        } elsif ($ContentEncoding eq 'quoted-printable') {
            Encode::_utf8_off($Body);
            $Body = MIME::QuotedPrint::encode($Body);
        }


        return ($ContentEncoding, $Body);

}

sub _DecodeLOB {
    my $self            = shift;
    my $ContentType     = shift;
    my $ContentEncoding = shift;
    my $Content         = shift;

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
       $Content = Encode::decode_utf8($Content) unless Encode::is_utf8($Content);
    }
        return ($Content);
}

# {{{ LINKDIRMAP
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
    my @results;

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


        # If Queue is 'General', we want to resolve the queue name for
        # the object.

        # This is in an eval block because $object might not exist.
        # and might not have a Name method. But "can" won't find autoloaded
        # items. If it fails, we don't care
        eval {
            my $object = $attribute . "Obj";
            next if ($self->$object->Name eq $value);
        };
        next if ( $value eq $self->$attribute() );
        my $method = "Set$attribute";
        my ( $code, $msg ) = $self->$method($value);
        my ($prefix) = ref($self) =~ /RT(?:.*)::(\w+)/;

        # Default to $id, but use name if we can get it.
        my $label = $self->id;
        $label = $self->Name if (UNIVERSAL::can($self,'Name'));
        push @results, $self->loc( "$prefix [_1]", $label ) . ': '. $msg;

=for loc

                                   "[_1] could not be set to [_2].",       # loc
                                   "That is already the current value",    # loc
                                   "No value sent to _Set!\n",             # loc
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

# {{{ Routines dealing with Links

# {{{ Link Collections

# {{{ sub Members

=head2 Members

  This returns an RT::Links object which references all the tickets 
which are 'MembersOf' this ticket

=cut

sub Members {
    my $self = shift;
    return ( $self->_Links( 'Target', 'MemberOf' ) );
}

# }}}

# {{{ sub MemberOf

=head2 MemberOf

  This returns an RT::Links object which references all the tickets that this
ticket is a 'MemberOf'

=cut

sub MemberOf {
    my $self = shift;
    return ( $self->_Links( 'Base', 'MemberOf' ) );
}

# }}}

# {{{ RefersTo

=head2 RefersTo

  This returns an RT::Links object which shows all references for which this ticket is a base

=cut

sub RefersTo {
    my $self = shift;
    return ( $self->_Links( 'Base', 'RefersTo' ) );
}

# }}}

# {{{ ReferredToBy

=head2 ReferredToBy

This returns an L<RT::Links> object which shows all references for which this ticket is a target

=cut

sub ReferredToBy {
    my $self = shift;
    return ( $self->_Links( 'Target', 'RefersTo' ) );
}

# }}}

# {{{ DependedOnBy

=head2 DependedOnBy

  This returns an RT::Links object which references all the tickets that depend on this one

=cut

sub DependedOnBy {
    my $self = shift;
    return ( $self->_Links( 'Target', 'DependsOn' ) );
}

# }}}



=head2 HasUnresolvedDependencies

  Takes a paramhash of Type (default to '__any').  Returns true if
$self->UnresolvedDependencies returns an object with one or more members
of that type.  Returns false otherwise


=begin testing

my $t1 = RT::Ticket->new($RT::SystemUser);
my ($id, $trans, $msg) = $t1->Create(Subject => 'DepTest1', Queue => 'general');
ok($id, "Created dep test 1 - $msg");

my $t2 = RT::Ticket->new($RT::SystemUser);
my ($id2, $trans, $msg2) = $t2->Create(Subject => 'DepTest2', Queue => 'general');
ok($id2, "Created dep test 2 - $msg2");
my $t3 = RT::Ticket->new($RT::SystemUser);
my ($id3, $trans, $msg3) = $t3->Create(Subject => 'DepTest3', Queue => 'general', Type => 'approval');
ok($id3, "Created dep test 3 - $msg3");
my ($addid, $addmsg);
ok (($addid, $addmsg) =$t1->AddLink( Type => 'DependsOn', Target => $t2->id));
ok ($addid, $addmsg);
ok (($addid, $addmsg) =$t1->AddLink( Type => 'DependsOn', Target => $t3->id));

ok ($addid, $addmsg);
my $link = RT::Link->new($RT::SystemUser);
my ($rv, $msg) = $link->Load($addid);
ok ($rv, $msg);
ok ($link->LocalTarget == $t3->id, "Link LocalTarget is correct");
ok ($link->LocalBase   == $t1->id, "Link LocalBase   is correct");

ok ($t1->HasUnresolvedDependencies, "Ticket ".$t1->Id." has unresolved deps");
ok (!$t1->HasUnresolvedDependencies( Type => 'blah' ), "Ticket ".$t1->Id." has no unresolved blahs");
ok ($t1->HasUnresolvedDependencies( Type => 'approval' ), "Ticket ".$t1->Id." has unresolved approvals");
ok (!$t2->HasUnresolvedDependencies, "Ticket ".$t2->Id." has no unresolved deps");
;

my ($rid, $rmsg)= $t1->Resolve();
ok(!$rid, $rmsg);
my ($rid2, $rmsg2) = $t2->Resolve();
ok ($rid2, $rmsg2);
($rid, $rmsg)= $t1->Resolve();
ok(!$rid, $rmsg);
my ($rid3,$rmsg3) = $t3->Resolve;
ok ($rid3,$rmsg3);
($rid, $rmsg)= $t1->Resolve();
ok($rid, $rmsg);


=end testing

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
        return 1;
    }
    else {
        return (undef);
    }
}


# {{{ UnresolvedDependencies 

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

# }}}

# {{{ AllDependedOnBy

=head2 AllDependedOnBy

Returns an array of RT::Ticket objects which (directly or indirectly)
depends on this ticket; takes an optional 'Type' argument in the param
hash, which will limit returned tickets to that type, as well as cause
tickets with that type to serve as 'leaf' nodes that stops the recursive
dependency search.

=cut

sub AllDependedOnBy {
    my $self = shift;
    my $dep = $self->DependedOnBy;
    my %args = (
        Type   => undef,
	_found => {},
	_top   => 1,
        @_
    );

    while (my $link = $dep->Next()) {
	next unless ($link->BaseURI->IsLocal());
	next if $args{_found}{$link->BaseObj->Id};

	if (!$args{Type}) {
	    $args{_found}{$link->BaseObj->Id} = $link->BaseObj;
	    $link->BaseObj->AllDependedOnBy( %args, _top => 0 );
	}
	elsif ($link->BaseObj->Type eq $args{Type}) {
	    $args{_found}{$link->BaseObj->Id} = $link->BaseObj;
	}
	else {
	    $link->BaseObj->AllDependedOnBy( %args, _top => 0 );
	}
    }

    if ($args{_top}) {
	return map { $args{_found}{$_} } sort keys %{$args{_found}};
    }
    else {
	return 1;
    }
}

# }}}

# {{{ DependsOn

=head2 DependsOn

  This returns an RT::Links object which references all the tickets that this ticket depends on

=cut

sub DependsOn {
    my $self = shift;
    return ( $self->_Links( 'Base', 'DependsOn' ) );
}

# }}}




# {{{ sub _Links 

=head2 Links DIRECTION [TYPE]

Return links (L<RT::Links>) to/from this object.

DIRECTION is either 'Base' or 'Target'.

TYPE is a type of links to return, it can be omitted to get
links of any type.

=cut

*Links = \&_Links;

sub _Links {
    my $self = shift;

    #TODO: Field isn't the right thing here. but I ahave no idea what mnemonic ---
    #tobias meant by $f
    my $field = shift;
    my $type  = shift || "";

    unless ( $self->{"$field$type"} ) {
        $self->{"$field$type"} = new RT::Links( $self->CurrentUser );
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

# }}}

# }}}

# {{{ sub _AddLink

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
        $RT::Logger->debug( "$self tried to create a link. both base and target were specified\n" );
        return ( 0, $self->loc("Can't specifiy both base and target") );
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

    # {{{ Check if the link already exists - we don't want duplicates
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

    my $TransString =
      "Record $args{'Base'} $args{Type} record $args{'Target'}.";

    return ( $linkid, $self->loc( "Link created ([_1])", $TransString ) );
}

# }}}

# {{{ sub _DeleteLink 

=head2 _DeleteLink

Delete a link. takes a paramhash of Base, Target and Type.
Either Base or Target must be null. The null value will 
be replaced with this ticket\'s id

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
        $RT::Logger->debug("$self ->_DeleteLink. got both Base and Target\n");
        return ( 0, $self->loc("Can't specifiy both base and target") );
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
        $RT::Logger->error("Base or Target must be specified\n");
        return ( 0, $self->loc('Either base or target must be specified') );
    }

    my $link = new RT::Link( $self->CurrentUser );
    $RT::Logger->debug( "Trying to load link: " . $args{'Base'} . " " . $args{'Type'} . " " . $args{'Target'} . "\n" );


    $link->LoadByParams( Base=> $args{'Base'}, Type=> $args{'Type'}, Target=>  $args{'Target'} );
    #it's a real link. 
    if ( $link->id ) {

        my $linkid = $link->id;
        $link->Delete();

        my $TransString = "Record $args{'Base'} no longer $args{Type} record $args{'Target'}.";
        return ( 1, $self->loc("Link deleted ([_1])", $TransString));
    }

    #if it's not a link we can find
    else {
        $RT::Logger->debug("Couldn't find that link\n");
        return ( 0, $self->loc("Link not found") );
    }
}

# }}}

# }}}

# {{{ Routines dealing with transactions

# {{{ sub _NewTransaction

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
        @_
    );

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
    my $trans = new RT::Transaction( $self->CurrentUser );
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
    );

    # Rationalize the object since we may have done things to it during the caching.
    $self->Load($self->Id);

    $RT::Logger->warning($msg) unless $transaction;

    $self->_SetLastUpdated;

    if ( defined $args{'TimeTaken'} and $self->can('_UpdateTimeTaken')) {
        $self->_UpdateTimeTaken( $args{'TimeTaken'} );
    }
    if ( $RT::UseTransactionBatch and $transaction ) {
	    push @{$self->{_TransactionBatch}}, $trans if $args{'CommitScrips'};
    }
    return ( $transaction, $msg, $trans );
}

# }}}

# {{{ sub Transactions 

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

# }}}
# }}}
#
# {{{ Routines dealing with custom fields

sub CustomFields {
    my $self = shift;
    my $cfs  = RT::CustomFields->new( $self->CurrentUser );

    # XXX handle multiple types properly
    $cfs->LimitToLookupType( $self->CustomFieldLookupType );
    $cfs->LimitToGlobalOrObjectId(
        $self->_LookupId( $self->CustomFieldLookupType ) );

    return $cfs;
}

# TODO: This _only_ works for RT::Class classes. it doesn't work, for example, for RT::FM classes.

sub _LookupId {
    my $self = shift;
    my $lookup = shift;
    my @classes = ($lookup =~ /RT::(\w+)-/g);

    my $object = $self;
    foreach my $class (reverse @classes) {
	my $method = "${class}Obj";
	$object = $object->$method;
    }

    return $object->Id;
}


=head2 CustomFieldLookupType 

Returns the path RT uses to figure out which custom fields apply to this object.

=cut

sub CustomFieldLookupType {
    my $self = shift;
    return ref($self);
}

#TODO Deprecated API. Destroy in 3.6
sub _LookupTypes { 
    my  $self = shift;
    $RT::Logger->warning("_LookupTypes call is deprecated at (". join(":",caller)."). Replace with CustomFieldLookupType");

    return($self->CustomFieldLookupType);

}

# {{{ AddCustomFieldValue

=head2 AddCustomFieldValue { Field => FIELD, Value => VALUE }

VALUE should be a string.
FIELD can be a CustomField object OR a CustomField ID.


Adds VALUE as a value of CustomField FIELD.  If this is a single-value custom field,
deletes the old value. 
If VALUE is not a valid value for the custom field, returns 
(0, 'Error message' ) otherwise, returns (1, 'Success Message')

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
                $args{'Field'}
            )
        );
    }
    # Load up a ObjectCustomFieldValues object for this custom field and this ticket
    my $values = $cf->ValuesForObject($self);

    unless ( $cf->ValidateValue( $args{'Value'} ) ) {
        return ( 0, $self->loc("Invalid value for custom field") );
    }

    # If the custom field only accepts a certain # of values, delete the existing
    # value and record a "changed from foo to bar" transaction
    unless ( $cf->UnlimitedValues) {

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
                        Object  => $self,
                        Content => $value->Content
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

        my ( $old_value, $old_content );
        if ( $old_value = $values->First ) {
            $old_content = $old_value->Content();
            return (1) if( $old_content eq $args{'Value'} && $old_value->LargeContent eq $args{'LargeContent'});;
        }

        my ( $new_value_id, $value_msg ) = $cf->AddValueForObject(
            Object       => $self,
            Content      => $args{'Value'},
            LargeContent => $args{'LargeContent'},
            ContentType  => $args{'ContentType'},
        );

        unless ($new_value_id) {
            return ( 0, $self->loc( "Could not add new custom field value: [_1]", $value_msg) );
        }

        my $new_value = RT::ObjectCustomFieldValue->new( $self->CurrentUser );
        $new_value->Load($new_value_id);

        # now that adding the new value was successful, delete the old one
        if ($old_value) {
            my ( $val, $msg ) = $old_value->Delete();
            unless ($val) {
                return ( 0, $msg );
            }
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

        if ( $old_value eq '' ) {
            return ( 1, $self->loc( "[_1] [_2] added", $cf->Name, $new_value->Content ));
        }
        elsif ( $new_value->Content eq '' ) {
            return ( 1,
                $self->loc( "[_1] [_2] deleted", $cf->Name, $old_value->Content ) );
        }
        else {
            return ( 1, $self->loc( "[_1] [_2] changed to [_3]", $cf->Name, $old_content,                $new_value->Content));
        }

    }

    # otherwise, just add a new value and record "new value added"
    else {
        my ($new_value_id, $value_msg) = $cf->AddValueForObject(
            Object       => $self,
            Content      => $args{'Value'},
            LargeContent => $args{'LargeContent'},
            ContentType  => $args{'ContentType'},
        );

        unless ($new_value_id) {
            return ( 0, $self->loc( "Could not add new custom field value: [_1]", $value_msg) );
        }
        if ( $args{'RecordTransaction'} ) {
            my ( $TransactionId, $Msg, $TransactionObj ) =
              $self->_NewTransaction(
                Type          => 'CustomField',
                Field         => $cf->Id,
                NewReference  => $new_value_id,
                ReferenceType => 'RT::ObjectCustomFieldValue',
              );
            unless ($TransactionId) {
                return ( 0,
                    $self->loc( "Couldn't create a transaction: [_1]", $Msg ) );
            }
        }
        return ( 1, $self->loc( "[_1] added as a value for [_2]", $args{'Value'}, $cf->Name));
    }

}

# }}}

# {{{ DeleteCustomFieldValue

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

    return (
        $TransactionId,
        $self->loc(
            "[_1] is no longer a value for custom field [_2]",
            $TransactionObj->OldValue, $cf->Name
        )
    );
}

# }}}

# {{{ FirstCustomFieldValue

=head2 FirstCustomFieldValue FIELD

Return the content of the first value of CustomField FIELD for this ticket
Takes a field id or name

=cut

sub FirstCustomFieldValue {
    my $self = shift;
    my $field = shift;
    my $values = $self->CustomFieldValues($field);
    if ($values->First) {
        return $values->First->Content;
    } else {
        return undef;
    }

}



# {{{ CustomFieldValues

=head2 CustomFieldValues FIELD

Return a ObjectCustomFieldValues object of all values of the CustomField whose 
id or Name is FIELD for this record.

Returns an RT::ObjectCustomFieldValues object

=cut

sub CustomFieldValues {
    my $self  = shift;
    my $field = shift;

    if ($field) {
        my $cf = $self->LoadCustomFieldByIdentifier($field);

        # we were asked to search on a custom field we couldn't fine
        unless ( $cf->id ) {
            return RT::ObjectCustomFieldValues->new( $self->CurrentUser );
        }
        return ( $cf->ValuesForObject($self) );
    }

    # we're not limiting to a specific custom field;
    my $ocfs = RT::ObjectCustomFieldValues->new( $self->CurrentUser );
    $ocfs->LimitToObject($self);
    return $ocfs;

}

=head2 CustomField IDENTIFER

Find the custom field has id or name IDENTIFIER for this object.

If no valid field is found, returns an empty RT::CustomField object.

=cut

sub LoadCustomFieldByIdentifier {
    my $self = shift;
    my $field = shift;
    
    my $cf = RT::CustomField->new($self->CurrentUser);

    if ( UNIVERSAL::isa( $field, "RT::CustomField" ) ) {
        $cf->LoadById( $field->id );
    }
    elsif ($field =~ /^\d+$/) {
        $cf = RT::CustomField->new($self->CurrentUser);
        $cf->Load($field); 
    } else {

        my $cfs = $self->CustomFields($self->CurrentUser);
        $cfs->Limit(FIELD => 'Name', VALUE => $field, CASESENSITIVE => 0);
        $cf = $cfs->First || RT::CustomField->new($self->CurrentUser);
    }
    return $cf;
}


# }}}

# }}}

# }}}

sub BasicColumns {
}

sub WikiBase {
  return $RT::WebPath. "/index.html?q=";
}

eval "require RT::Record_Vendor";
die $@ if ($@ && $@ !~ qr{^Can't locate RT/Record_Vendor.pm});
eval "require RT::Record_Local";
die $@ if ($@ && $@ !~ qr{^Can't locate RT/Record_Local.pm});

1;
