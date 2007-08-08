#!/usr/bin/perl

use strict;
use warnings;

use RT;
RT::LoadConfig();

sub run_gate {
    require RT::Test;
    return RT::Test->run_mailgate(@_);
}

sub create_ticket_via_gate {
    my $message = shift;
    my ($status, $gate_result) = run_gate( message => $message, @_ );
    my $id;
    unless ( $status >> 8 ) {
        ($id) = ($gate_result =~ /Ticket:\s*(\d+)/i);
        unless ( $id ) {
            diag "Couldn't find ticket id in text:\n$gate_result" if $ENV{'TEST_VERBOSE'};
        }
    } else {
        diag "Mailgate output:\n$gate_result" if $ENV{'TEST_VERBOSE'};
    }
    return ($status, $id);
}

