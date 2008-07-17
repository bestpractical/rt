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
use strict;
use warnings;

package RT::ScripAction::CreateTickets;
require RT::ScripAction::Generic;

use base qw(RT::ScripAction::Generic);

use MIME::Entity;

=head1 name

RT::ScripAction::CreateTickets - Create one or more tickets according
to an externally supplied template.

=head1 SYNOPSIS

 ===Create-Ticket codereview
 Subject: Code review for {$Tickets{'TOP'}->subject}
 Depended-On-By: TOP
 Content: Someone has Created a ticket. you should review and approve it,
 so they can finish their work
 ENDOFCONTENT

=head1 description


Using the "CreateTickets" ScripAction and mandatory dependencies, RT now has 
the ability to model complex workflow. When a ticket is Created in a queue
that has a "CreateTickets" scripaction, that ScripAction parses its "Template"



=head2 FORMAT

CreateTickets uses the template as a template for an ordered set of tickets 
to create. The basic format is as follows:


 ===Create-Ticket: identifier
 Param: Value
 Param2: Value
 Param3: Value
 Content: Blah
 blah
 blah
 ENDOFCONTENT
 ===Create-Ticket: id2
 Param: Value
 Content: Blah
 ENDOFCONTENT


Each ===Create-Ticket: section is evaluated as its own 
Text::Template object, which means that you can embed snippets
of perl inside the Text::Template using {} delimiters, but that 
such sections absolutely can not span a ===Create-Ticket boundary.

After each ticket is Created, it's stuffed into a hash called %Tickets
so as to be available during the creation of other tickets during the same 
ScripAction.  The hash is prepopulated with the ticket which triggered the 
ScripAction as $Tickets{'TOP'}; you can also access that ticket using the
shorthand TOP.

A simple example:

 ===Create-Ticket: codereview
 Subject: Code review for {$Tickets{'TOP'}->subject}
 Depended-On-By: TOP
 Content: Someone has Created a ticket. you should review and approve it,
 so they can finish their work
 ENDOFCONTENT



A convoluted example

 ===Create-Ticket: approval
 { # Find out who the administrators of the group called "HR" 
   # of which the creator of this ticket is a member
    my $name = "HR";
   
    my $groups = RT::Model::GroupCollection->new(current_user => RT->system_user);
    $groups->limit_to_user_defined_groups();
    $groups->limit(column => "name", operator => "=", value => "$name");
    $groups->with_member($transaction_obj->creator_obj->id);
 
    my $groupid = $groups->first->id;
 
    my $admin_ccs = RT::Model::UserCollection->new(current_user => RT->system_user);
    $admin_ccs->who_have_right(
	right => "AdminGroup",
	object =>$groups->first,
	include_system_rights => undef,
	include_superusers => 0,
	include_subgroup_members => 0,
    );
 
     my @admins;
     while (my $admin = $admin_ccs->next) {
         push (@admins, $admin->email); 
     }
 }
 Queue: ___Approvals
 Type: approval
 AdminCc: {join ("\nAdminCc: ",@admins) }
 Depended-On-By: TOP
 Refers-To: TOP
 Subject: Approval for ticket: {$Tickets{"TOP"}->id} - {$Tickets{"TOP"}->subject}
 Due: {time + 86400}
 Content-Type: text/plain
 Content: Your approval is requested for the ticket {$Tickets{"TOP"}->id}: {$Tickets{"TOP"}->subject}
 Blah
 Blah
 ENDOFCONTENT
 ===Create-Ticket: two
 Subject: Manager approval
 Depended-On-By: TOP
 Refers-On: {$Tickets{"approval"}->id}
 Queue: ___Approvals
 Content-Type: text/plain
 Content: 
 Your approval is requred for this ticket, too.
 ENDOFCONTENT
 
=head2 acceptable fields

A complete list of acceptable fields for this beastie:


    *  queue           => name or id# of a queue
       subject         => A text string
     ! Status          => A valid status. defaults to 'new'
       Due             => Dates can be specified in seconds since the epoch
                          to be handled literally or in a semi-free textual
                          format which RT will attempt to parse.
                        
                          
                          
       starts          => 
       Started         => 
       resolved        => 
       Owner           => Username or id of an RT user who can and should own 
                          this ticket; forces the owner if necessary
   +   Requestor       => Email address
   +   Cc              => Email address 
   +   AdminCc         => Email address 
       time_worked      => 
       time_estimated   => 
       time_left        => 
       initial_priority => 
       final_priority   => 
       type            => 
    +! DependsOn       => 
    +! DependedOnBy    =>
    +! RefersTo        =>
    +! ReferredToBy    => 
    +! Members         =>
    +! MemberOf        => 
       Content         => content. Can extend to multiple lines. Everything
                          within a template after a Content: header is treated
                          as content until we hit a line containing only 
                          ENDOFCONTENT
       Content_type     => the content-type of the content field.  Defaults to
                          'text/plain'
       UpdateType      => 'correspond' or 'comment'; used in conjunction with
                          'content' if this is an update.  Defaults to
                          'correspond'

       CustomField-<id#> => custom field value
       CF-name           => custom field value
       CustomField-name  => custom field value

Fields marked with an * are required.

Fields marked with a + may have multiple values, simply
by repeating the fieldname on a new line with an additional value.

Fields marked with a ! are postponed to be processed after all
tickets in the same actions are Created.  Except for 'Status', those
field can also take a ticket name within the same action (i.e.
the identifiers after ==Create-Ticket), instead of raw Ticket ID
numbers.

When parsed, field names are converted to lowercase and have -s stripped.
Refers-To, RefersTo, refersto, refers-to and r-e-f-er-s-tO will all 
be treated as the same thing.




=head1 AUTHOR

Jesse Vincent <jesse@bestpractical.com> 

=head1 SEE ALSO

perl(1).

=cut

my %LINKTYPEMAP = (
    MemberOf => {
        type => 'MemberOf',
        mode => 'target',
    },
    Parents => {
        type => 'MemberOf',
        mode => 'target',
    },
    Members => {
        type => 'MemberOf',
        mode => 'base',
    },
    Children => {
        type => 'MemberOf',
        mode => 'base',
    },
    has_member => {
        type => 'MemberOf',
        mode => 'base',
    },
    RefersTo => {
        type => 'RefersTo',
        mode => 'target',
    },
    ReferredToBy => {
        type => 'RefersTo',
        mode => 'base',
    },
    DependsOn => {
        type => 'DependsOn',
        mode => 'target',
    },
    DependedOnBy => {
        type => 'DependsOn',
        mode => 'base',
    },

);

# {{{ Scrip methods (Commit, Prepare)

# {{{ sub commit
#Do what we need to do and send it out.
sub commit {
    my $self = shift;

    # Create all the tickets we care about
    return (1) unless $self->ticket_obj->type eq 'ticket';

    $self->create_by_template( $self->ticket_obj );
    $self->update_by_template( $self->ticket_obj );
    return (1);
}

# }}}

# {{{ sub prepare

sub prepare {
    my $self = shift;

    unless ( $self->template_obj ) {
        Jifty->log->warn("No template object handed to $self\n");
    }

    unless ( $self->transaction_obj ) {
        Jifty->log->warn("No transaction object handed to $self\n");

    }

    unless ( $self->ticket_obj ) {
        Jifty->log->warn("No ticket object handed to $self\n");

    }

    $self->parse(
        content         => $self->template_obj->content,
        _active_content => 1
    );
    return 1;

}

# }}}

# }}}

sub create_by_template {
    my $self = shift;
    my $top  = shift;

    Jifty->log->debug("In CreateByTemplate");

    my @results;

    # XXX: cargo cult programming that works. i'll be back.
    use bytes;

    local %T::Tickets = %T::Tickets;
    local $T::TOP     = $T::TOP;
    local $T::ID      = $T::ID;
    $T::Tickets{'TOP'} = $T::TOP = $top if $top;

    my $ticketargs;
    my ( @links, @postponed );
    foreach my $template_id ( @{ $self->{'CreateTickets'} } ) {
        Jifty->log->debug("Workflow: processing $template_id of $T::TOP")
            if $T::TOP;

        $T::ID    = $template_id;
        @T::AllID = @{ $self->{'CreateTickets'} };

        ( $T::Tickets{$template_id}, $ticketargs ) = $self->parse_lines( $template_id, \@links, \@postponed );

        # Now we have a %args to work with.
        # Make sure we have at least the minimum set of
        # reasonable data and do our thang

        my ( $id, $transid, $msg ) = $T::Tickets{$template_id}->create(%$ticketargs);

        foreach my $res ( split( '\n', $msg ) ) {
            push @results, _( "Ticket %1", $T::Tickets{$template_id}->id ) . ': ' . $res;
        }
        if ( !$id ) {
            if ( $self->ticket_obj ) {
                $msg = "Couldn't create related ticket $template_id for " . $self->ticket_obj->id . " " . $msg;
            } else {
                $msg = "Couldn't create ticket $template_id " . $msg;
            }

            Jifty->log->error($msg);
            next;
        }

        Jifty->log->debug("Assigned $template_id with $id");
        $T::Tickets{$template_id}->set_origin_obj( $self->ticket_obj )
            if $self->ticket_obj
                && $T::Tickets{$template_id}->can('SetOriginObj');

    }

    $self->post_process( \@links, \@postponed );

    return @results;
}

sub update_by_template {
    my $self = shift;
    my $top  = shift;

    # XXX: cargo cult programming that works. i'll be back.
    use bytes;

    my @results;
    local %T::Tickets = %T::Tickets;
    local $T::ID      = $T::ID;

    my $ticketargs;
    my ( @links, @postponed );
    foreach my $template_id ( @{ $self->{'update_tickets'} } ) {
        Jifty->log->debug("Update Workflow: processing $template_id");

        $T::ID    = $template_id;
        @T::AllID = @{ $self->{'update_tickets'} };

        ( $T::Tickets{$template_id}, $ticketargs ) = $self->parse_lines( $template_id, \@links, \@postponed );

        # Now we have a %args to work with.
        # Make sure we have at least the minimum set of
        # reasonable data and do our thang

        my @attribs = qw(
            subject
            final_priority
            priority
            time_estimated
            time_worked
            time_left
            status
            queue
            due
            starts
            Started
            resolved
        );

        my $id = $template_id;
        $id =~ s/update-(\d+).*/$1/;
        my ( $loaded, $msg ) = $T::Tickets{$template_id}->load_by_id($id);

        unless ($loaded) {
            Jifty->log->error( "Couldn't update ticket $template_id: " . $msg );
            push @results, _( "Couldn't load ticket '%1'", $id );
            next;
        }

        my $current = $self->get_base_template( $T::Tickets{$template_id} );

        $template_id =~ m/^update-(.*)/;
        my $base_id = "base-$1";
        my $base    = $self->{'templates'}->{$base_id};
        if ($base) {
            $base    =~ s/\r//g;
            $base    =~ s/\n+$//;
            $current =~ s/\n+$//;

            # If we have no base template, set what we can.
            if ( $base ne $current ) {
                push @results, "Could not update ticket " . $T::Tickets{$template_id}->id . ": Ticket has changed";
                next;
            }
        }
        push @results, $T::Tickets{$template_id}->update(
            attributes_ref => \@attribs,
            args_ref       => $ticketargs
        );

        if ( $ticketargs->{'owner'} ) {
            ( $id, $msg ) = $T::Tickets{$template_id}->set_owner( $ticketargs->{'owner'}, "Force" );
            push @results, $msg
                unless $msg eq _("That user already owns that ticket");
        }

        push @results, $self->update_watchers( $T::Tickets{$template_id}, $ticketargs );

        push @results, $self->update_custom_fields( $T::Tickets{$template_id}, $ticketargs );

        next unless $ticketargs->{'mime_obj'};
        if ( $ticketargs->{'UpdateType'} =~ /^(private|comment)$/i ) {
            my ( $Transaction, $description, $object ) = $T::Tickets{$template_id}->comment(
                bcc_message_to => $ticketargs->{'Bcc'},
                mime_obj       => $ticketargs->{'mime_obj'},
                time_taken     => $ticketargs->{'time_worked'}
            );
            push( @results, $T::Tickets{$template_id}->_( "Ticket %1", $T::Tickets{$template_id}->id ) . ': ' . $description );
        } elsif ( $ticketargs->{'UpdateType'} =~ /^(public|response|correspond)$/i ) {
            my ( $Transaction, $description, $object ) = $T::Tickets{$template_id}->correspond(
                bcc_message_to => $ticketargs->{'Bcc'},
                mime_obj       => $ticketargs->{'mime_obj'},
                time_taken     => $ticketargs->{'time_worked'}
            );
            push( @results, $T::Tickets{$template_id}->_( "Ticket %1", $T::Tickets{$template_id}->id ) . ': ' . $description );
        } else {
            push( @results, $T::Tickets{$template_id}->_("Update type was neither correspondence nor comment.") . " " . $T::Tickets{$template_id}->_("Update not recorded.") );
        }
    }

    $self->post_process( \@links, \@postponed );

    return @results;
}

=head2 parse  TEMPLATE_CONTENT, DEFAULT_QUEUE, DEFAULT_REQEUESTOR ACTIVE

Parse a template from TEMPLATE_CONTENT

If $active is set to true, then we'll use Text::Template to parse the templates,
allowing you to embed active perl in your templates.

=cut

sub parse {
    my $self = shift;
    my %args = (
        content         => undef,
        queue           => undef,
        requestor       => undef,
        _active_content => undef,
        @_
    );

    if ( $args{'_active_content'} ) {
        $self->{'UsePerlTextTemplate'} = 1;
    } else {

        $self->{'UsePerlTextTemplate'} = 0;
    }

    if ( substr( $args{'content'}, 0, 3 ) eq '===' ) {
        $self->_parse_multiline_template(%args);
    } elsif ( $args{'content'} =~ /(?:\t|,)/i ) {
        $self->_parse_xsv_template(%args);

    }
}

=head2 _parse_multiline_template

Parses mulitline templates. Things like:

 ===Create-Ticket ... 

Takes the same arguments as Parse

=cut

sub _parse_multiline_template {
    my $self = shift;
    my %args = (@_);

    my $template_id;
    my ( $queue, $requestor );
    Jifty->log->debug("Line: ===");
    foreach my $line ( split( /\n/, $args{'content'} ) ) {
        $line =~ s/\r$//;
        Jifty->log->debug("Line: $line");
        if ( $line =~ /^===/ ) {
            if ( $template_id && !$queue && $args{'queue'} ) {
                $self->{'templates'}->{$template_id} .= "Queue: $args{'queue'}\n";
            }
            if ( $template_id && !$requestor && $args{'requestor'} ) {
                $self->{'templates'}->{$template_id} .= "Requestor: $args{'requestor'}\n";
            }
            $queue     = 0;
            $requestor = 0;
        }
        if ( $line =~ /^===Create-Ticket: (.*)$/ ) {
            $template_id = "create-$1";
            Jifty->log->debug("****  Create ticket: $template_id");
            push @{ $self->{'CreateTickets'} }, $template_id;
        } elsif ( $line =~ /^===Update-Ticket: (.*)$/ ) {
            $template_id = "update-$1";
            Jifty->log->debug("****  Update ticket: $template_id");
            push @{ $self->{'update_tickets'} }, $template_id;
        } elsif ( $line =~ /^===base-Ticket: (.*)$/ ) {
            $template_id = "base-$1";
            Jifty->log->debug("****  base ticket: $template_id");
            push @{ $self->{'base_tickets'} }, $template_id;
        } elsif ( $line =~ /^===#.*$/ ) {    # a comment
            next;
        } else {
            if ( $line =~ /^Queue:(.*)/i ) {
                $queue = 1;
                my $value = $1;
                $value =~ s/^\s//;
                $value =~ s/\s$//;
                if ( !$value && $args{'queue'} ) {
                    $value = $args{'queue'};
                    $line  = "Queue: $value";
                }
            }
            if ( $line =~ /^Requestors?:(.*)/i ) {
                $requestor = 1;
                my $value = $1;
                $value =~ s/^\s//;
                $value =~ s/\s$//;
                if ( !$value && $args{'requestor'} ) {
                    $value = $args{'requestor'};
                    $line  = "Requestor: $value";
                }
            }
            $self->{'templates'}->{$template_id} .= $line . "\n";
        }
    }
    if ( $template_id && !$queue && $args{'queue'} ) {
        $self->{'templates'}->{$template_id} .= "Queue: $args{'queue'}\n";
    }
}

sub parse_lines {
    my $self        = shift;
    my $template_id = shift;
    my $links       = shift;
    my $postponed   = shift;

    my $content = $self->{'templates'}->{$template_id};

    if ( $self->{'UsePerlTextTemplate'} ) {

        Jifty->log->debug("Workflow: evaluating\n$self->{templates}{$template_id}");

        my $template = Text::Template->new(
            TYPE   => 'STRING',
            SOURCE => $content
        );

        my $err;
        $content = $template->fill_in(
            PACKAGE => 'T',
            BROKEN  => sub {
                $err = {@_}->{error};
            }
        );

        Jifty->log->debug("Workflow: yielding\n$content");

        if ($err) {
            Jifty->log->error( "Ticket creation failed: " . $err );
            while ( my ( $k, $v ) = each %T::X ) {
                Jifty->log->debug("Eliminating $template_id from ${k}'s parents.");
                delete $v->{$template_id};
            }
            next;
        }
    }

    my $ticket_obj ||= RT::Model::Ticket->new;

    my %args;
    my %original_tags;
    my @lines = ( split( /\n/, $content ) );
    while ( defined( my $line = shift @lines ) ) {
        if ( $line =~ /^(.*?):(?:\s+)(.*?)(?:\s*)$/ ) {
            my $value        = $2;
            my $original_tag = $1;
            my $tag          = lc($original_tag);
            $tag =~ s/-//g;
            $tag =~ s/^(requestor|cc|admin_cc)s?$/$1/i;

            $original_tags{$tag} = $original_tag;

            if ( ref( $args{$tag} ) ) {    #If it's an array, we want to push the value
                push @{ $args{$tag} }, $value;
            } elsif ( defined( $args{$tag} ) ) {    #if we're about to get a second value, make it an array
                $args{$tag} = [ $args{$tag}, $value ];
            } else {                                #if there's nothing there, just set the value
                $args{$tag} = $value;
            }

            if ( $tag =~ /^content$/i ) {           #just build up the content
                                                    # convert it to an array
                $args{$tag} = defined($value) ? [ $value . "\n" ] : [];
                while ( defined( my $l = shift @lines ) ) {
                    last if ( $l =~ /^ENDOFCONTENT\s*$/ );
                    push @{ $args{'content'} }, $l . "\n";
                }
            } else {

                # if it's not content, strip leading and trailing spaces
                if ( $args{$tag} ) {
                    $args{$tag} =~ s/^\s+//g;
                    $args{$tag} =~ s/\s+$//g;
                }
                if ( ( $tag =~ /^(requestor|cc|admin_cc)$/i or grep { lc $_ eq $tag } keys %LINKTYPEMAP )
                    and $args{$tag} =~ /,/ )
                {
                    $args{$tag} = [ split /,\s*/, $args{$tag} ];
                }
            }
        }
    }

    foreach my $date qw(due starts started resolved) {
        my $dateobj = RT::Date->new;
        next unless $args{$date};
        if ( $args{$date} =~ /^\d+$/ ) {
            $dateobj->set( format => 'unix', value => $args{$date} );
        } else {
            eval { $dateobj->set( format => 'iso', value => $args{$date} ); };
            if ( $@ or $dateobj->unix <= 0 ) {
                $dateobj->set( format => 'unknown', value => $args{$date} );
            }
        }
        $args{$date} = $dateobj->iso;
    }

    $args{'requestor'} ||= $self->ticket_obj->role_group("requestor")->member_emails
        if $self->ticket_obj;

    $args{'type'} ||= 'ticket';

    my %ticketargs = (
        queue            => $args{'queue'},
        subject          => $args{'subject'},
        status           => $args{'status'} || 'new',
        due              => $args{'due'},
        starts           => $args{'starts'},
        started          => $args{'started'},
        resolved         => $args{'resolved'},
        owner            => $args{'owner'},
        requestor        => $args{'requestor'},
        cc               => $args{'cc'},
        admin_cc         => $args{'admin_cc'},
        time_worked      => $args{'time_worked'},
        time_estimated   => $args{'time_estimated'},
        time_left        => $args{'time_left'},
        initial_priority => $args{'initial_priority'} || 0,
        final_priority   => $args{'final_priority'} || 0,
        type             => $args{'type'},
    );

    if ( $args{content} ) {
        my $mime_obj = MIME::Entity->new();
        $mime_obj->build(
            Type => $args{'content_type'} || 'text/plain',
            Data => $args{'content'}
        );
        $ticketargs{mime_obj} = $mime_obj;
        $ticketargs{UpdateType} = $args{'updatetype'} || 'correspond';
    }

    foreach my $tag ( keys(%args) ) {

        # if the tag was added later, skip it
        my $orig_tag = $original_tags{$tag} or next;
        if ( $orig_tag =~ /^custom_?field-?(\d+)$/i ) {
            $ticketargs{ "custom_field-" . $1 } = $args{$tag};
        } elsif ( $orig_tag =~ /^(?:custom_?field|cf)-?(.*)$/i ) {
            my $cf = RT::Model::CustomField->new;
            $cf->load_by_name( name => $1, queue => $ticketargs{queue} );
            $ticketargs{ "custom_field-" . $cf->id } = $args{$tag};
        } elsif ($orig_tag) {
            my $cf = RT::Model::CustomField->new;
            $cf->load_by_name(
                name  => $orig_tag,
                queue => $ticketargs{queue}
            );
            next unless ( $cf->id );
            $ticketargs{ "custom_field-" . $cf->id } = $args{$tag};

        }
    }

    $self->get_deferred( \%args, $template_id, $links, $postponed );

    return $ticket_obj, \%ticketargs;
}

=head2 _parse_xsvtemplate 

Parses a tab or comma delimited template. Should only ever be called by Parse

=cut

sub _parse_xsv_template {
    my $self = shift;
    my %args = (@_);

    use Regexp::Common qw(delimited);
    my ( $first, $content ) = split( /\r?\n/, $args{'content'}, 2 );

    my $delimiter;
    if ( $first =~ /\t/ ) {
        $delimiter = "\t";
    } else {
        $delimiter = ',';
    }
    my @fields = split( /$delimiter/, $first );

    my $delimiter_re = qr[$delimiter];
    my $justquoted   = qr[$RE{quoted}];

    # Used to generate automatic template ids
    my $autoid = 1;

LINE:
    while ($content) {
        $content =~ s/^(\s*\r?\n)+//;

        # Keep track of queue and Requestor, so we can provide defaults
        my $queue;
        my $requestor;

        # The template for this line
        my $template;

        # What column we're on
        my $i = 0;

        # If the last iteration was the end of the line
        my $EOL = 0;

        # The template id
        my $template_id;

    COLUMN:
        while ( not $EOL
            and length $content
            and $content =~ s/^($justquoted|.*?)($delimiter_re|$)//smix )
        {
            $EOL = not $2;

            # Strip off quotes, if they exist
            my $value = $1;
            if ( $value =~ /^$RE{delimited}{-delim=>qq{\'\"}}$/ ) {
                substr( $value, 0,  1 ) = "";
                substr( $value, -1, 1 ) = "";
            }

            # What column is this?
            my $field = $fields[ $i++ ];
            next COLUMN unless $field =~ /\S/;
            $field =~ s/^\s//;
            $field =~ s/\s$//;

            if ( $field =~ /^id$/i ) {

                # Special case if this is the ID column
                if ( $value =~ /^\d+$/ ) {
                    $template_id = 'update-' . $value;
                    push @{ $self->{'update_tickets'} }, $template_id;
                } elsif ( $value =~ /^#base-(\d+)$/ ) {
                    $template_id = 'base-' . $1;
                    push @{ $self->{'base_tickets'} }, $template_id;
                } elsif ( $value =~ /\S/ ) {
                    $template_id = 'create-' . $value;
                    push @{ $self->{'CreateTickets'} }, $template_id;
                }
            } else {

                # Some translations
                if (   $field =~ /^Body$/i
                    || $field =~ /^Data$/i
                    || $field =~ /^Message$/i )
                {
                    $field = 'content';
                } elsif ( $field =~ /^Summary$/i ) {
                    $field = 'subject';
                } elsif ( $field =~ /^Queue$/i ) {

                    # Note that we found a queue
                    $queue = 1;
                    $value ||= $args{'queue'};
                } elsif ( $field =~ /^Requestors?$/i ) {
                    $field     = 'Requestor';    # Remove plural
                                                 # Note that we found a requestor
                    $requestor = 1;
                    $value ||= $args{'requestor'};
                }

                # Tack onto the end of the template
                $template .= $field . ": ";
                $template .= ( defined $value ? $value : "" );
                $template .= "\n";
                $template .= "ENDOFCONTENT\n"
                    if $field =~ /^content$/i;
            }
        }

        # Ignore blank lines
        next unless $template;

        # If we didn't find a queue of requestor, tack on the defaults
        if ( !$queue && $args{'queue'} ) {
            $template .= "Queue: $args{'queue'}\n";
        }
        if ( !$requestor && $args{'requestor'} ) {
            $template .= "Requestor: $args{'requestor'}\n";
        }

        # If we never found an ID, come up with one
        unless ($template_id) {
            $autoid++ while exists $self->{'templates'}->{"create-auto-$autoid"};
            $template_id = "create-auto-$autoid";

            # Also, it's a ticket to create
            push @{ $self->{'CreateTickets'} }, $template_id;
        }

        # Save the template we generated
        $self->{'templates'}->{$template_id} = $template;

    }
}

sub get_deferred {
    my $self      = shift;
    my $args      = shift;
    my $id        = shift;
    my $links     = shift;
    my $postponed = shift;

    # Deferred processing
    push @$links,
        (
        $id,
        {   DependsOn    => $args->{'dependson'},
            DependedOnBy => $args->{'dependedonby'},
            RefersTo     => $args->{'refersto'},
            ReferredToBy => $args->{'referredtoby'},
            Children     => $args->{'children'},
            Parents      => $args->{'parents'},
        }
        );

    push @$postponed, (

        # Status is postponed so we don't violate dependencies
        $id, { status => $args->{'status'}, }
    );
}

sub get_update_template {
    my $self = shift;
    my $t    = shift;

    my $string;
    $string .= "Queue: " . $t->queue_obj->name . "\n";
    $string .= "Subject: " . $t->subject . "\n";
    $string .= "Status: " . $t->status . "\n";
    $string .= "UpdateType: correspond\n";
    $string .= "Content: \n";
    $string .= "ENDOFCONTENT\n";
    $string .= "Due: " . $t->due_obj->as_string . "\n";
    $string .= "starts: " . $t->starts_obj->as_string . "\n";
    $string .= "Started: " . $t->started_obj->as_string . "\n";
    $string .= "Resolved: " . $t->resolved_obj->as_string . "\n";
    $string .= "Owner: " . $t->owner_obj->name . "\n";
    $string .= "Requestor: " . $t->role_group("requestor")->member_emails_as_string . "\n";
    $string .= "Cc: " . $t->role_group("cc")->member_emails_as_string . "\n";
    $string .= "AdminCc: " . $t->role_group("admin_cc")->member_emails_as_string . "\n";
    $string .= "time_worked: " . $t->time_worked . "\n";
    $string .= "time_estimated: " . $t->time_estimated . "\n";
    $string .= "time_left: " . $t->time_left . "\n";
    $string .= "initial_priority: " . $t->priority . "\n";
    $string .= "final_priority: " . $t->final_priority . "\n";

    foreach my $type ( sort keys %LINKTYPEMAP ) {

        # don't display duplicates
        if (   $type eq "has_member"
            || $type eq "Members"
            || $type eq "MemberOf" )
        {
            next;
        }
        $string .= "$type: ";

        my $mode   = $LINKTYPEMAP{$type}->{Mode};
        my $method = $LINKTYPEMAP{$type}->{Type};

        my $links;
        while ( my $link = $t->$method->next ) {
            $links .= ", " if $links;

            my $object = $mode . "_obj";
            my $member = $link->$object;
            $links .= $member->id if $member;
        }
        $string .= $links;
        $string .= "\n";
    }

    return $string;
}

sub get_base_template {
    my $self = shift;
    my $t    = shift;

    my $string;
    $string .= "Queue: " . $t->queue . "\n";
    $string .= "Subject: " . $t->subject . "\n";
    $string .= "Status: " . $t->status . "\n";
    $string .= "Due: " . $t->due_obj->unix . "\n";
    $string .= "starts: " . $t->starts_obj->unix . "\n";
    $string .= "Started: " . $t->started_obj->unix . "\n";
    $string .= "Resolved: " . $t->resolved_obj->unix . "\n";
    $string .= "Owner: " . $t->owner . "\n";
    $string .= "Requestor: " . $t->role_group("requestor")->member_emails_as_string . "\n";
    $string .= "Cc: " . $t->role_group("cc")->member_emails_as_string . "\n";
    $string .= "AdminCc: " . $t->role_group("admin_cc")->member_emails_as_string . "\n";
    $string .= "time_worked: " . $t->time_worked . "\n";
    $string .= "time_estimated: " . $t->time_estimated . "\n";
    $string .= "time_left: " . $t->time_left . "\n";
    $string .= "initial_priority: " . $t->priority . "\n";
    $string .= "final_priority: " . $t->final_priority . "\n";

    return $string;
}

sub get_create_template {
    my $self = shift;

    my $string;

    $string .= "Queue: General\n";
    $string .= "Subject: \n";
    $string .= "Status: new\n";
    $string .= "Content: \n";
    $string .= "ENDOFCONTENT\n";
    $string .= "Due: \n";
    $string .= "starts: \n";
    $string .= "Started: \n";
    $string .= "Resolved: \n";
    $string .= "Owner: \n";
    $string .= "Requestor: \n";
    $string .= "Cc: \n";
    $string .= "AdminCc:\n";
    $string .= "time_worked: \n";
    $string .= "time_estimated: \n";
    $string .= "time_left: \n";
    $string .= "initial_priority: \n";
    $string .= "final_priority: \n";

    foreach my $type ( keys %LINKTYPEMAP ) {

        # don't display duplicates
        if (   $type eq "has_member"
            || $type eq 'Members'
            || $type eq 'MemberOf' )
        {
            next;
        }
        $string .= "$type: \n";
    }
    return $string;
}

sub update_watchers {
    my $self   = shift;
    my $ticket = shift;
    my $args   = shift;

    my @results;

    foreach my $type qw(requestor cc admin_cc) {
        my $method  = $type . '_addresses';
        my $oldaddr = $ticket->$method;

        # Skip unless we have a defined field
        next unless defined $args->{$type};
        my $newaddr = $args->{$type};

        my @old = split( /,\s*/, $oldaddr );
        my @new;
        for ( ref $newaddr ? @{$newaddr} : split( /,\s*/, $newaddr ) ) {

            # Sometimes these are email addresses, sometimes they're
            # users.  Try to guess which is which, as we want to deal
            # with email addresses if at all possible.
            if (/^\S+@\S+$/) {
                push @new, $_;
            } else {

                # It doesn't look like an email address.  Try to load it.
                my $user = RT::Model::User->new;
                $user->load($_);
                if ( $user->id ) {
                    push @new, $user->email;
                } else {
                    push @new, $_;
                }
            }
        }

        my %oldhash = map { $_ => 1 } @old;
        my %newhash = map { $_ => 1 } @new;

        my @add    = grep( !defined $oldhash{$_}, @new );
        my @delete = grep( !defined $newhash{$_}, @old );

        foreach (@add) {
            my ( $val, $msg ) = $ticket->add_watcher(
                type  => $type,
                email => $_
            );

            push @results, $ticket->_( "Ticket %1", $ticket->id ) . ': ' . $msg;
        }

        foreach (@delete) {
            my ( $val, $msg ) = $ticket->delete_watcher(
                type  => $type,
                email => $_
            );
            push @results, $ticket->_( "Ticket %1", $ticket->id ) . ': ' . $msg;
        }
    }
    return @results;
}

sub update_custom_fields {
    my $self   = shift;
    my $ticket = shift;
    my $args   = shift;

    my @results;
    foreach my $arg ( keys %{$args} ) {
        next unless $arg =~ /^custom_?field-(\d+)$/;
        my $cf = $1;

        my $cf_obj = RT::Model::CustomField->new;
        $cf_obj->load_by_id($cf);

        my @values;
        if ( $cf_obj->type =~ /text/i ) {    # Both Text and Wikitext
            @values = ( $args->{$arg} );
        } else {
            @values = split /\n/, $args->{$arg};
        }

        if ( ( $cf_obj->type eq 'Freeform' && !$cf_obj->single_value )
            || $cf_obj->type =~ /text/i )
        {
            foreach my $val (@values) {
                $val =~ s/\r//g;
            }
        }

        foreach my $value (@values) {
            next unless length($value);
            my ( $val, $msg ) = $ticket->add_custom_field_value(
                column => $cf,
                value  => $value
            );
            push( @results, $msg );
        }
    }
    return @results;
}

sub post_process {
    my $self      = shift;
    my $links     = shift;
    my $postponed = shift;

    # postprocessing: add links

    while ( my $template_id = shift(@$links) ) {
        my $ticket = $T::Tickets{$template_id};
        Jifty->log->debug( "Handling links for " . $ticket->id );
        my %args = %{ shift(@$links) };

        foreach my $type ( keys %LINKTYPEMAP ) {
            next unless ( defined $args{$type} );
            foreach my $link ( ref( $args{$type} ) ? @{ $args{$type} } : ( $args{$type} ) ) {
                next unless $link;

                if ( $link =~ /^TOP$/i ) {
                    Jifty->log->debug( "Building $type link for $link: " . $T::Tickets{TOP}->id );
                    $link = $T::Tickets{TOP}->id;

                } elsif ( $link !~ m/^\d+$/ ) {
                    my $key = "create-$link";
                    if ( !exists $T::Tickets{$key} ) {
                        Jifty->log->debug("Skipping $type link for $key (non-existent)");
                        next;
                    }
                    Jifty->log->debug( "Building $type link for $link: " . $T::Tickets{$key}->id );
                    $link = $T::Tickets{$key}->id;
                } else {
                    Jifty->log->debug("Building $type link for $link");
                }

                my ( $wval, $wmsg ) = $ticket->add_link(
                    type                          => $LINKTYPEMAP{$type}->{'type'},
                    $LINKTYPEMAP{$type}->{'mode'} => $link,
                    silent                        => 1
                );

                Jifty->log->warn("add_link thru $link failed: $wmsg")
                    unless $wval;

                # push @non_fatal_errors, $wmsg unless ($wval);
            }

        }
    }

    # postponed actions -- Status only, currently
    while ( my $template_id = shift(@$postponed) ) {
        my $ticket = $T::Tickets{$template_id};
        Jifty->log->debug( "Handling postponed actions for " . $ticket->id );
        my %args = %{ shift(@$postponed) };
        $ticket->set_status( $args{status} ) if defined $args{status};
    }

}

1;

