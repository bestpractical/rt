use strict;
use warnings;

use RT::Test tests => 13;

my $lifecycles = RT->Config->Get('Lifecycles');
RT->Config->Set( Lifecycles => %{$lifecycles},
                 foo => {
                     initial  => ['initial'],
                     active   => ['open'],
                     inactive => ['resolved'],
                 }
);

RT::Lifecycle->FillCache();

my ( $url, $m ) = RT::Test->started_ok;
ok( $m->login(), 'logged in' );

$m->get_ok( $url . '/Admin/Queues/Modify.html?id=1' );

my $form            = $m->form_name('ModifyQueue');
my $lifecycle_input = $form->find_input('Lifecycle');
is( $lifecycle_input->value, 'default', 'default lifecycle' );

my @lifecycles = sort $lifecycle_input->possible_values;
is_deeply( \@lifecycles, [qw/default foo/], 'found all lifecycles' );

$m->submit_form();
$m->content_lacks( 'Lifecycle changed from',
    'no message of "Lifecycle changed from"' );
$m->content_lacks( 'That is already the current value',
    'no message of "That is already the current value"' );

$form = $m->form_name('ModifyQueue');
$m->submit_form( fields => { Lifecycle => 'foo' }, );
$m->content_contains(
    'Lifecycle changed from &#34;default&#34; to &#34;foo&#34;');
$lifecycle_input = $form->find_input('Lifecycle');
is( $lifecycle_input->value, 'foo', 'lifecycle is changed to foo' );

$form = $m->form_name('ModifyQueue');
$m->submit_form( fields => { Lifecycle => 'default' }, );
$m->content_contains(
    'Lifecycle changed from &#34;foo&#34; to &#34;default&#34;');
$lifecycle_input = $form->find_input('Lifecycle');
is( $lifecycle_input->value, 'default',
    'lifecycle is changed back to default' );

