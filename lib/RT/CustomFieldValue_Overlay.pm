use warnings;
use strict;

package RT::CustomFieldValue;

no warnings qw/redefine/;


=head2 ValidateName

Override the default ValidateName method that stops custom field values
from being integers.

=cut


sub ValidateName { 1 };

1;
