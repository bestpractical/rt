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

sub GetKeysForEncryption {
    my $self = shift;
    my %args = (Recipient => undef, @_);
    return $self->GetKeysInfo(
        Key => delete $args{'Recipient'},
        %args,
        Type => 'public'
    );
}

sub GetKeysInfo {
    return (
        exit_code => 1,
        message => 'Not implemented',
    );
}

sub ParseDate {
    my $self = shift;
    my $value = shift;

    # never
    return $value unless $value;

    require RT::Date;
    my $obj = RT::Date->new( RT->SystemUser );
    # unix time
    if ( $value =~ /^\d+$/ ) {
        $obj->Set( Value => $value );
    } else {
        $obj->Set( Format => 'unknown', Value => $value, Timezone => 'utc' );
    }
    return $obj;
}

1;
