#!/usr/bin/perl

use strict;
use warnings;

use RT;
RT::load_config();

warn "lib/t/utils.pl has been deprecated. Use RT::Test module instead";

sub run_gate {
    require RT::Test;
    return RT::Test->run_mailgate(@_);
}

sub create_ticket_via_gate {
    require RT::Test;
    return RT::Test->send_via_mailgate(@_);
}

