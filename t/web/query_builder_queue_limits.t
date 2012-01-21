use strict;
use warnings;

use RT::Test tests => 22;

my $lifecycles = RT->Config->Get('Lifecycles');
$lifecycles->{foo} = {
    initial  => ['initial'],
    active   => ['open'],
    inactive => ['resolved'],

};

RT::Lifecycle->FillCache();

my $foo = RT::Queue->new($RT::SystemUser);
my ( $id, $msg ) = $foo->Create( Name => 'foo', Lifecycle => 'foo' );
ok( $id, 'created queue foo' );

my $global_cf = RT::CustomField->new($RT::SystemUser);
( $id, $msg ) = $global_cf->Create(
    Name  => 'global_cf',
    Queue => 0,
    Type  => 'FreeformSingle',
);
ok( $id, 'create global_cf' );

my $general_cf = RT::CustomField->new($RT::SystemUser);
( $id, $msg ) = $general_cf->Create(
    Name  => 'general_cf',
    Queue => 'General',
    Type  => 'FreeformSingle',
);
ok( $id, 'create general_cf' );

my $foo_cf = RT::CustomField->new($RT::SystemUser);
( $id, $msg ) = $foo_cf->Create(
    Name  => 'foo_cf',
    Queue => 'foo',
    Type  => 'FreeformSingle'
);
ok( $id, 'create foo_cf' );

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

