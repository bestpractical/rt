use strict;
use warnings;

### after: use lib qw(@RT_LIB_PATH@);
use lib qw(/opt/rt3/local/lib /opt/rt3/lib);

package RT::FM::Test;

our @ISA;
BEGIN {
    local $@;
    eval { require RT::Test; 1 } or do {
        require Test::More;
        Test::More::BAIL_OUT(
            "requires 3.8 to run tests. Error:\n$@\n"
            ."You may need to set PERL5LIB=/path/to/rt/lib"
        );
    };
    push @ISA, 'RT::Test';
}

sub import {
    my $class = shift;
    my %args  = @_;

    $args{'requires'} ||= [];
    if ( $args{'testing'} ) {
        unshift @{ $args{'requires'} }, 'RT::FM';
    } else {
        $args{'testing'} = 'RT::FM';
    }

    $class->SUPER::import( %args );

    RT->Config->LoadConfig( File => 'RTFM_Config.pm' );
    require RT::FM;
}

1;
