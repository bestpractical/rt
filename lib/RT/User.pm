# BEGIN BPS TAGGED BLOCK {{{
#
# COPYRIGHT:
#
# This software is Copyright (c) 1996-2018 Best Practical Solutions, LLC
#                                          <sales@bestpractical.com>
#
# (Except where explicitly superseded by other copyright notices)
#
#
# LICENSE:
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
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA
# 02110-1301 or visit their web page on the internet at
# http://www.gnu.org/licenses/old-licenses/gpl-2.0.html.
#
#
# CONTRIBUTION SUBMISSION POLICY:
#
# (The following paragraph is not intended to limit the rights granted
# to you to modify and distribute this software under the terms of
# the GNU General Public License and is only of importance to you if
# you choose to contribute your changes and enhancements to the
# community by submitting them to Best Practical Solutions, LLC.)
#
# By intentionally submitting any modifications, corrections or
# derivatives to this work, or any other work intended for use with
# Request Tracker, to Best Practical Solutions, LLC, you confirm that
# you are the copyright holder for those contributions and you grant
# Best Practical Solutions,  LLC a nonexclusive, worldwide, irrevocable,
# royalty-free, perpetual, license to use, copy, create derivative
# works based on those contributions, and sublicense and distribute
# those contributions and any derivatives thereof.
#
# END BPS TAGGED BLOCK }}}

=head1 NAME

  RT::User - RT User object

=head1 SYNOPSIS

  use RT::User;

=head1 DESCRIPTION

=head1 METHODS

=cut


package RT::User;

use strict;
use warnings;

use Scalar::Util qw(blessed);

use base 'RT::Record';

sub Table {'Users'}






use Digest::SHA;
use Digest::MD5;
use Crypt::Eksblowfish::Bcrypt qw();
use RT::Principals;
use RT::ACE;
use RT::Interface::Email;
use Text::Password::Pronounceable;
use RT::Util;

sub _OverlayAccessible {
    {

          Name                  => { public => 1,  admin => 1 },    # loc_left_pair
          Password              => { read   => 0 },
          EmailAddress          => { public => 1 },                 # loc_left_pair
          Organization          => { public => 1,  admin => 1 },    # loc_left_pair
          RealName              => { public => 1 },                 # loc_left_pair
          NickName              => { public => 1 },                 # loc_left_pair
          Lang                  => { public => 1 },                 # loc_left_pair
          Gecos                 => { public => 1,  admin => 1 },    # loc_left_pair
          SMIMECertificate      => { public => 1,  admin => 1 },    # loc_left_pair
          City                  => { public => 1 },                 # loc_left_pair
          Country               => { public => 1 },                 # loc_left_pair
          Timezone              => { public => 1 },                 # loc_left_pair
    }
}



=head2 Create { PARAMHASH }



=cut


sub Create {
    my $self = shift;
    my %args = (
        Privileged => 0,
        Disabled => 0,
        EmailAddress => '',
        _RecordTransaction => 1,
        @_    # get the real argumentlist
    );

    # remove the value so it does not cripple SUPER::Create
    my $record_transaction = delete $args{'_RecordTransaction'};

    #Check the ACL
    unless ( $self->CurrentUser->HasRight(Right => 'AdminUsers', Object => $RT::System) ) {
        return ( 0, $self->loc('Permission Denied') );
    }


    unless ($self->CanonicalizeUserInfo(\%args)) {
        return ( 0, $self->loc("Could not set user info") );
    }

    $args{'EmailAddress'} = $self->CanonicalizeEmailAddress($args{'EmailAddress'});

    # if the user doesn't have a name defined, set it to the email address
    $args{'Name'} = $args{'EmailAddress'} unless ($args{'Name'});



    my $privileged = delete $args{'Privileged'};


    if ($args{'CryptedPassword'} ) {
        $args{'Password'} = $args{'CryptedPassword'};
        delete $args{'CryptedPassword'};
    } elsif ( !$args{'Password'} ) {
        $args{'Password'} = '*NO-PASSWORD*';
    } else {
        my ($ok, $msg) = $self->ValidatePassword($args{'Password'});
        return ($ok, $msg) if !$ok;

        $args{'Password'} = $self->_GeneratePassword($args{'Password'});
    }

    #TODO Specify some sensible defaults.

    unless ( $args{'Name'} ) {
        return ( 0, $self->loc("Must specify 'Name' attribute") );
    }

    my ( $val, $msg ) = $self->ValidateName( $args{'Name'} );
    return ( 0, $msg ) unless $val;
    ( $val, $msg ) = $self->ValidateEmailAddress( $args{'EmailAddress'} );
    return ( 0, $msg ) unless ($val);

    $RT::Handle->BeginTransaction();
    # Groups deal with principal ids, rather than user ids.
    # When creating this user, set up a principal Id for it.
    my $principal = RT::Principal->new($self->CurrentUser);
    my $principal_id = $principal->Create(PrincipalType => 'User',
                                Disabled => $args{'Disabled'});
    # If we couldn't create a principal Id, get the fuck out.
    unless ($principal_id) {
        $RT::Handle->Rollback();
        $RT::Logger->crit("Couldn't create a Principal on new user create.");
        $RT::Logger->crit("Strange things are afoot at the circle K");
        return ( 0, $self->loc('Could not create user') );
    }

    delete $args{'Disabled'};

    $self->SUPER::Create(id => $principal_id , %args);
    my $id = $self->Id;

    #If the create failed.
    unless ($id) {
        $RT::Handle->Rollback();
        $RT::Logger->error("Could not create a new user - " .join('-', %args));

        return ( 0, $self->loc('Could not create user') );
    }

    my $aclstash = RT::Group->new($self->CurrentUser);
    my $stash_id = $aclstash->_CreateACLEquivalenceGroup($principal);

    unless ($stash_id) {
        $RT::Handle->Rollback();
        $RT::Logger->crit("Couldn't stash the user in groupmembers");
        return ( 0, $self->loc('Could not create user') );
    }


    my $everyone = RT::Group->new($self->CurrentUser);
    $everyone->LoadSystemInternalGroup('Everyone');
    unless ($everyone->id) {
        $RT::Logger->crit("Could not load Everyone group on user creation.");
        $RT::Handle->Rollback();
        return ( 0, $self->loc('Could not create user') );
    }


    my ($everyone_id, $everyone_msg) = $everyone->_AddMember( InsideTransaction => 1, PrincipalId => $self->PrincipalId);
    unless ($everyone_id) {
        $RT::Logger->crit("Could not add user to Everyone group on user creation.");
        $RT::Logger->crit($everyone_msg);
        $RT::Handle->Rollback();
        return ( 0, $self->loc('Could not create user') );
    }


    my $access_class = RT::Group->new($self->CurrentUser);
    if ($privileged)  {
        $access_class->LoadSystemInternalGroup('Privileged');
    } else {
        $access_class->LoadSystemInternalGroup('Unprivileged');
    }

    unless ($access_class->id) {
        $RT::Logger->crit("Could not load Privileged or Unprivileged group on user creation");
        $RT::Handle->Rollback();
        return ( 0, $self->loc('Could not create user') );
    }


    my ($ac_id, $ac_msg) = $access_class->_AddMember( InsideTransaction => 1, PrincipalId => $self->PrincipalId);

    unless ($ac_id) {
        $RT::Logger->crit("Could not add user to Privileged or Unprivileged group on user creation. Aborted");
        $RT::Logger->crit($ac_msg);
        $RT::Handle->Rollback();
        return ( 0, $self->loc('Could not create user') );
    }


    if ( $record_transaction ) {
        $self->_NewTransaction( Type => "Create" );
    }

    $RT::Handle->Commit;

    return ( $id, $self->loc('User created') );
}

=head2 ValidateName STRING

Returns either (0, "failure reason") or 1 depending on whether the given
name is valid.

=cut

sub ValidateName {
    my $self = shift;
    my $name = shift;

    return ( 0, $self->loc('empty name') ) unless defined $name && length $name;

    my $TempUser = RT::User->new( RT->SystemUser );
    $TempUser->Load($name);

    if ( $TempUser->id && ( !$self->id || $TempUser->id != $self->id ) ) {
        return ( 0, $self->loc('Name in use') );
    }
    else {
        return 1;
    }
}

=head2 ValidatePassword STRING

Returns either (0, "failure reason") or 1 depending on whether the given
password is valid.

=cut

sub ValidatePassword {
    my $self = shift;
    my $password = shift;

    if ( length($password) < RT->Config->Get('MinimumPasswordLength') ) {
        return ( 0, $self->loc("Password needs to be at least [quant,_1,character,characters] long", RT->Config->Get('MinimumPasswordLength')) );
    }

    return 1;
}

=head2 SetPrivileged BOOL

If passed a true value, makes this user a member of the "Privileged"  PseudoGroup.
Otherwise, makes this user a member of the "Unprivileged" pseudogroup.

Returns a standard RT tuple of (val, msg);


=cut

sub SetPrivileged {
    my $self = shift;
    my $val = shift;

    #Check the ACL
    unless ( $self->CurrentUser->HasRight(Right => 'AdminUsers', Object => $RT::System) ) {
        return ( 0, $self->loc('Permission Denied') );
    }

    $self->_SetPrivileged($val);
}

sub _SetPrivileged {
    my $self = shift;
    my $val = shift;
    my $priv = RT::Group->new($self->CurrentUser);
    $priv->LoadSystemInternalGroup('Privileged');
    unless ($priv->Id) {
        $RT::Logger->crit("Could not find Privileged pseudogroup");
        return(0,$self->loc("Failed to find 'Privileged' users pseudogroup."));
    }

    my $unpriv = RT::Group->new($self->CurrentUser);
    $unpriv->LoadSystemInternalGroup('Unprivileged');
    unless ($unpriv->Id) {
        $RT::Logger->crit("Could not find unprivileged pseudogroup");
        return(0,$self->loc("Failed to find 'Unprivileged' users pseudogroup"));
    }

    my $principal = $self->PrincipalId;
    if ($val) {
        if ($priv->HasMember($principal)) {
            #$RT::Logger->debug("That user is already privileged");
            return (0,$self->loc("That user is already privileged"));
        }
        if ($unpriv->HasMember($principal)) {
            $unpriv->_DeleteMember($principal);
        } else {
        # if we had layered transactions, life would be good
        # sadly, we have to just go ahead, even if something
        # bogus happened
            $RT::Logger->crit("User ".$self->Id." is neither privileged nor ".
                "unprivileged. something is drastically wrong.");
        }
        my ($status, $msg) = $priv->_AddMember( InsideTransaction => 1, PrincipalId => $principal);
        if ($status) {
            $self->_NewTransaction(
                Type     => 'Set',
                Field    => 'Privileged',
                NewValue => 1,
                OldValue => 0,
            );
            return (1, $self->loc("That user is now privileged"));
        } else {
            return (0, $msg);
        }
    } else {
        if ($unpriv->HasMember($principal)) {
            #$RT::Logger->debug("That user is already unprivileged");
            return (0,$self->loc("That user is already unprivileged"));
        }
        if ($priv->HasMember($principal)) {
            $priv->_DeleteMember( $principal );
        } else {
        # if we had layered transactions, life would be good
        # sadly, we have to just go ahead, even if something
        # bogus happened
            $RT::Logger->crit("User ".$self->Id." is neither privileged nor ".
                "unprivileged. something is drastically wrong.");
        }
        my ($status, $msg) = $unpriv->_AddMember( InsideTransaction => 1, PrincipalId => $principal);
        if ($status) {
            $self->_NewTransaction(
                Type     => 'Set',
                Field    => 'Privileged',
                NewValue => 0,
                OldValue => 1,
            );
            return (1, $self->loc("That user is now unprivileged"));
        } else {
            return (0, $msg);
        }
    }
}

=head2 Privileged

Returns true if this user is privileged. Returns undef otherwise.

=cut

sub Privileged {
    my $self = shift;
    if ( RT->PrivilegedUsers->HasMember( $self->id ) ) {
        return(1);
    } else {
        return(undef);
    }
}

#create a user without validating _any_ data.

#To be used only on database init.
# We can't localize here because it's before we _have_ a loc framework

sub _BootstrapCreate {
    my $self = shift;
    my %args = (@_);

    $args{'Password'} = '*NO-PASSWORD*';


    $RT::Handle->BeginTransaction();

    # Groups deal with principal ids, rather than user ids.
    # When creating this user, set up a principal Id for it.
    my $principal = RT::Principal->new($self->CurrentUser);
    my $principal_id = $principal->Create(PrincipalType => 'User');

    # If we couldn't create a principal Id, get the fuck out.
    unless ($principal_id) {
        $RT::Handle->Rollback();
        $RT::Logger->crit("Couldn't create a Principal on new user create. Strange things are afoot at the circle K");
        return ( 0, 'Could not create user' );
    }
    $self->SUPER::Create(id => $principal_id, %args);
    my $id = $self->Id;
    #If the create failed.
      unless ($id) {
      $RT::Handle->Rollback();
      return ( 0, 'Could not create user' ) ; #never loc this
    }

    my $aclstash = RT::Group->new($self->CurrentUser);
    my $stash_id  = $aclstash->_CreateACLEquivalenceGroup($principal);

    unless ($stash_id) {
        $RT::Handle->Rollback();
        $RT::Logger->crit("Couldn't stash the user in groupmembers");
        return ( 0, $self->loc('Could not create user') );
    }

    $RT::Handle->Commit();

    return ( $id, 'User created' );
}

sub Delete {
    my $self = shift;

    return ( 0, $self->loc('Deleting this object would violate referential integrity') );

}

=head2 Load

Load a user object from the database. Takes a single argument.
If the argument is numerical, load by the column 'id'. If a user
object or its subclass passed then loads the same user by id.
Otherwise, load by the "Name" column which is the user's textual
username.

=cut

sub Load {
    my $self = shift;
    my $identifier = shift || return undef;

    if ( $identifier !~ /\D/ ) {
        return $self->SUPER::LoadById( $identifier );
    } elsif ( UNIVERSAL::isa( $identifier, 'RT::User' ) ) {
        return $self->SUPER::LoadById( $identifier->Id );
    } else {
        return $self->LoadByCol( "Name", $identifier );
    }
}

=head2 LoadByEmail

Tries to load this user object from the database by the user's email address.

=cut

sub LoadByEmail {
    my $self    = shift;
    my $address = shift;

    # Never load an empty address as an email address.
    unless ($address) {
        return (undef);
    }

    $address = $self->CanonicalizeEmailAddress($address);

    #$RT::Logger->debug("Trying to load an email address: $address");
    return $self->LoadByCol( "EmailAddress", $address );
}

=head2 LoadOrCreateByEmail ADDRESS

Attempts to find a user who has the provided email address. If that fails, creates an unprivileged user with
the provided email address and loads them. Address can be provided either as L<Email::Address> object
or string which is parsed using the module.

Returns a tuple of the user's id and a status message.
0 will be returned in place of the user's id in case of failure.

=cut

sub LoadOrCreateByEmail {
    my $self = shift;

    my %create;
    if (@_ > 1) {
        %create = (@_);
    } elsif ( UNIVERSAL::isa( $_[0] => 'Email::Address' ) ) {
        @create{'EmailAddress','RealName'} = ($_[0]->address, $_[0]->phrase);
    } else {
        my ($addr) = RT::EmailParser->ParseEmailAddress( $_[0] );
        @create{'EmailAddress','RealName'} = $addr ? ($addr->address, $addr->phrase) : (undef, undef);
    }

    $self->LoadByEmail( $create{EmailAddress} );
    $self->Load( $create{EmailAddress} ) unless $self->Id;

    return wantarray ? ($self->Id, $self->loc("User loaded")) : $self->Id
        if $self->Id;

    $create{Name}       ||= $create{EmailAddress};
    $create{Privileged} ||= 0;
    $create{Comments}   //= 'Autocreated when added as a watcher';

    my ($val, $message) = $self->Create( %create );
    return wantarray ? ($self->Id, $self->loc("User loaded")) : $self->Id
        if $self->Id;

    # Deal with the race condition of two account creations at once
    $self->LoadByEmail( $create{EmailAddress} );
    unless ( $self->Id ) {
        sleep 5;
        $self->LoadByEmail( $create{EmailAddress} );
    }

    if ( $self->Id ) {
        $RT::Logger->error("Recovered from creation failure due to race condition");
        return wantarray ? ($self->Id, $self->loc("User loaded")) : $self->Id;
    } else {
        $RT::Logger->crit("Failed to create user $create{EmailAddress}: $message");
        return wantarray ? (0, $message) : 0 unless $self->id;
    }
}

=head2 ValidateEmailAddress ADDRESS

Returns true if the email address entered is not in use by another user or is
undef or ''. Returns false if it's in use.

=cut

sub ValidateEmailAddress {
    my $self  = shift;
    my $Value = shift;

    # if the email address is null, it's always valid
    return (1) if ( !$Value || $Value eq "" );

    if ( RT->Config->Get('ValidateUserEmailAddresses') ) {
        # We only allow one valid email address
        my @addresses = Email::Address->parse($Value);
        return ( 0, $self->loc('Invalid syntax for email address') ) unless ( ( scalar (@addresses) == 1 ) && ( $addresses[0]->address ) );
    }


    my $TempUser = RT::User->new(RT->SystemUser);
    $TempUser->LoadByEmail($Value);

    if ( $TempUser->id && ( !$self->id || $TempUser->id != $self->id ) )
    {    # if we found a user with that address
            # it's invalid to set this user's address to it
        return ( 0, $self->loc('Email address in use') );
    } else {    #it's a valid email address
        return (1);
    }
}

=head2 SetName

Check to make sure someone else isn't using this name already

=cut

sub SetName {
    my $self  = shift;
    my $Value = shift;

    my ( $val, $message ) = $self->ValidateName($Value);
    if ($val) {
        return $self->_Set( Field => 'Name', Value => $Value );
    }
    else {
        return ( 0, $message );
    }
}

=head2 SetEmailAddress

Check to make sure someone else isn't using this email address already
so that a better email address can be returned

=cut

sub SetEmailAddress {
    my $self  = shift;
    my $Value = shift;
    $Value = '' unless defined $Value;

    my ($val, $message) = $self->ValidateEmailAddress( $Value );
    if ( $val ) {
        return $self->_Set( Field => 'EmailAddress', Value => $Value );
    } else {
        return ( 0, $message )
    }

}

=head2 EmailFrequency

Takes optional Ticket argument in paramhash. Returns a string, suitable
for localization, describing any notable properties about email delivery
to the user.  This includes lack of email address, ticket-level
squelching (if C<Ticket> is provided in the paramhash), or user email
delivery preferences.

Returns the empty string if there are no notable properties.

=cut

sub EmailFrequency {
    my $self = shift;
    my %args = (
        Ticket => undef,
        @_
    );
    return '' unless $self->id && $self->id != RT->Nobody->id
        && $self->id != RT->SystemUser->id;
    return 'no email address set'  # loc
        unless my $email = $self->EmailAddress;
    return 'email disabled for ticket' # loc
        if $args{'Ticket'} &&
            grep lc $email eq lc $_->Content, $args{'Ticket'}->SquelchMailTo;
    my $frequency = RT->Config->Get( 'EmailFrequency', $self ) || '';
    return 'receives daily digests' # loc
        if $frequency =~ /daily/i;
    return 'receives weekly digests' # loc
        if $frequency =~ /weekly/i;
    return 'email delivery suspended' # loc
        if $frequency =~ /suspend/i;
    return '';
}

=head2 CanonicalizeEmailAddress ADDRESS

CanonicalizeEmailAddress converts email addresses into canonical form.
it takes one email address in and returns the proper canonical
form. You can dump whatever your proper local config is in here.  Note
that it may be called as a static method; in this case the first argument
is class name not an object.

=cut

sub CanonicalizeEmailAddress {
    my $self = shift;
    my $email = shift;
    # Example: the following rule would treat all email
    # coming from a subdomain as coming from second level domain
    # foo.com
    if ( my $match   = RT->Config->Get('CanonicalizeEmailAddressMatch') and
         my $replace = RT->Config->Get('CanonicalizeEmailAddressReplace') )
    {
        $email =~ s/$match/$replace/gi;
    }
    return ($email);
}

=head2 CanonicalizeUserInfo HASH of ARGS

CanonicalizeUserInfo can convert all User->Create options.
it takes a hashref of all the params sent to User->Create and
returns that same hash, by default nothing is done. If external auth is enabled
CanonicalizeUserInfoFromExternalAuth is called.

This function is intended to allow users to have their info looked up via
an outside source and modified upon creation.

=cut

sub CanonicalizeUserInfo {
    my $self = shift;
    my $args = shift;

    if ( my $config = RT->Config->Get('ExternalInfoPriority') ) {
        if ( ref $config && @$config ) {
            return $self->CanonicalizeUserInfoFromExternalAuth( $args );
        }
    }

    return 1; # fall back to old RT::User::CanonicalizeUserInfo
}

=head2 CanonicalizeUserInfoFromExternalAuth

Convert an ldap entry in to fields that can be used by RT as specified by the
C<attr_map> configuration in the C<$ExternalSettings> variable for
L<RT::Authen::ExternalAuth>.

=cut

sub CanonicalizeUserInfoFromExternalAuth {

    # Careful, this $args hashref was given to RT::User::CanonicalizeUserInfo and
    # then transparently passed on to this function. The whole purpose is to update
    # the original hash as whatever passed it to RT::User is expecting to continue its
    # code with an update args hash.

    my $UserObj = shift;
    my $args    = shift;

    my $found   = 0;
    my %params  = (Name         => undef,
                  EmailAddress => undef,
                  RealName     => undef);

    $RT::Logger->debug( (caller(0))[3],
                        "called by",
                        caller,
                        "with:",
                        join(", ", map {sprintf("%s: %s", $_, ($args->{$_} ? $args->{$_} : ''))}
                            sort(keys(%$args))));

    # Get the list of defined external services
    my @info_services = @{ RT->Config->Get('ExternalInfoPriority') };
    # For each external service...
    foreach my $service (@info_services) {

        $RT::Logger->debug( "Attempting to get user info using this external service:",
                            $service);

        # Get the config for the service so that we know what attrs we can canonicalize
        my $config = RT->Config->Get('ExternalSettings')->{$service};

        # For each attr we've been told to canonicalize in the match list
        foreach my $rt_attr (@{$config->{'attr_match_list'}}) {
            # Jump to the next attr in $args if this one isn't in the attr_match_list
            $RT::Logger->debug( "Attempting to use this canonicalization key:",$rt_attr);
            unless(defined($args->{$rt_attr})) {
                $RT::Logger->debug("This attribute (",
                                    $rt_attr,
                                    ") is null or incorrectly defined in the attr_map for this service (",
                                    $service,
                                    ")");
                next;
            }

            # Else, use it as a canonicalization key and lookup the user info
            my $key = $config->{'attr_map'}->{$rt_attr};
            my $value = $args->{$rt_attr};

            # Check to see that the key being asked for is defined in the config's attr_map
            my $valid = 0;
            my ($attr_key, $attr_value);
            my $attr_map = $config->{'attr_map'};
            while (($attr_key, $attr_value) = each %$attr_map) {
                $valid = 1 if ($key eq $attr_value);
            }
            unless ($valid){
                $RT::Logger->debug( "This key (",
                                    $key,
                                    "is not a valid attribute key (",
                                    $service,
                                    ")");
                next;
            }

            # Use an if/elsif structure to do a lookup with any custom code needed
            # for any given type of external service, or die if no code exists for
            # the service requested.

            if($config->{'type'} eq 'ldap'){
                ($found, %params) = RT::Authen::ExternalAuth::LDAP::CanonicalizeUserInfo($service,$key,$value);
            } elsif ($config->{'type'} eq 'db') {
                ($found, %params) = RT::Authen::ExternalAuth::DBI::CanonicalizeUserInfo($service,$key,$value);
            }

            # Don't Check any more attributes
            last if $found;
        }
        # Don't Check any more services
        last if $found;
    }

    # If found, Canonicalize Email Address and
    # update the args hash that we were given the hashref for
    if ($found) {
        # It's important that we always have a canonical email address
        if ($params{'EmailAddress'}) {
            $params{'EmailAddress'} = $UserObj->CanonicalizeEmailAddress($params{'EmailAddress'});
        }
        %$args = (%$args, %params);
    }

    $RT::Logger->info(  (caller(0))[3],
                        "returning",
                        join(", ", map {sprintf("%s: %s", $_, ($args->{$_} ? $args->{$_} : ''))}
                            sort(keys(%$args))));

    ### HACK: The config var below is to overcome the (IMO) bug in
    ### RT::User::Create() which expects this function to always
    ### return true or rejects the user for creation. This should be
    ### a different config var (CreateUncanonicalizedUsers) and
    ### should be honored in RT::User::Create()
    return($found || RT->Config->Get('AutoCreateNonExternalUsers'));

}

=head2 Password and authentication related functions

=head3 SetRandomPassword

Takes no arguments. Returns a status code and a new password or an error message.
If the status is 1, the second value returned is the new password.
If the status is anything else, the new value returned is the error code.

=cut

sub SetRandomPassword {
    my $self = shift;

    unless ( $self->CurrentUserCanModify('Password') ) {
        return ( 0, $self->loc("Permission Denied") );
    }


    my $min = ( RT->Config->Get('MinimumPasswordLength') > 6 ?  RT->Config->Get('MinimumPasswordLength') : 6);
    my $max = ( RT->Config->Get('MinimumPasswordLength') > 8 ?  RT->Config->Get('MinimumPasswordLength') : 8);

    my $pass = $self->GenerateRandomPassword( $min, $max) ;

    # If we have "notify user on

    my ( $val, $msg ) = $self->SetPassword($pass);

    #If we got an error return the error.
    return ( 0, $msg ) unless ($val);

    #Otherwise, we changed the password, lets return it.
    return ( 1, $pass );

}

=head3 ResetPassword

Returns status, [ERROR or new password].  Resets this user's password to
a randomly generated pronouncable password and emails them, using a
global template called "PasswordChange".

This function is currently unused in the UI, but available for local scripts.

=cut

sub ResetPassword {
    my $self = shift;

    unless ( $self->CurrentUserCanModify('Password') ) {
        return ( 0, $self->loc("Permission Denied") );
    }
    my ( $status, $pass ) = $self->SetRandomPassword();

    unless ($status) {
        return ( 0, "$pass" );
    }

    my $ret = RT::Interface::Email::SendEmailUsingTemplate(
        To        => $self->EmailAddress,
        Template  => 'PasswordChange',
        Arguments => {
            NewPassword => $pass,
        },
    );

    if ($ret) {
        return ( 1, $self->loc('New password notification sent') );
    } else {
        return ( 0, $self->loc('Notification could not be sent') );
    }

}

=head3 GenerateRandomPassword MIN_LEN and MAX_LEN

Returns a random password between MIN_LEN and MAX_LEN characters long.

=cut

sub GenerateRandomPassword {
    my $self = shift;   # just to drop it
    return Text::Password::Pronounceable->generate(@_);
}

sub SafeSetPassword {
    my $self = shift;
    my %args = (
        Current      => undef,
        New          => undef,
        Confirmation => undef,
        @_,
    );
    return (1) unless defined $args{'New'} && length $args{'New'};

    my %cond = $self->CurrentUserRequireToSetPassword;

    unless ( $cond{'CanSet'} ) {
        return (0, $self->loc('You can not set password.') .' '. $cond{'Reason'} );
    }

    my $error = '';
    if ( $cond{'RequireCurrent'} && !$self->CurrentUser->IsPassword($args{'Current'}) ) {
        if ( defined $args{'Current'} && length $args{'Current'} ) {
            $error = $self->loc("Please enter your current password correctly.");
        } else {
            $error = $self->loc("Please enter your current password.");
        }
    } elsif ( $args{'New'} ne $args{'Confirmation'} ) {
        $error = $self->loc("Passwords do not match.");
    }

    if ( $error ) {
        $error .= ' '. $self->loc('Password has not been set.');
        return (0, $error);
    }

    return $self->SetPassword( $args{'New'} );
}

=head3 SetPassword

Takes a string. Checks the string's length and sets this user's password
to that string.

=cut

sub SetPassword {
    my $self     = shift;
    my $password = shift;

    unless ( $self->CurrentUserCanModify('Password') ) {
        return ( 0, $self->loc('Password: Permission Denied') );
    }

    if ( !$password ) {
        return ( 0, $self->loc("No password set") );
    } else {
        my ($val, $msg) = $self->ValidatePassword($password);
        return ($val, $msg) if !$val;

        my $new = !$self->HasPassword;
        $password = $self->_GeneratePassword($password);

        ( $val, $msg ) = $self->_Set(Field => 'Password', Value => $password);
        if ($val) {
            return ( 1, $self->loc("Password set") ) if $new;
            return ( 1, $self->loc("Password changed") );
        } else {
            return ( $val, $msg );
        }
    }

}

sub _GeneratePassword_bcrypt {
    my $self = shift;
    my ($password, @rest) = @_;

    my $salt;
    my $rounds;
    if (@rest) {
        # The first split is the number of rounds
        $rounds = $rest[0];

        # The salt is the first 22 characters, b64 encoded usign the
        # special bcrypt base64.
        $salt = Crypt::Eksblowfish::Bcrypt::de_base64( substr($rest[1], 0, 22) );
    } else {
        $rounds = RT->Config->Get('BcryptCost');

        # Generate a random 16-octet base64 salt
        $salt = "";
        $salt .= pack("C", int rand(256)) for 1..16;
    }

    my $hash = Crypt::Eksblowfish::Bcrypt::bcrypt_hash({
        key_nul => 1,
        cost    => $rounds,
        salt    => $salt,
    }, Digest::SHA::sha512( Encode::encode( 'UTF-8', $password) ) );

    return join("!", "", "bcrypt", sprintf("%02d", $rounds),
                Crypt::Eksblowfish::Bcrypt::en_base64( $salt ).
                Crypt::Eksblowfish::Bcrypt::en_base64( $hash )
              );
}

sub _GeneratePassword_sha512 {
    my $self = shift;
    my ($password, $salt) = @_;

    # Generate a 16-character base64 salt
    unless ($salt) {
        $salt = "";
        $salt .= ("a".."z", "A".."Z","0".."9", "+", "/")[rand 64]
            for 1..16;
    }

    my $sha = Digest::SHA->new(512);
    $sha->add($salt);
    $sha->add(Encode::encode( 'UTF-8', $password));
    return join("!", "", "sha512", $salt, $sha->b64digest);
}

=head3 _GeneratePassword PASSWORD [, SALT]

Returns a string to store in the database.  This string takes the form:

   !method!salt!hash

By default, the method is currently C<bcrypt>.

=cut

sub _GeneratePassword {
    my $self = shift;
    return $self->_GeneratePassword_bcrypt(@_);
}

=head3 HasPassword

Returns true if the user has a valid password, otherwise returns false.

=cut

sub HasPassword {
    my $self = shift;
    my $pwd = $self->__Value('Password');
    return undef if !defined $pwd
                    || $pwd eq ''
                    || $pwd eq '*NO-PASSWORD*';
    return 1;
}

=head3 IsPassword

Returns true if the passed in value is this user's password.
Returns undef otherwise.

=cut

sub IsPassword {
    my $self  = shift;
    my $value = shift;

    #TODO there isn't any apparent way to legitimately ACL this

    # RT does not allow null passwords
    if ( ( !defined($value) ) or ( $value eq '' ) ) {
        return (undef);
    }

   if ( $self->PrincipalObj->Disabled ) {
        $RT::Logger->info(
            "Disabled user " . $self->Name . " tried to log in" );
        return (undef);
    }

    unless ($self->HasPassword) {
        return(undef);
     }

    my $stored = $self->__Value('Password');
    if ($stored =~ /^!/) {
        # If it's a new-style (>= RT 4.0) password, it starts with a '!'
        my (undef, $method, @rest) = split /!/, $stored;
        if ($method eq "bcrypt") {
            return 0 unless RT::Util::constant_time_eq(
                $self->_GeneratePassword_bcrypt($value, @rest),
                $stored
            );
            # Upgrade to a larger number of rounds if necessary
            return 1 unless $rest[0] < RT->Config->Get('BcryptCost');
        } elsif ($method eq "sha512") {
            return 0 unless RT::Util::constant_time_eq(
                $self->_GeneratePassword_sha512($value, @rest),
                $stored
            );
        } else {
            $RT::Logger->warn("Unknown hash method $method");
            return 0;
        }
    } elsif (length $stored == 40) {
        # The truncated SHA256(salt,MD5(passwd)) form from 2010/12 is 40 characters long
        my $hash = MIME::Base64::decode_base64($stored);
        # Decoding yields 30 byes; first 4 are the salt, the rest are substr(SHA256,0,26)
        my $salt = substr($hash, 0, 4, "");
        return 0 unless RT::Util::constant_time_eq(
            substr(Digest::SHA::sha256($salt . Digest::MD5::md5(Encode::encode( "UTF-8", $value))), 0, 26),
            $hash, 1
        );
    } elsif (length $stored == 32) {
        # Hex nonsalted-md5
        return 0 unless RT::Util::constant_time_eq(
            Digest::MD5::md5_hex(Encode::encode( "UTF-8", $value)),
            $stored
        );
    } elsif (length $stored == 22) {
        # Base64 nonsalted-md5
        return 0 unless RT::Util::constant_time_eq(
            Digest::MD5::md5_base64(Encode::encode( "UTF-8", $value)),
            $stored
        );
    } elsif (length $stored == 13) {
        # crypt() output
        return 0 unless RT::Util::constant_time_eq(
            crypt(Encode::encode( "UTF-8", $value), $stored),
            $stored
        );
    } else {
        $RT::Logger->warning("Unknown password form");
        return 0;
    }

    # We got here by validating successfully, but with a legacy
    # password form.  Update to the most recent form.
    my $obj = $self->isa("RT::CurrentUser") ? $self->UserObj : $self;
    $obj->_Set(Field => 'Password', Value =>  $self->_GeneratePassword($value) );
    return 1;
}

sub CurrentUserRequireToSetPassword {
    my $self = shift;

    my %res = (
        CanSet => 1,
        Reason => '',
        RequireCurrent => 1,
    );

    if ( RT->Config->Get('WebRemoteUserAuth')
        && !RT->Config->Get('WebFallbackToRTLogin')
    ) {
        $res{'CanSet'} = 0;
        $res{'Reason'} = $self->loc("External authentication enabled.");
    } elsif ( !$self->CurrentUser->HasPassword ) {
        if ( $self->CurrentUser->id == ($self->id||0) ) {
            # don't require current password if user has no
            $res{'RequireCurrent'} = 0;
        } else {
            $res{'CanSet'} = 0;
            $res{'Reason'} = $self->loc("Your password is not set.");
        }
    }

    return %res;
}

=head3 AuthToken

Returns an authentication string associated with the user. This
string can be used to generate passwordless URLs to integrate
RT with services and programms like callendar managers, rss
readers and other.

=cut

sub AuthToken {
    my $self = shift;
    my $secret = $self->_Value( AuthToken => @_ );
    return $secret if $secret;

    $secret = substr(Digest::MD5::md5_hex(time . {} . rand()),0,16);

    my $tmp = RT::User->new( RT->SystemUser );
    $tmp->Load( $self->id );
    my ($status, $msg) = $tmp->SetAuthToken( $secret );
    unless ( $status ) {
        $RT::Logger->error( "Couldn't set auth token: $msg" );
        return undef;
    }
    return $secret;
}

=head3 GenerateAuthToken

Generate a random authentication string for the user.

=cut

sub GenerateAuthToken {
    my $self = shift;
    my $token = substr(Digest::MD5::md5_hex(time . {} . rand()),0,16);
    return $self->SetAuthToken( $token );
}

=head3 GenerateAuthString

Takes a string and returns back a hex hash string. Later you can use
this pair to make sure it's generated by this user using L</ValidateAuthString>

=cut

sub GenerateAuthString {
    my $self = shift;
    my $protect = shift;

    my $str = Encode::encode( "UTF-8", $self->AuthToken . $protect );

    return substr(Digest::MD5::md5_hex($str),0,16);
}

=head3 ValidateAuthString

Takes auth string and protected string. Returns true if protected string
has been protected by user's L</AuthToken>. See also L</GenerateAuthString>.

=cut

sub ValidateAuthString {
    my $self = shift;
    my $auth_string_to_validate = shift;
    my $protected = shift;

    my $str = Encode::encode( "UTF-8", $self->AuthToken . $protected );
    my $valid_auth_string = substr(Digest::MD5::md5_hex($str),0,16);

    return RT::Util::constant_time_eq( $auth_string_to_validate, $valid_auth_string );
}

=head2 SetDisabled

Toggles the user's disabled flag.
If this flag is
set, all password checks for this user will fail. All ACL checks for this
user will fail. The user will appear in no user listings.

=cut

sub SetDisabled {
    my $self = shift;
    my $val = shift;
    unless ( $self->CurrentUser->HasRight(Right => 'AdminUsers', Object => $RT::System) ) {
        return (0, $self->loc('Permission Denied'));
    }

    $RT::Handle->BeginTransaction();
    my ($status, $msg) = $self->PrincipalObj->SetDisabled($val);
    unless ($status) {
        $RT::Handle->Rollback();
        $RT::Logger->warning(sprintf("Couldn't %s user %s", ($val == 1) ? "disable" : "enable", $self->PrincipalObj->Id));
        return ($status, $msg);
    }
    $self->_NewTransaction( Type => ($val == 1) ? "Disabled" : "Enabled" );

    $RT::Handle->Commit();

    if ( $val == 1 ) {
        return (1, $self->loc("User disabled"));
    } else {
        return (1, $self->loc("User enabled"));
    }

}

=head2 Disabled

Returns true if user is disabled or false otherwise

=cut

sub Disabled {
    my $self = shift;
    return $self->PrincipalObj->Disabled(@_);
}

=head2 PrincipalObj

Returns the principal object for this user. returns an empty RT::Principal
if there's no principal object matching this user.
The response is cached. PrincipalObj should never ever change.

=cut

sub PrincipalObj {
    my $self = shift;

    unless ( $self->id ) {
        $RT::Logger->error("Couldn't get principal for an empty user");
        return undef;
    }

    if ( !$self->{_principal_obj} ) {

        my $obj = RT::Principal->new( $self->CurrentUser );
        $obj->LoadById( $self->id );
        if (! $obj->id ) {
            $RT::Logger->crit( 'No principal for user #' . $self->id );
            return undef;
        } elsif ( $obj->PrincipalType ne 'User' ) {
            $RT::Logger->crit(   'User #' . $self->id . ' has principal of ' . $obj->PrincipalType . ' type' );
            return undef;
        }
        $self->{_principal_obj} = $obj;
    }
    return $self->{_principal_obj};
}


=head2 PrincipalId

Returns this user's PrincipalId

=cut

sub PrincipalId {
    my $self = shift;
    return $self->Id;
}

=head2 HasGroupRight

Takes a paramhash which can contain
these items:
    GroupObj => RT::Group or Group => integer
    Right => 'Right'


Returns 1 if this user has the right specified in the paramhash for the Group
passed in.

Returns undef if they don't.

=cut

sub HasGroupRight {
    my $self = shift;
    my %args = (
        GroupObj    => undef,
        Group       => undef,
        Right       => undef,
        @_
    );


    if ( defined $args{'Group'} ) {
        $args{'GroupObj'} = RT::Group->new( $self->CurrentUser );
        $args{'GroupObj'}->Load( $args{'Group'} );
    }

    # Validate and load up the GroupId
    unless ( ( defined $args{'GroupObj'} ) and ( $args{'GroupObj'}->Id ) ) {
        return undef;
    }

    # Figure out whether a user has the right we're asking about.
    my $retval = $self->HasRight(
        Object => $args{'GroupObj'},
        Right     => $args{'Right'},
    );

    return ($retval);
}

=head2 OwnGroups

Returns a group collection object containing the groups of which this
user is a member.

=cut

sub OwnGroups {
    my $self = shift;
    my $groups = RT::Groups->new($self->CurrentUser);
    $groups->LimitToUserDefinedGroups;
    $groups->WithMember(
        PrincipalId => $self->Id,
        Recursively => 1
    );
    return $groups;
}

=head2 HasRight

Shim around PrincipalObj->HasRight. See L<RT::Principal>.

=cut

sub HasRight {
    my $self = shift;
    return $self->PrincipalObj->HasRight(@_);
}

=head2 CurrentUserCanSee [FIELD]

Returns true if the current user can see the user, based on if it is
public, ourself, or we have AdminUsers

=cut

sub CurrentUserCanSee {
    my $self = shift;
    my ($what, $txn) = @_;

    # If it's a public property, fine
    return 1 if $self->_Accessible( $what, 'public' );

    # Users can see all of their own properties
    return 1 if defined($self->Id) and $self->CurrentUser->Id == $self->Id;

    # If the user has the admin users right, that's also enough
    return 1 if $self->CurrentUserHasRight( 'AdminUsers' );

    # Transactions of public properties are visible to users with ShowUserHistory
    if ($what eq "Transaction" and $self->CurrentUserHasRight( 'ShowUserHistory' )) {
        my $type = $txn->__Value('Type');
        my $field = $txn->__Value('Field');
        return 1 if $type eq "Set" and $self->CurrentUserCanSee($field, $txn);

        # RT::Transaction->CurrentUserCanSee deals with ensuring we meet
        # the ACLs on CFs, so allow them here
        return 1 if $type eq "CustomField";
    }

    return 0;
}

=head2 CurrentUserCanModify RIGHT

If the user has rights for this object, either because
he has 'AdminUsers' or (if he's trying to edit himself and the right isn't an
admin right) 'ModifySelf', return 1. otherwise, return undef.

=cut

sub CurrentUserCanModify {
    my $self  = shift;
    my $field = shift;

    if ( $self->CurrentUser->HasRight(Right => 'AdminUsers', Object => $RT::System) ) {
        return (1);
    }

    #If the field is marked as an "administrators only" field,
    # don't let the user touch it.
    elsif ( $self->_Accessible( $field, 'admin' ) ) {
        return (undef);
    }

    #If the current user is trying to modify themselves
    elsif ( ( $self->id == $self->CurrentUser->id )
        and ( $self->CurrentUser->HasRight(Right => 'ModifySelf', Object => $RT::System) ) )
    {
        return (1);
    }

    #If we don't have a good reason to grant them rights to modify
    # by now, they lose
    else {
        return (undef);
    }

}

=head2 CurrentUserHasRight

Takes a single argument. returns 1 if $Self->CurrentUser
has the requested right. returns undef otherwise

=cut

sub CurrentUserHasRight {
    my $self  = shift;
    my $right = shift;

    return ( $self->CurrentUser->HasRight(Right => $right, Object => $RT::System) );
}

sub _PrefName {
    my $name = shift;
    if (ref $name) {
        $name = ref($name).'-'.$name->Id;
    }

    return 'Pref-'. $name;
}

=head2 Preferences NAME/OBJ DEFAULT

Obtain user preferences associated with given object or name.
Returns DEFAULT if no preferences found.  If DEFAULT is a hashref,
override the entries with user preferences.

=cut

sub Preferences {
    my $self  = shift;
    my $name = _PrefName(shift);
    my $default = shift;

    my ($attr) = $self->Attributes->Named( $name );
    my $content = $attr ? $attr->Content : undef;
    unless ( ref $content eq 'HASH' ) {
        return defined $content ? $content : $default;
    }

    if (ref $default eq 'HASH') {
        for (keys %$default) {
            exists $content->{$_} or $content->{$_} = $default->{$_};
        }
    } elsif (defined $default) {
        $RT::Logger->error("Preferences $name for user #".$self->Id." is hash but default is not");
    }
    return $content;
}

=head2 SetPreferences NAME/OBJ VALUE

Set user preferences associated with given object or name.

=cut

sub SetPreferences {
    my $self = shift;
    my $name = _PrefName( shift );
    my $value = shift;

    return (0, $self->loc("No permission to set preferences"))
        unless $self->CurrentUserCanModify('Preferences');

    my ($attr) = $self->Attributes->Named( $name );
    if ( $attr ) {
        my ($ok, $msg) = $attr->SetContent( $value );
        return (1, "No updates made")
            if $msg eq "That is already the current value";
        return ($ok, $msg);
    } else {
        return $self->AddAttribute( Name => $name, Content => $value );
    }
}

=head2 DeletePreferences NAME/OBJ VALUE

Delete user preferences associated with given object or name.

=cut

sub DeletePreferences {
    my $self = shift;
    my $name = _PrefName( shift );

    return (0, $self->loc("No permission to set preferences"))
        unless $self->CurrentUserCanModify('Preferences');

    my ($attr) = $self->DeleteAttribute( $name );
    return (0, $self->loc("Preferences were not found"))
        unless $attr;

    return 1;
}

=head2 Stylesheet

Returns a list of valid stylesheets take from preferences.

=cut

sub Stylesheet {
    my $self = shift;

    my $style = RT->Config->Get('WebDefaultStylesheet', $self->CurrentUser);

    if (RT::Interface::Web->ComponentPathIsSafe($style)) {
        for my $root (RT::Interface::Web->StaticRoots) {
            if (-d "$root/css/$style") {
                return $style
            }
        }
    }

    # Fall back to the system stylesheet.
    return RT->Config->Get('WebDefaultStylesheet');
}

=head2 WatchedQueues ROLE_LIST

Returns a RT::Queues object containing every queue watched by the user.

Takes a list of roles which is some subset of ('Cc', 'AdminCc').  Defaults to:

$user->WatchedQueues('Cc', 'AdminCc');

=cut

sub WatchedQueues {

    my $self = shift;
    my @roles = @_ ? @_ : ('Cc', 'AdminCc');

    $RT::Logger->debug('WatcheQueues got user ' . $self->Name);

    my $watched_queues = RT::Queues->new($self->CurrentUser);

    my $group_alias = $watched_queues->Join(
                                             ALIAS1 => 'main',
                                             FIELD1 => 'id',
                                             TABLE2 => 'Groups',
                                             FIELD2 => 'Instance',
                                           );

    $watched_queues->Limit(
                            ALIAS => $group_alias,
                            FIELD => 'Domain',
                            VALUE => 'RT::Queue-Role',
                            ENTRYAGGREGATOR => 'AND',
                            CASESENSITIVE => 0,
                          );
    if (grep { $_ eq 'Cc' } @roles) {
        $watched_queues->Limit(
                                SUBCLAUSE => 'LimitToWatchers',
                                ALIAS => $group_alias,
                                FIELD => 'Name',
                                VALUE => 'Cc',
                                ENTRYAGGREGATOR => 'OR',
                              );
    }
    if (grep { $_ eq 'AdminCc' } @roles) {
        $watched_queues->Limit(
                                SUBCLAUSE => 'LimitToWatchers',
                                ALIAS => $group_alias,
                                FIELD => 'Name',
                                VALUE => 'AdminCc',
                                ENTRYAGGREGATOR => 'OR',
                              );
    }

    my $queues_alias = $watched_queues->Join(
                                              ALIAS1 => $group_alias,
                                              FIELD1 => 'id',
                                              TABLE2 => 'CachedGroupMembers',
                                              FIELD2 => 'GroupId',
                                            );
    $watched_queues->Limit(
                            ALIAS => $queues_alias,
                            FIELD => 'MemberId',
                            VALUE => $self->PrincipalId,
                          );
    $watched_queues->Limit(
                            ALIAS => $queues_alias,
                            FIELD => 'Disabled',
                            VALUE => 0,
                          );


    $RT::Logger->debug("WatchedQueues got " . $watched_queues->Count . " queues");

    return $watched_queues;

}

sub _Set {
    my $self = shift;

    my %args = (
        Field => undef,
        Value => undef,
    TransactionType   => 'Set',
    RecordTransaction => 1,
        @_
    );

    # Nobody is allowed to futz with RT_System or Nobody

    if ( ($self->Id == RT->SystemUser->Id )  ||
         ($self->Id == RT->Nobody->Id)) {
        return ( 0, $self->loc("Can not modify system users") );
    }
    unless ( $self->CurrentUserCanModify( $args{'Field'} ) ) {
        return ( 0, $self->loc("Permission Denied") );
    }

    my $Old = $self->SUPER::_Value("$args{'Field'}");

    my ($ret, $msg) = $self->SUPER::_Set( Field => $args{'Field'},
                      Value => $args{'Value'} );

    #If we can't actually set the field to the value, don't record
    # a transaction. instead, get out of here.
    if ( $ret == 0 ) { return ( 0, $msg ); }

    if ( $args{'RecordTransaction'} == 1 ) {
        if ($args{'Field'} eq "Password") {
            $args{'Value'} = $Old = '********';
        }
        my ( $Trans, $Msg, $TransObj ) = $self->_NewTransaction(
                                               Type => $args{'TransactionType'},
                                               Field     => $args{'Field'},
                                               NewValue  => $args{'Value'},
                                               OldValue  => $Old,
                                               TimeTaken => $args{'TimeTaken'},
        );
        return ( $Trans, scalar $TransObj->BriefDescription );
    } else {
        return ( $ret, $msg );
    }
}

=head2 _Value

Takes the name of a table column.
Returns its value as a string, if the user passes an ACL check

=cut

sub _Value {

    my $self  = shift;
    my $field = shift;

    # Defer to the abstraction above to know if the field can be read
    return $self->SUPER::_Value($field) if $self->CurrentUserCanSee($field);
    return undef;
}

=head2 FriendlyName

Return the friendly name

=cut

sub FriendlyName {
    my $self = shift;
    return $self->RealName if defined $self->RealName and length $self->RealName;
    return $self->Name;
}

=head2 Format

Class or object method.

Returns a string describing a user in the current user's preferred format.

May be invoked in three ways:

    $UserObj->Format;
    RT::User->Format( User => $UserObj );   # same as above
    RT::User->Format( Address => $AddressObj, CurrentUser => $CurrentUserObj );

Possible arguments are:

=over

=item User

An L<RT::User> object representing the user to format.  Preferred to Address.

=item Address

An L<Email::Address> object representing the user address to format.  Address
will be used to lookup an L<RT::User> if possible.

=item CurrentUser

Required when Format is called as a class method with an Address argument.
Otherwise, this argument is ignored in preference to the CurrentUser of the
involved L<RT::User> object.

=item Format

Specifies the format to use, overriding any set from the config or current
user's preferences.

=back

=cut

sub Format {
    my $self = shift;
    my %args = (
        User        => undef,
        Address     => undef,
        CurrentUser => undef,
        Format      => undef,
        @_
    );

    if (blessed($self) and $self->id) {
        @args{"User", "CurrentUser"} = ($self, $self->CurrentUser);
    }
    elsif ($args{User} and $args{User}->id) {
        $args{CurrentUser} = $args{User}->CurrentUser;
    }
    elsif ($args{Address} and $args{CurrentUser}) {
        $args{User} = RT::User->new( $args{CurrentUser} );
        $args{User}->LoadByEmail( $args{Address}->address );
        if ($args{User}->id) {
            delete $args{Address};
        } else {
            delete $args{User};
        }
    }
    else {
        RT->Logger->warning("Invalid arguments to RT::User->Format at @{[join '/', caller]}");
        return "";
    }

    $args{Format} ||= RT->Config->Get("UsernameFormat", $args{CurrentUser});
    $args{Format} =~ s/[^A-Za-z0-9_]+//g;

    my $method    = "_FormatUser" . ucfirst lc $args{Format};
    my $formatter = $self->can($method);

    unless ($formatter) {
        RT->Logger->error(
            "Either system config or user #" . $args{CurrentUser}->id .
            " picked UsernameFormat $args{Format}, but RT::User->$method doesn't exist"
        );
        $formatter = $self->can("_FormatUserRole");
    }
    return $formatter->( $self, map { $_ => $args{$_} } qw(User Address) );
}

sub _FormatUserRole {
    my $self = shift;
    my %args = @_;

    my $user = $args{User};
    return $self->_FormatUserVerbose(@_)
        unless $user and $user->Privileged;

    my $name = $user->Name;
    $name .= " (".$user->RealName.")"
        if $user->RealName and lc $user->RealName ne lc $user->Name;
    return $name;
}

sub _FormatUserConcise {
    my $self = shift;
    my %args = @_;
    return $args{User} ? $args{User}->FriendlyName : $args{Address}->address;
}

sub _FormatUserVerbose {
    my $self = shift;
    my %args = @_;
    my ($user, $address) = @args{"User", "Address"};

    my $email   = '';
    my $phrase  = '';
    my $comment = '';

    if ($user) {
        $email   = $user->EmailAddress || '';
        $phrase  = $user->RealName  if $user->RealName and lc $user->RealName ne lc $email;
        $comment = $user->Name      if lc $user->Name ne lc $email;
    } else {
        ($email, $phrase, $comment) = (map { $address->$_ } "address", "phrase", "comment");
    }

    return join " ", grep { $_ } ($phrase || $comment || ''), ($email ? "<$email>" : "");
}

=head2 PreferredKey

Returns the preferred key of the user. If none is set, then this will query
GPG and set the preferred key to the maximally trusted key found (and then
return it). Returns C<undef> if no preferred key can be found.

=cut

sub PreferredKey
{
    my $self = shift;
    return undef unless RT->Config->Get('GnuPG')->{'Enable'};

    if ( ($self->CurrentUser->Id != $self->Id )  &&
          !$self->CurrentUser->HasRight(Right =>'AdminUsers', Object => $RT::System) ) {
          return undef;
    }



    my $prefkey = $self->FirstAttribute('PreferredKey');
    return $prefkey->Content if $prefkey;

    # we don't have a preferred key for this user, so now we must query GPG
    my %res = RT::Crypt->GetKeysForEncryption($self->EmailAddress);
    return undef unless defined $res{'info'};
    my @keys = @{ $res{'info'} };
    return undef if @keys == 0;

    if (@keys == 1) {
        $prefkey = $keys[0]->{'Fingerprint'};
    } else {
        # prefer the maximally trusted key
        @keys = sort { $b->{'TrustLevel'} <=> $a->{'TrustLevel'} } @keys;
        $prefkey = $keys[0]->{'Fingerprint'};
    }

    $self->SetAttribute(Name => 'PreferredKey', Content => $prefkey);
    return $prefkey;
}

sub PrivateKey {
    my $self = shift;


    #If the user wants to see their own values, let them.
    #If the user is an admin, let them.
    #Otherwwise, don't let them.
    #
    if ( ($self->CurrentUser->Id != $self->Id )  &&
          !$self->CurrentUser->HasRight(Right =>'AdminUsers', Object => $RT::System) ) {
          return undef;
    }

    my $key = $self->FirstAttribute('PrivateKey') or return undef;
    return $key->Content;
}

sub SetPrivateKey {
    my $self = shift;
    my $key = shift;

    # Users should not be able to change their own PrivateKey values
    unless ( $self->CurrentUser->HasRight(Right => 'AdminUsers', Object => $RT::System) ) {
        return (0, $self->loc("Permission Denied"));
    }

    unless ( $key ) {
        my ($status, $msg) = $self->DeleteAttribute('PrivateKey');
        unless ( $status ) {
            $RT::Logger->error( "Couldn't delete attribute: $msg" );
            return ($status, $self->loc("Couldn't unset private key"));
        }
        return ($status, $self->loc("Unset private key"));
    }

    # check that it's really private key
    {
        my %tmp = RT::Crypt->GetKeysForSigning( Signer => $key, Protocol => 'GnuPG' );
        return (0, $self->loc("No such key or it's not suitable for signing"))
            if $tmp{'exit_code'} || !$tmp{'info'};
    }

    my ($status, $msg) = $self->SetAttribute(
        Name => 'PrivateKey',
        Content => $key,
    );
    return ($status, $self->loc("Couldn't set private key"))
        unless $status;
    return ($status, $self->loc("Set private key"));
}

sub SetLang {
    my $self = shift;
    my ($lang) = @_;

    unless ($self->CurrentUserCanModify('Lang')) {
        return (0, $self->loc("Permission Denied"));
    }

    # Local hack to cause the result message to be in the _new_ language
    # if we're updating ourselves
    $self->CurrentUser->{LangHandle} = RT::I18N->get_handle( $lang )
        if $self->CurrentUser->id == $self->id;
    return $self->_Set( Field => 'Lang', Value => $lang );
}

sub BasicColumns {
    (
    [ Name => 'Username' ],
    [ EmailAddress => 'Email' ],
    [ RealName => 'Name' ],
    [ Organization => 'Organization' ],
    );
}

=head2 Bookmarks

Returns an unordered list of IDs representing the user's bookmarked tickets.

=cut

sub Bookmarks {
    my $self = shift;
    my $bookmarks = $self->FirstAttribute('Bookmarks');
    return if !$bookmarks;

    $bookmarks = $bookmarks->Content;
    return if !$bookmarks;

    return keys %$bookmarks;
}

=head2 HasBookmark TICKET

Returns whether the provided ticket is bookmarked by the user.

=cut

sub HasBookmark {
    my $self   = shift;
    my $ticket = shift;
    my $id     = $ticket->id;

    # maintain bookmarks across merges
    my @ids = ($id, $ticket->Merged);

    my $bookmarks = $self->FirstAttribute('Bookmarks');
    $bookmarks = $bookmarks ? $bookmarks->Content : {};

    my @bookmarked = grep { $bookmarks->{ $_ } } @ids;
    return @bookmarked ? 1 : 0;
}

=head2 ToggleBookmark TICKET

Toggles whether the provided ticket is bookmarked by the user.

=cut

sub ToggleBookmark {
    my $self   = shift;
    my $ticket = shift;
    my $id     = $ticket->id;

    # maintain bookmarks across merges
    my @ids = ($id, $ticket->Merged);

    my $bookmarks = $self->FirstAttribute('Bookmarks');
    $bookmarks = $bookmarks ? $bookmarks->Content : {};

    my $is_bookmarked;

    if ( grep { $bookmarks->{ $_ } } @ids ) {
        delete $bookmarks->{ $_ } foreach @ids;
        $is_bookmarked = 0;
    } else {
        $bookmarks->{ $id } = 1;
        $is_bookmarked = 1;
    }

    $self->SetAttribute(
        Name    => 'Bookmarks',
        Content => $bookmarks,
    );

    return $is_bookmarked;
}

=head2 RecentlyViewedTickets TICKET

Returns a list of two-element (ticket id, timestamp) array references ordered by recently viewed first.

=cut

sub RecentlyViewedTickets {
    my $self = shift;
    my $content = $self->FirstAttribute('RecentlyViewedTickets');
    return $content ? @{$content->Content} : ();
}

=head2 AddRecentlyViewedTicket TICKET

Takes an RT::Ticket object and adds it to the current user's RecentlyViewedTickets

=cut

sub AddRecentlyViewedTicket {
    my $self   = shift;
    my $ticket = shift;

    my $maxCount = 10; #The max number of tickets to keep

    #Nothing to do without a ticket
    return unless $ticket->Id;

    my @recentTickets;
    my $content = $self->FirstAttribute('RecentlyViewedTickets');
    $content = $content ? $content->Content : [];
    if (defined $content) {
        @recentTickets = @$content;
    }

    my @tickets;
    my $i = 0;
    for (@recentTickets) {
        my ($ticketId, $timestamp) = @$_;
        
        #Skip the ticket if it exists in recents already
        if ($ticketId != $ticket->Id) {
            push @tickets, $_;
            if ($i >= $maxCount - 1) {
                last;
            }
        }
        $i++;
    }

    #Add the new ticket
    unshift @tickets, [$ticket->Id, time()];

    $self->SetAttribute(
        Name    => 'RecentlyViewedTickets',
        Content => \@tickets,
    );
}

=head2 Create PARAMHASH

Create takes a hash of values and creates a row in the database:

  varchar(200) 'Name'.
  varbinary(256) 'Password'.
  varchar(16) 'AuthToken'.
  text 'Comments'.
  text 'Signature'.
  varchar(120) 'EmailAddress'.
  text 'FreeformContactInfo'.
  varchar(200) 'Organization'.
  varchar(120) 'RealName'.
  varchar(16) 'NickName'.
  varchar(16) 'Lang'.
  varchar(16) 'Gecos'.
  varchar(30) 'HomePhone'.
  varchar(30) 'WorkPhone'.
  varchar(30) 'MobilePhone'.
  varchar(30) 'PagerPhone'.
  varchar(200) 'Address1'.
  varchar(200) 'Address2'.
  varchar(100) 'City'.
  varchar(100) 'State'.
  varchar(16) 'Zip'.
  varchar(50) 'Country'.
  varchar(50) 'Timezone'.

=cut




=head2 id

Returns the current value of id. 
(In the database, id is stored as int(11).)


=cut


=head2 Name

Returns the current value of Name. 
(In the database, Name is stored as varchar(200).)



=head2 SetName VALUE


Set Name to VALUE. 
Returns (1, 'Status message') on success and (0, 'Error Message') on failure.
(In the database, Name will be stored as a varchar(200).)


=cut


=head2 Password

Returns the current value of Password. 
(In the database, Password is stored as varchar(256).)



=head2 SetPassword VALUE


Set Password to VALUE. 
Returns (1, 'Status message') on success and (0, 'Error Message') on failure.
(In the database, Password will be stored as a varchar(256).)


=cut


=head2 AuthToken

Returns the current value of AuthToken. 
(In the database, AuthToken is stored as varchar(16).)



=head2 SetAuthToken VALUE


Set AuthToken to VALUE. 
Returns (1, 'Status message') on success and (0, 'Error Message') on failure.
(In the database, AuthToken will be stored as a varchar(16).)


=cut


=head2 Comments

Returns the current value of Comments. 
(In the database, Comments is stored as text.)



=head2 SetComments VALUE


Set Comments to VALUE. 
Returns (1, 'Status message') on success and (0, 'Error Message') on failure.
(In the database, Comments will be stored as a text.)


=cut


=head2 Signature

Returns the current value of Signature. 
(In the database, Signature is stored as text.)



=head2 SetSignature VALUE


Set Signature to VALUE. 
Returns (1, 'Status message') on success and (0, 'Error Message') on failure.
(In the database, Signature will be stored as a text.)


=cut


=head2 EmailAddress

Returns the current value of EmailAddress. 
(In the database, EmailAddress is stored as varchar(120).)



=head2 SetEmailAddress VALUE


Set EmailAddress to VALUE. 
Returns (1, 'Status message') on success and (0, 'Error Message') on failure.
(In the database, EmailAddress will be stored as a varchar(120).)


=cut


=head2 FreeformContactInfo

Returns the current value of FreeformContactInfo. 
(In the database, FreeformContactInfo is stored as text.)



=head2 SetFreeformContactInfo VALUE


Set FreeformContactInfo to VALUE. 
Returns (1, 'Status message') on success and (0, 'Error Message') on failure.
(In the database, FreeformContactInfo will be stored as a text.)


=cut


=head2 Organization

Returns the current value of Organization. 
(In the database, Organization is stored as varchar(200).)



=head2 SetOrganization VALUE


Set Organization to VALUE. 
Returns (1, 'Status message') on success and (0, 'Error Message') on failure.
(In the database, Organization will be stored as a varchar(200).)


=cut


=head2 RealName

Returns the current value of RealName. 
(In the database, RealName is stored as varchar(120).)



=head2 SetRealName VALUE


Set RealName to VALUE. 
Returns (1, 'Status message') on success and (0, 'Error Message') on failure.
(In the database, RealName will be stored as a varchar(120).)


=cut


=head2 NickName

Returns the current value of NickName. 
(In the database, NickName is stored as varchar(16).)



=head2 SetNickName VALUE


Set NickName to VALUE. 
Returns (1, 'Status message') on success and (0, 'Error Message') on failure.
(In the database, NickName will be stored as a varchar(16).)


=cut


=head2 Lang

Returns the current value of Lang. 
(In the database, Lang is stored as varchar(16).)



=head2 SetLang VALUE


Set Lang to VALUE. 
Returns (1, 'Status message') on success and (0, 'Error Message') on failure.
(In the database, Lang will be stored as a varchar(16).)


=cut


=head2 Gecos

Returns the current value of Gecos. 
(In the database, Gecos is stored as varchar(16).)



=head2 SetGecos VALUE


Set Gecos to VALUE. 
Returns (1, 'Status message') on success and (0, 'Error Message') on failure.
(In the database, Gecos will be stored as a varchar(16).)


=cut


=head2 HomePhone

Returns the current value of HomePhone. 
(In the database, HomePhone is stored as varchar(30).)



=head2 SetHomePhone VALUE


Set HomePhone to VALUE. 
Returns (1, 'Status message') on success and (0, 'Error Message') on failure.
(In the database, HomePhone will be stored as a varchar(30).)


=cut


=head2 WorkPhone

Returns the current value of WorkPhone. 
(In the database, WorkPhone is stored as varchar(30).)



=head2 SetWorkPhone VALUE


Set WorkPhone to VALUE. 
Returns (1, 'Status message') on success and (0, 'Error Message') on failure.
(In the database, WorkPhone will be stored as a varchar(30).)


=cut


=head2 MobilePhone

Returns the current value of MobilePhone. 
(In the database, MobilePhone is stored as varchar(30).)



=head2 SetMobilePhone VALUE


Set MobilePhone to VALUE. 
Returns (1, 'Status message') on success and (0, 'Error Message') on failure.
(In the database, MobilePhone will be stored as a varchar(30).)


=cut


=head2 PagerPhone

Returns the current value of PagerPhone. 
(In the database, PagerPhone is stored as varchar(30).)



=head2 SetPagerPhone VALUE


Set PagerPhone to VALUE. 
Returns (1, 'Status message') on success and (0, 'Error Message') on failure.
(In the database, PagerPhone will be stored as a varchar(30).)


=cut


=head2 Address1

Returns the current value of Address1. 
(In the database, Address1 is stored as varchar(200).)



=head2 SetAddress1 VALUE


Set Address1 to VALUE. 
Returns (1, 'Status message') on success and (0, 'Error Message') on failure.
(In the database, Address1 will be stored as a varchar(200).)


=cut


=head2 Address2

Returns the current value of Address2. 
(In the database, Address2 is stored as varchar(200).)



=head2 SetAddress2 VALUE


Set Address2 to VALUE. 
Returns (1, 'Status message') on success and (0, 'Error Message') on failure.
(In the database, Address2 will be stored as a varchar(200).)


=cut


=head2 City

Returns the current value of City. 
(In the database, City is stored as varchar(100).)



=head2 SetCity VALUE


Set City to VALUE. 
Returns (1, 'Status message') on success and (0, 'Error Message') on failure.
(In the database, City will be stored as a varchar(100).)


=cut


=head2 State

Returns the current value of State. 
(In the database, State is stored as varchar(100).)



=head2 SetState VALUE


Set State to VALUE. 
Returns (1, 'Status message') on success and (0, 'Error Message') on failure.
(In the database, State will be stored as a varchar(100).)


=cut


=head2 Zip

Returns the current value of Zip. 
(In the database, Zip is stored as varchar(16).)



=head2 SetZip VALUE


Set Zip to VALUE. 
Returns (1, 'Status message') on success and (0, 'Error Message') on failure.
(In the database, Zip will be stored as a varchar(16).)


=cut


=head2 Country

Returns the current value of Country. 
(In the database, Country is stored as varchar(50).)



=head2 SetCountry VALUE


Set Country to VALUE. 
Returns (1, 'Status message') on success and (0, 'Error Message') on failure.
(In the database, Country will be stored as a varchar(50).)


=cut


=head2 Timezone

Returns the current value of Timezone. 
(In the database, Timezone is stored as varchar(50).)



=head2 SetTimezone VALUE


Set Timezone to VALUE. 
Returns (1, 'Status message') on success and (0, 'Error Message') on failure.
(In the database, Timezone will be stored as a varchar(50).)


=cut


=head2 SMIMECertificate

Returns the current value of SMIMECertificate. 
(In the database, SMIMECertificate is stored as text.)



=head2 SetSMIMECertificate VALUE


Set SMIMECertificate to VALUE. 
Returns (1, 'Status message') on success and (0, 'Error Message') on failure.
(In the database, SMIMECertificate will be stored as a text.)


=cut


=head2 Creator

Returns the current value of Creator. 
(In the database, Creator is stored as int(11).)


=cut


=head2 Created

Returns the current value of Created. 
(In the database, Created is stored as datetime.)


=cut


=head2 LastUpdatedBy

Returns the current value of LastUpdatedBy. 
(In the database, LastUpdatedBy is stored as int(11).)


=cut


=head2 LastUpdated

Returns the current value of LastUpdated. 
(In the database, LastUpdated is stored as datetime.)


=cut



sub _CoreAccessible {
    {
     
        id =>
        {read => 1, sql_type => 4, length => 11,  is_blob => 0,  is_numeric => 1,  type => 'int(11)', default => ''},
        Name => 
        {read => 1, write => 1, sql_type => 12, length => 200,  is_blob => 0,  is_numeric => 0,  type => 'varchar(200)', default => ''},
        Password => 
        {read => 1, write => 1, sql_type => 12, length => 256,  is_blob => 0,  is_numeric => 0,  type => 'varchar(256)', default => ''},
        AuthToken => 
        {read => 1, write => 1, sql_type => 12, length => 16,  is_blob => 0,  is_numeric => 0,  type => 'varchar(16)', default => ''},
        Comments => 
        {read => 1, write => 1, sql_type => -4, length => 0,  is_blob => 1,  is_numeric => 0,  type => 'text', default => ''},
        Signature => 
        {read => 1, write => 1, sql_type => -4, length => 0,  is_blob => 1,  is_numeric => 0,  type => 'text', default => ''},
        EmailAddress => 
        {read => 1, write => 1, sql_type => 12, length => 120,  is_blob => 0,  is_numeric => 0,  type => 'varchar(120)', default => ''},
        FreeformContactInfo => 
        {read => 1, write => 1, sql_type => -4, length => 0,  is_blob => 1,  is_numeric => 0,  type => 'text', default => ''},
        Organization => 
        {read => 1, write => 1, sql_type => 12, length => 200,  is_blob => 0,  is_numeric => 0,  type => 'varchar(200)', default => ''},
        RealName => 
        {read => 1, write => 1, sql_type => 12, length => 120,  is_blob => 0,  is_numeric => 0,  type => 'varchar(120)', default => ''},
        NickName => 
        {read => 1, write => 1, sql_type => 12, length => 16,  is_blob => 0,  is_numeric => 0,  type => 'varchar(16)', default => ''},
        Lang => 
        {read => 1, write => 1, sql_type => 12, length => 16,  is_blob => 0,  is_numeric => 0,  type => 'varchar(16)', default => ''},
        Gecos => 
        {read => 1, write => 1, sql_type => 12, length => 16,  is_blob => 0,  is_numeric => 0,  type => 'varchar(16)', default => ''},
        HomePhone => 
        {read => 1, write => 1, sql_type => 12, length => 30,  is_blob => 0,  is_numeric => 0,  type => 'varchar(30)', default => ''},
        WorkPhone => 
        {read => 1, write => 1, sql_type => 12, length => 30,  is_blob => 0,  is_numeric => 0,  type => 'varchar(30)', default => ''},
        MobilePhone => 
        {read => 1, write => 1, sql_type => 12, length => 30,  is_blob => 0,  is_numeric => 0,  type => 'varchar(30)', default => ''},
        PagerPhone => 
        {read => 1, write => 1, sql_type => 12, length => 30,  is_blob => 0,  is_numeric => 0,  type => 'varchar(30)', default => ''},
        Address1 => 
        {read => 1, write => 1, sql_type => 12, length => 200,  is_blob => 0,  is_numeric => 0,  type => 'varchar(200)', default => ''},
        Address2 => 
        {read => 1, write => 1, sql_type => 12, length => 200,  is_blob => 0,  is_numeric => 0,  type => 'varchar(200)', default => ''},
        City => 
        {read => 1, write => 1, sql_type => 12, length => 100,  is_blob => 0,  is_numeric => 0,  type => 'varchar(100)', default => ''},
        State => 
        {read => 1, write => 1, sql_type => 12, length => 100,  is_blob => 0,  is_numeric => 0,  type => 'varchar(100)', default => ''},
        Zip => 
        {read => 1, write => 1, sql_type => 12, length => 16,  is_blob => 0,  is_numeric => 0,  type => 'varchar(16)', default => ''},
        Country => 
        {read => 1, write => 1, sql_type => 12, length => 50,  is_blob => 0,  is_numeric => 0,  type => 'varchar(50)', default => ''},
        Timezone => 
        {read => 1, write => 1, sql_type => 12, length => 50,  is_blob => 0,  is_numeric => 0,  type => 'varchar(50)', default => ''},
        SMIMECertificate =>
        {read => 1, write => 1, sql_type => -4, length => 0,  is_blob => 1,  is_numeric => 0,  type => 'text', default => ''},
        Creator => 
        {read => 1, auto => 1, sql_type => 4, length => 11,  is_blob => 0,  is_numeric => 1,  type => 'int(11)', default => '0'},
        Created => 
        {read => 1, auto => 1, sql_type => 11, length => 0,  is_blob => 0,  is_numeric => 0,  type => 'datetime', default => ''},
        LastUpdatedBy => 
        {read => 1, auto => 1, sql_type => 4, length => 11,  is_blob => 0,  is_numeric => 1,  type => 'int(11)', default => '0'},
        LastUpdated => 
        {read => 1, auto => 1, sql_type => 11, length => 0,  is_blob => 0,  is_numeric => 0,  type => 'datetime', default => ''},

 }
};

sub UID {
    my $self = shift;
    return undef unless defined $self->Name;
    return "@{[ref $self]}-@{[$self->Name]}";
}

sub FindDependencies {
    my $self = shift;
    my ($walker, $deps) = @_;

    $self->SUPER::FindDependencies($walker, $deps);

    # ACL equivalence group
    my $objs = RT::Groups->new( $self->CurrentUser );
    $objs->Limit( FIELD => 'Domain', VALUE => 'ACLEquivalence', CASESENSITIVE => 0 );
    $objs->Limit( FIELD => 'Instance', VALUE => $self->Id );
    $deps->Add( in => $objs );

    # Memberships in SystemInternal groups
    $objs = RT::GroupMembers->new( $self->CurrentUser );
    $objs->Limit( FIELD => 'MemberId', VALUE => $self->Id );
    my $groups = $objs->Join(
        ALIAS1 => 'main',
        FIELD1 => 'GroupId',
        TABLE2 => 'Groups',
        FIELD2 => 'id',
    );
    $objs->Limit(
        ALIAS => $groups,
        FIELD => 'Domain',
        VALUE => 'SystemInternal',
        CASESENSITIVE => 0
    );
    $deps->Add( in => $objs );

    # XXX: This ignores the myriad of "in" references from the Creator
    # and LastUpdatedBy columns.
}

sub __DependsOn {
    my $self = shift;
    my %args = (
        Shredder => undef,
        Dependencies => undef,
        @_,
    );
    my $deps = $args{'Dependencies'};
    my $list = [];

# Principal
    $deps->_PushDependency(
        BaseObject => $self,
        Flags => RT::Shredder::Constants::DEPENDS_ON | RT::Shredder::Constants::WIPE_AFTER,
        TargetObject => $self->PrincipalObj,
        Shredder => $args{'Shredder'}
    );

# ACL equivalence group
# don't use LoadACLEquivalenceGroup cause it may not exists any more
    my $objs = RT::Groups->new( $self->CurrentUser );
    $objs->Limit( FIELD => 'Domain', VALUE => 'ACLEquivalence', CASESENSITIVE => 0 );
    $objs->Limit( FIELD => 'Instance', VALUE => $self->Id );
    push( @$list, $objs );

# Cleanup user's membership
    $objs = RT::GroupMembers->new( $self->CurrentUser );
    $objs->Limit( FIELD => 'MemberId', VALUE => $self->Id );
    push( @$list, $objs );

# Cleanup user's membership transactions
    $objs = RT::Transactions->new( $self->CurrentUser );
    $objs->Limit( FIELD => 'Type', OPERATOR => 'IN', VALUE => ['AddMember', 'DeleteMember'] );
    $objs->Limit( FIELD => 'Field', VALUE => $self->PrincipalObj->id, ENTRYAGGREGATOR => 'AND' );
    push( @$list, $objs );

    $deps->_PushDependencies(
        BaseObject => $self,
        Flags => RT::Shredder::Constants::DEPENDS_ON,
        TargetObjects => $list,
        Shredder => $args{'Shredder'}
    );

# TODO: Almost all objects has Creator, LastUpdatedBy and etc. fields
# which are references on users(Principal actualy)
    my @OBJECTS = qw(
        ACL
        Articles
        Attachments
        Attributes
        CachedGroupMembers
        Classes
        CustomFieldValues
        CustomFields
        GroupMembers
        Groups
        Links
        ObjectClasses
        ObjectCustomFieldValues
        ObjectCustomFields
        ObjectScrips
        Principals
        Queues
        ScripActions
        ScripConditions
        Scrips
        Templates
        Tickets
        Transactions
        Users
    );
    my @var_objs;
    foreach( @OBJECTS ) {
        my $class = "RT::$_";
        foreach my $method ( qw(Creator LastUpdatedBy) ) {
            my $objs = $class->new( $self->CurrentUser );
            next unless $objs->RecordClass->_Accessible( $method => 'read' );
            $objs->Limit( FIELD => $method, VALUE => $self->id );
            push @var_objs, $objs;
        }
    }
    $deps->_PushDependencies(
        BaseObject => $self,
        Flags => RT::Shredder::Constants::DEPENDS_ON | RT::Shredder::Constants::VARIABLE,
        TargetObjects => \@var_objs,
        Shredder => $args{'Shredder'}
    );

    return $self->SUPER::__DependsOn( %args );
}

sub BeforeWipeout {
    my $self = shift;
    if( $self->Name =~ /^(RT_System|Nobody)$/ ) {
        RT::Shredder::Exception::Info->throw('SystemObject');
    }
    return $self->SUPER::BeforeWipeout( @_ );
}

sub Serialize {
    my $self = shift;
    return (
        Disabled => $self->PrincipalObj->Disabled,
        Principal => $self->PrincipalObj->UID,
        PrincipalId => $self->PrincipalObj->Id,
        $self->SUPER::Serialize(@_),
    );
}

sub PreInflate {
    my $class = shift;
    my ($importer, $uid, $data) = @_;

    my $principal_uid = delete $data->{Principal};
    my $principal_id  = delete $data->{PrincipalId};
    my $disabled      = delete $data->{Disabled};

    my $obj = RT::User->new( RT->SystemUser );
    $obj->LoadByCols( Name => $data->{Name} );
    $obj->LoadByEmail( $data->{EmailAddress} ) unless $obj->Id;
    if ($obj->Id) {
        # User already exists -- merge

        # XXX: We might be merging a privileged user into an unpriv one,
        # in which case we should probably promote the unpriv user to
        # being privileged.  Of course, we don't know if the user being
        # imported is privileged yet, as its group memberships show up
        # later in the stream...
        $importer->MergeValues($obj, $data);
        $importer->SkipTransactions( $uid );

        # Mark both the principal and the user object as resolved
        $importer->Resolve(
            $principal_uid,
            ref($obj->PrincipalObj),
            $obj->PrincipalObj->Id
        );
        $importer->Resolve( $uid => ref($obj) => $obj->Id );
        return;
    }

    # Create a principal first, so we know what ID to use
    my $principal = RT::Principal->new( RT->SystemUser );
    my ($id) = $principal->Create(
        PrincipalType => 'User',
        Disabled => $disabled,
    );

    # Now we have a principal id, set the id for the user record
    $data->{id} = $id;

    $importer->Resolve( $principal_uid => ref($principal), $id );
    $data->{id} = $id;

    return $class->SUPER::PreInflate( $importer, $uid, $data );
}

sub PostInflate {
    my $self = shift;
    RT->InitSystemObjects if $self->Name eq "RT_System";
}

RT::Base->_ImportOverlays();


1;
