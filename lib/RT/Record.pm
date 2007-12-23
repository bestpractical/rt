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
=head1 name

  RT::Record - Base class for RT record objects

=head1 SYNOPSIS


=head1 DESCRIPTION



=head1 METHODS

=cut

package RT::Record;

use strict;
use warnings;

use RT::Date;
use RT::Model::User;
use RT::Model::AttributeCollection;
use RT::Model::Attribute;
use Encode qw();

our $_TABLE_ATTR = { };
use base qw(Jifty::Record);
use base qw(RT::Base);

# {{{ sub _init 

sub table { my $class = shift; 

$class = ref($class) || $class;
$class =~ s/^(.*):://g;
return $class;
}


sub current_user_can { 1} # For now, we're using RT's auth, not jifty's

sub __set {
    my $self = shift;
    my %args = (@_);

    unless (defined $args{'value'} ) {
        $args{'value'} ||= delete $args{'Value'};
    }

    unless (defined $args{'column'} ) {
    $args{'column'} ||= delete $args{'Field'};
    }
    $self->SUPER::__set( %args);

}


=head2 Delete

Delete this record object from the database.

=cut

sub delete {
    my $self = shift;
    my ($rv) = $self->SUPER::delete;
    if ($rv) {
        return ($rv, $self->loc("Object deleted"));
    } else {

        return(0, $self->loc("Object could not be deleted"))
    } 
}

=head2 object_typeStr

Returns a string which is this object's type.  The type is the class,
without the "RT::" prefix.


=cut

sub object_typeStr {
    my $self = shift;
    if (ref($self) =~ /^.*::(\w+)$/) {
	return $self->loc($1);
    } else {
	return $self->loc(ref($self));
    }
}

=head2 Attributes

Return this object's attributes as an RT::Model::AttributeCollection object

=cut

sub attributes {
    my $self = shift;
    
    unless ($self->{'attributes'}) {
        $self->{'attributes'} = RT::Model::AttributeCollection->new;     
       $self->{'attributes'}->LimitToObject($self); 
    }
    return ($self->{'attributes'}); 

}


=head2 add_attribute { name, Description, Content }

Adds a new attribute for this object.

=cut

sub add_attribute {
    my $self = shift;
    my %args = ( name        => undef,
                 Description => undef,
                 Content     => undef,
                 @_ );

    my $attr = RT::Model::Attribute->new;
    my ( $id, $msg ) = $attr->create( 
                                      Object    => $self,
                                      name        => $args{'name'},
                                      Description => $args{'Description'},
                                      Content     => $args{'Content'} );


    # XXX TODO: Why won't redo_search work here?                                     
    $self->attributes->_do_search;
    
    return ($id, $msg);
}


=head2 set_attribute { name, Description, Content }

Like add_attribute, but replaces all existing attributes with the same name.

=cut

sub set_attribute {
    my $self = shift;
    my %args = ( name        => undef,
                 Description => undef,
                 Content     => undef,
                 @_ );

    my @AttributeObjs = $self->attributes->named( $args{'name'} )
        or return $self->add_attribute( %args );

    my $AttributeObj = pop( @AttributeObjs );
    $_->delete foreach @AttributeObjs;

    $AttributeObj->set_Description( $args{'Description'} );
    $AttributeObj->set_Content( $args{'Content'} );

    $self->attributes->redo_search;
    return 1;
}

=head2 delete_attribute name

Deletes all attributes with the matching name for this object.

=cut

sub delete_attribute {
    my $self = shift;
    my $name = shift;
    return $self->attributes->delete_entry( name => $name );
}

=head2 first_attribute name

Returns the first attribute with the matching name for this object (as an
L<RT::Model::Attribute> object), or C<undef> if no such attributes exist.

Note that if there is more than one attribute with the matching name on the
object, the choice of which one to return is basically arbitrary.  This may be
made well-defined in the future.

=cut

sub first_attribute {
    my $self = shift;
    my $name = shift;
    return ($self->attributes->named( $name ))[0];
}


# {{{ sub create 

=head2  Create PARAMHASH

Takes a PARAMHASH of Column -> Value pairs.
If any Column has a Validate$PARAMname subroutine defined and the 
value provided doesn't pass validation, this routine returns
an error.

If this object's table has any of the following atetributes defined as
'Auto', this routine will automatically fill in their values.

=cut

sub create {
    my $self    = shift;
    my %attribs = (@_);
    foreach my $key ( keys %attribs ) {
        my $method = $self->can("validate_$key");
        if ($method) { 
        unless (  $method->($self, $attribs{$key} ) ) {
            if (wantarray) {
                return ( 0, $self->loc('Invalid value for %1', $key) );
            }
            else {
                return (0);
            }
        }
    }
    }


    $attribs{'Creator'} ||= $self->current_user->id if $self->can('Creator') && $self->current_user;

    my $now = RT::Date->new( current_user =>  $self->current_user );
    $now->set( Format => 'unix', value => time );

    my ($id) = $self->SUPER::create(%attribs);
    if ( UNIVERSAL::isa( $id, 'Class::ReturnValue' ) ) {
        if ( $id->errno ) {
            if (wantarray) {
                return ( 0,
                    $self->loc( "Internal Error: %1", $id->{error_message} ) );
            }
            else {
                return (0);
            }
        }
    }
    # If the object was Created in the database, 
    # load it up now, so we're sure we get what the database 
    # has.  Arguably, this should not be necessary, but there
    # isn't much we can do about it.

   unless ($id) { 
    if (wantarray) {
        return ( $id, $self->loc('Object could not be Created') );
    }
    else {
        return ($id);
    }

   }

    if  (UNIVERSAL::isa('errno',$id)) {
        die "it's an errno";
        return(undef);
    }

    $self->load($id) if ($id);



    if (wantarray) {
        return ( $id, $self->loc('Object Created') );
    }
    else {
        return ($id);
    }

}

# }}}

# {{{ sub load_by_cols

=head2 load_by_cols

Override Jifty::DBI::load_by_cols to do case-insensitive loads if the 
DB is case sensitive

=cut

sub load_by_id { shift->load_by_cols( id => shift) }

sub load_by_cols {
    my $self = shift;
    my %hash = (@_);

    # We don't want to hang onto this
    delete $self->{'attributes'};

    return $self->SUPER::load_by_cols( @_ );# unless $self->_Handle->case_sensitive;

    # If this database is case sensitive we need to uncase objects for
    # explicit loading
    foreach my $key ( keys %hash ) {
        # If we've been passed an empty value, we can't do the lookup.
        # We don't need to explicitly downcase integers or an id.
        if ( $key ne 'id' && defined $hash{$key} && $hash{$key} !~ /^\d+$/ ) {
            my ( $op, $val, $func );
            ( $key, $op, $val, $func ) = Jifty->handle->_make_clause_case_insensitive( $key, '=', delete $hash{$key} );
            $hash{$key}->{operator} = $op;
            $hash{$key}->{value}    = $val;
            $hash{$key}->{function} = $func;
        }
    }
    return $self->SUPER::load_by_cols(%hash);
}

# }}}

# {{{ Datehandling

# There is room for optimizations in most of those subs:

# {{{ LastUpdatedObj

sub LastUpdatedObj {
    my $self = shift;
    my $obj  = RT::Date->new();

    $obj->set( Format => 'sql', value => $self->LastUpdated );
    return $obj;
}

# }}}

# {{{ CreatedObj

sub CreatedObj {
    my $self = shift;
    my $obj  = RT::Date->new();

    $obj->set( Format => 'sql', value => $self->Created );

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

# {{{ sub _set 
#
sub _set {
    my $self = shift;

    my %args = (
        column => undef,
        value => undef,
        is_sql_function => undef,
        @_
    );

    unless ($args{'column'}) { Carp::confess("Field not converted to column") }

    #if the user is trying to modify the record
    # TODO: document _why_ this code is here

    if ( ( !defined( $args{'column'} ) ) || ( !defined( $args{'value'} ) ) ) {
        $args{'value'} = 0;
    }

    my $old_val = $self->__value($args{'column'});
     $self->_setLastUpdated();
    my $ret = $self->SUPER::_set(
        column => $args{'column'},
        value => $args{'value'},
        is_sql_function => $args{'is_sql_function'}
    );
        my ($status, $msg) =  $ret->as_array();

        # @values has two values, a status code and a message.

    # $ret is a Class::Returnvalue object. as such, in a boolean context, it's a bool
    # we want to change the standard "success" message
    if ($status) {
        $msg =
          $self->loc(
            "%1 changed from %2 to %3",
            $args{'column'},
            ( $old_val ? "'$old_val'" : $self->loc("(no value)") ),
            '"' . ($self->__value( $args{'column'}) ||'weird undefined value'). '"' 
          );
      } else {

          $msg = $self->current_user->loc_fuzzy($msg);
    }
    return wantarray ? ($status, $msg) : $ret;     

}

# }}}

# {{{ sub _setLastUpdated

=head2 _setLastUpdated

This routine updates the LastUpdated and LastUpdatedBy columns of the row in question
It takes no options. Arguably, this is a bug

=cut

sub _setLastUpdated {
    my $self = shift;
    my $now = RT::Date->new( current_user => $self->current_user );
    $now->set_to_now();

        my ( $msg, $val ) = $self->__set(
            column => 'LastUpdated',
            value => $now->ISO
        );
        ( $msg, $val ) = $self->__set(
            column => 'LastUpdatedBy',
            value =>  $self->current_user ? $self->current_user->id  : 0
        );
}

# }}}

# {{{ sub CreatorObj 

=head2 CreatorObj

Returns an RT::Model::User object with the RT account of the creator of this row

=cut

sub CreatorObj {
    my $self = shift;
    unless ( exists $self->{'CreatorObj'} ) {

        $self->{'CreatorObj'} = RT::Model::User->new;
        $self->{'CreatorObj'}->load( $self->Creator );
    }
    return ( $self->{'CreatorObj'} );
}

# }}}

# {{{ sub LastUpdatedByObj

=head2 LastUpdatedByObj

  Returns an RT::Model::User object of the last user to touch this object

=cut

sub LastUpdatedByObj {
    my $self = shift;
    unless ( exists $self->{LastUpdatedByObj} ) {
        $self->{'LastUpdatedByObj'} = RT::Model::User->new;
        $self->{'LastUpdatedByObj'}->load( $self->LastUpdatedBy );
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
    my $uri = RT::URI::fsck_com_rt->new;
    return($uri->URIForObject($self));
}

# }}}

=head2 Validatename name

Validate the name of the record we're creating. Mostly, just make sure it's not a numeric ID, which is invalid for name

=cut

sub validate_name {
    my $self = shift;
    my $value = shift;
    if ($value && $value=~ /^\d+$/) {
        return(0);
    } else  {
         return (1);
    }
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
        my $MaxSize = RT->Config->Get('MaxAttachmentSize');

        #if the current attachment contains nulls and the
        #database doesn't support embedded nulls

        if ( RT->Config->Get('AlwaysUseBase64')) {

            # set a flag telling us to mimencode the attachment
            $ContentEncoding = 'base64';

            #cut the max attchment size by 25% (for mime-encoding overhead.
            $RT::Logger->debug("Max size is $MaxSize\n");
            $MaxSize = $MaxSize * 3 / 4;
        # Some databases (postgres) can't handle non-utf8 data
        } elsif (  0 #   !Jifty->handle->binary_safe_blobs
                  && $MIMEType !~ /text\/plain/gi
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
    my $ContentType     = shift || '';
    my $ContentEncoding = shift || 'none';
    my $Content         = shift;

    if ( $ContentEncoding eq 'base64' ) {
        $Content = MIME::Base64::decode_base64($Content);
    }
    elsif ( $ContentEncoding eq 'quoted-printable' ) {
        $Content = MIME::QuotedPrint::decode($Content);
    }
    elsif ( $ContentEncoding && $ContentEncoding ne 'none' ) {
        return ( $self->loc( "Unknown ContentEncoding %1", $ContentEncoding ) );
    }
    if ( $ContentType eq 'text/plain' ) {
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
                  Target => 'has_member', },
    RefersTo => { Base => 'RefersTo',
                Target => 'ReferredToBy', },
    DependsOn => { Base => 'DependsOn',
                   Target => 'DependedOnBy', },
    MergedInto => { Base => 'MergedInto',
                   Target => 'MergedInto', },

);

sub Update {
    my $self = shift;
    my $class = ref($self) || $self;

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
        # and might not have a name method. 
        # If it fails, we don't care
        eval {
            my $object = $attribute . "Obj";
            next if ($self->can($object) && $self->$object->name eq $value);
        };
        next if ( $value eq ( $self->$attribute()|| '' ) );
        my $method = "set_$attribute";
        my ( $code, $msg ) = $self->$method($value);
        my ($prefix) = ref($self) =~ /RT(?:.*)::(\w+)/;

        # Default to $id, but use name if we can get it.
        my $label = $self->id;
        $label = $self->name if (UNIVERSAL::can($self,'name'));
        push @results, $self->loc( "$prefix %1", $label ) . ': '. $msg;

=for loc

                                   "%1 could not be set to %2.",       # loc
                                   "That is already the current value",    # loc
                                   "No value sent to _set!\n",             # loc
                                   "Illegal value for %1",               # loc
                                   "The new value has been set.",          # loc
                                   "No column specified",                  # loc
                                   "Immutable field",                      # loc
                                   "Nonexistant field?",                   # loc
                                   "Invalid data",                         # loc
                                   "Couldn't find row",                    # loc
                                   "Missing a primary key?: %1",         # loc
                                   "Found Object",                         # loc

=cut

    }

    return @results;
}

# {{{ Routines dealing with Links

# {{{ Link Collections

# {{{ sub Members

=head2 Members

  This returns an RT::Model::LinkCollection object which references all the tickets 
which are 'MembersOf' this ticket

=cut

sub Members {
    my $self = shift;
    return ( $self->_Links( 'Target', 'MemberOf' ) );
}

# }}}

# {{{ sub MemberOf

=head2 MemberOf

  This returns an RT::Model::LinkCollection object which references all the tickets that this
ticket is a 'MemberOf'

=cut

sub MemberOf {
    my $self = shift;
    return ( $self->_Links( 'Base', 'MemberOf' ) );
}

# }}}

# {{{ RefersTo

=head2 RefersTo

  This returns an RT::Model::LinkCollection object which shows all references for which this ticket is a base

=cut

sub RefersTo {
    my $self = shift;
    return ( $self->_Links( 'Base', 'RefersTo' ) );
}

# }}}

# {{{ ReferredToBy

=head2 ReferredToBy

  This returns an RT::Model::LinkCollection object which shows all references for which this ticket is a target

=cut

sub ReferredToBy {
    my $self = shift;
    return ( $self->_Links( 'Target', 'RefersTo' ) );
}

# }}}

# {{{ DependedOnBy

=head2 DependedOnBy

  This returns an RT::Model::LinkCollection object which references all the tickets that depend on this one

=cut

sub DependedOnBy {
    my $self = shift;
    return ( $self->_Links( 'Target', 'DependsOn' ) );
}

# }}}



=head2 has_unresolved_dependencies

  Takes a paramhash of Type (default to '__any').  Returns true if
$self->unresolved_dependencies returns an object with one or more members
of that type.  Returns false otherwise



=cut

sub has_unresolved_dependencies {
    my $self = shift;
    my %args = (
        Type   => undef,
        @_
    );

    my $deps = $self->unresolved_dependencies;

    if ($args{Type}) {
        $deps->limit( column => 'Type', 
              operator => '=',
              value => $args{Type}); 
    }
    else {
	    $deps->IgnoreType;
    }

    if ($deps->count > 0) {
        return 1;
    }
    else {
        return (undef);
    }
}


# {{{ unresolved_dependencies 

=head2 unresolved_dependencies

Returns an RT::Model::TicketCollection object of tickets which this ticket depends on
and which have a status of new, open or stalled. (That list comes from
RT::Model::Queue->ActiveStatusArray

=cut


sub unresolved_dependencies {
    my $self = shift;
    my $deps = RT::Model::TicketCollection->new;

    my @live_statuses = RT::Model::Queue->ActiveStatusArray();
    foreach my $status (@live_statuses) {
        $deps->LimitStatus(value => $status);
    }
    $deps->limit_depended_on_by($self->id);

    return($deps);

}

# }}}

# {{{ AllDependedOnBy

=head2 AllDependedOnBy

Returns an array of RT::Model::Ticket objects which (directly or indirectly)
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

    while (my $link = $dep->next()) {
	next unless ($link->BaseURI->IsLocal());
	next if $args{_found}{$link->BaseObj->id};

	if (!$args{Type}) {
	    $args{_found}{$link->BaseObj->id} = $link->BaseObj;
	    $link->BaseObj->AllDependedOnBy( %args, _top => 0 );
	}
	elsif ($link->BaseObj->Type eq $args{Type}) {
	    $args{_found}{$link->BaseObj->id} = $link->BaseObj;
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

  This returns an RT::Model::LinkCollection object which references all the tickets that this ticket depends on

=cut

sub DependsOn {
    my $self = shift;
    return ( $self->_Links( 'Base', 'DependsOn' ) );
}

# }}}




# {{{ sub _Links 

=head2 Links DIRECTION TYPE 

return links to/from this object. 

=cut

*Links = \&_Links;

sub _Links {
    my $self = shift;

    #TODO: Field isn't the right thing here. but I ahave no idea what mnemonic ---
    #tobias meant by $f
    my $field = shift;
    my $type  = shift || "";

    unless ( $self->{"$field$type"} ) {
        $self->{"$field$type"} = RT::Model::LinkCollection->new;
            # at least to myself
            $self->{"$field$type"}->limit( column => $field,
                                           value => $self->URI,
                                           entry_aggregator => 'OR' );
            $self->{"$field$type"}->limit( column => 'Type',
                                           value => $type )
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
    use RT::Model::Link;
    my $old_link = RT::Model::Link->new;
    $old_link->loadByParams( Base   => $args{'Base'},
                             Type   => $args{'Type'},
                             Target => $args{'Target'} );
    if ( $old_link->id ) {
        $RT::Logger->debug("$self Somebody tried to duplicate a link");
        return ( $old_link->id, $self->loc("Link already exists"), 1 );
    }

    # }}}


    # Storing the link in the DB.
    my $link = RT::Model::Link->new;
    my ($linkid, $linkmsg) = $link->create( Target => $args{Target},
                                  Base   => $args{Base},
                                  Type   => $args{Type} );

    unless ($linkid) {
        $RT::Logger->error("Link could not be Created: ".$linkmsg);
        return ( 0, $self->loc("Link could not be Created") );
    }

    my $TransString =
      "Record $args{'Base'} $args{Type} record $args{'Target'}.";

    return ( $linkid, $self->loc( "Link Created (%1)", $TransString ) );
}

# }}}

# {{{ sub _delete_link 

=head2 _delete_link

Delete a link. takes a paramhash of Base, Target and Type.
Either Base or Target must be null. The null value will 
be replaced with this ticket\'s id

=cut 

sub _delete_link {
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
        $RT::Logger->debug("$self ->_delete_link. got both Base and Target\n");
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

    my $link = RT::Model::Link->new();
    $RT::Logger->debug( "Trying to load link: " . $args{'Base'} . " " . $args{'Type'} . " " . $args{'Target'} . "\n" );


    $link->loadByParams( Base=> $args{'Base'}, Type=> $args{'Type'}, Target=>  $args{'Target'} );
    #it's a real link. 
    if ( $link->id ) {

        my $linkid = $link->id;
        $link->delete();

        my $TransString = "Record $args{'Base'} no longer $args{Type} record $args{'Target'}.";
        return ( 1, $self->loc("Link deleted (%1)", $TransString));
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

Private function to create a RT::Model::Transaction->new object for this ticket update

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
	$old_ref = $old_ref->id if ref($old_ref);
	$new_ref = $new_ref->id if ref($new_ref);
    }

    my $trans = RT::Model::Transaction->new();
    my ( $transaction, $msg ) = $trans->create(
	object_id  => $self->id,
	object_type => ref($self),
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
    $self->load($self->id);

    $RT::Logger->warning($msg) unless $transaction;

    $self->_setLastUpdated;

    if ( defined $args{'TimeTaken'} and $self->can('_UpdateTimeTaken')) {
        $self->_UpdateTimeTaken( $args{'TimeTaken'} );
    }
    if ( RT->Config->Get('UseTransactionBatch') and $transaction ) {
	    push @{$self->{_TransactionBatch}}, $trans if $args{'CommitScrips'};
    }
    return ( $transaction, $msg, $trans );
}

# }}}

# {{{ sub Transactions 

=head2 Transactions

  Returns an RT::Model::TransactionCollection object of all transactions on this record object

=cut

sub Transactions {
    my $self = shift;

    use RT::Model::TransactionCollection;
    my $transactions = RT::Model::TransactionCollection->new;

    #If the user has no rights, return an empty object
    $transactions->limit(
        column => 'object_id',
        value => $self->id,
    );
    $transactions->limit(
        column => 'object_type',
        value => ref($self),
    );

    return ($transactions);
}

# }}}
# }}}
#
# {{{ Routines dealing with custom fields

sub CustomFields {
    my $self = shift;
    my $cfs  = RT::Model::CustomFieldCollection->new;

    # XXX handle multiple types properly
    $cfs->LimitToLookupType( $self->CustomFieldLookupType );
    $cfs->LimitToGlobalOrobject_id(
        $self->_LookupId( $self->CustomFieldLookupType ) );

    return $cfs;
}

# TODO: This _only_ works for RT::Class classes. it doesn't work, for example, for RT::FM classes.

sub _LookupId {
    my $self = shift;
    my $lookup = shift;
    my @classes = ($lookup =~ /RT::Model::(\w+)-/g);

    my $object = $self;
    foreach my $class (reverse @classes) {
	my $method = "${class}Obj";
	$object = $object->$method;
    }

    return $object->id;
}


=head2 CustomFieldLookupType 

Returns the path RT uses to figure out which custom fields apply to this object.

=cut

sub CustomFieldLookupType {
    my $self = shift;
    return ref($self);
}

# {{{ AddCustomFieldValue

=head2 AddCustomFieldValue { Field => column, value => value }

value should be a string. column can be any identifier of a CustomField
supported by L</LoadCustomFieldByIdentifier> method.

Adds value as a value of CustomField column. If this is a single-value custom field,
deletes the old value.
If value is not a valid value for the custom field, returns 
(0, 'Error message' ) otherwise, returns ($id, 'Success Message') where
$id is ID of Created L<ObjectCustomFieldValue> object.

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
    if (!defined $args{'Field'}) {
    $args{'Field'} ||= $args{'column'};
    unless ($args{'Field'}) {
        Carp::cluck("Field argument missing. maybe a mistaken s// changed Field to Column?");

    }
    }

    if (!defined $args{'Value'}) {
    $args{'Value'} ||= delete $args{'value'};
    unless ($args{'Value'} ) {
        Carp::cluck("Value argument missing. maybe i'ts written as 'value'?");
    }
    }
    my $cf = $self->load_custom_field_by_identifier($args{'Field'});
    unless ( $cf->id ) {
        return ( 0, $self->loc( "Custom field %1 not found", $args{'Field'} ) );
    }

    my $OCFs = $self->CustomFields;
    $OCFs->limit( column => 'id', value => $cf->id );
    unless ( $OCFs->count ) {
        return (
            0,
            $self->loc(
                "Custom field %1 does not apply to this object",
                $args{'Field'}
            )
        );
    }

    # empty string is not correct value of any CF, so undef it
    foreach ( qw(Value LargeContent) ) {
        $args{ $_ } = undef if defined $args{ $_ } && !length $args{ $_ };
    }


    if ($cf->can('validate_Value')) { unless ( $cf->validate_Value( $args{'Value'} ) ) { return ( 0, $self->loc("Invalid value for custom field") ); } }
    # If the custom field only accepts a certain # of values, delete the existing
    # value and record a "changed from foo to bar" transaction
    unless ( $cf->unlimitedValues ) {

        # Load up a ObjectCustomFieldValues object for this custom field and this ticket
        my $values = $cf->ValuesForObject($self);

        # We need to whack any old values here.  In most cases, the custom field should
        # only have one value to delete.  In the pathalogical case, this custom field
        # used to be a multiple and we have many values to whack....
        my $cf_values = $values->count;

        if ( $cf_values > $cf->MaxValues ) {
            my $i = 0;   #We want to delete all but the max we can currently have , so we can then
                 # execute the same code to "change" the value from old to new
            while ( my $value = $values->next ) {
                $i++;
                if ( $i < $cf_values ) {
                    my ( $val, $msg ) = $cf->deleteValueForObject(
                        Object  => $self,
                        Content => $value->Content
                    );
                    unless ($val) {
                        return ( 0, $msg );
                    }
                    my ( $TransactionId, $Msg, $TransactionObj ) =
                      $self->_NewTransaction(
                        Type         => 'CustomField',
                        Field        => $cf->id,
                        OldReference => $value,
                      );
                }
            }
            $values->redo_search if $i; # redo search if have deleted at least one value
        }

        my ( $old_value, $old_content );
        if ( $old_value = $values->first ) {
            $old_content = $old_value->Content;
            $old_content = undef if defined $old_content && !length $old_content;

            my $is_the_same = 1;
            if ( defined $args{'Value'} ) {
                $is_the_same = 0 unless defined $old_content
                    && lc $old_content eq lc $args{'Value'};
            } else {
                $is_the_same = 0 if defined $old_content;
            }
            if ( $is_the_same ) {
                my $old_content = $old_value->LargeContent;
                if ( defined $args{'LargeContent'} ) {
                    $is_the_same = 0 unless defined $old_content
                        && $old_content eq $args{'LargeContent'};
                } else {
                    $is_the_same = 0 if defined $old_content;
                }
            }

            return $old_value->id if $is_the_same;
        }

        my ( $new_value_id, $value_msg ) = $cf->AddValueForObject(
            Object       => $self,
            Content      => $args{'Value'},
            LargeContent => $args{'LargeContent'},
            ContentType  => $args{'ContentType'},
        );

        unless ( $new_value_id ) {
            return ( 0, $self->loc( "Could not add new custom field value: %1", $value_msg ) );
        }

        my $new_value = RT::Model::ObjectCustomFieldValue->new;
        $new_value->load( $new_value_id );

        # now that adding the new value was successful, delete the old one
        if ( $old_value ) {
            my ( $val, $msg ) = $old_value->delete();
            return ( 0, $msg ) unless $val;
        }

        if ( $args{'RecordTransaction'} ) {
            my ( $TransactionId, $Msg, $TransactionObj ) =
              $self->_NewTransaction(
                Type         => 'CustomField',
                Field        => $cf->id,
                OldReference => $old_value,
                NewReference => $new_value,
              );
        }

        my $new_content = $new_value->Content;
        unless ( defined $old_content && length $old_content ) {
            return ( $new_value_id, $self->loc( "%1 %2 added", $cf->name, $new_content ));
        }
        elsif ( !defined $new_content || !length $new_content ) {
            return ( $new_value_id,
                $self->loc( "%1 %2 deleted", $cf->name, $old_content ) );
        }
        else {
            return ( $new_value_id, $self->loc( "%1 %2 changed to %3", $cf->name, $old_content, $new_content));
        }

    }

    # otherwise, just add a new value and record "new value added"
    else {
        my ($new_value_id, $msg) = $cf->AddValueForObject(
            Object       => $self,
            Content      => $args{'Value'},
            LargeContent => $args{'LargeContent'},
            ContentType  => $args{'ContentType'},
        );

        unless ( $new_value_id ) {
            return ( 0, $self->loc( "Could not add new custom field value: %1", $msg ) );
        }
        if ( $args{'RecordTransaction'} ) {
            my ( $tid, $msg ) = $self->_NewTransaction(
                Type          => 'CustomField',
                Field         => $cf->id,
                NewReference  => $new_value_id,
                ReferenceType => 'RT::Model::ObjectCustomFieldValue',
            );
            unless ( $tid ) {
                return ( 0, $self->loc( "Couldn't create a transaction: %1", $msg ) );
            }
        }
        return ( $new_value_id, $self->loc( "%1 added as a value for %2", $args{'Value'}, $cf->name ) );
    }
}

# }}}

# {{{ DeleteCustomFieldValue

=head2 DeleteCustomFieldValue { Field => column, value => value }

Deletes value as a value of CustomField column. 

value can be a string, a CustomFieldValue or a ObjectCustomFieldValue.

If value is not a valid value for the custom field, returns 
(0, 'Error message' ) otherwise, returns (1, 'Success Message')

=cut

sub delete_custom_field_value {
    my $self = shift;
    my %args = (
        Field   => undef,
        Value   => undef,
        ValueId => undef,
        @_
    );

    my $cf = $self->load_custom_field_by_identifier($args{'Field'});
    unless ( $cf->id ) {
        return ( 0, $self->loc( "Custom field %1 not found", $args{'Field'} ) );
    }

    my ( $val, $msg ) = $cf->deleteValueForObject(
        Object  => $self,
        Id      => $args{'ValueId'},
        Content => $args{'Value'},
    );
    unless ($val) {
        return ( 0, $msg );
    }

    my ( $TransactionId, $Msg, $TransactionObj ) = $self->_NewTransaction(
        Type          => 'CustomField',
        Field         => $cf->id,
        OldReference  => $val,
        ReferenceType => 'RT::Model::ObjectCustomFieldValue',
    );
    unless ($TransactionId) {
        return ( 0, $self->loc( "Couldn't create a transaction: %1", $Msg ) );
    }

    return (
        $TransactionId,
        $self->loc(
            "%1 is no longer a value for custom field %2",
            $TransactionObj->OldValue, $cf->name
        )
    );
}

# }}}

# {{{ first_custom_field_value

=head2 first_custom_field_value column

Return the content of the first value of CustomField column for this ticket
Takes a field id or name

=cut

sub first_custom_field_value {
    my $self = shift;
    my $field = shift;
    my $values = $self->CustomFieldValues( $field );
    return undef unless my $first = $values->first;
    return $first->Content;
}



# {{{ CustomFieldValues

=head2 CustomFieldValues column

Return a ObjectCustomFieldValues object of all values of the CustomField whose 
id or name is column for this record.

Returns an RT::Model::ObjectCustomFieldValueCollection object

=cut

sub CustomFieldValues {
    my $self  = shift;
    my $field = shift;

    if ( $field ) {
        my $cf = $self->load_custom_field_by_identifier( $field );

        # we were asked to search on a custom field we couldn't find
        unless ( $cf->id ) {
            $RT::Logger->warning("Couldn't load custom field by '$field' identifier");
            return RT::Model::ObjectCustomFieldValueCollection->new;
        }
        return ( $cf->ValuesForObject($self) );
    }
    # we're not limiting to a specific custom field;
    my $ocfs = RT::Model::ObjectCustomFieldValueCollection->new;
    $ocfs->LimitToObject( $self );
    return $ocfs;
}

=head2 LoadCustomFieldByIdentifier IDENTIFER

Find the custom field has id or name IDENTIFIER for this object.

If no valid field is found, returns an empty RT::Model::CustomField object.

=cut

sub load_custom_field_by_identifier {
    my $self = shift;
    my $field = shift;
   
    unless (defined $field) {
        Carp::confess;
    }
    my $cf = RT::Model::CustomField->new;

    if ( UNIVERSAL::isa( $field, "RT::Model::CustomField" ) ) {
        $cf->load_by_id( $field->id );
    }
    elsif ($field =~ /^\d+$/) {
        $cf = RT::Model::CustomField->new;
        $cf->load_by_id($field);
    } else {

        my $cfs = $self->CustomFields($self->current_user);
        $cfs->limit(column => 'name', value => $field, case_sensitive => 0);
        $cf = $cfs->first || RT::Model::CustomField->new;
    }
    return $cf;
}


# }}}

# }}}

# }}}

sub BasicColumns {
}

sub WikiBase {
    return RT->Config->Get('WebPath'). "/index.html?q=";
}

sub DESTROY {}
sub Table { warn(" deprecated Table call discarded")}
use vars qw/$AUTOLOAD/;
sub AUTOLOAD { Carp::cluck $AUTOLOAD . " not found"}

1;
