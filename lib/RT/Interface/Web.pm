## $Header$
## Copyright 2000 Jesse Vincent <jesse@fsck.com> & Tobias Brox <tobix@fsck.com>
## Request Tracker is Copyright 1996-2000 Jesse Vincent <jesse@fsck.com>

## This is a library of static subs to be used by the Mason web
## interface to RT

package RT::Interface::Web;

# {{{ sub NewParser

=head2 NewParser

  Returns a new Mason::Parser object. Takes a param hash of things 
  that get passed to HTML::Mason::Parser. Currently hard coded to only
  take the parameter 'allow_globals'.

=cut

sub NewParser {
    my %args = ( allow_globals => undef,
                 @_ );

    my $parser = new HTML::Mason::Parser( 
                        default_escape_flags=>'h',
                        allow_globals => $args{'allow_globals'}
					);
    return($parser);
}

# }}}

# {{{ sub NewInterp

=head2 NewInterp 

  Takes a paremeter hash. Needs a param called 'parser' which is a reference
  to an HTML::Mason::Parser.
  returns a new Mason::Interp object

=cut

sub NewInterp {
    my %params = ( allow_recursive_autohandlers => 1,
                   comp_root => "$RT::MasonComponentRoot",
                   data_dir => "$RT::MasonDataDir",
                   parser => undef,
                   @_);
    
    #We allow recursive autohandlers to allow for RT auth.

    use HTML::Mason::Interp;
    my $interp = new HTML::Mason::Interp(%params);
    
}

# }}}

# {{{ sub NewApacheHandler 

=head2 NewApacheHandler

  Takes a Mason::Interp object
  Returns a new Mason::ApacheHandler object

=cut

sub NewApacheHandler {
    my $interp=shift;
    my $ah = new HTML::Mason::ApacheHandler (interp=>$interp);
    return($ah);
}

# }}}

package HTML::Mason::Commands;

# {{{ sub Abort
# Error - calls Error and aborts
sub Abort {
    $m->comp("/Elements/Error" , Why => shift);
    $m->abort;
}
# }}}

# {{{ sub LoadTicket - loads a ticket

sub LoadTicket {
    my $id=shift;
   
    unless ($id) {
      Abort("No ticket specified");
    }

   

    my $Ticket = RT::Ticket->new($session{'CurrentUser'});
    $Ticket->Load($id);
    unless ($Ticket->id){
      Abort("Could not load ticket $id");
    }
    return $Ticket;
}

# }}}


# {{{ sub ProcessSimpleActions


sub ProcessSimpleActions {
    my %args=( ARGS => undef,
	       Ticket => undef,
	       Actions => undef,
	       @_);

    my ($Action);	

    my $Ticket = $args{'Ticket'};
    my @Actions = $$args{'Actions'};
 
    if (defined $args{ARGS}->{'Action'}) {
	if ($args{ARGS}->{'Action'} =~ /^(Steal|Kill|Take|SetTold)$/) {
	  $action = $1;
	my ($res, $msg)=$Ticket->$action();
	push(@Actions, $msg);
        }
    }
}

# }}}

# {{{ sub ProcessOwnerChanges

sub ProcessOwnerChanges {
    my %args=@_;
    if ($args{ARGS}->{'SetOwner'}
        and ($args{ARGS}->{'SetOwner'} ne $args{Ticket}->OwnerObj->Id())) {
	my ($Transaction, $Description)=$args{Ticket}->SetOwner($args{ARGS}->{'SetOwner'});
	push(@{$args{Actions}}, $Description);
    }
}
# }}}

# {{{ sub ProcessUpdateMessage
sub ProcessUpdateMessage {
    my %args=@_;

    #Make the update content have no 'weird' newlines in it
    if ($args{ARGS}->{'UpdateContent'}) {
	my @UpdateContent = split(/(\r\n|\n|\r)/,$args{ARGS}->{'UpdateContent'});
	my $Message = MIME::Entity->build 
	    ( Subject => $args{ARGS}->{'UpdateSubject'} || "",
	    	      Data => \@UpdateContent);
	
	## TODO: Implement public comments
	if ($args{ARGS}->{'UpdateType'} =~ /^(private|public)$/) {
	    my ($Transaction, $Description) = $args{Ticket}->Comment
		( CcMessageTo => $args{ARGS}->{'UpdateCc'},
		  BccMessageTo => $args{ARGS}->{'UpdateBcc'},
		  MIMEObj => $Message,
		  TimeTaken => $args{ARGS}->{'UpdateTimeWorked'});
	    push(@{$args{Actions}}, $Description);
	}
	elsif ($args{ARGS}->{'UpdateType'} eq 'response') {
	    my ($Transaction, $Description) = $args{Ticket}->Correspond
		( CcMessageTo => $args{ARGS}->{'UpdateCc'},
		  BccMessageTo => $args{ARGS}->{'UpdateBcc'},
		  MIMEObj => $Message,
		  TimeTaken => $args{ARGS}->{'UpdateTimeWorked'});
	    push(@{$args{Actions}}, $Description);
	}
    }
}
# }}}

# {{{ sub ProcessStatusChanges 

sub ProcessStatusChanges {
    my %args=( Ticket => undef,
	       ARGS => undef,
               Actions => undef,
               @_
	      );
    if ($args{ARGS}->{'SetStatus'} and ($args{ARGS}->{'SetStatus'} ne $args{Ticket}->Status())) {
	my ($Transaction, $Description)=$args{Ticket}->SetStatus($args{ARGS}->{'SetStatus'});
	push(@{$args{Actions}}, $Description);
    }
}

# }}}

# {{{ sub ProcessSearchQuery

=head2 ProcessSearchQuery

  Takes a form such as the one filled out in webrt/Search/Elements/PickRestriction and turns it into something that RT::Tickets can understand.

TODO Doc exactly what comes in the paramhash


=cut

sub ProcessSearchQuery {
    my %args=@_;

    ## TODO: The only parameter here is %ARGS.  Maybe it would be
    ## cleaner to load this parameter as $ARGS, and use $ARGS->{...}
    ## instead of $args{ARGS}->{...} ? :)
    
    #Searches are sticky.
    if (defined $session{'tickets'}) {
	# Reset the old search
	$session{'tickets'}->GotoFirstItem;
    } else {
	# Init a new search
	$session{'tickets'} = RT::Tickets->new($session{'CurrentUser'});
    }

    # {{{ Goto next/prev page
    if ($args{ARGS}->{'GotoPage'} eq 'Next') {
	$session{'tickets'}->NextPage;
    }
    elsif ($args{ARGS}->{'GotoPage'} eq 'Prev') {
	$session{'tickets'}->PrevPage;
    }
    # }}}

    # {{{ Deal with limiting the search
    if ($args{ARGS}->{'TicketsSortBy'}) {
	$session{'tickets_sort_by'} = $args{ARGS}->{'TicketsSortBy'};
	$session{'tickets_sort_order'} = $args{ARGS}->{'TicketsSortOrder'};
	$session{'tickets'}->OrderBy ( FIELD => $args{ARGS}->{'TicketsSortBy'},
				       ORDER => $args{ARGS}->{'TicketsSortOrder'});
    }
    # }}}
    
    # {{{ Set the query limit
    if (defined $args{ARGS}->{'RowsPerPage'}) {
	$RT::Logger->debug("limiting to ". 
			   $args{ARGS}->{'RowsPerPage'} . 
			   " rows");

	$session{'tickets_rows_per_page'} = $args{ARGS}->{'RowsPerPage'};
	$session{'tickets'}->RowsPerPage($args{ARGS}->{'RowsPerPage'});
    }
    
    # }}}
    # {{{ Limit owner
    if ($args{ARGS}->{'ValueOfOwner'} ne '' ) {
	$session{'tickets'}->LimitOwner(					
					VALUE => $args{ARGS}->{'ValueOfOwner'},
					OPERATOR => $args{ARGS}->{'OwnerOp'}
				       );
    }

    # }}}
    # {{{ Limit requestor email
    #TODO this doesn't work
    
    if ($args{ARGS}->{'ValueOfRequestor'} ne '') {
	my $alias=$session{'tickets'}->LimitRequestor (
						       VALUE => $args{ARGS}->{'ValueOfRequestor'},
						       OPERATOR =>  $args{ARGS}->{'RequestorOp'},
						      );
	
    }
    # }}}
    # {{{ Limit Queue
    if ($args{ARGS}->{'ValueOfQueue'} ne '') {
	$session{'tickets'}->LimitQueue(
				    VALUE => $args{ARGS}->{'ValueOfQueue'},
				    OPERATOR => $args{ARGS}->{'QueueOp'});
    }
    # }}}
    # {{{ Limit Status
    if ($args{ARGS}->{'ValueOfStatus'} ne '') {
	if ( ref($args{ARGS}->{'ValueOfStatus'}) ) {
	    foreach my $value ( @{ $args{ARGS}->{'ValueOfStatus'} } ) {
		$session{'tickets'}->LimitStatus (
						  VALUE => $value,
						  OPERATOR =>  $args{ARGS}->{'StatusOp'},
						 );
	    }
	} else {
	    $session{'tickets'}->LimitStatus (
					      VALUE => $args{ARGS}->{'ValueOfStatus'},
					      OPERATOR =>  $args{ARGS}->{'StatusOp'},
					     );
	}
	
    }

# }}}
    # {{{ Limit Subject
    if ($args{ARGS}->{'ValueOfSubject'} ne '') {
	$session{'tickets'}->LimitSubject(
					  VALUE =>  $args{ARGS}->{'ValueOfSubject'},
					  OPERATOR => $args{ARGS}->{'SubjectOp'},
					 );
    }

    # }}}    
    # {{{ Limit Dates
    if ($args{ARGS}->{'ValueOfDate'} ne '') {
	
	my $date = ParseDateToISO($args{ARGS}->{'ValueOfDate'});
	$args{ARGS}->{'DateType'} =~ s/_Date$//;

	$session{'tickets'}->LimitDate(
				       FIELD => $args{ARGS}->{'DateType'},
				       VALUE =>  $date,
				       OPERATOR => $args{ARGS}->{'DateOp'},
				      );
    }

    # }}}    
    # {{{ Limit Content
    if ($args{ARGS}->{'ValueOfContent'} ne '') {
	$session{'tickets'}->Limit(				
				   VALUE =>  $args{ARGS}->{'ValueOfContent'},
				   OPERATOR => $args{ARGS}->{'ContentOp'},
				  );
    }

    # }}}   
    # {{{ Limit KeywordSelects
    foreach my $KeywordSelectId (
	map { /^KeywordSelect(\d+)$/; $1 }
        grep { /^KeywordSelect(\d+)$/; }
          keys %{$args{ARGS}}
    ) {
      my $form = $args{ARGS}->{"KeywordSelect$KeywordSelectId"};
      my $oper = $args{ARGS}->{"KeywordSelectOp$KeywordSelectId"};
      foreach my $KeywordId ( ref($form) ? @{ $form } : ( $form ) ) {
	  if ($KeywordId) {
	      $session{'tickets'}->LimitKeyword(
						KEYWORDSELECT => $KeywordSelectId,
						OPERATOR => $oper,
						KEYWORD => $KeywordId,
					       );
	  }
      }
      
    }

    # }}}

}

# }}}


# {{{ sub ParseDateToISO

=head2 ParseDateToISO

Takes a date in an arbitrary format.
Returns an ISO date and time in GMT

=cut

sub ParseDateToISO {
    my $date = shift;

    use Date::Manip;
    my $parsed_date = Date::Manip::ParseDate($date);
    if ($parsed_date) {
	my $unixdate = Date::Manip::UnixDate($parsed_date, "%s");
	$RT::Logger->debug("Parsed date is $parsed_date (localtime)");
	my $date_obj = new RT::Date($CurrentUser);
	$date_obj->Set( Format => 'unix',
			Value => $unixdate
			      );
	return ($date_obj->ISO);
    }
    #if we couldn't parse the date...
    else {
	return(undef);
    }
}

# }}}


# {{{ sub Config 
# TODO: This might eventually read the cookies, user configuration
# information from the DB, queue configuration information from the
# DB, etc.

sub Config {
  my $args=shift;
  my $key=shift;
  return $args->{$key} || $RT::WebOptions{$key};
}

# }}}

# {{{ sub ProcessACLChanges

sub ProcessACLChanges {
    my $ACLref= shift;
    my $ARGSref = shift;
  
    my @CheckACL = @$ACLref;
    my %ARGS = %$ARGSref;
    
    my ($ACL, @results);
    foreach $ACL (@CheckACL) {
	my ($Principal);
	
	# Parse out what we're really talking about. 
	# it would be good to make this code generic enough to apply
	# to system rights too
	
	if ($ACL =~ /^(.*?)-(\d+)-(.*?)-(\d+)/) {
	    my $PrincipalType = $1;
	    my $PrincipalId = $2;
	    my $Scope = $3;
	    my $AppliesTo = $4;
	    
	    # {{{ Create an object called Principal
	    # so we can do rights operations
	    
	    if ($PrincipalType  eq 'User' ) {
		$Principal = new RT::User($session{'CurrentUser'});
	    } elsif ($PrincipalType eq 'Group') {
		$Principal = new RT::Group($session{'CurrentUser'});
	    } else {
		Abort("$PrincipalType unknown principal type")
	    }	
	    
	    $Principal->Load($PrincipalId) ||
	      Abort("$PrincipalType $PrincipalId couldn't be loaded");
	    
	    # }}}
	    
	    # {{{ load up an RT::ACL object with the same current vals of this ACL
	    
	    my $CurrentACL = new RT::ACL($session{'CurrentUser'});
	    if ($Scope eq 'Queue') {
		$CurrentACL->LimitToQueue($AppliesTo);
	    } elsif ($Scope eq 'System') {
		$CurrentACL->LimitToSystem();
	    }
	    
	    $CurrentACL->LimitPrincipalToType($PrincipalType);
	    $CurrentACL->LimitPrincipalToId($PrincipalId);
	    
	    # }}}
	    
	    # {{{ Get the values of the select we're working with 
	    # into an array. it will contain all the new rights that have 
	    # been granted
	    
	    
	    #Hack to turn the ACL returned into an array

	    my @rights = ref($ARGS{"GrantACE-$ACL"}) eq 'ARRAY' ?
	      @{$ARGS{"GrantACE-$ACL"}} : ($ARGS{"GrantACE-$ACL"});
	    
	    my @RevokeACE = ref($ARGS{"RevokeACE"}) eq 'ARRAY' ?
	      @{$ARGS{"RevokeACE"}} : ($ARGS{"RevokeACE"});
	    
	    # }}}
	    
	    # {{{ Add any rights we need. at the same time, build up
	    # a hash of what rights have been selected 
	    
	    foreach my $right (@rights) {
		next unless ($right);
		
		#if the right that's been selected wasn't there before, add it.
		unless ($CurrentACL->HasEntry(RightScope => "$Scope",
					      RightName => "$right",
					      RightAppliesTo => "$AppliesTo", 
					      PrincipalType => $PrincipalType ,
					      PrincipalId => $Principal->Id )) {
		    
		    #Add new entry to list of rights.
		    if ($Scope eq 'Queue') {
			my $Queue = new RT::Queue($session{'CurrentUser'});
			$Queue->Load($AppliesTo);
			unless ($Queue->id) {
			    Abort("Couldn't find a queue called $AppliesTo");
			}

			my ($val, $msg) = 
			  $Principal->GrantQueueRight( RightAppliesTo => $Queue->id,
						       RightName => "$right" );
			
			if ($val) { 
			    push (@results, "Granted right $right to ".
				  $Principal->Name." for queue " . 
				  $Queue->Name);
			}
			else {
			    push (@results, $msg);
			}
		    }
		    elsif ($Scope eq 'System') {
			my ($val, $msg)	=
			  $Principal->GrantSystemRight(RightAppliesTo => $AppliesTo,
						       RightName => "$right" );
			if ($val) {
			    push (@results, "Granted system right '$right' to ".
				  $Principal->Name);
			}
			else {
			    push (@results, $msg);
			    }	
		    }
		}
	    }
	    # }}}
	    
	    # {{{ remove any rights that have been deleted
	    foreach my $aceid (@RevokeACE) {
		next unless ($aceid);
		my $right = new RT::ACE($session{'CurrentUser'});
		$right->Load($aceid);
	 	next unless ($right->id);
	
		my $phrase = "Revoked ".$right->PrincipalType." ".
		  $right->PrincipalObj->Name . "'s right to ". $right->RightName;
		
		if ($right->RightScope eq 'System') {
		    $phrase .= ' across all queues.';
		}
		else {
		    $phrase .= ' for the queue '.$right->AppliesToObj->Name. '.';
		}
		my ($val, $msg )= $right->Delete();
		if ($val) {
		    push (@results, $phrase);
		}
		else {
		    push (@results, $msg);
		}	
	    }

	    # }}}
	}
    }
    
    return (@results);
  }


# }}}

# {{{ sub UpdateRecordObj

=head2 UpdateRecordObj ( ARGSRef => \%ARGS, Object => RT::Record, AttributesRef => \@attribs)

@attribs is a list of ticket fields to check and update if they differ from the  B<Object>'s current values. ARGSRef is a ref to HTML::Mason's %ARGS.

Returns an array of success/failure messages

=cut

sub UpdateRecordObject {
  my %args = ( 
	      ARGSRef => undef,
	      AttributesRef => undef,
	      Object => undef,
	      @_
	     );
  
  my (@results);

  my $object = $args{'Object'};
  my $attributes = $args{'AttributesRef'};
  my $ARGSRef = $args{'ARGSRef'};
  
  foreach $attribute (@$attributes) {
    $RT::Logger->debug("Looking at attribute $attribute-");#.$object->$attribute()."\n");
    if ((defined $ARGSRef->{"$attribute"}) and 
	($ARGSRef->{"$attribute"} ne $object->$attribute())) {

      $ARGSRef->{"$attribute"} =~ s/\r\n/\n/gs;
      
      my $method = "Set$attribute";
      my ($code, $msg) = $object->$method($ARGSRef->{"$attribute"});
      push @results, "$attribute: $msg";
    }
    
  }
  return (@results);
}
# }}}

# {{{ sub ProcessTicketBasics

=head2 ProcessTicketBasics ( TicketObj => $Ticket, ARGSRef => \%ARGS );

Returns an array of results messages.

=cut

    
sub ProcessTicketBasics {
  
  my %args = ( TicketObj => undef,
	       ARGSRef => undef,
	       @_
	     );
  
  my $TicketObj = $args{'TicketObj'};
  my $ARGSRef = $args{'ARGSRef'};

  # {{{ Set basic fields 
  my @attribs = qw(
		   Queue 
		   Owner 
		   Subject 
		   FinalPriority 
		   Priority 
		   Status 
		   TimeWorked  
		   TimeLeft 
        );
  
  my @results = UpdateRecordObject( AttributesRef => \@attribs, 
				    Object => $TicketObj, 
				    ARGSRef => $ARGSRef);


  # }}}
  
  return (@results);
}

# }}}

# {{{ sub ProcessTicketWatchers

=head2 ProcessTicketWatchers ( TicketObj => $Ticket, ARGSRef => \%ARGS );

Returns an array of results messages.

=cut

sub ProcessTicketWatchers {
    my %args = ( TicketObj => undef,
		 ARGSRef => undef,
		 @_
	       );
    my (@results);
    
    my $Ticket = $args{'TicketObj'};
    my $ARGSRef = $args{'ARGSRef'};
    
    # {{{ Munge watchers
    
    foreach my $key (keys %$ARGSRef) {
      # Delete deletable watchers
      if (($key =~ /^DelWatcher(\d*)$/) and
	  ($ARGSRef->{$key})) {
	my ($code, $msg) = $Ticket->DeleteWatcher($1);
	push @results, $msg;
      }
      
      # Add new watchers
      elsif ( ($ARGSRef->{$key} =~ /^(AdminCc|Cc|Requestor)$/) and
	      ($key =~ /^WatcherTypeUser(\d*)$/) ) {
	#They're in this order because otherwise $1 gets clobbered :/
	my ($code, $msg) = 
	  $Ticket->AddWatcher(Type => $ARGSRef->{$key}, Owner => $1);
	push @results, $msg;
      }
    }
    

    # }}}

    return (@results);
}
# }}}

# {{{ sub ProcessTicketDates

=head2 ProcessTicketDates ( TicketObj => $Ticket, ARGSRef => \%ARGS );

Returns an array of results messages.

=cut

sub ProcessTicketDates {
    my %args = ( TicketObj => undef,
		 ARGSRef => undef,
		 @_
	       );
    
    my $Ticket = $args{'TicketObj'};
    my $ARGSRef = $args{'ARGSRef'};
    
    my (@results);
    
    # {{{ Set date fields
    my @date_fields = qw(
			 Told  
			 Resolved  
			 Starts  
			 Started  
			 Due  
			);
    #Run through each field in this list. update the value if apropriate
    foreach $field (@date_fields) {
      my ($code, $msg);
      
    my $DateObj = RT::Date->new($session{'CurrentUser'});
      #If it's something other than just whitespace
      if ($ARGSRef->{$field.'_Date'} ne '') {
	$DateObj->Set(Format => 'unknown',
		      Value => $ARGSRef->{$field. '_Date'});
	my $obj = $field."Obj";
	if ( (defined $DateObj->Unix) and 
	     ($DateObj->Unix ne $Ticket->$obj()->Unix()) ) {
	  my $method = "Set$field";
	  my ($code, $msg) = $Ticket->$method($DateObj->ISO);
	  push @results, "$msg";
	}
      }
    }

    return (@results);
}
# }}}

# {{{ sub ProcessTicketLinks

=head2 ProcessTicketLinks ( TicketObj => $Ticket, ARGSRef => \%ARGS );

Returns an array of results messages.

=cut

sub ProcessTicketLinks {
    my %args = ( TicketObj => undef,
		 ARGSRef => undef,
		 @_
	       );
    
    my $Ticket = $args{'TicketObj'};
    my $ARGSRef = $args{'ARGSRef'};
    
    my (@results);
    
    # Delete links that are gone gone gone.
    foreach my $arg (keys %$ARGSRef) {
      if ($arg =~ /DeleteLink-(.*?)-(DependsOn|MemberOf|RefersTo)-(.*)$/) {
	my $base = $1;
	my $type = $2;
	my $target = $3;
	
	push @results, "Trying to delete: Base: $base Target: $target  Type $type";
	my ($val, $msg) = $Ticket->DeleteLink(Base => $base,
					      Type => $type,
					      Target => $target);
	
	push @results, $msg;
	
	
      }	
      
    }
    
    
    my @linktypes = qw( DependsOn MemberOf RefersTo );
    
    foreach my $linktype (@linktypes) {
      
      for my $luri (split (/ /,$ARGSRef->{$Ticket->Id."-$linktype"})) {
	my ($val, $msg) = $Ticket->AddLink( Target => $luri,
					    Type => $linktype);
	push @results, $msg;
      }
      
      for my $luri (split (/ /,$ARGSRef->{"$linktype-".$Ticket->Id})) {
	my ($val, $msg) = $Ticket->AddLink( Base => $luri,
					    Type => $linktype);
	
	push @results, $msg;
      }
    }
    
    #Merge if we need to
    if ($ARGSRef->{$Ticket->Id."-MergeInto"}) {
      my ($val, $msg) = $Ticket->MergeInto($ARGSRef->{$Ticket->Id."-MergeInto"});
      push @results, $msg;
    }
    
    return (@results);
}


# }}}

# {{{ sub ProcessTicketObjectKeywords

=head2 ProcessTicketObjectKeywords ( TicketObj => $Ticket, ARGSRef => \%ARGS );

Returns an array of results messages.

=cut

sub ProcessTicketObjectKeywords {
  my %args = ( TicketObj => undef,
	       ARGSRef => undef,
	       @_
	     );
  
  my $TicketObj = $args{'TicketObj'};
  my $ARGSRef = $args{'ARGSRef'};

  my (@results);
  
  # {{{ set ObjectKeywords.
  
  my $KeywordSelects = $TicketObj->QueueObj->KeywordSelects;
  
  # iterate through all the keyword selects for this queue
  
  while ( my $KeywordSelect = $KeywordSelects->Next ) {
    # {{{ do some setup
    
    # if we have KeywordSelectMagic for this keywordselect:
    next unless defined $ARGSRef->{'KeywordSelectMagic'. $KeywordSelect->id};
    
    
    # Lets get a hash of the possible values to work with
    my $value = $ARGSRef->{'KeywordSelect'. $KeywordSelect->id} || [];
    
    #lets get all those values in a hash. regardless of # of entries
    my %values = map { $_=>1 } ref($value) ? @{$value} : ( $value );
    
    # Load up the ObjectKeywords for this KeywordSelect for this ticket
    my $ObjectKeys = $TicketObj->KeywordsObj($KeywordSelect->id);

    # }}}
    # {{{ add new keywords
    my ($key);
    foreach $key (keys %values) {
	#unless the ticket has that keyword for that keyword select,
      unless ($ObjectKeys->HasEntry($key)) {
	#Add the keyword
	my ($result, $msg) = 
	  $TicketObj->AddKeyword( Keyword => $key,
				  KeywordSelect => $KeywordSelect->id);
	push(@results, $msg);
      }
    }
    
    # }}}
    # {{{ Delete unused keywords
    # Iterate through $ObjectKeys
    while (my $TicketKey = $ObjectKeys->Next) {
      
      # if the hash defined above doesn\'t contain the keyword mentioned,
      unless ($values{$TicketKey->Keyword}) {
	#I'd really love to just call $keyword->Delete, but then 
	# we wouldn't get a transaction recorded
	my ($result, $msg) = $TicketObj->DeleteKeyword(Keyword => $TicketKey->Keyword,
						       KeywordSelect => $KeywordSelect->id);
	push(@results, $msg);
      }
    }
    
    # }}}
  }
  
  # }}}

  return (@results);
}

# }}}

1;
