use strict;
use warnings;

use RT::Test tests => undef, playwright => 1, config => 'Set( $ArticleOnTicketCreate, 1 );';

my ( $url, $p ) = RT::Test->started_ok;

$p->login();

diag "Create ticket";
{
    $p->goto_create_ticket(1);

    $p->submit_form_ok(
        {
            form_name => 'TicketCreate',
            fields    => {
                Subject => 'Test ticket update',
                Content => 'this is ticket create message',
                Cc      => 'alice@example.com',
            },
            button => 'SubmitTicket',
        },
        'Create ticket'
    );
    $p->text_like(qr/Ticket \d+ created in queue/);
}

diag "Reply ticket";
{
    my $reply = $p->find_element(q{//a[text()='Reply']});
    my $href = $reply->getAttribute('href');
    $p->get_ok($href);

    # Check hidden TxnRecipients
    my $hidden_recipients = $p->{page}->locator('input[name="TxnRecipients"][type="hidden"]')->first();
    ok( $hidden_recipients->count() > 0, 'Hidden TxnRecipients' );

    my $send_all_count = $p->{page}->locator('input[name="TxnSendMailToAll"]')->count();
    is( $send_all_count, 1, 'One TxnSendMailToAll input' );

    my $send_all = $p->{page}->locator('input[name="TxnSendMailToAll"]')->first();
    ok( $send_all->isChecked(), 'TxnSendMailToAll is checked' );

    my $send_alice_count = $p->{page}->locator('input[name="TxnSendMailTo"][value="alice@example.com"]')->count();
    is( $send_alice_count, 1, 'One TxnSendMailTo alice input' );
    my $send_alice = $p->{page}->locator('input[name="TxnSendMailTo"][value="alice@example.com"]')->first();
    ok( $send_alice->isChecked(), 'TxnSendMailTo alice is checked' );

    $p->text_contains('On Correspond Notify Requestors and Ccs');

    $send_alice->click();
    ok( !$send_alice->isChecked(), 'TxnSendMailTo alice is not checked' );
    $send_all = $p->{page}->locator('input[name="TxnSendMailToAll"]')->first();
    ok( !$send_all->isChecked(), 'TxnSendMailToAll is not checked automatically' );

    $send_alice->click();
    ok( $send_alice->isChecked(), 'TxnSendMailTo alice is checked again' );
    $send_all = $p->{page}->locator('input[name="TxnSendMailToAll"]')->first();
    ok( $send_all->isChecked(), 'TxnSendMailToAll is checked automatically' );

    $send_all->click();
    ok( !$send_all->isChecked(), 'TxnSendMailToAll is not checked' );
    $send_alice = $p->{page}->locator('input[name="TxnSendMailTo"][value="alice@example.com"]')->first();
    ok( !$send_alice->isChecked(), 'TxnSendMailTo alice is not checked automatically' );

    $send_all->click();
    ok( $send_all->isChecked(), 'TxnSendMailToAll is checked' );
    $send_alice = $p->{page}->locator('input[name="TxnSendMailTo"][value="alice@example.com"]')->first();
    ok( $send_alice->isChecked(), 'TxnSendMailTo alice is checked automatically' );

    $p->submit_form_ok(
        {
            form_name => 'TicketUpdate',
            fields    => {
                UpdateContent    => 'this is a ticket update message',
                UpdateTimeWorked => 30,
            },
            button => 'SubmitTicket',
        },
        'Reply ticket'
    );
    $p->text_contains('Correspondence added');

    $p->find_element(q{//div[contains(@class, 'transaction')]});
    $p->text_contains('this is a ticket update message');
    $p->text_contains('30 minutes');

    my $last_email = $p->{page}->locator('a[href*="ShowEmailRecord.html"]')->first();

    # Click and wait for popup
    $last_email->click();
    $p->wait_for_htmx;
    my $pages = $p->{page}->context()->pages();
    my $popup = $pages->[-1];  # Get the last (newest) page
    $p->text_contains('CC: alice@example.com', $popup);
    $popup->close();
}

diag "Comment on ticket";
{
    my $comment = $p->find_element(q{//a[text()='Comment']});
    my $href = $comment->getAttribute('href');
    $p->get_ok($href);

    # Check hidden TxnRecipients
    my $hidden_recipients = $p->{page}->locator('input[name="TxnRecipients"][type="hidden"]')->first();
    ok( $hidden_recipients->count() > 0, 'Hidden TxnRecipients' );

    # Check no TxnSendMailToAll
    my $send_all_count = $p->{page}->locator('input[name="TxnSendMailToAll"]')->count();
    ok( $send_all_count == 0, 'No TxnSendMailToAll' );

    $p->text_contains('On Comment Notify Other Recipients as Comment');

    $p->submit_form_ok(
        {
            form_name => 'TicketUpdate',
            fields    => {
                UpdateContent => 'this is a ticket comment',
                UpdateCc      => 'alice@example.com, bob@example.com',
                UpdateBcc     => 'richard@example.com',
            },
            button => 'SubmitTicket',
        },
        'Comment on ticket'
    );
    $p->text_contains('Comments added');

    # Find the specific transaction containing our message to ensure it's loaded and visible
    my $transaction = $p->find_element(q{//div[contains(@class, 'transaction') and contains(., 'this is a ticket comment')]});
    $p->text_contains('this is a ticket comment');

    # Wait for and scroll to email link to ensure transaction details are fully loaded
    my $last_email = $p->{page}->locator('a[href*="ShowEmailRecord.html"]')->first();
    $last_email->scrollIntoViewIfNeeded();  # Scroll to trigger lazy load of transaction details

    # RT-Send-CC and email addresses are in separate table cells, check both
    $p->text_contains('RT-Send-CC:');
    $p->text_contains('alice@example.com, bob@example.com');
    $p->text_lacks('RT-Send-BCC: richard@example.com');    # ShowBccHeader is false by default

    # Click and wait for popup
    $last_email->click();
    $p->wait_for_htmx;
    my $pages = $p->{page}->context()->pages();
    my $popup = $pages->[-1];  # Get the last (newest) page
    $p->text_contains('CC: alice@example.com, bob@example.com', $popup);
    $p->text_contains('BCC: richard@example.com', $popup);
    $popup->close();
}

diag "Test one-time checkboxes";
{
    my $comment = $p->find_element(q{//a[text()='Comment']});
    my $href = $comment->getAttribute('href');
    $p->get_ok($href);

    # Check hidden TxnRecipients
    my $hidden_recipients = $p->{page}->locator('input[name="TxnRecipients"][type="hidden"]')->first();
    ok( $hidden_recipients->count() > 0, 'Hidden TxnRecipients' );

    # Check no TxnSendMailToAll
    my $send_all_count = $p->{page}->locator('input[name="TxnSendMailToAll"]')->count();
    ok( $send_all_count == 0, 'No TxnSendMailToAll' );

    $p->text_contains('On Comment Notify Other Recipients as Comment');

    my $update_cc  = $p->{page}->locator('input[name="UpdateCc"]')->first();
    my $update_bcc = $p->{page}->locator('input[name="UpdateBcc"]')->first();

    my $update_cc_all      = $p->{page}->locator('input[name="AllSuggestedCc"]')->first();
    my $update_cc_bob      = $p->{page}->locator('input[name="UpdateCc-bob@example.com"]')->first();
    my $update_cc_richard  = $p->{page}->locator('input[name="UpdateCc-richard@example.com"]')->first();
    my $update_bcc_all     = $p->{page}->locator('input[name="AllSuggestedBcc"]')->first();
    my $update_bcc_bob     = $p->{page}->locator('input[name="UpdateBcc-bob@example.com"]')->first();
    my $update_bcc_richard = $p->{page}->locator('input[name="UpdateBcc-richard@example.com"]')->first();


    ok( !$update_cc_all->isChecked(),      'AllSuggestedCc is not checked' );
    ok( !$update_cc_bob->isChecked(),      'UpdateCc-bob@example.com is not checked' );
    ok( !$update_cc_richard->isChecked(),  'UpdateCc-richard is not checked' );
    ok( !$update_bcc_all->isChecked(),     'AllSuggestedBcc is not checked' );
    ok( !$update_bcc_bob->isChecked(),     'UpdateBcc-bob@example.com is not checked' );
    ok( !$update_bcc_richard->isChecked(), 'UpdateBcc-richard is not checked' );
    is( $update_cc->inputValue(),  '', 'UpdateCc is empty' );
    is( $update_bcc->inputValue(), '', 'UpdateBcc is empty' );

    $update_cc_all->click();
    Test::More::pass('Click AllSuggestedCc');
    ok( $update_cc_all->isChecked(), 'AllSuggestedCc is checked' );
    $update_cc          = $p->{page}->locator('input[name="UpdateCc"]')->first();
    $update_bcc         = $p->{page}->locator('input[name="UpdateBcc"]')->first();
    $update_cc_bob      = $p->{page}->locator('input[name="UpdateCc-bob@example.com"]')->first();
    $update_cc_richard  = $p->{page}->locator('input[name="UpdateCc-richard@example.com"]')->first();
    $update_bcc_all     = $p->{page}->locator('input[name="AllSuggestedBcc"]')->first();
    $update_bcc_bob     = $p->{page}->locator('input[name="UpdateBcc-bob@example.com"]')->first();
    $update_bcc_richard = $p->{page}->locator('input[name="UpdateBcc-richard@example.com"]')->first();

    ok( $update_cc_bob->isChecked(),       'UpdateCc-bob@example.com is checked automatically' );
    ok( $update_cc_richard->isChecked(),   'UpdateCc-richard is checked automatically' );
    ok( !$update_bcc_all->isChecked(),     'AllSuggestedBcc is not checked' );
    ok( !$update_bcc_bob->isChecked(),     'UpdateBcc-bob@example.com is not checked' );
    ok( !$update_bcc_richard->isChecked(), 'UpdateBcc-richard is not checked' );

    # There is no space after the comma on Chrome, but there is one on Firefox.
    like( $update_cc->inputValue(), qr/bob\@example.com,\s*richard\@example.com/, 'UpdateCc is updated automatically' );
    is( $update_bcc->inputValue(), '', 'UpdateBcc is empty' );

    $update_cc_bob->click();
    Test::More::pass('Click UpdateCc-bob');
    ok( !$update_cc_bob->isChecked(), 'UpdateCc-bob is not checked' );
    $update_cc          = $p->{page}->locator('input[name="UpdateCc"]')->first();
    $update_bcc         = $p->{page}->locator('input[name="UpdateBcc"]')->first();
    $update_cc_all      = $p->{page}->locator('input[name="AllSuggestedCc"]')->first();
    $update_cc_richard  = $p->{page}->locator('input[name="UpdateCc-richard@example.com"]')->first();
    $update_bcc_all     = $p->{page}->locator('input[name="AllSuggestedBcc"]')->first();
    $update_bcc_bob     = $p->{page}->locator('input[name="UpdateBcc-bob@example.com"]')->first();
    $update_bcc_richard = $p->{page}->locator('input[name="UpdateBcc-richard@example.com"]')->first();

    ok( $update_cc_richard->isChecked(),   'UpdateCc-richard@example.com is checked' );
    ok( !$update_cc_all->isChecked(),      'AllSuggestedCc is not checked automatically' );
    ok( !$update_bcc_all->isChecked(),     'AllSuggestedBcc is not checked' );
    ok( !$update_bcc_bob->isChecked(),     'UpdateBcc-bob@example.com is not checked' );
    ok( !$update_bcc_richard->isChecked(), 'UpdateBcc-richard is not checked' );

    is( $update_cc->inputValue(),  'richard@example.com', 'UpdateCc is updated automatically' );
    is( $update_bcc->inputValue(), '',                    'UpdateBcc is empty' );

    $update_bcc_bob->click();
    Test::More::pass('Click UpdateBcc-bob');
    ok( $update_bcc_bob->isChecked(), 'UpdateCc-bob is checked' );
    $update_cc          = $p->{page}->locator('input[name="UpdateCc"]')->first();
    $update_bcc         = $p->{page}->locator('input[name="UpdateBcc"]')->first();
    $update_cc_all      = $p->{page}->locator('input[name="AllSuggestedCc"]')->first();
    $update_cc_bob      = $p->{page}->locator('input[name="UpdateCc-bob@example.com"]')->first();
    $update_cc_richard  = $p->{page}->locator('input[name="UpdateCc-richard@example.com"]')->first();
    $update_bcc_all     = $p->{page}->locator('input[name="AllSuggestedBcc"]')->first();
    $update_bcc_richard = $p->{page}->locator('input[name="UpdateBcc-richard@example.com"]')->first();

    ok( !$update_cc_bob->isChecked(),      'UpdateCc-richard@example.com is not checked' );
    ok( $update_cc_richard->isChecked(),   'UpdateCc-richard@example.com is checked' );
    ok( !$update_cc_all->isChecked(),      'AllSuggestedCc is not checked automatically' );
    ok( !$update_bcc_all->isChecked(),     'AllSuggestedBcc is not checked' );
    ok( !$update_bcc_richard->isChecked(), 'UpdateBcc-richard is not checked' );

    is( $update_cc->inputValue(),  'richard@example.com', 'UpdateCc is updated automatically' );
    is( $update_bcc->inputValue(), 'bob@example.com',     'UpdateBcc is updated' );

    $update_bcc_richard->click();
    Test::More::pass('Click UpdateBcc-richard');
    ok( $update_bcc_richard->isChecked(), 'UpdateCc-richard is checked' );
    $update_cc         = $p->{page}->locator('input[name="UpdateCc"]')->first();
    $update_bcc        = $p->{page}->locator('input[name="UpdateBcc"]')->first();
    $update_cc_all     = $p->{page}->locator('input[name="AllSuggestedCc"]')->first();
    $update_cc_bob     = $p->{page}->locator('input[name="UpdateCc-bob@example.com"]')->first();
    $update_cc_richard = $p->{page}->locator('input[name="UpdateCc-richard@example.com"]')->first();
    $update_bcc_all    = $p->{page}->locator('input[name="AllSuggestedBcc"]')->first();
    $update_bcc_bob    = $p->{page}->locator('input[name="UpdateBcc-bob@example.com"]')->first();

    ok( !$update_cc_bob->isChecked(),    'UpdateCc-bob@example.com is not checked' );
    ok( $update_cc_richard->isChecked(), 'UpdateCc-richard@example.com is checked' );
    ok( !$update_cc_all->isChecked(),    'AllSuggestedCc is not checked automatically' );
    ok( $update_bcc_all->isChecked(),    'AllSuggestedBcc is checked automatically' );
    ok( $update_bcc_bob->isChecked(),    'UpdateBcc-bob is checked' );

    is( $update_cc->inputValue(), 'richard@example.com', 'UpdateCc is updated automatically' );
    like( $update_bcc->inputValue(), qr/bob\@example.com,\s*richard\@example.com/, 'UpdateBcc is updated' );

    $p->submit_form_ok(
        {
            form_name => 'TicketUpdate',
            fields    => {
                UpdateContent => 'this is another ticket comment',
            },
            button => 'SubmitTicket',
        },
        'Reply ticket'
    );
    $p->text_contains('Comments added');

    # Find the specific transaction containing our message to ensure it's loaded and visible
    my $transaction = $p->find_element(q{//div[contains(@class, 'transaction') and contains(., 'this is another ticket comment')]});
    $p->text_contains('this is another ticket comment');

    # Wait for and scroll to email link to ensure transaction details are fully loaded
    my $last_email = $p->{page}->locator('a[href*="ShowEmailRecord.html"]')->first();
    $last_email->scrollIntoViewIfNeeded();  # Scroll to trigger lazy load of transaction details

    # RT-Send-CC and email address are in separate table cells, check both
    $p->text_contains('RT-Send-CC:');
    $p->text_contains('richard@example.com');
    $p->text_lacks('RT-Send-BCC: bob@example.com');    # ShowBccHeader is false by default

    # Click and wait for popup
    $last_email->click();
    $p->wait_for_htmx;
    my $pages = $p->{page}->context()->pages();
    my $popup = $pages->[-1];  # Get the last (newest) page
    $p->text_contains('CC: richard@example.com', $popup);
    $p->text_contains('BCC: bob@example.com, richard@example.com', $popup);
    $popup->close();
}

$p->get_ok('/Prefs/Other.html');
$p->submit_form_ok(
    {
        form_name => 'ModifyPreferences',
        fields    => { 'SimplifiedRecipients' => 1 },
        button    => 'Update',
    },
    'Set SimplifiedRecipients'
);

$p->text_contains('Preferences saved');

$p->goto_ticket(1);

diag "Test simplied recipients";
{
    my $reply = $p->{page}->locator('a:has-text("Reply")')->first();
    my $href = $reply->getAttribute('href');
    $p->get_ok($href);

    # Check hidden TxnRecipients
    my $hidden_recipients = $p->{page}->locator('input[name="TxnRecipients"][type="hidden"]')->first();
    ok( $hidden_recipients->count() > 0, 'Hidden TxnRecipients' );

    # Wait for the 2 ajax requests of preview scrips to complete by waiting for 2 checkboxes
    my $send_all_locator = $p->{page}->locator('input[name="TxnSendMailToAll"]');

    # Check both inputs are checked
    ok( $send_all_locator->nth(0)->isChecked(), 'TxnSendMailToAll is checked' );
    ok( $send_all_locator->nth(1)->isChecked(), 'TxnSendMailToAll is checked' );

    my $send_alice_locator = $p->{page}->locator('input[name="TxnSendMailTo"][value="alice@example.com"]');
    my $send_alice_count = $send_alice_locator->count();
    is( $send_alice_count, 2, '2 TxnSendMailTo alice inputs' );

    # Check both inputs are checked
    ok( $send_alice_locator->nth(0)->isChecked(), 'TxnSendMailTo alice is checked' );
    ok( $send_alice_locator->nth(1)->isChecked(), 'TxnSendMailTo alice is checked' );

    $send_alice_locator->nth(0)->click();
    ok( !$send_alice_locator->nth(0)->isChecked(), 'TxnSendMailTo alice is not checked' );
    ok( !$send_alice_locator->nth(1)->isChecked(), 'TxnSendMailTo alice is not checked' );

    ok( !$send_all_locator->nth(0)->isChecked(), 'TxnSendMailToAll is not checked automatically' );
    ok( !$send_all_locator->nth(1)->isChecked(), 'TxnSendMailToAll is not checked automatically' );
    is( $send_all_locator->count(), 2, '2 TxnSendMailToAll inputs' );

    $send_alice_locator->nth(0)->click();
    ok( $send_alice_locator->nth(0)->isChecked(), 'TxnSendMailTo alice is checked again' );
    ok( $send_alice_locator->nth(1)->isChecked(), 'TxnSendMailTo alice is checked again' );

    ok( $send_all_locator->nth(0)->isChecked(), 'TxnSendMailToAll is checked automatically' );
    ok( $send_all_locator->nth(1)->isChecked(), 'TxnSendMailToAll is checked automatically' );

    $send_all_locator->nth(0)->click();
    ok( !$send_all_locator->nth(0)->isChecked(), 'TxnSendMailToAll is not checked' );
    ok( !$send_all_locator->nth(1)->isChecked(), 'TxnSendMailToAll is not checked' );

    ok( !$send_alice_locator->nth(0)->isChecked(), 'TxnSendMailTo alice is not checked automatically' );
    ok( !$send_alice_locator->nth(1)->isChecked(), 'TxnSendMailTo alice is not checked automatically' );

    $send_all_locator->nth(0)->click();
    ok( $send_all_locator->nth(0)->isChecked(), 'TxnSendMailToAll is checked' );
    ok( $send_all_locator->nth(1)->isChecked(), 'TxnSendMailToAll is checked' );

    ok( $send_alice_locator->nth(0)->isChecked(), 'TxnSendMailTo alice is checked automatically' );
    ok( $send_alice_locator->nth(1)->isChecked(), 'TxnSendMailTo alice is checked automatically' );

    $p->submit_form_ok(
        {
            form_name => 'TicketUpdate',
            fields    => {
                UpdateContent => 'this is another ticket update',
            },
            button => 'SubmitTicket',
        },
        'Reply ticket'
    );
    $p->text_contains('Correspondence added');

    $p->find_element(q{//div[contains(@class, 'transaction')]});
    $p->text_contains('this is another ticket update');

    my $last_email = $p->{page}->locator('a[href*="ShowEmailRecord.html"]')->first();

    # Click and wait for popup
    $last_email->click();
    $p->wait_for_htmx;
    my $pages = $p->{page}->context()->pages();
    my $popup = $pages->[-1];  # Get the last (newest) page
    $p->text_contains('CC: alice@example.com', $popup);
    $popup->close();
}

diag "Test quote selection feature";
{
    $p->goto_ticket(1);

    my $create_transaction = $p->find_element(q{//div[contains(@class, 'transaction') and contains(., 'this is ticket create message')]});
    ok($create_transaction, 'Found create transaction in ticket history');

    my $transaction_content = $create_transaction->textContent();
    like($transaction_content, qr/this is ticket create message/, 'Create transaction contains expected message');

    # Click the reply button positioned on the create transaction in the ticket history
    my $transaction_reply_button = $p->find_element(q{//div[contains(@class, 'transaction') and contains(., 'this is ticket create message')]//a[contains(@href, 'Action=Respond')]});
    ok($transaction_reply_button, 'Found reply button on create transaction');
    $p->find_element(q{//div[contains(@class, 'transaction')]});
    $transaction_reply_button->click();

    my $quoted_content = $p->{page}->locator('textarea[name="UpdateContent"]')->first();
    my $content_value = $quoted_content->inputValue();
    like($content_value, qr/this is ticket create message/, 'Quote selection populated UpdateContent with original message');
}

my $article = RT::Article->new( RT->SystemUser );
my ( $ret, $msg ) = $article->Create( Class => 1, Name => 'This is article name', Summary => 'This is article summary' );
ok( $ret, $msg );

diag "Test include article feature";
{
    my $reply = $p->{page}->locator('a:has-text("Reply")')->first();
    my $href = $reply->getAttribute('href');
    $p->get_ok($href);

    # Set richtext field - need to find CKEditor contenteditable
    my $ckeditor = $p->{page}->locator('textarea[name="UpdateContent"] + .ck-editor .ck-editor__editable')->first();
    $ckeditor->fill('This is include article reply');

    # Set select field for article
    is( $p->{page}->locator('[name=IncludeArticleId]')->first->selectOption( $article->Id . '' )->[0],
        $article->Id, 'Selected article' );
    sleep 1;
    $p->submit_form_ok(
        {
            form_name => 'TicketUpdate',
            button => 'SubmitTicket',
        },
        'Reply ticket'
    );
    $p->text_contains('Correspondence added');

    $p->find_element(q{//div[contains(@class, 'transaction')]});
    $p->text_contains('This is include article reply');
    $p->text_contains('This is article name');
    $p->text_contains('This is article summary');
}

diag "Test article SubjectOverride feature";
{
    # Build a class with a subject custom field and an article that fills it in.
    my $class = RT::Class->new( RT->SystemUser );
    ( $ret, $msg ) = $class->Create(
        Name        => 'SubjectOverrideClass-' . $$,
        Description => 'Class for the SubjectOverride test',
    );
    ok( $ret, "Created class: $msg" );
    ( $ret, $msg ) = $class->AddToObject( RT::Queue->new( RT->SystemUser ) );
    ok( $ret, "Applied class globally: $msg" );

    my $subject_cf = RT::CustomField->new( RT->SystemUser );
    ( $ret, $msg ) = $subject_cf->Create(
        Name       => 'Subject-' . $$,
        Type       => 'Text',
        MaxValues  => 1,
        LookupType => 'RT::Class-RT::Article',
    );
    ok( $ret, "Created subject custom field: $msg" );
    ( $ret, $msg ) = $subject_cf->AddToObject($class);
    ok( $ret, "Added subject custom field to class: $msg" );

    my $override_article = RT::Article->new( RT->SystemUser );
    ( $ret, $msg ) = $override_article->Create(
        Name                             => 'Subject override article ' . $$,
        Summary                          => 'Article that overrides the subject',
        Class                            => $class->Id,
        'CustomField-' . $subject_cf->Id => 'This clobbers your subject',
    );
    ok( $ret, "Created override article: $msg" );

    my $ticket = RT::Ticket->new( RT->SystemUser );
    $ticket->Load(1);

    # Without SubjectOverride configured on the class, applying the article must
    # not touch the subject.
    {
        my $reply = $p->{page}->locator('a:has-text("Reply")')->first();
        my $href  = $reply->getAttribute('href');
        $p->get_ok($href);

        my $subject_input = $p->{page}->locator('input[name="UpdateSubject"]')->first();
        is( $subject_input->inputValue(), $ticket->Subject, 'Subject starts as the ticket subject' );

        is(
            $p->{page}->locator('[name=IncludeArticleId]')->first->selectOption( $override_article->Id . '' )->[0],
            $override_article->Id,
            'Selected article with no SubjectOverride configured'
        );
        $p->wait_for_htmx;

        $subject_input = $p->{page}->locator('input[name="UpdateSubject"]')->first();
        is( $subject_input->inputValue(), $ticket->Subject,
            'Subject not updated when class has no SubjectOverride' );
    }

    # Point the class at the subject custom field, then apply the article again.
    ( $ret, $msg ) = $class->SetSubjectOverride( $subject_cf->Id );
    ok( $ret, "Set SubjectOverride: $msg" );

    {
        my $reply = $p->{page}->locator('a:has-text("Reply")')->first();
        my $href  = $reply->getAttribute('href');
        $p->get_ok($href);

        my $subject_input = $p->{page}->locator('input[name="UpdateSubject"]')->first();
        is( $subject_input->inputValue(), $ticket->Subject, 'Subject starts as the ticket subject' );

        is(
            $p->{page}->locator('[name=IncludeArticleId]')->first->selectOption( $override_article->Id . '' )->[0],
            $override_article->Id,
            'Selected article with SubjectOverride configured'
        );
        $p->wait_for_htmx;

        $subject_input = $p->{page}->locator('input[name="UpdateSubject"]')->first();
        is( $subject_input->inputValue(), 'This clobbers your subject',
            'Subject updated with the article SubjectOverride custom field value' );
    }

    # The same override must apply on the create screen, which renders its own
    # message widget (Ticket/Widgets/Create/Message) rather than MessageDetails.
    {
        $p->goto_create_ticket(1);

        my $subject_input = $p->{page}->locator('input[name="Subject"]')->first();
        is( $subject_input->inputValue(), '', 'Subject starts empty on create' );

        is(
            $p->{page}->locator('[name=IncludeArticleId]')->first->selectOption( $override_article->Id . '' )->[0],
            $override_article->Id,
            'Selected article on create with SubjectOverride configured'
        );
        $p->wait_for_htmx;

        $subject_input = $p->{page}->locator('input[name="Subject"]')->first();
        is( $subject_input->inputValue(), 'This clobbers your subject',
            'Subject updated on create with the article SubjectOverride custom field value' );

        # Submitting must persist the overridden subject on the new ticket; the
        # create page returns Display.html without re-rendering the widget, so
        # this proves the override survives the round trip on its own.
        $p->submit_form_ok(
            {
                form_name => 'TicketCreate',
                fields    => { Content => 'create with subject override' },
                button    => 'SubmitTicket',
            },
            'Create ticket with subject override'
        );
        $p->text_like(qr/Ticket \d+ created in queue/);

        my $new_ticket = RT::Test->last_ticket;
        is( $new_ticket->Subject, 'This clobbers your subject',
            'New ticket persisted the overridden subject' );
    }
}

diag "Test Reply from a dashboard";
{
    my $root = RT::CurrentUser->new('root');

    my $search = RT::SavedSearch->new($root);
    my ( $ret, $msg ) = $search->Create(
        Name    => 'Reply search',
        Type    => 'Ticket',
        Content => {
            Format => q{'<a href="__WebPath__/Ticket/Display.html?id=__id__">__id__</a>/TITLE:#',}
                . q{'<a href="__WebPath__/Ticket/Display.html?id=__id__">__Subject__</a>/TITLE:Subject',}
                . q{Reply},
            Query       => 'id = 1',
            OrderBy     => 'id',
            Order       => 'ASC',
            RowsPerPage => 10,
        },
    );
    ok( $ret, "Created saved search: $msg" );

    my $dashboard = RT::Dashboard->new($root);
    ( $ret, $msg ) = $dashboard->Create(
        Name    => 'Reply dashboard',
        Content => {
            Elements => [
                {   Layout   => 'col-12',
                    Elements => [
                        [   {   portlet_type => 'search',
                                id           => $search->Id,
                                description  => 'Ticket: Reply search'
                            }
                        ]
                    ],
                },
            ],
        },
    );
    ok( $ret, "Created dashboard: $msg" );

    ( $ret, $msg ) = $root->UserObj->SetPreferences( DefaultDashboard => $dashboard->Id );
    ok( $ret, "Set root's default dashboard: $msg" );

    $p->get_ok('/');

    ok( $p->{page}->locator('.htmx-indicator')->count > 0, 'Saved-search portlet renders a persistent htmx-indicator' );

    $p->wait_for_element('table.inline-edit button.inline-edit-modal:has-text("Reply")');
    $p->{page}->locator('table.inline-edit button.inline-edit-modal:has-text("Reply")')->first->click;

    # TxnSendMailToAll comes only from ShowSimplifiedRecipients, so it proves the request fired.
    $p->wait_for_element('#dynamic-modal input[name="TxnSendMailToAll"]');
    ok( $p->{page}->locator('#dynamic-modal input[name="TxnSendMailToAll"]')->count > 0,
        'Recipients list loaded in dashboard inline Reply modal' );
    ok( $p->{page}
            ->locator('#dynamic-modal input[type="checkbox"][name="TxnSendMailTo"][value="alice@example.com"]')->count
            > 0,
        'Cc recipient alice loaded in dashboard inline Reply modal'
      );

    my $reply_body = 'Reply sent from a dashboard';
    $p->{page}->locator('#dynamic-modal textarea[name="UpdateContent"] + .ck-editor .ck-editor__editable')
        ->first->fill($reply_body);
    $p->{page}->locator('#dynamic-modal input.submit')->first->click;
    $p->wait_for_element('.jGrowl-message:has-text("Correspondence added")');

    DBIx::SearchBuilder::Record::Cachable->FlushCache;
    my $ticket = RT::Ticket->new( RT->SystemUser );
    $ticket->Load(1);
    my $txns = $ticket->Transactions;
    $txns->Limit( FIELD => 'Type', VALUE => 'Correspond' );
    $txns->OrderByCols( { FIELD => 'id', ORDER => 'DESC' } );
    my $reply = $txns->First;
    ok( $reply, 'Reply from dashboard added a Correspond transaction' );
    like( $reply->Content, qr/\Q$reply_body\E/, 'Reply body saved from dashboard inline Reply modal' );
}

$p->logout;

done_testing;
