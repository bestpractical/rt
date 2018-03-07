use strict;
use warnings;

use RT::Test tests => undef;

my $lifecycles = RT->Config->Get('Lifecycles');
$lifecycles->{foo} = {
    initial  => ['initial'],
    active   => ['open'],
    inactive => ['resolved'],

};

# explicitly Set so RT::Test can catch our change
RT->Config->Set( Lifecycles => %$lifecycles );

RT::Lifecycle->FillCache();

my $general = RT::Test->load_or_create_queue( Name => 'General' );
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

my $root = RT::Test->load_or_create_user( Name => 'root', );
my $user_a = RT::Test->load_or_create_user(
    Name     => 'user_a',
    Password => 'password',
);
my $user_b = RT::Test->load_or_create_user(
    Name     => 'user_b',
    Password => 'password',
);

ok(
    RT::Test->set_rights(
        {
            Principal => $user_a,
            Object    => $general,
            Right     => ['OwnTicket'],
        },
        {
            Principal => $user_b,
            Object    => $foo,
            Right     => ['OwnTicket'],
        },
    ),
    'granted OwnTicket right for user_a and user_b'
);

my ( $url, $m ) = RT::Test->started_ok;
ok( $m->login, 'logged in' );

$m->get_ok( $url . '/Search/Build.html' );

diag "check default statuses, cf and owners";
my $form = $m->form_name('BuildQuery');
ok( $form,                                     'found BuildQuery form' );
ok( $form->find_input("ValueOfCF.{global_cf}"), 'found global_cf by default' );
ok( !$form->find_input("ValueOfCF.{general_cf}"), 'no general_cf by default' );
ok( !$form->find_input("ValueOfCF.{foo_cf}"), 'no foo_cf by default' );

my $status_input = $form->find_input('ValueOfStatus');
my @statuses     = sort $status_input->possible_values;
is_deeply(
    \@statuses, [ '', qw/__Active__ __Inactive__ initial new open open rejected resolved resolved stalled/], 'found all statuses'
) or diag "Statuses are: ", explain \@statuses;

my $owner_input = $form->find_input('ValueOfActor');
my @owners     = sort $owner_input->possible_values;
is_deeply(
    \@owners, [ '', qw/Nobody root user_a user_b/], 'found all users'
);

diag "limit queue to foo";
$m->submit_form(
    fields => { ValueOfQueue => 'foo', QueueOp => '=' },
    button => 'AddClause',
);

$form = $m->form_name('BuildQuery');
ok( $form->find_input("ValueOfCF.{foo_cf}"), 'found foo_cf' );
ok( $form->find_input("ValueOfCF.{global_cf}"), 'found global_cf' );
ok( !$form->find_input("ValueOfCF.{general_cf}"), 'still no general_cf' );
$status_input = $form->find_input('ValueOfStatus');
@statuses     = sort $status_input->possible_values;
is_deeply(
    \@statuses,
    [ '', qw/__Active__ __Inactive__ initial open resolved/ ],
    'found statuses from foo only'
);

$owner_input = $form->find_input('ValueOfActor');
@owners     = sort $owner_input->possible_values;
is_deeply(
    \@owners, [ '', qw/Nobody root user_b/], 'no user_a'
);

diag "limit queue to general too";

$m->submit_form(
    fields => { ValueOfQueue => 'General', QueueOp => '=' },
    button => 'AddClause',
);

$form = $m->form_name('BuildQuery');
ok( $form->find_input("ValueOfCF.{general_cf}"), 'found general_cf' );
ok( $form->find_input("ValueOfCF.{foo_cf}"), 'found foo_cf' );
ok( $form->find_input("ValueOfCF.{global_cf}"), 'found global_cf' );
$status_input = $form->find_input('ValueOfStatus');
@statuses     = sort $status_input->possible_values;
is_deeply(
    \@statuses,
    [ '', qw/__Active__ __Inactive__ initial new open open rejected resolved resolved stalled/ ],
    'found all statuses again'
) or diag "Statuses are: ", explain \@statuses;
$owner_input = $form->find_input('ValueOfActor');
@owners     = sort $owner_input->possible_values;
is_deeply(
    \@owners, [ '', qw/Nobody root user_a user_b/], 'found all users again'
);

diag "limit queue to != foo";
$m->get_ok( $url . '/Search/Build.html?NewQuery=1' );
$m->submit_form(
    form_name => 'BuildQuery',
    fields => { ValueOfQueue => 'foo', QueueOp => '!=' },
    button => 'AddClause',
);

$form = $m->form_name('BuildQuery');
ok( $form->find_input("ValueOfCF.{global_cf}"), 'found global_cf' );
ok( !$form->find_input("ValueOfCF.{foo_cf}"), 'no foo_cf' );
ok( !$form->find_input("ValueOfCF.{general_cf}"), 'no general_cf' );
$status_input = $form->find_input('ValueOfStatus');
@statuses     = sort $status_input->possible_values;
is_deeply(
    \@statuses, [ '', qw/__Active__ __Inactive__ initial new open open rejected resolved resolved stalled/],
    'found all statuses'
) or diag "Statuses are: ", explain \@statuses;
$owner_input = $form->find_input('ValueOfActor');
@owners     = sort $owner_input->possible_values;
is_deeply(
    \@owners, [ '', qw/Nobody root user_a user_b/], 'found all users'
);

diag "limit queue to General OR foo";
$m->get_ok( $url . '/Search/Edit.html' );
$m->submit_form(
    form_name => 'BuildQueryAdvanced',
    fields => { Query => q{Queue = 'General' OR Queue = 'foo'} },
);
$form = $m->form_name('BuildQuery');
ok( $form->find_input("ValueOfCF.{general_cf}"), 'found general_cf' );
ok( $form->find_input("ValueOfCF.{foo_cf}"), 'found foo_cf' );
ok( $form->find_input("ValueOfCF.{global_cf}"), 'found global_cf' );
$status_input = $form->find_input('ValueOfStatus');
@statuses     = sort $status_input->possible_values;
is_deeply(
    \@statuses,
    [ '', qw/__Active__ __Inactive__ initial new open open rejected resolved resolved stalled/ ],
    'found all statuses'
) or diag "Statuses are: ", explain \@statuses;
$owner_input = $form->find_input('ValueOfActor');
@owners     = sort $owner_input->possible_values;
is_deeply(
    \@owners, [ '', qw/Nobody root user_a user_b/], 'found all users'
);

done_testing;
