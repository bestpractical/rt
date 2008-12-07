package RT::Approval;
use strict;
use warnings;

use RT::Ruleset;

RT::Ruleset->Add(
    Name => 'Approval',
    Rules => [
        'RT::Approval::Rule::NewPending',
        'RT::Approval::Rule::Rejected',
        'RT::Approval::Rule::Passed',
    ]);

1;
