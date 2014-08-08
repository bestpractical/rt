use strict;
use warnings;

use RT::Test tests => 78;

my %string = (
    ru => {
        test      => "\x{442}\x{435}\x{441}\x{442}",
        autoreply => "\x{410}\x{432}\x{442}\x{43e}\x{43e}\x{442}\x{432}\x{435}\x{442}",
        support   => "\x{43f}\x{43e}\x{434}\x{434}\x{435}\x{440}\x{436}\x{43a}\x{430}",
    },
    latin1 => {
        test      => Encode::decode('latin1', "t\xE9st"),
        autoreply => Encode::decode('latin1', "a\xFCtoreply"),
        support   => Encode::decode('latin1', "supp\xF5rt"),
    },
);

my $queue = RT::Test->load_or_create_queue(
    Name              => 'Regression',
    CorrespondAddress => 'rt-recipient@example.com',
    CommentAddress    => 'rt-recipient@example.com',
);
ok $queue && $queue->id, 'loaded or created queue';

diag "make sure queue has no subject tag";
{
    my ($status, $msg) = $queue->SetSubjectTag( undef );
    ok $status, "set subject tag for the queue" or diag "error: $msg";
}

diag "set intial simple autoreply template";
{
    my $template = RT::Template->new( RT->SystemUser );
    $template->Load('Autoreply in HTML');
    ok $template->id, "loaded autoreply tempalte";

    my ($status, $msg) = $template->SetContent(
        "Subject: Autreply { \$Ticket->Subject }\n"
        ."\n"
        ."hi there it's an autoreply.\n"
        ."\n"
    );
    ok $status, "changed content of the template"
        or diag "error: $msg";
}

diag "basic test of autoreply";
{
    my $ticket = RT::Ticket->new( RT->SystemUser );
    $ticket->Create(
        Queue => $queue->id,
        Subject => 'test',
        Requestor => 'root@localhost',
    );
    my @mails = RT::Test->fetch_caught_mails;
    ok @mails, "got some outgoing emails";
}

diag "non-ascii Subject with ascii prefix set in the template";
foreach my $set ( 'ru', 'latin1' ) {
    my $ticket = RT::Ticket->new( RT->SystemUser );
    $ticket->Create(
        Queue => $queue->id,
        Subject => $string{$set}{test},
        Requestor => 'root@localhost',
    );
    my @mails = RT::Test->fetch_caught_mails;
    ok @mails, "got some outgoing emails";

    my $status = 1;
    foreach my $mail ( @mails ) {
        my $entity = parse_mail( $mail );
        my $subject = Encode::decode( "UTF-8", $entity->head->get('Subject') );
        $subject =~ /$string{$set}{test}/
            or do { $status = 0; diag "wrong subject: $subject" };
    }
    ok $status, "all mails have correct data";
}

foreach my $tag_set ( 'ru', 'latin1' ) {

diag "set non-ascii subject tag for the queue";
{
    my ($status, $msg) = $queue->SetSubjectTag( $string{$tag_set}{support} );
    ok $status, "set subject tag for the queue" or diag "error: $msg";
}

diag "ascii subject with non-ascii subject tag";
{
    my $ticket = RT::Ticket->new( RT->SystemUser );
    $ticket->Create(
        Queue => $queue->id,
        Subject => 'test',
        Requestor => 'root@localhost',
    );
    my @mails = RT::Test->fetch_caught_mails;
    ok @mails, "got some outgoing emails";

    my $status = 1;
    foreach my $mail ( @mails ) {
        my $entity = parse_mail( $mail );
        my $subject = Encode::decode( "UTF-8", $entity->head->get('Subject') );
        $subject =~ /$string{$tag_set}{support}/
            or do { $status = 0; diag "wrong subject: $subject" };
    }
    ok $status, "all mails have correct data";
}

diag "non-ascii subject with non-ascii subject tag";
foreach my $set ( 'ru', 'latin1' ) {
    my $ticket = RT::Ticket->new( RT->SystemUser );
    $ticket->Create(
        Queue => $queue->id,
        Subject => $string{$set}{test},
        Requestor => 'root@localhost',
    );
    my @mails = RT::Test->fetch_caught_mails;
    ok @mails, "got some outgoing emails";

    my $status = 1;
    foreach my $mail ( @mails ) {
        my $entity = parse_mail( $mail );
        my $subject = Encode::decode( "UTF-8", $entity->head->get('Subject') );
        $subject =~ /$string{$tag_set}{support}/
            or do { $status = 0; diag "wrong subject: $subject" };
        $subject =~ /$string{$set}{test}/
            or do { $status = 0; diag "wrong subject: $subject" };
    }
    ok $status, "all mails have correct data";
}

} # subject tag

diag "return back the empty subject tag";
{
    my ($status, $msg) = $queue->SetSubjectTag( undef );
    ok $status, "set subject tag for the queue" or diag "error: $msg";
}


foreach my $prefix_set ( 'ru', 'latin1' ) {

diag "add non-ascii subject prefix in the autoreply template";
{
    my $template = RT::Template->new( RT->SystemUser );
    $template->Load('Autoreply in HTML');
    ok $template->id, "loaded autoreply tempalte";

    my ($status, $msg) = $template->SetContent(
        "Subject: $string{$prefix_set}{autoreply} { \$Ticket->Subject }\n"
        ."\n"
        ."hi there it's an autoreply.\n"
        ."\n"
    );
    ok $status, "changed content of the template" or diag "error: $msg";
}

diag "ascii subject with non-ascii subject prefix in template";
{
    my $ticket = RT::Ticket->new( RT->SystemUser );
    $ticket->Create(
        Queue => $queue->id,
        Subject => 'test',
        Requestor => 'root@localhost',
    );
    my @mails = RT::Test->fetch_caught_mails;
    ok @mails, "got some outgoing emails";

    my $status = 1;
    foreach my $mail ( @mails ) {
        my $entity = parse_mail( $mail );
        my $subject = Encode::decode( "UTF-8", $entity->head->get('Subject') );
        $subject =~ /$string{$prefix_set}{autoreply}/
            or do { $status = 0; diag "wrong subject: $subject" };
    }
    ok $status, "all mails have correct data";
}

diag "non-ascii subject with non-ascii subject prefix in template";
foreach my $set ( 'ru', 'latin1' ) {
    my $ticket = RT::Ticket->new( RT->SystemUser );
    $ticket->Create(
        Queue => $queue->id,
        Subject => $string{$set}{test},
        Requestor => 'root@localhost',
    );
    my @mails = RT::Test->fetch_caught_mails;
    ok @mails, "got some outgoing emails";

    my $status = 1;
    foreach my $mail ( @mails ) {
        my $entity = parse_mail( $mail );
        my $subject = Encode::decode( "UTF-8", $entity->head->get('Subject') );
        $subject =~ /$string{$prefix_set}{autoreply}/
            or do { $status = 0; diag "wrong subject: $subject" };
        $subject =~ /$string{$set}{test}/
            or do { $status = 0; diag "wrong subject: $subject" };
    }
    ok $status, "all mails have correct data";
}

foreach my $tag_set ( 'ru', 'latin1' ) {
diag "set non-ascii subject tag for the queue";
{
    my ($status, $msg) = $queue->SetSubjectTag( $string{$tag_set}{support} );
    ok $status, "set subject tag for the queue" or diag "error: $msg";
}

diag "non-ascii subject, non-ascii prefix in template and non-ascii tag";
foreach my $set ( 'ru', 'latin1' ) {
    my $ticket = RT::Ticket->new( RT->SystemUser );
    $ticket->Create(
        Queue => $queue->id,
        Subject => $string{$set}{test},
        Requestor => 'root@localhost',
    );
    my @mails = RT::Test->fetch_caught_mails;
    ok @mails, "got some outgoing emails";

    my $status = 1;
    foreach my $mail ( @mails ) {
        my $entity = parse_mail( $mail );
        my $subject = Encode::decode( "UTF-8", $entity->head->get('Subject') );
        $subject =~ /$string{$prefix_set}{autoreply}/
            or do { $status = 0; diag "wrong subject: $subject" };
        $subject =~ /$string{$tag_set}{support}/
            or do { $status = 0; diag "wrong subject: $subject" };
        $subject =~ /$string{$set}{test}/
            or do { $status = 0; diag "wrong subject: $subject" };
    }
    ok $status, "all mails have correct data";
}

} # subject tag

diag "flush subject tag of the queue";
{
    my ($status, $msg) = $queue->SetSubjectTag( undef );
    ok $status, "set subject tag for the queue" or diag "error: $msg";
}

} # prefix set


diag "don't change subject via template";
# clean DB has autoreply that always changes subject in template,
# we should test situation when subject is not changed from template
{
    my $template = RT::Template->new( RT->SystemUser );
    $template->Load('Autoreply in HTML');
    ok $template->id, "loaded autoreply tempalte";

    my ($status, $msg) = $template->SetContent(
        "\n"
        ."\n"
        ."hi there it's an autoreply.\n"
        ."\n"
    );
    ok $status, "changed content of the template" or diag "error: $msg";
}

diag "non-ascii Subject without changes in template";
foreach my $set ( 'ru', 'latin1' ) {
    my $ticket = RT::Ticket->new( RT->SystemUser );
    $ticket->Create(
        Queue => $queue->id,
        Subject => $string{$set}{test},
        Requestor => 'root@localhost',
    );
    my @mails = RT::Test->fetch_caught_mails;
    ok @mails, "got some outgoing emails";

    my $status = 1;
    foreach my $mail ( @mails ) {
        my $entity = parse_mail( $mail );
        my $subject = Encode::decode( "UTF-8", $entity->head->get('Subject') );
        $subject =~ /$string{$set}{test}/
            or do { $status = 0; diag "wrong subject: $subject" };
    }
    ok $status, "all mails have correct data";
}

foreach my $tag_set ( 'ru', 'latin1' ) {
diag "set non-ascii subject tag for the queue";
{
    my ($status, $msg) = $queue->SetSubjectTag( $string{$tag_set}{support} );
    ok $status, "set subject tag for the queue" or diag "error: $msg";
}

diag "non-ascii Subject without changes in template and with non-ascii subject tag";
foreach my $set ( 'ru', 'latin1' ) {
    my $ticket = RT::Ticket->new( RT->SystemUser );
    $ticket->Create(
        Queue => $queue->id,
        Subject => $string{$set}{test},
        Requestor => 'root@localhost',
    );
    my @mails = RT::Test->fetch_caught_mails;
    ok @mails, "got some outgoing emails";

    my $status = 1;
    foreach my $mail ( @mails ) {
        my $entity = parse_mail( $mail );
        my $subject = Encode::decode( "UTF-8", $entity->head->get('Subject') );
        $subject =~ /$string{$set}{test}/
            or do { $status = 0; diag "wrong subject: $subject" };
        $subject =~ /$string{$tag_set}{support}/
            or do { $status = 0; diag "wrong subject: $subject" };
    }
    ok $status, "all mails have correct data";
}

} # subject tag set

