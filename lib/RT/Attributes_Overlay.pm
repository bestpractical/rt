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
=head1 NAME

  RT::Attributes - collection of RT::Attribute objects

=head1 SYNOPSIS

  use RT:Attributes;
my $Attributes = new RT::Attributes($CurrentUser);

=head1 DESCRIPTION


=head1 METHODS

=begin testing

ok(require RT::Attributes);

my $root = RT::User->new($RT::SystemUser);
ok (UNIVERSAL::isa($root, 'RT::User'));
$root->Load('root');
ok($root->id, "Found a user for root");

my $attr = $root->Attributes;

ok (UNIVERSAL::isa($attr,'RT::Attributes'), 'got the attributes object');

ok($root->AddAttribute(Name => 'TestAttr', Content => 'The attribute has content')); 

my @names = $attr->Names;

is ($names[0] , 'TestAttr');


=end testing

=cut

use strict;
no warnings qw(redefine);


sub _DoSearch {
    my $self = shift;
    $self->SUPER::_DoSearch();
    $self->_BuildAccessTable();
}


sub _BuildAccessTable {
    my $self = shift;
    delete $self->{'attr'};
    while (my $attr = $self->Next) {
        push @{$self->{'attr'}->{$attr->Name}}, $attr;
    }
}


sub _AttrHash {
    my $self = shift;
    $self->_DoSearch if ($self->{'must_redo_search'});
    unless ($self->{'attr'}) {
        $self->{'attr'}->{'__none'} = RT::Attribute->new($self->CurrentUser);
    }
    return ($self->{'attr'});
}

=head2 Names

Returns a list of the Names of all attributes for this object. 

=cut

sub Names {
    my $self = shift;
    my @keys =  keys %{$self->_AttrHash};
    return(@keys);


}

=head2 Named STRING

Returns an array of all the RT::Attribute objects with the name STRING

=cut

sub Named {
    my $self = shift;
    my $name = shift;
    my @attributes; 
    if ($self->_AttrHash) {
        @attributes = @{($self->_AttrHash->{$name}||[])};
    }
    return (@attributes);   
}

=head2 DeleteEntry { Name =>   Value => }

Deletes the attribute with the matching name and value

=cut


sub DeleteEntry {
    my $self = shift;
    my %args = ( Name => undef,
                 Content => undef,
                 @_);

    foreach my $attr ($self->Named($args{'Name'})){ 
        $attr->Delete if ($attr->Content eq $args{'Content'});
    }
    $self->_DoSearch();
    return (1, $self->loc('Attribute Deleted'));
}


# {{{ LimitToObject 

=head2 LimitToObject $object

Limit the Attributes to rights for the object $object. It needs to be an RT::Record class.

=cut

sub LimitToObject {
    my $self = shift;
    my $obj = shift;
    unless (defined($obj) && ref($obj) && UNIVERSAL::can($obj, 'id')) {
    return undef;
    }
    $self->Limit(FIELD => 'ObjectType', OPERATOR=> '=', VALUE => ref($obj), ENTRYAGGREGATOR => 'OR');
    $self->Limit(FIELD => 'ObjectId', OPERATOR=> '=', VALUE => $obj->id, ENTRYAGGREGATOR => 'OR', QUOTEVALUE => 0);

}

# }}}

1;
