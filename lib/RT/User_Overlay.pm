# BEGIN BPS TAGGED BLOCK {{{
# 
# COPYRIGHT:
#  
# This software is Copyright (c) 1996-2009 Best Practical Solutions, LLC 
#                                          <jesse@bestpractical.com>
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

=begin testing

ok(require RT::User);

=end testing


=cut


package RT::User;

use strict;
no warnings qw(redefine);

use vars qw(%_USERS_KEY_CACHE);

%_USERS_KEY_CACHE = ();

use Digest::MD5;
use RT::Principals;
use RT::ACE;
use RT::Interface::Email;
use Encode;

# {{{ sub _Accessible 


sub _OverlayAccessible {
    {

        Name                    => { public => 1,  admin => 1 },
          Password              => { read   => 0 },
          EmailAddress          => { public => 1 },
          Organization          => { public => 1,  admin => 1 },
          RealName              => { public => 1 },
          NickName              => { public => 1 },
          Lang                  => { public => 1 },
          EmailEncoding         => { public => 1 },
          WebEncoding           => { public => 1 },
          ExternalContactInfoId => { public => 1,  admin => 1 },
          ContactInfoSystem     => { public => 1,  admin => 1 },
          ExternalAuthId        => { public => 1,  admin => 1 },
          AuthSystem            => { public => 1,  admin => 1 },
          Gecos                 => { public => 1,  admin => 1 },
          PGPKey                => { public => 1,  admin => 1 },

    }
}



# }}}

# {{{ sub Create 

=head2 Create { PARAMHASH }


=begin testing

# Make sure we can create a user

my $u1 = RT::User->new($RT::SystemUser);
is(ref($u1), 'RT::User');
my ($id, $msg) = $u1->Create(Name => 'CreateTest1'.$$, EmailAddress => $$.'create-test-1@example.com');
ok ($id, "Creating user CreateTest1 - " . $msg );

# Make sure we can't create a second user with the same name
my $u2 = RT::User->new($RT::SystemUser);
($id, $msg) = $u2->Create(Name => 'CreateTest1'.$$, EmailAddress => $$.'create-test-2@example.com');
ok (!$id, $msg);


# Make sure we can't create a second user with the same EmailAddress address
my $u3 = RT::User->new($RT::SystemUser);
($id, $msg) = $u3->Create(Name => 'CreateTest2'.$$, EmailAddress => $$.'create-test-1@example.com');
ok (!$id, $msg);

# Make sure we can create a user with no EmailAddress address
my $u4 = RT::User->new($RT::SystemUser);
($id, $msg) = $u4->Create(Name => 'CreateTest3'.$$);
ok ($id, $msg);

# make sure we can create a second user with no EmailAddress address
my $u5 = RT::User->new($RT::SystemUser);
($id, $msg) = $u5->Create(Name => 'CreateTest4'.$$);
ok ($id, $msg);

# make sure we can create a user with a blank EmailAddress address
my $u6 = RT::User->new($RT::SystemUser);
($id, $msg) = $u6->Create(Name => 'CreateTest6'.$$, EmailAddress => '');
ok ($id, $msg);
# make sure we can create a second user with a blankEmailAddress address
my $u7 = RT::User->new($RT::SystemUser);
($id, $msg) = $u7->Create(Name => 'CreateTest7'.$$, EmailAddress => '');
ok ($id, $msg);

# Can we change the email address away from from "";
($id,$msg) = $u7->SetEmailAddress('foo@bar'.$$);
ok ($id, $msg);
# can we change the address back to "";  
($id,$msg) = $u7->SetEmailAddress('');
ok ($id, $msg);
is ($u7->EmailAddress, '');


=end testing

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
        return ( 0, $self->loc('No permission to create users') );
    }


    unless ($self->CanonicalizeUserInfo(\%args)) {
        return ( 0, $self->loc("Could not set user info") );
    }

    $args{'EmailAddress'} = $self->CanonicalizeEmailAddress($args{'EmailAddress'});

    # if the user doesn't have a name defined, set it to the email address
    $args{'Name'} = $args{'EmailAddress'} unless ($args{'Name'});



    # Privileged is no longer a column in users
    my $privileged = $args{'Privileged'};
    delete $args{'Privileged'};


    if ($args{'CryptedPassword'} ) {
        $args{'Password'} = $args{'CryptedPassword'};
        delete $args{'CryptedPassword'};
    }
    elsif ( !$args{'Password'} ) {
        $args{'Password'} = '*NO-PASSWORD*';
    }
    elsif ( length( $args{'Password'} ) < $RT::MinimumPasswordLength ) {
        return ( 0, $self->loc("Password needs to be at least [_1] characters long",$RT::MinimumPasswordLength) );
    }

    else {
        $args{'Password'} = $self->_GeneratePassword($args{'Password'});
    }

    #TODO Specify some sensible defaults.

    unless ( $args{'Name'} ) {
	use Data::Dumper;
	$RT::Logger->crit(Dumper \%args);
        return ( 0, $self->loc("Must specify 'Name' attribute") );
    }

    #SANITY CHECK THE NAME AND ABORT IF IT'S TAKEN
    if ($RT::SystemUser) {   #This only works if RT::SystemUser has been defined
        my $TempUser = RT::User->new($RT::SystemUser);
        $TempUser->Load( $args{'Name'} );
        return ( 0, $self->loc('Name in use') ) if ( $TempUser->Id );

        return ( 0, $self->loc('Email address in use') )
          unless ( $self->ValidateEmailAddress( $args{'EmailAddress'} ) );
    }
    else {
        $RT::Logger->warning( "$self couldn't check for pre-existing users");
    }


    $RT::Handle->BeginTransaction();
    # Groups deal with principal ids, rather than user ids.
    # When creating this user, set up a principal Id for it.
    my $principal = RT::Principal->new($self->CurrentUser);
    my $principal_id = $principal->Create(PrincipalType => 'User',
                                Disabled => $args{'Disabled'},
                                ObjectId => '0');
    # If we couldn't create a principal Id, get the fuck out.
    unless ($principal_id) {
        $RT::Handle->Rollback();
        $RT::Logger->crit("Couldn't create a Principal on new user create.");
        $RT::Logger->crit("Strange things are afoot at the circle K");
        return ( 0, $self->loc('Could not create user') );
    }

    $principal->__Set(Field => 'ObjectId', Value => $principal_id);
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

# }}}



# {{{ SetPrivileged

=head2 SetPrivileged BOOL

If passed a true value, makes this user a member of the "Privileged"  PseudoGroup.
Otherwise, makes this user a member of the "Unprivileged" pseudogroup. 

Returns a standard RT tuple of (val, msg);

=begin testing


ok(my $user = RT::User->new($RT::SystemUser));
ok($user->Load('root'), "Loaded user 'root'");
ok($user->Privileged, "User 'root' is privileged");
ok(my ($v,$m) = $user->SetPrivileged(0));
ok ($v ==1, "Set unprivileged suceeded ($m)");
ok(!$user->Privileged, "User 'root' is no longer privileged");
ok(my ($v2,$m2) = $user->SetPrivileged(1));
ok ($v2 ==1, "Set privileged suceeded ($m2");
ok($user->Privileged, "User 'root' is privileged again");

=end testing

=cut

sub SetPrivileged {
    my $self = shift;
    my $val = shift;

    #Check the ACL
    unless ( $self->CurrentUser->HasRight(Right => 'AdminUsers', Object => $RT::System) ) {
        return ( 0, $self->loc('Permission Denied') );
    }
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

    if ($val) {
        if ($priv->HasMember($self->PrincipalObj)) {
            #$RT::Logger->debug("That user is already privileged");
            return (0,$self->loc("That user is already privileged"));
        }
        if ($unpriv->HasMember($self->PrincipalObj)) {
            $unpriv->_DeleteMember($self->PrincipalId);
        } else {
        # if we had layered transactions, life would be good
        # sadly, we have to just go ahead, even if something
        # bogus happened
            $RT::Logger->crit("User ".$self->Id." is neither privileged nor ".
                "unprivileged. something is drastically wrong.");
        }
        my ($status, $msg) = $priv->_AddMember( InsideTransaction => 1, PrincipalId => $self->PrincipalId);  
        if ($status) {
            return (1, $self->loc("That user is now privileged"));
        } else {
            return (0, $msg);
        }
    }
    else {
        if ($unpriv->HasMember($self->PrincipalObj)) {
            #$RT::Logger->debug("That user is already unprivileged");
            return (0,$self->loc("That user is already unprivileged"));
        }
        if ($priv->HasMember($self->PrincipalObj)) {
            $priv->_DeleteMember( $self->PrincipalId);
        } else {
        # if we had layered transactions, life would be good
        # sadly, we have to just go ahead, even if something
        # bogus happened
            $RT::Logger->crit("User ".$self->Id." is neither privileged nor ".
                "unprivileged. something is drastically wrong.");
        }
        my ($status, $msg) = $unpriv->_AddMember( InsideTransaction => 1, PrincipalId => $self->PrincipalId);  
        if ($status) {
            return (1, $self->loc("That user is now unprivileged"));
        } else {
            return (0, $msg);
        }
    }
}

# }}}

# {{{ Privileged

=head2 Privileged

Returns true if this user is privileged. Returns undef otherwise.

=cut

sub Privileged {
    my $self = shift;
    my $priv = RT::Group->new($self->CurrentUser);
    $priv->LoadSystemInternalGroup('Privileged');
    if ($priv->HasMember($self->PrincipalObj)) {
        return(1);
    }
    else {
        return(undef);
    }
}

# }}}

# {{{ sub _BootstrapCreate 

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
    my $principal_id = $principal->Create(PrincipalType => 'User', ObjectId => '0');
    $principal->__Set(Field => 'ObjectId', Value => $principal_id);
   
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

# }}}

# {{{ sub Delete 

sub Delete {
    my $self = shift;

    return ( 0, $self->loc('Deleting this object would violate referential integrity') );

}

# }}}

# {{{ sub Load 

=head2 Load

Load a user object from the database. Takes a single argument.
If the argument is numerical, load by the column 'id'. Otherwise, load by
the "Name" column which is the user's textual username.

=cut

sub Load {
    my $self       = shift;
    my $identifier = shift || return undef;

    #if it's an int, load by id. otherwise, load by name.
    if ( $identifier !~ /\D/ ) {
        $self->SUPER::LoadById($identifier);
    }
    else {
        $self->LoadByCol( "Name", $identifier );
    }
}

# }}}

# {{{ sub LoadByEmail

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

    #$RT::Logger->debug("Trying to load an email address: $address\n");
    return $self->LoadByCol( "EmailAddress", $address );
}

# }}}

# {{{ LoadOrCreateByEmail 

=head2 LoadOrCreateByEmail ADDRESS

Attempts to find a user who has the provided email address. If that fails, creates an unprivileged user with
the provided email address. and loads them.

Returns a tuple of the user's id and a status message.
0 will be returned in place of the user's id in case of failure.

=cut

sub LoadOrCreateByEmail {
    my $self = shift;
    my $email = shift;

        my ($val, $message);

	my ( $Address, $Name ) =
	RT::Interface::Email::ParseAddressFromHeader($email);
	$email = $Address;

        $self->LoadByEmail($email);
        $message = $self->loc('User loaded');
        unless ($self->Id) {
		$self->Load($email);
	}
	unless($self->Id) {
            ( $val, $message ) = $self->Create(
                Name => $email,
                EmailAddress => $email,
                RealName     => $Name,
                Privileged   => 0,
                Comments     => 'Autocreated when added as a watcher');
            unless ($val) {
                # Deal with the race condition of two account creations at once
                $self->LoadByEmail($email);
                unless ($self->Id) {
                    sleep 5;
                    $self->LoadByEmail($email);
                }
                if ($self->Id) {
                    $RT::Logger->error("Recovered from creation failure due to race condition");
                    $message = $self->loc("User loaded");
                }
                else {
                    $RT::Logger->crit("Failed to create user ".$email .": " .$message);
                }
            }
        }

        if ($self->Id) {
            return($self->Id, $message);
        }
        else {
            return(0, $message);
        }


    }

# }}}

# {{{ sub ValidateEmailAddress

=head2 ValidateEmailAddress ADDRESS

Returns true if the email address entered is not in use by another user or is 
undef or ''. Returns false if it's in use. 

=cut

sub ValidateEmailAddress {
    my $self  = shift;
    my $Value = shift;

    # if the email address is null, it's always valid
    return (1) if ( !$Value || $Value eq "" );

    my $TempUser = RT::User->new($RT::SystemUser);
    $TempUser->LoadByEmail($Value);

    if ( $TempUser->id && ( $TempUser->id != $self->id ) )
    {    # if we found a user with that address
            # it's invalid to set this user's address to it
        return (undef);
    }
    else {    #it's a valid email address
        return (1);
    }
}

# }}}

# {{{ sub CanonicalizeEmailAddress



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
    if ($RT::CanonicalizeEmailAddressMatch && $RT::CanonicalizeEmailAddressReplace ) {
        $email =~ s/$RT::CanonicalizeEmailAddressMatch/$RT::CanonicalizeEmailAddressReplace/gi;
    }
    return ($email);
}


# }}}

# {{{ sub CanonicalizeUserInfo



=head2 CanonicalizeUserInfo HASH of ARGS

CanonicalizeUserInfo can convert all User->Create options.
it takes a hashref of all the params sent to User->Create and
returns that same hash, by default nothing is done.

This function is intended to allow users to have their info looked up via
an outside source and modified upon creation.

=cut

sub CanonicalizeUserInfo {
    my $self = shift;
    my $args = shift;
    my $success = 1;

    return ($success);
}


# }}}


# {{{ Password related functions

# {{{ sub SetRandomPassword

=head2 SetRandomPassword

Takes no arguments. Returns a status code and a new password or an error message.
If the status is 1, the second value returned is the new password.
If the status is anything else, the new value returned is the error code.

=cut

sub SetRandomPassword {
    my $self = shift;

    unless ( $self->CurrentUserCanModify('Password') ) {
        return ( 0, $self->loc("Permission Denied") );
    }


    my $min = ( $RT::MinimumPasswordLength > 6 ?  $RT::MinimumPasswordLength : 6);
    my $max = ( $RT::MinimumPasswordLength > 8 ?  $RT::MinimumPasswordLength : 8);

    my $pass = $self->GenerateRandomPassword( $min, $max) ;

    # If we have "notify user on 

    my ( $val, $msg ) = $self->SetPassword($pass);

    #If we got an error return the error.
    return ( 0, $msg ) unless ($val);

    #Otherwise, we changed the password, lets return it.
    return ( 1, $pass );

}

# }}}

# {{{ sub ResetPassword

=head2 ResetPassword

Returns status, [ERROR or new password].  Resets this user\'s password to
a randomly generated pronouncable password and emails them, using a 
global template called "RT_PasswordChange", which can be overridden
with global templates "RT_PasswordChange_Privileged" or "RT_PasswordChange_NonPrivileged" 
for privileged and Non-privileged users respectively.

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

    my $template = RT::Template->new( $self->CurrentUser );

    if ( $self->Privileged ) {
        $template->LoadGlobalTemplate('RT_PasswordChange_Privileged');
    }
    else {
        $template->LoadGlobalTemplate('RT_PasswordChange_NonPrivileged');
    }

    unless ( $template->Id ) {
        $template->LoadGlobalTemplate('RT_PasswordChange');
    }

    unless ( $template->Id ) {
        $RT::Logger->crit( "$self tried to send "
              . $self->Name
              . " a password reminder "
              . "but couldn't find a password change template" );
    }

    my $notification = RT::Action::SendPasswordEmail->new(
        TemplateObj => $template,
        Argument    => $pass
    );

    $notification->SetHeader( 'To', $self->EmailAddress );

    my ($ret);
    $ret = $notification->Prepare();
    if ($ret) {
        $ret = $notification->Commit();
    }

    if ($ret) {
        return ( 1, $self->loc('New password notification sent') );
    }
    else {
        return ( 0, $self->loc('Notification could not be sent') );
    }

}

# }}}

# {{{ sub GenerateRandomPassword

=head2 GenerateRandomPassword MIN_LEN and MAX_LEN

Returns a random password between MIN_LEN and MAX_LEN characters long.

=cut

sub GenerateRandomPassword {
    my $self       = shift;
    my $min_length = shift;
    my $max_length = shift;

    #This code derived from mpw.pl, a bit of code with a sordid history
    # Its notes: 

    # Perl cleaned up a bit by Jesse Vincent 1/14/2001.
    # Converted to perl from C by Marc Horowitz, 1/20/2000.
    # Converted to C from Multics PL/I by Bill Sommerfeld, 4/21/86.
    # Original PL/I version provided by Jerry Saltzer.

    my ( $frequency, $start_freq, $total_sum, $row_sums );

    #When munging characters, we need to know where to start counting letters from
    my $a = ord('a');

    # frequency of English digraphs (from D Edwards 1/27/66) 
    $frequency = [
        [
            4, 20, 28, 52, 2,  11,  28, 4,  32, 4, 6, 62, 23, 167,
            2, 14, 0,  83, 76, 127, 7,  25, 8,  1, 9, 1
        ],    # aa - az
        [
            13, 0, 0, 0,  55, 0, 0,  0, 8, 2, 0,  22, 0, 0,
            11, 0, 0, 15, 4,  2, 13, 0, 0, 0, 15, 0
        ],    # ba - bz
        [
            32, 0, 7, 1,  69, 0,  0,  33, 17, 0, 10, 9, 1, 0,
            50, 3, 0, 10, 0,  28, 11, 0,  0,  0, 3,  0
        ],    # ca - cz
        [
            40, 16, 9, 5,  65, 18, 3,  9, 56, 0, 1, 4, 15, 6,
            16, 4,  0, 21, 18, 53, 19, 5, 15, 0, 3, 0
        ],    # da - dz
        [
            84, 20, 55, 125, 51, 40, 19, 16,  50,  1,
            4,  55, 54, 146, 35, 37, 6,  191, 149, 65,
            9,  26, 21, 12,  5,  0
        ],    # ea - ez
        [
            19, 3, 5, 1,  19, 21, 1, 3, 30, 2, 0, 11, 1, 0,
            51, 0, 0, 26, 8,  47, 6, 3, 3,  0, 2, 0
        ],    # fa - fz
        [
            20, 4, 3, 2,  35, 1,  3, 15, 18, 0, 0, 5, 1, 4,
            21, 1, 1, 20, 9,  21, 9, 0,  5,  0, 1, 0
        ],    # ga - gz
        [
            101, 1, 3, 0, 270, 5,  1, 6, 57, 0, 0, 0, 3, 2,
            44,  1, 0, 3, 10,  18, 6, 0, 5,  0, 3, 0
        ],    # ha - hz
        [
            40, 7,  51, 23, 25, 9,   11, 3,  0, 0, 2, 38, 25, 202,
            56, 12, 1,  46, 79, 117, 1,  22, 0, 4, 0, 3
        ],    # ia - iz
        [
            3, 0, 0, 0, 5, 0, 0, 0, 1, 0, 0, 0, 0, 0,
            4, 0, 0, 0, 0, 0, 3, 0, 0, 0, 0, 0
        ],    # ja - jz
        [
            1, 0, 0, 0, 11, 0, 0, 0, 13, 0, 0, 0, 0, 2,
            0, 0, 0, 0, 6,  2, 1, 0, 2,  0, 1, 0
        ],    # ka - kz
        [
            44, 2, 5, 12, 62, 7,  5, 2, 42, 1, 1,  53, 2, 2,
            25, 1, 1, 2,  16, 23, 9, 0, 1,  0, 33, 0
        ],    # la - lz
        [
            52, 14, 1, 0, 64, 0, 0, 3, 37, 0, 0, 0, 7, 1,
            17, 18, 1, 2, 12, 3, 8, 0, 1,  0, 2, 0
        ],    # ma - mz
        [
            42, 10, 47, 122, 63, 19, 106, 12, 30, 1,
            6,  6,  9,  7,   54, 7,  1,   7,  44, 124,
            6,  1,  15, 0,   12, 0
        ],    # na - nz
        [
            7,  12, 14, 17, 5,  95, 3,  5,  14, 0, 0, 19, 41, 134,
            13, 23, 0,  91, 23, 42, 55, 16, 28, 0, 4, 1
        ],    # oa - oz
        [
            19, 1, 0, 0,  37, 0, 0, 4, 8, 0, 0, 15, 1, 0,
            27, 9, 0, 33, 14, 7, 6, 0, 0, 0, 0, 0
        ],    # pa - pz
        [
            0, 0, 0, 0, 0, 0, 0,  0, 0, 0, 0, 0, 0, 0,
            0, 0, 0, 0, 0, 0, 17, 0, 0, 0, 0, 0
        ],    # qa - qz
        [
            83, 8, 16, 23, 169, 4,  8, 8,  77, 1, 10, 5, 26, 16,
            60, 4, 0,  24, 37,  55, 6, 11, 4,  0, 28, 0
        ],    # ra - rz
        [
            65, 9,  17, 9, 73, 13,  1,  47, 75, 3, 0, 7, 11, 12,
            56, 17, 6,  9, 48, 116, 35, 1,  28, 0, 4, 0
        ],    # sa - sz
        [
            57, 22, 3,  1, 76, 5, 2, 330, 126, 1,
            0,  14, 10, 6, 79, 7, 0, 49,  50,  56,
            21, 2,  27, 0, 24, 0
        ],    # ta - tz
        [
            11, 5,  9, 6,  9,  1,  6, 0, 9, 0, 1, 19, 5, 31,
            1,  15, 0, 47, 39, 31, 0, 3, 0, 0, 0, 0
        ],    # ua - uz
        [
            7, 0, 0, 0, 72, 0, 0, 0, 28, 0, 0, 0, 0, 0,
            5, 0, 0, 0, 0,  0, 0, 0, 0,  0, 3, 0
        ],    # va - vz
        [
            36, 1, 1, 0, 38, 0, 0, 33, 36, 0, 0, 4, 1, 8,
            15, 0, 0, 0, 4,  2, 0, 0,  1,  0, 0, 0
        ],    # wa - wz
        [
            1, 0, 2, 0, 0, 1, 0, 0, 3, 0, 0, 0, 0, 0,
            1, 5, 0, 0, 0, 3, 0, 0, 1, 0, 0, 0
        ],    # xa - xz
        [
            14, 5, 4, 2, 7,  12, 12, 6, 10, 0, 0, 3, 7, 5,
            17, 3, 0, 4, 16, 30, 0,  0, 5,  0, 0, 0
        ],    # ya - yz
        [
            1, 0, 0, 0, 4, 0, 0, 0, 0, 0, 0, 0, 0, 0,
            0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
        ]
    ];    # za - zz

    #We need to know the totals for each row 
    $row_sums = [
        map {
            my $sum = 0;
            map { $sum += $_ } @$_;
            $sum;
          } @$frequency
    ];

    #Frequency with which a given letter starts a word.
    $start_freq = [
        1299, 425, 725, 271, 375, 470, 93, 223, 1009, 24,
        20,   355, 379, 319, 823, 618, 21, 317, 962,  1991,
        271,  104, 516, 6,   16,  14
    ];

    $total_sum = 0;
    map { $total_sum += $_ } @$start_freq;

    my $length = $min_length + int( rand( $max_length - $min_length ) );

    my $char = $self->_GenerateRandomNextChar( $total_sum, $start_freq );
    my @word = ( $char + $a );
    for ( 2 .. $length ) {
        $char =
          $self->_GenerateRandomNextChar( $row_sums->[$char],
            $frequency->[$char] );
        push ( @word, $char + $a );
    }

    #Return the password
    return pack( "C*", @word );

}

#A private helper function for RandomPassword
# Takes a row summary and a frequency chart for the next character to be searched
sub _GenerateRandomNextChar {
    my $self = shift;
    my ( $all, $freq ) = @_;
    my ( $pos, $i );

    for ( $pos = int( rand($all) ), $i = 0 ;
        $pos >= $freq->[$i] ;
        $pos -= $freq->[$i], $i++ )
    {
    }

    return ($i);
}

# }}}

# {{{ sub SetPassword

=head2 SetPassword

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
    }
    elsif ( length($password) < $RT::MinimumPasswordLength ) {
        return ( 0, $self->loc("Password needs to be at least [_1] characters long", $RT::MinimumPasswordLength) );
    }
    else {
        my $new = !$self->HasPassword;
        $password = $self->_GeneratePassword($password);
        my ( $val, $msg ) = $self->SUPER::SetPassword($password);
        if ($val) {
            return ( 1, $self->loc("Password set") ) if $new;
            return ( 1, $self->loc("Password changed") );
        }
        else {
            return ( $val, $msg );
        }
    }

}

=head2 _GeneratePassword PASSWORD

returns an MD5 hash of the password passed in, in hexadecimal encoding.

=cut

sub _GeneratePassword {
    my $self = shift;
    my $password = shift;

    my $md5 = Digest::MD5->new();
    $md5->add(encode_utf8($password));
    return ($md5->hexdigest);

}

=head2 _GeneratePasswordBase64 PASSWORD

returns an MD5 hash of the password passed in, in base64 encoding
(obsoleted now).

=cut

sub _GeneratePasswordBase64 {
    my $self = shift;
    my $password = shift;

    my $md5 = Digest::MD5->new();
    $md5->add(encode_utf8($password));
    return ($md5->b64digest);

}

# }}}

                                                                                
=head2 HasPassword
                                                                                
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


# {{{ sub IsPassword 

=head2 IsPassword

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

    # generate an md5 password 
    if ($self->_GeneratePassword($value) eq $self->__Value('Password')) {
        return(1);
    }

    #  if it's a historical password we say ok.
    if ($self->__Value('Password') eq crypt($value, $self->__Value('Password'))
        or $self->_GeneratePasswordBase64($value) eq $self->__Value('Password'))
    {
        # ...but upgrade the legacy password inplace.
        $self->SUPER::SetPassword( $self->_GeneratePassword($value) );
        return(1);
    }

    # no password check has succeeded. get out

    return (undef);
}

# }}}

# }}}

# {{{ sub SetDisabled

=head2 Sub SetDisabled

Toggles the user's disabled flag.
If this flag is
set, all password checks for this user will fail. All ACL checks for this
user will fail. The user will appear in no user listings.

=cut 

# }}}

sub SetDisabled {
    my $self = shift;
    unless ( $self->CurrentUser->HasRight(Right => 'AdminUsers', Object => $RT::System) ) {
        return (0, $self->loc('Permission Denied'));
    }
    return $self->PrincipalObj->SetDisabled(@_);
}

sub Disabled {
    my $self = shift;
    return $self->PrincipalObj->Disabled(@_);
}


# {{{ Principal related routines

=head2 PrincipalObj 

Returns the principal object for this user. returns an empty RT::Principal
if there's no principal object matching this user. 
The response is cached. PrincipalObj should never ever change.

=begin testing

ok(my $u = RT::User->new($RT::SystemUser));
ok($u->Load(1), "Loaded the first user");
ok($u->PrincipalObj->ObjectId == 1, "user 1 is the first principal");
is($u->PrincipalObj->PrincipalType, 'User' , "Principal 1 is a user, not a group");

=end testing

=cut


sub PrincipalObj {
    my $self = shift;
    unless ($self->{'PrincipalObj'} && 
            ($self->{'PrincipalObj'}->ObjectId == $self->Id) &&
            ($self->{'PrincipalObj'}->PrincipalType eq 'User')) {

            $self->{'PrincipalObj'} = RT::Principal->new($self->CurrentUser);
            $self->{'PrincipalObj'}->LoadByCols('ObjectId' => $self->Id,
                                                'PrincipalType' => 'User') ;
            }
    return($self->{'PrincipalObj'});
}


=head2 PrincipalId  

Returns this user's PrincipalId

=cut

sub PrincipalId {
    my $self = shift;
    return $self->Id;
}

# }}}



# {{{ sub HasGroupRight

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

    # {{{ Validate and load up the GroupId
    unless ( ( defined $args{'GroupObj'} ) and ( $args{'GroupObj'}->Id ) ) {
        return undef;
    }

    # }}}


    # Figure out whether a user has the right we're asking about.
    my $retval = $self->HasRight(
        Object => $args{'GroupObj'},
        Right     => $args{'Right'},
    );

    return ($retval);


}

# }}}

# {{{ sub OwnGroups 

=head2 OwnGroups

Returns a group collection object containing the groups of which this
user is a member.

=cut

sub OwnGroups {
    my $self = shift;
    my $groups = RT::Groups->new($self->CurrentUser);
    $groups->LimitToUserDefinedGroups;
    $groups->WithMember(PrincipalId => $self->Id, 
			Recursively => 1);
    return $groups;
}

# }}}

# {{{ sub Rights testing

=head1 Rights testing


=begin testing

my $root = RT::User->new($RT::SystemUser);
$root->Load('root');
ok($root->Id, "Found the root user");
my $rootq = RT::Queue->new($root);
$rootq->Load(1);
ok($rootq->Id, "Loaded the first queue");

ok ($rootq->CurrentUser->HasRight(Right=> 'CreateTicket', Object => $rootq), "Root can create tickets");

my $new_user = RT::User->new($RT::SystemUser);
my ($id, $msg) = $new_user->Create(Name => 'ACLTest'.$$);

ok ($id, "Created a new user for acl test $msg");

my $q = RT::Queue->new($new_user);
$q->Load(1);
ok($q->Id, "Loaded the first queue");


ok (!$q->CurrentUser->HasRight(Right => 'CreateTicket', Object => $q), "Some random user doesn't have the right to create tickets");
ok (my ($gval, $gmsg) = $new_user->PrincipalObj->GrantRight( Right => 'CreateTicket', Object => $q), "Granted the random user the right to create tickets");
ok ($gval, "Grant succeeded - $gmsg");


ok ($q->CurrentUser->HasRight(Right => 'CreateTicket', Object => $q), "The user can create tickets after we grant him the right");
ok (my ($gval, $gmsg) = $new_user->PrincipalObj->RevokeRight( Right => 'CreateTicket', Object => $q), "revoked the random user the right to create tickets");
ok ($gval, "Revocation succeeded - $gmsg");
ok (!$q->CurrentUser->HasRight(Right => 'CreateTicket', Object => $q), "The user can't create tickets anymore");





# Create a ticket in the queue
my $new_tick = RT::Ticket->new($RT::SystemUser);
my ($tickid, $tickmsg) = $new_tick->Create(Subject=> 'ACL Test', Queue => 'General');
ok($tickid, "Created ticket: $tickid");
# Make sure the user doesn't have the right to modify tickets in the queue
ok (!$new_user->HasRight( Object => $new_tick, Right => 'ModifyTicket'), "User can't modify the ticket without group membership");
# Create a new group
my $group = RT::Group->new($RT::SystemUser);
$group->CreateUserDefinedGroup(Name => 'ACLTest'.$$);
ok($group->Id, "Created a new group Ok");
# Grant a group the right to modify tickets in a queue
ok(my ($gv,$gm) = $group->PrincipalObj->GrantRight( Object => $q, Right => 'ModifyTicket'),"Granted the group the right to modify tickets");
ok($gv,"Grant succeeed - $gm");
# Add the user to the group
ok( my ($aid, $amsg) = $group->AddMember($new_user->PrincipalId), "Added the member to the group");
ok ($aid, "Member added to group: $amsg");
# Make sure the user does have the right to modify tickets in the queue
ok ($new_user->HasRight( Object => $new_tick, Right => 'ModifyTicket'), "User can modify the ticket with group membership");


# Remove the user from the group
ok( my ($did, $dmsg) = $group->DeleteMember($new_user->PrincipalId), "Deleted the member from the group");
ok ($did,"Deleted the group member: $dmsg");
# Make sure the user doesn't have the right to modify tickets in the queue
ok (!$new_user->HasRight( Object => $new_tick, Right => 'ModifyTicket'), "User can't modify the ticket without group membership");


my $q_as_system = RT::Queue->new($RT::SystemUser);
$q_as_system->Load(1);
ok($q_as_system->Id, "Loaded the first queue");

# Create a ticket in the queue
my $new_tick2 = RT::Ticket->new($RT::SystemUser);
my ($tick2id, $tickmsg) = $new_tick2->Create(Subject=> 'ACL Test 2', Queue =>$q_as_system->Id);
ok($tick2id, "Created ticket: $tick2id");
is($new_tick2->QueueObj->id, $q_as_system->Id, "Created a new ticket in queue 1");


# make sure that the user can't do this without subgroup membership
ok (!$new_user->HasRight( Object => $new_tick2, Right => 'ModifyTicket'), "User can't modify the ticket without group membership");

# Create a subgroup
my $subgroup = RT::Group->new($RT::SystemUser);
$subgroup->CreateUserDefinedGroup(Name => 'Subgrouptest',$$);
ok($subgroup->Id, "Created a new group ".$subgroup->Id."Ok");
#Add the subgroup as a subgroup of the group
my ($said, $samsg) =  $group->AddMember($subgroup->PrincipalId);
ok ($said, "Added the subgroup as a member of the group");
# Add the user to a subgroup of the group

my ($usaid, $usamsg) =  $subgroup->AddMember($new_user->PrincipalId);
ok($usaid,"Added the user ".$new_user->Id."to the subgroup");
# Make sure the user does have the right to modify tickets in the queue
ok ($new_user->HasRight( Object => $new_tick2, Right => 'ModifyTicket'), "User can modify the ticket with subgroup membership");

#  {{{ Deal with making sure that members of subgroups of a disabled group don't have rights

my ($id, $msg);
($id, $msg) =  $group->SetDisabled(1);
ok ($id,$msg);
ok (!$new_user->HasRight( Object => $new_tick2, Right => 'ModifyTicket'), "User can't modify the ticket when the group ".$group->Id. " is disabled");
 ($id, $msg) =  $group->SetDisabled(0);
ok($id,$msg);
# Test what happens when we disable the group the user is a member of directly

($id, $msg) =  $subgroup->SetDisabled(1);
 ok ($id,$msg);
ok (!$new_user->HasRight( Object => $new_tick2, Right => 'ModifyTicket'), "User can't modify the ticket when the group ".$subgroup->Id. " is disabled");
 ($id, $msg) =  $subgroup->SetDisabled(0);
 ok ($id,$msg);
ok ($new_user->HasRight( Object => $new_tick2, Right => 'ModifyTicket'), "User can modify the ticket without group membership");

# }}}


my ($usrid, $usrmsg) =  $subgroup->DeleteMember($new_user->PrincipalId);
ok($usrid,"removed the user from the group - $usrmsg");
# Make sure the user doesn't have the right to modify tickets in the queue
ok (!$new_user->HasRight( Object => $new_tick2, Right => 'ModifyTicket'), "User can't modify the ticket without group membership");

#revoke the right to modify tickets in a queue
ok(($gv,$gm) = $group->PrincipalObj->RevokeRight( Object => $q, Right => 'ModifyTicket'),"Granted the group the right to modify tickets");
ok($gv,"revoke succeeed - $gm");

# {{{ Test the user's right to modify a ticket as a _queue_ admincc for a right granted at the _queue_ level

# Grant queue admin cc the right to modify ticket in the queue 
ok(my ($qv,$qm) = $q_as_system->AdminCc->PrincipalObj->GrantRight( Object => $q_as_system, Right => 'ModifyTicket'),"Granted the queue adminccs the right to modify tickets");
ok($qv, "Granted the right successfully - $qm");

# Add the user as a queue admincc
ok ((my $add_id, $add_msg) = $q_as_system->AddWatcher(Type => 'AdminCc', PrincipalId => $new_user->PrincipalId)  , "Added the new user as a queue admincc");
ok ($add_id, "the user is now a queue admincc - $add_msg");

# Make sure the user does have the right to modify tickets in the queue
ok ($new_user->HasRight( Object => $new_tick2, Right => 'ModifyTicket'), "User can modify the ticket as an admincc");
# Remove the user from the role  group
ok ((my $del_id, $del_msg) = $q_as_system->DeleteWatcher(Type => 'AdminCc', PrincipalId => $new_user->PrincipalId)  , "Deleted the new user as a queue admincc");

# Make sure the user doesn't have the right to modify tickets in the queue
ok (!$new_user->HasRight( Object => $new_tick2, Right => 'ModifyTicket'), "User can't modify the ticket without group membership");

# }}}

# {{{ Test the user's right to modify a ticket as a _ticket_ admincc with the right granted at the _queue_ level

# Add the user as a ticket admincc
ok ((my $uadd_id, $uadd_msg) = $new_tick2->AddWatcher(Type => 'AdminCc', PrincipalId => $new_user->PrincipalId)  , "Added the new user as a queue admincc");
ok ($add_id, "the user is now a queue admincc - $add_msg");

# Make sure the user does have the right to modify tickets in the queue
ok ($new_user->HasRight( Object => $new_tick2, Right => 'ModifyTicket'), "User can modify the ticket as an admincc");

# Remove the user from the role  group
ok ((my $del_id, $del_msg) = $new_tick2->DeleteWatcher(Type => 'AdminCc', PrincipalId => $new_user->PrincipalId)  , "Deleted the new user as a queue admincc");

# Make sure the user doesn't have the right to modify tickets in the queue
ok (!$new_user->HasRight( Object => $new_tick2, Right => 'ModifyTicket'), "User can't modify the ticket without group membership");


# Revoke the right to modify ticket in the queue 
ok(my ($rqv,$rqm) = $q_as_system->AdminCc->PrincipalObj->RevokeRight( Object => $q_as_system, Right => 'ModifyTicket'),"Revokeed the queue adminccs the right to modify tickets");
ok($rqv, "Revoked the right successfully - $rqm");

# }}}



# {{{ Test the user's right to modify a ticket as a _queue_ admincc for a right granted at the _system_ level

# Before we start Make sure the user does not have the right to modify tickets in the queue
ok (!$new_user->HasRight( Object => $new_tick2, Right => 'ModifyTicket'), "User can not modify the ticket without it being granted");
ok (!$new_user->HasRight( Object => $new_tick2->QueueObj, Right => 'ModifyTicket'), "User can not modify tickets in the queue without it being granted");

# Grant queue admin cc the right to modify ticket in the queue 
ok(my ($qv,$qm) = $q_as_system->AdminCc->PrincipalObj->GrantRight( Object => $RT::System, Right => 'ModifyTicket'),"Granted the queue adminccs the right to modify tickets");
ok($qv, "Granted the right successfully - $qm");

# Make sure the user can't modify the ticket before they're added as a watcher
ok (!$new_user->HasRight( Object => $new_tick2, Right => 'ModifyTicket'), "User can not modify the ticket without being an admincc");
ok (!$new_user->HasRight( Object => $new_tick2->QueueObj, Right => 'ModifyTicket'), "User can not modify tickets in the queue without being an admincc");

# Add the user as a queue admincc
ok ((my $add_id, $add_msg) = $q_as_system->AddWatcher(Type => 'AdminCc', PrincipalId => $new_user->PrincipalId)  , "Added the new user as a queue admincc");
ok ($add_id, "the user is now a queue admincc - $add_msg");

# Make sure the user does have the right to modify tickets in the queue
ok ($new_user->HasRight( Object => $new_tick2, Right => 'ModifyTicket'), "User can modify the ticket as an admincc");
ok ($new_user->HasRight( Object => $new_tick2->QueueObj, Right => 'ModifyTicket'), "User can modify tickets in the queue as an admincc");
# Remove the user from the role  group
ok ((my $del_id, $del_msg) = $q_as_system->DeleteWatcher(Type => 'AdminCc', PrincipalId => $new_user->PrincipalId)  , "Deleted the new user as a queue admincc");

# Make sure the user doesn't have the right to modify tickets in the queue
ok (!$new_user->HasRight( Object => $new_tick2, Right => 'ModifyTicket'), "User can't modify the ticket without group membership");
ok (!$new_user->HasRight( Object => $new_tick2->QueueObj, Right => 'ModifyTicket'), "User can't modify tickets in the queue without group membership");

# }}}

# {{{ Test the user's right to modify a ticket as a _ticket_ admincc with the right granted at the _queue_ level

ok (!$new_user->HasRight( Object => $new_tick2, Right => 'ModifyTicket'), "User can not modify the ticket without being an admincc");
ok (!$new_user->HasRight( Object => $new_tick2->QueueObj, Right => 'ModifyTicket'), "User can not modify tickets in the queue obj without being an admincc");


# Add the user as a ticket admincc
ok ((my $uadd_id, $uadd_msg) = $new_tick2->AddWatcher(Type => 'AdminCc', PrincipalId => $new_user->PrincipalId)  , "Added the new user as a queue admincc");
ok ($add_id, "the user is now a queue admincc - $add_msg");

# Make sure the user does have the right to modify tickets in the queue
ok ($new_user->HasRight( Object => $new_tick2, Right => 'ModifyTicket'), "User can modify the ticket as an admincc");
ok (!$new_user->HasRight( Object => $new_tick2->QueueObj, Right => 'ModifyTicket'), "User can not modify tickets in the queue obj being only a ticket admincc");

# Remove the user from the role  group
ok ((my $del_id, $del_msg) = $new_tick2->DeleteWatcher(Type => 'AdminCc', PrincipalId => $new_user->PrincipalId)  , "Deleted the new user as a queue admincc");

# Make sure the user doesn't have the right to modify tickets in the queue
ok (!$new_user->HasRight( Object => $new_tick2, Right => 'ModifyTicket'), "User can't modify the ticket without being an admincc");
ok (!$new_user->HasRight( Object => $new_tick2->QueueObj, Right => 'ModifyTicket'), "User can not modify tickets in the queue obj without being an admincc");


# Revoke the right to modify ticket in the queue 
ok(my ($rqv,$rqm) = $q_as_system->AdminCc->PrincipalObj->RevokeRight( Object => $RT::System, Right => 'ModifyTicket'),"Revokeed the queue adminccs the right to modify tickets");
ok($rqv, "Revoked the right successfully - $rqm");

# }}}




# Grant "privileged users" the system right to create users
# Create a privileged user.
# have that user create another user
# Revoke the right for privileged users to create users
# have the privileged user try to create another user and fail the ACL check

=end testing

=cut

# }}}


# {{{ sub HasRight

=head2 HasRight

Shim around PrincipalObj->HasRight. See RT::Principal

=cut

sub HasRight {

    my $self = shift;
    return $self->PrincipalObj->HasRight(@_);
}

# }}}

# {{{ sub CurrentUserCanModify

=head2 CurrentUserCanModify RIGHT

If the user has rights for this object, either because
he has 'AdminUsers' or (if he\'s trying to edit himself and the right isn\'t an 
admin right) 'ModifySelf', return 1. otherwise, return undef.

=cut

sub CurrentUserCanModify {
    my $self  = shift;
    my $right = shift;

    if ( $self->CurrentUser->HasRight(Right => 'AdminUsers', Object => $RT::System) ) {
        return (1);
    }

    #If the field is marked as an "administrators only" field, 
    # don\'t let the user touch it.
    elsif ( $self->_Accessible( $right, 'admin' ) ) {
        return (undef);
    }

    #If the current user is trying to modify themselves
    elsif ( ( $self->id == $self->CurrentUser->id )
        and ( $self->CurrentUser->HasRight(Right => 'ModifySelf', Object => $RT::System) ) )
    {
        return (1);
    }

    #If we don\'t have a good reason to grant them rights to modify
    # by now, they lose
    else {
        return (undef);
    }

}

# }}}

# {{{ sub CurrentUserHasRight

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
	$name = ref ($name).'-'.$name->Id;
    }

    return 'Pref-'.$name;
}

# {{{ sub Preferences

=head2 Preferences NAME/OBJ DEFAULT

  Obtain user preferences associated with given object or name.
  Returns DEFAULT if no preferences found.  If DEFAULT is a hashref,
  override the entries with user preferences.

=cut

sub Preferences {
    my $self  = shift;
    my $name = _PrefName (shift);
    my $default = shift;

    my $attr = RT::Attribute->new ($self->CurrentUser);
    $attr->LoadByNameAndObject (Object => $self, Name => $name);

    my $content = $attr->Id ? $attr->Content : undef;
    if (ref ($content) eq 'HASH') {
	if (ref ($default) eq 'HASH') {
	    for (keys %$default) {
		exists $content->{$_} or $content->{$_} = $default->{$_};
	    }
	}
	elsif (defined $default) {
	    $RT::Logger->error("Preferences $name for user".$self->Id." is hash but default is not");
	}
	return $content;
    }
    else {
	return defined $content ? $content : $default;
    }
}

# }}}

# {{{ sub SetPreferences

=head2 SetPreferences NAME/OBJ VALUE

  Set user preferences associated with given object or name.

=cut

sub SetPreferences {
    my $self  = shift;
    my $name = _PrefName (shift);
    my $value = shift;
    my $attr = RT::Attribute->new ($self->CurrentUser);
    $attr->LoadByNameAndObject (Object => $self, Name => $name);
    if ($attr->Id) {
	return $attr->SetContent ($value);
    }
    else {
	return $self->AddAttribute ( Name => $name, Content => $value );
    }
}

# }}}


=head2 WatchedQueues ROLE_LIST

Returns a RT::Queues object containing every queue watched by the user.

Takes a list of roles which is some subset of ('Cc', 'AdminCc').  Defaults to:

$user->WatchedQueues('Cc', 'AdminCc');

=cut

sub WatchedQueues {

    my $self = shift;
    my @roles = @_ || ('Cc', 'AdminCc');

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
                          );
    if (grep { $_ eq 'Cc' } @roles) {
        $watched_queues->Limit(
                                SUBCLAUSE => 'LimitToWatchers',
                                ALIAS => $group_alias,
                                FIELD => 'Type',
                                VALUE => 'Cc',
                                ENTRYAGGREGATOR => 'OR',
                              );
    }
    if (grep { $_ eq 'AdminCc' } @roles) {
        $watched_queues->Limit(
                                SUBCLAUSE => 'LimitToWatchers',
                                ALIAS => $group_alias,
                                FIELD => 'Type',
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

    $RT::Logger->debug("WatchedQueues got " . $watched_queues->Count . " queues");
    
    return $watched_queues;

}


# {{{ sub _CleanupInvalidDelegations

=head2 _CleanupInvalidDelegations { InsideTransaction => undef }

Revokes all ACE entries delegated by this user which are inconsistent
with their current delegation rights.  Does not perform permission
checks.  Should only ever be called from inside the RT library.

If called from inside a transaction, specify a true value for the
InsideTransaction parameter.

Returns a true value if the deletion succeeded; returns a false value
and logs an internal error if the deletion fails (should not happen).

=cut

# XXX Currently there is a _CleanupInvalidDelegations method in both
# RT::User and RT::Group.  If the recursive cleanup call for groups is
# ever unrolled and merged, this code will probably want to be
# factored out into RT::Principal.

sub _CleanupInvalidDelegations {
    my $self = shift;
    my %args = ( InsideTransaction => undef,
		  @_ );

    unless ( $self->Id ) {
	$RT::Logger->warning("User not loaded.");
	return (undef);
    }

    my $in_trans = $args{InsideTransaction};

    return(1) if ($self->HasRight(Right => 'DelegateRights',
				  Object => $RT::System));

    # Look up all delegation rights currently posessed by this user.
    my $deleg_acl = RT::ACL->new($RT::SystemUser);
    $deleg_acl->LimitToPrincipal(Type => 'User',
				 Id => $self->PrincipalId,
				 IncludeGroupMembership => 1);
    $deleg_acl->Limit( FIELD => 'RightName',
		       OPERATOR => '=',
		       VALUE => 'DelegateRights' );
    my @allowed_deleg_objects = map {$_->Object()}
	@{$deleg_acl->ItemsArrayRef()};

    # Look up all rights delegated by this principal which are
    # inconsistent with the allowed delegation objects.
    my $acl_to_del = RT::ACL->new($RT::SystemUser);
    $acl_to_del->DelegatedBy(Id => $self->Id);
    foreach (@allowed_deleg_objects) {
	$acl_to_del->LimitNotObject($_);
    }

    # Delete all disallowed delegations
    while ( my $ace = $acl_to_del->Next() ) {
	my $ret = $ace->_Delete(InsideTransaction => 1);
	unless ($ret) {
	    $RT::Handle->Rollback() unless $in_trans;
	    $RT::Logger->warning("Couldn't delete delegated ACL entry ".$ace->Id);
	    return (undef);
	}
    }

    $RT::Handle->Commit() unless $in_trans;
    return (1);
}

# }}}

# {{{ sub _Set

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

    if ( ($self->Id == $RT::SystemUser->Id )  || 
         ($self->Id == $RT::Nobody->Id)) {
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

        my ( $Trans, $Msg, $TransObj ) = $self->_NewTransaction(
                                               Type => $args{'TransactionType'},
                                               Field     => $args{'Field'},
                                               NewValue  => $args{'Value'},
                                               OldValue  => $Old,
                                               TimeTaken => $args{'TimeTaken'},
        );
        return ( $Trans, scalar $TransObj->BriefDescription );
    }
    else {
        return ( $ret, $msg );
    }
}

# }}}

# {{{ sub _Value 

=head2 _Value

Takes the name of a table column.
Returns its value as a string, if the user passes an ACL check

=cut

sub _Value {

    my $self  = shift;
    my $field = shift;

    #If the current user doesn't have ACLs, don't let em at it.  

    my @PublicFields = qw( Name EmailAddress Organization Disabled
      RealName NickName Gecos ExternalAuthId
      AuthSystem ExternalContactInfoId
      ContactInfoSystem );

    #if the field is public, return it.
    if ( $self->_Accessible( $field, 'public' ) ) {
        return ( $self->SUPER::_Value($field) );

    }

    #If the user wants to see their own values, let them
    # TODO figure ouyt a better way to deal with this
   elsif ( $self->CurrentUser->Id == $self->Id ) {
        return ( $self->SUPER::_Value($field) );
    }

    #If the user has the admin users right, return the field
    elsif ( $self->CurrentUser->HasRight(Right =>'AdminUsers', Object => $RT::System) ) {
        return ( $self->SUPER::_Value($field) );
    }
    else {
        return (undef);
    }

}

# }}}

sub BasicColumns {
    (
	[ Name => 'User Id' ],
	[ EmailAddress => 'Email' ],
	[ RealName => 'Name' ],
	[ Organization => 'Organization' ],
    );
}

1;


