use strict;
use warnings;

use RT::Test tests => 28;

my $lifecycles = RT->Config->Get('Lifecycles');
$lifecycles->{foo} = {
    initial  => ['initial'],
    active   => ['open'],
    inactive => ['resolved'],

};

RT::Lifecycle->FillCache();

my $foo = RT::Test->load_or_create_queue( Name => 'foo', Lifecycle => 'foo' );

my $global_cf = RT::Test->load_or_create_custom_field(
    Name  => 'global_cf',
    Queue => 0,
    Type  => 'FreeformSingle',
);

my $general_cf = RT::Test->load_or_create_custom_field(
    Name  => 'general_cf',
    Queue => 'General',
    Type  => 'FreeformSingle',
);

my $foo_cf = RT::Test->load_or_create_custom_field(
    Name  => 'foo_cf',
    Queue => 'foo',
    Type  => 'FreeformSingle'
);

my ( $url, $m ) = RT::Test->started_ok;
ok( $m->login, 'logged in' );

$m->get_ok( $url . '/Search/Build.html' );

diag "check default statuses and cf";
my $form = $m->form_name('BuildQuery');
ok( $form,                                     'found BuildQuery form' );
ok( $form->find_input("ValueOf'CF.{global_cf}'"), 'found global_cf by default' );
ok( !$form->find_input("ValueOf'CF.{general_cf}'"), 'no general_cf by default' );
ok( !$form->find_input("ValueOf'CF.{foo_cf}'"), 'no foo_cf by default' );

my $status_input = $form->find_input('ValueOfStatus');
my @statuses     = sort $status_input->possible_values;
is_deeply(
    \@statuses, [ '', qw/initial new open rejected resolved stalled/], 'found all statuses'
);

diag "limit queue to foo";
$m->submit_form(
    fields => { ValueOfQueue => 'foo' },
    button => 'AddClause',
);

$form = $m->form_name('BuildQuery');
ok( $form->find_input("ValueOf'CF.{foo_cf}'"), 'found foo_cf' );
ok( $form->find_input("ValueOf'CF.{global_cf}'"), 'found global_cf' );
ok( !$form->find_input("ValueOf'CF.{general_cf}'"), 'still no general_cf' );
$status_input = $form->find_input('ValueOfStatus');
@statuses     = sort $status_input->possible_values;
is_deeply(
    \@statuses,
    [ '', qw/initial open resolved/ ],
    'found statuses from foo only'
);

diag "limit queue to general too";

$m->submit_form(
    fields => { ValueOfQueue => 'General' },
    button => 'AddClause',
);

$form = $m->form_name('BuildQuery');
ok( $form->find_input("ValueOf'CF.{general_cf}'"), 'found general_cf' );
ok( $form->find_input("ValueOf'CF.{foo_cf}'"), 'found foo_cf' );
ok( $form->find_input("ValueOf'CF.{global_cf}'"), 'found global_cf' );
$status_input = $form->find_input('ValueOfStatus');
@statuses     = sort $status_input->possible_values;
is_deeply(
    \@statuses,
    [ '', qw/initial new open rejected resolved stalled/ ],
    'found all statuses again'
);

diag "limit queue to != foo";
$m->get_ok( $url . '/Search/Build.html?NewQuery=1' );
$m->submit_form(
    form_name => 'BuildQuery',
    fields => { ValueOfQueue => 'foo', QueueOp => '!=' },
    button => 'AddClause',
);

$form = $m->form_name('BuildQuery');
ok( $form->find_input("ValueOf'CF.{global_cf}'"), 'found global_cf' );
ok( !$form->find_input("ValueOf'CF.{foo_cf}'"), 'no foo_cf' );
ok( !$form->find_input("ValueOf'CF.{general_cf}'"), 'no general_cf' );
$status_input = $form->find_input('ValueOfStatus');
@statuses     = sort $status_input->possible_values;
is_deeply(
    \@statuses, [ '', qw/initial new open rejected resolved stalled/],
    'found all statuses'
);

diag "limit queue to General OR foo";
$m->get_ok( $url . '/Search/Edit.html' );
$m->submit_form(
    form_name => 'BuildQueryAdvanced',
    fields => { Query => q{Queue = 'General' OR Queue = 'foo'} },
);
$form = $m->form_name('BuildQuery');
ok( $form->find_input("ValueOf'CF.{general_cf}'"), 'found general_cf' );
ok( $form->find_input("ValueOf'CF.{foo_cf}'"), 'found foo_cf' );
ok( $form->find_input("ValueOf'CF.{global_cf}'"), 'found global_cf' );
$status_input = $form->find_input('ValueOfStatus');
@statuses     = sort $status_input->possible_values;
is_deeply(
    \@statuses,
    [ '', qw/initial new open rejected resolved stalled/ ],
    'found all statuses'
);
