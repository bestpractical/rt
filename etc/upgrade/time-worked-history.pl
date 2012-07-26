#!/usr/bin/env perl
use 5.8.3;
use strict;
use warnings;

use RT;
RT::LoadConfig();
RT->Config->Set('LogToScreen' => 'info');
RT::Init();

my $dbh = $RT::Handle->dbh;
my $ids = $dbh->selectcol_arrayref(
    "SELECT t1.id FROM Tickets t1, Tickets t2 WHERE t1.id = t2.EffectiveId"
    ." AND t2.id != t2.EffectiveId AND t2.EffectiveId = t1.id"
);
foreach my $id ( @$ids ) {
    my $t = RT::Ticket->new( RT->SystemUser );
    $t->Load( $id );
    unless ( $t->id ) {
        $RT::Logger->error("Couldn't load ticket #$id");
        next;
    }

    fix_time_worked_history($t);
}

sub fix_time_worked_history {
    my ($t) = (@_);

    my $history = 0;
    my $candidate = undef;
    my @delete = ();
    my $delete_time = 0;

    my $txns = $t->Transactions;
    while ( my $txn = $txns->Next ) {
        if ( $txn->Type =~ /^(Create|Correspond|Comment)$/ ) {
            $history += $txn->TimeTaken || 0;
        } elsif ( $txn->Type eq 'Set' && $txn->Field eq 'TimeWorked' ) {
            $history += $txn->NewValue - $txn->OldValue;
            $candidate = $txn;
        } elsif ( $candidate && $txn->Field eq 'MergedInto' ) {
            if ($candidate->Creator eq $txn->Creator ) {
                push @delete, $candidate;
                $delete_time += $candidate->NewValue - $candidate->OldValue;
            }

            $candidate = undef;
        }
    }

    if ( $history == $t->TimeWorked ) {
        $RT::Logger->info("Ticket #". $t->id . " has TimeWorked matching history. Skipping");
    } elsif ( $history - $delete_time == $t->TimeWorked ) {
        $RT::Logger->warn( "Ticket #". $t->id ." has TimeWorked mismatch. Deleting transactions" );
        foreach my $dtxn ( @delete ) {
            my ($status, $msg) = $dtxn->Delete;
            $RT::Logger->error("Couldn't delete transaction: $msg") unless $status;
        }
    } else {
        $RT::Logger->error( "Ticket #". $t->id ." has TimeWorked mismatch, but we couldn't find correct transactions to delete. Skipping" );
    }
}
