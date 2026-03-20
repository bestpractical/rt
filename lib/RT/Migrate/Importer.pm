# BEGIN BPS TAGGED BLOCK {{{
#
# COPYRIGHT:
#
# This software is Copyright (c) 1996-2025 Best Practical Solutions, LLC
#                                          <sales@bestpractical.com>
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
# http://www.gnu.org/licenses/old-licenses/gpl-2.0.html.
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

package RT::Migrate::Importer;

use strict;
use warnings;

use LWP::UserAgent;
use JSON;
use MIME::Entity;
use Encode;
use URI;
use URI::QueryParam;

# Package-level state
our $UA;  # Reusable LWP::UserAgent
our %REMOTE_QUEUE_MAP;  # Remote queue ID => Name mapping
our %REMOTE_TICKET_MAP; # Remote ticket ID => Local ticket ID mapping

# Transaction types that have content (attachments/message body)
our %CONTENT_TYPES = map { $_ => 1 } qw(
    Create Correspond Comment EmailRecord CommentEmailRecord
);

# Transaction types to SKIP (everything else is replayed)
# Create is handled separately during ticket creation
our %SKIP_TYPES = map { $_ => 1 } qw(
    Create
);

sub run {
    my $class = shift;
    my %args  = (
        CurrentUser     => undef,
        Source          => undef,
        Token           => undef,
        Queues          => [],
        Days            => 30,
        Delay           => 1,
        PerQueue        => 15,
        DryRun          => 0,
        PrivilegedUsers => 0,
        @_,
    );

    my ( $created, $skipped ) = ( 0, 0 );
    my @imported;  # Track imported tickets for summary

    # Initialize UserAgent (reuse across requests)
    $UA ||= LWP::UserAgent->new(
        timeout => 30,
        agent   => 'RT-Import-Remote/1.0',
    );

    unless ( $args{Source} ) {
        RT->Logger->error("Source URL is required");
        return ( 0, 0 );
    }

    # Normalize Source URL - remove trailing slashes
    $args{Source} =~ s{/+$}{};

    unless ( $args{Token} ) {
        RT->Logger->error("API Token is required");
        return ( 0, 0 );
    }

    # If no queues specified, fetch all queues from remote
    my @queues = @{ $args{Queues} };
    if ( !@queues ) {
        RT->Logger->info("No queues specified, fetching all queues from remote");
        @queues = $class->FetchRemoteQueues(
            Source => $args{Source},
            Token  => $args{Token},
        );
        unless (@queues) {
            RT->Logger->error("Failed to fetch queues from remote");
            return ( 0, 0 );
        }
        RT->Logger->info( "Found " . scalar(@queues) . " queues: " . join( ', ', @queues ) );
    }
    else {
        # Populate remote queue mapping for specified queues
        RT->Logger->info("Fetching remote queue details for specified queues");
        $class->PopulateRemoteQueueMap(
            Source => $args{Source},
            Token  => $args{Token},
            Queues => \@queues,
        );
    }

    # Filter to queues that exist locally
    my @valid_queues;
    for my $queue_name (@queues) {
        my $queue = RT::Queue->new( RT->SystemUser );
        $queue->Load($queue_name);
        if ( $queue->Id ) {
            push @valid_queues, $queue_name;
        }
        else {
            RT->Logger->info("Skipping queue '$queue_name' - does not exist locally");
        }
    }
    @queues = @valid_queues;

    unless (@queues) {
        RT->Logger->error("No matching queues found locally");
        return ( 0, 0 );
    }

    RT->Logger->info( "Importing from " . scalar(@queues) . " queues: " . join( ', ', @queues ) );

    # Load existing state
    my $system = RT::System->new( RT->SystemUser );
    my $attr   = $system->FirstAttribute('RT-Import-Remote-State');
    my $state  = {};
    if ($attr) {
        my $content = $attr->Content;
        if ( $content && ref($content) eq 'HASH' ) {
            $state = $content->{ $args{Source} } || {};
        }
    }
    RT->Logger->debug( "Loaded state with " . scalar( keys %$state ) . " previously imported tickets" );

    # Populate remote ticket map from state for link resolution
    %REMOTE_TICKET_MAP = ();
    for my $remote_id ( keys %$state ) {
        if ( $state->{$remote_id}{local_id} ) {
            $REMOTE_TICKET_MAP{$remote_id} = $state->{$remote_id}{local_id};
        }
    }
    RT->Logger->debug( "Populated remote ticket map with " . scalar( keys %REMOTE_TICKET_MAP ) . " entries" );

    # Calculate date threshold
    my $since = $class->_GetSinceDate( $args{Days} );

    # Process each queue
    for my $queue_name (@queues) {
        my $queue_created = 0;

        # Build query with proper quoting
        my $quoted_queue = $queue_name;
        $quoted_queue =~ s/'/''/g;  # TicketSQL uses '' to escape '
        my $query = "Queue = '$quoted_queue' AND Created > '$since'";

        RT->Logger->info("Fetching tickets for queue '$queue_name' with query: $query");

        my $page        = 1;
        my $has_more    = 1;
        my $per_page    = 25;
        my $queue_limit = $args{PerQueue};

        while ($has_more) {
            RT->Logger->debug("Fetching page $page for queue '$queue_name'");

            my $tickets = $class->FetchRemoteTickets(
                Source  => $args{Source},
                Token   => $args{Token},
                Query   => $query,
                Page    => $page,
                PerPage => $per_page,
            );

            unless ($tickets) {
                RT->Logger->error("Failed to fetch tickets from remote for queue '$queue_name'");
                last;
            }

            if ( @$tickets == 0 ) {
                RT->Logger->debug("No more tickets for queue '$queue_name'");
                $has_more = 0;
                last;
            }

            for my $remote_ticket (@$tickets) {
                # Check per-queue limit
                if ( $queue_limit && $queue_created >= $queue_limit ) {
                    RT->Logger->debug("Reached per-queue limit of $queue_limit for '$queue_name'");
                    $has_more = 0;
                    last;
                }

                my $remote_id = $remote_ticket->{id};

                if ( $state->{$remote_id} ) {
                    RT->Logger->debug(
                        "Ticket $remote_id already imported as local ticket " . $state->{$remote_id}{local_id}
                    );
                    $skipped++;
                    next;
                }

                if ( $args{DryRun} ) {
                    RT->Logger->info("[DRY-RUN] Would import ticket $remote_id from queue '$queue_name'");
                    $created++;
                    $queue_created++;
                    next;
                }

                my $ticket_details = $class->FetchTicketDetails(
                    Source   => $args{Source},
                    Token    => $args{Token},
                    TicketId => $remote_id,
                );

                unless ($ticket_details) {
                    RT->Logger->error("Failed to fetch details for ticket $remote_id");
                    return ( $created, $skipped );
                }

                # Fetch history first so we can get Create transaction content
                my $transactions = $class->FetchTicketHistory(
                    Source   => $args{Source},
                    Token    => $args{Token},
                    TicketId => $remote_id,
                );

                # Disable all scrips during import to prevent spurious transactions
                local $RT::Record::DisableScrips = 1;

                # Create local ticket with Create transaction content
                my $local_ticket = $class->CreateTicket(
                    CurrentUser     => $args{CurrentUser},
                    RemoteTicket    => $ticket_details,
                    QueueName       => $queue_name,
                    Transactions    => $transactions || [],
                    Source          => $args{Source},
                    Token           => $args{Token},
                    PrivilegedUsers => $args{PrivilegedUsers},
                );

                if ($local_ticket) {
                    # Prevent TransactionBatch scrips from running on this ticket
                    $local_ticket->RanTransactionBatch(1);

                    my $subject = $local_ticket->Subject || '(no subject)';
                    RT->Logger->info(
                        sprintf( "Imported: remote #%d -> local #%d [%s] %s",
                            $remote_id, $local_ticket->Id, $queue_name, $subject )
                    );

                    # Track for summary
                    push @imported, {
                        remote_id  => $remote_id,
                        local_id   => $local_ticket->Id,
                        queue      => $queue_name,
                        subject    => $subject,
                    };

                    # Replay remaining transactions (Create is handled above)
                    if ( $transactions && @$transactions ) {
                        my ( $txn_created, $txn_skipped ) = $class->ReplayTransactions(
                            CurrentUser     => $args{CurrentUser},
                            LocalTicket     => $local_ticket,
                            Transactions    => $transactions,
                            Source          => $args{Source},
                            Token           => $args{Token},
                            PrivilegedUsers => $args{PrivilegedUsers},
                        );
                        RT->Logger->debug("Replayed $txn_created transactions, skipped $txn_skipped");
                    }

                    # Update state and ticket map
                    my $now = RT::Date->new( RT->SystemUser );
                    $now->SetToNow;
                    $state->{$remote_id} = {
                        local_id      => $local_ticket->Id,
                        replicated_at => $now->ISO,
                    };
                    $REMOTE_TICKET_MAP{$remote_id} = $local_ticket->Id;
                    $created++;
                    $queue_created++;
                }
                else {
                    RT->Logger->error("Failed to create local ticket for remote ticket $remote_id");
                    $skipped++;
                }

                # Rate limiting
                sleep( $args{Delay} ) if $args{Delay};
            }

            # Check if there might be more
            if ( @$tickets < $per_page ) {
                $has_more = 0;
            }
            else {
                $page++;
            }

            # Rate limiting between pages
            sleep( $args{Delay} ) if $args{Delay} && $has_more;
        }

        RT->Logger->info("Queue '$queue_name': imported $queue_created tickets");
    }

    # Save state
    unless ( $args{DryRun} ) {
        my $save_attr    = $system->FirstAttribute('RT-Import-Remote-State');
        my $save_content = {};
        if ($save_attr) {
            $save_content = $save_attr->Content || {};
        }
        $save_content->{ $args{Source} } = $state;

        my ( $ok, $msg ) = $system->SetAttribute(
            Name    => 'RT-Import-Remote-State',
            Content => $save_content,
        );
        if ($ok) {
            RT->Logger->info( "Saved state with " . scalar( keys %$state ) . " imported tickets" );
        }
        else {
            RT->Logger->error("Failed to save state: $msg");
        }
    }

    # Print summary
    if (@imported) {
        RT->Logger->info("=== Import Summary ===");
        for my $t (@imported) {
            RT->Logger->info(
                sprintf( "  #%d -> #%d [%s] %s",
                    $t->{remote_id}, $t->{local_id}, $t->{queue},
                    substr( $t->{subject}, 0, 50 ) )
            );
        }
        RT->Logger->info("======================");
    }

    return ( $created, $skipped, \@imported );
}

sub FetchRemoteQueues {
    my $class = shift;
    my %args  = (
        Source => undef,
        Token  => undef,
        @_,
    );

    # Reset the queue mapping
    %REMOTE_QUEUE_MAP = ();

    my @queues;
    my $page     = 1;
    my $per_page = 100;

    while (1) {
        my $uri = URI->new( $args{Source} . '/REST/2.0/queues/all' );
        $uri->query_param( page     => $page );
        $uri->query_param( per_page => $per_page );

        my $response = $class->_MakeRequest(
            Token => $args{Token},
            URL   => $uri->as_string,
        );

        last unless $response && $response->{items} && @{ $response->{items} };

        for my $item ( @{ $response->{items} } ) {
            next unless $item->{_url};
            my $queue_details = $class->_MakeRequest(
                Token => $args{Token},
                URL   => $item->{_url},
            );
            if ( $queue_details && $queue_details->{Name} ) {
                push @queues, $queue_details->{Name};
                $REMOTE_QUEUE_MAP{ $queue_details->{id} } = $queue_details->{Name}
                    if $queue_details->{id};
            }
        }

        last if @{ $response->{items} } < $per_page;
        $page++;
    }

    return @queues;
}

sub PopulateRemoteQueueMap {
    my $class = shift;
    my %args  = (
        Source => undef,
        Token  => undef,
        Queues => [],
        @_,
    );

    # Reset the queue mapping
    %REMOTE_QUEUE_MAP = ();

    for my $queue_name ( @{ $args{Queues} } ) {
        # Search for queue by name on remote
        my $uri = URI->new( $args{Source} . '/REST/2.0/queues' );
        $uri->query_param( query => "Name = '$queue_name'" );

        my $response = $class->_MakeRequest(
            Token => $args{Token},
            URL   => $uri->as_string,
        );

        if ( $response && $response->{items} && @{ $response->{items} } ) {
            my $item = $response->{items}[0];
            if ( $item->{_url} ) {
                my $queue_details = $class->_MakeRequest(
                    Token => $args{Token},
                    URL   => $item->{_url},
                );
                if ( $queue_details && $queue_details->{id} ) {
                    $REMOTE_QUEUE_MAP{ $queue_details->{id} } = $queue_details->{Name};
                    RT->Logger->debug("Mapped remote queue '$queue_name' to ID $queue_details->{id}");
                }
            }
        }
        else {
            RT->Logger->warning("Could not find remote queue '$queue_name'");
        }
    }

    RT->Logger->debug( "Populated remote queue map with " . scalar( keys %REMOTE_QUEUE_MAP ) . " queues" );
}

sub FetchRemoteTickets {
    my $class = shift;
    my %args  = (
        Source  => undef,
        Token   => undef,
        Query   => undef,
        Page    => 1,
        PerPage => 25,
        @_,
    );

    my $uri = URI->new( $args{Source} . '/REST/2.0/tickets' );
    $uri->query_param( query    => $args{Query} );
    $uri->query_param( page     => $args{Page} );
    $uri->query_param( per_page => $args{PerPage} );

    my $response = $class->_MakeRequest(
        Token => $args{Token},
        URL   => $uri->as_string,
    );

    return unless $response;
    return $response->{items} || [];
}

sub FetchTicketDetails {
    my $class = shift;
    my %args  = (
        Source   => undef,
        Token    => undef,
        TicketId => undef,
        @_,
    );

    my $url = $args{Source} . '/REST/2.0/ticket/' . $args{TicketId};

    return $class->_MakeRequest(
        Token => $args{Token},
        URL   => $url,
    );
}

sub FetchTicketHistory {
    my $class = shift;
    my %args  = (
        Source   => undef,
        Token    => undef,
        TicketId => undef,
        @_,
    );

    my @transactions;
    my $page     = 1;
    my $per_page = 100;
    my $has_more = 1;

    while ($has_more) {
        my $uri = URI->new( $args{Source} . '/REST/2.0/ticket/' . $args{TicketId} . '/history' );
        $uri->query_param( page     => $page );
        $uri->query_param( per_page => $per_page );

        my $response = $class->_MakeRequest(
            Token => $args{Token},
            URL   => $uri->as_string,
        );

        last unless $response;

        my $items = $response->{items} || [];
        last unless @$items;

        # The history endpoint returns items with _url, need to fetch each
        for my $item ( @$items ) {
            if ( $item->{_url} ) {
                my $txn = $class->_MakeRequest(
                    Token => $args{Token},
                    URL   => $item->{_url},
                );
                push @transactions, $txn if $txn;
            }
            else {
                push @transactions, $item;
            }
        }

        # Check if there are more pages
        if ( @$items < $per_page ) {
            $has_more = 0;
        }
        else {
            $page++;
        }
    }

    RT->Logger->debug( "Fetched " . scalar(@transactions) . " transactions for ticket " . $args{TicketId} );
    return \@transactions;
}

sub _MakeRequest {
    my $class = shift;
    my %args  = (
        Token => undef,
        URL   => undef,
        @_,
    );

    RT->Logger->debug("GET $args{URL}");

    my $response = $UA->get(
        $args{URL},
        'Authorization' => 'token ' . $args{Token},
        'Accept'        => 'application/json',
    );

    unless ( $response->is_success ) {
        RT->Logger->error( "Request failed: " . $response->status_line );
        RT->Logger->debug( "Response: " . $response->decoded_content );
        return;
    }

    my $data;
    eval { $data = JSON::decode_json( $response->decoded_content ); };
    if ($@) {
        RT->Logger->error("Failed to parse JSON response: $@");
        return;
    }

    return $data;
}

sub FetchAttachment {
    my $class = shift;
    my %args  = (
        Source       => undef,
        Token        => undef,
        AttachmentId => undef,
        @_,
    );

    my $url = $args{Source} . '/REST/2.0/attachment/' . $args{AttachmentId};

    return $class->_MakeRequest(
        Token => $args{Token},
        URL   => $url,
    );
}

sub FetchAttachmentContent {
    my $class = shift;
    my %args  = @_;

    my $att_info = $args{AttachmentInfo};
    return unless $att_info;

    my $content = $att_info->{Content};
    return unless defined $content;

    # REST2 returns content base64 encoded
    require MIME::Base64;
    my $decoded = MIME::Base64::decode_base64($content);

    # For text content types, decode as UTF-8
    my $content_type = $att_info->{ContentType} || '';
    if ( $content_type =~ m{^text/}i ) {
        # Try to decode as UTF-8, fall back to raw bytes if that fails
        eval {
            $decoded = Encode::decode( 'UTF-8', $decoded, Encode::FB_CROAK );
        };
        if ($@) {
            # Not valid UTF-8, try to decode as Latin-1 then re-encode
            RT->Logger->debug("Content not valid UTF-8, trying Latin-1: $@");
            eval {
                $decoded = Encode::decode( 'ISO-8859-1', $decoded );
            };
        }
    }

    return $decoded;
}

sub CreateTicket {
    my $class = shift;
    my %args  = (
        CurrentUser     => undef,
        RemoteTicket    => undef,
        QueueName       => undef,
        Transactions    => [],
        Source          => undef,
        Token           => undef,
        PrivilegedUsers => 0,
        @_,
    );

    my $remote = $args{RemoteTicket};

    # Resolve requestor
    my $requestor_email;
    if ( $remote->{Requestor} && @{ $remote->{Requestor} } ) {
        my $req = $remote->{Requestor}[0];
        $requestor_email = $req->{id} || $req->{name} || $req;
    }

    # Resolve owner
    my $owner;
    if ( $remote->{Owner} && $remote->{Owner}{id} ) {
        $owner = $class->LoadOrCreateUser(
            EmailAddress => $remote->{Owner}{id},
            RealName     => $remote->{Owner}{name},
            Privileged   => $args{PrivilegedUsers},
        );
    }

    # Use provided queue name (already validated to exist locally)
    my $queue_name = $args{QueueName};

    my $queue = RT::Queue->new( $args{CurrentUser} );
    $queue->Load($queue_name);
    unless ( $queue->Id ) {
        RT->Logger->error("Queue not found: $queue_name");
        return;
    }

    # Build MIMEObj from Create transaction content if available
    my $mime;
    if ( $args{Transactions} && $args{Source} && $args{Token} ) {
        $mime = $class->BuildCreateMIME(
            Transactions => $args{Transactions},
            Source       => $args{Source},
            Token        => $args{Token},
        );
    }

    my $ticket = RT::Ticket->new( $args{CurrentUser} );

    my %create_args = (
        Queue     => $queue->Id || $queue_name,
        Subject   => $remote->{Subject} || '(no subject)',
        Requestor => $requestor_email,
    );

    $create_args{Owner}   = $owner->Id if $owner && $owner->Id;
    $create_args{MIMEObj} = $mime      if $mime;

    # Handle priority
    $create_args{Priority}        = $remote->{Priority}        if defined $remote->{Priority};
    $create_args{InitialPriority} = $remote->{InitialPriority} if defined $remote->{InitialPriority};
    $create_args{FinalPriority}   = $remote->{FinalPriority}   if defined $remote->{FinalPriority};

    my ( $id, $txn, $msg ) = $ticket->Create(%create_args);

    unless ($id) {
        RT->Logger->error("Failed to create ticket: $msg");
        return;
    }

    # Backdate Created
    if ( $remote->{Created} ) {
        my $date = $class->ParseISO8601( $remote->{Created} );
        RT->Logger->debug( "Backdating ticket to: " . $date->ISO . " (from $remote->{Created})" );

        my ( $ok, $err ) = $ticket->__Set( Field => 'Created', Value => $date->ISO );
        RT->Logger->error("Failed to set Created: $err") unless $ok;

        # Also backdate the Create transaction and fix creator
        my $txns = $ticket->Transactions;
        $txns->Limit( FIELD => 'Type', VALUE => 'Create' );
        if ( my $create_txn = $txns->First ) {
            ( $ok, $err ) = $create_txn->__Set( Field => 'Created', Value => $date->ISO );
            RT->Logger->error("Failed to set Created on transaction: $err") unless $ok;

            # Set the original creator on the Create transaction
            if ( $remote->{Creator} ) {
                my $creator_email;
                my $creator_name;

                if ( ref($remote->{Creator}) eq 'HASH' ) {
                    # REST2 returns {id, type, _url} - may need to fetch full details
                    $creator_email = $remote->{Creator}{id};
                    $creator_name  = $remote->{Creator}{name} // $remote->{Creator}{RealName};

                    # If we don't have RealName, fetch user details
                    if ( !$creator_name && $remote->{Creator}{_url} ) {
                        RT->Logger->debug("Fetching ticket Creator details from $remote->{Creator}{_url}");
                        my $user_data = $class->_MakeRequest(
                            Token => $args{Token},
                            URL   => $remote->{Creator}{_url},
                        );
                        if ($user_data) {
                            $creator_name = $user_data->{RealName};
                            $creator_email //= $user_data->{EmailAddress} // $user_data->{Name};
                        }
                    }
                }
                else {
                    $creator_email = $remote->{Creator};
                }

                RT->Logger->debug("Ticket Creator: email='$creator_email', realname='"
                    . ($creator_name // 'undef') . "'");

                my $creator = $class->LoadOrCreateUser(
                    EmailAddress => $creator_email,
                    RealName     => $creator_name,
                    Privileged   => $args{PrivilegedUsers},
                );
                if ( $creator && $creator->Id ) {
                    ( $ok, $err ) = $create_txn->__Set( Field => 'Creator', Value => $creator->Id );
                    RT->Logger->error("Failed to set Creator on transaction: $err") unless $ok;
                    # Also fix the ticket's Creator
                    ( $ok, $err ) = $ticket->__Set( Field => 'Creator', Value => $creator->Id );
                    RT->Logger->error("Failed to set Creator on ticket: $err") unless $ok;
                    RT->Logger->debug("Set ticket/txn Creator to " . $creator->Id
                        . " (" . $creator->Name . ", RealName='" . ($creator->RealName // '') . "')");
                }
            }
        }
    }

    # Set status (after create to handle lifecycle differences)
    if ( $remote->{Status} && $remote->{Status} ne $ticket->Status ) {
        my ( $ok, $err ) = $ticket->__Set( Field => 'Status', Value => $remote->{Status} );
        RT->Logger->warning("Failed to set Status to $remote->{Status}: $err") unless $ok;
    }

    # Handle custom fields
    if ( $remote->{CustomFields} ) {
        for my $cf ( @{ $remote->{CustomFields} } ) {
            my $cf_name  = $cf->{name};
            my $cf_value = $cf->{values} ? join( ', ', @{ $cf->{values} } ) : '';

            my $cf_obj = RT::CustomField->new( $args{CurrentUser} );
            $cf_obj->LoadByName(
                Name          => $cf_name,
                LookupType    => RT::Ticket->CustomFieldLookupType,
                ObjectId      => $queue->Id,
                IncludeGlobal => 1,
            );

            if ( $cf_obj->Id ) {
                my ( $ok, $err ) = $ticket->AddCustomFieldValue(
                    Field             => $cf_obj->Id,
                    Value             => $cf_value,
                    RecordTransaction => 0,
                );
                RT->Logger->warning("Failed to set CF $cf_name: $err") unless $ok;
            }
            else {
                RT->Logger->debug("Custom field '$cf_name' not found locally, skipping");
            }
        }
    }

    return $ticket;
}

sub BuildCreateMIME {
    my $class = shift;
    my %args  = (
        Transactions => [],
        Source       => undef,
        Token        => undef,
        @_,
    );

    # Find Create transaction
    my ($create_txn) = grep { $_->{Type} && $_->{Type} eq 'Create' } @{ $args{Transactions} };
    return unless $create_txn;

    my $remote_txn_id = $create_txn->{id};
    return unless $remote_txn_id;

    # Fetch attachments for Create transaction
    my $att_url  = $args{Source} . '/REST/2.0/transaction/' . $remote_txn_id . '/attachments';
    my $att_list = $class->_MakeRequest(
        Token => $args{Token},
        URL   => $att_url,
    );

    my $attachments = $att_list->{items} || [];
    return unless @$attachments;

    my $body_content = '';
    my $body_type    = 'text/plain';
    my @file_attachments;

    for my $att (@$attachments) {
        my $att_info = $class->FetchAttachment(
            Source       => $args{Source},
            Token        => $args{Token},
            AttachmentId => $att->{id},
        );
        unless ($att_info) {
            RT->Logger->warning("Failed to fetch attachment $att->{id} for Create transaction");
            next;
        }

        my $content = $class->FetchAttachmentContent( AttachmentInfo => $att_info );

        if (   !$att_info->{Filename}
            && $att_info->{ContentType}
            && $att_info->{ContentType} =~ m{^text/}i )
        {
            $body_content = $content // '';
            $body_type    = $att_info->{ContentType};
        }
        elsif ( $att_info->{Filename} && defined $content ) {
            push @file_attachments, {
                content  => $content,
                type     => $att_info->{ContentType} || 'application/octet-stream',
                filename => $att_info->{Filename},
            };
        }
    }

    return unless length($body_content) || @file_attachments;

    my $mime = MIME::Entity->build(
        Type    => $body_type,
        Charset => 'UTF-8',
        Data    => Encode::encode( 'UTF-8', $body_content ),
    );

    for my $file (@file_attachments) {
        $mime->attach(
            Data        => $file->{content},
            Type        => $file->{type},
            Filename    => Encode::encode( 'UTF-8', $file->{filename} ),
            Disposition => 'attachment',
        );
    }

    RT->Logger->debug("Built MIME object from Create transaction content");
    return $mime;
}

sub ReplayTransactions {
    my $class = shift;
    my %args  = (
        CurrentUser     => undef,
        LocalTicket     => undef,
        Transactions    => [],
        Source          => undef,
        Token           => undef,
        PrivilegedUsers => 0,
        @_,
    );

    my $ticket = $args{LocalTicket};
    my ( $created, $skipped ) = ( 0, 0 );

    for my $remote_txn ( @{ $args{Transactions} } ) {
        my $type = $remote_txn->{Type} or next;

        # Skip types we don't want to replay
        if ( $SKIP_TYPES{$type} ) {
            RT->Logger->debug("Skipping $type transaction (in skip list)");
            next;
        }

        RT->Logger->debug("Replaying $type transaction");

        # Debug: dump raw transaction data for CF and Set transactions
        if ( $type eq 'CustomField' || $type eq 'Set' ) {
            require Data::Dumper;
            local $Data::Dumper::Terse = 1;
            local $Data::Dumper::Indent = 0;
            RT->Logger->debug("$type txn raw: " . Data::Dumper::Dumper($remote_txn));
        }

        # ---- Resolve creator FIRST ----
        my $creator_id;
        if ( my $creator = $remote_txn->{Creator} ) {
            my $email    = ref($creator) ? $creator->{id} : $creator;
            my $realname = ref($creator) ? ( $creator->{name} // $creator->{RealName} ) : undef;

            RT->Logger->debug("Creator resolution: email='$email', realname='"
                . ($realname // 'undef') . "', raw=" . (ref($creator) ? 'HASH' : $creator));

            if ($email) {
                my $user = $class->LoadOrCreateUser(
                    EmailAddress => $email,
                    RealName     => $realname,
                    Privileged   => $args{PrivilegedUsers},
                );
                if ( $user && $user->Id ) {
                    $creator_id = $user->Id;
                    RT->Logger->debug("Creator resolved to user ID $creator_id, RealName='"
                        . ($user->RealName // '') . "'");
                }
            }
        }

        # ---- Fetch attachments/content (only for content-bearing types) ----
        my $body_content = '';
        my $body_type    = 'text/plain';
        my @file_attachments;
        my $mime;

        if ( $CONTENT_TYPES{$type} && ( my $remote_txn_id = $remote_txn->{id} ) ) {

            my $att_url  = $args{Source} . '/REST/2.0/transaction/' . $remote_txn_id . '/attachments';
            my $att_list = $class->_MakeRequest(
                Token => $args{Token},
                URL   => $att_url,
            );

            my $attachments = $att_list->{items} || [];

            for my $att (@$attachments) {
                my $att_info = $class->FetchAttachment(
                    Source       => $args{Source},
                    Token        => $args{Token},
                    AttachmentId => $att->{id},
                );
                unless ($att_info) {
                    RT->Logger->warning("Failed to fetch attachment $att->{id} for $type transaction $remote_txn_id");
                    next;
                }

                my $content = $class->FetchAttachmentContent(
                    AttachmentInfo => $att_info
                );

                if (   !$att_info->{Filename}
                    && $att_info->{ContentType}
                    && $att_info->{ContentType} =~ m{^text/}i )
                {
                    $body_content = $content // '';
                    $body_type    = $att_info->{ContentType};
                }
                elsif ( $att_info->{Filename} && defined $content ) {
                    push @file_attachments, {
                        content  => $content,
                        type     => $att_info->{ContentType} || 'application/octet-stream',
                        filename => $att_info->{Filename},
                    };
                }
            }
        }

        my $has_content = length($body_content) || @file_attachments;

        # ---- Build MIME only if needed ----
        if ($has_content) {
            $mime = MIME::Entity->build(
                Type    => $body_type,
                Charset => 'UTF-8',
                Data    => Encode::encode( 'UTF-8', $body_content ),
            );

            if ( $remote_txn->{Subject} ) {
                $mime->head->replace(
                    'Subject',
                    Encode::encode( 'UTF-8', $remote_txn->{Subject} )
                );
            }

            if ($creator_id) {
                my $user = RT::User->new(RT->SystemUser);
                $user->Load($creator_id);

                if ( $user->EmailAddress ) {
                    $mime->head->replace(
                        'From',
                        sprintf(
                            '%s <%s>',
                            $user->RealName || $user->Name,
                            $user->EmailAddress
                        )
                    );
                }
            }

            for my $file (@file_attachments) {
                $mime->attach(
                    Data        => $file->{content},
                    Type        => $file->{type},
                    Filename    => Encode::encode( 'UTF-8', $file->{filename} ),
                    Disposition => 'attachment',
                );
            }
        }

        # ---- Resolve field ----
        my $field = $remote_txn->{Field};

        # For CustomField transactions, resolve to local CF ID
        if ( $type eq 'CustomField' ) {
            my $cf_name;
            if ( ref($field) eq 'HASH' ) {
                # REST2 returns {id, type, _url} - fetch the CF name
                if ( $field->{_url} ) {
                    my $cf_data = $class->_MakeRequest(
                        Token => $args{Token},
                        URL   => $field->{_url},
                    );
                    $cf_name = $cf_data->{Name} if $cf_data;
                }
                $cf_name //= $field->{id};
            }
            else {
                $cf_name = $field;
            }

            if ($cf_name) {
                my $cf = RT::CustomField->new( RT->SystemUser );
                $cf->LoadByName( Name => $cf_name, LookupType => RT::Ticket->CustomFieldLookupType );
                if ( $cf->Id ) {
                    $field = $cf->Id;
                    RT->Logger->debug("Resolved CF '$cf_name' to local ID " . $cf->Id);
                }
                else {
                    RT->Logger->debug("Could not find local CF '$cf_name' - skipping transaction");
                    $skipped++;
                    next;
                }
            }
        }
        elsif ( ref($field) eq 'HASH' ) {
            $field = $field->{id};
        }

        my $old_value = $remote_txn->{OldValue};
        my $new_value = $remote_txn->{NewValue};

        # For CustomField transactions, values are in OldReference/NewReference
        # We need to fetch the ObjectCustomFieldValue to get the actual content
        # Note: OCFV endpoint may return 404 if record was deleted - that's OK
        if ( $type eq 'CustomField' ) {
            my $resolved_old = 0;
            my $resolved_new = 0;

            if ( $remote_txn->{OldReference} && $remote_txn->{OldReference}{_url} ) {
                my $ocfv = $class->_MakeRequest(
                    Token => $args{Token},
                    URL   => $remote_txn->{OldReference}{_url},
                );
                if ($ocfv) {
                    $old_value = $ocfv->{Content} // $ocfv->{LargeContent};
                    $resolved_old = 1;
                    RT->Logger->debug("CF OldReference resolved to: '$old_value'");
                }
            }
            if ( $remote_txn->{NewReference} && $remote_txn->{NewReference}{_url} ) {
                my $ocfv = $class->_MakeRequest(
                    Token => $args{Token},
                    URL   => $remote_txn->{NewReference}{_url},
                );
                if ($ocfv) {
                    $new_value = $ocfv->{Content} // $ocfv->{LargeContent};
                    $resolved_new = 1;
                    RT->Logger->debug("CF NewReference resolved to: '$new_value'");
                }
            }

            # If we couldn't resolve references, clear out numeric IDs (they're not useful)
            # OldValue/NewValue for CF txns are OCFV IDs, not actual values
            if ( !$resolved_old && defined($old_value) && $old_value =~ /^\d+$/ ) {
                RT->Logger->debug("CF OldValue '$old_value' is numeric ID, clearing (reference fetch failed)");
                $old_value = undef;
            }
            if ( !$resolved_new && defined($new_value) && $new_value =~ /^\d+$/ ) {
                RT->Logger->debug("CF NewValue '$new_value' is numeric ID, clearing (reference fetch failed)");
                $new_value = undef;
            }
        }

        # Dereference hash values if needed (REST2 may return objects)
        # For CustomField transactions, prefer 'Content' over 'id' since values are strings
        if ( ref($old_value) eq 'HASH' ) {
            $old_value = $old_value->{Content} // $old_value->{Name} // $old_value->{id} // $old_value;
        }
        if ( ref($new_value) eq 'HASH' ) {
            $new_value = $new_value->{Content} // $new_value->{Name} // $new_value->{id} // $new_value;
        }

        # For Queue Set transactions, resolve remote queue IDs to local queue IDs
        if ( $type eq 'Set' && $field eq 'Queue' ) {
            for my $val_ref ( \$old_value, \$new_value ) {
                next unless defined $$val_ref;
                # Look up remote queue name from our mapping
                my $queue_name = $REMOTE_QUEUE_MAP{ $$val_ref };
                if ($queue_name) {
                    # Find local queue with same name
                    my $local_queue = RT::Queue->new( RT->SystemUser );
                    $local_queue->Load($queue_name);
                    if ( $local_queue->Id ) {
                        $$val_ref = $local_queue->Id;
                    }
                    else {
                        # Queue doesn't exist locally - use 0 to indicate unknown
                        $$val_ref = 0;
                    }
                }
            }
        }

        # For AddWatcher/DelWatcher, resolve the principal (user) being added/removed
        if ( $type eq 'AddWatcher' || $type eq 'DelWatcher' ) {
            require Data::Dumper;
            local $Data::Dumper::Terse = 1;
            local $Data::Dumper::Indent = 0;
            RT->Logger->debug("$type txn raw: " . Data::Dumper::Dumper($remote_txn));

            # Field should be the watcher type: Requestor, Cc, AdminCc
            # REST2 may return Field as a hash with {id, type, _url}
            if ( ref($field) eq 'HASH' ) {
                # Try to get the watcher type name
                if ( $field->{_url} && $field->{_url} =~ m{/group/(\d+)$} ) {
                    # It's a group reference - need to determine type from context
                    # The type might be in the transaction Data field
                    $field = $remote_txn->{Data} if $remote_txn->{Data};
                }
                $field //= $field->{id};
            }
            # Normalize field names
            $field = 'Requestor' if $field && $field =~ /^requestor$/i;
            $field = 'Cc' if $field && $field =~ /^cc$/i;
            $field = 'AdminCc' if $field && $field =~ /^admincc$/i;

            # Get the principal value from the raw transaction (before dereferencing)
            my $raw_value = $type eq 'AddWatcher'
                ? $remote_txn->{NewValue}
                : $remote_txn->{OldValue};

            my $principal_email;
            my $principal_realname;

            if ( ref($raw_value) eq 'HASH' ) {
                # REST2 returns {id, type, _url} for principals where id is the principal ID
                # In RT, PrincipalId = UserId for users, so we can query /user/{principal_id} directly
                my $principal_id = $raw_value->{id};

                if ($principal_id) {
                    # Build user URL from principal ID (PrincipalId = UserId in RT)
                    my $user_url = $args{Source} . '/REST/2.0/user/' . $principal_id;
                    RT->Logger->debug("$type: Fetching user details from $user_url");

                    my $user_data = $class->_MakeRequest(
                        Token => $args{Token},
                        URL   => $user_url,
                    );

                    if ($user_data) {
                        # Got user data - extract email and name
                        $principal_email = $user_data->{EmailAddress} // $user_data->{Name};
                        $principal_realname = $user_data->{RealName};
                        RT->Logger->debug("$type: Got user: email='$principal_email', realname='"
                            . ($principal_realname // '') . "'");
                    }
                    else {
                        # User fetch failed - might be a group instead
                        my $group_url = $args{Source} . '/REST/2.0/group/' . $principal_id;
                        RT->Logger->debug("$type: User not found, trying group: $group_url");

                        my $group_data = $class->_MakeRequest(
                            Token => $args{Token},
                            URL   => $group_url,
                        );

                        if ($group_data) {
                            $principal_email = $group_data->{Name};
                            RT->Logger->debug("$type: Got group: name='$principal_email'");
                        }
                    }
                }

                # If we couldn't resolve the principal, skip this transaction
                if ( !$principal_email ) {
                    RT->Logger->warning("$type: Could not resolve principal $raw_value->{id} - skipping transaction");
                    $skipped++;
                    next;
                }
            }
            else {
                $principal_email = $raw_value;
            }

            RT->Logger->debug("$type: Field='$field', principal_email='$principal_email'");

            if ($principal_email) {
                my $user = $class->LoadOrCreateUser(
                    EmailAddress => $principal_email,
                    RealName     => $principal_realname,
                    Privileged   => $args{PrivilegedUsers},
                );
                if ( $user && $user->Id ) {
                    if ( $type eq 'AddWatcher' ) {
                        $new_value = $user->PrincipalId;
                    }
                    else {
                        $old_value = $user->PrincipalId;
                    }
                    RT->Logger->debug("$type: Resolved '$principal_email' to PrincipalId "
                        . ($type eq 'AddWatcher' ? $new_value : $old_value));
                }
            }
        }

        # Handle AddLink/DeleteLink - resolve remote ticket IDs to local IDs
        if ( $type eq 'AddLink' || $type eq 'DeleteLink' ) {
            # Field contains the link type (e.g., DependsOn, MemberOf, RefersTo)
            # NewValue (AddLink) or OldValue (DeleteLink) contains the target ticket URI
            # Data contains a human-readable description like "Ticket 123"

            my $target_value = $type eq 'AddLink' ? $new_value : $old_value;

            # Extract remote ticket ID from the target value
            # Could be a URI like "fsck.com-rt://example.com/ticket/123" or just "123"
            my $remote_target_id;
            if ( $target_value && $target_value =~ m{/ticket/(\d+)$} ) {
                $remote_target_id = $1;
            }
            elsif ( $target_value && $target_value =~ /^(\d+)$/ ) {
                $remote_target_id = $1;
            }

            if ($remote_target_id) {
                # Look up local ticket ID from our mapping
                my $local_target_id = $REMOTE_TICKET_MAP{$remote_target_id};

                if ($local_target_id) {
                    # Build local URI
                    my $local_uri = RT::URI->new( RT->SystemUser );
                    $local_uri->FromObject( RT::Ticket->new( RT->SystemUser ) );
                    my $base_uri = $local_uri->Resolver->LocalURIPrefix;
                    my $local_target_uri = "$base_uri/ticket/$local_target_id";

                    if ( $type eq 'AddLink' ) {
                        $new_value = $local_target_uri;
                    }
                    else {
                        $old_value = $local_target_uri;
                    }
                    RT->Logger->debug("$type: Resolved remote ticket $remote_target_id to local $local_target_id");
                }
                else {
                    RT->Logger->warning("$type: Remote ticket $remote_target_id not imported yet - skipping link transaction");
                    $skipped++;
                    next;
                }
            }
            else {
                # External link (not to another RT ticket) - keep as-is
                RT->Logger->debug("$type: External link, keeping value as-is: $target_value");
            }
        }

        # Handle Force (forcible owner change) - resolve user IDs
        if ( $type eq 'Force' ) {
            for my $val_ref ( \$old_value, \$new_value ) {
                next unless defined $$val_ref;
                my $raw_val = $$val_ref;

                # REST2 may return user as hash with {id, _url}
                my $user_id;
                my $user_email;
                my $user_realname;

                if ( ref($raw_val) eq 'HASH' ) {
                    $user_id = $raw_val->{id};
                    if ( $raw_val->{_url} ) {
                        my $user_data = $class->_MakeRequest(
                            Token => $args{Token},
                            URL   => $raw_val->{_url},
                        );
                        if ($user_data) {
                            $user_email = $user_data->{EmailAddress} // $user_data->{Name};
                            $user_realname = $user_data->{RealName};
                        }
                    }
                }
                else {
                    $user_id = $raw_val;
                }

                # Try to resolve to local user
                if ($user_email) {
                    my $user = $class->LoadOrCreateUser(
                        EmailAddress => $user_email,
                        RealName     => $user_realname,
                        Privileged   => $args{PrivilegedUsers},
                    );
                    $$val_ref = $user->Id if $user && $user->Id;
                }
                elsif ( $user_id && $user_id =~ /^\d+$/ ) {
                    # Numeric ID without email - fetch from remote
                    my $user_url = $args{Source} . '/REST/2.0/user/' . $user_id;
                    my $user_data = $class->_MakeRequest(
                        Token => $args{Token},
                        URL   => $user_url,
                    );
                    if ($user_data) {
                        my $user = $class->LoadOrCreateUser(
                            EmailAddress => $user_data->{EmailAddress} // $user_data->{Name},
                            RealName     => $user_data->{RealName},
                            Privileged   => $args{PrivilegedUsers},
                        );
                        $$val_ref = $user->Id if $user && $user->Id;
                    }
                }
            }
        }

        # Handle SetWatcher - similar to AddWatcher but for replacement
        if ( $type eq 'SetWatcher' ) {
            # Normalize field name
            $field = 'Requestor' if $field && $field =~ /^requestor$/i;
            $field = 'Cc' if $field && $field =~ /^cc$/i;
            $field = 'AdminCc' if $field && $field =~ /^admincc$/i;

            my $raw_value = $remote_txn->{NewValue};
            my $principal_email;
            my $principal_realname;

            if ( ref($raw_value) eq 'HASH' && $raw_value->{id} ) {
                my $user_url = $args{Source} . '/REST/2.0/user/' . $raw_value->{id};
                my $user_data = $class->_MakeRequest(
                    Token => $args{Token},
                    URL   => $user_url,
                );
                if ($user_data) {
                    $principal_email = $user_data->{EmailAddress} // $user_data->{Name};
                    $principal_realname = $user_data->{RealName};
                }
            }
            else {
                $principal_email = $raw_value;
            }

            if ($principal_email) {
                my $user = $class->LoadOrCreateUser(
                    EmailAddress => $principal_email,
                    RealName     => $principal_realname,
                    Privileged   => $args{PrivilegedUsers},
                );
                $new_value = $user->PrincipalId if $user && $user->Id;
            }
        }

        # Handle Reminder transactions - NewValue contains reminder ticket ID
        # Reminders are separate tickets, so we may not have imported them
        if ( $type =~ /^(?:Add|Open|Resolve)Reminder$/ ) {
            my $remote_reminder_id = $new_value;
            if ( ref($remote_reminder_id) eq 'HASH' ) {
                $remote_reminder_id = $remote_reminder_id->{id};
            }

            if ( $remote_reminder_id && $REMOTE_TICKET_MAP{$remote_reminder_id} ) {
                $new_value = $REMOTE_TICKET_MAP{$remote_reminder_id};
                RT->Logger->debug("$type: Resolved reminder ticket $remote_reminder_id to local " . $new_value);
            }
            elsif ($remote_reminder_id) {
                RT->Logger->warning("$type: Reminder ticket $remote_reminder_id not imported - keeping remote ID (may not display correctly)");
                # Keep the remote ID; the transaction will be recorded but may not link correctly
            }
        }

        # Debug: show what we're creating
        RT->Logger->debug("Creating $type txn: Field=" . ($field // 'undef')
            . ", OldValue=" . ($old_value // 'undef')
            . ", NewValue=" . ($new_value // 'undef'));

        my $transaction = RT::Transaction->new( $ticket->CurrentUser );
        my ( $txn_id, $msg ) = $transaction->Create(
            Ticket         => $ticket->Id,
            Type           => $type,
            Data           => $remote_txn->{Data} // '',
            OldValue       => $old_value,
            NewValue       => $new_value,
            Field          => $field,
            MIMEObj        => $mime,
            Creator        => $creator_id || RT->SystemUser->Id,
            ActivateScrips => 0,
        );

        if ($txn_id) {
            $created++;

            my $txn_obj = RT::Transaction->new( RT->SystemUser );
            $txn_obj->Load($txn_id);

            # Backdate transaction
            if ( $remote_txn->{Created} ) {
                my $date = $class->ParseISO8601( $remote_txn->{Created} );
                $txn_obj->__Set( Field => 'Created', Value => $date->ISO );
            }
        }
        else {
            RT->Logger->error("Failed to create $type transaction: $msg");
            $skipped++;
        }
    }

    return ( $created, $skipped );
}

sub ParseISO8601 {
    my $class      = shift;
    my $iso_string = shift;

    my $date = RT::Date->new( RT->SystemUser );

    # REST2 returns ISO 8601 timestamps like:
    #   "2025-02-25T14:52:49Z"       (UTC with Z suffix)
    #   "2025-02-25T14:52:49+00:00"  (UTC with offset)
    #   "2025-02-25T09:52:49-05:00"  (EST with offset)

    my $parsed   = $iso_string;
    my $timezone = 'UTC';

    # Handle timezone offset like +00:00 or -05:00
    if ( $parsed =~ s/([+-])(\d{2}):?(\d{2})$// ) {
        my ( $sign, $hours, $mins ) = ( $1, $2, $3 );
        # RT::Date handles UTC; we need to adjust the time if there's an offset
        my $offset_seconds = ( $hours * 3600 + $mins * 60 ) * ( $sign eq '-' ? -1 : 1 );
        # Parse as-is, then adjust - RT::Date's timezone handling is tricky
        # For now, assume REST2 returns UTC (Z or +00:00) and log if different
        if ( $offset_seconds != 0 ) {
            RT->Logger->debug("ParseISO8601: Non-UTC offset found: $iso_string (offset ${sign}${hours}:${mins})");
        }
    }

    # Handle Z suffix (UTC)
    $parsed =~ s/Z$//;

    # Convert T to space for RT::Date
    $parsed =~ s/T/ /;

    $date->Set( Format => 'ISO', Value => $parsed, Timezone => $timezone );

    RT->Logger->debug("ParseISO8601: '$iso_string' -> '" . $date->ISO . "' (stored as UTC)");

    return $date;
}

sub LoadOrCreateUser {
    my $class = shift;
    my %args  = (
        EmailAddress => undef,
        Name         => undef,
        RealName     => undef,
        Privileged   => 0,
        @_,
    );

    my $identifier = $args{EmailAddress} || $args{Name};
    return unless $identifier;

    my $user = RT::User->new( RT->SystemUser );
    $user->Load($identifier);

    if ( $user->Id ) {
        # Update RealName if provided and user doesn't have one (or has placeholder)
        if ( $args{RealName} && ( !$user->RealName || $user->RealName eq $user->Name ) ) {
            my ( $ok, $msg ) = $user->SetRealName( $args{RealName} );
            RT->Logger->debug("Updated RealName for $identifier: " . $args{RealName}) if $ok;
        }
        return $user;
    }

    # Create new user
    my ( $ok, $msg ) = $user->Create(
        Name       => $identifier,
        RealName   => $args{RealName} // '',
        Privileged => $args{Privileged} ? 1 : 0,
    );

    if ($ok) {
        RT->Logger->info("Created user: $identifier");
        return $user;
    }

    RT->Logger->error("Failed to create user $identifier: $msg");
    return;
}

sub _GetSinceDate {
    my $class = shift;
    my $days  = shift || 30;

    my $date = RT::Date->new( RT->SystemUser );
    $date->SetToNow;
    $date->AddDays( -$days );
    return $date->ISO;
}

RT::Base->_ImportOverlays();

1;

__END__

=head1 NAME

RT::Migrate::Importer - Import tickets from a remote RT instance

=head1 SYNOPSIS

    use RT::Migrate::Importer;

    # Import from specific queues
    my ($created, $updated, $skipped) = RT::Migrate::Importer->run(
        CurrentUser => $current_user,
        Source      => 'https://rt.example.com',
        Token       => 'your-api-token',
        Queues      => ['General', 'Support'],
        Days        => 30,
    );

    # Import from all queues with custom limit per queue
    my ($created, $updated, $skipped) = RT::Migrate::Importer->run(
        CurrentUser => $current_user,
        Source      => 'https://rt.example.com',
        Token       => 'your-api-token',
        Queues      => [],           # Empty = all queues
        PerQueue    => 25,           # Custom limit per queue (default: 15)
        Days        => 30,
    );

=head1 DESCRIPTION

This module provides functionality to import tickets from a remote RT
instance to the local RT instance via the REST2 API. It handles:

=over

=item * Fetching tickets via REST2 with pagination

=item * Creating local tickets with matching metadata

=item * Replaying transactions (Correspond, Comment, CustomField, etc.)

=item * Resolving users by email, creating if not found

=item * Tracking imported tickets to avoid duplicates

=item * Per-queue ticket limits to control import volume

=back

=head1 METHODS

=head2 run(%args)

Main entry point. Takes the following arguments:

=over

=item CurrentUser - RT::CurrentUser object

=item Source - URL of remote RT instance

=item Token - REST2 API token

=item Queues - ArrayRef of queue names to import from. If empty, imports from all queues.

=item Days - Number of days to look back (default: 30)

=item PerQueue - Maximum tickets to import per queue (default: 15)

=item Delay - Seconds to sleep between importing each ticket (default: 1)

=item DryRun - If true, don't make changes

=item PrivilegedUsers - If true, create new users as privileged (default: 0)

=back

Returns ($created, $skipped, \@imported) where @imported is an array
of hashrefs with remote_id, local_id, queue, and subject for each ticket.

=head2 FetchRemoteQueues(%args)

Fetches list of queue names from the remote RT instance.

=head2 FetchRemoteTickets(%args)

Fetches tickets from the remote RT instance via REST2.

=head2 FetchTicketDetails(%args)

Fetches full details for a single ticket.

=head2 FetchTicketHistory(%args)

Fetches transaction history for a ticket.

=head2 CreateTicket(%args)

Creates a local ticket from remote ticket data. Takes the following arguments:

=over

=item CurrentUser - RT::CurrentUser object

=item RemoteTicket - HashRef of ticket data from REST2 API

=item QueueName - Name of the local queue (already validated to exist)

=item Transactions - ArrayRef of transaction data (optional, for Create content)

=item Source - URL of remote RT instance (required if Transactions provided)

=item Token - REST2 API token (required if Transactions provided)

=back

If Transactions, Source, and Token are provided, extracts content from the
remote Create transaction and includes it in the local ticket's Create
transaction via L</BuildCreateMIME>.

=head2 BuildCreateMIME(%args)

Builds a MIME object from the Create transaction's attachments. Takes:

=over

=item Transactions - ArrayRef of transaction data

=item Source - URL of remote RT instance

=item Token - REST2 API token

=back

Returns a MIME::Entity object, or undef if no content found.

=head2 ReplayTransactions(%args)

Replays content-bearing transactions (Correspond, Comment, etc.) on a local
ticket. Takes:

=over

=item CurrentUser - RT::CurrentUser object

=item LocalTicket - RT::Ticket object to replay transactions on

=item Transactions - ArrayRef of transaction data from REST2 API

=item Source - URL of remote RT instance

=item Token - REST2 API token

=back

Skips Create transactions since those are handled by L</CreateTicket>.
Returns ($created, $skipped) counts.

=head2 ParseISO8601($string)

Parses an ISO 8601 date string and returns an RT::Date object.

=head2 LoadOrCreateUser(%args)

Loads a user by email, creating if not found. Takes:

=over

=item EmailAddress - Email address to look up/create

=item Name - Alternative identifier if EmailAddress not provided

=item RealName - User's real name (optional)

=item Privileged - If true, create user as privileged (default: 0)

=back

=head1 AUTHOR

Best Practical Solutions, LLC E<lt>modules@bestpractical.comE<gt>

=cut
