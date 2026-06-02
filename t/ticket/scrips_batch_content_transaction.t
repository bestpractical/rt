use strict;
use warnings;

use RT::Test tests => undef;

# When $PreferContentTransactionInBatch is enabled, TransactionBatch scrips
# (and their templates) should receive the message-bearing transaction
# (Create/Correspond/Comment) as $Transaction, rather than whatever
# transaction happened to be created first in the batch.

RT->Config->Set( UseTransactionBatch => 1 );

my $queue = RT::Test->load_or_create_queue( Name => 'General' );
ok $queue && $queue->id, 'loaded queue';

# A capture file the batch scrip writes the transaction it received into.
my $capture = File::Spec->catfile( RT::Test->temp_directory, 'batch_txn' );

my $code = <<"END";
    my \$txn = \$self->TransactionObj;
    open my \$fh, '>', '$capture' or die "\$!";
    print \$fh \$txn->Type . "\\n";
    print \$fh \$txn->Content . "\\n";
    close \$fh;
    return 1;
END

my $scrip = RT::Scrip->new( RT->SystemUser );
my ( $sid, $smsg ) = $scrip->Create(
    Description      => 'capture batch transaction',
    ScripCondition   => 'On Transaction',
    ScripAction      => 'User Defined',
    Template         => 'Blank',
    Stage            => 'TransactionBatch',
    Queue            => 0,
    CustomPrepareCode => 'return 1;',
    CustomCommitCode => $code,
);
ok $sid, "created batch scrip: $smsg";

# Run a combined owner-change + message update (the way Ticket/Display.html
# drives it: one outer Atomic so both land in a single batch) and return the
# transaction type and content the scrip saw.
sub run_update {
    my %args = @_;

    # Create the ticket already open so changing the owner does not also
    # generate an auto-open Status transaction, keeping the batch deterministic:
    # [ Set(Owner), SetWatcher(Owner), Correspond/Comment ].
    my $ticket = RT::Test->create_ticket(
        Queue   => $queue->id,
        Subject => 'batch txn test',
        Status  => 'open',
    );

    unlink $capture;

    my $obj = RT::Ticket->new( RT->SystemUser );
    $obj->Load( $ticket->id );
    $obj->Atomic(sub {
        $obj->SetOwner('root');
        if ( $args{Comment} ) {
            $obj->Comment( Content => $args{Comment} );
        }
        else {
            $obj->Correspond( Content => $args{Correspond} );
        }
        return 1;
    });

    open my $fh, '<', $capture or die "couldn't read $capture: $!";
    chomp( my @lines = <$fh> );
    close $fh;
    return { Type => $lines[0], Content => $lines[1] };
}

diag 'Default behavior (option off): scrip receives the first batched transaction';
{
    RT->Config->Set( PreferContentTransactionInBatch => 0 );
    my $seen = run_update( Correspond => 'the actual reply body' );
    is $seen->{Type}, 'Set',
        'with option off, scrip receives the content-less owner-change transaction';
    is $seen->{Content}, 'This transaction appears to have no content',
        'and its content is the no-content placeholder';
}

diag 'Option on: scrip receives the Correspond transaction';
{
    RT->Config->Set( PreferContentTransactionInBatch => 1 );
    my $seen = run_update( Correspond => 'the actual reply body' );
    is $seen->{Type}, 'Correspond',
        'with option on, scrip receives the Correspond transaction';
    is $seen->{Content}, 'the actual reply body',
        'and its content is the reply body';
}

diag 'Option on: a Comment is also treated as a content transaction';
{
    RT->Config->Set( PreferContentTransactionInBatch => 1 );
    my $seen = run_update( Comment => 'an internal comment' );
    is $seen->{Type}, 'Comment',
        'with option on, scrip receives the Comment transaction';
    is $seen->{Content}, 'an internal comment',
        'and its content is the comment body';
}

diag 'Option on: a Create transaction is always first in its batch and still flows through';
{
    # A Create transaction can never be preceded by another transaction in its
    # batch (the ticket does not exist beforehand), so it is always the first
    # batched transaction. With the option on it is selected via the fallback
    # to the first transaction, since it is not a Correspond/Comment.
    RT->Config->Set( PreferContentTransactionInBatch => 1 );

    unlink $capture;
    my $obj = RT::Ticket->new( RT->SystemUser );
    my ($id) = $obj->Create(
        Queue   => $queue->id,
        Subject => 'create batch test',
        Status  => 'open',
    );
    ok $id, 'created ticket';
    $obj->ApplyTransactionBatch;

    open my $fh, '<', $capture or die "couldn't read $capture: $!";
    chomp( my @lines = <$fh> );
    close $fh;
    is $lines[0], 'Create',
        'scrip receives the Create transaction (the only one in a creation batch)';
}

done_testing;
