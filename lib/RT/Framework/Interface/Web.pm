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
    warn "Attributes of articles are ". join(',',@attributes);
    
    
    foreach my $art_id ( ref($$args{'ARGSRef'}->{'EditArticle'}) ? 
			   @{ $args{'ARGSRef'}->{'EditArticle'} } : 
			   ( $args{'ARGSRef'}->{'EditArticle'} ) ) {
			 
	my $article = RT::FM::Article->new($session{'CurrentUser'});
	$article->Load($art_id);
	my @results = UpdateRecordObject ( AttributesRef => \@attributes, 
					   Object => $article, 
					   ARGSRef => $args{'ARGSRef'});
	@total_results = (@total_results, @results);
    }	
    return (@total_results);
    
	
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
    
    foreach my $id ( ref($$args{'ARGSRef'}->{'EditCustomField'}) ? 
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
	if ((defined $ARGSRef->{$formvar}) and 
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
