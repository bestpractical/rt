# $Header: /raid/cvsroot/rt/lib/RT/ACL.pm,v 1.2 2001/11/06 23:04:14 jesse Exp $
# Distributed under the terms of the GNU GPL
# Copyright (c) 1996-2002 Jesse Vincent <jesse@fsck.com>

=head1 NAME

  RT::ACL - collection of RT ACE objects

=head1 SYNOPSIS

  use RT::ACL;
my $ACL = new RT::ACL($CurrentUser);

=head1 DESCRIPTION


=head1 METHODS

=begin testing

ok(require RT::ACL);

=end testing

=cut

no warnings qw(redefine);


=head2 Next

Hand out the next ACE that was found

=cut


# {{{ LimitToObject 

=head2 LimitToObject { Type => undef, Id => undef }

Limit the ACL to the Object with ObjectId Id and ObjectType Type

=cut

sub LimitToObject {
    my $self = shift;
    my %args = ( Type => undef,
                 Id => undef,
                 @_);

    $self->Limit(FIELD => 'ObjectType', OPERATOR=> '=', VALUE => $args{'Type'}, ENTRYAGGREGATOR => 'OR');
    $self->Limit(FIELD => 'ObjectId', OPERATOR=> '=', VALUE => $args{'Id'}, ENTRYAGGREGATOR => 'OR');

}

# }}}

# {{{ LimitToPrincipal 

=head2 LimitToPrincipal { Type => undef, Id => undef }

Limit the ACL to the principal with PrincipalId Id and PrincipalType Type

Id is not optional.
Type is.

=cut

sub LimitToPrincipal {
    my $self = shift;
    my %args = ( Type => undef,
                 Id => undef,
                 @_);
    if (defined $args{'Type'} ){
        $self->Limit(FIELD => 'PrincipalType', OPERATOR=> '=', VALUE => $args{'Type'}, ENTRYAGGREGATOR => 'OR');
    }
    $self->Limit(FIELD => 'PrincipalId', OPERATOR=> '=', VALUE => $args{'Id'}, ENTRYAGGREGATOR => 'OR');

}

# }}}

# {{{
=head2 ExcludeDelegatedRights 

Don't list rights which have been delegated.

=cut

sub ExcludeDelegatedRights {
    my $self = shift;
    $self->DelegatedBy(Id => 0);
    $self->DelegatedFrom(Id => 0);
}
# }}}

# {{{ DelegatedBy 

=head2 DelegatedBy { Id => undef }

Limit the ACL to rights delegated by the principal whose Principal Id is
B<Id>

Id is not optional.

=cut

sub DelegatedBy {
    my $self = shift;
    my %args = (
        Id => undef,
        @_
    );
    $self->Limit(
        FIELD           => 'DelegatedBy',
        OPERATOR        => '=',
        VALUE           => $args{'Id'},
        ENTRYAGGREGATOR => 'OR'
    );

}

# }}}

# {{{ DelegatedFrom 

=head2 DelegatedFrom { Id => undef }

Limit the ACL to rights delegate from the ACE which has the Id specified 
by the Id parameter.

Id is not optional.

=cut

sub DelegatedFrom {
    my $self = shift;
    my %args = (
                 Id => undef,
                 @_);
    $self->Limit(FIELD => 'DelegatedFrom', OPERATOR=> '=', VALUE => $args{'Id'}, ENTRYAGGREGATOR => 'OR');

}

# }}}


# {{{ sub Next 
sub Next {
    my $self = shift;
    
    my $ACE = $self->SUPER::Next();
    if ((defined($ACE)) and (ref($ACE))) {
	
	if ( $ACE->CurrentUserHasRight('ShowACL') or
	     $ACE->CurrentUserHasRight('ModifyACL')
	   ) {
	    return($ACE);
	}
	
	#If the user doesn't have the right to show this ACE
	else {	
	    return($self->Next());
	}
    }
    #if there never was any ACE
    else {
	return(undef);
    }	
    
}

# }}}



#wrap around _DoSearch  so that we can build the hash of returned
#values 
sub _DoSearch {
    my $self = shift;
   # $RT::Logger->debug("Now in ".$self."->_DoSearch");
    my $return = $self->SUPER::_DoSearch(@_);
  #  $RT::Logger->debug("In $self ->_DoSearch. return from SUPER::_DoSearch was $return\n");
    $self->_BuildHash();
    return ($return);
}


#Build a hash of this ACL's entries.
sub _BuildHash {
    my $self = shift;

    while (my $entry = $self->Next) {
       my $hashkey = $entry->ObjectType . "-" .  $entry->ObjectId . "-" .  $entry->RightName . "-" .  $entry->PrincipalId . "-" .  $entry->PrincipalType;

        $self->{'as_hash'}->{"$hashkey"} =1;

    }
}


# {{{ HasEntry

=head2 HasEntry

=cut

sub HasEntry {

    my $self = shift;
    my %args = ( RightScope => undef,
                 RightAppliesTo => undef,
                 RightName => undef,
                 PrincipalId => undef,
                 PrincipalType => undef,
                 @_ );

    #if we haven't done the search yet, do it now.
    $self->_DoSearch();

    if ($self->{'as_hash'}->{ $args{'RightScope'} . "-" .
			      $args{'RightAppliesTo'} . "-" . 
			      $args{'RightName'} . "-" .
			      $args{'PrincipalId'} . "-" .
			      $args{'PrincipalType'}
                            } == 1) {
	return(1);
    }
    else {
	return(undef);
    }
}

# }}}
1;
