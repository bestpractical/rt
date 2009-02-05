package RT::Test::Warnings;
use strict;
use warnings;

use RT::Test::Warnings::Appender;
use Log::Log4perl;

sub import {
    my $root = Log::Log4perl->get_logger('');
    my $a = RT::Test::Warnings::Appender->new( name => "WarningAppender" );
    $root->add_appender($a);
}

1;
