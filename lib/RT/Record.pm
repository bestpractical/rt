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

  RT::Record - Base class for RT record objects

=head1 SYNOPSIS


=head1 DESCRIPTION


=begin testing

ok (require RT::Record);

=end testing

=head1 METHODS

=cut

package RT::Record;
use RT::Date;
use RT::User;
use RT::Attributes;
use RT::Base;
use DBIx::SearchBuilder::Record::Cachable;

use strict;
use vars qw/@ISA $_TABLE_ATTR/;

@ISA = qw(RT::Base);

if ($RT::DontCacheSearchBuilderRecords ) {
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

    $self->Attributes->RedoSearch;
    
    return ($id, $msg);
}


# {{{ sub _Handle 
sub _Handle {
    my $self = shift;
    return ($RT::Handle);
}

# }}}

# {{{ sub Create 

=item  Create PARAMHASH

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
                my ($op, $val);
                ($key, $op, $val) = $self->_Handle->_MakeClauseCaseInsensitive($key, '=', $hash{$key});
                $newhash{$key}->{operator} = $op;
                $newhash{$key}->{value} = $val;
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

    $self->_SetLastUpdated();
    my ( $val, $msg ) = $self->SUPER::_Set(
        Field => $args{'Field'},
        Value => $args{'Value'},
        IsSQL => $args{'IsSQL'}
    );
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


=head2 SQLType attribute

return the SQL type for the attribute 'attribute' as stored in _ClassAccessible

=cut

sub SQLType {
    my $self = shift;
    my $field = shift;

    return ($self->_Accessible($field, 'type'));


}

require Encode::compat if $] < 5.007001;
require Encode;




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

    return Encode::decode_utf8($value) || $value if $args{'decode_utf8'};
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

    if ( defined $args{'TimeTaken'} ) {
        $self->_UpdateTimeTaken( $args{'TimeTaken'} );
    }
    if ( $RT::UseTransactionBatch and $transaction ) {
	    push @{$self->{_TransactionBatch}}, $trans;
    }
    return ( $transaction, $msg, $trans );
}

# }}}

# {{{ sub Transactions 

=head2 Transactions

  Returns an RT::Transactions object of all transactions on this ticket

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
	FIELD    => 'ObjectType',
	VALUE    => ref($self),
    );

    return ($transactions);
}

# }}}

# {{{ Routines dealing with custom fields

sub CustomFields {
    my $self = shift;
    my $cfs = RT::CustomFields->new( $self->CurrentUser );
    $cfs->UnLimit;

    # XXX handle multiple types properly
    foreach my $lookup ($self->_LookupTypes) {
	$cfs->LimitToLookupType($lookup);
	$cfs->LimitToGlobalOrObjectId($self->_LookupId($lookup));
    }

    return $cfs;
}

sub _LookupId {
    my $self = shift;
    my $lookup = shift;
    my @classes = ($lookup =~ /RT::(\w+)-/g);

    foreach my $class (reverse @classes) {
	my $method = "${class}Obj";
	$self = $self->$method;
    }

    return $self->Id;
}

sub _LookupTypes { ref($_[0]) }

# {{{ AddCustomFieldValue

=item AddCustomFieldValue { Field => FIELD, Value => VALUE }

VALUE should be a string.
FIELD can be a CustomField object OR a CustomField ID.


Adds VALUE as a value of CustomField FIELD.  If this is a single-value custom field,
deletes the old value. 
If VALUE isn't a valid value for the custom field, returns 
(0, 'Error message' ) otherwise, returns (1, 'Success Message')

=cut

sub AddCustomFieldValue {
    my $self = shift;
#    unless ( $self->CurrentUserHasRight('ModifyTicket') ) {
#        return ( 0, $self->loc("Permission Denied") );
#    }
    $self->_AddCustomFieldValue(@_);
}

sub _AddCustomFieldValue {
    my $self = shift;
    my %args = (
        Field => undef,
        Value => undef,
	RecordTransaction => 1,
        @_
    );

    my $cf = RT::CustomField->new( $self->CurrentUser );
    if ( UNIVERSAL::isa( $args{'Field'}, "RT::CustomField" ) ) {
        $cf->Load( $args{'Field'}->id );
    }
    else {
        $cf->Load( $args{'Field'} );
    }

    unless ( $cf->Id ) {
        return ( 0, $self->loc("Custom field [_1] not found", $args{'Field'}) );
    }

    my $OCFs = RT::ObjectCustomFields->new( $self->CurrentUser );
    $OCFs->LimitToCustomField( $cf->Id );
    $OCFs->LimitToObjectId( $self->Id );
    $OCFs->LimitToObjectId( 0 );
    unless ($OCFs->Count) {
        return ( 0, $self->loc("Custom field [_1] does not apply to this object", $args{'Field'}) );
    }

    # Load up a ObjectCustomFieldValues object for this custom field and this ticket
    my $values = $cf->ValuesForObject( $self );

    unless ( $cf->ValidateValue( $args{'Value'} ) ) {
        return ( 0, $self->loc("Invalid value for custom field") );
    }

    # If the custom field only accepts a single value, delete the existing
    # value and record a "changed from foo to bar" transaction
    if ( $cf->SingleValue ) {

        # We need to whack any old values here.  In most cases, the custom field should
        # only have one value to delete.  In the pathalogical case, this custom field
        # used to be a multiple and we have many values to whack....
        my $cf_values = $values->Count;

        if ( $cf_values > 1 ) {
            my $i = 0;   #We want to delete all but the last one, so we can then
                 # execute the same code to "change" the value from old to new
            while ( my $value = $values->Next ) {
                $i++;
                if ( $i < $cf_values ) {
                    my ($val, $msg) = $cf->DeleteValueForObject(Object => $self, Content => $value->Content);
                    unless ($val) {
                        return (0,$msg);
                    }
                    my ( $TransactionId, $Msg, $TransactionObj ) =
                      $self->_NewTransaction(
                        Type     => 'CustomField',
                        Field    => $cf->Id,
                        OldReference => $value,
                      );
                }
            }
        }

        my ($old_value, $old_content);
        if ($old_value = $cf->ValuesForObject( $self )->First) {
	    $old_content = $old_value->Content();
	    return (1) if $old_content eq $args{'Value'};
	}

        my ( $new_value_id, $value_msg ) = $cf->AddValueForObject(
            Object  => $self,
            Content => $args{'Value'},
            LargeContent => $args{'LargeContent'},
            ContentType => $args{'ContentType'},
        );

        unless ($new_value_id) {
            return ( 0,
                $self->loc("Could not add new custom field value for ticket. [_1] ",
                  ,$value_msg) );
        }

        my $new_value = RT::ObjectCustomFieldValue->new( $self->CurrentUser );
        $new_value->Load($new_value_id);

        # now that adding the new value was successful, delete the old one
	if ($old_value) {
	    my ($val, $msg) = $cf->DeleteValueForObject(Object => $self, Content => $old_content);
	    unless ($val) { 
	    		return (0,$msg);
	    }
	}

	if ($args{'RecordTransaction'}) {
        my ( $TransactionId, $Msg, $TransactionObj ) = $self->_NewTransaction(
            Type     => 'CustomField',
            Field    => $cf->Id,
            OldReference => $old_value,
            NewReference => $new_value,
        );
	}

        if ( $old_value eq '' ) {
            return ( 1, $self->loc("[_1] [_2] added", $cf->Name, $new_value->Content) );
        }
        elsif ( $new_value->Content eq '' ) {
            return ( 1, $self->loc("[_1] [_2] deleted", $cf->Name, $old_value) );
        }
        else {
            return ( 1, $self->loc("[_1] [_2] changed to [_3]", $cf->Name, $old_value, $new_value->Content ) );
        }

    }

    # otherwise, just add a new value and record "new value added"
    else {
        my ( $new_value_id ) = $cf->AddValueForObject(
            Object  => $self,
            Content => $args{'Value'},
            LargeContent => $args{'LargeContent'},
            ContentType => $args{'ContentType'},
        );

        unless ($new_value_id) {
            return ( 0,
                $self->loc("Could not add new custom field value for ticket. "));
        }
    if ( $args{'RecordTransaction'} ) {
        my ( $TransactionId, $Msg, $TransactionObj ) = $self->_NewTransaction(
            Type     => 'CustomField',
            Field    => $cf->Id,
            NewReference => $new_value_id,
	    ReferenceType => 'RT::ObjectCustomFieldValue',
        );
        unless ($TransactionId) {
            return ( 0,
                $self->loc( "Couldn't create a transaction: [_1]", $Msg ) );
        }
    }
        return ( 1, $self->loc("[_1] added as a value for [_2]",$args{'Value'}, $cf->Name));
    }

}

# }}}

# {{{ DeleteCustomFieldValue

=item DeleteCustomFieldValue { Field => FIELD, Value => VALUE }

Deletes VALUE as a value of CustomField FIELD. 

VALUE can be a string, a CustomFieldValue or a ObjectCustomFieldValue.

If VALUE isn't a valid value for the custom field, returns 
(0, 'Error message' ) otherwise, returns (1, 'Success Message')

=cut

sub DeleteCustomFieldValue {
    my $self = shift;
    my %args = (
        Field => undef,
        Value => undef,
	ValueId => undef,
        @_);

#    XXX - normalise CF related ACLs... ask obra!
#    unless ( $self->CurrentUserHasRight('ModifyTicket') ) {
#        return ( 0, $self->loc("Permission Denied") );
#    }
    my $cf = RT::CustomField->new( $self->CurrentUser );
    if ( UNIVERSAL::isa( $args{'Field'}, "RT::CustomField" ) ) {
        $cf->LoadById( $args{'Field'}->id );
    }
    else {
        $cf->LoadById( $args{'Field'} );
    }

    unless ( $cf->Id ) {
        return ( 0, $self->loc("Custom field not found") );
    }


     my ($val, $msg) = $cf->DeleteValueForObject(
	 Object => $self,
	 Id => $args{'ValueId'},
	 Content => $args{'Value'},
     );
     unless ($val) { 
            return (0,$msg);
     }
        my ( $TransactionId, $Msg, $TransactionObj ) = $self->_NewTransaction(
            Type     => 'CustomField',
            Field    => $cf->Id,
            OldReference => $val,
	    ReferenceType => 'RT::ObjectCustomFieldValue',
        );
        unless($TransactionId) {
            return(0, $self->loc("Couldn't create a transaction: [_1]", $Msg));
        } 

        return($TransactionId, $self->loc("[_1] is no longer a value for custom field [_2]", $TransactionObj->OldValue, $cf->Name));
}

# }}}

# {{{ FirstCustomFieldValue

=item FirstCustomFieldValue FIELD

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

=item CustomFieldValues FIELD

Return a ObjectCustomFieldValues object of all values of CustomField FIELD for this ticket.  
Takes a field id or name.


=cut

sub CustomFieldValues {
    my $self  = shift;
    my $field = shift;

    my $cf_values = RT::ObjectCustomFieldValues->new( $self->CurrentUser );
    $cf_values->LimitToObject($self);
    $cf_values->OrderBy( FIELD => 'id' );

    if (length $field) {
	$field =~ /^\d+$/ or die "LoadByNameAndQueue impossible for Record.pm";
	my $cf = RT::CustomField->new($self->CurrentUser);
        $cf->LoadById($field);
	$cf_values->LimitToCustomField($cf->id);
    }

    # @values is a CustomFieldValues object;
    return ($cf_values);
}

# }}}

# }}}

sub BasicColumns {
}


eval "require RT::Record_Vendor";
die $@ if ($@ && $@ !~ qr{^Can't locate RT/Record_Vendor.pm});
eval "require RT::Record_Local";
die $@ if ($@ && $@ !~ qr{^Can't locate RT/Record_Local.pm});

1;
