use strict;
use warnings;
use RT::Test tests => undef;

use RT::Test::Email;
use Test::Warn;

my $root = RT::User->new(RT->SystemUser);
$root->Load('root');

# Set root as admincc
my $q = RT::Queue->new(RT->SystemUser);
$q->Load('General');
my ($ok, $msg) = $q->AddWatcher( Type => 'AdminCc', PrincipalId => $root->Id );
ok($ok, "Added root as a watcher on the General queue");

# Create a couple users to test notifications
my %users;
for my $user_name (qw(enduser tech)) {
    my $user = $users{$user_name} = RT::User->new(RT->SystemUser);
    $user->Create( Name => ucfirst($user_name),
                   Privileged => 1,
                   EmailAddress => $user_name.'@example.com');
    my ($val, $msg);
    ($val, $msg) = $user->PrincipalObj->GrantRight(Object =>$q, Right => $_)
        for qw(ModifyTicket OwnTicket ShowTicket);
}

my $t = RT::Ticket->new(RT->SystemUser);
my ($tid, $ttrans, $tmsg);

diag "Autoreply and AdminCc (Transaction)";
mail_ok {
    ($tid, $ttrans, $tmsg) = 
        $t->Create(Subject => "The internet is broken",
                   Owner => 'Tech', Requestor => 'Enduser',
                   Queue => 'General');
} { from    => qr/The default queue/,
    to      => 'enduser@example.com',
    subject => qr/\Q[example.com #1] AutoReply: The internet is broken\E/,
    body    => parts_regex(
        'trouble ticket regarding \*?The internet is broken\*?',
        'trouble ticket regarding <b>The internet is broken</b>'
    ),
    'Content-Type' => qr{multipart},
},{ from    => qr/RT System/,
    bcc     => 'root@localhost',
    subject => qr/\Q[example.com #1] The internet is broken\E/,
    body    => parts_regex(
        'Request (\[\d+\])?1(\s*[(<]http://localhost:\d+/Ticket/Display\.html\?id=1[)>])?\s*was acted upon by RT_System',
        'Request <a href="http://localhost:\d+/Ticket/Display\.html\?id=1">1</a> was acted upon by RT_System\.</b>'
    ),
    'Content-Type' => qr{multipart},
};

diag "Admin Correspondence and Correspondence";
mail_ok {
    ($ok, $tmsg) = $t->Correspond(
        MIMEObj => HTML::Mason::Commands::MakeMIMEEntity(
            Body => '<p>This is a test of <b>HTML</b> correspondence.</p>',
            Type => 'text/html',
        ),
    );
} { from    => qr/RT System/,
    bcc     => 'root@localhost',
    subject => qr/\Q[example.com #1] The internet is broken\E/,
    body    => parts_regex(
        'Ticket URL: (?:\[\d+\])?http://localhost:\d+/Ticket/Display\.html\?id=1.+?'.
        'This is a test of \*?HTML\*? correspondence\.',
        'Ticket URL: <a href="(http://localhost:\d+/Ticket/Display\.html\?id=1)">\1</a>.+?'.
        '<p>This is a test of <b>HTML</b> correspondence\.</p>'
    ),
    'Content-Type' => qr{multipart},
},{ from    => qr/RT System/,
    to      => 'enduser@example.com',
    subject => qr/\Q[example.com #1] The internet is broken\E/,
    body    => parts_regex(
        'This is a test of \*?HTML\*? correspondence\.',
        '<p>This is a test of <b>HTML</b> correspondence\.</p>'
    ),
    'Content-Type' => qr{multipart},
};

SKIP: {
    skip "Only fails on core HTMLFormatter", 9
        unless RT->Config->Get("HTMLFormatter") eq "core";
    require HTML::FormatText::WithLinks::AndTables;
    skip "Only fails with older verions of HTML::FormatText::WithLinks::AndTables", 9
        unless $HTML::FormatText::WithLinks::AndTables::VERSION < 0.03;
    diag "Failing HTML -> Text conversion";
    warnings_like {
        my $body = '<table><tr><td><table><tr><td>Foo</td></tr></table></td></tr></table>';
        mail_ok {
            ($ok, $tmsg) = $t->Correspond(
                MIMEObj => HTML::Mason::Commands::MakeMIMEEntity(
                    Body => $body,
                    Type => 'text/html',
                ),
            );
        } { from    => qr/RT System/,
            bcc     => 'root@localhost',
            subject => qr/\Q[example.com #1] The internet is broken\E/,
            body    => qr{Ticket URL: <a href="(http://localhost:\d+/Ticket/Display\.html\?id=1)">\1</a>.+?$body}s,
            'Content-Type' => qr{text/html},  # TODO
        },{ from    => qr/RT System/,
            to      => 'enduser@example.com',
            subject => qr/\Q[example.com #1] The internet is broken\E/,
            body    => qr{$body},
            'Content-Type' => qr{text/html},  # TODO
        };
    } [(qr/uninitialized value/, qr/Failed to downgrade HTML/)x3];
}


diag "Admin Comment in HTML";
mail_ok {
    ($ok, $tmsg) = $t->Comment(
        MIMEObj => HTML::Mason::Commands::MakeMIMEEntity(
            Body => '<p>Comment test, <em>please!</em></p>',
            Type => 'text/html',
        ),
    );
} { from    => qr/RT System/,
    bcc     => 'root@localhost',
    subject => qr/\Q[example.com #1] [Comment] The internet is broken\E/,
    body    => parts_regex(
        'This is a comment about (\[\d+\])?ticket.1(\s*[(<]http://localhost:\d+/Ticket/Display\.html\?id=1[)>])?\..+?'.
        'It is not sent to the Requestor\(s\):.+?'.
        'Comment test, _?please!_?',

        '<p>This is a comment about <a href="http://localhost:\d+/Ticket/Display\.html\?id=1">ticket 1</a>\. '.
        'It is not sent to the Requestor\(s\):</p>.+?'.
        '<p>Comment test, <em>please!</em></p>',
    ),
    'Content-Type' => qr{multipart},
};


diag "Resolved in HTML templates";
mail_ok {
    ($ok, $tmsg) = $t->SetStatus('resolved');
} { from    => qr/RT System/,
    to      => 'enduser@example.com',
    subject => qr/\Q[example.com #1] Resolved: The internet is broken\E/,
    body    => parts_regex(
        'According to our records, your request has been resolved\.',
        '<p>According to our records, your request has been resolved\.',
    ),
    'Content-Type' => qr{multipart},
};


diag "Status changes in HTML";
my $scrip = RT::Scrip->new(RT->SystemUser);
my ($sval, $smsg) =$scrip->Create(
    ScripCondition => 'On Status Change',
    ScripAction => 'Notify Requestors',
    Template => 'Status Change in HTML',
    Queue => $q->Id,
    Description => 'Tell requestors about status changes'
);
ok ($sval, $smsg);
ok ($scrip->Id, "Created the scrip");
ok ($scrip->TemplateObj->Id, "Created the scrip template");
ok ($scrip->ConditionObj->Id, "Created the scrip condition");
ok ($scrip->ActionObj->Id, "Created the scrip action");

mail_ok {
    ($ok, $tmsg) = $t->SetStatus('stalled');
} { from    => qr/RT System/,
    to      => 'enduser@example.com',
    subject => qr/\Q[example.com #1] Status Changed to: stalled\E/,
    body    => parts_regex(
        'http://localhost:\d+/Ticket/Display\.html\?id=1.+?',
        '<a href="(http://localhost:\d+/Ticket/Display\.html\?id=1)">\1</a>'
    ),
    'Content-Type' => qr{multipart},
};

done_testing;

sub parts_regex {
    my ($text, $html) = @_;

    my $pattern = 'Content-Type: text/plain.+?' . $text . '.+?' .
                  'Content-Type: text/html.+?'  . $html;

    return qr/$pattern/s;
}

