#$Header$

package RT::KeywordSelect;

use strict;
use vars qw(@ISA);
use RT::Record;
use RT::Keyword;

@ISA = qw(RT::Record);

# {{{ POD
=head1 NAME

 RT::KeywordSelect - Manipulate an RT::KeywordSelect record

=head1 SYNOPSIS

  use RT::KeywordSelect;

  my $keyword_select = RT::KeywordSelect->new($CurrentUser);
  $keyword_select->Create(
    Keyword     => 20,
    ObjectType => 'Ticket',
    Name       => 'Choices'
  );

  my $keyword_select = RT::KeywordSelect->new($CurrentUser);
  $keyword_select->Create(
    Name        => 'Choices',			  
    Keyword     => 20,
    ObjectType  => 'Ticket',
    ObjectField => 'Queue',
    ObjectValue => 1,
    Single      => 1,
    Depth => 4,
  );

=head1 DESCRIPTION

An B<RT::KeywordSelect> object is a link between a Keyword and a object
type (one of: Ticket), titled by the I<Name> field of the B<RT::Keyword> such
that:

=over 4

=item Object display will contain a field, titled with the I<Name> field and
  showing any descendent keywords which are related to this object via the
  B<RT::ObjectKeywords> table.

=item Object creation for this object will contain a field titled with the
  I<Name> field and containing the descendents of the B<RT::Keyword> as
  choices.  If the I<Single> field of this B<RT::KeywordSelect> is true, each
  object must be associated (via an B<RT::ObjectKeywords> record) to a single
  descendent.  If the I<Single> field is false, each object may be connect to
  zero, one, or many descendents.

=item Searches for this object type will contain a selection field titled with
  the I<Name> field and containing the descendents of the B<RT::Keyword> as
  choices.

=item If I<ObjectField> is defined (one of: Queue), all of the above apply only
  when the value of I<ObjectField> (Queue) in B<ObjectType> (Ticket) matches
  I<ObjectValue>.

=back

=head1 METHODS

=over 4

=item new CURRENT_USER

Takes a single argument, an RT::CurrentUser object.  Instantiates a new
(uncreated) RT::KeywordSelect object.

=cut
# }}}

# {{{ sub _Init
sub _Init {
    my $self = shift;
    $self->{'table'} = "KeywordSelects";
    $self->SUPER::_Init(@_);
}
# }}}

# {{{ sub _Accessible
sub _Accessible {
    my $self = shift;
    my %Cols = (
		Name => 'read/write',
		Keyword => 'read/write', # link to Keywords.  Can be specified by id
		Single => 'read/write', # bool (described below)

		Depth => 'read/write', #- If non-zero, limits the descendents to this number of levels deep.
		ObjectType  => 'read/write', # currently only C<Ticket>
		ObjectField => 'read/write', #optional, currently only C<Queue>
		ObjectValue => 'read/write', #constrains KeywordSelect function to when B<ObjectType>.I<ObjectField> equals I<ObjectValue>
		Disabled => 'read/write'
	       );
    return($self->SUPER::_Accessible(@_, %Cols));  
}
# }}}

# {{{ sub LoadByName

=head2 LoadByName( Name => [NAME], Queue => [QUEUE_ID])
.  Takes a queue id and a keyword select name. 
    tries to load the keyword select for that queue. if that fails, it tries to load it
    without a queue specified.

=cut


sub LoadByName {
    my $self = shift;
    my %args = ( Name => undef,
		 Queue => undef,
		 @_
	       );
    if ($args{'Queue'}) {
	#Try to get the keyword select for this queue
	$self->LoadByCols( Name => $args{'Name'}, 
			   ObjectType => 'Ticket', 
			   ObjectField => 'Queue', 
			   ObjectValue => $args{'Queue'});
    }	
    unless ($self->Id) { #if that failed to load an object
	#Try to get the keyword select of that name that's global
	$self->LoadByCols( Name => $args{'Name'}, 
			   ObjectType => 'Ticket', 
			   ObjectField => 'Queue', 
			   ObjectValue => '0');
    }
    
    return($self->Id);
    
}

# }}}

# {{{ sub Create
=item Create KEY => VALUE, ...

Takes a list of key/value pairs and creates a the object.  Returns the id of
the newly created record, or false if there was an error.

Keys are:

Keyword - link to Keywords.  Can be specified by id.
Name - A name for this KeywordSelect
Single - bool (described above)
Depth - If non-zero, limits the descendents to this number of levels deep.
ObjectType - currently only C<Ticket>
ObjectField - optional, currently only C<Queue>
ObjectValue - constrains KeywordSelect function to when B<ObjectType>.I<ObjectField> equals I<ObjectValue>

=cut

sub Create {
    my $self = shift;
    my %args = ( Keyword => undef,
		 Single => 1,
		 Depth => 0,
		 Name => undef,
		 ObjectType => undef,
		 ObjectField => undef,
		 ObjectValue => undef,
		 @_);

    #If we're talking about a keyword select based on a ticket's 'Queue' field
    if  ( ($args{'ObjectField'} eq 'Queue') and
	  ($args{'ObjectType'} eq 'Ticket')) {
	
	#If we're talking about a keywordselect for all queues
	if ($args{'ObjectValue'} == 0) {
	    unless( $self->CurrentUserHasSystemRight('AdminKeywordSelects')) {
		return (0, 'Permission denied');
	    }
	}  
	#otherwise, we're talking about a keywordselect for a specific queue
	else {
	    unless ($self->CurrentUserHasQueueRight( Right => 'AdminKeywordSelects',
						     Queue => $args{'ObjectValue'})) {
		return (0, 'Permission denied');
	    }
	}
    }
    else {
	return (0, "Can't create a KeywordSelect for that object/field combo");
    }

    my $Keyword = new RT::Keyword($self->CurrentUser);

    if ( $args{'Keyword'} && $args{'Keyword'} !~ /^\d+$/ ) {
	$Keyword->LoadByPath($args{'Keyword'});
    }	
    else {
	$Keyword->Load($args{'Keyword'});
    }

    unless ($Keyword->Id) {
	$RT::Logger->debug("Keyword ".$args{'Keyword'} ." not found\n");
	return(0, 'Keyword not found');
    }
    
    $args{'Name'} = $Keyword->Name if  (!$args{'Name'});
    
    my $val = $self->SUPER::Create( Name => $args{'Name'},
				    Keyword => $Keyword->Id,
				    Single => $args{'Single'},
				    Depth => $args{'Depth'},
				    ObjectType => $args{'ObjectType'},
				    ObjectField => $args{'ObjectField'},
				    ObjectValue => $args{'ObjectValue'});
    if ($val) {
	return ($val, 'KeywordSelect Created');
    }
    else {
	return (0, 'System error. KeywordSelect not created');
	
    }
}
# }}}

# {{{ sub Delete

sub Delete {
    my $self = shift;
    
    return (0, 'Deleting this object would break referential integrity.');
}

# }}}


# {{{ sub SetDisabled

=head2 Sub SetDisabled

Toggles the KeywordSelect's disabled flag.


=cut 

sub SetDisabled {
    my $self = shift;
    my $value = shift;

    unless ($self->CurrentUserHasRight('AdminKeywordSelects')) {
	return (0, "Permission denied");
    }
    return($self->_Set(Field => 'Disabled', Value => $value));
}

# }}}

# {{{ sub KeywordObj

=item KeywordObj

Returns the B<RT::Keyword> referenced by the I<Keyword> field.

=cut

sub KeywordObj {
    my $self = shift;

    my $Keyword = new RT::Keyword($self->CurrentUser);
    $Keyword->Load( $self->Keyword ); #or ?
    return($Keyword);
} 
# }}}

# {{{ sub Object

=item Object

Returns the object (currently only RT::Queue) specified by ObjectField and ObjectValue.

=cut

sub Object {
    my $self = shift;
    if ( $self->ObjectField eq 'Queue' ) {
	my $Queue = new RT::Queue($self->CurrentUser);
	$Queue->Load( $self->ObjectValue );
	return ($Queue);
    } else {
	$RT::Logger->error("$self trying to load an object value for a non-queue object");
	return (undef);
    }
}

# }}}

# {{{ sub _Set

# does an acl check, then passes off the call
sub _Set {
    my $self = shift;

    unless ($self->CurrentUserHasRight('AdminKeywordSelects')) {
	return (0, "Permission denied");
    }
    
    return ($self->SUPER::_Set(@_));

}

# }}}


# {{{ sub CurrentUserHasQueueRight 

=head2 CurrentUserHasQueueRight ( Queue => QUEUEID, Right => RIGHTNANAME )

Check to see whether the current user has the specified right for the specified queue.

=cut

sub CurrentUserHasQueueRight {
    my $self = shift;
    my %args = (Queue => undef,
		Right => undef,
		@_
		);
    return ($self->HasRight( Right => $args{'Right'},
			     Principal => $self->CurrentUser->UserObj,
			     Queue => $args{'Queue'}));
}

# }}}

# {{{ sub CurrentUserHasSystemRight 

=head2 CurrentUserHasSystemRight RIGHTNAME

Check to see whether the current user has the specified right for the 'system' scope.

=cut

sub CurrentUserHasSystemRight {
    my $self = shift;
    my $right = shift;
    $RT::Logger->debug("$self in hashsysright for right $right\n");
    return ($self->HasRight( Right => $right,
			     System => 1,
			     Principal => $self->CurrentUser->UserObj));
}

# }}}

# {{{ sub CurrentUserHasRight

=item CurrentUserHasRight RIGHT  [QUEUEID]

Takes a rightname as a string. Can take a queue id as a second
optional parameter, which can be useful to a routine like create.
Helper menthod for HasRight. Presets Principal to CurrentUser then 
calls HasRight.

=cut

sub CurrentUserHasRight {
    my $self = shift;
    my $right = shift;
    return ($self->HasRight( Principal => $self->CurrentUser->UserObj,
                             Right => $right,
			   ));
}

# }}}

# {{{ sub HasRight

=item HasRight

Takes a param-hash consisting of "Right" and "Principal"  Principal is 
an RT::User object or an RT::CurrentUser object. "Right" is a textual
Right string that applies to KeywordSelects

=cut

sub HasRight {
    my $self = shift;
    my %args = ( Right => undef,
                 Principal => undef,
		 Queue => undef,
		 System => undef,
                 @_ );

    #If we're explicitly specifying a queue, as we need to do on create
    if ($args{'Queue'}) {
	return ($args{'Principal'}->HasQueueRight(Right => $args{'Right'},
						  Queue => $args{'Queue'}));
    }
    #else if we're specifying to check a system right
    elsif ($args{'System'}) {
        return( $args{'Principal'}->HasSystemRight( $args{'Right'} ));
    }	

    #else if we 're using the object's queue
    elsif (($self->__Value('ObjectField') eq 'Queue') and
	   ($self->__Value('ObjectValue') > 0 )) {
        return ($args{'Principal'}->HasQueueRight(Right => $args{'Right'},
						  Queue => $self->__Value('Queue') )); 
    }
    
    #If the object is system scoped.
    else {
        return( $args{'Principal'}->HasSystemRight( $args{'Right'} ));
    }
}

# }}}

=back

=head1 AUTHORS

Ivan Kohler <ivan-rt@420.am>, Jesse Vincent <jesse@fsck.com>

=head1 BUGS

The ACL system for this object is more byzantine than it should be.  reworking it eventually
would be a good thing.

=head1 SEE ALSO

L<RT::KeywordSelects>, L<RT::Keyword>, L<RT::Keywords>, L<RT::ObjectKeyword>,
L<RT::ObjectKeywords>, L<RT::Record>

=cut

1;

