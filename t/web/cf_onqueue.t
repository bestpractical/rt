#!/usr/bin/perl -w
use strict;

use RT::Test strict => 1, tests => 4, l10n => 1;
my ($baseurl, $m) = RT::Test->started_ok;

ok $m->login, 'logged in';

diag "Create a queue CF" if $ENV{'TEST_VERBOSE'};
my $cf = RT::Model::CustomField->new( current_user => RT->system_user );
my ( $status, $msg ) = $cf->create(
    name        => 'QueueCFTest',
    description => 'QueueCFTest',
    type        => 'Freeform',
    lookup_type => 'RT::Model::Queue',
    max_values  => 1,
);

ok( $status, $msg );

diag "Apply the new CF globally" if $ENV{'TEST_VERBOSE'};
my $queue = RT::Model::Queue->new( current_user => RT->system_user );
( $status, $msg ) = $cf->add_to_object( $queue );
ok( $status, $msg );

# TODO we need add cf support for queue in /admin/
#diag "Edit the CF value for default queue" if $ENV{'TEST_VERBOSE'};
#{
#    $m->follow_link( url => '/admin/queues/' );
#    $m->title_is(q/Admin queues/, 'queues configuration screen');
#    $m->follow_link( text => "1" );
#    $m->title_is(q/Editing Configuration for queue General/, 'default queue configuration screen');
#    $m->content_like( qr/QueueCFTest/, 'CF QueueCFTest displayed on default queue' );
#    $m->submit_form(
#        form_name => 'queue_modify',
         # The following doesn't want to works :(
         #with_fields => { 'object-RT::Model::Queue-1-CustomField-1-value' },
#        fields => {
#            'object-RT::Model::Queue-1-CustomField-1-value' => 'QueueCFTest content',
#        },
#    );
#    $m->content_like( qr/QueueCFTest QueueCFTest content added/, 'Content filed in CF QueueCFTest for default queue' );
#
#}


__END__
