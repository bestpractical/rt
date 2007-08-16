#!/usr/bin/perl

use strict;
use warnings;

use RT;
RT::LoadConfig();

use IPC::Open2;

our $url = RT->Config->Get('WebURL');
our $mailgate = $RT::BinPath .'/rt-mailgate';
die "Couldn't find mailgate ($mailgate) command" unless -f $mailgate;
$mailgate .= ' --debug';

sub run_gate {
    my %args = (
        url     => $url,
        message => '',
        action  => 'correspond',
        queue   => 'General',
        @_
    );
    my $message = delete $args{'message'};

    my $cmd = $mailgate;
    while( my ($k,$v) = each %args ) {
        next unless $v;
        $cmd .= " --$k '$v'";
    }
    $cmd .= ' 2>&1';

    DBIx::SearchBuilder::Record::Cachable->FlushCache;

    my ($child_out, $child_in);
    my $pid = open2($child_out, $child_in, $cmd);
    if ( UNIVERSAL::isa($message, 'MIME::Entity') ) {
        $message->print( $child_in );
    } else {
        print $child_in $message;
    }
    close $child_in;
    my $result = do { local $/; <$child_out> };
    close $child_out;
    waitpid $pid, 0;
    return ($?, $result);
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

