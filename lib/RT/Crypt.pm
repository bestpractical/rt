
use strict;
use warnings;

package RT::Crypt;

require RT::Crypt::GnuPG;
require RT::Crypt::SMIME;

our @PROTOCOLS = ('GnuPG', 'SMIME');

sub Protocols {
    return @PROTOCOLS;
}

sub EnabledProtocols {
    my $self = shift;
    return grep RT->Config->Get($_)->{'Enable'}, $self->Protocols;
}

sub UseForOutgoing {
    return RT->Config->Get('Crypt')->{'Outgoing'};
}

sub EnabledOnIncoming {
    return @{ scalar RT->Config->Get('Crypt')->{'Incomming'} };
}

{ my %cache;
sub LoadImplementation {
    my $class = 'RT::Crypt::'. $_[1];
    return $class if $cache{ $class }++;

    eval "require $class; 1" or do { require Carp; Carp::confess( $@ ) };
    return $class;
} }

# encryption and signatures can be nested one over another, for example:
# GPG inline signed text can be signed with SMIME

sub FindProtectedParts {
    my $self = shift;
    my %args = (
        Entity    => undef,
        Protocols => undef,
        Skip      => {},
        Scattered => 1,
        @_
    );

    my $entity = $args{'Entity'};
    return () if $args{'Skip'}{ $entity };

    my @protocols = $args{'Protocols'}
        ? @{ $args{'Protocols'} } 
        : $self->EnabledOnIncoming;

    foreach my $protocol ( @protocols ) {
        my $class = $self->LoadImplementation( $protocol );
        my %info = $class->CheckIfProtected( Entity => $entity );
        next unless keys %info;

        $args{'Skip'}{ $entity } = 1;
        $info{'Protocol'} = $protocol;
        return \%info;
    }

    if ( $entity->effective_type =~ /^multipart\/(?:signed|encrypted)/ ) {
        # if no module claimed that it supports these types then
        # we don't dive in and check sub-parts
        $args{'Skip'}{ $entity } = 1;
        return ();
    }

    my @res;

    # not protected itself, look inside
    push @res, $self->FindProtectedParts(
        %args, Entity => $_, Scattered => 0,
    ) foreach grep !$args{'Skip'}{$_}, $entity->parts;

    if ( $args{'Scattered'} ) {
        my %parent;
        my $filter; $filter = sub {
            $parent{$_[0]} = $_[1];
            return
                grep !$args{'Skip'}{$_},
                $_[0]->is_multipart ? () : $_,
                map $filter->($_, $_[0]), grep !$args{'Skip'}{$_},
                    $_[0]->parts;
        };
        my @parts = $filter->($entity);
        foreach my $protocol ( @protocols ) {
            my $class = $self->LoadImplementation( $protocol );
            my @list = $class->FindScatteredParts(
                Parts   => \@parts,
                Parents => \%parent,
                Skip    => $args{'Skip'}
            );
            next unless @list;

            $_->{'Protocol'} = $protocol foreach @list;
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

    my $protocol = delete $args{'Protocol'} || 'GnuPG';
    my $class = $self->LoadImplementation( $protocol );

    my %res = $class->SignEncrypt( %args );
    $res{'Protocol'} = $protocol;
    return %res;
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
        my $class = $self->LoadImplementation( $protocol );
        my %res = $class->VerifyDecrypt( %args, Info => $protected );
        $res{'Protocol'} = $protocol;
        push @res, \%res;
    }
    return @res;
}

sub ParseStatus {
    my $self = shift;
    my %args = (
        Protocol => undef,
        Status   => '',
        @_
    );
    return $self->LoadImplementation( $args{'Protocol'} )->ParseStatus( $args{'Status'} );
}

1;
