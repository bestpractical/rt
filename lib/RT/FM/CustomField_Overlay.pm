# BEGIN LICENSE BLOCK
# 
#  Copyright (c) 2002 Jesse Vincent <jesse@bestpractical.com>
#  
#  This program is free software; you can redistribute it and/or modify
#  it under the terms of version 2 of the GNU General Public License 
#  as published by the Free Software Foundation.
# 
#  A copy of that license should have arrived with this
#  software, but in any event can be snarfed from www.gnu.org.
# 
#  This program is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#  GNU General Public License for more details.
# 
# END LICENSE BLOCK

no qw/redefine/;


use RT::FM::User;


use vars qw( @TYPES);

@TYPES = qw(SelectSingle SelectMultiple FreeformSingle FreeformMultiple );

=item Value NAME

Returns a RT::FM::CustomFieldValue object of this Field\'s value with the name NAME

=cut

sub Value {
    my $self = shift;
    my $name = shift;

    my $values = $self->ValuesObj();
    $values->Limit(FIELD => 'Name',
		   OPERATOR => '=',
		   VALUE => $name);

    return ($values->First);

}

=item ValuesObj

Returns a RT::FM::CustomFieldValueCollection object of this Field's values.

=cut

sub ValuesObj {
	my $self = shift;
	my $values = new RT::FM::CustomFieldValueCollection($self->CurrentUser);
	$values->Limit( FIELD => 'CustomField',
			OPERATOR => '=',
			VALUE => $self->Id );
	return ($values);
}

=item NewValue HASH

Create a new value for this CustomField.  Takes a paramhash containing the elements Name, Description and SortOrder

=cut

sub NewValue {
	my $self = shift;
	my %args = ( Name => undef,
		     Description => undef,
		     SortOrder => undef,
		     CustomField => $self->Id,
		     @_ );
	print STDERR "New value is ".$args{'Name'}."\n";
	my $newval = new RT::FM::CustomFieldValue($self->CurrentUser);
	return($newval->Create(%args));
}

=item DeleteValue ID

Deletes a value from this custom field by id.  Also removes this value
for any article which has had it selected	

=cut

sub DeleteValue {
	my $self = shift;
	my $id = shift;
	my $valtodel = new RT::FM::CustomFieldValue($self->CurrentUser);
	$valtodel->Load($id);
	unless ($valtodel->Id) {
		return (0, "Couldn't find that value");
	}
	unless ($valtodel->CustomField == $self->Id) {
		return (0, "That is not a value for this custom field");
	}

	return($valtodel->Delete());
}



=item Types 

Retuns an array of the types of CustomField that are supported

=cut

sub Types {
	return (@TYPES);
}


1;
