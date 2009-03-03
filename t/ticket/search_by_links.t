#!/usr/bin/perl -w

use strict;
use warnings;

use Test::More tests => 76;
use RT::Test;
use RT::Model::Ticket;

my $q = RT::Test->load_or_create_queue( name =>  'Regression' );
ok $q && $q->id, 'loaded or created queue';

my ($total, @data, @tickets, %test) = (0, ());

sub add_tix_from_data {
    my @res = ();
    while (@data) {
        my $t = RT::Model::Ticket->new(current_user => RT->system_user);
        my %args = %{ shift(@data) };
        $args{$_} = $res[ $args{$_} ]->id foreach grep $args{$_}, keys %RT::Model::Ticket::LINKTYPEMAP;
        my ( $id, undef $msg ) = $t->create(
            queue => $q->id,
            %args,
        );
        ok( $id, "ticket created" ) or diag("error: $msg");
        push @res, $t;
        $total++;
    }
    return @res;
}

sub run_tests {
    my @ids = map $_->id, @tickets;
    foreach my $key ( sort keys %test ) {
        my $tix = RT::Model::TicketCollection->new(current_user => RT->system_user);
        $tix->tisql->query( "( $key ) AND .id = ?", [ @ids ] );

        my $error = 0;

        my $count = 0;
        $count++ foreach grep $_, values %{ $test{$key} };
        is($tix->count, $count, "found correct number of ticket(s) by '$key'") or $error = 1;

        my $good_tickets = 1;
        while ( my $ticket = $tix->next ) {
            next if $test{$key}->{ $ticket->subject };
            diag $ticket->subject ." ticket has been found when it's not expected";
            $good_tickets = 0;
        }
        ok( $good_tickets, "all tickets are good with '$key'" ) or $error = 1;

        diag "Wrong SQL query for '$key':". $tix->build_select_query if $error;
    }
}

# simple set with "no links", "parent and child"
@data = (
    { subject => '-', },
    { subject => 'p', },
    { subject => 'c', MemberOf => -1 },
);
@tickets = add_tix_from_data();
%test = (
    'has    .links'       => { '-' => 0, c => 1, p => 1 },
    'has no .links'       => { '-' => 1, c => 0, p => 0 },
    'has    .links_to'    => { '-' => 0, c => 1, p => 0 },
    'has no .links_to'    => { '-' => 1, c => 0, p => 1 },
    'has    .links_from'  => { '-' => 0, c => 0, p => 1 },
    'has no .links_from'  => { '-' => 1, c => 1, p => 0 },

    'has    .links{type => "HasMember"}'  => { '-' => 0, c => 0, p => 1 },
    'has no .links{type => "HasMember"}'  => { '-' => 1, c => 1, p => 0 },
    'has    .links{type => "MemberOf"}'    => { '-' => 0, c => 1, p => 0 },
    'has no .links{type => "MemberOf"}'    => { '-' => 1, c => 0, p => 1 },

    'has    .links{type => "RefersTo"}'    => { '-' => 0, c => 0, p => 0 },
    'has no .links{type => "RefersTo"}'    => { '-' => 1, c => 1, p => 1 },

# TODO:
#    '.linked      = '. $tickets[0]->id  => { '-' => 0, c => 0, p => 0 },
#    '.linked     != '. $tickets[0]->id  => { '-' => 1, c => 1, p => 1 },

    '.links{type => "MemberOf"}.local_target     = '. $tickets[1]->id  => { '-' => 0, c => 1, p => 0 },
    '.links{type => "MemberOf"}.local_target    != '. $tickets[1]->id  => { '-' => 1, c => 0, p => 1 },
);
{
    my $tix = RT::Model::TicketCollection->new(current_user => RT->system_user);
    $tix->from_sql("Queue = '". $q->id ."'");
    is($tix->count, $total, "found $total tickets");
}
run_tests();

# another set with tests of combinations searches
@data = (
    { subject => '-', },
    { subject => 'p', },
    { subject => 'rp',  RefersTo => -1 },
    { subject => 'c',   MemberOf => -2 },
    { subject => 'rc1', RefersTo => -1 },
    { subject => 'rc2', RefersTo => -2 },
);
@tickets = add_tix_from_data();
my $pid = $tickets[1]->id;
%test = (
    'has    .links{type => "RefersTo"}' => { '-' => 0, c => 0, p => 0, rp => 1, rc1 => 1, rc2 => 1 },
    'has no .links{type => "RefersTo"}' => { '-' => 1, c => 1, p => 1, rp => 0, rc1 => 0, rc2 => 0 },

    'has    .links{type => "RefersTo"} AND has    .links{type => "MemberOf"}'
        => { '-' => 0, c => 0, p => 0, rp => 0, rc1 => 0, rc2 => 0 },
    'has    .links{type => "RefersTo"} AND has no .links{type => "MemberOf"}'
        => { '-' => 0, c => 0, p => 0, rp => 1, rc1 => 1, rc2 => 1 },
    'has no .links{type => "RefersTo"} AND has    .links{type => "MemberOf"}'
        => { '-' => 0, c => 1, p => 0, rp => 0, rc1 => 0, rc2 => 0 },
    'has no .links{type => "RefersTo"} AND has no .links{type => "MemberOf"}'
        => { '-' => 1, c => 0, p => 1, rp => 0, rc1 => 0, rc2 => 0 },

    'has    .links{type => "RefersTo"} OR  has    .links{type => "MemberOf"}'
        => { '-' => 0, c => 1, p => 0, rp => 1, rc1 => 1, rc2 => 1 },
    'has    .links{type => "RefersTo"} OR  has no .links{type => "MemberOf"}'
        => { '-' => 1, c => 0, p => 1, rp => 1, rc1 => 1, rc2 => 1 },
    'has no .links{type => "RefersTo"} OR  has    .links{type => "MemberOf"}'
        => { '-' => 1, c => 1, p => 1, rp => 0, rc1 => 0, rc2 => 0 },
    'has no .links{type => "RefersTo"} OR  has no .links{type => "MemberOf"}'
        => { '-' => 1, c => 1, p => 1, rp => 1, rc1 => 1, rc2 => 1 },

    ".links{type => 'RefersTo'}.local_target  = $pid AND .links{type => 'MemberOf'}.local_target  = $pid"
        => { '-' => 0, c => 0, p => 0, rp => 0, rc1 => 0, rc2 => 0 },
    ".links{type => 'RefersTo'}.local_target  = $pid AND .links{type => 'MemberOf'}.local_target != $pid"
        => { '-' => 0, c => 0, p => 0, rp => 1, rc1 => 0, rc2 => 0 },
    ".links{type => 'RefersTo'}.local_target != $pid AND .links{type => 'MemberOf'}.local_target  = $pid"
        => { '-' => 0, c => 1, p => 0, rp => 0, rc1 => 0, rc2 => 0 },
    ".links{type => 'RefersTo'}.local_target != $pid AND .links{type => 'MemberOf'}.local_target != $pid"
        => { '-' => 1, c => 0, p => 1, rp => 0, rc1 => 1, rc2 => 1 },

    ".links{type => 'RefersTo'}.local_target  = $pid OR  .links{type => 'MemberOf'}.local_target  = $pid"
        => { '-' => 0, c => 1, p => 0, rp => 1, rc1 => 0, rc2 => 0 },
    ".links{type => 'RefersTo'}.local_target  = $pid OR  .links{type => 'MemberOf'}.local_target != $pid"
        => { '-' => 1, c => 0, p => 1, rp => 1, rc1 => 1, rc2 => 1 },
    ".links{type => 'RefersTo'}.local_target != $pid OR  .links{type => 'MemberOf'}.local_target  = $pid"
        => { '-' => 1, c => 1, p => 1, rp => 0, rc1 => 1, rc2 => 1 },
    ".links{type => 'RefersTo'}.local_target != $pid OR  .links{type => 'MemberOf'}.local_target != $pid"
        => { '-' => 1, c => 1, p => 1, rp => 1, rc1 => 1, rc2 => 1 },
);
{
    my $tix = RT::Model::TicketCollection->new(current_user => RT->system_user);
    $tix->from_sql("Queue = '". $q->id ."'");
    is($tix->count, $total, "found $total tickets");
}
run_tests();

