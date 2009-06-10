# BEGIN BPS TAGGED BLOCK {{{
# 
# COPYRIGHT:
#  
# This software is Copyright (c) 1996-2009 Best Practical Solutions, LLC 
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
require RT::Action::Generic;

use strict;
use warnings;
use vars qw/@ISA/;
@ISA = qw(RT::Action::Generic);

use MIME::Entity;

=head1 NAME

 RT::Action::CreateTickets

Create one or more tickets according to an externally supplied template.


=head1 SYNOPSIS

 ===Create-Ticket codereview
 Subject: Code review for {$Tickets{'TOP'}->Subject}
 Depended-On-By: TOP
 Content: Someone has created a ticket. you should review and approve it,
 so they can finish their work
 ENDOFCONTENT

=head1 DESCRIPTION


Using the "CreateTickets" ScripAction and mandatory dependencies, RT now has 
the ability to model complex workflow. When a ticket is created in a queue
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

After each ticket is created, it's stuffed into a hash called %Tickets
so as to be available during the creation of other tickets during the same 
ScripAction.  The hash is prepopulated with the ticket which triggered the 
ScripAction as $Tickets{'TOP'}; you can also access that ticket using the
shorthand TOP.

A simple example:

 ===Create-Ticket: codereview
 Subject: Code review for {$Tickets{'TOP'}->Subject}
 Depended-On-By: TOP
 Content: Someone has created a ticket. you should review and approve it,
 so they can finish their work
 ENDOFCONTENT



A convoluted example

 ===Create-Ticket: approval
 { # Find out who the administrators of the group called "HR" 
   # of which the creator of this ticket is a member
    my $name = "HR";
   
    my $groups = RT::Groups->new($RT::SystemUser);
    $groups->LimitToUserDefinedGroups();
    $groups->Limit(FIELD => "Name", OPERATOR => "=", VALUE => "$name");
    $groups->WithMember($TransactionObj->CreatorObj->Id);
 
    my $groupid = $groups->First->Id;
 
    my $adminccs = RT::Users->new($RT::SystemUser);
    $adminccs->WhoHaveRight(
	Right => "AdminGroup",
	Object =>$groups->First,
	IncludeSystemRights => undef,
	IncludeSuperusers => 0,
	IncludeSubgroupMembers => 0,
    );
 
     my @admins;
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
 Depended-On-By: TOP
 Refers-On: {$Tickets{"approval"}->Id}
 Queue: ___Approvals
 Content-Type: text/plain
 Content: 
 Your approval is requred for this ticket, too.
 ENDOFCONTENT
 
=head2 Acceptable fields

A complete list of acceptable fields for this beastie:


    *  Queue           => Name or id# of a queue
       Subject         => A text string
     ! Status          => A valid status. defaults to 'new'
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
       Content         => content. Can extend to multiple lines. Everything
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

Fields marked with an * are required.

Fields marked with a + may have multiple values, simply
by repeating the fieldname on a new line with an additional value.

Fields marked with a ! are postponed to be processed after all
tickets in the same actions are created.  Except for 'Status', those
field can also take a ticket name within the same action (i.e.
the identifiers after ==Create-Ticket), instead of raw Ticket ID
numbers.

When parsed, field names are converted to lowercase and have -s stripped.
Refers-To, RefersTo, refersto, refers-to and r-e-f-er-s-tO will all 
be treated as the same thing.


=begin testing

ok (require RT::Action::CreateTickets);
use_ok(RT::Scrip);
use_ok(RT::Template);
use_ok(RT::ScripAction);
use_ok(RT::ScripCondition);
use_ok(RT::Ticket);

my $approvalsq = RT::Queue->new($RT::SystemUser);
$approvalsq->Create(Name => 'Approvals');
ok ($approvalsq->Id, "Created Approvals test queue");


my $approvals = 
'===Create-Ticket: approval
Queue: ___Approvals
Type: approval
AdminCc: {join ("\nAdminCc: ",@admins) }
Depended-On-By: {$Tickets{"TOP"}->Id}
Refers-To: TOP 
Subject: Approval for ticket: {$Tickets{"TOP"}->Id} - {$Tickets{"TOP"}->Subject}
Due: {time + 86400}
Content-Type: text/plain
Content: Your approval is requested for the ticket {$Tickets{"TOP"}->Id}: {$Tickets{"TOP"}->Subject}
Blah
Blah
ENDOFCONTENT
===Create-Ticket: two
Subject: Manager approval.
Depended-On-By: approval
Queue: ___Approvals
Content-Type: text/plain
Content: 
Your minion approved ticket {$Tickets{"TOP"}->Id}. you ok with that?
ENDOFCONTENT
';

ok ($approvals =~ /Content/, "Read in the approvals template");

my $apptemp = RT::Template->new($RT::SystemUser);
$apptemp->Create( Content => $approvals, Name => "Approvals", Queue => "0");

ok ($apptemp->Id);

my $q = RT::Queue->new($RT::SystemUser);
$q->Create(Name => 'WorkflowTest');
ok ($q->Id, "Created workflow test queue");

my $scrip = RT::Scrip->new($RT::SystemUser);
my ($sval, $smsg) =$scrip->Create( ScripCondition => 'On Transaction',
                ScripAction => 'Create Tickets',
                Template => 'Approvals',
                Queue => $q->Id);
ok ($sval, $smsg);
ok ($scrip->Id, "Created the scrip");
ok ($scrip->TemplateObj->Id, "Created the scrip template");
ok ($scrip->ConditionObj->Id, "Created the scrip condition");
ok ($scrip->ActionObj->Id, "Created the scrip action");

my $t = RT::Ticket->new($RT::SystemUser);
my($tid, $ttrans, $tmsg) = $t->Create(Subject => "Sample workflow test",
           Owner => "root",
           Queue => $q->Id);

ok ($tid,$tmsg);

my $deps = $t->DependsOn;
is ($deps->Count, 1, "The ticket we created depends on one other ticket");
my $dependson= $deps->First->TargetObj;
ok ($dependson->Id, "It depends on a real ticket");
unlike ($dependson->Subject, qr/{/, "The subject doesn't have braces in it. that means we're interpreting expressions");
is ($t->ReferredToBy->Count,1, "It's only referred to by one other ticket");
is ($t->ReferredToBy->First->BaseObj->Id,$t->DependsOn->First->TargetObj->Id, "The same ticket that depends on it refers to it.");
use RT::Action::CreateTickets;
my $action =  RT::Action::CreateTickets->new( CurrentUser => $RT::SystemUser);;

# comma-delimited templates
my $commas = <<"EOF";
id,Queue,Subject,Owner,Content
ticket1,General,"foo, bar",root,blah
ticket2,General,foo bar,root,blah
ticket3,General,foo' bar,root,blah'boo
ticket4,General,foo' bar,,blah'boo
EOF


# Comma delimited templates with missing data
my $sparse_commas = <<"EOF";
id,Queue,Subject,Owner,Requestor
ticket14,General,,,bobby
ticket15,General,,,tommy
ticket16,General,,suzie,tommy
ticket17,General,Foo "bar" baz,suzie,tommy
ticket18,General,'Foo "bar" baz',suzie,tommy
ticket19,General,'Foo bar' baz,suzie,tommy
EOF


# tab-delimited templates
my $tabs = <<"EOF";
id\tQueue\tSubject\tOwner\tContent
ticket10\tGeneral\t"foo' bar"\troot\tblah'
ticket11\tGeneral\tfoo, bar\troot\tblah
ticket12\tGeneral\tfoo' bar\troot\tblah'boo
ticket13\tGeneral\tfoo' bar\t\tblah'boo
EOF

my %expected;

$expected{ticket1} = <<EOF;
Queue: General
Subject: foo, bar
Owner: root
Content: blah
ENDOFCONTENT
EOF

$expected{ticket2} = <<EOF;
Queue: General
Subject: foo bar
Owner: root
Content: blah
ENDOFCONTENT
EOF

$expected{ticket3} = <<EOF;
Queue: General
Subject: foo' bar
Owner: root
Content: blah'boo
ENDOFCONTENT
EOF

$expected{ticket4} = <<EOF;
Queue: General
Subject: foo' bar
Owner: 
Content: blah'boo
ENDOFCONTENT
EOF

$expected{ticket10} = <<EOF;
Queue: General
Subject: foo' bar
Owner: root
Content: blah'
ENDOFCONTENT
EOF

$expected{ticket11} = <<EOF;
Queue: General
Subject: foo, bar
Owner: root
Content: blah
ENDOFCONTENT
EOF

$expected{ticket12} = <<EOF;
Queue: General
Subject: foo' bar
Owner: root
Content: blah'boo
ENDOFCONTENT
EOF

$expected{ticket13} = <<EOF;
Queue: General
Subject: foo' bar
Owner: 
Content: blah'boo
ENDOFCONTENT
EOF


$expected{'ticket14'} = <<EOF;
Queue: General
Subject: 
Owner: 
Requestor: bobby
EOF
$expected{'ticket15'} = <<EOF;
Queue: General
Subject: 
Owner: 
Requestor: tommy
EOF
$expected{'ticket16'} = <<EOF;
Queue: General
Subject: 
Owner: suzie
Requestor: tommy
EOF
$expected{'ticket17'} = <<EOF;
Queue: General
Subject: Foo "bar" baz
Owner: suzie
Requestor: tommy
EOF
$expected{'ticket18'} = <<EOF;
Queue: General
Subject: Foo "bar" baz
Owner: suzie
Requestor: tommy
EOF
$expected{'ticket19'} = <<EOF;
Queue: General
Subject: 'Foo bar' baz
Owner: suzie
Requestor: tommy
EOF




$action->Parse(Content =>$commas);
$action->Parse(Content =>$sparse_commas);
$action->Parse(Content => $tabs);

my %got;
foreach (@{ $action->{'create_tickets'} }) {
  $got{$_} = $action->{'templates'}->{$_};
}

foreach my $id ( sort keys %expected ) {
    ok(exists($got{"create-$id"}), "template exists for $id");
    is($got{"create-$id"}, $expected{$id}, "template is correct for $id");
}

=end testing


=head1 AUTHOR

Jesse Vincent <jesse@bestpractical.com> 

=head1 SEE ALSO

perl(1).

=cut

my %LINKTYPEMAP = (
    MemberOf => {
        Type => 'MemberOf',
        Mode => 'Target',
    },
    Parents => {
        Type => 'MemberOf',
        Mode => 'Target',
    },
    Members => {
        Type => 'MemberOf',
        Mode => 'Base',
    },
    Children => {
        Type => 'MemberOf',
        Mode => 'Base',
    },
    HasMember => {
        Type => 'MemberOf',
        Mode => 'Base',
    },
    RefersTo => {
        Type => 'RefersTo',
        Mode => 'Target',
    },
    ReferredToBy => {
        Type => 'RefersTo',
        Mode => 'Base',
    },
    DependsOn => {
        Type => 'DependsOn',
        Mode => 'Target',
    },
    DependedOnBy => {
        Type => 'DependsOn',
        Mode => 'Base',
    },

);

# {{{ Scrip methods (Commit, Prepare)

# {{{ sub Commit
#Do what we need to do and send it out.
sub Commit {
    my $self = shift;

    # Create all the tickets we care about
    return (1) unless $self->TicketObj->Type eq 'ticket';

    $self->CreateByTemplate( $self->TicketObj );
    $self->UpdateByTemplate( $self->TicketObj );
    return (1);
}

# }}}

# {{{ sub Prepare

sub Prepare {
    my $self = shift;

    unless ( $self->TemplateObj ) {
        $RT::Logger->warning("No template object handed to $self\n");
    }

    unless ( $self->TransactionObj ) {
        $RT::Logger->warning("No transaction object handed to $self\n");

    }

    unless ( $self->TicketObj ) {
        $RT::Logger->warning("No ticket object handed to $self\n");

    }

    $self->Parse(
        Content        => $self->TemplateObj->Content,
        _ActiveContent => 1
    );
    return 1;

}

# }}}

# }}}

sub CreateByTemplate {
    my $self = shift;
    my $top  = shift;

    $RT::Logger->debug("In CreateByTemplate");

    my @results;

    # XXX: cargo cult programming that works. i'll be back.
    use bytes;

    local %T::Tickets = %T::Tickets;
    local $T::TOP     = $T::TOP;
    local $T::ID      = $T::ID;
    $T::Tickets{'TOP'} = $T::TOP = $top if $top;

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
        $T::Tickets{$template_id}->SetOriginObj( $self->TicketObj )
            if $self->TicketObj
            && $T::Tickets{$template_id}->can('SetOriginObj');

    }

    $self->PostProcess( \@links, \@postponed );

    return @results;
}

sub UpdateByTemplate {
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

=head2 Parse  TEMPLATE_CONTENT, DEFAULT_QUEUE, DEFAULT_REQEUESTOR ACTIVE

Parse a template from TEMPLATE_CONTENT

If $active is set to true, then we'll use Text::Template to parse the templates,
allowing you to embed active perl in your templates.

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

    }
}

=head2 _ParseMultilineTemplate

Parses mulitline templates. Things like:

 ===Create-Ticket ... 

Takes the same arguments as Parse

=cut

sub _ParseMultilineTemplate {
    my $self = shift;
    my %args = (@_);

    my $template_id;
    my ( $queue, $requestor );
        $RT::Logger->debug("Line: ===");
        foreach my $line ( split( /\n/, $args{'Content'} ) ) {
            $line =~ s/\r$//;
            $RT::Logger->debug("Line: $line");
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

        $RT::Logger->debug("Workflow: yielding\n$content");

        if ($err) {
            $RT::Logger->error( "Ticket creation failed: " . $err );
            while ( my ( $k, $v ) = each %T::X ) {
                $RT::Logger->debug(
                    "Eliminating $template_id from ${k}'s parents.");
                delete $v->{$template_id};
            }
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
                if (($tag =~ /^(requestor|cc|admincc)$/i or grep {lc $_ eq $tag} keys %LINKTYPEMAP) and $args{$tag} =~ /,/) {
                    $args{$tag} = [ split /,\s*/, $args{$tag} ];
                }
            }
        }
    }

    foreach my $date qw(due starts started resolved) {
        my $dateobj = RT::Date->new( $self->CurrentUser );
        next unless $args{$date};
        if ( $args{$date} =~ /^\d+$/ ) {
            $dateobj->Set( Format => 'unix', Value => $args{$date} );
        } else {
            eval {
                $dateobj->Set( Format => 'iso', Value => $args{$date} );
            };
            if ($@ or $dateobj->Unix <= 0) {
                $dateobj->Set( Format => 'unknown', Value => $args{$date} );
            }
        }
        $args{$date} = $dateobj->ISO;
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
        Type            => $args{'type'},
    );

    if ( $args{content} ) {
        my $mimeobj = MIME::Entity->new();
        $mimeobj->build(
            Type => $args{'contenttype'} || 'text/plain',
            Data => $args{'content'}
        );
        $ticketargs{MIMEObj} = $mimeobj;
        $ticketargs{UpdateType} = $args{'updatetype'} || 'correspond';
    }

    foreach my $tag ( keys(%args) ) {
        # if the tag was added later, skip it
        my $orig_tag = $original_tags{$tag} or next;
        if ( $orig_tag =~ /^customfield-?(\d+)$/i ) {
            $ticketargs{ "CustomField-" . $1 } = $args{$tag};
        } elsif ( $orig_tag =~ /^(?:customfield|cf)-?(.*)$/i ) {
            my $cf = RT::CustomField->new( $self->CurrentUser );
            $cf->LoadByName( Name => $1, Queue => $ticketargs{Queue} );
            $ticketargs{ "CustomField-" . $cf->id } = $args{$tag};
        } elsif ($orig_tag) {
            my $cf = RT::CustomField->new( $self->CurrentUser );
            $cf->LoadByName( Name => $orig_tag, Queue => $ticketargs{Queue} );
            next unless ($cf->id) ;
            $ticketargs{ "CustomField-" . $cf->id } = $args{$tag};

        }
    }

    $self->GetDeferred( \%args, $template_id, $links, $postponed );

    return $TicketObj, \%ticketargs;
}


=head2 _ParseXSVTemplate 

Parses a tab or comma delimited template. Should only ever be called by Parse

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

    foreach my $type ( sort keys %LINKTYPEMAP ) {

        # don't display duplicates
        if (   $type eq "HasMember"
            || $type eq "Members"
            || $type eq "MemberOf" )
        {
            next;
        }
        $string .= "$type: ";

        my $mode   = $LINKTYPEMAP{$type}->{Mode};
        my $method = $LINKTYPEMAP{$type}->{Type};

        my $links;
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

    foreach my $type ( keys %LINKTYPEMAP ) {

        # don't display duplicates
        if (   $type eq "HasMember"
            || $type eq 'Members'
            || $type eq 'MemberOf' )
        {
            next;
        }
        $string .= "$type: \n";
    }
    return $string;
}

sub UpdateWatchers {
    my $self   = shift;
    my $ticket = shift;
    my $args   = shift;

    my @results;

    foreach my $type qw(Requestor Cc AdminCc) {
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
            next unless length($value);
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

        foreach my $type ( keys %LINKTYPEMAP ) {
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
                    Type => $LINKTYPEMAP{$type}->{'Type'},
                    $LINKTYPEMAP{$type}->{'Mode'} => $link,
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

eval "require RT::Action::CreateTickets_Vendor";
die $@ if ( $@ && $@ !~ qr{^Can't locate RT/Action/CreateTickets_Vendor.pm} );
eval "require RT::Action::CreateTickets_Local";
die $@ if ( $@ && $@ !~ qr{^Can't locate RT/Action/CreateTickets_Local.pm} );

1;

