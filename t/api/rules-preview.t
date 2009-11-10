#!/usr/bin/perl
use strict;
use RT::Test strict => 1; use Test::More tests => 5;
use_ok('RT::Interface::Web');
my $queue = RT::Model::Queue->new(current_user => RT->system_user );
$queue->create( name => 'RecordCustomFields-'.$$ );
ok ($queue->id, "Created the queue" . $queue->id);

my $ticket = RT::Model::Ticket->new(current_user => RT->system_user );
$ticket->create(
	queue => $queue->id,
	requestor => 'root@localhost',
	cc => 'moosecc@example.org',
	subject => 'scrip preview test',
);

ok($ticket->id, "Created the ticket ok");

our $DEBUG=1;

my ( $txn_id, $description, $txn ) = $ticket->correspond(
    cc_message_to => 'onetime@example.org',
    content       => 'test dry run and previews',
    time_taken    => '10',
    dry_run       => 1,
);

ok($txn_id, 'created txn');

my $preview = {};
for (@{$txn->rules}) {
    my $hints = $_->hints;
    next unless $hints->{class} eq 'SendEmail';
    $preview->{$_->description} = $hints->{recipients};
}

is_deeply($preview,
          { 'On Correspond Notify Other Recipients' =>
            { to => ['onetime@example.org'], cc => [], bcc => [] },
            'On Correspond Notify requestors and ccs' =>
            { to => [ 'root@localhost' ],
              cc => [ 'moosecc@example.org' ],
              bcc => [] },
            'On Correspond Notify admin_ccs' =>
            { to => [], cc => [], bcc => [] } }
      );

