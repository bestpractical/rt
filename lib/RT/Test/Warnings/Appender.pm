package RT::Test::Warnings::Appender;
use strict;
use warnings;
use base qw/Log::Log4perl::Appender/;

sub new {
    my $class = shift;
    return bless {@_}, $class;
}

sub log {
    my $self = shift;
    my $message = $_[0]{message};
    my @messages = ref $message eq "ARRAY" ? @{$message} : ($message);
    warn @messages;
}

1;
