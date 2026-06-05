
use strict;
use warnings;


my $config;
BEGIN {
$config = <<END;
Set(\%Lifecycles,
    default => {
        initial  => [qw(new)],
        active   => [qw(open stalled)],
        inactive => [qw(resolved rejected deleted)],
        defaults => {
            on_create => 'new',
        },
        transitions => {
            ''       => [qw(new open resolved)],
            new      => [qw(open resolved rejected deleted)],
            open     => [qw(stalled resolved rejected deleted)],
            stalled  => [qw(open)],
            resolved => [qw(open)],
            rejected => [qw(open)],
            deleted  => [qw(open)],
        },
        actions => {
            'new -> open'     => {label => 'Open It', update => 'Respond'},
            'new -> resolved' => {label => 'Resolve', update => 'Comment'},
            'new -> rejected' => {label => 'Reject',  update => 'Respond'},
            'new -> deleted'  => {label => 'Delete',  update => ''},

            'open -> stalled'  => {label => 'Stall',   update => 'Comment'},
            'open -> resolved' => {label => 'Resolve', update => 'Comment'},
            'open -> rejected' => {label => 'Reject',  update => 'Respond'},

            'stalled -> open'  => {label => 'Open It',  update => ''},
            'resolved -> open' => {label => 'Re-open',  update => 'Comment'},
            'rejected -> open' => {label => 'Re-open',  update => 'Comment'},
            'deleted -> open'  => {label => 'Undelete', update => ''},
        },
        status_metadata => {
            open => {
                description => 'Work is actively underway.',
                notes       => 'Set to open when you begin working on the ticket.',
            },
            stalled => {
                description => 'Blocked, waiting on something external.',
            },
        },
        transition_metadata => {
            'open -> resolved' => {
                description => 'The work is complete.',
                notes       => 'Resolve when finished; add a reply first.',
            },
            'open -> *' => {
                description => 'Leaving the open status.',
                notes       => 'A from-open note.',
            },
            '* -> rejected' => {
                description => 'Closed without action.',
            },
            '* -> *' => {
                notes => 'A generic transition note.',
            },
        },
    },
    delivery => {
        initial  => ['ordered'],
        active   => ['on way', 'delayed'],
        inactive => ['delivered'],
        defaults => {
            on_create => 'ordered',
        },
        transitions => {
            ''        => ['ordered'],
            ordered   => ['on way', 'delayed'],
            'on way'  => ['delivered'],
            delayed   => ['on way'],
            delivered => [],
        },
        actions => {
            'ordered -> on way'   => {label => 'Put On Way', update => 'Respond'},
            'ordered -> delayed'  => {label => 'Delay',      update => 'Respond'},

            'on way -> delivered' => {label => 'Done',       update => 'Respond'},
            'delayed -> on way'   => {label => 'Put On Way', update => 'Respond'},
        },
    },
    triage => {
        initial  => ['untriaged'],
        active   => ['ordinary', 'escalated'],
        inactive => ['resolved'],
        defaults => {
            on_create => 'untriaged',
        },
        transitions => {
            ''        => ['untriaged'],
            untriaged => ['ordinary', 'escalated'],
            ordinary  => ['resolved'],
            escalated => ['resolved'],
            resolved => [],
        },
        rights => {
            '* -> escalated' => 'EscalateTicket',
        },
    },
    racing => {
        type => 'racecar',
        active => ['on-your-mark', 'get-set', 'go'],
        inactive => ['first', 'second', 'third', 'no-place'],
    },
    "sales"      => {
        type     => 'ticket',
        initial  => ['initial'],
        active   => ['active', 'case-Variant'],
        inactive => ['inactive'],
    },
    "sales-engineering" => {
        "initial" => ["sales"],
        "active"  => [
            "engineering",
            "stalled"
        ],
        "inactive" => [
            "resolved",
            "rejected",
            "deleted"
        ],
    },
);
END
}

use RT::Test config => $config, tests => undef;

1;
