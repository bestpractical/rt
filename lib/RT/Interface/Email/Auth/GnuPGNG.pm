package RT::Interface::Email::Auth::GnuPGNG;

use strict;
use warnings;

=head2 GetCurrentUser

To use the gnupg-secured mail gateway, you need to do the following:

Set up a gnupgp key directory with a pubring containing only the keys
you care about and specify the following in your SiteConfig.pm

Set(%GnuPGOptions, homedir => '/opt/rt3/var/data/GnuPG');
Set(@MailPlugins, 'Auth::GnuPGNG', ...other filter...);

=cut

use RT::Crypt::GnuPG;

sub GetCurrentUser {
    my %args = (
        Message       => undef,
        RawMessageRef => undef,
        CurrentUser   => undef,
        AuthLevel     => undef,
        Ticket        => undef,
        Queue         => undef,
        Action        => undef,
        @_
    );

    $args{'Message'}->head->delete($_)
        for qw(X-RT-GnuPG-Status X-RT-Incoming-Encrypton
               X-RT-Incoming-Signature X-RT-Privacy);

    my ($status, @res) = VerifyDecrypt( Entity => $args{'Message'} );
    if ( $status && !@res ) {
        $args{'Message'}
            ->head->add( 'X-RT-Incoming-Encryption' => 'Not encrypted' );

        return @args{qw(CurrentUser AuthLevel)};
    }

    $RT::Logger->error("Had a problem during decrypting and verifying")
        unless $status;

    $args{'Message'}->head->add( 'X-RT-GnuPG-Status' => $_->{'status'} )
        foreach @res;
    $args{'Message'}->head->add( 'X-RT-Privacy' => 'PGP' );

    # XXX: first entity only for now
    if (@res) {
        my $decrypted;
        my @status = RT::Crypt::GnuPG::ParseStatus( $res[0]->{'status'} );
        for (@status) {
            if ( $_->{Operation} eq 'Decrypt' && $_->{Status} eq 'DONE' ) {
                $decrypted = 1;
            }
            if ( $_->{Operation} eq 'Verify' && $_->{Status} eq 'DONE' ) {
                $args{'Message'}->head->add(
                    'X-RT-Incoming-Signature' => $_->{UserString} );
            }
        }
        $args{'Message'}->head->add( 'X-RT-Incoming-Encryption' => $decrypted
            ? 'Success'
            : 'Not encrypted' );
    }

    return @args{qw(CurrentUser AuthLevel)};
}

sub VerifyDecrypt {
    my %args = (
        Entity => undef,
        @_
    );

    my @res = RT::Crypt::GnuPG::VerifyDecrypt( %args );
    unless ( @res ) {
        $RT::Logger->debug("No more encrypted/signed parts");
        return 1;
    }

    $RT::Logger->debug('Found GnuPG protected parts');

    # return on any error
    if ( grep $_->{'exit_code'}, @res ) {
        $RT::Logger->debug("Error during verify/decrypt operation");
        return (0, @res);
    }

    # nesting
    my ($status, @nested) = VerifyDecrypt( %args );
    return $status, @res, @nested;
}

eval "require RT::Interface::Email::Auth::GnuPGNG_Vendor";
die $@
  if ( $@
    && $@ !~ qr{^Can't locate RT/Interface/Email/Auth/GnuPGNG_Vendor.pm} );
eval "require RT::Interface::Email::Auth::GnuPGNG_Local";
die $@
  if ( $@
    && $@ !~ qr{^Can't locate RT/Interface/Email/Auth/GnuPGNG_Local.pm} );

1;

