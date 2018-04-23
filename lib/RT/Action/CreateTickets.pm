# BEGIN BPS TAGGED BLOCK {{{
#
# COPYRIGHT:
#
# This software is Copyright (c) 1996-2018 Best Practical Solutions, LLC
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

package RT::Action::CreateTickets;
use base 'RT::Action';

use strict;
use warnings;

use MIME::Entity;
use RT::Link;

=head1 NAME

RT::Action::CreateTickets - Create one or more tickets according to an externally supplied template

=head1 SYNOPSIS

 ===Create-Ticket: codereview
 Subject: Code review for {$Tickets{'TOP'}->Subject}
 Depended-On-By: TOP
 Content: Someone has created a ticket. you should review and approve it,
 so they can finish their work
 ENDOFCONTENT

=head1 DESCRIPTION

The CreateTickets ScripAction allows you to create automated workflows in RT,
creating new tickets in response to actions and conditions from other
tickets.

=head2 Format

CreateTickets uses the RT template configured in the scrip as a template
for an ordered set of tickets to create. The basic format is as follows:

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

As shown, you can put one or more C<===Create-Ticket:> sections in
a template. Each C<===Create-Ticket:> section is evaluated as its own
L<Text::Template> object, which means that you can embed snippets
of Perl inside the L<Text::Template> using C<{}> delimiters, but that
such sections absolutely can not span a C<===Create-Ticket:> boundary.

Note that each C<Value> must come right after the C<Param> on the same
line. The C<Content:> param can extend over multiple lines, but the text
of the first line must start right after C<Content:>. Don't try to start
your C<Content:> section with a newline.

After each ticket is created, it's stuffed into a hash called C<%Tickets>
making it available during the creation of other tickets during the
same ScripAction. The hash key for each ticket is C<create-[identifier]>,
where C<[identifier]> is the value you put after C<===Create-Ticket:>.  The hash
is prepopulated with the ticket which triggered the ScripAction as
C<$Tickets{'TOP'}>. You can also access that ticket using the shorthand
C<TOP>.

A simple example:

 ===Create-Ticket: codereview
 Subject: Code review for {$Tickets{'TOP'}->Subject}
 Depended-On-By: TOP
 Content: Someone has created a ticket. you should review and approve it,
 so they can finish their work
 ENDOFCONTENT

A convoluted example:

 ===Create-Ticket: approval
 { # Find out who the administrators of the group called "HR" 
   # of which the creator of this ticket is a member
    my $name = "HR";

    my $groups = RT::Groups->new(RT->SystemUser);
    $groups->LimitToUserDefinedGroups();
    $groups->Limit(FIELD => "Name", OPERATOR => "=", VALUE => $name, CASESENSITIVE => 0);
    $groups->WithMember($TransactionObj->CreatorObj->Id);

    my $groupid = $groups->First->Id;

    my $adminccs = RT::Users->new(RT->SystemUser);
    $adminccs->WhoHaveRight(
        Right => "AdminGroup",
        Object =>$groups->First,
        IncludeSystemRights => undef,
        IncludeSuperusers => 0,
        IncludeSubgroupMembers => 0,
    );

     our @admins;
     while (my $admin = $adminccs->Next) {
         push (@admins, $admin->EmailAddress);
     }
 }
 Queue: ___Approvals
 Type: approval
 AdminCc: {join ("\nAdminCc: ",@admins) }
 Depended-On-By: TOP
 Refers-To: TOP
 Subject: Approval for ticket: {$Tickets{"TOP"}->Id} - {$Tickets{"TOP"}->Subject}
 Due: {time + 86400}
 Content-Type: text/plain
 Content: Your approval is requested for the ticket {$Tickets{"TOP"}->Id}: {$Tickets{"TOP"}->Subject}
 Blah
 Blah
 ENDOFCONTENT
 ===Create-Ticket: two
 Subject: Manager approval
 Type: approval
 Depended-On-By: TOP
 Refers-To: {$Tickets{"create-approval"}->Id}
 Queue: ___Approvals
 Content-Type: text/plain
 Content: Your approval is requred for this ticket, too.
 ENDOFCONTENT

As shown above, you can include a block with Perl code to set up some
values for the new tickets. If you want to access a variable in the
template section after the block, you must scope it with C<our> rather
than C<my>. Just as with other RT templates, you can also include
Perl code in the template sections using C<{}>.

=head2 Acceptable Fields

A complete list of acceptable fields:

    *  Queue           => Name or id# of a queue
       Subject         => A text string
     ! Status          => A valid status. Defaults to 'new'
       Due             => Dates can be specified in seconds since the epoch
                          to be handled literally or in a semi-free textual
                          format which RT will attempt to parse.
       Starts          =>
       Started         =>
       Resolved        =>
       Owner           => Username or id of an RT user who can and should own
                          this ticket; forces the owner if necessary
   +   Requestor       => Email address
   +   Cc              => Email address
   +   AdminCc         => Email address
   +   RequestorGroup  => Group name
   +   CcGroup         => Group name
   +   AdminCcGroup    => Group name
       TimeWorked      =>
       TimeEstimated   =>
       TimeLeft        =>
       InitialPriority =>
       FinalPriority   =>
       Type            =>
    +! DependsOn       =>
    +! DependedOnBy    =>
    +! RefersTo        =>
    +! ReferredToBy    =>
    +! Members         =>
    +! MemberOf        =>
       Content         => Content. Can extend to multiple lines. Everything
                          within a template after a Content: header is treated
                          as content until we hit a line containing only
                          ENDOFCONTENT
       ContentType     => the content-type of the Content field.  Defaults to
                          'text/plain'
       UpdateType      => 'correspond' or 'comment'; used in conjunction with
                          'content' if this is an update.  Defaults to
                          'correspond'

       CustomField-<id#> => custom field value
       CF-name           => custom field value
       CustomField-name  => custom field value

Fields marked with an C<*> are required.

Fields marked with a C<+> may have multiple values, simply
by repeating the fieldname on a new line with an additional value.

Fields marked with a C<!> have processing postponed until after all
tickets in the same actions are created.  Except for C<Status>, those
fields can also take a ticket name within the same action (i.e.
the identifiers after C<===Create-Ticket:>), instead of raw ticket ID
numbers.

When parsed, field names are converted to lowercase and have hyphens stripped.
C<Refers-To>, C<RefersTo>, C<refersto>, C<refers-to> and C<r-e-f-er-s-tO> will
all be treated as the same thing.

=head1 METHODS

=cut

#Do what we need to do and send it out.
sub Commit {
    my $self = shift;

    # Create all the tickets we care about
    return (1) unless $self->TicketObj->Type eq 'ticket';

    $self->CreateByTemplate( $self->TicketObj );
    $self->UpdateByTemplate( $self->TicketObj );
    return (1);
}



sub Prepare {
    my $self = shift;

    unless ( $self->TemplateObj ) {
        $RT::Logger->warning("No template object handed to $self");
    }

    unless ( $self->TransactionObj ) {
        $RT::Logger->warning("No transaction object handed to $self");

    }

    unless ( $self->TicketObj ) {
        $RT::Logger->warning("No ticket object handed to $self");

    }

    my $active = 0;
    if ( $self->TemplateObj->Type eq 'Perl' ) {
        $active = 1;
    } else {
        RT->Logger->info(sprintf(
            "Template #%d is type %s.  You most likely want to use a Perl template instead.",
            $self->TemplateObj->id, $self->TemplateObj->Type
        ));
    }

    $self->Parse(
        Content        => $self->TemplateObj->Content,
        _ActiveContent => $active,
    );
    return 1;

}



sub CreateByTemplate {
    my $self = shift;
    my $top  = shift;

    $RT::Logger->debug("In CreateByTemplate");

    my @results;

    # XXX: cargo cult programming that works. i'll be back.

    local %T::Tickets = %T::Tickets;
    local $T::TOP     = $T::TOP;
    local $T::ID      = $T::ID;
    $T::Tickets{'TOP'} = $T::TOP = $top if $top;
    local $T::TransactionObj = $self->TransactionObj;

    my $ticketargs;
    my ( @links, @postponed );
    foreach my $template_id ( @{ $self->{'create_tickets'} } ) {
        $RT::Logger->debug("Workflow: processing $template_id of $T::TOP")
            if $T::TOP;

        $T::ID    = $template_id;
        @T::AllID = @{ $self->{'create_tickets'} };

        ( $T::Tickets{$template_id}, $ticketargs )
            = $self->ParseLines( $template_id, \@links, \@postponed );

        # Now we have a %args to work with.
        # Make sure we have at least the minimum set of
        # reasonable data and do our thang

        my ( $id, $transid, $msg )
            = $T::Tickets{$template_id}->Create(%$ticketargs);

        foreach my $res ( split( '\n', $msg ) ) {
            push @results,
                $T::Tickets{$template_id}
                ->loc( "Ticket [_1]", $T::Tickets{$template_id}->Id ) . ': '
                . $res;
        }
        if ( !$id ) {
            if ( $self->TicketObj ) {
                $msg = "Couldn't create related ticket $template_id for "
                    . $self->TicketObj->Id . " "
                    . $msg;
            } else {
                $msg = "Couldn't create ticket $template_id " . $msg;
            }

            $RT::Logger->error($msg);
            next;
        }

        $RT::Logger->debug("Assigned $template_id with $id");
    }

    $self->PostProcess( \@links, \@postponed );

    return @results;
}

sub UpdateByTemplate {
    my $self = shift;
    my $top  = shift;

    # XXX: cargo cult programming that works. i'll be back.

    my @results;
    local %T::Tickets = %T::Tickets;
    local $T::ID      = $T::ID;

    my $ticketargs;
    my ( @links, @postponed );
    foreach my $template_id ( @{ $self->{'update_tickets'} } ) {
        $RT::Logger->debug("Update Workflow: processing $template_id");

        $T::ID    = $template_id;
        @T::AllID = @{ $self->{'update_tickets'} };

        ( $T::Tickets{$template_id}, $ticketargs )
            = $self->ParseLines( $template_id, \@links, \@postponed );

        # Now we have a %args to work with.
        # Make sure we have at least the minimum set of
        # reasonable data and do our thang

        my @attribs = qw(
            Subject
            FinalPriority
            Priority
            TimeEstimated
            TimeWorked
            TimeLeft
            Status
            Queue
            Due
            Starts
            Started
            Resolved
        );

        my $id = $template_id;
        $id =~ s/update-(\d+).*/$1/;
        my ($loaded, $msg) = $T::Tickets{$template_id}->LoadById($id);

        unless ( $loaded ) {
            $RT::Logger->error("Couldn't update ticket $template_id: " . $msg);
            push @results, $self->loc( "Couldn't load ticket '[_1]'", $id );
            next;
        }

        my $current = $self->GetBaseTemplate( $T::Tickets{$template_id} );

        $template_id =~ m/^update-(.*)/;
        my $base_id = "base-$1";
        my $base    = $self->{'templates'}->{$base_id};
        if ($base) {
            $base    =~ s/\r//g;
            $base    =~ s/\n+$//;
            $current =~ s/\n+$//;

            # If we have no base template, set what we can.
            if ( $base ne $current ) {
                push @results,
                    "Could not update ticket "
                    . $T::Tickets{$template_id}->Id
                    . ": Ticket has changed";
                next;
            }
        }
        push @results, $T::Tickets{$template_id}->Update(
            AttributesRef => \@attribs,
            ARGSRef       => $ticketargs
        );

        if ( $ticketargs->{'Owner'} ) {
            ($id, $msg) = $T::Tickets{$template_id}->SetOwner($ticketargs->{'Owner'}, "Force");
            push @results, $msg unless $msg eq $self->loc("That user already owns that ticket");
        }

        push @results,
            $self->UpdateWatchers( $T::Tickets{$template_id}, $ticketargs );

        push @results,
            $self->UpdateCustomFields( $T::Tickets{$template_id}, $ticketargs );

        next unless $ticketargs->{'MIMEObj'};
        if ( $ticketargs->{'UpdateType'} =~ /^(private|comment)$/i ) {
            my ( $Transaction, $Description, $Object )
                = $T::Tickets{$template_id}->Comment(
                BccMessageTo => $ticketargs->{'Bcc'},
                MIMEObj      => $ticketargs->{'MIMEObj'},
                TimeTaken    => $ticketargs->{'TimeWorked'}
                );
            push( @results,
                $T::Tickets{$template_id}
                    ->loc( "Ticket [_1]", $T::Tickets{$template_id}->id )
                    . ': '
                    . $Description );
        } elsif ( $ticketargs->{'UpdateType'} =~ /^(public|response|correspond)$/i ) {
            my ( $Transaction, $Description, $Object )
                = $T::Tickets{$template_id}->Correspond(
                BccMessageTo => $ticketargs->{'Bcc'},
                MIMEObj      => $ticketargs->{'MIMEObj'},
                TimeTaken    => $ticketargs->{'TimeWorked'}
                );
            push( @results,
                $T::Tickets{$template_id}
                    ->loc( "Ticket [_1]", $T::Tickets{$template_id}->id )
                    . ': '
                    . $Description );
        } else {
            push(
                @results,
                $T::Tickets{$template_id}->loc(
                    "Update type was neither correspondence nor comment.")
                    . " "
                    . $T::Tickets{$template_id}->loc("Update not recorded.")
            );
        }
    }

    $self->PostProcess( \@links, \@postponed );

    return @results;
}

=head2 Parse

Takes (in order) template content, a default queue, a default requestor, and
active (a boolean flag).

Parses a template in the template content, defaulting queue and requestor if
unspecified in the template to the values provided as arguments.

If the active flag is true, then we'll use L<Text::Template> to parse the
templates, allowing you to embed active Perl in your templates.

=cut

sub Parse {
    my $self = shift;
    my %args = (
        Content        => undef,
        Queue          => undef,
        Requestor      => undef,
        _ActiveContent => undef,
        @_
    );

    if ( $args{'_ActiveContent'} ) {
        $self->{'UsePerlTextTemplate'} = 1;
    } else {

        $self->{'UsePerlTextTemplate'} = 0;
    }

    if ( substr( $args{'Content'}, 0, 3 ) eq '===' ) {
        $self->_ParseMultilineTemplate(%args);
    } elsif ( $args{'Content'} =~ /(?:\t|,)/i ) {
        $self->_ParseXSVTemplate(%args);
    } else {
        RT->Logger->error("Invalid Template Content (Couldn't find ===, and is not a csv/tsv template) - unable to parse: $args{Content}");
    }
}

=head2 _ParseMultilineTemplate

Parses mulitline templates. Things like:

 ===Create-Ticket: ...

Takes the same arguments as L</Parse>.

=cut

sub _ParseMultilineTemplate {
    my $self = shift;
    my %args = (@_);

    my $template_id;
    my ( $queue, $requestor );
        $RT::Logger->debug("Line: ===");
        foreach my $line ( split( /\n/, $args{'Content'} ) ) {
            $line =~ s/\r$//;
            $RT::Logger->debug( "Line: $line" );
            if ( $line =~ /^===/ ) {
                if ( $template_id && !$queue && $args{'Queue'} ) {
                    $self->{'templates'}->{$template_id}
                        .= "Queue: $args{'Queue'}\n";
                }
                if ( $template_id && !$requestor && $args{'Requestor'} ) {
                    $self->{'templates'}->{$template_id}
                        .= "Requestor: $args{'Requestor'}\n";
                }
                $queue     = 0;
                $requestor = 0;
            }
            if ( $line =~ /^===Create-Ticket: (.*)$/ ) {
                $template_id = "create-$1";
                $RT::Logger->debug("****  Create ticket: $template_id");
                push @{ $self->{'create_tickets'} }, $template_id;
            } elsif ( $line =~ /^===Update-Ticket: (.*)$/ ) {
                $template_id = "update-$1";
                $RT::Logger->debug("****  Update ticket: $template_id");
                push @{ $self->{'update_tickets'} }, $template_id;
            } elsif ( $line =~ /^===Base-Ticket: (.*)$/ ) {
                $template_id = "base-$1";
                $RT::Logger->debug("****  Base ticket: $template_id");
                push @{ $self->{'base_tickets'} }, $template_id;
            } elsif ( $line =~ /^===#.*$/ ) {    # a comment
                next;
            } else {
                if ( $line =~ /^Queue:(.*)/i ) {
                    $queue = 1;
                    my $value = $1;
                    $value =~ s/^\s//;
                    $value =~ s/\s$//;
                    if ( !$value && $args{'Queue'} ) {
                        $value = $args{'Queue'};
                        $line  = "Queue: $value";
                    }
                }
                if ( $line =~ /^Requestors?:(.*)/i ) {
                    $requestor = 1;
                    my $value = $1;
                    $value =~ s/^\s//;
                    $value =~ s/\s$//;
                    if ( !$value && $args{'Requestor'} ) {
                        $value = $args{'Requestor'};
                        $line  = "Requestor: $value";
                    }
                }
                $self->{'templates'}->{$template_id} .= $line . "\n";
            }
        }
        if ( $template_id && !$queue && $args{'Queue'} ) {
            $self->{'templates'}->{$template_id} .= "Queue: $args{'Queue'}\n";
        }
    }

sub ParseLines {
    my $self        = shift;
    my $template_id = shift;
    my $links       = shift;
    my $postponed   = shift;

    my $content = $self->{'templates'}->{$template_id};

    if ( $self->{'UsePerlTextTemplate'} ) {

        $RT::Logger->debug(
            "Workflow: evaluating\n$self->{templates}{$template_id}");

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

        $RT::Logger->debug("Workflow: yielding $content");

        if ($err) {
            $RT::Logger->error( "Ticket creation failed: " . $err );
            next;
        }
    }

    my $TicketObj ||= RT::Ticket->new( $self->CurrentUser );

    my %args;
    my %original_tags;
    my @lines = ( split( /\n/, $content ) );
    while ( defined( my $line = shift @lines ) ) {
        if ( $line =~ /^(.*?):(?:\s+)(.*?)(?:\s*)$/ ) {
            my $value = $2;
            my $original_tag = $1;
            my $tag   = lc($original_tag);
            $tag =~ s/-//g;
            $tag =~ s/^(requestor|cc|admincc)s?$/$1/i;

            $original_tags{$tag} = $original_tag;

            if ( ref( $args{$tag} ) )
            {    #If it's an array, we want to push the value
                push @{ $args{$tag} }, $value;
            } elsif ( defined( $args{$tag} ) )
            {    #if we're about to get a second value, make it an array
                $args{$tag} = [ $args{$tag}, $value ];
            } else {    #if there's nothing there, just set the value
                $args{$tag} = $value;
            }

            if ( $tag =~ /^content$/i ) {    #just build up the content
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
                if (
                    ($tag =~ /^(requestor|cc|admincc)(group)?$/i
                        or grep {lc $_ eq $tag} keys %RT::Link::TYPEMAP)
                    and $args{$tag} =~ /,/
                ) {
                    $args{$tag} = [ split /,\s*/, $args{$tag} ];
                }
            }
        }
    }

    foreach my $date (qw(due starts started resolved)) {
        my $dateobj = RT::Date->new( $self->CurrentUser );
        next unless $args{$date};
        if ( $args{$date} =~ /^\d+$/ ) {
            $dateobj->Set( Format => 'unix', Value => $args{$date} );
        } else {
            eval {
                $dateobj->Set( Format => 'iso', Value => $args{$date} );
            };
            if ($@ or not $dateobj->IsSet) {
                $dateobj->Set( Format => 'unknown', Value => $args{$date} );
            }
        }
        $args{$date} = $dateobj->ISO;
    }

    foreach my $role (qw(requestor cc admincc)) {
        next unless my $value = $args{ $role . 'group' };

        my $group = RT::Group->new( $self->CurrentUser );
        $group->LoadUserDefinedGroup( $value );
        unless ( $group->id ) {
            $RT::Logger->error("Couldn't load group '$value'");
            next;
        }

        $args{ $role } = $args{ $role } ? [$args{ $role }] : []
            unless ref $args{ $role };
        push @{ $args{ $role } }, $group->PrincipalObj->id;
    }

    $args{'requestor'} ||= $self->TicketObj->Requestors->MemberEmailAddresses
        if $self->TicketObj;

    $args{'type'} ||= 'ticket';

    my %ticketargs = (
        Queue           => $args{'queue'},
        Subject         => $args{'subject'},
        Status          => $args{'status'} || 'new',
        Due             => $args{'due'},
        Starts          => $args{'starts'},
        Started         => $args{'started'},
        Resolved        => $args{'resolved'},
        Owner           => $args{'owner'},
        Requestor       => $args{'requestor'},
        Cc              => $args{'cc'},
        AdminCc         => $args{'admincc'},
        TimeWorked      => $args{'timeworked'},
        TimeEstimated   => $args{'timeestimated'},
        TimeLeft        => $args{'timeleft'},
        InitialPriority => $args{'initialpriority'} || 0,
        FinalPriority   => $args{'finalpriority'} || 0,
        SquelchMailTo   => $args{'squelchmailto'},
        Type            => $args{'type'},
    );

    if ( $args{content} ) {
        my $mimeobj = MIME::Entity->build(
            Type    => $args{'contenttype'} || 'text/plain',
            Charset => 'UTF-8',
            Data    => [ map {Encode::encode( "UTF-8", $_ )} @{$args{'content'}} ],
        );
        $ticketargs{MIMEObj} = $mimeobj;
        $ticketargs{UpdateType} = $args{'updatetype'} || 'correspond';
    }

    foreach my $tag ( keys(%args) ) {
        # if the tag was added later, skip it
        my $orig_tag = $original_tags{$tag} or next;
        if ( $orig_tag =~ /^customfield-?(\d+)$/i ) {
            $ticketargs{ "CustomField-" . $1 } = $args{$tag};
        } elsif ( $orig_tag =~ /^(?:customfield|cf)-?(.+)$/i ) {
            my $cf = RT::CustomField->new( $self->CurrentUser );
            $cf->LoadByName(
                Name          => $1,
                LookupType    => RT::Ticket->CustomFieldLookupType,
                ObjectId      => $ticketargs{Queue},
                IncludeGlobal => 1,
            );
            next unless $cf->id;
            $ticketargs{ "CustomField-" . $cf->id } = $args{$tag};
        } elsif ($orig_tag) {
            my $cf = RT::CustomField->new( $self->CurrentUser );
            $cf->LoadByName(
                Name          => $orig_tag,
                LookupType    => RT::Ticket->CustomFieldLookupType,
                ObjectId      => $ticketargs{Queue},
                IncludeGlobal => 1,
            );
            next unless $cf->id;
            $ticketargs{ "CustomField-" . $cf->id } = $args{$tag};

        }
    }

    $self->GetDeferred( \%args, $template_id, $links, $postponed );

    return $TicketObj, \%ticketargs;
}


=head2 _ParseXSVTemplate

Parses a tab or comma delimited template. Should only ever be called by
L</Parse>.

=cut

sub _ParseXSVTemplate {
    my $self = shift;
    my %args = (@_);

    use Regexp::Common qw(delimited);
    my($first, $content) = split(/\r?\n/, $args{'Content'}, 2);

    my $delimiter;
    if ( $first =~ /\t/ ) {
        $delimiter = "\t";
    } else {
        $delimiter = ',';
    }
    my @fields = split( /$delimiter/, $first );

    my $delimiter_re = qr[$delimiter];
    my $justquoted = qr[$RE{quoted}];

    # Used to generate automatic template ids
    my $autoid = 1;

  LINE:
    while ($content) {
        $content =~ s/^(\s*\r?\n)+//;

        # Keep track of Queue and Requestor, so we can provide defaults
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
        while (not $EOL and length $content and $content =~ s/^($justquoted|.*?)($delimiter_re|$)//smix) {
            $EOL = not $2;

            # Strip off quotes, if they exist
            my $value = $1;
            if ( $value =~ /^$RE{delimited}{-delim=>qq{\'\"}}$/ ) {
                substr( $value, 0,  1 ) = "";
                substr( $value, -1, 1 ) = "";
            }

            # What column is this?
            my $field = $fields[$i++];
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
                    push @{ $self->{'create_tickets'} }, $template_id;
                }
            } else {
                # Some translations
                if (   $field =~ /^Body$/i
                    || $field =~ /^Data$/i
                    || $field =~ /^Message$/i )
                  {
                  $field = 'Content';
                } elsif ( $field =~ /^Summary$/i ) {
                    $field = 'Subject';
                } elsif ( $field =~ /^Queue$/i ) {
                    # Note that we found a queue
                    $queue = 1;
                    $value ||= $args{'Queue'};
                } elsif ( $field =~ /^Requestors?$/i ) {
                    $field = 'Requestor'; # Remove plural
                    # Note that we found a requestor
                    $requestor = 1;
                    $value ||= $args{'Requestor'};
                }

                # Tack onto the end of the template
                $template .= $field . ": ";
                $template .= (defined $value ? $value : "");
                $template .= "\n";
                $template .= "ENDOFCONTENT\n"
                  if $field =~ /^Content$/i;
            }
        }

        # Ignore blank lines
        next unless $template;
        
        # If we didn't find a queue of requestor, tack on the defaults
        if ( !$queue && $args{'Queue'} ) {
            $template .= "Queue: $args{'Queue'}\n";
        }
        if ( !$requestor && $args{'Requestor'} ) {
            $template .= "Requestor: $args{'Requestor'}\n";
        }

        # If we never found an ID, come up with one
        unless ($template_id) {
            $autoid++ while exists $self->{'templates'}->{"create-auto-$autoid"};
            $template_id = "create-auto-$autoid";
            # Also, it's a ticket to create
            push @{ $self->{'create_tickets'} }, $template_id;
        }
        
        # Save the template we generated
        $self->{'templates'}->{$template_id} = $template;

    }
}

sub GetDeferred {
    my $self      = shift;
    my $args      = shift;
    my $id        = shift;
    my $links     = shift;
    my $postponed = shift;

    # Unify the aliases for child/parent
    $args->{$_} = [$args->{$_}]
        for grep {$args->{$_} and not ref $args->{$_}} qw/members hasmember memberof/;
    push @{$args->{'children'}}, @{delete $args->{'members'}}   if $args->{'members'};
    push @{$args->{'children'}}, @{delete $args->{'hasmember'}} if $args->{'hasmember'};
    push @{$args->{'parents'}},  @{delete $args->{'memberof'}}  if $args->{'memberof'};

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
        $id, { Status => $args->{'status'}, }
    );
}

sub GetUpdateTemplate {
    my $self = shift;
    my $t    = shift;

    my $string;
    $string .= "Queue: " . $t->QueueObj->Name . "\n";
    $string .= "Subject: " . $t->Subject . "\n";
    $string .= "Status: " . $t->Status . "\n";
    $string .= "UpdateType: correspond\n";
    $string .= "Content: \n";
    $string .= "ENDOFCONTENT\n";
    $string .= "Due: " . $t->DueObj->AsString . "\n";
    $string .= "Starts: " . $t->StartsObj->AsString . "\n";
    $string .= "Started: " . $t->StartedObj->AsString . "\n";
    $string .= "Resolved: " . $t->ResolvedObj->AsString . "\n";
    $string .= "Owner: " . $t->OwnerObj->Name . "\n";
    $string .= "Requestor: " . $t->RequestorAddresses . "\n";
    $string .= "Cc: " . $t->CcAddresses . "\n";
    $string .= "AdminCc: " . $t->AdminCcAddresses . "\n";
    $string .= "TimeWorked: " . $t->TimeWorked . "\n";
    $string .= "TimeEstimated: " . $t->TimeEstimated . "\n";
    $string .= "TimeLeft: " . $t->TimeLeft . "\n";
    $string .= "InitialPriority: " . $t->Priority . "\n";
    $string .= "FinalPriority: " . $t->FinalPriority . "\n";

    foreach my $type ( RT::Link->DisplayTypes ) {
        $string .= "$type: ";

        my $mode   = $RT::Link::TYPEMAP{$type}->{Mode};
        my $method = $RT::Link::TYPEMAP{$type}->{Type};

        my $links = '';
        while ( my $link = $t->$method->Next ) {
            $links .= ", " if $links;

            my $object = $mode . "Obj";
            my $member = $link->$object;
            $links .= $member->Id if $member;
        }
        $string .= $links;
        $string .= "\n";
    }

    return $string;
}

sub GetBaseTemplate {
    my $self = shift;
    my $t    = shift;

    my $string;
    $string .= "Queue: " . $t->Queue . "\n";
    $string .= "Subject: " . $t->Subject . "\n";
    $string .= "Status: " . $t->Status . "\n";
    $string .= "Due: " . $t->DueObj->Unix . "\n";
    $string .= "Starts: " . $t->StartsObj->Unix . "\n";
    $string .= "Started: " . $t->StartedObj->Unix . "\n";
    $string .= "Resolved: " . $t->ResolvedObj->Unix . "\n";
    $string .= "Owner: " . $t->Owner . "\n";
    $string .= "Requestor: " . $t->RequestorAddresses . "\n";
    $string .= "Cc: " . $t->CcAddresses . "\n";
    $string .= "AdminCc: " . $t->AdminCcAddresses . "\n";
    $string .= "TimeWorked: " . $t->TimeWorked . "\n";
    $string .= "TimeEstimated: " . $t->TimeEstimated . "\n";
    $string .= "TimeLeft: " . $t->TimeLeft . "\n";
    $string .= "InitialPriority: " . $t->Priority . "\n";
    $string .= "FinalPriority: " . $t->FinalPriority . "\n";

    return $string;
}

sub GetCreateTemplate {
    my $self = shift;

    my $string;

    $string .= "Queue: General\n";
    $string .= "Subject: \n";
    $string .= "Status: new\n";
    $string .= "Content: \n";
    $string .= "ENDOFCONTENT\n";
    $string .= "Due: \n";
    $string .= "Starts: \n";
    $string .= "Started: \n";
    $string .= "Resolved: \n";
    $string .= "Owner: \n";
    $string .= "Requestor: \n";
    $string .= "Cc: \n";
    $string .= "AdminCc:\n";
    $string .= "TimeWorked: \n";
    $string .= "TimeEstimated: \n";
    $string .= "TimeLeft: \n";
    $string .= "InitialPriority: \n";
    $string .= "FinalPriority: \n";

    foreach my $type ( RT::Link->DisplayTypes ) {
        $string .= "$type: \n";
    }
    return $string;
}

sub UpdateWatchers {
    my $self   = shift;
    my $ticket = shift;
    my $args   = shift;

    my @results;

    foreach my $type (qw(Requestor Cc AdminCc)) {
        my $method  = $type . 'Addresses';
        my $oldaddr = $ticket->$method;

        # Skip unless we have a defined field
        next unless defined $args->{$type};
        my $newaddr = $args->{$type};

        my @old = split( /,\s*/, $oldaddr );
        my @new;
        for (ref $newaddr ? @{$newaddr} : split( /,\s*/, $newaddr )) {
            # Sometimes these are email addresses, sometimes they're
            # users.  Try to guess which is which, as we want to deal
            # with email addresses if at all possible.
            if (/^\S+@\S+$/) {
                push @new, $_;
            } else {
                # It doesn't look like an email address.  Try to load it.
                my $user = RT::User->new($self->CurrentUser);
                $user->Load($_);
                if ($user->Id) {
                    push @new, $user->EmailAddress;
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
            my ( $val, $msg ) = $ticket->AddWatcher(
                Type  => $type,
                Email => $_
            );

            push @results,
                $ticket->loc( "Ticket [_1]", $ticket->Id ) . ': ' . $msg;
        }

        foreach (@delete) {
            my ( $val, $msg ) = $ticket->DeleteWatcher(
                Type  => $type,
                Email => $_
            );
            push @results,
                $ticket->loc( "Ticket [_1]", $ticket->Id ) . ': ' . $msg;
        }
    }
    return @results;
}

sub UpdateCustomFields {
    my $self   = shift;
    my $ticket = shift;
    my $args   = shift;

    my @results;
    foreach my $arg (keys %{$args}) {
        next unless $arg =~ /^CustomField-(\d+)$/;
        my $cf = $1;

        my $CustomFieldObj = RT::CustomField->new($self->CurrentUser);
        $CustomFieldObj->SetContextObject( $ticket );
        $CustomFieldObj->LoadById($cf);

        my @values;
        if ($CustomFieldObj->Type =~ /text/i) { # Both Text and Wikitext
            @values = ($args->{$arg});
        } else {
            @values = split /\n/, $args->{$arg};
        }
        
        if ( ($CustomFieldObj->Type eq 'Freeform' 
              && ! $CustomFieldObj->SingleValue) ||
              $CustomFieldObj->Type =~ /text/i) {
            foreach my $val (@values) {
                $val =~ s/\r//g;
            }
        }

        foreach my $value (@values) {
            next if $ticket->CustomFieldValueIsEmpty(
                Field => $CustomFieldObj,
                Value => $value,
            );
            my ( $val, $msg ) = $ticket->AddCustomFieldValue(
                Field => $cf,
                Value => $value
            );
            push ( @results, $msg );
        }
    }
    return @results;
}

sub PostProcess {
    my $self      = shift;
    my $links     = shift;
    my $postponed = shift;

    # postprocessing: add links

    while ( my $template_id = shift(@$links) ) {
        my $ticket = $T::Tickets{$template_id};
        $RT::Logger->debug( "Handling links for " . $ticket->Id );
        my %args = %{ shift(@$links) };

        foreach my $type ( keys %RT::Link::TYPEMAP ) {
            next unless ( defined $args{$type} );
            foreach my $link (
                ref( $args{$type} ) ? @{ $args{$type} } : ( $args{$type} ) )
            {
                next unless $link;

                if ( $link =~ /^TOP$/i ) {
                    $RT::Logger->debug( "Building $type link for $link: "
                            . $T::Tickets{TOP}->Id );
                    $link = $T::Tickets{TOP}->Id;

                } elsif ( $link !~ m/^\d+$/ ) {
                    my $key = "create-$link";
                    if ( !exists $T::Tickets{$key} ) {
                        $RT::Logger->debug(
                            "Skipping $type link for $key (non-existent)");
                        next;
                    }
                    $RT::Logger->debug( "Building $type link for $link: "
                            . $T::Tickets{$key}->Id );
                    $link = $T::Tickets{$key}->Id;
                } else {
                    $RT::Logger->debug("Building $type link for $link");
                }

                my ( $wval, $wmsg ) = $ticket->AddLink(
                    Type => $RT::Link::TYPEMAP{$type}->{'Type'},
                    $RT::Link::TYPEMAP{$type}->{'Mode'} => $link,
                    Silent                        => 1
                );

                $RT::Logger->warning("AddLink thru $link failed: $wmsg")
                    unless $wval;

                # push @non_fatal_errors, $wmsg unless ($wval);
            }

        }
    }

    # postponed actions -- Status only, currently
    while ( my $template_id = shift(@$postponed) ) {
        my $ticket = $T::Tickets{$template_id};
        $RT::Logger->debug( "Handling postponed actions for " . $ticket->id );
        my %args = %{ shift(@$postponed) };
        $ticket->SetStatus( $args{Status} ) if defined $args{Status};
    }

}

RT::Base->_ImportOverlays();

1;

