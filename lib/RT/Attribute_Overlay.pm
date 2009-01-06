# BEGIN BPS TAGGED BLOCK {{{
# 
# COPYRIGHT:
# 
# This software is Copyright (c) 1996-2009 Best Practical Solutions, LLC
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

package RT::Attribute;

use strict;
no warnings qw(redefine);
use Storable qw/nfreeze thaw/;
use MIME::Base64;


=head1 NAME

  RT::Attribute_Overlay 

=head1 Content

=cut

# the acl map is a map of "name of attribute" and "what right the user must have on the associated object to see/edit it

our $ACL_MAP = {
    SavedSearch => { create => 'EditSavedSearches',
                     update => 'EditSavedSearches',
                     delete => 'EditSavedSearches',
                     display => 'ShowSavedSearches' },

};

# There are a number of attributes that users should be able to modify for themselves, such as saved searches
#  we could do this with a different set of "modify" rights, but that gets very hacky very fast. this is even faster and even
# hackier. we're hardcoding that a different set of rights are needed for attributes on oneself
our $PERSONAL_ACL_MAP = { 
    SavedSearch => { create => 'ModifySelf',
                     update => 'ModifySelf',
                     delete => 'ModifySelf',
                     display => 'allow' },

};

=head2 LookupObjectRight { ObjectType => undef, ObjectId => undef, Name => undef, Right => { create, update, delete, display } }

Returns the right that the user needs to have on this attribute's object to perform the related attribute operation. Returns "allow" if the right is otherwise unspecified.

=cut

sub LookupObjectRight { 
    my $self = shift;
    my %args = ( ObjectType => undef,
                 ObjectId => undef,
                 Right => undef,
                 Name => undef,
                 @_);

    # if it's an attribute on oneself, check the personal acl map
    if (($args{'ObjectType'} eq 'RT::User') && ($args{'ObjectId'} eq $self->CurrentUser->Id)) {
    return('allow') unless ($PERSONAL_ACL_MAP->{$args{'Name'}});
    return('allow') unless ($PERSONAL_ACL_MAP->{$args{'Name'}}->{$args{'Right'}});
    return($PERSONAL_ACL_MAP->{$args{'Name'}}->{$args{'Right'}}); 

    }
   # otherwise check the main ACL map
    else {
    return('allow') unless ($ACL_MAP->{$args{'Name'}});
    return('allow') unless ($ACL_MAP->{$args{'Name'}}->{$args{'Right'}});
    return($ACL_MAP->{$args{'Name'}}->{$args{'Right'}}); 
    }
}




=head2 Create PARAMHASH

Create takes a hash of values and creates a row in the database:

  varchar(200) 'Name'.
  varchar(255) 'Content'.
  varchar(16) 'ContentType',
  varchar(64) 'ObjectType'.
  int(11) 'ObjectId'.

You may pass a C<Object> instead of C<ObjectType> and C<ObjectId>.

=cut




sub Create {
    my $self = shift;
    my %args = ( 
                Name => '',
                Description => '',
                Content => '',
                ContentType => '',
                Object => undef,
		  @_);

    if ($args{Object} and UNIVERSAL::can($args{Object}, 'Id')) {
	    $args{ObjectType} = ref($args{Object});
	    $args{ObjectId} = $args{Object}->Id;
    } else {
        return(0, $self->loc("Required parameter '[_1]' not specified", 'Object'));

    }
   
    # object_right is the right that the user has to have on the object for them to have $right on this attribute
    my $object_right = $self->LookupObjectRight(
        Right      => 'create',
        ObjectId   => $args{'ObjectId'},
        ObjectType => $args{'ObjectType'},
        Name       => $args{'Name'}
    );
    if ($object_right eq 'deny') { 
        return (0, $self->loc('Permission Denied'));
    } 
    elsif ($object_right eq 'allow') {
        # do nothing, we're ok
    }
    elsif (!$self->CurrentUser->HasRight( Object => $args{Object}, Right => $object_right)) {
        return (0, $self->loc('Permission Denied'));
    }

   
    if (ref ($args{'Content'}) ) { 
        eval  {$args{'Content'} = $self->_SerializeContent($args{'Content'}); };
        if ($@) {
         return(0, $@);
        }
        $args{'ContentType'} = 'storable';
    }

    
    $self->SUPER::Create(
                         Name => $args{'Name'},
                         Content => $args{'Content'},
                         ContentType => $args{'ContentType'},
                         Description => $args{'Description'},
                         ObjectType => $args{'ObjectType'},
                         ObjectId => $args{'ObjectId'},
);

}


# {{{ sub LoadByNameAndObject

=head2  LoadByNameAndObject (Object => OBJECT, Name => NAME)

Loads the Attribute named NAME for Object OBJECT.

=cut

sub LoadByNameAndObject {
    my $self = shift;
    my %args = (
        Object => undef,
        Name  => undef,
        @_,
    );

    return (
	$self->LoadByCols(
	    Name => $args{'Name'},
	    ObjectType => ref($args{'Object'}),
	    ObjectId => $args{'Object'}->Id,
	)
    );

}

# }}}


=head2 _DeserializeContent

DeserializeContent returns this Attribute's "Content" as a hashref.


=cut

sub _DeserializeContent {
    my $self = shift;
    my $content = shift;

    my $hashref;
    eval {$hashref  = thaw(decode_base64($content))} ; 
    if ($@) {
        $RT::Logger->error("Deserialization of attribute ".$self->Id. " failed");
    }

    return($hashref);

}


=head2 Content

Returns this attribute's content. If it's a scalar, returns a scalar
If it's data structure returns a ref to that data structure.

=cut

sub Content {
    my $self = shift;
    # Here we call _Value to get the ACL check.
    my $content = $self->_Value('Content');
    if ($self->__Value('ContentType') eq 'storable') {
        eval {$content = $self->_DeserializeContent($content); };
        if ($@) {
            $RT::Logger->error("Deserialization of content for attribute ".$self->Id. " failed. Attribute was: ".$content);
        }
    } 

    return($content);

}

sub _SerializeContent {
    my $self = shift;
    my $content = shift;
        return( encode_base64(nfreeze($content))); 
}


sub SetContent {
    my $self = shift;
    my $content = shift;

    # Call __Value to avoid ACL check.
    if ( $self->__Value('ContentType') eq 'storable' ) {
        # We eval the serialization because it will lose on a coderef.
        $content = eval { $self->_SerializeContent($content) };
        if ($@) {
            $RT::Logger->error("Content couldn't be frozen: $@");
            return(0, "Content couldn't be frozen");
        }
    }
    return $self->SUPER::SetContent( $content );
}

=head2 SubValue KEY

Returns the subvalue for $key.


=cut

sub SubValue {
    my $self = shift;
    my $key = shift;
    my $values = $self->Content();
    return undef unless ref($values);
    return($values->{$key});
}

=head2 DeleteSubValue NAME

Deletes the subvalue with the key NAME

=cut

sub DeleteSubValue {
    my $self = shift;
    my $key = shift;
    my %values = $self->Content();
    delete $values{$key};
    $self->SetContent(%values);

    

}


=head2 DeleteAllSubValues 

Deletes all subvalues for this attribute

=cut


sub DeleteAllSubValues {
    my $self = shift; 
    $self->SetContent({});
}

=head2 SetSubValues  {  }

Takes a hash of keys and values and stores them in the content of this attribute.

Each key B<replaces> the existing key with the same name

Returns a tuple of (status, message)

=cut


sub SetSubValues {
   my $self = shift;
   my %args = (@_); 
   my $values = ($self->Content() || {} );
   foreach my $key (keys %args) {
    $values->{$key} = $args{$key};
   }

   $self->SetContent($values);

}


sub Object {
    my $self = shift;
    my $object_type = $self->__Value('ObjectType');
    my $object;
    eval { $object = $object_type->new($self->CurrentUser) };
    unless(UNIVERSAL::isa($object, $object_type)) {
        $RT::Logger->error("Attribute ".$self->Id." has a bogus object type - $object_type (".$@.")");
        return(undef);
     }
    $object->Load($self->__Value('ObjectId'));

    return($object);

}


sub Delete {
    my $self = shift;
    unless ($self->CurrentUserHasRight('delete')) {
        return (0,$self->loc('Permission Denied'));
    }
    return($self->SUPER::Delete(@_));
}


sub _Value {
    my $self = shift;
    unless ($self->CurrentUserHasRight('display')) {
        return (0,$self->loc('Permission Denied'));
    }

    return($self->SUPER::_Value(@_));


}


sub _Set {
    my $self = shift;
    unless ($self->CurrentUserHasRight('modify')) {

        return (0,$self->loc('Permission Denied'));
    }
    return($self->SUPER::_Set(@_));

}


=head2 CurrentUserHasRight

One of "display" "modify" "delete" or "create" and returns 1 if the user has that right for attributes of this name for this object.Returns undef otherwise.

=cut

sub CurrentUserHasRight {
    my $self = shift;
    my $right = shift;

    # object_right is the right that the user has to have on the object for them to have $right on this attribute
    my $object_right = $self->LookupObjectRight(
        Right      => $right,
        ObjectId   => $self->__Value('ObjectId'),
        ObjectType => $self->__Value('ObjectType'),
        Name       => $self->__Value('Name')
    );
   
    return (1) if ($object_right eq 'allow');
    return (0) if ($object_right eq 'deny');
    return(1) if ($self->CurrentUser->HasRight( Object => $self->Object, Right => $object_right));
    return(0);

}


=head1 TODO

We should be deserializing the content on load and then enver again, rather than at every access

=cut


1;
