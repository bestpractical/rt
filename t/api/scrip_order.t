
use strict;
use warnings;

use RT::Test tests => 204;

my $queue = RT::Test->load_or_create_queue( Name => 'General' );
ok $queue && $queue->id, 'loaded or created queue';

note "check that execution order reflects sort order";
{
    my $ten = main->create_scrip_ok(
        Description => "Set priority to 10",
        Queue => $queue->id, 
        CustomCommitCode => '$self->TicketObj->SetPriority(10);',
    );

    my $five = main->create_scrip_ok(
        Description => "Set priority to 5",
        Queue => $queue->id,
        CustomCommitCode => '$self->TicketObj->SetPriority(5);', 
    );

    my $ticket = RT::Ticket->new(RT->SystemUser);
    my ($id, $msg) = $ticket->Create( 
        Queue => $queue->id, 
        Subject => "Scrip order test $$",
    );
    ok($ticket->id, "Created ticket? id=$id");
    is($ticket->Priority , 5, "By default newer scrip is last");

    main->move_scrip_ok( $five, $queue->id, 'up' );

    $ticket = RT::Ticket->new(RT->SystemUser);
    ($id, $msg) = $ticket->Create(
        Queue => $queue->id,
        Subject => "Scrip order test $$",
    );
    ok($ticket->id, "Created ticket? id=$id");
    is($ticket->Priority , 10, "Moved scrip and result is different");
}

my $queue_B = RT::Test->load_or_create_queue( Name => 'Other' );
ok $queue_B && $queue_B->id, 'loaded or created queue';

note "move around two local scrips";
{
    main->delete_all_scrips();

    my @scrips;
    push @scrips, main->create_scrip_ok( Queue => $queue->id );
    push @scrips, main->create_scrip_ok( Queue => $queue->id );
    main->check_scrips_order(\@scrips, [$queue]);

    main->move_scrip_ok( $scrips[0], $queue->id, 'down' );
    @scrips = @scrips[1, 0];
    main->check_scrips_order(\@scrips, [$queue]);

    main->move_scrip_ok( $scrips[0], $queue->id, 'down' );
    @scrips = @scrips[1, 0];
    main->check_scrips_order(\@scrips, [$queue]);

    main->move_scrip_ok( $scrips[1], $queue->id, 'up' );
    @scrips = @scrips[1, 0];
    main->check_scrips_order(\@scrips, [$queue]);

    main->move_scrip_ok( $scrips[1], $queue->id, 'up' );
    @scrips = @scrips[1, 0];
    main->check_scrips_order(\@scrips, [$queue]);
}

note "move around two global scrips";
{
    main->delete_all_scrips();

    my @scrips;
    push @scrips, main->create_scrip_ok( Queue => 0 );
    push @scrips, main->create_scrip_ok( Queue => 0 );
    main->check_scrips_order(\@scrips, [$queue]);

    main->move_scrip_ok( $scrips[0], 0, 'down' );
    @scrips = @scrips[1, 0];
    main->check_scrips_order(\@scrips, [$queue]);

    main->move_scrip_ok( $scrips[0], 0, 'down' );
    @scrips = @scrips[1, 0];
    main->check_scrips_order(\@scrips, [$queue]);

    main->move_scrip_ok( $scrips[1], 0, 'up' );
    @scrips = @scrips[1, 0];
    main->check_scrips_order(\@scrips, [$queue]);

    main->move_scrip_ok( $scrips[1], 0, 'up' );
    @scrips = @scrips[1, 0];
    main->check_scrips_order(\@scrips, [$queue]);
}

note "move local scrip below global";
{
    main->delete_all_scrips();
    my @scrips;
    push @scrips, main->create_scrip_ok( Queue => $queue->id );
    push @scrips, main->create_scrip_ok( Queue => $queue_B->id );
    push @scrips, main->create_scrip_ok( Queue => 0 );
    push @scrips, main->create_scrip_ok( Queue => $queue->id );
    main->check_scrips_order(\@scrips, [$queue, $queue_B]);

    main->move_scrip_ok( $scrips[0], $queue->id, 'down' );
    @scrips = @scrips[1, 2, 0, 3];
    main->check_scrips_order(\@scrips, [$queue, $queue_B]);
}

note "move local scrip above global";
{
    main->delete_all_scrips();
    my @scrips;
    push @scrips, main->create_scrip_ok( Queue => $queue_B->id );
    push @scrips, main->create_scrip_ok( Queue => 0 );
    push @scrips, main->create_scrip_ok( Queue => $queue->id );
    push @scrips, main->create_scrip_ok( Queue => $queue_B->id );
    main->check_scrips_order(\@scrips, [$queue, $queue_B]);

    main->move_scrip_ok( $scrips[-1], $queue_B->id, 'up' );
    @scrips = @scrips[0, 3, 1, 2];
    main->check_scrips_order(\@scrips, [$queue, $queue_B]);
}

note "move global scrip down with local in between";
{
    main->delete_all_scrips();
    my @scrips;
    push @scrips, main->create_scrip_ok( Queue => 0 );
    push @scrips, main->create_scrip_ok( Queue => $queue_B->id );
    push @scrips, main->create_scrip_ok( Queue => $queue->id );
    push @scrips, main->create_scrip_ok( Queue => 0 );
    push @scrips, main->create_scrip_ok( Queue => $queue->id );
    main->check_scrips_order(\@scrips, [$queue, $queue_B]);

    main->move_scrip_ok( $scrips[0], 0, 'down' );
    @scrips = @scrips[1, 2, 3, 0, 4];
    main->check_scrips_order(\@scrips, [$queue, $queue_B]);
}

note "move global scrip up with local in between";
{
    main->delete_all_scrips();
    my @scrips;
    push @scrips, main->create_scrip_ok( Queue => $queue->id );
    push @scrips, main->create_scrip_ok( Queue => 0 );
    push @scrips, main->create_scrip_ok( Queue => $queue_B->id );
    push @scrips, main->create_scrip_ok( Queue => $queue->id );
    push @scrips, main->create_scrip_ok( Queue => 0 );
    main->check_scrips_order(\@scrips, [$queue, $queue_B]);

    main->move_scrip_ok( $scrips[-1], 0, 'up' );
    @scrips = @scrips[0, 4, 1, 2, 3];
    main->check_scrips_order(\@scrips, [$queue, $queue_B]);
}

note "delete scrips one by one";
{
    main->delete_all_scrips();
    my @scrips;
    push @scrips, main->create_scrip_ok( Queue => $queue->id );
    push @scrips, main->create_scrip_ok( Queue => $queue_B->id );
    push @scrips, main->create_scrip_ok( Queue => 0 );
    push @scrips, main->create_scrip_ok( Queue => $queue_B->id );
    push @scrips, main->create_scrip_ok( Queue => $queue->id );
    push @scrips, main->create_scrip_ok( Queue => 0 );
    main->check_scrips_order(\@scrips, [$queue, $queue_B]);

    foreach my $idx (3, 2, 0 ) {
        $_->Delete foreach splice @scrips, $idx, 1;
        main->check_scrips_order(\@scrips, [$queue, $queue_B]);
    }
}

sub create_scrip_ok {
    local $Test::Builder::Level = $Test::Builder::Level + 1;
    my $self = shift;
    my %args = (
        ScripCondition => 'On Create',
        ScripAction => 'User Defined', 
        CustomPrepareCode => 'return 1',
        CustomCommitCode => 'return 1', 
        Template => 'Blank',
        Stage => 'TransactionCreate',
        @_
    );

    my $scrip = RT::Scrip->new( RT->SystemUser );
    my ($id, $msg) = $scrip->Create( %args );
    ok($id, "Created scrip") or diag "error: $msg";

    return $scrip;
}

sub delete_all_scrips {
    local $Test::Builder::Level = $Test::Builder::Level + 1;
    my $self = shift;
    my $scrips = RT::Scrips->new( RT->SystemUser );
    $scrips->UnLimit;
    $_->Delete foreach @{ $scrips->ItemsArrayRef };
}

sub move_scrip_ok {
    local $Test::Builder::Level = $Test::Builder::Level + 1;
    my $self = shift;
    my ($scrip, $queue, $dir) = @_;

    my $rec = RT::ObjectScrip->new( RT->SystemUser );
    $rec->LoadByCols( Scrip => $scrip->id, ObjectId => $queue );
    ok $rec->id, 'found application of the scrip';

    my $method = 'Move'. ucfirst lc $dir;
    my ($status, $msg) = $rec->$method();
    ok $status, "moved scrip $dir" or diag "error: $msg";
}

sub check_scrips_order {
    local $Test::Builder::Level = $Test::Builder::Level + 1;
    my $self = shift;
    my $scrips = shift;
    my $queues = shift;

    foreach my $qid ( 0, map $_->id, @$queues ) {
        my $list = RT::Scrips->new( RT->SystemUser );
        $list->LimitToGlobal;
        $list->LimitToQueue( $qid ) if $qid;
        $list->ApplySortOrder;
        is_deeply(
            [map $_->id, @{ $list->ItemsArrayRef } ],
            [map $_->id, grep $_->IsAdded( $qid ) || $_->IsGlobal, @$scrips],
            'list of scrips match expected'
        )
    }

    foreach my $qid ( map $_->id, @$queues ) {
        my $list = RT::ObjectScrips->new( RT->SystemUser );
        $list->LimitToObjectId( 0 );
        $list->LimitToObjectId( $qid );

        my %so;
        $so{ $_->SortOrder }++ foreach @{ $list->ItemsArrayRef };
        ok( !grep( {$_ != 1} values %so), 'no dublicate order' );
    }
    {
        my $list = RT::ObjectScrips->new( RT->SystemUser );
        $list->UnLimit;
        $list->OrderBy( FIELD => 'SortOrder', ORDER => 'ASC' );

        my $prev;
        foreach my $rec ( @{ $list->ItemsArrayRef } ) {
            my $so = $rec->SortOrder;
            do { $prev = $so; next } unless defined $prev;

            ok $so == $prev || $so == $prev+1, "sequential order";
            $prev = $so;
        }
    }
}

sub dump_sort_order {

    diag " id oid so";
    diag join "\n", map { join "\t", @$_ } map @$_, $RT::Handle->dbh->selectall_arrayref(
        "select Scrip, ObjectId, SortOrder from ObjectScrips ORDER BY SortOrder"
    );

}


