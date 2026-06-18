use strict;
use warnings;

use RT::Test tests => undef, playwright => 1;

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

diag "Test quote selection sends the selected text in the POST body, not the URL";
{
    my $ticket = RT::Test->create_ticket(
        Queue   => 'General',
        Subject => 'quote partial selection',
        Content => 'QUOTEME_MARKER and SKIPME_REMAINDER',
    );
    $p->goto_ticket( $ticket->id );
    $p->wait_for_element('.messagebody');

    # Select only "QUOTEME_MARKER" in the create transaction's message body.
    my $selected = $p->{page}->evaluate(<<'JS');
const walker = document.createTreeWalker(document.querySelector('.messagebody'), NodeFilter.SHOW_TEXT);
let node;
while ( (node = walker.nextNode()) && !node.nodeValue.includes('QUOTEME_MARKER') ) {}
const start = node.nodeValue.indexOf('QUOTEME_MARKER');
const range = document.createRange();
range.setStart(node, start);
range.setEnd(node, start + 'QUOTEME_MARKER'.length);
const sel = window.getSelection();
sel.removeAllRanges();
sel.addRange(range);
return sel.toString();
JS

    is( $selected, 'QUOTEME_MARKER', 'selected only the marker text in the message body' );

    $p->{page}->locator('a.reply-link')->first->click();
    $p->wait_for_htmx;

    my $url = $p->{page}->url();
    like( $url, qr/Action=Respond/, 'reply navigated to the update form' );
    unlike( $url, qr/QuoteContent/i, 'selected text is not in the URL (sent in the POST body)' );

    my $value = $p->{page}->locator('textarea[name="UpdateContent"]')->first->inputValue();
    like( $value, qr/QUOTEME_MARKER/, 'message box quotes the selected text' );
    unlike( $value, qr/SKIPME_REMAINDER/, 'message box excludes the unselected remainder' );
}

$p->logout;

done_testing;
