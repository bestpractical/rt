use strict;
use warnings;

use RT::Test nodb => 1, tests => 5;
use Test::Warn;
use RT::Interface::Web; # This gets us HTML::Mason::Commands

{
    my $cf = 2;
    my %args = (
        'GroupingName' => {
            'Value'       => "bar",
            'Value-Magic' => 1
        },
    );

    my ($ret, $grouping) = HTML::Mason::Commands::_ValidateConsistentCustomFieldValues($cf, \%args);

    ok ( $ret, 'No duplicates found');
    is ( $grouping, 'GroupingName', 'Grouping is GroupingName');
}

{
    my $cf = 2;
    my %args = (
        'GroupingName'    => {
            'Value'       => "foo",
            'Value-Magic' => 1
        },
        'AnotherGrouping' => {
            'Value'       => "bar",
            'Value-Magic' => 1
        },
    );

    my ($ret, $grouping);
    warning_like {
        ($ret, $grouping) = HTML::Mason::Commands::_ValidateConsistentCustomFieldValues($cf, \%args);
    } qr/^CF 2 submitted with multiple differing values/i;

    ok ( !$ret, 'Caught duplicate values');
    is ( $grouping, 'AnotherGrouping', 'Defaulted to AnotherGrouping');
}
