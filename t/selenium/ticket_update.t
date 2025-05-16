use strict;
use warnings;

use RT::Test tests => undef, selenium => 1;

my ( $url, $s ) = RT::Test->started_ok;

$s->login();

diag "Create ticket";
{
    $s->goto_create_ticket(1);

    $s->submit_form_ok(
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
    $s->text_like(qr/Ticket \d+ created in queue/);
}

diag "Reply ticket";
{
    my $reply = $s->find_element(q{//a[text()='Reply']});
    $s->get_ok( $reply->get_property('href') );

    $s->find_element_ok( q{//input[@name='TxnRecipients'][@type='hidden']}, '', 'Hidden TxnRecipients' );
    my @send_all = $s->find_elements(q{//input[@name='TxnSendMailToAll']});
    is( @send_all, 1, 'One TxnSendMailToAll input' );

    my $send_all = $send_all[0];
    ok( $send_all->is_selected, 'TxnSendMailToAll is checked' );

    my @send_alice = $s->find_elements( selector_to_xpath(q{input[name='TxnSendMailTo'][value='alice@example.com']}) );
    is( @send_alice, 1, 'One TxnSendMailTo alice input' );
    my $send_alice = $send_alice[0];
    ok( $send_alice->is_selected, 'TxnSendMailTo alice is checked' );

    sleep 0.5;
    $s->text_contains('On Correspond Notify Requestors and Ccs');

    $s->scroll_to(q{input[name='TxnSendMailTo'][value='alice@example.com']});
    $send_alice->click();
    ok( !$send_alice->is_selected, 'TxnSendMailTo alice is not checked' );
    $send_all = $s->find_element(q{//input[@name='TxnSendMailToAll']});
    ok( !$send_all->is_selected, 'TxnSendMailToAll is not checked automatically' );

    $send_alice->click();
    ok( $send_alice->is_selected, 'TxnSendMailTo alice is checked again' );
    $send_all = $s->find_element(q{//input[@name='TxnSendMailToAll']});
    ok( $send_all->is_selected, 'TxnSendMailToAll is checked automatically' );

    $send_all->click();
    ok( !$send_all->is_selected, 'TxnSendMailToAll is not checked' );
    $send_alice = $s->find_element(q{//input[@name='TxnSendMailTo'][@value='alice@example.com']});
    ok( !$send_alice->is_selected, 'TxnSendMailTo alice is not checked automatically' );

    $send_all->click();
    ok( $send_all->is_selected, 'TxnSendMailToAll is checked' );
    $send_alice = $s->find_element(q{//input[@name='TxnSendMailTo'][@value='alice@example.com']});
    ok( $send_alice->is_selected, 'TxnSendMailTo alice is checked automatically' );

    sleep 2;    # Firefox fails sometimes if there is no wait
    $s->submit_form_ok(
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
    $s->text_contains('Correspondence added');

    $s->find_element(q{//div[contains(@class, 'transaction')]});
    $s->text_contains('this is a ticket update message');
    $s->text_contains('30 minutes');

    my $last_email = ( $s->find_elements(q{//a[contains(@href, 'ShowEmailRecord.html')]}) )[0];
    $s->scroll_to(q{a[href*='ShowEmailRecord.html']});

    $last_email->click();
    $s->switch_to_window( $s->get_window_handles->[1] );
    sleep 0.1;
    $s->text_contains('CC: alice@example.com');
    $s->close;
    $s->switch_to_window( $s->get_window_handles->[0] );
}

diag "Comment on ticket";
{
    my $reply = $s->find_element(q{//a[text()='Comment']});
    $s->get_ok( $reply->get_property('href') );

    $s->find_element_ok( q{//input[@name='TxnRecipients'][@type='hidden']}, '', 'Hidden TxnRecipients' );
    $s->find_no_element_ok( q{//input[@name='TxnSendMailToAll']}, 'No TxnSendMailToAll' );

    sleep 0.5;
    $s->text_contains('On Comment Notify Other Recipients as Comment');

    $s->submit_form_ok(
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
    sleep 0.5;
    $s->text_contains('Comments added');

    $s->find_element(q{//div[contains(@class, 'transaction')]});
    $s->text_contains('this is a ticket comment');

    my $last_email = ( $s->find_elements( selector_to_xpath(q{a[href*='ShowEmailRecord.html']}) ) )[0];
    $s->scroll_to(q{a[href*='ShowEmailRecord.html']});
    $s->text_contains('RT-Send-CC: alice@example.com, bob@example.com');
    $s->text_lacks('RT-Send-BCC: richard@example.com');    # ShowBccHeader is false by default
    $last_email->click();

    $s->switch_to_window( $s->get_window_handles->[1] );
    sleep 0.5;
    $s->text_contains('CC: alice@example.com, bob@example.com');
    $s->text_contains('BCC: richard@example.com');
    $s->close;
    $s->switch_to_window( $s->get_window_handles->[0] );
}

diag "Test one-time checkboxes";
{
    my $reply = $s->find_element(q{//a[text()='Comment']});
    $s->get_ok( $reply->get_property('href') );

    $s->find_element_ok( q{//input[@name='TxnRecipients'][@type='hidden']}, '', 'Hidden TxnRecipients' );
    $s->find_no_element_ok( q{//input[@name='TxnSendMailToAll']}, 'No TxnSendMailToAll' );
    sleep 0.5;
    $s->text_contains('On Comment Notify Other Recipients as Comment');

    my $update_cc  = $s->find_element(q{//input[@name='UpdateCc']});
    my $update_bcc = $s->find_element(q{//input[@name='UpdateBcc']});

    my $update_cc_all      = $s->find_element(q{//input[@name='AllSuggestedCc']});
    my $update_cc_bob      = $s->find_element(q{//input[@name='UpdateCc-bob@example.com']});
    my $update_cc_richard  = $s->find_element(q{//input[@name='UpdateCc-richard@example.com']});
    my $update_bcc_all     = $s->find_element(q{//input[@name='AllSuggestedBcc']});
    my $update_bcc_bob     = $s->find_element(q{//input[@name='UpdateBcc-bob@example.com']});
    my $update_bcc_richard = $s->find_element(q{//input[@name='UpdateBcc-richard@example.com']});


    ok( !$update_cc_all->is_selected,      'AllSuggestedCc is not checked' );
    ok( !$update_cc_bob->is_selected,      'UpdateCc-bob@example.com is not checked' );
    ok( !$update_cc_richard->is_selected,  'UpdateCc-richard is not checked' );
    ok( !$update_bcc_all->is_selected,     'AllSuggestedBcc is not checked' );
    ok( !$update_bcc_bob->is_selected,     'UpdateBcc-bob@example.com is not checked' );
    ok( !$update_bcc_richard->is_selected, 'UpdateBcc-richard is not checked' );
    is( $update_cc->get_value,  '', 'UpdateCc is empty' );
    is( $update_bcc->get_value, '', 'UpdateBcc is empty' );

    $update_cc_all->click_ok();
    ok( $update_cc_all->is_selected, 'AllSuggestedCc is checked' );
    $update_cc          = $s->find_element(q{//input[@name='UpdateCc']});
    $update_bcc         = $s->find_element(q{//input[@name='UpdateBcc']});
    $update_cc_bob      = $s->find_element(q{//input[@name='UpdateCc-bob@example.com']});
    $update_cc_richard  = $s->find_element(q{//input[@name='UpdateCc-richard@example.com']});
    $update_bcc_all     = $s->find_element(q{//input[@name='AllSuggestedBcc']});
    $update_bcc_bob     = $s->find_element(q{//input[@name='UpdateBcc-bob@example.com']});
    $update_bcc_richard = $s->find_element(q{//input[@name='UpdateBcc-richard@example.com']});

    ok( $update_cc_bob->is_selected,       'UpdateCc-bob@example.com is checked automatically' );
    ok( $update_cc_richard->is_selected,   'UpdateCc-richard is checked automatically' );
    ok( !$update_bcc_all->is_selected,     'AllSuggestedBcc is not checked' );
    ok( !$update_bcc_bob->is_selected,     'UpdateBcc-bob@example.com is not checked' );
    ok( !$update_bcc_richard->is_selected, 'UpdateBcc-richard is not checked' );

    # There is no space after the comma on Chrome, but there is one on Firefox.
    like( $update_cc->get_value, qr/bob\@example.com,\s*richard\@example.com/, 'UpdateCc is updated automatically' );
    is( $update_bcc->get_value, '', 'UpdateBcc is empty' );

    $update_cc_bob->click_ok();
    ok( !$update_cc_bob->is_selected, 'UpdateCc-bob is not checked' );
    $update_cc          = $s->find_element(q{//input[@name='UpdateCc']});
    $update_bcc         = $s->find_element(q{//input[@name='UpdateBcc']});
    $update_cc_all      = $s->find_element(q{//input[@name='AllSuggestedCc']});
    $update_cc_richard  = $s->find_element(q{//input[@name='UpdateCc-richard@example.com']});
    $update_bcc_all     = $s->find_element(q{//input[@name='AllSuggestedBcc']});
    $update_bcc_bob     = $s->find_element(q{//input[@name='UpdateBcc-bob@example.com']});
    $update_bcc_richard = $s->find_element(q{//input[@name='UpdateBcc-richard@example.com']});

    ok( $update_cc_richard->is_selected,   'UpdateCc-richard@example.com is checked' );
    ok( !$update_cc_all->is_selected,      'AllSuggestedCc is not checked automatically' );
    ok( !$update_bcc_all->is_selected,     'AllSuggestedBcc is not checked' );
    ok( !$update_bcc_bob->is_selected,     'UpdateBcc-bob@example.com is not checked' );
    ok( !$update_bcc_richard->is_selected, 'UpdateBcc-richard is not checked' );

    is( $update_cc->get_value,  'richard@example.com', 'UpdateCc is updated automatically' );
    is( $update_bcc->get_value, '',                    'UpdateBcc is empty' );

    $update_bcc_bob->click_ok();
    ok( $update_bcc_bob->is_selected, 'UpdateCc-bob is checked' );
    $update_cc          = $s->find_element(q{//input[@name='UpdateCc']});
    $update_bcc         = $s->find_element(q{//input[@name='UpdateBcc']});
    $update_cc_all      = $s->find_element(q{//input[@name='AllSuggestedCc']});
    $update_cc_bob      = $s->find_element(q{//input[@name='UpdateCc-bob@example.com']});
    $update_cc_richard  = $s->find_element(q{//input[@name='UpdateCc-richard@example.com']});
    $update_bcc_all     = $s->find_element(q{//input[@name='AllSuggestedBcc']});
    $update_bcc_richard = $s->find_element(q{//input[@name='UpdateBcc-richard@example.com']});

    ok( !$update_cc_bob->is_selected,      'UpdateCc-richard@example.com is not checked' );
    ok( $update_cc_richard->is_selected,   'UpdateCc-richard@example.com is checked' );
    ok( !$update_cc_all->is_selected,      'AllSuggestedCc is not checked automatically' );
    ok( !$update_bcc_all->is_selected,     'AllSuggestedBcc is not checked' );
    ok( !$update_bcc_richard->is_selected, 'UpdateBcc-richard is not checked' );

    is( $update_cc->get_value,  'richard@example.com', 'UpdateCc is updated automatically' );
    is( $update_bcc->get_value, 'bob@example.com',     'UpdateBcc is updated' );

    $update_bcc_richard->click_ok();
    ok( $update_bcc_richard->is_selected, 'UpdateCc-richard is checked' );
    $update_cc         = $s->find_element(q{//input[@name='UpdateCc']});
    $update_bcc        = $s->find_element(q{//input[@name='UpdateBcc']});
    $update_cc_all     = $s->find_element(q{//input[@name='AllSuggestedCc']});
    $update_cc_bob     = $s->find_element(q{//input[@name='UpdateCc-bob@example.com']});
    $update_cc_richard = $s->find_element(q{//input[@name='UpdateCc-richard@example.com']});
    $update_bcc_all    = $s->find_element(q{//input[@name='AllSuggestedBcc']});
    $update_bcc_bob    = $s->find_element(q{//input[@name='UpdateBcc-bob@example.com']});

    ok( !$update_cc_bob->is_selected,    'UpdateCc-bob@example.com is not checked' );
    ok( $update_cc_richard->is_selected, 'UpdateCc-richard@example.com is checked' );
    ok( !$update_cc_all->is_selected,    'AllSuggestedCc is not checked automatically' );
    ok( $update_bcc_all->is_selected,    'AllSuggestedBcc is checked automatically' );
    ok( $update_bcc_bob->is_selected,    'UpdateBcc-bob is checked' );

    is( $update_cc->get_value, 'richard@example.com', 'UpdateCc is updated automatically' );
    like( $update_bcc->get_value, qr/bob\@example.com,\s*richard\@example.com/, 'UpdateBcc is updated' );

    sleep 2;    # Firefox fails sometimes if there is no wait
    $s->submit_form_ok(
        {
            form_name => 'TicketUpdate',
            fields    => {
                UpdateContent => 'this is another ticket comment',
            },
            button => 'SubmitTicket',
        },
        'Reply ticket'
    );
    $s->text_contains('Comments added');

    $s->find_element(q{//div[contains(@class, 'transaction')]});
    $s->text_contains('this is another ticket comment');

    my $last_email = ( $s->find_elements(q{//a[contains(@href, 'ShowEmailRecord.html')]}) )[0];
    $s->scroll_to(q{a[href*='ShowEmailRecord.html']});
    $s->text_contains('RT-Send-CC: richard@example.com');
    $s->text_lacks('RT-Send-BCC: bob@example.com');    # ShowBccHeader is false by default
    $last_email->click();

    $s->switch_to_window( $s->get_window_handles->[1] );
    sleep 0.5;
    $s->text_contains('CC: richard@example.com');
    $s->text_contains('BCC: bob@example.com, richard@example.com');
    $s->close;
    $s->switch_to_window( $s->get_window_handles->[0] );
}

$s->get_ok('/Prefs/Other.html');
$s->submit_form_ok(
    {
        form_name => 'ModifyPreferences',
        fields    => { 'SimplifiedRecipients' => 1 },
        button    => 'Update',
    },
    'Set SimplifiedRecipients'
);

$s->text_contains('Preferences saved');

$s->goto_ticket(1);

diag "Test simplied recipients";
{
    my $reply = ($s->find_elements(q{//a[text()='Reply']}))[0];
    $s->get_ok( $reply->get_property('href') );

    $s->find_element_ok( q{//input[@name='TxnRecipients'][@type='hidden']}, '', 'Hidden TxnRecipients' );
    # Use 2 find_element to implicit wait for the 2 ajax requests of preview scrips
    my @send_all = (
        $s->find_element(q{//input[@name='TxnSendMailToAll'][@id='TxnSendMailToAll-Simplified']}),
        $s->find_element(q{//input[@name='TxnSendMailToAll'][@id='TxnSendMailToAll']}),
    );
    is( @send_all, 2, '2 TxnSendMailToAll inputs' );
    for my $send_all (@send_all) {
        ok( $send_all->is_selected, 'TxnSendMailToAll is checked' );
    }

    my @send_alice = $s->find_elements(q{//input[@name='TxnSendMailTo'][@value='alice@example.com']});
    is( @send_alice, 2, '2 TxnSendMailTo alice inputs' );
    for my $send_alice (@send_alice) {
        ok( $send_alice->is_selected, 'TxnSendMailTo alice is checked' );
    }

    $send_alice[0]->click();
    @send_alice = $s->find_elements(q{//input[@name='TxnSendMailTo'][@value='alice@example.com']});
    for my $send_alice (@send_alice) {
        ok( !$send_alice->is_selected, 'TxnSendMailTo alice is not checked' );
    }
    @send_all = $s->find_elements(q{//input[@name='TxnSendMailToAll']});
    is( @send_all, 2, '2 TxnSendMailToAll inputs' );
    for my $send_all (@send_all) {
        ok( !$send_all->is_selected, 'TxnSendMailToAll is not checked automatically' );
    }

    $send_alice[0]->click();
    @send_alice = $s->find_elements(q{//input[@name='TxnSendMailTo'][@value='alice@example.com']});
    for my $send_alice (@send_alice) {
        ok( $send_alice->is_selected, 'TxnSendMailTo alice is checked again' );
    }
    @send_all = $s->find_elements(q{//input[@name='TxnSendMailToAll']});
    for my $send_all (@send_all) {
        ok( $send_all->is_selected, 'TxnSendMailToAll is checked automatically' );
    }

    $send_all[0]->click();
    @send_all = $s->find_elements(q{//input[@name='TxnSendMailToAll']});
    for my $send_all (@send_all) {
        ok( !$send_all->is_selected, 'TxnSendMailToAll is not checked' );
    }
    @send_alice = $s->find_elements(q{//input[@name='TxnSendMailTo'][@value='alice@example.com']});
    for my $send_alice (@send_alice) {
        ok( !$send_alice->is_selected, 'TxnSendMailTo alice is not checked automatically' );
    }

    $send_all[0]->click();
    @send_all = $s->find_elements(q{//input[@name='TxnSendMailToAll']});
    for my $send_all (@send_all) {
        ok( $send_all->is_selected, 'TxnSendMailToAll is checked' );
    }
    @send_alice = $s->find_elements(q{//input[@name='TxnSendMailTo'][@value='alice@example.com']});
    for my $send_alice (@send_alice) {
        ok( $send_alice->is_selected, 'TxnSendMailTo alice is checked automatically' );
    }

    sleep 2;    # Firefox fails sometimes if there is no wait
    $s->submit_form_ok(
        {
            form_name => 'TicketUpdate',
            fields    => {
                UpdateContent => 'this is another ticket update',
            },
            button => 'SubmitTicket',
        },
        'Reply ticket'
    );
    $s->text_contains('Correspondence added');

    $s->find_element(q{//div[contains(@class, 'transaction')]});
    $s->text_contains('this is another ticket update');

    my $last_email = ($s->find_elements( selector_to_xpath(q{a[href*='ShowEmailRecord.html']}) ))[0];
    $s->scroll_to(q{a[href*='ShowEmailRecord.html']});

    $last_email->click();
    $s->switch_to_window( $s->get_window_handles->[1] );
    sleep 0.1;
    $s->text_contains('CC: alice@example.com');
    $s->close;
    $s->switch_to_window( $s->get_window_handles->[0] );
}

$s->logout;

done_testing;
