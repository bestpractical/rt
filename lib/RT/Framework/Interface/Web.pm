## $Header$
## Copyright 2001 Jesse Vincent <jesse@fsck.com> 


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
                   comp_root => undef,
		   data_dir => undef,
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

# {{{ sub ProcessUpdateMessage
sub ProcessUpdateMessage {
  #TODO document what else this takes.
  my %args=( ARGSRef => undef,
	     Actions => undef,
	     TicketObj => undef,
	     @_);

    #Make the update content have no 'weird' newlines in it
    if ($args{ARGSRef}->{'UpdateContent'}) {

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
    my @UpdateContent = split(/(\r\n|\n|\r)/,
			      $args{Body});
    my $Message = MIME::Entity->build 
    ( Subject => $args{'Subject'} || "",
      From => $args{'From'},
      Cc => $args{'Cc'},
      Data => \@UpdateContent);
    
    my $cgi_object = CGIObject();
    
    my $filehandle = $cgi_object->upload($args{'AttachmentFieldName'});
    
    
    use File::Temp qw(tempfile tempdir);

    #foreach my $filehandle (@filenames) {
    
    my ($fh, $temp_file) = tempfile();
    
    binmode $fh; #thank you, windows
    my ($buffer);
    #while ($buffer = <$filehandle>) {
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

# {{{ sub UpdateArticles

sub UpdateArticles {
    my %args = (
		ARGSRef => undef,
		@_
	       );

    my @total_results;
    my $template_article = RT::FM::Article->new($session{'CurrentUser'}) ;
 
    # TODO  There needs to be a DBIx::SB::Record API to get this cleanly
    my @attributes = grep { $template_article->{'_AccessibleCache'}->{$_}->{'read'} } 
      keys %{$template_article->{'_AccessibleCache'}};
    
    
    foreach my $art_id ( ref($args{'ARGSRef'}->{'EditArticle'}) ? 
			 @{ $args{'ARGSRef'}->{'EditArticle'} } : 
			 ( $args{'ARGSRef'}->{'EditArticle'} ) ) {

	# update all the basic fields
	my $article = RT::FM::Article->new($session{'CurrentUser'});
	$RT::FM::Logger->crit("Loading $art_id\n");
	$article->Load($art_id);
	my @results = UpdateRecordObject ( AttributesRef => \@attributes, 
					   Object => $article, 
					   ARGSRef => $args{'ARGSRef'});
	my @cf_results = UpdateArticleCustomFieldValues (
					   Object => $article, 
					   ARGSRef => $args{'ARGSRef'});
	@total_results = (@total_results, @results, @cf_results);
	
    }	
    return (@total_results);
    
	
}


# }}}


# {{{ sub UpdateUsers

sub UpdateUsers {
    my %args = (
                ARGSRef => undef,
                @_
               );

    my @total_results;
    my $template = RT::FM::User->new($session{'CurrentUser'}) ;

    # TODO  There needs to be a DBIx::SB::Record API to get this cleanly
    my @attributes = grep { $template->{'_AccessibleCache'}->{$_}->{'read'} }
      keys %{$template->{'_AccessibleCache'}};


    foreach my $id ( ref($args{'ARGSRef'}->{'EditUser'}) ?
                         @{ $args{'ARGSRef'}->{'EditUser'} } :
                         ( $args{'ARGSRef'}->{'EditUser'} ) ) {

        # update all the basic fields
        my $object = RT::FM::User->new($session{'CurrentUser'});
        $object->Load($id);
        my @results = UpdateRecordObject ( AttributesRef => \@attributes,
                                           Object => $object,
                                           ARGSRef => $args{'ARGSRef'});
        @total_results = (@total_results, @results, @cf_results);

    }
    return (@total_results);


}


# }}}


# {{{ sub UpdateArticleCustomFieldValues

=head2 UpdateArticleCustomFieldValues ( Object => $Article, ARGSRef => \%ARGS );

Returns an array of results messages.

=cut

sub UpdateArticleCustomFieldValues {
    my %args = ( Object => undef,
		 ARGSRef => undef,
		 @_
	       );
    
    my $Article = $args{'Object'};
    my $ARGSRef = $args{'ARGSRef'};
    
    my (@results);
    
    # {{{ set ObjectKeywords.

    my $CustomFields = new RT::FM::CustomFieldCollection($session{'CurrentUser'});
    $CustomFields->UnLimit();

  
        # iterate through all the custom fields
    while ( my $CustomField = $CustomFields->Next ) {
	# {{{ do some setup

	my %values;


	# Thanks to the miracle of http and html, if the form is empty (if all values are deleted, this just loses.	
	next unless defined 
	    $ARGSRef->{'RT::FM::Article-'.$Article->Id.'-CustomField-'.$CustomField->Id.'-AllValues-Magic'}; 
	
	# Lets get a hash of the possible values to work with
	my $allvalues = $ARGSRef->{'RT::FM::Article-'.$Article->Id.'-CustomField-'.$CustomField->Id.'-AllValues'} || [];

	# Get an array of all possible values
	my @allvalues =  ref($allvalues) ? @{$allvalues} : ( $allvalues );


	#lets get all those values in a hash. regardless of # of entries
	#we'll use this for adding and deleting keywords from this object.
	foreach my $value (@allvalues) {
		$value =~ s/\r\n/\n/gs;
		if ($value =~ /\n/) {
			foreach my $subvalue (split(/\n/,$value)) {
				$values{$subvalue} = 1;
			}
		}
		else {
			$values{$value} = 1;
		}
	}
	
	
	# Load up the ObjectKeywords for this CustomField for this ticket
	my $CurrentValuesObj = $Article->CustomFieldValues($CustomField->id);
	
	# }}}
	# {{{ add new keywords

	foreach my $key (keys %values) {

	    #unless the ticket has that value for that field
            unless (grep {$_->Content eq $key }   @{$CurrentValuesObj->ItemsArrayRef} ) {
		#Add the keyword
		my ($result, $msg) = 
		  $Article->AddCustomFieldValue( Value => $key,
						 CustomField => $CustomField->id);
		push(@results, $msg);
	    }
	}
	
	# }}}
	# {{{ Delete unused keywords
	
	#redo this search, so we don't ask it to delete things that are already gone
	# such as when a single keyword select gets its value changed.
	$cfvalues = $Article->CustomFieldValues($CustomField->id);

	while (my $CFValue = $cfvalues->Next) {
	    
	    # if the hash defined above doesn\'t contain the keyword mentioned,
	    unless ($values{$CFValue->Content}) {
		my ($result, $msg) = 
		  $Article->DeleteCustomFieldValue(Value => $CFValue->Content,
					          CustomField => $CustomField->id);
		push(@results, $msg);
	    }
	}
	
	# }}}
    }
    
    #Iterate through the keyword selects for BulkManipulator style access
    while ( my $CustomField = $CustomFields->Next ) {

	# Lets get a hash of the possible values to work with
	my $add_value = $ARGSRef->{'RT::FM::Article-'.$Article->Id.'-CustomField-'.$CustomField->Id.'-AddValues'} || [];
	
	#lets get all those values in a hash. regardless of # of entries
	#we'll use this for adding and deleting keywords from this object.
	my @add_values =  ref($add_value) ? @{$add_value} : ( $add_value );

        foreach my $value (@add_values) {

	    #Add the keyword
	    my ($result, $msg) = 
		  $Article->AddCustomFieldValue( Value => $value ,
					  CustomField => $CustomField->id);
		push(@results, $msg);
	}
	
	# Lets get a hash of the possible values to work with
	my $del_value = $ARGSRef->{'RT::FM::Article-'.$Article->Id.'-CustomField-'.$CustomField->Id.'-DeleteValues'} || [];
	
	#lets get all those values in a hash. regardless of # of entries
	#we'll use this for adding and deleting keywords from this object.
	my @del_values =  ref($del_value) ? @{$del_value} : ( $del_value );
	
        foreach my $value (@del_values) {
	    #Delete the keyword
	    my ($result, $msg) = 
	      $Article->DeleteCustomFieldValue(	Value => $value,
						CustomField => $CustomField->id);
	    push(@results, $msg);
	}	
    }	
    # }}}
    
    return (@results);
}

# }}}

# {{{ sub UpdateCustomFields

sub UpdateCustomFields {
    my %args = (
		ARGSRef => undef,
		@_
		
	       );
    
    my @total_results;
    my $template = RT::FM::CustomField->new($session{'CurrentUser'}) ;
    # TODO  There needs to be a DBIx::SB::Record API to get this cleanly
    my @attributes = grep { $template->{'_AccessibleCache'}->{$_}->{'read'} } 
      keys %{$template->{'_AccessibleCache'}};
    
    foreach my $id ( ref($args{'ARGSRef'}->{'EditCustomField'}) ? 
		     @{ $args{'ARGSRef'}->{'EditCustomField'} } : 
		     ( $args{'ARGSRef'}->{'EditCustomField'} ) ) {
	
	my $object = RT::FM::CustomField->new($session{'CurrentUser'});
	$object->Load($id);
	my @results = UpdateRecordObject ( AttributesRef => \@attributes, 
					   Object => $object, 
					   ARGSRef => $args{'ARGSRef'});
	@total_results = (@total_results, @results);
    	
    
        foreach my $val
	(ref($args{'ARGSRef'}->{'DeleteValue-RT::FM::CustomField-'.$id}) ? 
           @{ $args{'ARGSRef'}->{'DeleteValue-RT::FM::CustomField-'.$id} } : 
	    ( $args{'ARGSRef'}->{'DeleteValue-RT::FM::CustomField-'.$id} ) ) {
		my ($ret, $msg) = $object->DeleteValue($val);
		push @total_results, $msg;	
	}

        foreach my $val
	(ref($args{'ARGSRef'}->{'NewValue-RT::FM::CustomField-'.$id}) ? 
           @{ $args{'ARGSRef'}->{'NewValue-RT::FM::CustomField-'.$id} } : 
	    ( $args{'ARGSRef'}->{'NewValue-RT::FM::CustomField-'.$id} ) ) {
		next unless ($val);
		my ($ret, $msg) = $object->NewValue(Name => $val);
		push @total_results, $msg;	
	}
    }
    return (@total_results);
    
	
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
	my $formvar = ref($object)."-".$object->Id."-$attribute";
	warn "Looking for $formvar";
	if (
	     ((defined $ARGSRef->{$formvar}) || 
	      (defined $ARGSRef->{$formvar."-magic"} ) ) 
             and 
	     ($ARGSRef->{"$formvar"} ne $object->$attribute())) {
	    
	    $ARGSRef->{"$formvar"} =~ s/\r\n/\n/gs;
	    
	    my $method = "Set$attribute";
	    warn "Calling $method on $object";
	    my ($code, $msg) = $object->$method($ARGSRef->{"$formvar"});
	    push @results, "$attribute: $msg";
	}
    }
    return (@results);
}
# }}}

1;
