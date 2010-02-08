use strict;
use warnings;

package RT::Crypt::Base;

sub SignEncrypt {
    return (exit_code => 1, status => []);    
}

sub VerifyDecrypt {
    return (exit_code => 1, status => []);
}

sub DrySign {
    my $self = shift;
    my %args = ( Signer => undef, @_ );
    my $from = $args{'Signer'};

    my $mime = MIME::Entity->build(
        Type    => "text/plain",
        From    => 'nobody@localhost',
        To      => 'nobody@localhost',
        Subject => "dry sign",
        Data    => ['t'],
    );

    my %res = $self->SignEncrypt(
        Sign    => 1,
        Encrypt => 0,
        Entity  => $mime,
        Signer  => $from,
    );

    return $res{exit_code} == 0;
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
