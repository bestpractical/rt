# BEGIN BPS TAGGED BLOCK {{{
# 
# COPYRIGHT:
#  
# This software is Copyright (c) 1996-2007 Best Practical Solutions, LLC 
#                                          <jesse@bestpractical.com>
# 
# (Except where explicitly superseded by other copyright notices)
# 
# 
# LICENSE:
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
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA
# 02110-1301 or visit their web page on the internet at
# http://www.gnu.org/copyleft/gpl.html.
# 
# 
# CONTRIBUTION SUBMISSION POLICY:
# 
# (The following paragraph is not intended to limit the rights granted
# to you to modify and distribute this software under the terms of
# the GNU General Public License and is only of importance to you if
# you choose to contribute your changes and enhancements to the
# community by submitting them to Best Practical Solutions, LLC.)
# 
# By intentionally submitting any modifications, corrections or
# derivatives to this work, or any other work intended for use with
# Request Tracker, to Best Practical Solutions, LLC, you confirm that
# you are the copyright holder for those contributions and you grant
# Best Practical Solutions,  LLC a nonexclusive, worldwide, irrevocable,
# royalty-free, perpetual, license to use, copy, create derivative
# works based on those contributions, and sublicense and distribute
# those contributions and any derivatives thereof.
# 
# END BPS TAGGED BLOCK }}}
## Portions Copyright 2000 Tobias Brox <tobix@fsck.com>

## This is a library of static subs to be used by the Mason web
## interface to RT


=head1 NAME

RT::Interface::Web


=cut


package RT::Interface::Web;
use HTTP::Date;

use strict;
use warnings;


use RT::SavedSearches;

# {{{ EscapeUTF8

=head2 EscapeUTF8 SCALARREF

does a css-busting but minimalist escaping of whatever html you're passing in.

=cut

sub EscapeUTF8  {
    my $ref = shift;
    return unless defined $$ref;

    $$ref =~ s/&/&#38;/g;
    $$ref =~ s/</&lt;/g; 
    $$ref =~ s/>/&gt;/g;
    $$ref =~ s/\(/&#40;/g;
    $$ref =~ s/\)/&#41;/g;
    $$ref =~ s/"/&#34;/g;
    $$ref =~ s/'/&#39;/g;
}

# }}}

# {{{ EscapeURI

=head2 EscapeURI SCALARREF

Escapes URI component according to RFC2396

=cut

use Encode qw();
sub EscapeURI {
    my $ref = shift;
    return unless defined $$ref;

    use bytes;
    $$ref =~ s/([^a-zA-Z0-9_.!~*'()-])/uc sprintf("%%%02X", ord($1))/eg;
}

# }}}

# {{{ WebCanonicalizeInfo

=head2 WebCanonicalizeInfo();

Different web servers set different environmental varibles. This
function must return something suitable for REMOTE_USER. By default,
just downcase $ENV{'REMOTE_USER'}

=cut

sub WebCanonicalizeInfo {
    return $ENV{'REMOTE_USER'}? lc $ENV{'REMOTE_USER'}: $ENV{'REMOTE_USER'};
}

# }}}

# {{{ WebExternalAutoInfo

=head2 WebExternalAutoInfo($user);

Returns a hash of user attributes, used when WebExternalAuto is set.

=cut

sub WebExternalAutoInfo {
    my $user = shift;

    my %user_info;

    $user_info{'Privileged'} = 1;

    if ($^O !~ /^(?:riscos|MacOS|MSWin32|dos|os2)$/) {
        # Populate fields with information from Unix /etc/passwd

        my ($comments, $realname) = (getpwnam($user))[5, 6];
        $user_info{'Comments'} = $comments if defined $comments;
        $user_info{'RealName'} = $realname if defined $realname;
    }
    elsif ($^O eq 'MSWin32' and eval 'use Net::AdminMisc; 1') {
        # Populate fields with information from NT domain controller
    }

    # and return the wad of stuff
    return {%user_info};
}

# }}}



=head2 Redirect URL

This routine ells the current user's browser to redirect to URL.  
Additionally, it unties the user's currently active session, helping to avoid 
A bug in Apache::Session 1.81 and earlier which clobbers sessions if we try to use 
a cached DBI statement handle twice at the same time.

=cut


sub Redirect {
    my $redir_to = shift;
    untie $HTML::Mason::Commands::session;
    my $uri = URI->new($redir_to);
    my $server_uri = URI->new( RT->Config->Get('WebURL') );

    # If the user is coming in via a non-canonical
    # hostname, don't redirect them to the canonical host,
    # it will just upset them (and invalidate their credentials)
    if ($uri->host  eq $server_uri->host && 
        $uri->port eq $server_uri->port) {
            $uri->host($ENV{'HTTP_HOST'});
            $uri->port($ENV{'SERVER_PORT'});
        }

    $HTML::Mason::Commands::m->redirect($uri->canonical);
    $HTML::Mason::Commands::m->abort;
}


=head2 StaticFileHeaders 

Send the browser a few headers to try to get it to (somewhat agressively)
cache RT's static Javascript and CSS files.

This routine could really use _accurate_ heuristics. (XXX TODO)

=cut

sub StaticFileHeaders {
    # Expire things in a month.
    $HTML::Mason::Commands::r->headers_out->{'Expires'} = HTTP::Date::time2str( time() + 2592000 );

    # Last modified at server start time
    $HTML::Mason::Commands::r->headers_out->{'Last-Modified'} = HTTP::Date::time2str($^T);

}


package HTML::Mason::Commands;

use strict;
use warnings;

use vars qw/$r $m %session/;


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
    elsif ( my $u = eval { RT::CurrentUser->new($RT::SystemUser->Id) } ) {
        return ($u->loc(@_));
    }
    else {
        # pathetic case -- SystemUser is gone.
        return $_[0];
    }
}

# }}}


# {{{ loc_fuzzy

=head2 loc_fuzzy STRING

loc_fuzzy is for handling localizations of messages that may already
contain interpolated variables, typically returned from libraries
outside RT's control.  It takes the message string and extracts the
variable array automatically by matching against the candidate entries
inside the lexicon file.

=cut

sub loc_fuzzy {
    my $msg  = shift;
    
    if ($session{'CurrentUser'} && 
        UNIVERSAL::can($session{'CurrentUser'}, 'loc')){
        return($session{'CurrentUser'}->loc_fuzzy($msg));
    }
    else  {
        my $u = RT::CurrentUser->new($RT::SystemUser->Id);
        return ($u->loc_fuzzy($msg));
    }
}

# }}}


# {{{ sub Abort
# Error - calls Error and aborts
sub Abort {

    if ($session{'ErrorDocument'} && 
        $session{'ErrorDocumentType'}) {
        $r->content_type($session{'ErrorDocumentType'});
        $m->comp($session{'ErrorDocument'} , Why => shift);
        $m->abort;
    } 
    else  {
        $m->comp("/Elements/Error" , Why => shift);
        $m->abort;
    }
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

    my $MIMEObj = MakeMIMEEntity(
        Subject             => $ARGS{'Subject'},
        From                => $ARGS{'From'},
        Cc                  => $ARGS{'Cc'},
        Body                => $ARGS{'Content'},
    );

    if ( $ARGS{'Attachments'} ) {
        my $rv = $MIMEObj->make_multipart;
        $RT::Logger->error("Couldn't make multipart message")
            if !$rv || $rv !~ /^(?:DONE|ALREADY)$/;

        foreach ( values %{$ARGS{'Attachments'}} ) {
            unless ( $_ ) {
                $RT::Logger->error("Couldn't add empty attachemnt");
                next;
            }
            $MIMEObj->add_part($_);
        }
    }

    my %create_args = (
        Type            => $ARGS{'Type'} || 'ticket',
        Queue           => $ARGS{'Queue'},
        Owner           => $ARGS{'Owner'},
        InitialPriority => $ARGS{'InitialPriority'},
        FinalPriority   => $ARGS{'FinalPriority'},
        TimeLeft        => $ARGS{'TimeLeft'},
        TimeEstimated   => $ARGS{'TimeEstimated'},
        TimeWorked      => $ARGS{'TimeWorked'},
        Subject         => $ARGS{'Subject'},
        Status          => $ARGS{'Status'},
        Due             => $due->ISO,
        Starts          => $starts->ISO,
        MIMEObj         => $MIMEObj
    );

    my @temp_squelch;
    foreach my $type (qw(Requestors Cc AdminCc)) {
        my @tmp = Mail::Address->parse( $ARGS{ $type } );
        push @temp_squelch, map $_->address, @tmp
            if grep $_ eq $type, @{ $ARGS{'SkipNotification'} || [] };

        $create_args{ $type } = [
            grep $_, map {
                my $user = RT::User->new( $RT::SystemUser );
                $user->LoadOrCreateByEmail( $_ );
                # convert to ids to avoid work later
                $user->id;
            } @tmp
        ];
    }
    # XXX: workaround for name conflict :(
    $create_args{'Requestor'} = delete $create_args{'Requestors'};

    if ( @temp_squelch ) {
        require RT::Action::SendEmail;
        RT::Action::SendEmail->SquelchMailTo( RT::Action::SendEmail->SquelchMailTo, @temp_squelch );
    }

    if ( $ARGS{'AttachTickets'} ) {
        require RT::Action::SendEmail;
        RT::Action::SendEmail->AttachTickets(
            RT::Action::SendEmail->AttachTickets,
            ref $ARGS{'AttachTickets'}?
                @{ $ARGS{'AttachTickets'} }
                :( $ARGS{'AttachTickets'} )
        );
    }

    foreach my $arg (keys %ARGS) {
        next if $arg =~ /-(?:Magic|Category)$/;

        if ($arg =~ /^Object-RT::Transaction--CustomField-/) {
            $create_args{$arg} = $ARGS{$arg};
        }
        # Object-RT::Ticket--CustomField-3-Values
        elsif ( $arg =~ /^Object-RT::Ticket--CustomField-(\d+)(.*?)$/ ) {
            my $cfid = $1;

            my $cf = RT::CustomField->new( $session{'CurrentUser'} );
            $cf->Load( $cfid );
            unless ( $cf->id ) {
                $RT::Logger->error( "Couldn't load custom field #". $cfid );
                next;
            }

            if ( $arg =~ /-Upload$/ ) {
                $create_args{"CustomField-$cfid"} = _UploadedFile( $arg );
                next;
            }

            my $type = $cf->Type;

            my @values = ();
            if ( ref $ARGS{ $arg } eq 'ARRAY' ) {
                @values = @{ $ARGS{ $arg } };
            } elsif ( $type =~ /text/i ) {
                @values = ($ARGS{ $arg });
            } else {
                @values = split /\r*\n/, $ARGS{ $arg } || '';
            }
            @values = grep $_ ne '',
                map {
                    s/\r+\n/\n/g;
                    s/^\s+//;
                    s/\s+$//;
                    $_;
                }
                grep defined, @values;

            $create_args{"CustomField-$cfid"} = \@values;
        }
    }

    # turn new link lists into arrays, and pass in the proper arguments
    my %map = (
        'new-DependsOn' => 'DependsOn',
        'DependsOn-new' => 'DependedOnBy',
        'new-MemberOf'  => 'Parents',
        'MemberOf-new'  => 'Children',
        'new-RefersTo'  => 'RefersTo',
        'RefersTo-new'  => 'ReferredToBy',
    );
    foreach my $key ( keys %map ) {
        next unless $ARGS{ $key };
        $create_args{ $map{ $key } } = [ grep $_, split ' ', $ARGS{ $key } ];
        
    }
 
    my ( $id, $Trans, $ErrMsg ) = $Ticket->Create(%create_args);
    unless ( $id && $Trans ) {
        Abort($ErrMsg);
    }

    push ( @Actions, split("\n", $ErrMsg) );
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

=head2 ProcessUpdateMessage

Takes paramhash with fields ARGSRef, TicketObj and SkipSignatureOnly.

Don't write message if it only contains current user's signature and
SkipSignatureOnly argument is true. Function anyway adds attachments
and updates time worked field even if skips message. The default value
is true.

=cut

sub ProcessUpdateMessage {

    #TODO document what else this takes.
    my %args = (
        ARGSRef   => undef,
        TicketObj => undef,
        SkipSignatureOnly => 1,
        @_
    );

    my @results;

    #Make the update content have no 'weird' newlines in it
    return () unless    $args{ARGSRef}->{'UpdateTimeWorked'}
                     || $args{ARGSRef}->{'UpdateAttachments'}
                     || $args{ARGSRef}->{'UpdateContent'};

    $args{ARGSRef}->{'UpdateContent'} =~ s/\r+\n/\n/g if $args{ARGSRef}->{'UpdateContent'};

    # skip updates if the content contains only user's signature
    # and we don't update other fields
    if ( $args{'SkipSignatureOnly'} ) {
        my $sig = $args{'TicketObj'}->CurrentUser->UserObj->Signature || '';
        $sig =~ s/^\s*|\s*$//g;
        if( $args{ARGSRef}->{'UpdateContent'} =~ /^\s*(--)?\s*\Q$sig\E\s*$/ ) {
            return () unless $args{ARGSRef}->{'UpdateTimeWorked'} ||
                             $args{ARGSRef}->{'UpdateAttachments'};

            # we have to create transaction, but we don't create attachment
            # XXX: this couldn't work as expected
            $args{ARGSRef}->{'UpdateContent'} = '';
        }
    }

    if ( $args{ARGSRef}->{'UpdateSubject'} eq $args{'TicketObj'}->Subject ) {
        $args{ARGSRef}->{'UpdateSubject'} = undef;
    }

    my $Message = MakeMIMEEntity(
        Subject => $args{ARGSRef}->{'UpdateSubject'},
        Body    => $args{ARGSRef}->{'UpdateContent'},
    );

    $Message->head->add( 'Message-ID' => 
          "<rt-"
          . $RT::VERSION . "-"
          . $$ . "-"
          . CORE::time() . "-"
          . int(rand(2000)) . "."
          . $args{'TicketObj'}->id . "-"
          . "0" . "-"  # Scrip
          . "0" . "@"  # Email sent
              . RT->Config->Get('Organization')
          . ">" );
    my $old_txn = RT::Transaction->new( $session{'CurrentUser'} );
    if ( $args{ARGSRef}->{'QuoteTransaction'} ) {
        $old_txn->Load( $args{ARGSRef}->{'QuoteTransaction'} );
    }
    else {
        $old_txn = $args{TicketObj}->Transactions->First();
    }

    if ( $old_txn->Message and my $msg = $old_txn->Message->First ) {
        my @in_reply_to = split(/\s+/m, $msg->GetHeader('In-Reply-To') || '');  
        my @references = split(/\s+/m, $msg->GetHeader('References') || '' );  
        my @msgid = split(/\s+/m, $msg->GetHeader('Message-ID') || '');
        #XXX: custom header should begin with X- otherwise is violation of the standard
        my @rtmsgid = split(/\s+/m, $msg->GetHeader('RT-Message-ID') || ''); 

        $Message->head->replace( 'In-Reply-To', join(' ', @rtmsgid ? @rtmsgid : @msgid));
        $Message->head->replace( 'References', join(' ', @references, @msgid, @rtmsgid));
    }

    if ( $args{ARGSRef}->{'UpdateAttachments'} ) {
        $Message->make_multipart;
        $Message->add_part($_)
           foreach values %{ $args{ARGSRef}->{'UpdateAttachments'} };
    }

    if ( $args{ARGSRef}->{'AttachTickets'} ) {
        require RT::Action::SendEmail;
        RT::Action::SendEmail->AttachTickets(
            RT::Action::SendEmail->AttachTickets,
            ref $args{ARGSRef}->{'AttachTickets'}?
                @{ $args{ARGSRef}->{'AttachTickets'} }
                :( $args{ARGSRef}->{'AttachTickets'} )
        );
    }

           my  $bcc = $args{ARGSRef}->{'UpdateBcc'};
           my  $cc = $args{ARGSRef}->{'UpdateCc'};

    my %message_args = (
            CcMessageTo  => $cc,
            BccMessageTo => $bcc,
            Sign         => $args{ARGSRef}->{'Sign'},
            Encrypt      => $args{ARGSRef}->{'Encrypt'},
            MIMEObj      => $Message,
            TimeTaken    => $args{ARGSRef}->{'UpdateTimeWorked'});


    if ( not  $args{'ARGRef'}->{'UpdateIgnoreAddressCheckboxes'}) {
        foreach my $key ( keys %{ $args{ARGSRef} } ) {
            if ( $key =~ /^Update(Cc|Bcc)-(.*)$/ ) {
                my $var   = ucfirst($1).'MessageTo';
                my $value = $2;
                {
                    if ( $args{$var} ) {
                        $message_args{$var} .= ", $value";
                    } else {
                        $message_args{$var} = $value;
                    }
                }
            }

        }
    }



    if ( $args{ARGSRef}->{'UpdateType'} =~ /^(private|public)$/ ) {
        my ( $Transaction, $Description, $Object ) = $args{TicketObj}->Comment(%message_args);
        push( @results, $Description );
        $Object->UpdateCustomFields( ARGSRef => $args{ARGSRef} ) if $Object;
    }
    elsif ( $args{ARGSRef}->{'UpdateType'} eq 'response' ) {
        my ( $Transaction, $Description, $Object ) =
        $args{TicketObj}->Correspond(%message_args);
        push( @results, $Description );
        $Object->UpdateCustomFields( ARGSRef => $args{ARGSRef} ) if $Object;
    }
    else {
        push(
            @results,
            loc("Update type was neither correspondence nor comment.") . " "
              . loc("Update not recorded.")
        );
    }
    return @results;
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
        @_,
    );
    my $Message = MIME::Entity->build(
        Type    => 'multipart/mixed',
        Subject => $args{'Subject'} || "",
        From    => $args{'From'},
        Cc      => $args{'Cc'},        
    );

    if ( defined $args{'Body'} && length $args{'Body'} ) {
        # Make the update content have no 'weird' newlines in it
        $args{'Body'} =~ s/\r\n/\n/gs;

        # MIME::Head is not happy in utf-8 domain.  This only happens
        # when processing an incoming email (so far observed).
        no utf8;
        use bytes;
        $Message->attach(
            Type    => 'text/plain',
            Charset => 'UTF-8',
            Data    => $args{'Body'},
        );
    }

    if ( $args{'AttachmentFieldName'} ) {

        my $cgi_object = $m->cgi_object;

        if ( my $filehandle = $cgi_object->upload( $args{'AttachmentFieldName'} ) ) {

            my (@content,$buffer);
            while ( my $bytesread = read( $filehandle, $buffer, 4096 ) ) {
                push @content, $buffer;
            }

            my $uploadinfo = $cgi_object->uploadInfo($filehandle);

            # Prefer the cached name first over CGI.pm stringification.
            my $filename = $RT::Mason::CGI::Filename;
            $filename = "$filehandle" unless defined($filename);
                           
            $filename =~ s#^.*[\\/]##;


            
            $Message->attach(
                Type     => $uploadinfo->{'Content-Type'},
                Filename => Encode::decode_utf8($filename),
                Data     => \@content,
            );
        }
    }

    $Message->make_singlepart;
    RT::I18N::SetMIMEEntityToUTF8($Message); # convert text parts into utf-8

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
    elsif ( $args{ARGS}->{'GotoPage'} > 0 ) {
        $session{'tickets'}->GotoPage( $args{ARGS}->{GotoPage} - 1 );
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
     if ( $args{ARGS}->{'ValueOfWatcherRole'} ne '' ) {
         $session{'tickets'}->LimitWatcher(
             TYPE     => $args{ARGS}->{'WatcherRole'},
             VALUE    => $args{ARGS}->{'ValueOfWatcherRole'},
             OPERATOR => $args{ARGS}->{'WatcherRoleOp'},

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
        my $val = $args{ARGS}->{'ValueOfSubject'};
        if ($args{ARGS}->{'SubjectOp'} =~ /like/) {
            $val = "%".$val."%";
        }
        $session{'tickets'}->LimitSubject(
            VALUE    => $val,
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
            $session{'tickets'}->LimitDate(
                FIELD => $args{ARGS}->{'DateType'},
                VALUE => $date,
                OPERATOR => $args{ARGS}->{'DateOp'},
            );
        }
    }

    # }}}    
    # {{{ Limit Content
    if ( $args{ARGS}->{'ValueOfAttachmentField'} ne '' ) {
        my $val = $args{ARGS}->{'ValueOfAttachmentField'};
        if ($args{ARGS}->{'AttachmentFieldOp'} =~ /like/) {
            $val = "%".$val."%";
        }
        $session{'tickets'}->Limit(
            FIELD   => $args{ARGS}->{'AttachmentField'},
            VALUE    => $val,
            OPERATOR => $args{ARGS}->{'AttachmentFieldOp'},
        );
    }

    # }}}   

 # {{{ Limit CustomFields

    foreach my $arg ( keys %{ $args{ARGS} } ) {
        next unless ( $args{ARGS}->{$arg} );
        next unless $arg =~ /^CustomField(\d+)$/;
        my $id = $1;

        my $form = $args{ARGS}->{ $arg };
        my $oper = $args{ARGS}->{ "CustomFieldOp" . $id } || '';
        foreach my $value ( ref($form) ? @{$form} : ($form) ) {
            my $quote = 1;
            if ($oper =~ /like/i) {
                $value = "%".$value."%";
            }
            if ( $value =~ /^null$/i ) {

                #Don't quote the string 'null'
                $quote = 0;

                # Convert the operator to something apropriate for nulls
                $oper = 'IS'     if $oper eq '=';
                $oper = 'IS NOT' if $oper eq '!=';
            }
            $session{'tickets'}->LimitCustomField(
                CUSTOMFIELD => $id,
                OPERATOR    => $oper,
                QUOTEVALUE  => $quote,
                VALUE       => $value,
            );
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

    my $date_obj = RT::Date->new($session{'CurrentUser'});
    $date_obj->Set(
        Format => 'unknown',
        Value  => $date
    );
    return ( $date_obj->ISO );
}

# }}}

# {{{ sub ProcessACLChanges

sub ProcessACLChanges {
    my $ARGSref = shift;

    #XXX: why don't we get ARGSref like in other Process* subs?

    my @results;

    foreach my $arg (keys %$ARGSref) {
        next unless ( $arg =~ /^(GrantRight|RevokeRight)-(\d+)-(.+?)-(\d+)$/ );

        my ($method, $principal_id, $object_type, $object_id) = ($1, $2, $3, $4);

        my @rights;
        if ( UNIVERSAL::isa( $ARGSref->{$arg}, 'ARRAY' ) ) {
            @rights = @{$ARGSref->{$arg}}
        } else {
            @rights = $ARGSref->{$arg};
        }
        @rights = grep $_, @rights;
        next unless @rights;

        my $principal = RT::Principal->new( $session{'CurrentUser'} );
        $principal->Load( $principal_id );

        my $obj;
        if ($object_type eq 'RT::System') {
            $obj = $RT::System;
        } elsif ($RT::ACE::OBJECT_TYPES{$object_type}) {
            $obj = $object_type->new($session{'CurrentUser'});
            $obj->Load($object_id);
            unless( $obj->id ) {
                $RT::Logger->error("couldn't load $object_type #$object_id");
                next;
            }
        } else {
            $RT::Logger->error("object type '$object_type' is incorrect");
            push (@results, loc("System Error"). ': '.
                            loc("Rights could not be granted for [_1]", $object_type));
            next;
        }

        foreach my $right (@rights) {
            my ($val, $msg) = $principal->$method(Object => $obj, Right => $right);
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
        AttributePrefix => undef,
        @_
    );

    my $Object = $args{'Object'};
    my @results = $Object->Update(
        AttributesRef   => $args{'AttributesRef'},
        ARGSRef         => $args{'ARGSRef'},
        AttributePrefix => $args{'AttributePrefix'},
    );

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

    my @attribs = qw(Name Type Description Queue SortOrder);
    my @results = UpdateRecordObject(
        AttributesRef => \@attribs,
        Object        => $Object,
        ARGSRef       => $ARGSRef
    );

    my $prefix = "CustomField-" . $Object->Id;
    if ( $ARGSRef->{ "$prefix-AddValue-Name" } ) {
        my ( $addval, $addmsg ) = $Object->AddValue(
            Name        => $ARGSRef->{ "$prefix-AddValue-Name" },
            Description => $ARGSRef->{ "$prefix-AddValue-Description" },
            SortOrder   => $ARGSRef->{ "$prefix-AddValue-SortOrder" },
        );
        push ( @results, $addmsg );
    }

    my @delete_values = (
        ref $ARGSRef->{ "$prefix-DeleteValue" } eq 'ARRAY' )
      ? @{ $ARGSRef->{ "$prefix-DeleteValue" } }
      : ( $ARGSRef->{ "$prefix-DeleteValue" } );

    foreach my $id (@delete_values) {
        next unless defined $id;
        my ( $err, $msg ) = $Object->DeleteValue($id);
        push ( @results, $msg );
    }

    my $vals = $Object->Values();
    while (my $cfv = $vals->Next()) {
        if (my $so = $ARGSRef->{ "$prefix-SortOrder" . $cfv->Id }) {
            if ($cfv->SortOrder != $so) {
                my ( $err, $msg ) = $cfv->SetSortOrder($so);
                push ( @results, $msg );
            }
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
      TimeEstimated
      TimeWorked
      TimeLeft
      Type
      Status
      Queue
    );


    if ( $ARGSRef->{'Queue'} and ( $ARGSRef->{'Queue'} !~ /^(\d+)$/ ) ) {
        my $tempqueue = RT::Queue->new($RT::SystemUser);
        $tempqueue->Load( $ARGSRef->{'Queue'} );
        if ( $tempqueue->id ) {
            $ARGSRef->{'Queue'} = $tempqueue->id;
        }
    }


    # Status isn't a field that can be set to a null value.
    # RT core complains if you try
    delete $ARGSRef->{'Status'} unless $ARGSRef->{'Status'};
    
    my @results = UpdateRecordObject(
        AttributesRef => \@attribs,
        Object        => $TicketObj,
        ARGSRef       => $ARGSRef,
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
        push ( @results, $msg );
    }

    # }}}

    return (@results);
}

# }}}

sub ProcessTicketCustomFieldUpdates {
    my %args = @_;
    $args{'Object'} = delete $args{'TicketObj'};
    my $ARGSRef = { %{ $args{'ARGSRef'} } };

    # Build up a list of objects that we want to work with
    my %custom_fields_to_mod;
    foreach my $arg ( keys %$ARGSRef ) {
        if ( $arg =~ /^Ticket-(\d+-.*)/) {
            $ARGSRef->{"Object-RT::Ticket-$1"} = delete $ARGSRef->{$arg};
        }
        elsif ( $arg =~ /^CustomField-(\d+-.*)/) {
            $ARGSRef->{"Object-RT::Ticket--$1"} = delete $ARGSRef->{$arg};
        }
    }

    return ProcessObjectCustomFieldUpdates(%args, ARGSRef => $ARGSRef);
}

sub ProcessObjectCustomFieldUpdates {
    my %args = @_;
    my $ARGSRef = $args{'ARGSRef'};
    my @results;

    # Build up a list of objects that we want to work with
    my %custom_fields_to_mod;
    foreach my $arg ( keys %$ARGSRef ) {
        # format: Object-<object class>-<object id>-CustomField-<CF id>-<commands>
        next unless $arg =~ /^Object-([\w:]+)-(\d*)-CustomField-(\d+)-(.*)$/;

        # For each of those objects, find out what custom fields we want to work with.
        $custom_fields_to_mod{ $1 }{ $2 || 0 }{ $3 }{ $4 } = $ARGSRef->{ $arg };
    }

    # For each of those objects
    foreach my $class ( keys %custom_fields_to_mod ) {
        foreach my $id ( keys %{$custom_fields_to_mod{$class}} ) {
            my $Object = $args{'Object'};
            $Object = $class->new( $session{'CurrentUser'} )
                unless $Object && ref $Object eq $class;

            $Object->Load( $id ) unless ($Object->id || 0) == $id;
            unless ( $Object->id ) {
                $RT::Logger->warning("Couldn't load object $class #$id");
                next;
            }

            foreach my $cf ( keys %{ $custom_fields_to_mod{ $class }{ $id } } ) {
                my $CustomFieldObj = RT::CustomField->new( $session{'CurrentUser'} );
                $CustomFieldObj->LoadById( $cf );
                unless ( $CustomFieldObj->id ) {
                    $RT::Logger->warning("Couldn't load custom field #$id");
                    next;
                }
                push @results, _ProcessObjectCustomFieldUpdates(
                    Prefix      => "Object-$class-$id-CustomField-$cf-",
                    Object      => $Object,
                    CustomField => $CustomFieldObj,
                    ARGS        => $custom_fields_to_mod{$class}{$id}{$cf},
                );
            }
        }
    }
    return @results;
}

sub _ProcessObjectCustomFieldUpdates {
    my %args = @_;
    my $cf = $args{'CustomField'};
    my $cf_type = $cf->Type;

    my @results;
    foreach my $arg ( keys %{ $args{'ARGS'} } ) {

        # since http won't pass in a form element with a null value, we need
        # to fake it
        if ( $arg eq 'Values-Magic' ) {
            # We don't care about the magic, if there's really a values element;
            next if $args{'ARGS'}->{'Value'} || $args{'ARGS'}->{'Values'};

            # "Empty" values does not mean anything for Image and Binary fields
            next if $cf_type =~ /^(?:Image|Binary)$/;

            $arg = 'Values';
            $args{'ARGS'}->{'Values'} = undef;
        }

        my @values = ();
        if ( ref $args{'ARGS'}->{ $arg } eq 'ARRAY' ) {
            @values = @{ $args{'ARGS'}->{$arg} };
        } elsif ( $cf_type =~ /text/i ) { # Both Text and Wikitext
            @values = ($args{'ARGS'}->{$arg});
        } else {
            @values = split /\r*\n/, $args{'ARGS'}->{ $arg } || '';
        }
        @values = grep $_ ne '',
            map {
                s/\r+\n/\n/g;
                s/^\s+//;
                s/\s+$//;
                $_;
            }
            grep defined, @values;
        
        if ( $arg eq 'AddValue' || $arg eq 'Value' ) {
            foreach my $value (@values) {
                my ( $val, $msg ) = $args{'Object'}->AddCustomFieldValue(
                    Field => $cf->id,
                    Value => $value
                );
                push ( @results, $msg );
            }
        }
        elsif ( $arg eq 'Upload' ) {
            my $value_hash = _UploadedFile( $args{'Prefix'} . $arg ) or next;
            my ( $val, $msg ) = $args{'Object'}->AddCustomFieldValue(
                %$value_hash,
                Field => $cf,
            );
            push ( @results, $msg );
        }
        elsif ( $arg eq 'DeleteValues' ) {
            foreach my $value ( @values ) {
                my ( $val, $msg ) = $args{'Object'}->DeleteCustomFieldValue(
                    Field => $cf,
                    Value => $value,
                );
                push ( @results, $msg );
            }
        }
        elsif ( $arg eq 'DeleteValueIds' ) {
            foreach my $value ( @values ) {
                my ( $val, $msg ) = $args{'Object'}->DeleteCustomFieldValue(
                    Field   => $cf,
                    ValueId => $value,
                );
                push ( @results, $msg );
            }
        }
        elsif ( $arg eq 'Values' && !$cf->Repeated ) {
            my $cf_values = $args{'Object'}->CustomFieldValues( $cf->id );

            my %values_hash;
            foreach my $value ( @values ) {
                # build up a hash of values that the new set has
                $values_hash{$value} = 1;
                next if $cf_values->HasEntry( $value );

                my ( $val, $msg ) = $args{'Object'}->AddCustomFieldValue(
                    Field => $cf,
                    Value => $value
                );
                push ( @results, $msg );
            }

            $cf_values->RedoSearch;
            while ( my $cf_value = $cf_values->Next ) {
                next if $values_hash{ $cf_value->Content };

                my ( $val, $msg ) = $args{'Object'}->DeleteCustomFieldValue(
                    Field => $cf,
                    Value => $cf_value->Content
                );
                push ( @results, $msg);
            }
        }
        elsif ( $arg eq 'Values' ) {
            my $cf_values = $args{'Object'}->CustomFieldValues( $cf->id );

            # keep everything up to the point of difference, delete the rest
            my $delete_flag;
            foreach my $old_cf (@{$cf_values->ItemsArrayRef}) {
                if (!$delete_flag and @values and $old_cf->Content eq $values[0]) {
                    shift @values;
                    next;
                }

                $delete_flag ||= 1;
                $old_cf->Delete;
            }

            # now add/replace extra things, if any
            foreach my $value ( @values ) {
                my ( $val, $msg ) = $args{'Object'}->AddCustomFieldValue(
                    Field => $cf,
                    Value => $value
                );
                push ( @results, $msg );
            }
        }
        else {
            push ( @results,
                loc("User asked for an unknown update type for custom field [_1] for [_2] object #[_3]",
                $cf->Name, ref $args{'Object'}, $args{'Object'}->id )
            );
        }
    }
    return @results;
}

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

    # Munge watchers

    foreach my $key ( keys %$ARGSRef ) {

        # Delete deletable watchers
        if ( $key =~ /^Ticket-DeleteWatcher-Type-(.*)-Principal-(\d+)$/ ) {
            my ( $code, $msg ) = $Ticket->DeleteWatcher(
                PrincipalId => $2,
                Type        => $1
            );
            push @results, $msg;
        }

        # Delete watchers in the simple style demanded by the bulk manipulator
        elsif ( $key =~ /^Delete(Requestor|Cc|AdminCc)$/ ) {
            my ( $code, $msg ) = $Ticket->DeleteWatcher(
                Email => $ARGSRef->{$key},
                Type  => $1
            );
            push @results, $msg;
        }

        # Add new wathchers by email address
        elsif ( ( $ARGSRef->{$key} || '' ) =~ /^(?:AdminCc|Cc|Requestor)$/
            and $key =~ /^WatcherTypeEmail(\d*)$/ )
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
        elsif ( $key =~ /^Ticket-AddWatcher-Principal-(\d*)$/ ) {
            my $principal_id = $1;
            my $form = $ARGSRef->{$key};
            foreach my $value ( ref($form) ? @{$form} : ($form) ) {
                next unless $value =~ /^(?:AdminCc|Cc|Requestor)$/i;

                my ( $code, $msg ) = $Ticket->AddWatcher(
                    Type        => $value,
                    PrincipalId => $principal_id
                );
                push @results, $msg;
            }
        }

    }
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
    foreach my $field (@date_fields) {
        next unless exists $ARGSRef->{ $field . '_Date' };
        next if $ARGSRef->{ $field . '_Date' } eq '';
    
        my ( $code, $msg );

        my $DateObj = RT::Date->new( $session{'CurrentUser'} );
        $DateObj->Set(
            Format => 'unknown',
            Value  => $ARGSRef->{ $field . '_Date' }
        );

        my $obj = $field . "Obj";
        if ( ( defined $DateObj->Unix )
            and ( $DateObj->Unix != $Ticket->$obj()->Unix() ) )
        {
            my $method = "Set$field";
            my ( $code, $msg ) = $Ticket->$method( $DateObj->ISO );
            push @results, "$msg";
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
                 ARGSRef   => undef,
                 @_ );

    my $Ticket  = $args{'TicketObj'};
    my $ARGSRef = $args{'ARGSRef'};


    my (@results) = ProcessRecordLinks(RecordObj => $Ticket, ARGSRef => $ARGSRef);

    #Merge if we need to
    if ( $ARGSRef->{ $Ticket->Id . "-MergeInto" } ) {
        my ( $val, $msg ) =
          $Ticket->MergeInto( $ARGSRef->{ $Ticket->Id . "-MergeInto" } );
        push @results, $msg;
    }

    return (@results);
}

# }}}

sub ProcessRecordLinks {
    my %args = ( RecordObj => undef,
                 ARGSRef   => undef,
                 @_ );

    my $Record  = $args{'RecordObj'};
    my $ARGSRef = $args{'ARGSRef'};

    my (@results);

    # Delete links that are gone gone gone.
    foreach my $arg ( keys %$ARGSRef ) {
        if ( $arg =~ /DeleteLink-(.*?)-(DependsOn|MemberOf|RefersTo)-(.*)$/ ) {
            my $base   = $1;
            my $type   = $2;
            my $target = $3;

            push @results,
                loc( "Trying to delete: Base: [_1] Target: [_2] Type: [_3]",
                                              $base,       $target,   $type );
            my ( $val, $msg ) = $Record->DeleteLink( Base   => $base,
                                                     Type   => $type,
                                                     Target => $target );

            push @results, $msg;

        }

    }

    my @linktypes = qw( DependsOn MemberOf RefersTo );

    foreach my $linktype (@linktypes) {
        if ( $ARGSRef->{ $Record->Id . "-$linktype" } ) {
            for my $luri ( split ( / /, $ARGSRef->{ $Record->Id . "-$linktype" } ) ) {
                $luri =~ s/\s*$//;    # Strip trailing whitespace
                my ( $val, $msg ) = $Record->AddLink( Target => $luri,
                                                      Type   => $linktype );
                push @results, $msg;
            }
        }
        if ( $ARGSRef->{ "$linktype-" . $Record->Id } ) {

            for my $luri ( split ( / /, $ARGSRef->{ "$linktype-" . $Record->Id } ) ) {
                my ( $val, $msg ) = $Record->AddLink( Base => $luri,
                                                      Type => $linktype );

                push @results, $msg;
            }
        } 
    }

    return (@results);
}


=head2 _UploadedFile ( $arg );

Takes a CGI parameter name; if a file is uploaded under that name,
return a hash reference suitable for AddCustomFieldValue's use:
C<( Value => $filename, LargeContent => $content, ContentType => $type )>.

Returns C<undef> if no files were uploaded in the C<$arg> field.

=cut

sub _UploadedFile {
    my $arg = shift;
    my $cgi_object = $m->cgi_object;
    my $fh = $cgi_object->upload($arg) or return undef;
    my $upload_info = $cgi_object->uploadInfo($fh);

    my $filename = "$fh";
    $filename =~ s#^.*[\\/]##;
    binmode($fh);

    return {
        Value => $filename,
        LargeContent => do { local $/; scalar <$fh> },
        ContentType => $upload_info->{'Content-Type'},
    };
}

=head2 _load_container_object ( $type, $id );

Instantiate container object for saving searches.

=cut

sub _load_container_object {
    my ($obj_type, $obj_id) = @_;
    return RT::SavedSearch->new($session{'CurrentUser'})->_load_privacy_object($obj_type, $obj_id);
}

=head2 _parse_saved_search ( $arg );

Given a serialization string for saved search, and returns the
container object and the search id.

=cut

sub _parse_saved_search {
    my $spec = shift;
    if ($spec  !~ /^(.*?)-(\d+)-SavedSearch-(\d+)$/ ) {
        return;
    }
    my $obj_type  = $1;
    my $obj_id    = $2;
    my $search_id = $3;

    return (_load_container_object ($obj_type, $obj_id), $search_id);
}

eval "require RT::Interface::Web_Vendor";
die $@ if ($@ && $@ !~ qr{^Can't locate RT/Interface/Web_Vendor.pm});
eval "require RT::Interface::Web_Local";
die $@ if ($@ && $@ !~ qr{^Can't locate RT/Interface/Web_Local.pm});

1;
