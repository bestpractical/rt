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
                   comp_root => [ [local => $RT::MasonLocalComponentRoot] , 
 			 	  [standard => $RT::MasonComponentRoot] ] , 
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
    my $ah = new HTML::Mason::ApacheHandler ( interp=>$interp);
    return($ah);
}

# }}}

package HTML::Mason::Commands;
# {{{ sub Abort
# Error - calls Error and aborts
sub Abort {

    SetContentType('text/html');
    $m->comp("/Elements/Error" , Why => shift);
    $m->abort;
}
# }}}

# sub CreateTicket 

=head2 CreateTicket ARGS

Create a new ticket, using Mason's %ARGS.  returns @results.
=cut

sub CreateTicket {
    my %ARGS = (@_);

    my (@Actions);

    my $Ticket = new RT::Ticket($session{'CurrentUser'});

    my $Queue = new RT::Queue($session{'CurrentUser'});	
    unless ($Queue->Load($ARGS{'Queue'})) {
	Abort('Queue not found');
    }
    
    unless ($Queue->CurrentUserHasRight('CreateTicket')) {
	Abort('You have no permission to create tickets in that queue.');
    }
   
    my $due = new RT::Date($session{'CurrentUser'});
    $due->Set(Format => 'unknown', Value => $ARGS{'Due'});
    my $starts = new RT::Date($session{'CurrentUser'});
    $starts->Set(Format => 'unknown', Value => $ARGS{'Starts'});
    
 
    my @Requestors = split(/,/,$ARGS{'Requestors'});
    my @Cc = split(/,/,$ARGS{'Cc'});
    my @AdminCc = split(/,/,$ARGS{'AdminCc'});
    
    my $MIMEObj = MakeMIMEEntity( Subject => $ARGS{'Subject'},
				  From => $ARGS{'From'},
				  Cc => $ARGS{'Cc'},
				  Body => $ARGS{'Content'},
				  AttachmentFieldName => 'Attach');
 
				  
    my %create_args = ( 
		       Queue => $ARGS{Queue},
		       Owner=>$ARGS{Owner},
		       InitialPriority=> $ARGS{InitialPriority},
		       FinalPriority=> $ARGS{FinalPriority},
		       TimeLeft => $ARGS{TimeLeft},
		       TimeWorked => $ARGS{TimeWorked},
		       Requestor=> \@Requestors,
		       Cc => \@Cc,
		       AdminCc => \@AdminCc,
		       Subject=>$ARGS{Subject},
		       Status=>$ARGS{Status},
		       Due => $due->ISO,
		       Starts => $starts->ISO,
		       MIMEObj => $MIMEObj	  
		      );         

    
    # we need to get any KeywordSelect-<integer> fields into %create_args..
    grep { $_ =~ /^KeywordSelect-/ && {$create_args{$_} = $ARGS{$_}}} %ARGS;

    my ($id, $Trans, $ErrMsg)= $Ticket->Create(%create_args);
    unless ($id && $Trans) {
	Abort($ErrMsg);
    }
    my @linktypes = qw( DependsOn MemberOf RefersTo );
    
    foreach my $linktype (@linktypes) {
      foreach my $luri (split (/ /,$ARGS{"new-$linktype"})) {
	$luri =~ s/\s*$//; # Strip trailing whitespace
	my ($val, $msg) = $Ticket->AddLink( Target => $luri,
					    Type => $linktype);
	push (@Actions, $msg) unless ($val);
      }
      
      foreach my $luri (split (/ /,$ARGS{"$linktype-new"})) {
	my ($val, $msg) = $Ticket->AddLink( Base => $luri,
					    Type => $linktype);
	
	push (@Actions, $msg) unless ($val);
      }
    }

    push(@Actions, $ErrMsg);
    unless ($Ticket->CurrentUserHasRight('ShowTicket')) {
      Abort("No permission to view newly created ticket #".$Ticket->id.".");
    }
    return ($Ticket, @Actions);

}

# }}}

# {{{ sub LoadTicket - loads a ticket

=head2  LoadTicket id

Takes a ticket id as its only variable. if it's handed an array, it takes
the first value.

Returns an RT::Ticket object as the current user.

=cut

sub LoadTicket {
    my $id=shift;

    if (ref($id) eq "ARRAY")   {
	$id =$id->[0];
    }
 
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

# {{{ sub ProcessUpdateMessage
sub ProcessUpdateMessage {
  #TODO document what else this takes.
  my %args=( ARGSRef => undef,
	     Actions => undef,
	     TicketObj => undef,
	     @_);

    #Make the update content have no 'weird' newlines in it
    if ($args{ARGSRef}->{'UpdateContent'}) {

     if ($args{ARGSRef}->{'UpdateSubject'} eq $args{'TicketObj'}->Subject()) {
	$args{ARGSRef}->{'UpdateSubject'} = undef;
     }

     my $Message = 
	  MakeMIMEEntity(
			 Subject => $args{ARGSRef}->{'UpdateSubject'},
			 Body => $args{ARGSRef}->{'UpdateContent'},
			 AttachmentFieldName => 'UpdateAttachment');
	
	## TODO: Implement public comments
	if ($args{ARGSRef}->{'UpdateType'} =~ /^(private|public)$/) {
	    my ($Transaction, $Description) = $args{TicketObj}->Comment
		( CcMessageTo => $args{ARGSRef}->{'UpdateCc'},
		  BccMessageTo => $args{ARGSRef}->{'UpdateBcc'},
		  MIMEObj => $Message,
		  TimeTaken => $args{ARGSRef}->{'UpdateTimeWorked'});
	    push(@{$args{Actions}}, $Description);
	}
	elsif ($args{ARGSRef}->{'UpdateType'} eq 'response') {
	    my ($Transaction, $Description) = $args{TicketObj}->Correspond
		( CcMessageTo => $args{ARGSRef}->{'UpdateCc'},
		  BccMessageTo => $args{ARGSRef}->{'UpdateBcc'},
		  MIMEObj => $Message,
		  TimeTaken => $args{ARGSRef}->{'UpdateTimeWorked'});
	    push(@{$args{Actions}}, $Description);
	} 
	else {
	    push(@{$args{'Actions'}}, "Update type was neither correspondence nor comment. Update not recorded");
	}
    }
}
# }}}

# {{{ sub MakeMIMEEntity

=head2 MakeMIMEEntity PARAMHASH

Takes a paramhash Subject, Body and AttachmentFieldName.

  Returns a MIME::Entity.

=cut

sub MakeMIMEEntity {
  #TODO document what else this takes.
    my %args=(
	      Subject => undef,
	      From => undef,
	      Cc => undef,
	      Body => undef,
	      AttachmentFieldName => undef,
	      @_);

  #Make the update content have no 'weird' newlines in it

  $args{'Body'} =~ s/\r\n/\n/gs;
  my $Message = MIME::Entity->build 
    ( Subject => $args{'Subject'} || "",
      From => $args{'From'},
      Cc => $args{'Cc'},
      Data => [ $args{'Body'} ] );

  my $cgi_object = CGIObject();

  my $filehandle = $cgi_object->upload($args{'AttachmentFieldName'});
  
  
  use File::Temp qw(tempfile tempdir);

  #foreach my $filehandle (@filenames) {
  
  my ($fh, $temp_file) = tempfile();
  
  binmode $fh; #thank you, windows
  my ($buffer);
  while (my $bytesread=read($filehandle,$buffer,4096)) {
      print $fh $buffer;
  }
  
  
  my $filename = "$filehandle";
  $filename =~ s#^(.*)/##;	
    my $uploadinfo = $cgi_object->uploadInfo($filehandle);	
  $Message->attach(Path => $temp_file,
		   Filename => $filename,
		   Type => $uploadinfo->{'Content-Type'});	
  close ($fh);
  #	}
  $Message->make_singlepart();
  return ($Message);

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

    #Import a bookmarked search if we have one
    if (defined $args{ARGS}->{'Bookmark'}) {
	$session{'tickets'}->ThawLimits($args{ARGS}->{'Bookmark'});
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


    if ($args{ARGS}->{'RefreshSearchInterval'}) {
	$session{'tickets_refresh_interval'} = 
		$args{ARGS}->{'RefreshSearchInterval'};
    }

    if ($args{ARGS}->{'TicketsSortBy'}) {
	$session{'tickets_sort_by'} = $args{ARGS}->{'TicketsSortBy'};
	$session{'tickets_sort_order'} = $args{ARGS}->{'TicketsSortOrder'};
	$session{'tickets'}->OrderBy(FIELD => $args{ARGS}->{'TicketsSortBy'},
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
    # {{{ Limit priority
    if ($args{ARGS}->{'ValueOfPriority'} ne '' ) {
	$session{'tickets'}->LimitPriority(					
				VALUE => $args{ARGS}->{'ValueOfPriority'},
				OPERATOR => $args{ARGS}->{'PriorityOp'}
			       );
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
    
    if ($args{ARGS}->{'ValueOfRequestor'} ne '') {
	my $alias=$session{'tickets'}->LimitRequestor 
	  (
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
	$session{'tickets'}->LimitContent(				
				   VALUE =>  $args{ARGS}->{'ValueOfContent'},
				   OPERATOR => $args{ARGS}->{'ContentOp'},
				  );
    }

    # }}}   
    # {{{ Limit KeywordSelects

    foreach my $KeywordSelectId (
				 map { /^KeywordSelect(\d+)$/; $1 }
				 grep { /^KeywordSelect(\d+)$/; }
				 keys %{$args{ARGS}} ) {
	my $form = $args{ARGS}->{"KeywordSelect$KeywordSelectId"};
	my $oper = $args{ARGS}->{"KeywordSelectOp$KeywordSelectId"};
	foreach my $KeywordId ( ref($form) ? @{ $form } : ( $form ) ) {
	    next unless ($KeywordId); 
	    my $quote = 1;
	    if ( $KeywordId =~ /^null$/i ) {
		#Don't quote the string 'null'
		$quote = 0;
		# Convert the operator to something apropriate for nulls
		$oper = 'IS' if ( $oper eq '=' );
		$oper = 'IS NOT' if ( $oper eq '!=' ) ;
	    }
	    $session{'tickets'}->LimitKeyword(KEYWORDSELECT => $KeywordSelectId,
					      OPERATOR => $oper,
					      QUOTEVALUE => $quote,
					      KEYWORD => $KeywordId);
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
	
    my $date_obj = new RT::Date($CurrentUser);
    $date_obj->Set( Format => 'unknown',
			Value => $date
			      );
    return ($date_obj->ISO);
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

    # {{{ Add rights
    foreach $ACL (@CheckACL) {
	my ($Principal);
	
	next unless ($ACL);

	# Parse out what we're really talking about. 
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

	    # }}}
	    
	    # {{{ Add any rights we need.



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
	}
    }
    # }}} Add rights

    # {{{ remove any rights that have been deleted

	    my @RevokeACE = ref($ARGS{"RevokeACE"}) eq 'ARRAY' ?
	      @{$ARGS{"RevokeACE"}} : ($ARGS{"RevokeACE"});

	    foreach my $aceid (@RevokeACE) {

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
		   Subject 
		   FinalPriority 
		   Priority 
		   Status 
		   TimeWorked  
		   TimeLeft 
        );
 

  if ($ARGSRef->{'Queue'} and ($ARGSRef->{'Queue'} !~ /^(\d+)$/)) {
	my $tempqueue = RT::Queue->new($RT::SystemUser);
	$tempqueue->Load($ARGSRef->{'Queue'});
	if ($tempqueue->id) {
	  $ARGSRef->{'Queue'} =  $tempqueue->Id();
	}	
  }
 
  my @results = UpdateRecordObject( AttributesRef => \@attribs, 
				    Object => $TicketObj, 
				    ARGSRef => $ARGSRef);

  
  # We special case owner changing, so we can use ForceOwnerChange
   if ( $ARGSRef->{'Owner'} && 
	($TicketObj->Owner != $ARGSRef->{'Owner'}) ) {
       my ($ChownType);
       if ($ARGSRef->{'ForceOwnerChange'}) {
	   $ChownType = "Force";
       } else {
	   $ChownType = "Give";
       }
       
       my ($val, $msg) = $TicketObj->SetOwner($ARGSRef->{'Owner'}, $ChownType);
       push (@results, "$msg");
   }
  
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
	# Delete watchers in the simple style demanded by the bulk manipulator
	elsif ($key =~ /^Delete(Requestor|Cc|AdminCc)$/) {
	    my ($code, $msg) = 
	      $Ticket->DeleteWatcher( $ARGSRef->{$key}, $1);
	    push @results, $msg;
	}
	
	
	# Add new wathchers by email address      
	elsif ( ($ARGSRef->{$key} =~ /^(AdminCc|Cc|Requestor)$/) and
		($key =~ /^WatcherTypeEmail(\d*)$/) ) {
	    #They're in this order because otherwise $1 gets clobbered :/
	    my ($code, $msg) = 
	      $Ticket->AddWatcher(Type => $ARGSRef->{$key}, 
				  Email => $ARGSRef->{"WatcherAddressEmail".$1});
	    push @results, $msg;
	}
	#Add requestors in the simple style demanded by the bulk manipulator
	elsif ($key =~ /^Add(Requestor|Cc|AdminCc)$/) {
	  my ($code, $msg) = 
	    $Ticket->AddWatcher(Type => $1,
				Email => $ARGSRef->{$key});
	  push @results, $msg;
      }
	
	# Add new  watchers by owner
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
    # }}}
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
	$luri =~ s/\s*$//; # Strip trailing whitespace
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
	#we'll use this for adding and deleting keywords from this object.
	my %values = map { $_=>1 } ref($value) ? @{$value} : ( $value );
	
	# Load up the ObjectKeywords for this KeywordSelect for this ticket
	my $ObjectKeys = $TicketObj->KeywordsObj($KeywordSelect->id);
	
	# }}}
	# {{{ add new keywords

	foreach my $key (keys %values) {

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
	
	#redo this search, so we don't ask it to delete things that are already gone
	# such as when a single keyword select gets its value changed.
	$ObjectKeys = $TicketObj->KeywordsObj($KeywordSelect->id);

	while (my $TicketKey = $ObjectKeys->Next) {
	    
	    # if the hash defined above doesn\'t contain the keyword mentioned,
	    unless ($values{$TicketKey->Keyword}) {
		#I'd really love to just call $keyword->Delete, but then 
		# we wouldn't get a transaction recorded
		my ($result, $msg) = 
		  $TicketObj->DeleteKeyword(Keyword => $TicketKey->Keyword,
					    KeywordSelect => $KeywordSelect->id);
		push(@results, $msg);
	    }
	}
	
	# }}}
    }
    
    #Iterate through the keyword selects for BulkManipulator style access
    while ( my $KeywordSelect = $KeywordSelects->Next ) {
	if ($ARGSRef->{"AddToKeywordSelect".$KeywordSelect->Id}) {
	    #Add the keyword
	    my ($result, $msg) = 
		  $TicketObj->AddKeyword( Keyword => $ARGSRef->{"AddToKeywordSelect".
								$KeywordSelect->Id },
					  KeywordSelect => $KeywordSelect->id);
		push(@results, $msg);
	    }	
	if ($ARGSRef->{"DeleteFromKeywordSelect".$KeywordSelect->Id}) {
	    #Delete the keyword
	    my ($result, $msg) = 
	      $TicketObj->DeleteKeyword(Keyword =>$ARGSRef->{"DeleteFromKeywordSelect".
							     $KeywordSelect->Id },
					KeywordSelect => $KeywordSelect->id);
	    push(@results, $msg);
	}	
    }	
    # }}}
    
    return (@results);
}

# }}}


1;
