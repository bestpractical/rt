use strict;
use warnings;

package RT::Crypt::Base;

sub SignEncrypt {
    return (exit_code => 1, status => []);    
}

sub VerifyDecrypt {
    return (exit_code => 1, status => []);
}

sub CheckIfProtected { return () }

sub FindScatteredParts { return () }

1;
