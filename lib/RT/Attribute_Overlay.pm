# BEGIN LICENSE BLOCK
# 
# Copyright (c) 1996-2003 Jesse Vincent <jesse@bestpractical.com>
# 
# (Except where explictly superceded by other copyright notices)
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
# Unless otherwise specified, all modifications, corrections or
# extensions to this work which alter its source code become the
# property of Best Practical Solutions, LLC when submitted for
# inclusion in the work.
# 
# 
# END LICENSE BLOCK
use strict;
no warnings qw(redefine);
use Storable qw/nfreeze thaw/;

=head1 NAME

  RT::Attribute_Overlay 

=head1 Content

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
                ObjectType => '',
                ObjectId => '0',
		  @_);

    if ($args{Object} and UNIVERSAL::can($args{Object}, 'Id')) {
	    $args{ObjectType} = ref($args{Object});
	    $args{ObjectId} = $args{Object}->Id;
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
    eval {$hashref  = thaw($content)} ; 
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
    my $content = $self->_Value('Content');
    if ($self->ContentType eq 'storable') {
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
        return( nfreeze($content)); 
}


sub SetContent {
    my $self = shift;
    my $content = shift;

    if ($self->ContentType eq 'storable') {
    # We eval the serialization because it will lose on a coderef.
    eval  {$content = $self->_SerializeContent($content); };
    if ($@) {
        $RT::Logger->error("For some reason, content couldn't be frozen");
        return(0, $@);
    }
    }
    return ($self->SUPER::SetContent($content));
}

=head2 SubValue KEY

Returns the subvalue for $key.

=begin testing

my $user = $RT::SystemUser;
my ($id, $msg) =  $user->AddAttribute(Name => 'SavedSearch', Content => { Query => 'Foo'} );
ok ($id, $msg);
my $attr = RT::Attribute->new($RT::SystemUser);
$attr->Load($id);
ok($attr->Name eq 'SavedSearch');
$attr->SetSubValues( Format => 'baz');

my $format = $attr->SubValue('Format');
is ($format , 'baz');

$attr->SetSubValues( Format => 'bar');
$format = $attr->SubValue('Format');
is ($format , 'bar');

$attr->DeleteAllSubValues();
$format = $attr->SubValue('Format');
is ($format, undef);

$attr->SetSubValues(Format => 'This is a format');

my $attr2 = RT::Attribute->new($RT::SystemUser);
$attr2->Load($id);
is ($attr2->SubValue('Format'), 'This is a format');


=end testing

=cut

sub SubValue {
    my $self = shift;
    my $key = shift;
    my $values = $self->Content();
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


=head1 TODO

We should be deserializing the content on load and then enver again, rather than at every access

=cut


1;
