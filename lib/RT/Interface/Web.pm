## $Header: /raid/cvsroot/rt/lib/RT/Interface/Web.pm,v 1.4 2001/12/14 18:46:03 jesse Exp $
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
    my %args = (
        allow_globals => undef,
        @_
    );

    my $parser = new HTML::Mason::Parser(
        default_escape_flags => 'h',
        allow_globals        => $args{'allow_globals'}
    );
    return ($parser);
}

# }}}

# {{{ sub NewApacheHandler 

=head2 NewApacheHandler

  Takes a Mason::Interp object
  Returns a new Mason::ApacheHandler object

=cut

sub NewApacheHandler {
    my $interp = shift;
    my $ah = new HTML::Mason::ApacheHandler( 
    
        comp_root                    => [
            [ local    => $RT::MasonLocalComponentRoot ],
            [ standard => $RT::MasonComponentRoot ]
        ],
        data_dir => "$RT::MasonDataDir");
    
    return ($ah);
}

# }}}

# {{{ sub NewCGIHandler 

=head2 NewCGIHandler

  Returns a new Mason::CGIHandler object

=cut

sub NewCGIHandler {
    my %args = (
        allow_globals => qw//,
        @_
    );

    my $handler = HTML::Mason::CGIHandler->new(
        comp_root                    => [
            [ local    => $RT::MasonLocalComponentRoot ],
            [ standard => $RT::MasonComponentRoot ]
        ],
        data_dir => "$RT::MasonDataDir",
        allow_globals        => [qw(%session)]
    );
    return ($handler);
}

# }}}


package HTML::Mason::Commands;

# {{{ SetContentType

=head2 SetContentType TYPE

Set this response's output to content type TYPE

=cut

sub SetContentType {
    my $type = shift;
    $r->content_type($type);
}

# }}}

# {{{ loc

=head2 loc ARRAY

loc is a nice clean global routine which calls $session{'CurrentUser'}->loc()
with whatever it's called with. If there is no $session{'CurrentUser'}, 
it creates a temporary user, so we have something to get a localisation handle
through

=cut

sub loc {

    if ($session{'CurrentUser'} && 
        UNIVERSAL::can($session{'CurrentUser'}, 'loc')){
        return($session{'CurrentUser'}->loc(@_));
    }
    else  {
        my $u = RT::CurrentUser->new($RT::SystemUser);
        return ($u->loc(@_));
    }
}

# }}}


# {{{ loc_match

=head2 loc_match ARRAY

loc_match is for handling localizations of messages that may already
contain interpolated variables, typically returned from libraries
outside RT's control.  It takes the message string and extracts the
variable array automatically by matching against the candidate entries
passed as rest of @_.

=cut

sub loc_match {
    my $self = shift;
    my $msg  = shift;
    
    foreach my $entry (@_) {
	my $regex = quotemeta($entry);
	$regex =~ s/\\\[_\d\\\]/(.*?)/;
	if (my @matched = ($msg =~ /^$regex$/)) {
	    return loc($entry, @matched);
	}
    }

    return loc($msg);
}

# }}}


# {{{ sub Abort
# Error - calls Error and aborts
sub Abort {

    $r->content_type('text/html');
    $m->comp( "/Elements/Error", Why => shift );;
    $m->abort;
}

# }}}

# {{{ sub CreateTicket 

=head2 CreateTicket ARGS

Create a new ticket, using Mason's %ARGS.  returns @results.
=cut

sub CreateTicket {
    my %ARGS = (@_);

    my (@Actions);

    my $Ticket = new RT::Ticket( $session{'CurrentUser'} );

    my $Queue = new RT::Queue( $session{'CurrentUser'} );
    unless ( $Queue->Load( $ARGS{'Queue'} ) ) {
        Abort('Queue not found');
    }

    unless ( $Queue->CurrentUserHasRight('CreateTicket') ) {
        Abort('You have no permission to create tickets in that queue.');
    }

    my $due = new RT::Date( $session{'CurrentUser'} );
    $due->Set( Format => 'unknown', Value => $ARGS{'Due'} );
    my $starts = new RT::Date( $session{'CurrentUser'} );
    $starts->Set( Format => 'unknown', Value => $ARGS{'Starts'} );

    my @Requestors = split ( /,/, $ARGS{'Requestors'} );
    my @Cc         = split ( /,/, $ARGS{'Cc'} );
    my @AdminCc    = split ( /,/, $ARGS{'AdminCc'} );

    my $MIMEObj = MakeMIMEEntity(
        Subject             => $ARGS{'Subject'},
        From                => $ARGS{'From'},
        Cc                  => $ARGS{'Cc'},
        Body                => $ARGS{'Content'},
        AttachmentFieldName => 'Attach'
    );

    my %create_args = (
        Queue           => $ARGS{'Queue'},
        Owner           => $ARGS{'Owner'},
        InitialPriority => $ARGS{'InitialPriority'},
        FinalPriority   => $ARGS{'FinalPriority'},
        TimeLeft        => $ARGS{'TimeLeft'},
        TimeWorked      => $ARGS{'TimeWorked'},
        Requestor       => \@Requestors,
        Cc              => \@Cc,
        AdminCc         => \@AdminCc,
        Subject         => $ARGS{'Subject'},
        Status          => $ARGS{'Status'},
        Due             => $due->ISO,
        Starts          => $starts->ISO,
        MIMEObj         => $MIMEObj
    );
  foreach my $arg (%ARGS) {
        if ($arg =~ /^CustomField-(\d+)$/) {
                $create_args{$arg} = $ARGS{"$arg"};
        }
    }
    my ( $id, $Trans, $ErrMsg ) = $Ticket->Create(%create_args);
    unless ( $id && $Trans ) {
        Abort($ErrMsg);
    }
    my @linktypes = qw( DependsOn MemberOf RefersTo );

    foreach my $linktype (@linktypes) {
        foreach my $luri ( split ( / /, $ARGS{"new-$linktype"} ) ) {
            $luri =~ s/\s*$//;    # Strip trailing whitespace
            my ( $val, $msg ) = $Ticket->AddLink(
                Target => $luri,
                Type   => $linktype
            );
            push ( @Actions, $msg ) unless ($val);
        }

        foreach my $luri ( split ( / /, $ARGS{"$linktype-new"} ) ) {
            my ( $val, $msg ) = $Ticket->AddLink(
                Base => $luri,
                Type => $linktype
            );

            push ( @Actions, $msg ) unless ($val);
        }
    }

    push ( @Actions, $ErrMsg );
    unless ( $Ticket->CurrentUserHasRight('ShowTicket') ) {
        Abort( "No permission to view newly created ticket #"
            . $Ticket->id . "." );
    }
    return ( $Ticket, @Actions );

}

# }}}

# {{{ sub LoadTicket - loads a ticket

=head2  LoadTicket id

Takes a ticket id as its only variable. if it's handed an array, it takes
the first value.

Returns an RT::Ticket object as the current user.

=cut

sub LoadTicket {
    my $id = shift;

    if ( ref($id) eq "ARRAY" ) {
        $id = $id->[0];
    }

    unless ($id) {
        Abort("No ticket specified");
    }

    my $Ticket = RT::Ticket->new( $session{'CurrentUser'} );
    $Ticket->Load($id);
    unless ( $Ticket->id ) {
        Abort("Could not load ticket $id");
    }
    return $Ticket;
}

# }}}

# {{{ sub ProcessUpdateMessage

sub ProcessUpdateMessage {

    #TODO document what else this takes.
    my %args = (
        ARGSRef   => undef,
        Actions   => undef,
        TicketObj => undef,
        @_
    );

    #Make the update content have no 'weird' newlines in it
    if ( $args{ARGSRef}->{'UpdateContent'} ) {

        if (
            $args{ARGSRef}->{'UpdateSubject'} eq $args{'TicketObj'}->Subject() )
        {
            $args{ARGSRef}->{'UpdateSubject'} = undef;
        }

        my $Message = MakeMIMEEntity(
            Subject             => $args{ARGSRef}->{'UpdateSubject'},
            Body                => $args{ARGSRef}->{'UpdateContent'},
            AttachmentFieldName => 'UpdateAttachment'
        );

        ## TODO: Implement public comments
        if ( $args{ARGSRef}->{'UpdateType'} =~ /^(private|public)$/ ) {
            my ( $Transaction, $Description ) = $args{TicketObj}->Comment(
                CcMessageTo  => $args{ARGSRef}->{'UpdateCc'},
                BccMessageTo => $args{ARGSRef}->{'UpdateBcc'},
                MIMEObj      => $Message,
                TimeTaken    => $args{ARGSRef}->{'UpdateTimeWorked'}
            );
            push ( @{ $args{Actions} }, $Description );
        }
        elsif ( $args{ARGSRef}->{'UpdateType'} eq 'response' ) {
            my ( $Transaction, $Description ) = $args{TicketObj}->Correspond(
                CcMessageTo  => $args{ARGSRef}->{'UpdateCc'},
                BccMessageTo => $args{ARGSRef}->{'UpdateBcc'},
                MIMEObj      => $Message,
                TimeTaken    => $args{ARGSRef}->{'UpdateTimeWorked'}
            );
            push ( @{ $args{Actions} }, $Description );
        }
        else {
            push ( @{ $args{'Actions'} },
                loc("Update type was neither correspondence nor comment.").
                " ".
                loc("Update not recorded.")
            );
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
    my %args = (
        Subject             => undef,
        From                => undef,
        Cc                  => undef,
        Body                => undef,
        AttachmentFieldName => undef,
        @_
    );

    #Make the update content have no 'weird' newlines in it

    $args{'Body'} =~ s/\r\n/\n/gs;
    my $Message = MIME::Entity->build(
        Subject => $args{'Subject'} || "",
        From    => $args{'From'},
        Cc      => $args{'Cc'},
        Data    => [ $args{'Body'} ]
    );

    my $cgi_object = $m->cgi_object;

    if (my $filehandle = $cgi_object->upload( $args{'AttachmentFieldName'} ) ) {



    use File::Temp qw(tempfile tempdir);

    #foreach my $filehandle (@filenames) {

    my ( $fh, $temp_file ) = tempfile();

    binmode $fh;    #thank you, windows
    my ($buffer);
    while ( my $bytesread = read( $filehandle, $buffer, 4096 ) ) {
        print $fh $buffer;
    }

    my $uploadinfo = $cgi_object->uploadInfo($filehandle);

    # Prefer the cached name first over CGI.pm stringification.
    my $filename = $RT::Mason::CGI::Filename;
    $filename = "$filehandle" unless defined($filename);
		   
    $filename =~ s#^.*/##;
    $Message->attach(
        Path     => $temp_file,
        Filename => $filename,
        Type     => $uploadinfo->{'Content-Type'}
    );
    close($fh);

    #	}

    }

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
    my %args = @_;

    ## TODO: The only parameter here is %ARGS.  Maybe it would be
    ## cleaner to load this parameter as $ARGS, and use $ARGS->{...}
    ## instead of $args{ARGS}->{...} ? :)

    #Searches are sticky.
    if ( defined $session{'tickets'} ) {

        # Reset the old search
        $session{'tickets'}->GotoFirstItem;
    }
    else {

        # Init a new search
        $session{'tickets'} = RT::Tickets->new( $session{'CurrentUser'} );
    }

    #Import a bookmarked search if we have one
    if ( defined $args{ARGS}->{'Bookmark'} ) {
        $session{'tickets'}->ThawLimits( $args{ARGS}->{'Bookmark'} );
    }

    # {{{ Goto next/prev page
    if ( $args{ARGS}->{'GotoPage'} eq 'Next' ) {
        $session{'tickets'}->NextPage;
    }
    elsif ( $args{ARGS}->{'GotoPage'} eq 'Prev' ) {
        $session{'tickets'}->PrevPage;
    }

    # }}}

    # {{{ Deal with limiting the search

    if ( $args{ARGS}->{'RefreshSearchInterval'} ) {
        $session{'tickets_refresh_interval'} =
          $args{ARGS}->{'RefreshSearchInterval'};
    }

    if ( $args{ARGS}->{'TicketsSortBy'} ) {
        $session{'tickets_sort_by'}    = $args{ARGS}->{'TicketsSortBy'};
        $session{'tickets_sort_order'} = $args{ARGS}->{'TicketsSortOrder'};
        $session{'tickets'}->OrderBy(
            FIELD => $args{ARGS}->{'TicketsSortBy'},
            ORDER => $args{ARGS}->{'TicketsSortOrder'}
        );
    }

    # }}}

    # {{{ Set the query limit
    if ( defined $args{ARGS}->{'RowsPerPage'} ) {
        $RT::Logger->debug(
            "limiting to " . $args{ARGS}->{'RowsPerPage'} . " rows" );

        $session{'tickets_rows_per_page'} = $args{ARGS}->{'RowsPerPage'};
        $session{'tickets'}->RowsPerPage( $args{ARGS}->{'RowsPerPage'} );
    }

    # }}}
    # {{{ Limit priority
    if ( $args{ARGS}->{'ValueOfPriority'} ne '' ) {
        $session{'tickets'}->LimitPriority(
            VALUE    => $args{ARGS}->{'ValueOfPriority'},
            OPERATOR => $args{ARGS}->{'PriorityOp'}
        );
    }

    # }}}
    # {{{ Limit owner
    if ( $args{ARGS}->{'ValueOfOwner'} ne '' ) {
        $session{'tickets'}->LimitOwner(
            VALUE    => $args{ARGS}->{'ValueOfOwner'},
            OPERATOR => $args{ARGS}->{'OwnerOp'}
        );
    }

    # }}}
    # {{{ Limit requestor email

    if ( $args{ARGS}->{'ValueOfRequestor'} ne '' ) {
        my $alias = $session{'tickets'}->LimitRequestor(
            VALUE    => $args{ARGS}->{'ValueOfRequestor'},
            OPERATOR => $args{ARGS}->{'RequestorOp'},
        );

    }

    # }}}
    # {{{ Limit Queue
    if ( $args{ARGS}->{'ValueOfQueue'} ne '' ) {
        $session{'tickets'}->LimitQueue(
            VALUE    => $args{ARGS}->{'ValueOfQueue'},
            OPERATOR => $args{ARGS}->{'QueueOp'}
        );
    }

    # }}}
    # {{{ Limit Status
    if ( $args{ARGS}->{'ValueOfStatus'} ne '' ) {
        if ( ref( $args{ARGS}->{'ValueOfStatus'} ) ) {
            foreach my $value ( @{ $args{ARGS}->{'ValueOfStatus'} } ) {
                $session{'tickets'}->LimitStatus(
                    VALUE    => $value,
                    OPERATOR => $args{ARGS}->{'StatusOp'},
                );
            }
        }
        else {
            $session{'tickets'}->LimitStatus(
                VALUE    => $args{ARGS}->{'ValueOfStatus'},
                OPERATOR => $args{ARGS}->{'StatusOp'},
            );
        }

    }

    # }}}
    # {{{ Limit Subject
    if ( $args{ARGS}->{'ValueOfSubject'} ne '' ) {
        $session{'tickets'}->LimitSubject(
            VALUE    => $args{ARGS}->{'ValueOfSubject'},
            OPERATOR => $args{ARGS}->{'SubjectOp'},
        );
    }

    # }}}    
    # {{{ Limit Dates
    if ( $args{ARGS}->{'ValueOfDate'} ne '' ) {
        my $date = ParseDateToISO( $args{ARGS}->{'ValueOfDate'} );
        $args{ARGS}->{'DateType'} =~ s/_Date$//;

        if ( $args{ARGS}->{'DateType'} eq 'Updated' ) {
            $session{'tickets'}->LimitTransactionDate(
                                            VALUE    => $date,
                                            OPERATOR => $args{ARGS}->{'DateOp'},
            );
        }
        else {
            $session{'tickets'}->LimitDate( FIELD => $args{ARGS}->{'DateType'},
                                            VALUE => $date,
                                            OPERATOR => $args{ARGS}->{'DateOp'},
            );
        }
    }

    # }}}    
    # {{{ Limit Content
    if ( $args{ARGS}->{'ValueOfAttachmentField'} ne '' ) {
        $session{'tickets'}->Limit(
            FIELD   => $args{ARGS}->{'AttachmentField'},
            VALUE    => $args{ARGS}->{'ValueOfAttachmentField'},
            OPERATOR => $args{ARGS}->{'AttachmentFieldOp'},
        );
    }

    # }}}   

 # {{{ Limit CustomFields

    foreach my $arg ( keys %{ $args{ARGS} } ) {
        my $id;
        if ( $arg =~ /^CustomField(\d+)$/ ) {
            $id = $1;
        }
        else {
            next;
        }
        next unless ( $args{ARGS}->{$arg} );

        my $form = $args{ARGS}->{$arg};
        my $oper = $args{ARGS}->{ "CustomFieldOp" . $id };
        foreach my $value ( ref($form) ? @{$form} : ($form) ) {
            my $quote = 1;
            if ( $KeywordId =~ /^null$/i ) {

                #Don't quote the string 'null'
                $quote = 0;

                # Convert the operator to something apropriate for nulls
                $oper = 'IS'     if ( $oper eq '=' );
                $oper = 'IS NOT' if ( $oper eq '!=' );
            }
            $session{'tickets'}->LimitCustomField( CUSTOMFIELD => $id,
                                                   OPERATOR    => $oper,
                                                   QUOTEVALUE  => $quote,
                                                   VALUE       => $value );
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
    $date_obj->Set(
        Format => 'unknown',
        Value  => $date
    );
    return ( $date_obj->ISO );
}

# }}}

# {{{ sub Config 
# TODO: This might eventually read the cookies, user configuration
# information from the DB, queue configuration information from the
# DB, etc.

sub Config {
    my $args = shift;
    my $key  = shift;
    return $args->{$key} || $RT::WebOptions{$key};
}

# }}}

# {{{ sub ProcessACLChanges

sub ProcessACLChanges {
    my $ARGSref = shift;

    my %ARGS     = %$ARGSref;

    my ( $ACL, @results );


    foreach my $arg (keys %ARGS) {
        if ($arg =~ /GrantRight-(\d+)-(.*?)-(\d+)$/) {
            my $principal_id = $1;
            my $object_type = $2;
            my $object_id = $3;
            my $rights = $ARGS{$arg};

            my $principal = RT::Principal->new($session{'CurrentUser'});
            $principal->Load($principal_id);

            my @rights = ref($ARGS{$arg}) eq 'ARRAY' ? @{$ARGS{$arg}} : ($ARGS{$arg});
            foreach my $right (@rights) {
                next unless ($right);
                my ($val, $msg) = $principal->GrantRight(ObjectType => $object_type, ObjectId => $object_id, Right => $right);
                push (@results, $msg);
            }
        }
       elsif ($arg =~ /RevokeRight-(\d+)-(.*?)-(\d+)-(.*?)$/) {
            my $principal_id = $1;
            my $object_type = $2;
            my $object_id = $3;
            my $right = $4;

            my $principal = RT::Principal->new($session{'CurrentUser'});
            $principal->Load($principal_id);
            next unless ($right);
            my ($val, $msg) = $principal->RevokeRight(ObjectType => $object_type, ObjectId => $object_id, Right => $right);
            push (@results, $msg);
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
        ARGSRef       => undef,
        AttributesRef => undef,
        Object        => undef,
        @_
    );

    my (@results);

    my $object     = $args{'Object'};
    my $attributes = $args{'AttributesRef'};
    my $ARGSRef    = $args{'ARGSRef'};

    foreach $attribute (@$attributes) {
        if ( ( defined $ARGSRef->{"$attribute"} )
            and ( $ARGSRef->{"$attribute"} ne $object->$attribute() ) )
        {
            $ARGSRef->{"$attribute"} =~ s/\r\n/\n/gs;

            my $method = "Set$attribute";
            my ( $code, $msg ) = $object->$method( $ARGSRef->{"$attribute"} );

	    push @results, loc($attribute) . ': '. loc_match(
		$msg,
"[_1] could not be set to [_2].",	# loc
"That is already the current value",	# loc
"No value sent to _Set!\n",		# loc
"Illegal value for [_1]",		# loc
"The new value has been set.",		# loc
"No column specified",			# loc
"Immutable field",			# loc
"Nonexistant field?",			# loc
"Invalid data",				# loc
"Couldn't find row",			# loc
"Missing a primary key?: [_1]",		# loc
"Found Object",				# loc
	    );
        }
    }
    return (@results);
}

# }}}


# {{{ Sub ProcessCustomFieldUpdates

sub ProcessCustomFieldUpdates {
    my %args = (
        CustomFieldObj => undef,
        ARGSRef        => undef,
        @_
    );

    my $Object  = $args{'CustomFieldObj'};
    my $ARGSRef = $args{'ARGSRef'};

    my @attribs = qw( Name Type Description Queue SortOrder);
    my @results = UpdateRecordObject(
        AttributesRef => \@attribs,
        Object        => $Object,
        ARGSRef       => $ARGSRef
    );

    if ( $ARGSRef->{ "CustomField-" . $Object->Id . "-AddValue-Name" } ) {

        my ( $addval, $addmsg ) = $Object->AddValue(
            Name =>
              $ARGSRef->{ "CustomField-" . $Object->Id . "-AddValue-Name" },
            Description => $ARGSRef->{ "CustomField-"
                  . $Object->Id
                  . "-AddValue-Description" },
            SortOrder => $ARGSRef->{ "CustomField-"
                  . $Object->Id
                  . "-AddValue-SortOrder" },
        );
        push ( @results, $addmsg );
    }
    my @delete_values = (
        ref $ARGSRef->{ 'CustomField-' . $Object->Id . '-DeleteValue' } eq
          'ARRAY' )
      ? @{ $ARGSRef->{ 'CustomField-' . $Object->Id . '-DeleteValue' } }
      : ( $ARGSRef->{ 'CustomField-' . $Object->Id . '-DeleteValue' } );
    foreach my $id (@delete_values) {
        next unless defined $id;
        my ( $err, $msg ) = $Object->DeleteValue($id);
        push ( @results, $msg );
    }
    return (@results);
}

# }}}

# {{{ sub ProcessTicketBasics

=head2 ProcessTicketBasics ( TicketObj => $Ticket, ARGSRef => \%ARGS );

Returns an array of results messages.

=cut

sub ProcessTicketBasics {

    my %args = (
        TicketObj => undef,
        ARGSRef   => undef,
        @_
    );

    my $TicketObj = $args{'TicketObj'};
    my $ARGSRef   = $args{'ARGSRef'};

    # {{{ Set basic fields 
    my @attribs = qw(
      Subject
      FinalPriority
      Priority
      TimeWorked
      TimeLeft
      Status
      Queue
    );

    if ( $ARGSRef->{'Queue'} and ( $ARGSRef->{'Queue'} !~ /^(\d+)$/ ) ) {
        my $tempqueue = RT::Queue->new($RT::SystemUser);
        $tempqueue->Load( $ARGSRef->{'Queue'} );
        if ( $tempqueue->id ) {
            $ARGSRef->{'Queue'} = $tempqueue->Id();
        }
    }

    my @results = UpdateRecordObject(
        AttributesRef => \@attribs,
        Object        => $TicketObj,
        ARGSRef       => $ARGSRef
    );

    # We special case owner changing, so we can use ForceOwnerChange
    if ( $ARGSRef->{'Owner'} && ( $TicketObj->Owner != $ARGSRef->{'Owner'} ) ) {
        my ($ChownType);
        if ( $ARGSRef->{'ForceOwnerChange'} ) {
            $ChownType = "Force";
        }
        else {
            $ChownType = "Give";
        }

        my ( $val, $msg ) =
          $TicketObj->SetOwner( $ARGSRef->{'Owner'}, $ChownType );
        push ( @results, "$msg" );
    }

    # }}}

    return (@results);
}

# }}}

# {{{ Sub ProcessTicketCustomFieldUpdates

sub ProcessTicketCustomFieldUpdates {
    my %args = (
        ARGSRef => undef,
        @_
    );

    my @results;

    my $ARGSRef = $args{'ARGSRef'};

    # Build up a list of tickets that we want to work with
    my %tickets_to_mod;
    my %custom_fields_to_mod;
    foreach my $arg ( keys %{$ARGSRef} ) {
        if ( $arg =~ /^Ticket-(\d+)-CustomField-(\d+)-/ ) {

            # For each of those tickets, find out what custom fields we want to work with.
            $custom_fields_to_mod{$1}{$2} = 1;
        }
    }

    # For each of those tickets
    foreach my $tick ( keys %custom_fields_to_mod ) {
        my $Ticket = RT::Ticket->new( $session{'CurrentUser'} );
        $Ticket->Load($tick);

        # For each custom field  
        foreach my $cf ( keys %{ $custom_fields_to_mod{$tick} } ) {

            foreach my $arg ( keys %{$ARGSRef} ) {
                next unless ( $arg =~ /^Ticket-$tick-CustomField-$cf-/ );
                my @values =
                  ( ref( $ARGSRef->{$arg} ) eq 'ARRAY' ) 
                  ? @{ $ARGSRef->{$arg} }
                  : ( $ARGSRef->{$arg} );
                if ( ( $arg =~ /-AddValue$/ ) || ( $arg =~ /-Value$/ ) ) {
                    foreach my $value (@values) {
                        next unless ($value);
                        my ( $val, $msg ) = $Ticket->AddCustomFieldValue(
                            Field => $cf,
                            Value => $value
                        );
                        push ( @results, $msg );
                    }
                }
                elsif ( $arg =~ /-DeleteValues$/ ) {
                    foreach my $value (@values) {
                        next unless ($value);
                        my ( $val, $msg ) = $Ticket->DeleteCustomFieldValue(
                            Field => $cf,
                            Value => $value
                        );
                        push ( @results, $msg );
                    }
                }
                elsif ( $arg =~ /-Values$/ ) {
                    my $cf_values = $Ticket->CustomFieldValues($cf);

                    my %values_hash;
                    foreach my $value (@values) {
                        next unless ($value);

                        # build up a hash of values that the new set has
                        $values_hash{$value} = 1;

                        unless ( $cf_values->HasEntry($value) ) {
                            my ( $val, $msg ) = $Ticket->AddCustomFieldValue(
                                Field => $cf,
                                Value => $value
                            );
                            push ( @results, $msg );
                        }

                    }
                    while ( my $cf_value = $cf_values->Next ) {
                        push ( @results,
                            "Thinking about deleting "
                              . $cf_value->Id . "-"
                              . $cf_value->Content
                              . " for custom field $cf" );
                        unless ( $values_hash{ $cf_value->Content } == 1 ) {
                            push ( @results,
                                "Deleting "
                                  . $cf_value->Id . "-"
                                  . $cf_value->Content
                                  . " for custom field $cf" );
                            my ( $val, $msg ) = $Ticket->DeleteCustomFieldValue(
                                Field => $cf,
                                Value => $cf_value->Content
                            );
                            push ( @results, $msg );

                        }

                    }
                }
                else {
                    push ( @results,
"User asked for an unknown update type for custom field "
                          . $cf->Name
                          . " for ticket "
                          . $ticket->id );
                }
            }
        }
        return (@results);
    }
}

# }}}

# {{{ sub ProcessTicketWatchers

=head2 ProcessTicketWatchers ( TicketObj => $Ticket, ARGSRef => \%ARGS );

Returns an array of results messages.

=cut

sub ProcessTicketWatchers {
    my %args = (
        TicketObj => undef,
        ARGSRef   => undef,
        @_
    );
    my (@results);

    my $Ticket  = $args{'TicketObj'};
    my $ARGSRef = $args{'ARGSRef'};

    # {{{ Munge watchers

    foreach my $key ( keys %$ARGSRef ) {

        # {{{ Delete deletable watchers
        if ( ( $key =~ /^Ticket-DelWatcher-Type-(.*)-Principal-(\d+)$/ )  ) {
            my ( $code, $msg ) = 
                $Ticket->DeleteWatcher(PrincipalId => $2,
                                       Type => $1);
            push @results, $msg;
        }

        # Delete watchers in the simple style demanded by the bulk manipulator
        elsif ( $key =~ /^Delete(Requestor|Cc|AdminCc)$/ ) {
            my ( $code, $msg ) = $Ticket->DeleteWatcher( Type => $ARGSRef->{$key}, PrincipalId => $1 );
            push @results, $msg;
        }

        # }}}

        # Add new wathchers by email address      
        elsif ( ( $ARGSRef->{$key} =~ /^(AdminCc|Cc|Requestor)$/ )
            and ( $key =~ /^WatcherTypeEmail(\d*)$/ ) )
        {

            #They're in this order because otherwise $1 gets clobbered :/
            my ( $code, $msg ) = $Ticket->AddWatcher(
                Type  => $ARGSRef->{$key},
                Email => $ARGSRef->{ "WatcherAddressEmail" . $1 }
            );
            push @results, $msg;
        }

        #Add requestors in the simple style demanded by the bulk manipulator
        elsif ( $key =~ /^Add(Requestor|Cc|AdminCc)$/ ) {
            my ( $code, $msg ) = $Ticket->AddWatcher(
                Type  => $1,
                Email => $ARGSRef->{$key}
            );
            push @results, $msg;
        }

        # Add new  watchers by owner
        elsif ( ( $ARGSRef->{$key} =~ /^(AdminCc|Cc|Requestor)$/ )
            and ( $key =~ /^Ticket-AddWatcher-Principal-(\d*)$/ ) ) {

            #They're in this order because otherwise $1 gets clobbered :/
            my ( $code, $msg ) =
              $Ticket->AddWatcher( Type => $ARGSRef->{$key}, PrincipalId => $1 );
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
    my %args = (
        TicketObj => undef,
        ARGSRef   => undef,
        @_
    );

    my $Ticket  = $args{'TicketObj'};
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
        my ( $code, $msg );

        my $DateObj = RT::Date->new( $session{'CurrentUser'} );

        #If it's something other than just whitespace
        if ( $ARGSRef->{ $field . '_Date' } ne '' ) {
            $DateObj->Set(
                Format => 'unknown',
                Value  => $ARGSRef->{ $field . '_Date' }
            );
            my $obj = $field . "Obj";
            if ( ( defined $DateObj->Unix )
                and ( $DateObj->Unix ne $Ticket->$obj()->Unix() ) )
            {
                my $method = "Set$field";
                my ( $code, $msg ) = $Ticket->$method( $DateObj->ISO );
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
    my %args = (
        TicketObj => undef,
        ARGSRef   => undef,
        @_
    );

    my $Ticket  = $args{'TicketObj'};
    my $ARGSRef = $args{'ARGSRef'};

    my (@results);

    # Delete links that are gone gone gone.
    foreach my $arg ( keys %$ARGSRef ) {
        if ( $arg =~ /DeleteLink-(.*?)-(DependsOn|MemberOf|RefersTo)-(.*)$/ ) {
            my $base   = $1;
            my $type   = $2;
            my $target = $3;

            push @results,
              "Trying to delete: Base: $base Target: $target  Type $type";
            my ( $val, $msg ) = $Ticket->DeleteLink(
                Base   => $base,
                Type   => $type,
                Target => $target
            );

            push @results, $msg;

        }

    }

    my @linktypes = qw( DependsOn MemberOf RefersTo );

    foreach my $linktype (@linktypes) {

        for my $luri ( split ( / /, $ARGSRef->{ $Ticket->Id . "-$linktype" } ) )
        {
            $luri =~ s/\s*$//;    # Strip trailing whitespace
            my ( $val, $msg ) = $Ticket->AddLink(
                Target => $luri,
                Type   => $linktype
            );
            push @results, $msg;
        }

        for my $luri ( split ( / /, $ARGSRef->{ "$linktype-" . $Ticket->Id } ) )
        {
            my ( $val, $msg ) = $Ticket->AddLink(
                Base => $luri,
                Type => $linktype
            );

            push @results, $msg;
        }
    }

    #Merge if we need to
    if ( $ARGSRef->{ $Ticket->Id . "-MergeInto" } ) {
        my ( $val, $msg ) =
          $Ticket->MergeInto( $ARGSRef->{ $Ticket->Id . "-MergeInto" } );
        push @results, $msg;
    }

    return (@results);
}

# }}}

1;
