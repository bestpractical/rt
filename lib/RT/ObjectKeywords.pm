#$Header$

package RT::ObjectKeywords;

use strict;
use vars qw( @ISA );

use RT::EasySearch;
use RT::ObjectKeyword;

@ISA = qw( RT::EasySearch );

sub _Init {
    my $self = shift;
    $self->{'table'} = 'ObjectKeywords';
    $self->{'primary_key'} = 'id';
    return ($self->SUPER::_Init(@_));
}

sub NewItem {
    my $self = shift;
    return (new RT::ObjectKeyword($self->CurrentUser));
}


# {{{ sub LimitToKeywordSelect

=head2 LimitToKeywordSelect

  Takes a B<RT::KeywordSelect> id or Nameas its single argument. limits the returned set of ObjectKeywords
to ObjectKeywords which apply to that ticket

=cut


sub LimitToKeywordSelect {
    my $self = shift;
    my $keywordselect = shift;
    
    if ($keywordselect =~ /^\d+$/) {

	$self->Limit(FIELD => 'KeywordSelect',
		     OPERATOR => '=',
		     ENTRYAGGREGATOR => 'OR',
		     VALUE => "$keywordselect");
    }

    #We're limiting by name. time to be klever
    else {
	my $ks = $self->NewAlias('KeywordSelects');
	$self->Join(ALIAS1 => $ks, FIELD1 => 'id',
		    ALIAS2 => 'main', FIELD2 => 'KeywordSelect');
	
	$self->Limit( ALIAS => "$ks",
		       FIELD => 'Name',
		       VALUE => "$keywordselect",
		       OPERATOR => "=",
		       ENTRYAGGREGATOR => "OR");

	$self->Limit ( ALIAS => "$ks",
		       FIELD => 'ObjectType',
		       VALUE => 'Ticket',
		       OPERATOR => '=',
		     );

	$self->Limit ( ALIAS => "$ks",
		       FIELD => 'ObjectField',
		       VALUE => 'Queue',
		       OPERATOR => '=',
		     );


	# TODO +++ we need to be able to limit the returned
	# keywordselects to ones that apply only to this queue
	#	$self->Limit( ALIAS => "$ks",
	#		       FIELD => 'ObjectValue',
	#		       VALUE => $self->QueueObj->Id,
	#		       OPERATOR => "=",
	#		       ENTRYAGGREGATOR => "OR");	

    }



}

# }}}

# {{{ LimitToTicket

=head2 LimitToTicket TICKET_ID

  Takes an B<RT::Ticket> id as its single argument. limits the returned set of ObjectKeywords
to ObjectKeywords which apply to that ticket

=cut

sub LimitToTicket {
    my $self = shift;
    my $ticket = shift;
    $self->Limit(FIELD => 'ObjectId',
		 OPERATOR => '=',
		 ENTRYAGGREGATOR => 'OR',
		 VALUE => "$ticket");

    $self->Limit(FIELD => 'ObjectType',
		 OPERATOR => '=',
		 ENTRYAGGREGATOR => 'OR',
		 VALUE => "Ticket");
    
}

# }}}

# {{{ sub _DoSearch
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
# }}}

# {{{ sub _BuildHash
#Build a hash of this ACL's entries.
sub _BuildHash {
    my $self = shift;

    #   $RT::Logger->debug("Now in ".$self."->_BuildHash\n");
    while (my $entry = $self->Next) {

	my $hashkey = $entry->Keyword;
        $self->{'as_hash'}->{"$hashkey"} =1;
    }

}
# }}}

# {{{ HasEntry

=head2 HasEntry KEYWORD_ID
  
  Takes a keyword id and returns true if this ObjectKeywords object has an entry for that
keyword.  Returns undef otherwise.

=cut

sub HasEntry {

    my $self = shift;
    my $keyword = shift;


    #if we haven't done the search yet, do it now.
    $self->_DoSearch();
    
    #    $RT::Logger->debug("Now in ".$self."->HasEntry\n");
    
    $RT::Logger->debug("Trying to find as_hash-> ".
		       $keyword ."..."
		      );
    
    if ($self->{'as_hash'}->{ $keyword } == 1) {
	$RT::Logger->debug("found.\n");
	return(1);
    }
    else {
	$RT::Logger->debug("not found.\n");
	return(undef);
    }
}

# }}}


# {{{ sub RelativePaths

=head2 RelativePaths

# Return a (reference to a) list of KeywordRelativePaths

=cut

sub RelativePaths  {
    my $self = shift;

    my @list;

    # Here $key is a RT::ObjectKeyword
    while (my $key=$self->Next()) {
	push(@list, $key->KeywordRelativePath);
    }
    return(\@list);
}
# }}}

# {{{ sub RelativePathsAsString

=head2 RelativePathsAsString

# Returns the RT::ObjectKeywords->RelativePaths as a comma seperated string

=cut

sub RelativePathsAsString {
    my $self = shift;
    return(join(", ",@{$self->KeywordRelativePaths}));
}
# }}}



1;

