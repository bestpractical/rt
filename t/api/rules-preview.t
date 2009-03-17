#!/usr/bin/perl
use strict;
use RT::Test; use Test::More tests => 5;
use_ok('RT::Interface::Web');
my $queue = RT::Model::Queue->new(current_user => RT->system_user );
$queue->create( name => 'RecordCustomFields-'.$$ );
ok ($queue->id, "Created the queue" . $queue->id);

my $ticket = RT::Model::Ticket->new(current_user => RT->system_user );
$ticket->create(
	queue => $queue->id,
	requestor => 'root@localhost',
	subject => 'scrip preview test',
);

ok($ticket->id, "Created the ticket ok");

our $DEBUG=1;

my ( $txn_id, $description, $txn ) = $ticket->correspond(
    content       => 'test dry run and previews',
    time_taken    => '10',
    dry_run       => 1,
);

ok($txn_id, 'created txn');

diag $txn;
diag $description;
diag $txn_id;

my $preview = {};

sub hints_callback {
    my ($action_class, $description, $key, $value) = @_;
    if ($action_class eq 'SendEmail') {
        push @{$preview->{$description}{$key} ||= []}, $value;
    }
}

for (@{$txn->rules}) {
    warn $_;
#    warn Dumper($_);
    $_->hints(\&hints_callback);
}

warn Dumper($preview);

use Data::Dumper;
