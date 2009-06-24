
use strict;
use warnings;

use RT::Test tests => '19';
use_ok('RT');
use_ok('RT::Ticket');

my $queue = RT::Test->load_or_create_queue( Name => 'Regression' );
ok $queue && $queue->id, 'loaded or created queue';

RT->Config->Set( UseTransactionBatch => 1 );

my ($baseurl, $m) = RT::Test->started_ok;
ok $m->login, 'logged in as root';

my $sid;
{
    $m->follow_link_ok( { text => 'Configuration' } );
    $m->follow_link_ok( { text => 'Queues' } );
    $m->follow_link_ok( { text => $queue->Name } );
    $m->follow_link_ok( { text => 'Scrips' } );
    $m->follow_link_ok( { text => 'New scrip' } );
    $m->form_number(3);
    $m->field('Scrip-new-Description' => 'test');
    $m->select('Scrip-new-ScripCondition' => 'On Transaction');
    $m->select('Scrip-new-ScripAction' => 'User Defined');
    $m->select('Scrip-new-Template' => 'Global template: Blank');
    $m->select('Scrip-new-Stage' => 'TransactionBatch');
    $m->field('Scrip-new-CustomPrepareCode' => 'return 1;');
    $m->field('Scrip-new-CustomCommitCode' => 'return 1;');
    $m->submit;
    $m->content_like( qr/Scrip Created/ );

    ($sid) = ($m->content =~ /Scrip\s*#(\d+)/);

    my $form = $m->form_number(3);
    is $m->value("Scrip-$sid-Description"), 'test', 'correct description';
    is value_name($form, "Scrip-$sid-ScripCondition"), 'On Transaction', 'correct condition';
    is value_name($form, "Scrip-$sid-ScripAction"), 'User Defined', 'correct action';
    is value_name($form, "Scrip-$sid-Template"), 'Global template: Blank', 'correct template';
    is value_name($form, "Scrip-$sid-Stage"), 'TransactionBatch', 'correct stage';

    use File::Temp qw(tempfile);
    my ($tmp_fh, $tmp_fn) = tempfile();

    my $code = <<END;
open my \$fh, '>', '$tmp_fn' or die "Couldn't open '$tmp_fn':\$!";

my \$batch = \$self->TicketObj->TransactionBatch;
unless ( \$batch && \@\$batch ) {
    print \$fh "no batch\n";
    return 1;
}
foreach my \$txn ( \@\$batch ) {
    print \$fh \$txn->Type ."\n";
}
return 1;
END

    $m->field( "Scrip-$sid-CustomCommitCode" => $code );
    $m->submit;

    $m->goto_create_ticket( $queue );
    $m->form_number(3);
    $m->submit;

    is_deeply parse_handle($tmp_fh), ['Create'], 'Create';

    $m->follow_link_ok( { text => 'Resolve' } );
    $m->form_number(3);
    $m->field( "UpdateContent" => 'resolve it' );
    $m->click('SubmitTicket');

    is_deeply parse_handle($tmp_fh), ['Comment', 'Status'], 'Comment + Resolve';
}

sub value_name {
    my $form = shift;
    my $field = shift;

    my $input = $form->find_input( $field );

    my @names = $input->value_names;
    my @values = $input->possible_values;
    for ( my $i = 0; $i < @values; $i++ ) {
        return $names[ $i ] if $values[ $i ] eq $input->value;
    }
    return undef;
}

sub parse_handle {
    my $fh = shift;
    seek $fh, 0, 0;
    my @lines = <$fh>;
    foreach ( @lines ) { s/^\s+//gms; s/\s+$//gms }
    truncate $fh, 0;
    return \@lines;
}

