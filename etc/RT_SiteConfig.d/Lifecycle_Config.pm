Set(%Lifecycles,
#    incident_reports => {},
#    incidents => {},
#    investigations => {},
#    countermeasures => {},
    madrid => {},
);

Set(%Lifecycles,
    escalation => {
        initial         => [qw(new)], # loc_qw
        active          => [qw(open stalled escalation1)], # loc_qw
        inactive        => [qw(resolved rejected deleted)], # loc_qw

        defaults => {
            on_create => 'new',
            approved  => 'open',
            denied    => 'rejected',
            reminder_on_open     => 'open',
            reminder_on_resolve  => 'resolved',
        },

        transitions => {
            ""       => [qw(new open resolved)],
            # from   => [ to list ],
            new      => [qw(    open rejected deleted)],
            open     => [qw(new   escalation1   stalled resolved rejected deleted)],
            stalled  => [qw(new open         resolved rejected deleted)],
            resolved => [qw(new open stalled escalation1   rejected deleted)],
            rejected => [qw(new open stalled resolved       deleted)],
            deleted  => [qw(new open stalled resolved rejected        )],
            escalation1  => [qw(open stalled resolved      )],
        },
        rights => {
            '* -> deleted'  => 'DeleteTicket',
            '* -> *'        => 'ModifyTicket',
            '* -> escalation1' => 'EscalateTicket',
        },
        actions => [
            'new -> open'      => { label  => 'Open It' }, # loc{label}
            'new -> resolved'  => { label  => 'Resolve', update => 'Comment' }, # loc{label}
            'new -> rejected'  => { label  => 'Reject',  update => 'Respond' }, # loc{label}
            'new -> deleted'   => { label  => 'Delete',                      }, # loc{label}
            'open -> stalled'  => { label  => 'Stall',   update => 'Comment' }, # loc{label}
            'open -> resolved' => { label  => 'Resolve', update => 'Comment' }, # loc{label}
            'open -> rejected' => { label  => 'Reject',  update => 'Respond' }, # loc{label}
            'stalled -> open'  => { label  => 'Open It',                     }, # loc{label}
            'resolved -> open' => { label  => 'Re-open', update => 'Comment' }, # loc{label}
            'rejected -> open' => { label  => 'Re-open', update => 'Comment' }, # loc{label}
            'deleted -> open'  => { label  => 'Undelete',                    }, # loc{label}
            'open -> escalation1' => { label => 'Escalate', update => 'Comment' }, # loc{label}
            'escalation1 -> open' => { label => 'Re-open' }, # loc{label}
        ],
		dates => {
			'open -> escalation1' => 'Escalated',
			'escalation1 -> *' => 'DeEscalated',
		},
    },
    '__maps__' => {
      'escalation -> default' => {
        new   => 'new',
        open => 'open',
        stalled => 'stalled',
        resolved => 'resolved',
        deleted => 'deleted',
        rejected => 'rejected',
        escalation1 => 'open',
      },
      'default -> escalation' => {
          new   => 'new',
          open => 'open',
          stalled => 'stalled',
          resolved => 'resolved',
          rejected => 'rejected',
          deleted => 'deleted',
      },
    },
);

1;
