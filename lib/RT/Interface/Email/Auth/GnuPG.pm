# BEGIN LICENSE BLOCK
# 
# Copyright (c) 1996-2003 Jesse Vincent <jesse@bestpractical.com>
# 
# (Except where explictly superceded by other copyright notices)
# 
# This work is made available to you under the terms of Version 2 of
# the GNU General Public License. A copy of that license should have
# been provided with this software, but in any event can be snarfed
# from www.gnu.org.
# 
# This work is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# General Public License for more details.
# 
# Unless otherwise specified, all modifications, corrections or
# extensions to this work which alter its source code become the
# property of Best Practical Solutions, LLC when submitted for
# inclusion in the work.
# 
# 
# END LICENSE BLOCK
#
package RT::Interface::Email::Auth::GnuPG;
use Mail::GnuPG;

=head2 GetCurrentUser

To use the gnupg-secured mail gateway, you need to do the following:

Set up a gnupgp key directory with a pubring containing only the keys
you care about and specify the following in your SiteConfig.pm

Set($RT::GPGKeyDir, "/path/to/keyring-directory");
@RT::MailPlugins = qw(Auth::MailFrom Auth::GnuPG Filter::TakeAction);



=cut



sub GetCurrentUser {
    my %args = (
        Message     => undef,
        RawMessageRef     => undef,
        CurrentUser => undef,
        AuthLevel   => undef,
        Ticket      => undef,
        Queue       => undef,
        Action      => undef,
        @_
    );

    my ( $val, $key, $address,$gpg );

    eval {

        my $parser = RT::EmailParser->new();
        $parser->SmartParseMIMEEntityFromScalar(Message => ${$args{'RawMessageRef'}}, Decode => 0);
        $gpg = Mail::GnuPG->new( keydir => $RT::GPGKeyDir );
        my $entity = $parser->Entity;
        ( $val, $key, $address ) = $gpg->verify( $parser->Entity);
          $RT::Logger->crit("Got $val - $key - $address");
      };
    
        if ($@) {
            $RT::Logger->crit($@);
        }

      unless ($address) {
        $RT::Logger->crit( "Couldn't find a valid signature" . join ( "\n", @{ $gpg->{'last_message'} } ) );
        return ( $args{'CurrentUser'}, $args{'AuthLevel'} );
    }

    my @addrs = Mail::Address->parse($address);
    $address = $addrs[0]->address();

    my $CurrentUser = RT::CurrentUser->new();
    $CurrentUser->LoadByEmail($address);

    if ( $CurrentUser->Id ) {
        $RT::Logger->crit($address . " authenticated via PGP signature");
        return ( $CurrentUser, 2 );
    }

}

eval "require RT::Interface::Email::Auth::GnuPG_Vendor";
die $@
  if ( $@
    && $@ !~ qr{^Can't locate RT/Interface/Email/Auth/GnuPG_Vendor.pm} );
eval "require RT::Interface::Email::Auth::GnuPG_Local";
die $@
  if ( $@
    && $@ !~ qr{^Can't locate RT/Interface/Email/Auth/GnuPG_Local.pm} );

1;
