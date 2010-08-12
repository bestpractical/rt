use strict;
use warnings;

package RT::StatusSchemas;

our $VERSION = '0.02';

=head1 NAME

RT::Estension::StatusSchemas - define different set of statuses for queues in RT

=head1 SYNOPSIS

    # schema close to RT's default, but with some nice
    # additions
    Set( %StatusSchemaMeta,
        default => {
            initial  => ['new'],
            active   => ['open', 'stalled'],
            inactive => ['resolved', 'rejected', 'deleted'],

            transitions => {
                # from   => [ to list ],
                new      => [qw(open resolved rejected deleted)],
                open     => [qw(stalled resolved rejected deleted)],
                stalled  => [qw(open)],
                resolved => [qw(open)],
                rejected => [qw(open)],
                deleted  => [qw(open)],
            },
            rights  => {
                '* -> deleted'  => 'DeleteTicket',
                '* -> rejected' => 'RejectTicket',
                '* -> *'        => 'ModifyTicketStatus',
            },
            actions => {
                # 'from -> to'    => [action text, Respond/Comment/hide/''],
                'new -> open'     => ['Open It', 'Respond'],
                'new -> resolved' => ['Resolve', 'Comment'],
                'new -> rejected' => ['Reject',  'Respond'],
                'new -> deleted'  => ['Delete',  ''],

                'open -> stalled'  => ['Stall',   'Comment'],
                'open -> resolved' => ['Resolve', 'Comment'],
                'open -> rejected' => ['Reject',  'Respond'],
                'open -> deleted'  => ['Delete',  'hide'],

                'stalled -> open'  => ['Open It',  ''],
                'resolved -> open' => ['Re-open',  'Comment'],
                'rejected -> open' => ['Re-open',  'Comment'],
                'deleted -> open'  => ['Undelete', ''],
            },
        },
    );

=head1 DESCRIPTION

By default RT has one set of statuses for all queues with this extension you can
define multiple schemas with different statuses and other interesting things.

=head1 CONFIGURATION

=head2 Basics

This extension is configured in the RT config file using several options:

=over 4

=item %StatusSchemas - use to define status schemas for queues, if there is no
record for some queue then 'default' is used. For example:

    Set( %StatusSchemas,
        General => 'some_schema',
        'Another Queue' => 'another schema',
    );

=item %StatusSchemaMeta - use to describe status schemas. Below you can read more
about format of this option, but here is basic format:

    Set( %StatusSchemaMeta,
        default => {
            ... description of default schema ...
        },
        'another schema' => {
            ... description of another schema ...
        },
    );

=back

=head2 Statuses

Each schema is a list of statues splitted into three logic sets:
initial, active and inactive (read below). All statuses in a schema
must be unique. Each set may have any number of statuses.

For example:

    default => {
        initial  => ['new'],
        active   => ['open', 'stalled'],
        inactive => ['resolved', 'rejected', 'deleted'],
        ...
    },

Note that size of status field in the DB is limitted to 10 ASCII
characters. You can increase size in the DB, but shorter statuses
are usually better for UI and DB performance. Also ASCII may looks
contradictionary with multi-language interface, but you can translate
statuses and other things using po files.

=head3 Status sets

Unlike RT 3.8 this extension adds 'intial' set in addition to 'active'
and 'inactive' sets.

=over 4

=item intial

This set is new for RT and covers one thing that has not been
covered in RT 3.8 and earlier. First time you change a status
from 'new' to another in 3.8 and earlier Started date is set
to now. Status 'new' is hardcoded in RT 3.8 for this purpose.

With this extension you can define multiple intial statuses and
Started date is only set when you change from one of initial
statuses to status from active or inactive set.

This allow you to get better statistics over dates. For example
you may have initial statuses 'new' and 'negotiation' and active
status 'processing'. Created date is set whenever ticket was created
and started date is set once status changed to 'processing'.

As well, you may have this set empty when you're sure all tickets
with this status schema are active when created.

Started date is set to now on create if ticket is created with
not initial status and started date is not defined.

=item active

Active set is something well know as active statuses from RT 3.8
except that it's splitted into two sets: initial and active.

=item inactive

Inactive statuses haven't been changed much from implementation
in RT 3.8.

Resolved date is set to now when status is changed from any
intial or active status to inactive. As well, on create if status
of new ticket is inactive and resolved date is not defined.

'deleted' is still a special status and protected by 'DeleteTicket'
right, you have to add it to set manually or avoid if you don't
want tickets to be deleted.

=back

Statuses in each set are ordered and listed in the UI in the defined
order. It worth to mention that order of statuses may influence
behavior a little when it's ambiguose which status to choose.

Changes between statuses are constrolled by possible transitions
described below.

=head2 Allowing transitions, protecting with rights, labeling them and defining actions

Transition - is a change of status from A to B. You should define
all possible transitions in each schema using the following format:

    default => {
        ...
        transitions => {
            new      => [qw(open resolved rejected deleted)],
            open     => [qw(stalled resolved rejected deleted)],
            stalled  => [qw(open)],
            resolved => [qw(open)],
            rejected => [qw(open)],
            deleted  => [qw(open)],
        },
        ...
    },

=head3 Protecting with rights

A transation or group of transitions can be protected by a right,
for example:

    default => {
        ...
        rights => {
            '* -> deleted'  => 'DeleteTicket',
            '* -> rejected' => 'RejectTicket',
            '* -> *'        => 'ModifyTicketStatus',
        },
        ...
    },

On the left hand side you can have the following variants:

    '<from> -> <to>'
    '* -> <to>'
    '<from> -> *'
    '* -> *'

Variants are listed in order by priority, so if user want
to change status from X to Y then schema checked for presence
of exact match, then for presence of 'any to Y', 'X to any' and
finally 'any to any'.

If you don't define any rights or there is no match for some
transition then DeleteTicket and ModifyTicket rights are
checked, like RT does by default.

=head3 Labeling and defining actions

Each transition can be named, by default it's named as B what often
is not that good. At this point this label is required for the UI
only where all transitions are listed on ticket's page as possible
actions on the ticket. Each such action may be acompanied with
comment, correspond or hidden by default. For example you may want
your users to write a reply when they change status from new to open.
Or it's possible to hide open -> delete transition by default from
ticket's main view, but still make it legal for 'edit basics' page
or API.

Additional comment or correspond is not mandatory and may be skipped
by users. By default no action there is no need in action and one-click
link is showed.

Use the following format to define labels and actions of transitions:

    default => {
        ...
        actions => {
            'new -> open'     => ['Open It', 'Respond'],
            'new -> resolved' => ['Resolve', 'Comment'],
            'new -> rejected' => ['Reject',  'Respond'],
            'new -> deleted'  => ['Delete',  ''],

            'open -> stalled'  => ['Stall',   'Comment'],
            'open -> resolved' => ['Resolve', 'Comment'],
            'open -> rejected' => ['Reject',  'Respond'],
            'open -> deleted'  => ['Delete',  'hide'],

            'stalled -> open'  => ['Open It',  ''],
            'resolved -> open' => ['Re-open',  'Comment'],
            'rejected -> open' => ['Re-open',  'Comment'],
            'deleted -> open'  => ['Undelete', ''],
        },
        ...
    },

=head2 Moving tickets between queues with different schemas

Unless there is some mapping between statuses in schema A and B,
you can not move tickets between queues with these schemas.

    __maps__ => {
        'from schema -> to schema' => {
            'status in left schema' => 'status in right schema',
            ...
        },
        ...
    },

=head2 Changes in the UI and Scrips

=head3 Quicksearch portlet

This portlet has been rewriten and shows initial and active
statuses in all schemas. If status is not valid for a queue then
users will see '-' instead of number.

For setups with many different schemas or schemas that has no
equal statuses at all it may be better to group queues by status
schemas. You can achieve this by using QuicksearchBySchema
portlet. Change HomepageComponents config option first.

=head3 AutoOpen scrip action

Auto open scrip action has been rewritten completly. You can
read description of its behavior in F<lib/RT/Action/AutoOpen_Vendor.pm>
using perldoc program.

=head3 StatusChange scrip condition

StatusChange scrip condition has been extended with new format of
the Argument to better serve systems with multiple status schemas.
Read description in F<lib/RT/Condition/StatusChange_Vendor.pm>.

=cut


require RT::StatusSchema;
RT::StatusSchema->register_rights;

1;
