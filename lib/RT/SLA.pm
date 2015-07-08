# BEGIN BPS TAGGED BLOCK {{{
#
# COPYRIGHT:
#
# This software is Copyright (c) 1996-2015 Best Practical Solutions, LLC
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
use strict;
use warnings;

package RT::SLA;

=head1 NAME

RT::SLA - Service Level Agreements for RT

=head1 DESCRIPTION

Automated due dates using service levels.

=head1 CONFIGURATION

Service level agreements of tickets is controlled by an SLA custom field (CF).
This field is created during C<make initdb> step (above) and applied globally.
This CF MUST be of C<select one value> type. Values of the CF define the
service levels.

It's possible to define different set of levels for different
queues. You can create several CFs with the same name and
different set of values. But if you move tickets between
queues a lot then it's going to be a problem and it's preferred
to use B<ONE> SLA custom field.

There is no WebUI in the current version. Almost everything is
controlled in the RT's config using option C<%RT::ServiceAgreements>
and C<%RT::ServiceBusinessHours>. For example:

    %RT::ServiceAgreements = (
        Default => '4h',
        QueueDefault => {
            'Incident' => '2h',
        },
        Levels => {
            '2h' => { Resolve => { RealMinutes => 60*2 } },
            '4h' => { Resolve => { RealMinutes => 60*4 } },
        },
    );

In this example I<Incident> is the name of the queue, and I<2h> is the name of
the SLA which will be applied to this queue by default.

Each service level can be described using several options:
L<Starts|/"Starts (interval, first business minute)">,
L<Resolve|/"Resolve and Response (interval, no defaults)">,
L<Response|/"Resolve and Response (interval, no defaults)">,
L<KeepInLoop|/"Keep in loop (interval, no defaults)">,
L<OutOfHours|/"OutOfHours (struct, no default)">
and L<ServiceBusinessHours|/"Configuring business hours">.

=head2 Starts (interval, first business minute)

By default when a ticket is created Starts date is set to
first business minute after time of creation. In other
words if a ticket is created during business hours then
Starts will be equal to Created time, otherwise Starts will
be beginning of the next business day.

However, if you provide 24/7 support then you most
probably would be interested in Starts to be always equal
to Created time.

Starts option can be used to adjust behaviour. Format
of the option is the same as format for deadlines which
described later in details. RealMinutes, BusinessMinutes
options and OutOfHours modifiers can be used here like
for any other deadline. For example:

    'standard' => {
        # give people 15 minutes
        Starts   => { BusinessMinutes => 15  },
    },

You can still use old option StartImmediately to set
Starts date equal to Created date.

Example:

    '24/7' => {
        StartImmediately => 1,
        Response => { RealMinutes => 30 },
    },

But it's the same as:

    '24/7' => {
        Starts => { RealMinutes => 0 },
        Response => { RealMinutes => 30 },
    },

=head2 Resolve and Response (interval, no defaults)

These two options define deadlines for resolve of a ticket
and reply to customer(requestors) questions accordingly.

You can define them using real time, business or both. Read more
about the latter L<below|/"Using both Resolve and Response in the same level">.

The Due date field is used to store calculated deadlines.

=head3 Resolve

Defines deadline when a ticket should be resolved. This option is
quite simple and straightforward when used without L</Response>.

Example:

    # 8 business hours
    'simple' => { Resolve => 60*8 },
    ...
    # one real week
    'hard' => { Resolve => { RealMinutes => 60*24*7 } },

=head3 Response

In many companies providing support service(s) resolve time of a ticket
is less important than time of response to requestors from staff
members.

You can use Response option to define such deadlines.  The Due date is
set when a ticket is created, unset when a worker replies, and re-set
when the requestor replies again -- until the ticket is closed, when the
ticket's Due date is unset.

B<NOTE> that this behaviour changes when Resolve and Response options
are combined; see L</"Using both Resolve and Response in the same
level">.

Note that by default, only the requestors on the ticket are considered
"outside actors" and thus require a Response due date; all other email
addresses are treated as workers of the ticket, and thus count as
meeting the SLA.  If you'd like to invert this logic, so that the Owner
and AdminCcs are the only worker email addresses, and all others are
external, see the L</AssumeOutsideActor> configuration.

The owner is never treated as an outside actor; if they are also the
requestor of the ticket, it will have no SLA.

If an outside actor replies multiple times, their later replies are
ignored; the deadline is awlways calculated from the oldest
correspondence from the outside actor.


=head3 Using both Resolve and Response in the same level

Resolve and Response can be combined. In such case due date is set
according to the earliest of two deadlines and never is dropped to
'not set'.

If a ticket met its Resolve deadline then due date stops "flipping",
is freezed and the ticket becomes overdue. Before that moment when
an inside actor replies to a ticket, due date is changed to Resolve
deadline instead of 'Not Set', as well this happens when a ticket
is closed. So all the time due date is defined.

Example:

    'standard delivery' => {
        Response => { RealMinutes => 60*1  }, # one hour
        Resolve  => { RealMinutes => 60*24 }, # 24 real hours
    },

A client orders goods and due date of the order is set to the next one
hour, you have this hour to process the order and write a reply.
As soon as goods are delivered you resolve tickets and usually meet
Resolve deadline, but if you don't resolve or user replies then most
probably there are problems with delivery of the goods. And if after
a week you keep replying to the client and always meeting one hour
response deadline that doesn't mean the ticket is not over due.
Due date was frozen 24 hours after creation of the order.

=head3 Using business and real time in one option

It's quite rare situation when people need it, but we've decided
that business is applied first and then real time when deadline
described using both types of time. For example:

    'delivery' => {
        Resolve => { BusinessMinutes => 0, RealMinutes => 60*8 },
    },
    'fast delivery' {
        StartImmediately => 1,
        Resolve => { RealMinutes => 60*8 },
    },

For delivery requests which come into the system during business
hours these levels define the same deadlines, otherwise the first
level set deadline to 8 real hours starting from the next business
day, when tickets with the second level should be resolved in the
next 8 hours after creation.

=head2 Keep in loop (interval, no defaults)

If response deadline is used then Due date is changed to repsonse
deadline or to "Not Set" when staff replies to a ticket. In some
cases you want to keep requestors in loop and keed them up to date
every few hours. KeepInLoop option can be used to achieve this.

    'incident' => {
        Response   => { RealMinutes => 60*1  }, # one hour
        KeepInLoop => { RealMinutes => 60*2 }, # two hours
        Resolve    => { RealMinutes => 60*24 }, # 24 real hours
    },

In the above example Due is set to one hour after creation, reply
of a inside actor moves Due date two hours forward, outside actors'
replies move Due date to one hour and resolve deadine is 24 hours.

=head2 Modifying Agreements

=head3 OutOfHours (struct, no default)

Out of hours modifier. Adds more real or business minutes to resolve
and/or reply options if event happens out of business hours, read also
</"Configuring business hours"> below.

Example:

    'level x' => {
        OutOfHours => { Resolve => { RealMinutes => +60*24 } },
        Resolve    => { RealMinutes => 60*24 },
    },

If a request comes into the system during night then supporters have two
hours, otherwise only one.

    'level x' => {
        OutOfHours => { Response => { BusinessMinutes => +60*2 } },
        Resolve    => { BusinessMinutes => 60 },
    },

Supporters have two additional hours in the morning to deal with bunch
of requests that came into the system during the last night.

=head3 IgnoreOnStatuses (array, no default)

Allows you to ignore a deadline when ticket has certain status. Example:

    'level x' => {
        KeepInLoop => { BusinessMinutes => 60, IgnoreOnStatuses => ['stalled'] },
    },

In above example KeepInLoop deadline is ignored if ticket is stalled.

B<NOTE>: When a ticket goes from an ignored status to a normal status, the new
Due date is calculated from the last action (reply, SLA change, etc) which fits
the SLA type (Response, Starts, KeepInLoop, etc).  This means if a ticket in
the above example flips from stalled to open without a reply, the ticket will
probably be overdue.  In most cases this shouldn't be a problem since moving
out of stalled-like statuses is often the result of RT's auto-open on reply
scrip, therefore ensuring there's a new reply to calculate Due from.  The
overall effect is that ignored statuses don't let the Due date drift
arbitrarily, which could wreak havoc on your SLA performance.
C<ExcludeTimeOnIgnoredStatuses> option could get around the "probably be
overdue" issue by excluding the time spent on ignored statuses.

        'level x' => {
            KeepInLoop => {
                BusinessMinutes => 60,
                ExcludeTimeOnIgnoredStatuses => 1,
                IgnoreOnStatuses => ['stalled'],
            },
        },

=head2 Configuring business hours

In the config you can set one or more work schedules. Use the following
format:

    %RT::ServiceBusinessHours = (
        'Default' => {
            ... description ...
        },
        'Support' => {
            ... description ...
        },
        'Sales' => {
            ... description ...
        },
    );

Read more about how to describe a schedule in L<Business::Hours>.

=head3 Defining different business hours for service levels

Each level supports BusinessHours option to specify your own business
hours.

    'level x' => {
        BusinessHours => 'work just in Monday',
        Resolve    => { BusinessMinutes => 60 },
    },

then %RT::ServiceBusinessHours should have the corresponding definition:

    %RT::ServiceBusinessHours = (
        'work just in Monday' => {
            1 => { Name => 'Monday', Start => '9:00', End => '18:00' },
        },
    );

Default Business Hours setting is in $RT::ServiceBusinessHours{'Default'}.

=head2 Defining service levels per queue

In the config you can set per queue defaults, using:

    %RT::ServiceAgreements = (
        Default => 'global default level of service',
        QueueDefault => {
            'queue name' => 'default value for this queue',
            ...
        },
        ...
    };

=head2 AssumeOutsideActor

When using a L<Response|/"Resolve and Response (interval, no defaults)">
configuration, the due date is unset when anyone who is not a requestor
replies.  If it is common for non-requestors to reply to tickets, and
this should I<not> satisfy the SLA, you may wish to set
C<AssumeOutsideActor>.  This causes the extension to assume that the
Response SLA has only been met when the owner or AdminCc reply.

    %RT::ServiceAgreements = (
        AssumeOutsideActor => 1,
        ...
    };

=head2 Access control

You can totally hide SLA custom field from users and use per queue
defaults, just revoke SeeCustomField and ModifyCustomField.

If you want people to see the current service level ticket is assigned
to then grant SeeCustomField right.

You may want to allow customers or managers to escalate thier tickets.
Just grant them ModifyCustomField right.

=cut

sub BusinessHours {
    my $self = shift;
    my $name = shift || 'Default';

    require Business::Hours;
    my $res = new Business::Hours;
    $res->business_hours( %{ $RT::ServiceBusinessHours{ $name } } )
        if $RT::ServiceBusinessHours{ $name };
    return $res;
}

sub Agreement {
    my $self = shift;
    my %args = (
        Level => undef,
        Type => 'Response',
        Time => undef,
        Ticket => undef,
        Queue  => undef,
        @_
    );

    my $meta = $RT::ServiceAgreements{'Levels'}{ $args{'Level'} };
    return undef unless $meta;

    if ( exists $meta->{'StartImmediately'} || !defined $meta->{'Starts'} ) {
        $meta->{'Starts'} = {
            delete $meta->{'StartImmediately'}
                ? ( )
                : ( BusinessMinutes => 0 )
            ,
        };
    }

    return undef unless $meta->{ $args{'Type'} };

    my %res;
    if ( ref $meta->{ $args{'Type'} } ) {
        %res = %{ $meta->{ $args{'Type'} } };
    } elsif ( $meta->{ $args{'Type'} } =~ /^\d+$/ ) {
        %res = ( BusinessMinutes => $meta->{ $args{'Type'} } );
    } else {
        $RT::Logger->error("Levels of SLA should be either number or hash ref");
        return undef;
    }

    if ( $args{'Ticket'} && $res{'IgnoreOnStatuses'} ) {
        my $status = $args{'Ticket'}->Status;
        return undef if grep $_ eq $status, @{$res{'IgnoreOnStatuses'}};
    }

    $res{'OutOfHours'} = $meta->{'OutOfHours'}{ $args{'Type'} };

    $args{'Queue'} ||= $args{'Ticket'}->QueueObj if $args{'Ticket'};
    if ( $args{'Queue'} && ref $RT::ServiceAgreements{'QueueDefault'}{ $args{'Queue'}->Name } ) {
        $res{'Timezone'} = $RT::ServiceAgreements{'QueueDefault'}{ $args{'Queue'}->Name }{'Timezone'};
    }
    $res{'Timezone'} ||= $meta->{'Timezone'} || $RT::Timezone;

    $res{'BusinessHours'} = $meta->{'BusinessHours'};

    return \%res;
}

sub Due {
    my $self = shift;
    return $self->CalculateTime( @_ );
}

sub Starts {
    my $self = shift;
    return $self->CalculateTime( @_, Type => 'Starts' );
}

sub CalculateTime {
    my $self = shift;
    my %args = (@_);
    my $agreement = $args{'Agreement'} || $self->Agreement( @_ );
    return undef unless $agreement and ref $agreement eq 'HASH';

    my $res = $args{'Time'};

    my $ok = eval {
        local $ENV{'TZ'} = $ENV{'TZ'};
        if ( $agreement->{'Timezone'} && $agreement->{'Timezone'} ne ($ENV{'TZ'}||'') ) {
            $ENV{'TZ'} = $agreement->{'Timezone'};
            require POSIX; POSIX::tzset();
        }

        my $bhours = $self->BusinessHours( $agreement->{'BusinessHours'} );

        if ( $agreement->{'OutOfHours'} && $bhours->first_after( $res ) != $res ) {
            foreach ( qw(RealMinutes BusinessMinutes) ) {
                next unless my $mod = $agreement->{'OutOfHours'}{ $_ };
                ($agreement->{ $_ } ||= 0) += $mod;
            }
        }

        if (   $args{ Ticket }
            && $agreement->{ IgnoreOnStatuses }
            && $agreement->{ ExcludeTimeOnIgnoredStatuses } )
        {
            my $txns = RT::Transactions->new( RT->SystemUser );
            $txns->LimitToTicket($args{Ticket}->id);
            $txns->Limit(
                FIELD => 'Field',
                VALUE => 'Status',
            );
            my $date = RT::Date->new( RT->SystemUser );
            $date->Set( Value => $args{ Time } );
            $txns->Limit(
                FIELD    => 'Created',
                OPERATOR => '>=',
                VALUE    => $date->ISO( Timezone => 'UTC' ),
            );

            my $last_time = $args{ Time };
            while ( my $txn = $txns->Next ) {
                if ( grep( { $txn->OldValue eq $_ } @{ $agreement->{ IgnoreOnStatuses } } ) ) {
                    if ( !grep( { $txn->NewValue eq $_ } @{ $agreement->{ IgnoreOnStatuses } } ) ) {
                        if ( defined $agreement->{ 'BusinessMinutes' } ) {

                            # re-init $bhours to make sure we don't have a cached start/end,
                            # so the time here is not outside the calculated business hours

                            my $bhours = $self->BusinessHours( $agreement->{ 'BusinessHours' } );
                            my $time = $bhours->between( $last_time, $txn->CreatedObj->Unix );
                            if ( $time > 0 ) {
                                $res = $bhours->add_seconds( $res, $time );
                            }
                        }
                        else {
                            my $time = $txn->CreatedObj->Unix - $last_time;
                            $res += $time;
                        }
                        $last_time = $txn->CreatedObj->Unix;
                    }
                }
                else {
                    $last_time = $txn->CreatedObj->Unix;
                }
            }
        }

        if ( defined $agreement->{'BusinessMinutes'} ) {
            if ( $agreement->{'BusinessMinutes'} ) {
                $res = $bhours->add_seconds(
                    $res, 60 * $agreement->{'BusinessMinutes'},
                );
            }
            else {
                $res = $bhours->first_after( $res );
            }
        }
        $res += 60 * $agreement->{'RealMinutes'}
            if defined $agreement->{'RealMinutes'};
        1;
    };

    POSIX::tzset() if $agreement->{'Timezone'}
        && $agreement->{'Timezone'} ne ($ENV{'TZ'}||'');
    die $@ unless $ok;

    return $res;
}

sub GetCustomField {
    my $self = shift;
    my %args = (Ticket => undef, CustomField => 'SLA', @_);
    unless ( $args{'Ticket'} ) {
        $args{'Ticket'} = $self->TicketObj if $self->can('TicketObj');
    }
    unless ( $args{'Ticket'} ) {
        return RT::CustomField->new( $RT::SystemUser );
    }
    my $cfs = $args{'Ticket'}->QueueObj->TicketCustomFields;
    $cfs->Limit( FIELD => 'Name', VALUE => $args{'CustomField'}, CASESENSITIVE => 0 );
    return $cfs->First || RT::CustomField->new( $RT::SystemUser );
}

sub GetDefaultServiceLevel {
    my $self = shift;
    my %args = (Ticket => undef, Queue => undef, @_);
    unless ( $args{'Queue'} || $args{'Ticket'} ) {
        $args{'Ticket'} = $self->TicketObj if $self->can('TicketObj');
    }
    if ( !$args{'Queue'} && $args{'Ticket'} ) {
        $args{'Queue'} = $args{'Ticket'}->QueueObj;
    }
    if ( $args{'Queue'} ) {
        return $args{'Queue'}->SLA if $args{'Queue'}->SLA;
        if ( $RT::ServiceAgreements{'QueueDefault'} &&
            ( my $info = $RT::ServiceAgreements{'QueueDefault'}{ $args{'Queue'}->Name } )) {
            return $info unless ref $info;
            return $info->{'Level'} || $RT::ServiceAgreements{'Default'};
        }
    }
    return $RT::ServiceAgreements{'Default'};
}

RT::Base->_ImportOverlays();

1;
