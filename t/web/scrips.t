use strict;
use warnings;

use RT::Test tests => undef;
use Test::Warn;

RT->Config->Set( UseTransactionBatch => 1 );

# TODO:
# Test the rest of the conditions.
# Test actions.
# Test templates?
# Test cleanup scripts.

my $queue_g = RT::Test->load_or_create_queue( Name => 'General' );
ok $queue_g && $queue_g->id, 'loaded or created queue';

my $queue_r = RT::Test->load_or_create_queue( Name => 'Regression' );
ok $queue_r && $queue_r->id, 'loaded or created queue';

my ($baseurl, $m) = RT::Test->started_ok;
ok $m->login, "logged in";

$m->follow_link_ok({id => 'admin-global-scrips-tickets-create'});

sub prepare_code_with_value {
    my $value = shift;

    # changing the ticket is an easy scrip check for a test
    return
        '$self->TicketObj->SetSubject(' .
        '$self->TicketObj->Subject . ' .
        '"|" . ' . $value .
        ')';
}

{
    # preserve order for checking the subject string later
    my @values_for_actions;

    my $conds = RT::ScripConditions->new(RT->SystemUser);
    foreach my $cond_value ('On Forward', 'On Forward Ticket', 'On Forward Transaction') {
        $conds->Limit(
            FIELD           => 'name',
            VALUE           => $cond_value,
            ENTRYAGGREGATOR => 'OR',
        );
    }

    while (my $rec = $conds->Next) {
        push @values_for_actions, [$rec->Id, '"' . $rec->Name . '"'];
    }

    @values_for_actions = sort { $a->[0] cmp $b->[0] } @values_for_actions;

    foreach my $data (@values_for_actions) {
        my ($condition, $prepare_code_value) = @$data;
        diag "Create Scrip (Cond #$condition)" if $ENV{TEST_VERBOSE};
        $m->follow_link_ok({id => 'admin-global-scrips-tickets-create'});
        my $prepare_code = prepare_code_with_value($prepare_code_value);
        $m->form_name('CreateScrip');
        $m->set_fields(
            'ScripCondition'    => $condition,
            'ScripAction'       => 'User Defined',
            'Template'          => 'Blank',
            'CustomPrepareCode' => $prepare_code,
        );
        $m->click('Create');
        $m->content_like(qr{Scrip Created});
    }

    my $ticket_obj = RT::Test->create_ticket(
        Subject => 'subject',
        Content => 'stuff',
        Queue   => 1,
    );
    my $ticket = $ticket_obj->id;
    $m->goto_ticket($ticket);

    $m->follow_link_ok(
        { id => 'page-actions-forward' },
        'follow 1st Forward to forward ticket'
    );

    diag "Forward Ticket" if $ENV{TEST_VERBOSE};
    $m->submit_form(
        form_name => 'ForwardMessage',
        fields    => {
            To => 'rt-test@example.com, rt-to@example.com',
        },
        button => 'ForwardAndReturn'
    );

    $m->text_contains("#${ticket}: subject|On Forward|On Forward Ticket");

    diag "Forward Transaction" if $ENV{TEST_VERBOSE};
    # get the first transaction on the ticket
    my ($transaction) = $ticket_obj->Transactions->First->id;
    $m->get(
        "$baseurl/Ticket/Forward.html?id=1&QuoteTransaction=$transaction"
    );
    $m->submit_form(
        form_name => 'ForwardMessage',
        fields    => {
            To => 'rt-test@example.com, rt-to@example.com',
        },
        button => 'ForwardAndReturn'
    );

    $m->text_contains("#${ticket}: subject|On Forward|On Forward Ticket|On Forward|On Forward Transaction");

    RT::Test->clean_caught_mails;
}

note "check basics in scrip's admin interface";
{
    $m->follow_link_ok( { id => 'admin-global-scrips-tickets-create' } );
    ok $m->form_name('CreateScrip');
    is $m->value_name('Description'), '', 'empty value';
    is $m->value_name('ScripAction'), '-', 'empty value';
    is $m->value_name('ScripCondition'), '-', 'empty value';
    is $m->value_name('Template'), '-', 'empty value';
    $m->field('Description' => 'test');
    $m->click('Create');
    $m->content_contains("Action is mandatory argument");

    ok $m->form_name('CreateScrip');
    is $m->value_name('Description'), 'test', 'value stays on the page';
    $m->select('ScripAction' => 'Notify Ccs');
    $m->click('Create');
    $m->content_contains("Template is mandatory argument");

    ok $m->form_name('CreateScrip');
    is $m->value_name('Description'), 'test', 'value stays on the page';
    is $m->value_name('ScripAction'), 'Notify Ccs', 'value stays on the page';
    $m->select('Template' => 'Blank');
    $m->click('Create');
    $m->content_contains("Condition is mandatory argument");

    ok $m->form_name('CreateScrip');
    is $m->value_name('Description'), 'test', 'value stays on the page';
    is $m->value_name('ScripAction'), 'Notify Ccs', 'value stays on the page';
    $m->select('ScripCondition' => 'On Close');
    $m->click('Create');
    $m->content_contains("Scrip Created");

    ok $m->form_name('ModifyScrip');
    is $m->value_name('Description'), 'test', 'correct value';
    is $m->value_name('ScripCondition'), 'On Close', 'correct value';
    is $m->value_name('ScripAction'), 'Notify Ccs', 'correct value';
    is $m->value_name('Template'), 'Blank', 'correct value';
    $m->field('Description' => 'test test');
    $m->click('Update');
    # regression
    $m->content_lacks("Template is mandatory argument");

    ok $m->form_name('ModifyScrip');
    is $m->value_name('Description'), 'test test', 'correct value';
    $m->content_contains("Description changed from", "found action result message");
}

note "check application in admin interface";
{
    $m->follow_link_ok({ id => 'admin-global-scrips-tickets-create' });
    $m->submit_form_ok({
        with_fields => {
            Description     => "testing application",
            ScripCondition  => "On Create",
            ScripAction     => "Open Tickets",
            Template        => "Blank",
        },
        button => 'Create',
    }, "created scrip");
    $m->content_contains("Scrip Created", "found result message");

    my ($sid) = ($m->content =~ /Modify scrip #(\d+)/);
    ok $sid, "found scrip id on the page";
    RT::Test->object_scrips_are($sid, [0]);

    $m->follow_link_ok({ id => 'page-applies-to' });
    ok $m->form_name("AddRemoveScrip"), "found form";
    $m->tick("RemoveScrip-$sid", 0);
    $m->click_ok("Update", "update scrip application");
    RT::Test->object_scrips_are($sid, []);

    ok $m->form_name("AddRemoveScrip"), "found form";
    $m->tick("AddScrip-$sid", 0);
    $m->tick("AddScrip-$sid", $queue_g->id);
    $m->click_ok("Update", "update scrip application");
    RT::Test->object_scrips_are($sid, [0], [$queue_g->id, $queue_r->id]);
}

note "check templates in scrip's admin interface";
{
    my $template = RT::Template->new( RT->SystemUser );
    my ($status, $msg) = $template->Create( Queue => $queue_g->id, Name => 'foo' );
    ok $status, 'created a template';

    my $templates = RT::Templates->new( RT->SystemUser );
    $templates->LimitToGlobal;

    my @default = (
          '',
          map $_->Name, @{$templates->ItemsArrayRef}
    );

    $m->follow_link_ok( { id => 'admin-global-scrips-tickets-create' } );
    ok $m->form_name('CreateScrip');
    my @templates = ($m->find_all_inputs( type => 'option', name => 'Template' ))[0]
        ->possible_values;
    is_deeply([sort @templates], [sort @default]);

    $m->follow_link_ok( { id => 'admin-queues' } );
    $m->follow_link_ok( { text => 'General' } );
    $m->follow_link_ok( { id => 'page-settings-scrips-create' } );

    ok $m->form_name('CreateScrip');
    @templates = ($m->find_all_inputs( type => 'option', name => 'Template' ))[0]
        ->possible_values;
    is_deeply([sort @templates], [sort @default, 'foo']);

note "make sure we can not apply scrip to queue without required template";
    $m->field('Description' => 'test template');
    $m->select('ScripCondition' => 'On Close');
    $m->select('ScripAction' => 'Notify Ccs');
    $m->select('Template' => 'foo');
    $m->click('Create');
    $m->content_contains("Scrip Created");

    $m->follow_link_ok( { id => 'page-applies-to' } );
    my ($id) = ($m->content =~ /Modify associated queues for scrip #(\d+)/);
    $m->form_name('AddRemoveScrip');
    $m->tick('AddScrip-'.$id, $queue_r->id);
    $m->click('Update');
    $m->content_like(qr{No template foo in queue Regression or global});

note "unapply the scrip from any queue";
    $m->form_name('AddRemoveScrip');
    $m->tick('RemoveScrip-'.$id, $queue_g->id);
    $m->click('Update');
    $m->content_like(qr{Object deleted});

note "you can pick any template";
    $m->follow_link_ok( { id => 'page-basics' } );
    ok $m->form_name('ModifyScrip');
    @templates = ($m->find_all_inputs( type => 'option', name => 'Template' ))[0]
        ->possible_values;
    is_deeply(
        [sort @templates],
        [sort do {
            my $t = RT::Templates->new( RT->SystemUser );
            $t->UnLimit;
            ('', $t->DistinctFieldValues('Name'))
        }],
    );

note "go to apply page and apply with template change";
    $m->follow_link_ok( { id => 'page-applies-to' } );
    $m->form_name('AddRemoveScrip');
    $m->field('Template' => 'blank');
    $m->tick('AddScrip-'.$id, $queue_g->id);
    $m->tick('AddScrip-'.$id, $queue_r->id);
    $m->click('Update');
    $m->content_contains("Template: Template changed from ");
    $m->content_contains("Object created");
}

note "apply scrip in different stage to different queues";
{
    $m->follow_link_ok( { id => 'admin-queues' } );
    $m->follow_link_ok( { text => 'General' } );
    $m->follow_link_ok( { id => 'page-settings-scrips-create'});

    ok $m->form_name('CreateScrip');
    $m->field('Description' => 'test stage');
    $m->select('ScripCondition' => 'On Close');
    $m->select('ScripAction' => 'Notify Ccs');
    $m->select('Template' => 'Blank');
    $m->click('Create');
    $m->content_contains("Scrip Created");

    my ($sid) = ($m->content =~ /Modify scrip #(\d+)/);
    ok $sid, "found scrip id on the page";

    $m->follow_link_ok({ text => 'Applies to' });
    ok $m->form_name('AddRemoveScrip');
    $m->select('Stage' => 'Batch');
    $m->tick( "AddScrip-$sid" => $queue_r->id );
    $m->click('Update');
    $m->content_contains("Object created");

    $m->follow_link_ok({ text => 'General' });
    $m->follow_link_ok({ id => 'page-settings-scrips' });

    my (@matches) = $m->content =~ /test stage/g;
    # regression
    is scalar @matches, 1, 'scrip mentioned only once';
}

note "test scrip logging";
{
    my $logdir = RT->Config->Get('LogDir') || File::Spec->catdir( $RT::VarPath, 'log' );
    $logdir    = File::Spec->catdir( $logdir, 'scrips' );

    my %test_scrips = (
        'No Errors'          => [ 'return 1;',          'return 1;',          'return 1;' ],
        'IsApplicable Error' => [ 'return $undefined;', 'return 1;',          'return 1;' ],
        'Prepare Error'      => [ 'return 1;',          'return $undefined;', 'return 1;' ],
        'Commit Error'       => [ 'return 1;',          'return 1;',          'return $undefined;' ],
    );
    my %test_scrip_logfile_should_exist = (
        'No Errors'          => { IsApplicable => 0, Prepare => 0, Commit => 0, },
        'IsApplicable Error' => { IsApplicable => 1, Prepare => 0, Commit => 0, },
        'Prepare Error'      => { IsApplicable => 0, Prepare => 1, Commit => 0, },
        'Commit Error'       => { IsApplicable => 0, Prepare => 0, Commit => 1, },
    );

    my %id_for_scrip;
    foreach my $test_scrip ( sort keys %test_scrips  ) {
        diag "Create Scrip (Test Scrip Logging - $test_scrip)" if $ENV{TEST_VERBOSE};
        $m->follow_link_ok({id => 'admin-global-scrips-tickets-create'});
        $m->form_name('CreateScrip');
        $m->set_fields(
            'Description'            => "Test Scrip Logging - $test_scrip",
            'ScripCondition'         => 'User Defined',
            'ScripAction'            => 'User Defined',
            'Template'               => 'Blank',
            'CustomIsApplicableCode' => $test_scrips{$test_scrip}->[0],
            'CustomPrepareCode'      => $test_scrips{$test_scrip}->[1],
            'CustomCommitCode'       => $test_scrips{$test_scrip}->[2],
        );
        $m->click('Create');
        $m->content_like(qr{Scrip Created});

        my ($sid) = ($m->content =~ /Modify scrip #(\d+)/);
        ok $sid, "found scrip id on the page";

        $id_for_scrip{$test_scrip} = $sid;
    }

    # creating a ticket should fire off all test scrips
    diag "Create Ticket (Test Scrip Logging No Config)" if $ENV{TEST_VERBOSE};
    warnings_like {
        RT::Test->create_ticket(
            Subject => 'Test Scrip Logging',
            Content => 'stuff',
            Queue   => 1,
        );
    } [ qr/Global symbol .* requires explicit package name/,
        qr/Global symbol .* requires explicit package name/,
        qr/Global symbol .* requires explicit package name/,
        qr/Global symbol .* requires explicit package name/,
        qr/Global symbol .* requires explicit package name/,
        qr/Global symbol .* requires explicit package name/,
      ];

    # without any config specified there should be no log files
    foreach my $test_scrip ( sort keys %id_for_scrip  ) {
        foreach my $mode ( qw( IsApplicable Prepare Commit ) ) {
            my $filename = 'scrip-' . $id_for_scrip{$test_scrip} . '-' . $mode . '.log';
            my $fullpath = File::Spec->catfile( $logdir, $filename );

            ok ! -e $fullpath, "Scrip log file '$filename' should not exist";
        }
    }

    # now set config and create another ticket
    # need to stop server, change config, restart server
    # to avoid warning about changing config with running server
    RT::Test->stop_server;
    RT->Config->Set( LogScripsForUser => { root => 'warn', RT_System => 'warn' } );
    ( $baseurl, $m ) = RT::Test->started_ok;
    ok( $m->login(), 'logged in' );

    diag "Create Ticket (Test Scrip Logging With Config)" if $ENV{TEST_VERBOSE};
    warnings_like {
        RT::Test->create_ticket(
            Subject => 'Test Scrip Logging',
            Content => 'stuff',
            Queue   => 1,
        );
    } [ qr/Global symbol .* requires explicit package name/,
        qr/Global symbol .* requires explicit package name/,
        qr/Global symbol .* requires explicit package name/,
        qr/Global symbol .* requires explicit package name/,
        qr/Global symbol .* requires explicit package name/,
        qr/Global symbol .* requires explicit package name/,
      ];

    foreach my $test_scrip ( sort keys %id_for_scrip  ) {
        foreach my $mode ( qw( IsApplicable Prepare Commit ) ) {
            my $filename = 'scrip-' . $id_for_scrip{$test_scrip} . '-' . $mode . '.log';
            my $fullpath = File::Spec->catfile( $logdir, $filename );

            if ( $test_scrip_logfile_should_exist{$test_scrip}->{$mode} ) {
                ok -e $fullpath, "Scrip log file '$filename' should exist";
            } else {
                ok ! -e $fullpath, "Scrip log file '$filename' should not exist";
            }
        }
    }
}

done_testing;
