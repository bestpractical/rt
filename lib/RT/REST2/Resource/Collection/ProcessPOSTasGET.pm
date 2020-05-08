package RT::REST2::Resource::Collection::ProcessPOSTasGET;
use strict;
use warnings;

use Moose::Role;
use namespace::autoclean;

use Web::Machine::FSM::States qw( is_status_code );

requires 'to_json';

sub process_post {
    my $self = shift;
    my $json = $self->to_json;
    unless (is_status_code($json)) {
        $self->response->body( $json );
        return 1;
    } else {
        return $json;
    }
}

1;
