
use strict;
use warnings;

package RT::Crypt;

require RT::Crypt::GnuPG;
require RT::Crypt::SMIME;

sub EnabledOnIncoming {
    return 'GnuPG', 'SMIME';
}

# encryption and signatures can be nested one over another, for example:
# GPG inline signed text can be signed with SMIME

sub FindProtectedParts {
    my $self = shift;
    my %args = (
        Entity => undef,
        Skip => {},
        Scattered => 1,
        @_
    );

    my $entity = $args{'Entity'};
    return () if $args{'Skip'}{ $entity };

    my @protocols = $self->EnabledOnIncoming;

    foreach my $protocol ( @protocols ) {
        my $class = 'RT::Crypt::'. $protocol;
        my %info = $class->CheckIfProtected( Entity => $entity );
        next unless keys %info;

        $args{'Skip'}{ $entity } = 1;
        $info{'Protocol'} = $protocol;
        return \%info;
    }

    # not protected itself, look inside
    push @res, $self->FindProtectedParts(
        %args, Entity => $_, Scattered => 0,
    ) foreach grep !$args{'Skip'}{$_}, $entity->parts;

    if ( $args{'Scattered'} ) {
        my $filter; $filter = sub {
            return grep !$args{'Skip'}{$_},
                $_[0]->is_multipart ? () : $_[0],
                map $filter->($_), grep !$args{'Skip'}{$_},
                    $_[0]->parts;
        };
        my @parts = $filter->($entity);
        foreach my $protocol ( @protocols ) {
            my $class = 'RT::Crypt::'. $protocol;
            my @list = $class->FindScatteredParts( Parts => \@parts, Skip => $args{'Skip'} );
            next unless @list;

            push @res, @list;
            @parts = grep !$args{'Skip'}{$_}, @parts;
        }
    }

    return @res;
}

sub SignEncrypt {
    my $self = shift;
    my %args = (@_);

    my $entity = $args{'Entity'};
    if ( $args{'Sign'} && !defined $args{'Signer'} ) {
        $args{'Signer'} =
            $self->UseKeyForSigning
            || (Email::Address->parse( $entity->head->get( 'From' ) ))[0]->address;
    }
    if ( $args{'Encrypt'} && !$args{'Recipients'} ) {
        my %seen;
        $args{'Recipients'} = [
            grep $_ && !$seen{ $_ }++, map $_->address,
            map Email::Address->parse( $entity->head->get( $_ ) ),
            qw(To Cc Bcc)
        ];
    }

    my $using = delete $args{'Using'} || 'GnuPG';
    my $class = 'RT::Crypt::'. $using;

    return $class->SignEncrypt( %args );
}

sub VerifyDecrypt {
    my $self = shift;
    my %args = (
        Entity    => undef,
        Detach    => 1,
        SetStatus => 1,
        AddStatus => 0,
        @_
    );

    my @res;

    my @protected = $self->FindProtectedParts( Entity => $args{'Entity'} );
    foreach my $protected ( @protected ) {
        my $protocol = $protected->{'Protocol'};
        my $class = 'RT::Crypt::'. $protocol;
        my %res = $class->VerifyDecrypt( %args, %$protected );
        push @res, \%res;
    }
    return @res;
}

1;
