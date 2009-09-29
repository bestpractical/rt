use strict;
use warnings;

use RT::Test config => 'Set( $LinkSelfLoops, 1 );', tests => undef;

my ($baseurl, $m) = RT::Test->started_ok;

# Set up queues
my $systems = RT::Test->load_or_create_queue(
    Name              => 'Systems',
    CorrespondAddress => 'systems@example.com',
    CommentAddress    => 'systems-comment@example.com',
);
ok $systems && $systems->id, 'loaded or created systems queue';

my $helpdesk = RT::Test->load_or_create_queue(
    Name              => 'Helpdesk',
    CorrespondAddress => 'helpdesk@example.com',
    CommentAddress    => 'helpdesk-comment@example.com',
);
ok $helpdesk && $helpdesk->id, 'loaded or created helpdesk queue';

# ...and rights
RT::Test->set_rights(
    {   Principal => 'Everyone',
        Right     => [
            'CreateTicket',
            'ShowTicket',
            'SeeQueue',
            'ReplyToTicket',
            'CommentOnTicket',
            'ModifyTicket'
        ],
    },
    {   Principal => 'Privileged',
        Right     => ['TakeTicket', 'OwnTicket', 'ShowTicketComments'],
    }
);

# ...and users
my $bjoern = RT::Test->load_or_create_user(
    EmailAddress => 'bjoern@example.com',
);

my $sven = RT::Test->load_or_create_user(
    EmailAddress => 'sven@example.com',
);
my ($ok, $msg);
($ok, $msg) = $helpdesk->AddWatcher( Type => 'AdminCc', Email => 'bjoern@example.com' );
ok($ok, "Added bjoern as admincc on helpdesk - $msg");
($ok, $msg) = $systems->AddWatcher( Type => 'AdminCc', Email => 'sven@example.com' );
ok($ok, "Added sven as admincc on systems - $msg");

sub reinsert {
    my $text = shift;
    my $mime = parse_mail($text);
    return (0, 0) unless ($mime->head->get("To")||"") =~ /(helpdesk|systems)(?:-(comment))?\@example\.com/
        or ($mime->head->get("Cc")||"") =~ /(helpdesk|systems)(?:-(comment))?\@example\.com/
        or ($mime->head->get("Bcc")||"") =~ /(helpdesk|systems)(?:-(comment))?\@example\.com/;

    my ($queue, $action) = (ucfirst($1), $2 || "correspond");
    return RT::Test->send_via_mailgate( $text, queue => $queue, action => $action );
}

sub got_mail_ok {
    local $Test::Builder::Level = $Test::Builder::Level + 1;
    my @messages = @_;
    my @mails = RT::Test->fetch_caught_mails;
    is( scalar(@mails), scalar(@messages) );
    for my $msg (@messages) {
        my $text = shift @mails;
        my $mail = parse_mail($text);
        my $fail;
        for (grep {$_ ne "id"} keys %{$msg}) {
            like($mail->head->get($_), $msg->{$_}, "$_ contains @{[$msg->{$_}]}") or $fail++;
        }
        warn $text if $fail;
        my ($status, $id) = reinsert($text);
        if ($msg->{id}) {
            is ($status >> 8, 0, "The mail gateway exited normally");
            is ($id, $msg->{id}, "Created ticket");
        }
    }
    warn $_ for @mails;
}

sub record_ok {
    local $Test::Builder::Level = $Test::Builder::Level + 1;
    my %args = (
        mode => 'comment',
        on => undef,
        as => undef,
        cc => undef,
        @_,
    );

    $args{as} ||= $args{on}->CurrentUser;

    my $ticket = RT::Ticket->new( $args{as} );
    $ticket->Load( ref $args{on} ? $args{on}->Id  : $args{on} );
    my $method = ucfirst lc $args{mode};

    my $caller = join(":", caller);
    my $mime = MIME::Entity->build(
        Data => $caller,
        "Message-Id" => "$caller\@example.com",
        Subject => $caller,
    );
    my ($id, $status) = $ticket->$method(
        MIMEObj => $mime,
        CcMessageTo => $args{cc},
    );
    ok($id, "Added $method on @{[$ticket->Id]} as @{[$args{as}->EmailAddress]})");
}

# =====> SITUATION 1:  Helpdesk queue adds systems@ as a one-time cc on a
# comment (helpdesk gets all correspondence from systems, as a comment;  
# systems only gets mail explicitly one-time-CC'd to them)

{
    # Joe sends mail to helpdesk@
    my $text = <<EOF;
From: joe\@example.com
To: helpdesk\@example.com
Subject: This is a test of new ticket creation
Message-Id: first\@example.com

A helpdesk ticket
EOF

    my ($status, $id) = RT::Test->send_via_mailgate($text, queue => 'Helpdesk');
    is ($status >> 8, 0, "The mail gateway exited normally");
    ok ($id, "Created ticket");
    my ($helpticket, $systicket) = ($id, $id + 1);

    # Sends mail back to Joe, and to Bjoern
    got_mail_ok( { to => qr/joe\@/ }, { bcc => qr/bjoern\@/} );

    # Ticket #101 is created in the helpdesk queue with joe as the requestor
    my $ticket = RT::Test->last_ticket( $bjoern );
    isa_ok ($ticket, 'RT::Ticket');
    is ($ticket->Id, $id, "correct ticket id");
    is ($ticket->Subject , 'This is a test of new ticket creation', "Created the ticket");

    # Bjoern adds a comment with systems@ as a one-time CC.
    record_ok( mode => 'comment', on => $ticket, as => $bjoern, cc => 'systems@example.com');

    # RT sends mail to systems@
    got_mail_ok(
        {   from => qr/helpdesk-comment\@/,
            cc   => qr/systems\@/,
            id   => $systicket,
        },
    );

    # Ticket #102 is created in the system queue with helpdesk-comment@ as the requestor
    $ticket = RT::Test->last_ticket( $sven );
    is($ticket->RequestorAddresses, 'helpdesk-comment@example.com');

    # Auto-reply goes back to #101, and to sven
    got_mail_ok(
        {   from => qr/systems\@/,
            to   => qr/helpdesk-comment\@/,
            id   => $systicket,
        },
        {   from => qr/systems\@/,
            bcc  => qr/sven\@/,
        },
    );

    # Auto-reply gets dropped
    got_mail_ok();
    is(RT::Test->last_ticket->id, $ticket->id);

    # Ticket #102 is now linked to ticket #101

    # Sven adds a comment on #102
    record_ok( mode => 'comment', on => $systicket, as => $sven );

    # No mail is sent out (Sven would get it, but NotifyActor is not set)
    got_mail_ok();

    # Sven adds a correspondence on #102
    record_ok( mode => 'correspond', on => $systicket, as => $sven );

    # helpdesk-comment is notified
    got_mail_ok(
        {   from => qr/systems\@/,
            to   => qr/helpdesk-comment\@/,
            id   => $systicket,
        },
    );

    # Which notifies Bjoern
    got_mail_ok(
        {   from => qr/helpdesk-comment\@/,
            bcc  => qr/bjoern\@/,
        },
    );

    # Bjoern adds a comment on #101
    record_ok( mode => 'comment', on => $helpticket, as => $bjoern );

    #   AdminCCs on #101 are notified
    got_mail_ok();

    # Bjoern adds a correspondence on #101
    record_ok( mode => 'correspond', on => $helpticket, as => $bjoern );

    #   Joe and AdminCCs on #101 are notified
    got_mail_ok(
        {   from => qr/helpdesk\@/,
            to   => qr/joe\@/,
        },
    );

    # Bjoern adds a comment on #101, choosing to one-time-CC systems@
    record_ok( mode => 'comment', on => $helpticket, as => $bjoern, cc => 'systems@example.com' );

    #   AdminCCs on #101 are notified, as is systems@,
    got_mail_ok(
        {   from => qr/helpdesk-comment\@/,
            cc   => qr/systems\@/,
            id   => $helpticket,
        },
    );

    #   which notifies Sven and AdminCCs on #102
    got_mail_ok(
        {   from => qr/systems\@/,
            bcc  => qr/sven\@/,
        },
    );

    # Bjoern adds a correspondence on #101, choosing to one-time-CC systems@
    record_ok( mode => 'correspond', on => $helpticket, as => $bjoern, cc => 'systems@example.com' );

    #   Joe and AdminCCs on #101 are notified, as is systems@,
    got_mail_ok(
        {   from => qr/helpdesk\@/,
            cc   => qr/systems\@/,
            id   => $helpticket,
        },
        {   from => qr/helpdesk\@/,
            to   => qr/joe\@/,
        },
    );

    #   which notifies Sven and AdminCCs on #102
    got_mail_ok(
        {   from => qr/systems\@/,
            bcc  => qr/sven\@/,
        },
        {   from => qr/systems\@/,
            to   => qr/helpdesk-comment\@/,
            id   => $systicket,
        },
    );

    # Mail to helpdesk-comment gets droppped
    got_mail_ok();
}

# ======> SITUATION 2:  Helpdesk queue adds systems@ as a one-time cc on
# a correspondence
# (The result is identical to the above, with the exception of the
# original email)
{
    # Joe sends mail to helpdesk@
    my $text = <<EOF;
From: joe\@example.com
To: helpdesk\@example.com
Subject: This is a test of new ticket creation
Message-Id: second\@example.com

A helpdesk ticket
EOF

    my ($status, $id) = RT::Test->send_via_mailgate($text, queue => 'Helpdesk');
    is ($status >> 8, 0, "The mail gateway exited normally");
    ok ($id, "Created ticket");
    my ($helpticket, $systicket) = ($id, $id + 1);

    # Sends mail back to Joe, and to Bjoern
    got_mail_ok( { to => qr/joe\@/ }, { bcc => qr/bjoern\@/} );

    # Ticket #201 is created in the helpdesk queue with joe as the requestor
    my $ticket = RT::Test->last_ticket( $bjoern );
    isa_ok ($ticket, 'RT::Ticket');
    is ($ticket->Id, $id, "correct ticket id");
    is ($ticket->Subject , 'This is a test of new ticket creation', "Created the ticket");

    # Bjoern adds a correspondence with systems@ as a one-time CC.
    record_ok( mode => 'correspond', on => $ticket, as => $bjoern, cc => 'systems@example.com');

    # RT sends mail to joe and systems@
    got_mail_ok(
        {   from => qr/helpdesk\@/,
            cc   => qr/systems\@/,
            id   => $systicket,
        },
        {   from => qr/helpdesk\@/,
            to   => qr/joe\@/,
        },
    );

    # Ticket #202 is created in the system queue with helpdesk@ as the requestor
    $ticket = RT::Test->last_ticket( $sven );
    is($ticket->RequestorAddresses, 'helpdesk@example.com');

    # Auto-reply goes back to #201, and to sven
    got_mail_ok(
        {   from => qr/systems\@/,
            to   => qr/helpdesk\@/,
            id   => $systicket,
        },
        {   from => qr/systems\@/,
            bcc  => qr/sven\@/,
        },
    );

    # Auto-reply gets dropped
    got_mail_ok();
    is(RT::Test->last_ticket->id, $ticket->id);

    # Ticket #202 is linked to ticket #201

    # Sven adds a comment on #202
    record_ok( mode => 'comment', on => $systicket, as => $sven );

    # No mail is sent out (Sven would get it, but NotifyActor is not set)
    got_mail_ok();

    # Sven adds a correspondence on #202
    record_ok( mode => 'correspond', on => $systicket, as => $sven );

    # AdminCCs on #202 are notified, as is helpdesk@,
    got_mail_ok(
        {   from => qr/systems\@/,
            to   => qr/helpdesk\@/,
            id   => $systicket,
        },
    );

    # Which notifies Joe, Bjoern, and AdminCCs on #201
    got_mail_ok(
        {   from => qr/helpdesk\@/,
            bcc  => qr/bjoern\@/,
        },
        {   from => qr/helpdesk\@/,
            to   => qr/joe\@/,
        },
    );

    # Bjoern adds a comment on #201
    record_ok( mode => 'comment', on => $helpticket, as => $bjoern );

    #   AdminCCs on #201 are notified
    got_mail_ok();

    # Bjoern adds a correspondence on #201
    record_ok( mode => 'correspond', on => $helpticket, as => $bjoern );

    #   Joe and AdminCCs on #201 are notified
    got_mail_ok(
        {   from => qr/helpdesk\@/,
            to   => qr/joe\@/,
        },
    );

    # Bjoern adds a comment on #201, choosing to one-time-CC systems@
    record_ok( mode => 'comment', on => $helpticket, as => $bjoern, cc => 'systems@example.com' );

    #   AdminCCs on #201 are notified, as is systems@,
    got_mail_ok(
        {   from => qr/helpdesk-comment\@/,
            cc   => qr/systems\@/,
            id   => $helpticket,
        },
    );
    #   which notifies Sven and AdminCCs on #202 (and the "requestor"
    # helpdesk@, since it came from helpdesk-comment@, not helpdesk@,
    # so NotifyActor isn't relevant!)
    got_mail_ok(
        {   from => qr/systems\@/,
            bcc  => qr/sven\@/,
        },
        {   from => qr/systems\@/,
            to   => qr/helpdesk\@/,
            id   => $systicket,
        },
    );

    # Mail to helpdesk gets droppped
    got_mail_ok();

    # Bjoern adds a correspondence on #201, choosing to one-time-CC systems@
    record_ok( mode => 'correspond', on => $helpticket, as => $bjoern, cc => 'systems@example.com' );
    #   Joe and AdminCCs on #201 are notified, as is systems@,
    got_mail_ok(
        {   from => qr/helpdesk\@/,
            cc   => qr/systems\@/,
            id   => $helpticket,
        },
        {   from => qr/helpdesk\@/,
            to   => qr/joe\@/,
        },
    );
    #   which notifies Sven and AdminCCs on #202
    got_mail_ok(
        {   from => qr/systems\@/,
            bcc  => qr/sven\@/,
        },
    );

}

# ======> SITUATION 3:  Helpdesk queue adds systems@ as permanent cc
# (linked system ticket gets all helpdesk correspondence, but not
# comments; helpdesk gets correspondence from systems)

{
    # Joe sends mail to helpdesk@
    my $text = <<EOF;
From: joe\@example.com
To: helpdesk\@example.com
Subject: This is a test of new ticket creation
Message-Id: third\@example.com

A helpdesk ticket
EOF

    my ($status, $id) = RT::Test->send_via_mailgate($text, queue => 'Helpdesk');
    is ($status >> 8, 0, "The mail gateway exited normally");
    ok ($id, "Created ticket");
    my ($helpticket, $systicket) = ($id, $id + 1);

    # Sends mail back to Joe, and to Bjoern
    got_mail_ok( { to => qr/joe\@/ }, { bcc => qr/bjoern\@/} );

    # Ticket #301 is created in the helpdesk queue with joe as the requestor
    my $ticket = RT::Test->last_ticket( $bjoern );
    isa_ok ($ticket, 'RT::Ticket');
    is ($ticket->Id, $id, "correct ticket id");
    is ($ticket->Subject , 'This is a test of new ticket creation', "Created the ticket");

    # Bjoern adds systems@ as a cc on the ticket
    ok($ticket->AddWatcher( Type => 'Cc', Email => 'systems@example.com' ), "Added systems@ as a watcher");

    # Bjoern adds a comment
    record_ok( mode => 'comment', on => $ticket, as => $bjoern );

    # No mail is sent out (Bjoern would get it, but NotifyActor is not set)
    got_mail_ok();

    # Bjoern adds a correspondence
    record_ok( mode => 'correspond', on => $ticket, as => $bjoern );

    #   Joe and AdminCCs on #301 are notified, as is systems@
    got_mail_ok(
        {   from => qr/helpdesk\@/,
            to   => qr/joe\@/,
            cc   => qr/systems\@/,
            id   => $systicket,
        },
    );

    # Ticket #302 is created in the system queue with helpdesk@ as the requestor
    $ticket = RT::Test->last_ticket( $sven );
    is($ticket->RequestorAddresses, 'helpdesk@example.com');

    # Auto-reply goes back to #301, and to sven
    got_mail_ok(
        {   from => qr/systems\@/,
            to   => qr/helpdesk\@/,
            id   => $systicket,
        },
        {   from => qr/systems\@/,
            bcc  => qr/sven\@/,
        },
    );

    # Auto-reply gets dropped
    got_mail_ok();
    is(RT::Test->last_ticket->id, $ticket->id);

    # Ticket #302 is linked to ticket #301

    # Sven adds a comment on #302
    record_ok( mode => 'comment', on => $systicket, as => $sven );

    #   AdminCCs on #302 are notified
    got_mail_ok();

    # Sven adds a correspondence on #302
    record_ok( mode => 'correspond', on => $systicket, as => $sven );

    #   AdminCCs on #302 are notified, as is helpdesk@,
    got_mail_ok(
        {   from => qr/systems\@/,
            to   => qr/helpdesk\@/,
            id   => $systicket,
        },
    );

    #   which notifies Bjoern and Joe on #301
    got_mail_ok(
        {   from => qr/helpdesk\@/,
            bcc  => qr/bjoern\@/,
        },
        {   from => qr/helpdesk\@/,
            to   => qr/joe\@/,
        },
    );

    # Bjoern adds a comment on #301
    record_ok( mode => 'comment', on => $helpticket, as => $bjoern );

    #   AdminCCs on #301 are notified
    got_mail_ok();

    # Bjoern adds a correspondence on #301
    record_ok( mode => 'correspond', on => $helpticket, as => $bjoern );

    #   Joe and AdminCCs on #301 are notified, as is systems@
    got_mail_ok(
        {   from => qr/helpdesk\@/,
            to   => qr/joe\@/,
            cc   => qr/systems\@/,
            id   => $helpticket,
        },
    );

    #   which notifies Sven and AdminCCs on #302
    got_mail_ok(
        {   from => qr/systems\@/,
            bcc  => qr/sven\@/,
        },
    );

}

# ======> SITUATION 4:  Helpdesk queue adds systems@ as permanent AdminCC
# (linked system ticket gets all correspondence and comments; helpdesk
# gets correspondence from systems)

{
    # Joe sends mail to helpdesk@
    my $text = <<EOF;
From: joe\@example.com
To: helpdesk\@example.com
Subject: This is a test of new ticket creation
Message-Id: fourth\@example.com

A helpdesk ticket
EOF

    my ($status, $id) = RT::Test->send_via_mailgate($text, queue => 'Helpdesk');
    is ($status >> 8, 0, "The mail gateway exited normally");
    ok ($id, "Created ticket");
    my ($helpticket, $systicket) = ($id, $id + 1);

    # Sends mail back to Joe, and to Bjoern
    got_mail_ok( { to => qr/joe\@/ }, { bcc => qr/bjoern\@/} );

    # Ticket #401 is created in the helpdesk queue with joe as the requestor
    my $ticket = RT::Test->last_ticket( $bjoern );
    isa_ok ($ticket, 'RT::Ticket');
    is ($ticket->Id, $id, "correct ticket id");
    is ($ticket->Subject , 'This is a test of new ticket creation', "Created the ticket");

    # Bjoern adds systems@ as an AdminCC on the ticket
    ok($ticket->AddWatcher( Type => 'AdminCc', Email => 'systems@example.com' ), "Added systems@ as a watcher");

    # Bjoern adds a comment
    record_ok( mode => 'comment', on => $ticket, as => $bjoern );

    #   AdminCCs on #401 are notified, as is systems@
    got_mail_ok(
        {   from => qr/helpdesk-comment\@/,
            bcc  => qr/systems\@/,
            id   => $systicket,
        },
    );

    # Ticket #402 is created in the system queue with helpdesk-comment@ as the requestor
    $ticket = RT::Test->last_ticket( $sven );
    is($ticket->RequestorAddresses, 'helpdesk-comment@example.com');

    # Auto-reply goes back to #401, and to sven
    got_mail_ok(
        {   from => qr/systems\@/,
            to   => qr/helpdesk-comment\@/,
            id   => $systicket,
        },
        {   from => qr/systems\@/,
            bcc  => qr/sven\@/,
        },
    );

    # Auto-reply gets dropped
    got_mail_ok();
    is(RT::Test->last_ticket->id, $ticket->id);

    # Ticket #402 is linked to ticket #401

    # Sven adds a comment on #402
    record_ok( mode => 'comment', on => $systicket, as => $sven );

    #   AdminCCs on #402 are notified
    got_mail_ok();

    # Sven adds a correspondence on #402
    record_ok( mode => 'correspond', on => $systicket, as => $sven );

    #   AdminCCs on #402 are notified, as is helpdesk-comment@,
    got_mail_ok(
        {   from => qr/systems\@/,
            to   => qr/helpdesk-comment\@/,
            id   => $systicket,
        },
    );
    #   which notifies Bjoern and AdminCCs on #401
    got_mail_ok(
        {   from => qr/helpdesk-comment\@/,
            bcc  => qr/bjoern\@/,
        },
    );

    # Bjoern adds a comment on #401
    record_ok( mode => 'comment', on => $helpticket, as => $bjoern );
    #   AdminCCs on #401 are notified, as is systems@
    got_mail_ok(
        {   from => qr/helpdesk-comment\@/,
            bcc  => qr/systems\@/,
            id   => $helpticket,
        },
    );
    #   which notifies Sven and AdminCCs on #402
    got_mail_ok(
        {   from => qr/systems\@/,
            bcc  => qr/sven\@/,
        },
    );

    # Bjoern adds a correspondence on #401
    record_ok( mode => 'correspond', on => $helpticket, as => $bjoern );
    #   Joe and AdminCCs on #401 are notified, as is systems@
    got_mail_ok(
        {   from => qr/helpdesk\@/,
            bcc  => qr/systems\@/,
            id   => $helpticket,
        },
        {   from => qr/helpdesk\@/,
            to   => qr/joe\@/,
        },
    );

    #   which notifies Sven and AdminCCs on #402 (and requestor, which is helpdesk-comment)
    got_mail_ok(
        {   from => qr/systems\@/,
            bcc  => qr/sven\@/,
        },
        {   from => qr/systems\@/,
            to   => qr/helpdesk-comment\@/,
            id   => $systicket,
        },
    );

    # helpdesk-comment@ mail gets dropped
    got_mail_ok();
}


# ======> SITUATION 5:  Helpdesk queue adds systems@ as permanent
# AdminCC, systems adds helpdesk@ as permanent AdminCC (All
# correspondence and comment from helpdesk added as comment on system;
# all correspondence and comment from system added as comment on helpdesk)

{
    # Joe sends mail to helpdesk@
    my $text = <<EOF;
From: joe\@example.com
To: helpdesk\@example.com
Subject: This is a test of new ticket creation
Message-Id: fifth\@example.com

A helpdesk ticket
EOF

    my ($status, $id) = RT::Test->send_via_mailgate($text, queue => 'Helpdesk');
    is ($status >> 8, 0, "The mail gateway exited normally");
    ok ($id, "Created ticket");
    my ($helpticket, $systicket) = ($id, $id + 1);

    # Sends mail back to Joe, and to Bjoern
    got_mail_ok( { to => qr/joe\@/ }, { bcc => qr/bjoern\@/} );

    # Ticket #501 is created in the helpdesk queue with joe as the requestor
    my $ticket = RT::Test->last_ticket( $bjoern );
    isa_ok ($ticket, 'RT::Ticket');
    is ($ticket->Id, $id, "correct ticket id");
    is ($ticket->Subject , 'This is a test of new ticket creation', "Created the ticket");

    # Bjoern adds systems@ as an AdminCC ticket #501
    # Bjoern adds a comment
    #   AdminCCs on #501 are notified, as is systems@

    # Ticket #502 is created in the system queue with helpdesk-comment@ as
    # the requestor
    # Ticket #502 is linked to ticket #501
    # Sven takes ticket #502
    # Sven adds helpdesk@ as an AdminCC on ticket #502

    # Sven adds a comment on #502
    #   AdminCCs on #502 are notified, as is helpdesk-comment@,
    #   which adds a comment on #501,
    #   which notifies Bjoern and AdminCCs on #501
    # (Note that RT will correctly detect that #502 has seen this comment
    # already, and _not_loop it back!)

    # Sven adds a correspondence on #502
    #   AdminCCs on #502 are notified, as is helpdesk-comment@,
    #   which adds a comment on #501,
    #   which notifies Bjoern and AdminCCs on #501
    # (See above note about looping)

    # Bjoern adds a comment on #501
    #   AdminCCs on #501 are notified, as is systems@
    #   which adds a comment on #502,
    #   which notifies Sven and AdminCCs on #502
    # (See above note about looping)

    # Bjoern adds a correspondence on #501
    #   Joe and AdminCCs on #501 are notified, as is systems@
    #   which adds a comment on #502,
    #   which notifies Sven and AdminCCs on #502
    # (see above note about looping)
}

undef $m;
done_testing;
