#!/usr/bin/perl

use strict;
use warnings;


my $config;
BEGIN {
$config = <<END;
Set(\%Lifecycles,
    default => {
        default_initial => 'new',
        initial  => [qw(new)],
        active   => [qw(open stalled)],
        inactive => [qw(resolved rejected deleted)],
        transitions => {
            ''       => [qw(new open resolved)],
            new      => [qw(open resolved rejected deleted)],
            open     => [qw(stalled resolved rejected deleted)],
            stalled  => [qw(open)],
            resolved => [qw(open)],
            rejected => [qw(open)],
            deleted  => [qw(open)],
        },
        actions => {
            'new -> open'     => {label => 'Open It', update => 'Respond'},
            'new -> resolved' => {label => 'Resolve', update => 'Comment'},
            'new -> rejected' => {label => 'Reject',  update => 'Respond'},
            'new -> deleted'  => {label => 'Delete',  update => ''},

            'open -> stalled'  => {label => 'Stall',   update => 'Comment'},
            'open -> resolved' => {label => 'Resolve', update => 'Comment'},
            'open -> rejected' => {label => 'Reject',  update => 'Respond'},

            'stalled -> open'  => {label => 'Open It',  update => ''},
            'resolved -> open' => {label => 'Re-open',  update => 'Comment'},
            'rejected -> open' => {label => 'Re-open',  update => 'Comment'},
            'deleted -> open'  => {label => 'Undelete', update => ''},
        },
    },
    delivery => {
        default_initial => 'ordered',
        initial  => ['ordered'],
        active   => ['on way', 'delayed'],
        inactive => ['delivered'],
        transitions => {
            ordered   => ['on way', 'delayed'],
            'on way'  => ['delivered'],
            delayed   => ['on way'],
            delivered => [],
        },
        actions => {
            'ordered -> on way'   => {label => 'Put On Way', update => 'Respond'},
            'ordered -> delayed'  => {label => 'Delay',      update => 'Respond'},

            'on way -> delivered' => {label => 'Done',       update => 'Respond'},
            'delayed -> on way'   => {label => 'Put On Way', update => 'Respond'},
        },
    },
);
Set(\%LifecycleMap, delivery => 'delivery');
END
}

use RT::Test config => $config;

1;
