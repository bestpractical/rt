
use strict;
use warnings;

use RT::Test tests => 19;
use_ok('RT');
use_ok('RT::Ticket');

my $queue = RT::Test->load_or_create_queue( Name => 'Regression' );
ok $queue && $queue->id, 'loaded or created queue';

RT->Config->Set( UseTransactionBatch => 1 );

my ($baseurl, $m) = RT::Test->started_ok;
ok $m->login, 'logged in as root';

my $sid;
{
    $m->follow_link_ok( { id => 'admin-queues' } );
    $m->follow_link_ok( { text => $queue->Name } );
    $m->follow_link_ok( { id => 'page-scrips-create'});

    $m->form_name('CreateScrip');
    $m->field('Description' => 'test');
    $m->select('ScripCondition' => 'On Transaction');
    $m->select('ScripAction' => 'User Defined');
    $m->select('Template' => 'Blank');
    $m->select('Stage' => 'Batch');
    $m->field('CustomPrepareCode' => 'return 1;');
    $m->field('CustomCommitCode' => 'return 1;');
    $m->click('Create');
    $m->content_contains("Scrip Created");

    my $form = $m->form_name('ModifyScrip');
    $sid = $form->value('id');
    is $m->value("Description"), 'test', 'correct description';
    is value_name($form, "ScripCondition"), 'On Transaction', 'correct condition';
    is value_name($form, "ScripAction"), 'User Defined', 'correct action';
    is value_name($form, "Template"), 'Blank', 'correct template';

    {
        my $rec = RT::ObjectScrip->new( RT->SystemUser );
        $rec->LoadByCols( Scrip => $sid, ObjectId => $queue->id );
        is $rec->Stage, 'TransactionBatch', "correct stage";
    }

    my $tmp_fn = File::Spec->catfile( RT::Test->temp_directory, 'transactions' );
    open my $tmp_fh, '+>', $tmp_fn or die $!;

    my $code = <<END;
open( my \$fh, '>', '$tmp_fn' ) or die "Couldn't open '$tmp_fn':\$!";

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

    $m->field( "CustomCommitCode" => $code );
    $m->click('Update');

    $m->goto_create_ticket( $queue );
    $m->form_name('TicketCreate');
    $m->submit;

    is_deeply parse_handle($tmp_fh), ['Create'], 'Create';

    $m->follow_link_ok( { text => 'Resolve' } );
    $m->form_name('TicketUpdate');
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

