# BEGIN LICENSE BLOCK
# 
# Copyright (c) 1996-2002 Jesse Vincent <jesse@bestpractical.com>
# 
# (Except where explictly superceded by other copyright notices)
# 
# This work is made available to you under the terms of Version 2 of
# the GNU General Public License. A copy of that license should have
# been provided with this software, but in any event can be snarfed
# from www.gnu.org
# 
# This work is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# General Public License for more details.
# 
# 
# Unless otherwise specified, all modifications, corrections or
# extensions to this work which alter its source code become the
# property of Best Practical Solutions, LLC when submitted for
# inclusion in the work.
# 
# 
# END LICENSE BLOCK

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

no warnings qw(redefine);

use vars qw(%_USERS_KEY_CACHE);

%_USERS_KEY_CACHE = ();

use RT::Principals;
use RT::ACE;


# {{{ sub _Accessible 


sub _ClassAccessible {
    {
     
        id =>
                {read => 1, type => 'int(11)', default => ''},
        Name => 
                {read => 1, write => 1, public => 1, admin => 1, type => 'varchar(120)', default => ''},
        Password => 
                { write => 1, type => 'varchar(40)', default => ''},
        Comments => 
                {read => 1, write => 1, admin => 1, type => 'blob', default => ''},
        Signature => 
                {read => 1, write => 1, type => 'blob', default => ''},
        EmailAddress => 
                {read => 1, write => 1, public => 1,  type => 'varchar(120)', default => ''},
        FreeformContactInfo => 
                {read => 1, write => 1, type => 'blob', default => ''},
        Organization => 
                {read => 1, write => 1, public => 1, admin => 1, type => 'varchar(200)', default => ''},
        RealName => 
                {read => 1, write => 1, public => 1, type => 'varchar(120)', default => ''},
        NickName => 
                {read => 1, write => 1, public => 1, type => 'varchar(16)', default => ''},
        Lang => 
                {read => 1, write => 1, public => 1, type => 'varchar(16)', default => ''},
        EmailEncoding => 
                {read => 1, write => 1, public => 1, type => 'varchar(16)', default => ''},
        WebEncoding => 
                {read => 1, write => 1, public => 1, type => 'varchar(16)', default => ''},
        ExternalContactInfoId => 
                {read => 1, write => 1, public => 1, admin => 1, type => 'varchar(100)', default => ''},
        ContactInfoSystem => 
                {read => 1, write => 1, public => 1, admin => 1, type => 'varchar(30)', default => ''},
        ExternalAuthId => 
                {read => 1, write => 1, public => 1, admin => 1, type => 'varchar(100)', default => ''},
        AuthSystem => 
                {read => 1, write => 1, public => 1, admin => 1,type => 'varchar(30)', default => ''},
        Gecos => 
                {read => 1, write => 1, public => 1, admin => 1, type => 'varchar(16)', default => ''},

        PGPKey => {
                {read => 1, write => 1, public => 1, admin => 1, type => 'text', default => ''},
        },
        HomePhone => 
                {read => 1, write => 1, type => 'varchar(30)', default => ''},
        WorkPhone => 
                {read => 1, write => 1, type => 'varchar(30)', default => ''},
        MobilePhone => 
                {read => 1, write => 1, type => 'varchar(30)', default => ''},
        PagerPhone => 
                {read => 1, write => 1, type => 'varchar(30)', default => ''},
        Address1 => 
                {read => 1, write => 1, type => 'varchar(200)', default => ''},
        Address2 => 
                {read => 1, write => 1, type => 'varchar(200)', default => ''},
        City => 
                {read => 1, write => 1, type => 'varchar(100)', default => ''},
        State => 
                {read => 1, write => 1, type => 'varchar(100)', default => ''},
        Zip => 
                {read => 1, write => 1, type => 'varchar(16)', default => ''},
        Country => 
                {read => 1, write => 1, type => 'varchar(50)', default => ''},
        Creator => 
                {read => 1, auto => 1, type => 'int(11)', default => ''},
        Created => 
                {read => 1, auto => 1, type => 'datetime', default => ''},
        LastUpdatedBy => 
                {read => 1, auto => 1, type => 'int(11)', default => ''},
        LastUpdated => 
                {read => 1, auto => 1, type => 'datetime', default => ''},

 }
};


# }}}

# {{{ sub Create 

sub Create {
    my $self = shift;
    my %args = (
        Privileged => 0,
        @_    # get the real argumentlist
    );

    #Check the ACL
    unless ( $self->CurrentUser->HasRight(Right => 'AdminUsers', Object => $RT::System) ) {
        return ( 0, $self->loc('No permission to create users') );
    }


    # Privileged is no longer a column in users
    my $privileged = $args{'Privileged'};
    delete $args{'Privileged'};

    if ( !$args{'Password'} ) {
        $args{'Password'} = '*NO-PASSWORD*';
    }
    elsif ( length( $args{'Password'} ) < $RT::MinimumPasswordLength ) {
        return ( 0, $self->loc("Password too short") );
    }
    else {
        my $salt = join '',
          ( '.', '/', 0 .. 9, 'A' .. 'Z', 'a' .. 'z' )[ rand 64, rand 64 ];
        $args{'Password'} = crypt( $args{'Password'}, $salt );
    }

    #TODO Specify some sensible defaults.

    unless ( defined( $args{'Name'} ) ) {
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
                                ObjectId => '0');
    $principal->__Set(Field => 'ObjectId', Value => $principal_id);
    # If we couldn't create a principal Id, get the fuck out.
    unless ($principal_id) {
        $RT::Handle->Rollback();
        $self->crit("Couldn't create a Principal on new user create. Strange things are afoot at the circle K");
        return ( 0, $self->loc('Could not create user') );
    }


    $self->SUPER::Create(id => $principal_id , %args);
    my $id = $self->Id;

    #If the create failed.
    unless ($id) {
        $RT::Logger->error("Could not create a new user");

        return ( 0, $self->loc('Could not create user') );
    }


    #TODO post 2.0
    #if ($args{'SendWelcomeMessage'}) {
    #	#TODO: Check if the email exists and looks valid
    #	#TODO: Send the user a "welcome message" 
    #}



    my $aclstash = RT::Group->new($self->CurrentUser);
    my $stash_id = $aclstash->_CreateACLEquivalenceGroup($principal);

    unless ($stash_id) {
        $RT::Handle->Rollback();
        $self->crit("Couldn't stash the user in groumembers");
        return ( 0, $self->loc('Could not create user') );
    }

    $RT::Handle->Commit;

    #$RT::Logger->debug("Adding the user as a member of everyone"); 
    my $everyone = RT::Group->new($self->CurrentUser);
    $everyone->LoadSystemInternalGroup('Everyone');
    $everyone->AddMember($self->PrincipalId);

    if ($privileged)  {
        my $priv = RT::Group->new($self->CurrentUser);
        #$RT::Logger->debug("Making ".$self->Id." a privileged user");
        $priv->LoadSystemInternalGroup('Privileged');
        $priv->AddMember($self->PrincipalId);  
    } else {
        my $unpriv = RT::Group->new($self->CurrentUser);
        #$RT::Logger->debug("Making ".$self->Id." an unprivileged user");
        $unpriv->LoadSystemInternalGroup('Unprivileged');
        $unpriv->AddMember($self->PrincipalId);  
    }


   #  $RT::Logger->debug("Finished creating the user");
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
            $unpriv->DeleteMember($self->PrincipalId);
        } else {
        # if we had layered transactions, life would be good
        # sadly, we have to just go ahead, even if something
        # bogus happened
            $RT::Logger->crit("User ".$self->Id." is neither privileged nor ".
                "unprivileged. something is drastically wrong.");
        }
        $priv->AddMember($self->PrincipalId);  
        return (1, $self->loc("That user is now privileged"));
    }
    else {
        if ($unpriv->HasMember($self->PrincipalObj)) {
            #$RT::Logger->debug("That user is already unprivileged");
            return (0,$self->loc("That user is already unprivileged"));
        }
        if ($priv->HasMember($self->PrincipalObj)) {
            $priv->DeleteMember($self->PrincipalId);
        } else {
        # if we had layered transactions, life would be good
        # sadly, we have to just go ahead, even if something
        # bogus happened
            $RT::Logger->crit("User ".$self->Id." is neither privileged nor ".
                "unprivileged. something is drastically wrong.");
        }
        $unpriv->AddMember($self->PrincipalId);  
        return (1, $self->loc("That user is now unprivileged"));
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



=item CanonicalizeEmailAddress ADDRESS

# CanonicalizeEmailAddress converts email addresses into canonical form.
# it takes one email address in and returns the proper canonical
# form. You can dump whatever your proper local config is in here

=cut

sub CanonicalizeEmailAddress {
    my $self = shift;
    my $email = shift;
    # Example: the following rule would treat all email
    # coming from a subdomain as coming from second level domain
    # foo.com
    if ($RT::CanonicalizeEmailAddressMatch && $RT::CanonicalizeEmailAddressReplace ) {
        $email =~ s/\$RT::CanonicalizeEmailAddressMatch/$RT::CanonicalizeEmailAddressReplace/gi;
    }
    return ($email);
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

    my $pass = $self->GenerateRandomPassword( 6, 8 );

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

    if ( $self->IsPrivileged ) {
        $template->LoadGlobalTemplate('RT_PasswordChange_Privileged');
    }
    else {
        $template->LoadGlobalTemplate('RT_PasswordChange_Privileged');
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

    $notification->SetTo( $self->EmailAddress );

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

    my $char = $self->GenerateRandomNextChar( $total_sum, $start_freq );
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
        return ( 0, $self->loc('Permission Denied') );
    }

    if ( !$password ) {
        return ( 0, $self->loc("No password set") );
    }
    elsif ( length($password) < $RT::MinimumPasswordLength ) {
        return ( 0, $self->loc("Password too short") );
    }
    else {
        my $salt = join '',
          ( '.', '/', 0 .. 9, 'A' .. 'Z', 'a' .. 'z' )[ rand 64, rand 64 ];
        return ( $self->SUPER::SetPassword( crypt( $password, $salt ) ) );
    }

}

# }}}

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

    if ( ($self->__Value('Password') eq '') || 
         ($self->__Value('Password') eq undef) )  {
        return(undef);
     }

    if ( $self->__Value('Password') eq
        crypt( $value, $self->__Value('Password') ) )
    {
        return (1);
    }
    else {
        return (undef);
    }
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
ok($u->PrincipalObj->PrincipalType eq 'User' , "Principal 1 is a user, not a group");

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

# {{{ sub Rights testing

=head2 Rights testing


=begin testing

my $root = RT::User->new($RT::SystemUser);
$root->Load('root');
ok($root->Id, "Found the root user");
my $rootq = RT::Queue->new($root);
$rootq->Load(1);
ok($rootq->Id, "Loaded the first queue");

ok ($rootq->CurrentUser->HasRight(Right=> 'CreateTicket', Object => $rootq), "Root can create tickets");

my $new_user = RT::User->new($RT::SystemUser);
my ($id, $msg) = $new_user->Create(Name => 'ACLTest');

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
$group->CreateUserDefinedGroup(Name => 'ACLTest');
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
ok($new_tick2->QueueObj->id eq $q_as_system->Id, "Created a new ticket in queue 1");


# make sure that the user can't do this without subgroup membership
ok (!$new_user->HasRight( Object => $new_tick2, Right => 'ModifyTicket'), "User can't modify the ticket without group membership");

# Create a subgroup
my $subgroup = RT::Group->new($RT::SystemUser);
$subgroup->CreateUserDefinedGroup(Name => 'Subgrouptest');
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

# Grant system admin cc the right to modify ticket 


# Add the user as a queue admincc
# Make sure the user does have the right to modify tickets in the queue
# Remove the user from the role  group
# Make sure the user doesn't have the right to modify tickets in the queue
# Revoke the right for the role group


# Grant system admin cc the right to modify ticket  
# Add the user as a ticket admincc
# Make sure the user does have the right to modify tickets in the queue
# Remove the user from the role  group
# Make sure the user doesn't have the right to modify tickets in the queue
# Revoke the right for the role group

# Grant "privileged users" the system right to create users
# Create a privileged user.
# have that user create another user
# Revoke the right for privileged users to create users
# have the privileged user try to create another user and fail the ACL check

=end testing

=cut

# }}}


# {{{ sub HasRight

=head2 sub HasRight (Right => 'right' Object => undef)


Checks to see whether the this user has the right "Right" for the Object
specified. If the Object parameter is omitted, checks to see whether the 
user has the right globally.

This still hard codes to check to see if a user has queue-level rights
if we ask about a specific ticket.


This takes the params:

    Right => name of a right

    And either:

    Object => an RT style object (->id will get its id)

    or 

    ObjectId => id #
    ObjectType => an object type



Returns 1 if a matching ACE was found.

Returns undef if no ACE was found.

=cut

sub HasRight {

    my $self = shift;
    my %args = ( Right      => undef,
                 Object     => undef,
                 ObjectId     => undef,
                 ObjectType     => undef,
                 @_ );


    my ($object_id, $object_type) ;
    if ( defined( $args{'Object'} ) && UNIVERSAL::can( $args{'Object'}, 'id' ) )
    {
        $object_id   = $args{'Object'}->id;
        $object_type = ref( $args{'Object'} );
    }
    elsif ( $args{'ObjectId'} && $args{'ObjectType'} ) {
        $object_id   = $args{'ObjectId'};
        $object_type = $args{'ObjectType'};

    }
    else {
        $RT::Logger->crit("$self HasRight called with no valid object");
        return (undef);
    }


    if ( $self->PrincipalObj->Disabled ) {
        $RT::Logger->err( "Disabled User:  " . $self->Name . " failed access check for " . $args{'Right'} );
        if ($object_type) {
            $RT::Logger->err ( " for $object_type $object_id");
        } 
        return (undef);
    }

    if ( !defined $args{'Right'} ) {
        require Carp;
        $RT::Logger->debug( Carp::cluck("HasRight called without a right") );
        return (undef);
    }

    # {{{ If we've cached a win or loss for this lookup say so

    # {{{ Construct a hashkey to cache decisions in
    my ($hashkey);
    {    #it's ugly, but we need to turn off warning, because we're joining nulls.
        local $^W = 0;
        $hashkey = $self->Id . ":" . join ( ";:;", %args );
    }
    # }}}

    #Anything older than 10 seconds needs to be rechecked
    my $cache_timeout = ( time - 10 );

    # {{{ if we've cached a positive result for this query, return 1
    if (    ( defined $self->_ACLCache->{"$hashkey"} )
         && ( $self->_ACLCache->{"$hashkey"} == 1 )
         && ( defined $self->_ACLCache->{"$hashkey"}{'set'} )
         && ( $self->_ACLCache->{"$hashkey"}{'set'} > $cache_timeout ) ) {

        #$RT::Logger->debug("Cached ACL win for ".  $args{'Right'}.$args{'Scope'}.  $args{'AppliesTo'}."\n");	    
        return ( 1);
    }
    # }}}

    #  {{{ if we've cached a negative result for this query return undef
    elsif (    ( defined $self->_ACLCache->{"$hashkey"} )
            && ( $self->_ACLCache->{"$hashkey"} == -1 )
            && ( defined $self->_ACLCache->{"$hashkey"}{'set'} )
            && ( $self->_ACLCache->{"$hashkey"}{'set'} > $cache_timeout ) ) {

        #$RT::Logger->debug("Cached ACL loss decision for ".  $args{'Right'}.$args{'Scope'}.  $args{'AppliesTo'}."\n");	    

        return (undef);
    }
    # }}}

    # }}}



    #  {{{ Out of date docs
    
    #   We want to grant the right if:


    #    # The user has the right as a member of a system-internal or 
    #    # user-defined group
    #
    #    Find all records from the ACL where they're granted to a group 
    #    of type "UserDefined" or "System"
    #    for the object "System or the object "Queue N" and the group we're looking
    #    at has the recursive member $self->Id
    #
    #    # The user has the right based on a role
    #
    #    Find all the records from ACL where they're granted to the role "foo"
    #    for the object "System" or the object "Queue N" and the group we're looking
    #   at is of domain  ("RT::Queue-Role" and applies to the right queue)
    #                             or ("RT::Ticket-Role" and applies to the right ticket)
    #    and the type is the same as the type of the ACL and the group has
    #    the recursive member $self->Id
    #

    # }}}

    my ( $or_look_at_object_rights, $or_check_roles );

    my $right = $args{'Right'};
   

    my @roles;


    # {{{ If this object is a ticket , we want to look at ticket roles
    if ( $object_type eq 'RT::Ticket' ) {
          push (@roles, $self->_RolesForObject($object_type, $object_id));

        # {{{ If we're looking at ticket rights, we also want to look at the associated queue rights.
        # this is a little bit hacky, but basically, now that we've done the ticket roles magic, we load the queue object
        # and ask all the rest of our questions about the queue.
        my $ticket = RT::Ticket->new($RT::SystemUser);
        $ticket->Load($object_id);
        $args{'Object'}   = $ticket->QueueObj;
        $object_type = ref($args{'Object'});
        $object_id = $args{'Object'}->Id;
        # }}}

    }
    # }}}


    # {{{ If we're looking at a queue, we want to check queue roles
    # We don't want to do an "elsif" here because ticket rights above transmute into queue rights
    if ( $object_type eq 'RT::Queue' ) {
          push (@roles, $self->_RolesForObject( $object_type, $object_id));

        $or_check_roles = " OR ( (".join (' OR ', @roles)." ) ".  
        " AND Groups.Type = ACL.PrincipalType AND Groups.Id = Principals.ObjectId AND Principals.PrincipalType = 'Group') ";
    }
    # }}}

    
    # {{{ If an object is defined, we want to look at rights for that object
    if ( $object_type && $object_id) {
        $or_look_at_object_rights =
          " OR (ACL.ObjectType = '" . $object_type . "'  AND ACL.ObjectId = '" . $object_id . "') ";

    }
    # }}}

    #  {{{ Build that honkin-big SQL query



    

    my $query = "SELECT COUNT(ACL.id) from ACL, Groups, Principals, CachedGroupMembers WHERE  ".
    # Only find superuser or rights with the name $right
   "(ACL.RightName = 'SuperUser' OR  ACL.RightName = '$right') ".
   # Never find disabled groups.
   "AND Principals.Disabled = 0 ".
   "AND CachedGroupMembers.Disabled = 0 ".

   # See if the user is a member of the group recursively
   "AND Principals.Id = CachedGroupMembers.GroupId AND CachedGroupMembers.MemberId = '" . $self->PrincipalId . "' ". 

    # Make sure the rights apply to the entire system or to the object in question
    "AND (   ACL.ObjectType = 'RT::System' $or_look_at_object_rights ) ".

    # limit the result set to groups of types ACLEquivalence (user)  UserDefined, SystemInternal and Personal
    "AND ( (  ACL.PrincipalId = Principals.Id and Principals.ObjectId = Groups.Id AND ACL.PrincipalType = 'Group' AND ".
        "(Groups.Domain = 'SystemInternal' OR Groups.Domain = 'UserDefined' OR Groups.Domain = 'ACLEquivalence' OR Groups.Domain = 'Personal'))".

        # have a look at role groups, if there are any
         $or_check_roles.
        " ) ";

    # }}}

    # {{{ Actually check the ACL by performing an SQL query
    #   $RT::Logger->debug("Now Trying $query");	
    $hitcount = $self->_Handle->FetchResult($query);
    # }}}
    
    # {{{ if there's a match, the right is granted 
    if ($hitcount) {

        # Cache a positive hit.
        $self->_ACLCache->{"$hashkey"}{'set'} = time;
        $self->_ACLCache->{"$hashkey"} = 1;
        return (1);
    }
    # }}}
    # {{{ If there's no match, the right is not granted
    else {   

        # 	$RT::Logger->debug("No ACL matched query: $query\n");	
        # cache a negative hit
        $self->_ACLCache->{"$hashkey"}{'set'} = time;
        $self->_ACLCache->{"$hashkey"} = -1;

        return (undef);
    }
    # }}}
    # }}}
}

# }}}

# {{{ _RolesForObject



=head2 _RolesForObject( $object_type, $object_id)

Returns an SQL clause finding role groups for Objects

=cut


sub _RolesForObject {
    my $self = shift;
    my $type = shift;
    my $id = shift;
    my $clause = "(Groups.Domain = '".$type."-Role' AND Groups.Instance = '" . $id. "') ";

    return($clause);
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

=head2
  
  Takes a single argument. returns 1 if $Self->CurrentUser
  has the requested right. returns undef otherwise

=cut

sub CurrentUserHasRight {
    my $self  = shift;
    my $right = shift;

    return ( $self->CurrentUser->HasRight(Right => $right, Object => $RT::System) );
}

# }}}

# {{{ sub _Set

sub _Set {
    my $self = shift;

    my %args = (
        Field => undef,
        Value => undef,
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

    #Set the new value
    my ( $ret, $msg ) = $self->SUPER::_Set(
        Field => $args{'Field'},
        Value => $args{'Value'}
    );

    return ( $ret, $msg );
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

# {{{ ACL caching

# {{{ _ACLCache

=head2 _ACLCache

# Function: _ACLCache
# Type    : private instance
# Args    : none
# Lvalue  : hash: ACLCache
# Desc    : Returns a reference to the Key cache hash

=cut

sub _ACLCache {
    return(\%_USERS_KEY_CACHE);
}

# }}}

# {{{ _InvalidateACLCache

=head2 _InvalidateACLCache

Cleans out and reinitializes the user rights key cache

=cut

sub _InvalidateACLCache {
    %_USERS_KEY_CACHE = ();
}

# }}}

# }}}

1;


