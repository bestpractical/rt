use strict;
use warnings;

package RT::Model::User;

use base qw/RT::Record/;

=head1 NAME

  RT::Model::User - RT User object

=head1 SYNOPSIS

  use RT::Model::User;

=head1 DESCRIPTION


=head1 METHODS



=cut




use Digest::MD5;
use RT::Interface::Email;
use Encode;

use Jifty::DBI::Schema;

sub table {'Users'}

use Jifty::DBI::Record schema {
    column        Name  => max_length is 200,      type is 'varchar(200)', default is '';
    column        Password  => max_length is 40,      type is 'varchar(40)', default is '';
    column        Comments  =>        type is 'blob', default is '';
    column        Signature  =>       type is 'blob', default is '';
    column        EmailAddress  => max_length is 120,      type is 'varchar(120)', default is '';
    column        FreeformContactInfo  =>       type is 'blob', default is '';
    column        Organization  =>, max_length is 200,      type is 'varchar(200)', default is '';
    column        RealName  => max_length is 120,      type is 'varchar(120)', default is '';
    column        NickName  => max_length is 16,      type is 'varchar(16)', default is '';
    column        Lang  => max_length is 16,      type is 'varchar(16)', default is '';
    column        EmailEncoding  => max_length is 16,      type is 'varchar(16)', default is '';
    column        WebEncoding  => max_length is 16,      type is 'varchar(16)', default is '';
    column        ExternalContactInfoId  => max_length is 100,      type is 'varchar(100)', default is '';
    column        ContactInfoSystem  => max_length is 30,      type is 'varchar(30)', default is '';
    column        ExternalAuthId  => max_length is 100,      type is 'varchar(100)', default is '';
    column        AuthSystem  => max_length is 30,      type is 'varchar(30)', default is '';
    column        Gecos  => max_length is 16,      type is 'varchar(16)', default is '';
    column        HomePhone  => max_length is 30,      type is 'varchar(30)', default is '';
    column        WorkPhone  => max_length is 30,      type is 'varchar(30)', default is '';
    column        MobilePhone  => max_length is 30,      type is 'varchar(30)', default is '';
    column        PagerPhone  => max_length is 30,      type is 'varchar(30)', default is '';
    column        Address1  => max_length is 200,      type is 'varchar(200)', default is '';
    column        Address2  => max_length is 200,      type is 'varchar(200)', default is '';
    column        City  => max_length is 100,      type is 'varchar(100)', default is '';
    column        State  => max_length is 100,      type is 'varchar(100)', default is '';
    column        Zip  => max_length is 16,      type is 'varchar(16)', default is '';
    column        Country  => max_length is 50,      type is 'varchar(50)', default is '';
    column        Timezone  => max_length is 50,      type is 'varchar(50)', default is '';
    column        PGPKey  =>        type is 'text';
    column        Creator =>  max_length is 11,      type is 'int(11)', default is '0';
    column        Created =>       type is 'datetime', default is '';
    column        LastUpdatedBy => max_length is 11,      type is 'int(11)', default is '0';
    column        LastUpdated =>       type is 'datetime', default is '';




};




# {{{ sub create 

=head2 Create { PARAMHASH }



=cut


sub create {
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
    Carp::confess unless($self->current_user);
    unless ( $self->current_user->has_right(Right => 'AdminUsers', Object => RT->System) ) {
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
    elsif ( length( $args{'Password'} ) < RT->Config->Get('MinimumPasswordLength') ) {
        return ( 0, $self->loc("Password needs to be at least [_1] characters long",RT->Config->Get('MinimumPasswordLength')) );
    }

    else {
        $args{'Password'} = $self->_GeneratePassword($args{'Password'});
    }

    #TODO Specify some sensible defaults.

    unless ( $args{'Name'} ) {
        return ( 0, $self->loc("Must specify 'Name' attribute") );
    }

    #SANITY CHECK THE NAME AND ABORT IF IT'S TAKEN
    if (RT->SystemUser) {   #This only works if RT::SystemUser has been defined
        my $TempUser = RT::Model::User->new(RT->SystemUser);
        $TempUser->load( $args{'Name'} );
        return ( 0, $self->loc('Name in use') ) if ( $TempUser->id );

        return ( 0, $self->loc('Email address in use') )
          unless ( $self->validate_EmailAddress( $args{'EmailAddress'} ) );
    }
    else {
        $RT::Logger->warning( "$self couldn't check for pre-existing users");
    }


    Jifty->handle->begin_transaction();
    # Groups deal with principal ids, rather than user ids.
    # When creating this user, set up a principal Id for it.
    my $principal = RT::Model::Principal->new($self->current_user);
    my $principal_id = $principal->create(PrincipalType => 'User',
                                Disabled => $args{'Disabled'},
                                ObjectId => '0');
    # If we couldn't create a principal Id, get the fuck out.
    unless ($principal_id) {
        Jifty->handle->rollback();
        $RT::Logger->crit("Couldn't create a Principal on new user create.");
        $RT::Logger->crit("Strange things are afoot at the circle K");
        return ( 0, $self->loc('Could not create user') );
    }

    $principal->__set(column => 'ObjectId', value => $principal_id);
    delete $args{'Disabled'};

    $self->SUPER::create(id => $principal_id , %args);
    my $id = $self->id;

    #If the create failed.
    unless ($id) {
        Jifty->handle->rollback();
        $RT::Logger->error("Could not create a new user - " .join('-', %args));

        return ( 0, $self->loc('Could not create user') );
    }

    my $aclstash = RT::Model::Group->new($self->current_user);
    my $stash_id = $aclstash->_createACLEquivalenceGroup($principal);

    unless ($stash_id) {
        Jifty->handle->rollback();
        $RT::Logger->crit("Couldn't stash the user in groupmembers");
        return ( 0, $self->loc('Could not create user') );
    }


    my $everyone = RT::Model::Group->new($self->current_user);
    $everyone->load_system_internal_group('Everyone');
    unless ($everyone->id) {
        $RT::Logger->crit("Could not load Everyone group on user creation.");
        Jifty->handle->rollback();
        return ( 0, $self->loc('Could not create user') );
    }


    my ($everyone_id, $everyone_msg) = $everyone->_AddMember( InsideTransaction => 1, PrincipalId => $self->PrincipalId);
    unless ($everyone_id) {
        $RT::Logger->crit("Could not add user to Everyone group on user creation.");
        $RT::Logger->crit($everyone_msg);
        Jifty->handle->rollback();
        return ( 0, $self->loc('Could not create user') );
    }


    my $access_class = RT::Model::Group->new($self->current_user);
    if ($privileged)  {
        $access_class->load_system_internal_group('Privileged');
    } else {
        $access_class->load_system_internal_group('Unprivileged');
    }

    unless ($access_class->id) {
        $RT::Logger->crit("Could not load Privileged or Unprivileged group on user creation");
        Jifty->handle->rollback();
        return ( 0, $self->loc('Could not create user') );
    }


    my ($ac_id, $ac_msg) = $access_class->_AddMember( InsideTransaction => 1, PrincipalId => $self->PrincipalId);  

    unless ($ac_id) {
        $RT::Logger->crit("Could not add user to Privileged or Unprivileged group on user creation. Aborted");
        $RT::Logger->crit($ac_msg);
        Jifty->handle->rollback();
        return ( 0, $self->loc('Could not create user') );
    }


    if ( $record_transaction ) {
    $self->_NewTransaction( Type => "Create" );
    }

    Jifty->handle->commit;

    return ( $id, $self->loc('User Created') );
}

# }}}



# {{{ SetPrivileged

=head2 SetPrivileged BOOL

If passed a true value, makes this user a member of the "Privileged"  PseudoGroup.
Otherwise, makes this user a member of the "Unprivileged" pseudogroup. 

Returns a standard RT tuple of (val, msg);


=cut

sub set_Privileged {
    my $self = shift;
    my $val = shift;

    #Check the ACL
    unless ( $self->current_user->has_right(Right => 'AdminUsers', Object => RT->System) ) {
        return ( 0, $self->loc('Permission Denied') );
    }
    my $priv = RT::Model::Group->new($self->current_user);
    $priv->load_system_internal_group('Privileged');
   
    unless ($priv->id) {
        $RT::Logger->crit("Could not find Privileged pseudogroup");
        return(0,$self->loc("Failed to find 'Privileged' users pseudogroup."));
    }

    my $unpriv = RT::Model::Group->new($self->current_user);
    $unpriv->load_system_internal_group('Unprivileged');
    unless ($unpriv->id) {
        $RT::Logger->crit("Could not find unprivileged pseudogroup");
        return(0,$self->loc("Failed to find 'Unprivileged' users pseudogroup"));
    }

    if ($val) {
        if ($priv->has_member($self->PrincipalObj)) {
            #$RT::Logger->debug("That user is already privileged");
            return (0,$self->loc("That user is already privileged"));
        }
        if ($unpriv->has_member($self->PrincipalObj)) {
            $unpriv->_delete_member($self->PrincipalId);
        } else {
        # if we had layered transactions, life would be good
        # sadly, we have to just go ahead, even if something
        # bogus happened
            $RT::Logger->crit("User ".$self->id." is neither privileged nor ".
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
        if ($unpriv->has_member($self->PrincipalObj)) {
            #$RT::Logger->debug("That user is already unprivileged");
            return (0,$self->loc("That user is already unprivileged"));
        }
        if ($priv->has_member($self->PrincipalObj)) {
            $priv->_delete_member( $self->PrincipalId);
        } else {
        # if we had layered transactions, life would be good
        # sadly, we have to just go ahead, even if something
        # bogus happened
            $RT::Logger->crit("User ".$self->id." is neither privileged nor ".
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
    my $priv = RT::Model::Group->new($self->current_user);
    $priv->load_system_internal_group('Privileged');
    if ($priv->has_member($self->PrincipalObj)) {
        return(1);
    }
    else {
        return(undef);
    }
}

# }}}

# {{{ sub _bootstrap_create 

#create a user without validating _any_ data.

#To be used only on database init.
# We can't localize here because it's before we _have_ a loc framework

sub _bootstrap_create {
    my $self = shift;
    my %args = (@_);

    $args{'Password'} = '*NO-PASSWORD*';


    Jifty->handle->begin_transaction(); 

    # Groups deal with principal ids, rather than user ids.
    # When creating this user, set up a principal Id for it.
    my $principal = RT::Model::Principal->new($self->current_user);
    my ($principal_id , $pmsg) = $principal->create(  PrincipalType => 'User', ObjectId => '0', Disabled => '0');
    # If we couldn't create a principal Id, get the fuck out.
    unless ($principal_id) {
        Jifty->handle->rollback();
        $RT::Logger->crit("Couldn't create a Principal on new user create. Strange things are afoot at the circle K: $pmsg");
        return ( 0, 'Could not create user' );
    }
    my ($val,$msg)=    $principal->__set(column => 'ObjectId', value => $principal_id);

    my ($status, $user_msg) = $self->SUPER::create(id => $principal_id, %args);
    unless ($status) {
        die $user_msg;
    }
    my $id = $self->id;
    #If the create failed.
      unless ($id) {
      Jifty->handle->rollback();
      return ( 0, 'Could not create user' ) ; #never loc this
    }

    
    my $aclstash = RT::Model::Group->new($self->current_user);

    my $stash_id  = $aclstash->_createACLEquivalenceGroup($principal);

    unless ($stash_id) {
        Jifty->handle->rollback();
        $RT::Logger->crit("Couldn't stash the user in groupmembers");
        return ( 0, $self->loc('Could not create user') );
    }

                                    
    Jifty->handle->commit();

    return ( $id, 'User Created' );
}

# }}}

# {{{ sub delete 

sub delete {
    my $self = shift;

    return ( 0, $self->loc('Deleting this object would violate referential integrity') );

}

# }}}

# {{{ sub load 

=head2 Load

Load a user object from the database. Takes a single argument.
If the argument is numerical, load by the column 'id'. If a user
object or its subclass passed then loads the same user by id.
Otherwise, load by the "Name" column which is the user's textual
username.

=cut

sub load {
    my $self = shift;
    my $identifier = shift || return undef;

    if ( $identifier !~ /\D/ ) {
        return $self->load_by_id( $identifier );
    }
    elsif ( UNIVERSAL::isa( $identifier, 'RT::Model::User' ) ) {
        return $self->load_by_id( $identifier->id );
    }
    else {
        return $self->load_by_cols( "Name", $identifier );
    }
}

# }}}

# {{{ sub load_by_email

=head2 load_by_email

Tries to load this user object from the database by the user's email address.


=cut

sub load_by_email {
    my $self    = shift;
    my $address = shift;

    # Never load an empty address as an email address.
    unless ($address) {
        return (undef);
    }

    $address = $self->CanonicalizeEmailAddress($address);

    #$RT::Logger->debug("Trying to load an email address: $address\n");
    return $self->load_by_cols( "EmailAddress", $address );
}

# }}}

# {{{ load_or_create_by_email 

=head2 load_or_create_by_email ADDRESS

Attempts to find a user who has the provided email address. If that fails, creates an unprivileged user with
the provided email address and loads them. Address can be provided either as L<Mail::Address> object
or string which is parsed using the module.

Returns a tuple of the user's id and a status message.
0 will be returned in place of the user's id in case of failure.

=cut

sub load_or_create_by_email {
    my $self = shift;
    my $email = shift;

    my ($message, $name);
    if ( UNIVERSAL::isa( $email => 'Mail::Address' ) ) {
        ($email, $name) = ($email->address, $email->phrase);
    } else {
        ($email, $name) = RT::Interface::Email::ParseAddressFromHeader( $email );
    }

    $self->load_by_email( $email );
    $self->load( $email ) unless $self->id;
    $message = $self->loc('User loaded');

    unless( $self->id ) {
        my $val;
        ($val, $message) = $self->create(
            Name         => $email,
            EmailAddress => $email,
            RealName     => $name,
            Privileged   => 0,
            Comments     => 'AutoCreated when added as a watcher',
        );
        unless ( $val ) {
            # Deal with the race condition of two account creations at once
            $self->load_by_email( $email );
            unless ( $self->id ) {
                sleep 5;
                $self->load_by_email( $email );
            }
            if ( $self->id ) {
                $RT::Logger->error("Recovered from creation failure due to race condition");
                $message = $self->loc("User loaded");
            }
            else {
                $RT::Logger->crit("Failed to create user ". $email .": " .$message);
            }
        }
    }
    return (0, $message) unless $self->id;
    return ($self->id, $message);
}

# }}}

# {{{ sub validate_EmailAddress

=head2 ValidateEmailAddress ADDRESS

Returns true if the email address entered is not in use by another user or is 
undef or ''. Returns false if it's in use. 

=cut

sub validate_EmailAddress {
    my $self  = shift;
    my $Value = shift;

    # if the email address is null, it's always valid
    return (1) if ( !$Value || $Value eq "" );

    my $TempUser = RT::Model::User->new(RT->SystemUser);
    $TempUser->load_by_email($Value);

    if ( $TempUser->id && ( !$self->id || $TempUser->id != $self->id ) )
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
that it may be called as a static method; in this case, $self may be
undef.

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


# }}}

# {{{ sub CanonicalizeUserInfo



=head2 CanonicalizeUserInfo HASH of ARGS

CanonicalizeUserInfo can convert all User->create options.
it takes a hashref of all the params sent to User->create and
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

# {{{ sub set_RandomPassword

=head2 SetRandomPassword

Takes no arguments. Returns a status code and a new password or an error message.
If the status is 1, the second value returned is the new password.
If the status is anything else, the new value returned is the error code.

=cut

sub set_RandomPassword {
    my $self = shift;

    unless ( $self->current_userCanModify('Password') ) {
        return ( 0, $self->loc("Permission Denied") );
    }


    my $min = ( RT->Config->Get('MinimumPasswordLength') > 6 ?  RT->Config->Get('MinimumPasswordLength') : 6);
    my $max = ( RT->Config->Get('MinimumPasswordLength') > 8 ?  RT->Config->Get('MinimumPasswordLength') : 8);

    my $pass = $self->GenerateRandomPassword( $min, $max) ;

    # If we have "notify user on 

    my ( $val, $msg ) = $self->set_Password($pass);

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

    unless ( $self->current_userCanModify('Password') ) {
        return ( 0, $self->loc("Permission Denied") );
    }
    my ( $status, $pass ) = $self->set_RandomPassword();

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

# {{{ sub set_Password

=head2 SetPassword

Takes a string. Checks the string's length and sets this user's password 
to that string.

=cut

sub set_Password {
    my $self     = shift;
    my $password = shift;

    unless ( $self->current_userCanModify('Password') ) {
        return ( 0, $self->loc('Password: Permission Denied') );
    }

    if ( !$password ) {
        return ( 0, $self->loc("No password set") );
    }
    elsif ( length($password) < RT->Config->Get('MinimumPasswordLength') ) {
        return ( 0, $self->loc("Password needs to be at least [_1] characters long", RT->Config->Get('MinimumPasswordLength')) );
    }
    else {
        my $new = !$self->HasPassword;
        $password = $self->_GeneratePassword($password);
        my ( $val, $msg ) = $self->_set(column => 'Password', value=> $password);
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
    my $pwd = $self->__value('Password');
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
    if ($self->_GeneratePassword($value) eq $self->__value('Password')) {
        return(1);
    }

    #  if it's a historical password we say ok.
    if ($self->__value('Password') eq crypt($value, $self->__value('Password'))
        or $self->_GeneratePasswordBase64($value) eq $self->__value('Password'))
    {
        # ...but upgrade the legacy password inplace.
        $self->set(column => Password, value => $self->_GeneratePassword($value) );
        return(1);
    }

    # no password check has succeeded. get out

    return (undef);
}

# }}}

# }}}

# {{{ sub set_Disabled

=head2 Sub SetDisabled

Toggles the user's disabled flag.
If this flag is
set, all password checks for this user will fail. All ACL checks for this
user will fail. The user will appear in no user listings.

=cut 

# }}}

sub set_Disabled {
    my $self = shift;
    unless ( $self->current_user->has_right(Right => 'AdminUsers', Object => RT->System) ) {
        return (0, $self->loc('Permission Denied'));
    }
    return $self->PrincipalObj->set_Disabled(@_);
}

sub Disabled {
    my $self = shift;
    return $self->PrincipalObj->Disabled(@_);
}


# {{{ Principal related routines

=head2 PrincipalObj 

Returns the principal object for this user. returns an empty RT::Model::Principal
if there's no principal object matching this user. 
The response is cached. PrincipalObj should never ever change.


=cut


sub PrincipalObj {
    my $self = shift;
    unless ( $self->{'PrincipalObj'} ) {
        my $obj = RT::Model::Principal->new( $self->current_user );
        $obj->load_by_id( $self->id );
        unless ( $obj->id && $obj->PrincipalType eq 'User' ) {
            Carp::cluck;
            $RT::Logger->crit( 'Wrong principal for user #'. $self->id );
        } else {
            $self->{'PrincipalObj'} = $obj;
        }
    }
    return $self->{'PrincipalObj'};
}


=head2 PrincipalId  

Returns this user's PrincipalId

=cut

sub PrincipalId {
    my $self = shift;
    return $self->id;
}

# }}}



# {{{ sub HasGroupRight

=head2 HasGroupRight

Takes a paramhash which can contain
these items:
    GroupObj => RT::Model::Group or Group => integer
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
        $args{'GroupObj'} = RT::Model::Group->new( $self->current_user );
        $args{'GroupObj'}->load( $args{'Group'} );
    }

    # {{{ Validate and load up the GroupId
    unless ( ( defined $args{'GroupObj'} ) and ( $args{'GroupObj'}->id ) ) {
        return undef;
    }

    # }}}


    # Figure out whether a user has the right we're asking about.
    my $retval = $self->has_right(
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
    my $groups = RT::Model::GroupCollection->new($self->current_user);
    $groups->LimitToUserDefinedGroups;
    $groups->WithMember(PrincipalId => $self->id, 
            Recursively => 1);
    return $groups;
}

# }}}

# {{{ sub Rights testing

=head1 Rights testing



=cut

# }}}


# {{{ sub has_right

=head2 has_right

Shim around PrincipalObj->has_right. See RT::Model::Principal

=cut

sub has_right {

    my $self = shift;
    return  $self->PrincipalObj->has_right(@_);

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

    if ( $self->current_user->has_right(Right => 'AdminUsers', Object => RT->System) ) {
        return (1);
    }

    #If the field is marked as an "administrators only" field, 
    # don\'t let the user touch it.
    elsif (0) {# $self->_Accessible( $right, 'admin' ) ) {
        return (undef);
    }

    #If the current user is trying to modify themselves
    elsif ( ( $self->id == $self->current_user->id )
        and ( $self->current_user->has_right(Right => 'ModifySelf', Object => RT->System) ) )
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

# {{{ sub current_user_has_right

=head2 current_user_has_right
  
Takes a single argument. returns 1 if $Self->current_user
has the requested right. returns undef otherwise

=cut

sub current_user_has_right {
    my $self  = shift;
    my $right = shift;
    return ( $self->current_user->has_right(Right => $right, Object => RT->System) );
}

sub _PrefName {
    my $name = shift;
    if (ref $name) {
        $name = ref($name).'-'.$name->id;
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

    my $attr = RT::Model::Attribute->new( $self->current_user );
    $attr->load_by_nameAndObject( Object => $self, Name => $name );

    my $content = $attr->id ? $attr->Content : undef;
    unless ( ref $content eq 'HASH' ) {
        return defined $content ? $content : $default;
    }

    if (ref $default eq 'HASH') {
        for (keys %$default) {
            exists $content->{$_} or $content->{$_} = $default->{$_};
        }
    }
    elsif (defined $default) {
        $RT::Logger->error("Preferences $name for user".$self->id." is hash but default is not");
    }
    return $content;
}

# }}}

# {{{ sub set_Preferences

=head2 SetPreferences NAME/OBJ value

  Set user preferences associated with given object or name.

=cut

sub set_Preferences {
    my $self = shift;
    my $name = _PrefName( shift );
    my $value = shift;
    my $attr = RT::Model::Attribute->new( $self->current_user );
    $attr->load_by_nameAndObject( Object => $self, Name => $name );
    if ( $attr->id ) {
        return $attr->set_Content( $value );
    }
    else {
        return $self->add_attribute( Name => $name, Content => $value );
    }
}

# }}}


=head2 WatchedQueues ROLE_LIST

Returns a RT::Model::QueueCollection object containing every queue watched by the user.

Takes a list of roles which is some subset of ('Cc', 'AdminCc').  Defaults to:

$user->WatchedQueues('Cc', 'AdminCc');

=cut

sub WatchedQueues {

    my $self = shift;
    my @roles = @_ || ('Cc', 'AdminCc');

    $RT::Logger->debug('WatcheQueues got user ' . $self->Name);

    my $watched_queues = RT::Model::QueueCollection->new($self->current_user);

    my $group_alias = $watched_queues->join(
                                             alias1 => 'main',
                                             column1 => 'id',
                                             table2 => 'Groups',
                                             column2 => 'Instance',
                                           );

    $watched_queues->limit( 
                            alias => $group_alias,
                            column => 'Domain',
                            value => 'RT::Model::Queue-Role',
                            entry_aggregator => 'AND',
                          );
    if (grep { $_ eq 'Cc' } @roles) {
        $watched_queues->limit(
                                subclause => 'LimitToWatchers',
                                alias => $group_alias,
                                column => 'Type',
                                value => 'Cc',
                                entry_aggregator => 'OR',
                              );
    }
    if (grep { $_ eq 'AdminCc' } @roles) {
        $watched_queues->limit(
                                subclause => 'LimitToWatchers',
                                alias => $group_alias,
                                column => 'Type',
                                value => 'AdminCc',
                                entry_aggregator => 'OR',
                              );
    }

    my $queues_alias = $watched_queues->join(
                                              alias1 => $group_alias,
                                              column1 => 'id',
                                              table2 => 'CachedGroupMembers',
                                              column2 => 'GroupId',
                                            );
    $watched_queues->limit(
                            alias => $queues_alias,
                            column => 'MemberId',
                            value => $self->PrincipalId,
                          );

    $RT::Logger->debug("WatchedQueues got " . $watched_queues->count . " queues");
    
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
# RT::Model::User and RT::Model::Group.  If the recursive cleanup call for groups is
# ever unrolled and merged, this code will probably want to be
# factored out into RT::Model::Principal.

sub _CleanupInvalidDelegations {
    my $self = shift;
    my %args = ( InsideTransaction => undef,
          @_ );

    unless ( $self->id ) {
    $RT::Logger->warning("User not loaded.");
    return (undef);
    }

    my $in_trans = $args{InsideTransaction};

    return(1) if ($self->has_right(Right => 'DelegateRights',
                  Object => RT->System));

    # Look up all delegation rights currently posessed by this user.
    my $deleg_acl = RT::Model::ACECollection->new(RT->SystemUser);
    $deleg_acl->LimitToPrincipal(Type => 'User',
                 Id => $self->PrincipalId,
                 IncludeGroupMembership => 1);
    $deleg_acl->limit( column => 'RightName',
               operator => '=',
               value => 'DelegateRights' );
    my @allowed_deleg_objects = map {$_->Object()}
    @{$deleg_acl->items_array_ref()};

    # Look up all rights delegated by this principal which are
    # inconsistent with the allowed delegation objects.
    my $acl_to_del = RT::Model::ACECollection->new(RT->SystemUser);
    $acl_to_del->DelegatedBy(Id => $self->id);
    foreach (@allowed_deleg_objects) {
    $acl_to_del->LimitNotObject($_);
    }

    # Delete all disallowed delegations
    while ( my $ace = $acl_to_del->next() ) {
    my $ret = $ace->_delete(InsideTransaction => 1);
    unless ($ret) {
        Jifty->handle->rollback() unless $in_trans;
        $RT::Logger->warning("Couldn't delete delegated ACL entry ".$ace->id);
        return (undef);
    }
    }

    Jifty->handle->commit() unless $in_trans;
    return (1);
}

# }}}

# {{{ sub _set

sub _set {
    my $self = shift;

    my %args = (
        column => undef,
        value => undef,
    TransactionType   => 'Set',
    RecordTransaction => 1,
        @_
    );

    # Nobody is allowed to futz with RT_System or Nobody 

    if ( ($self->id == RT->SystemUser->id )  || 
         ($self->id == $RT::Nobody->id)) {
        return ( 0, $self->loc("Can not modify system users") );
    }
    unless ( $self->current_userCanModify( $args{'column'} ) ) {
        return ( 0, $self->loc("Permission Denied") );
    }

    my $Old = $self->SUPER::_value($args{'column'});
    
    my ($ret, $msg) = $self->SUPER::_set( column => $args{'column'},
                      value => $args{'value'} );
    
    #If we can't actually set the field to the value, don't record
    # a transaction. instead, get out of here.
    if ( $ret == 0 ) { return ( 0, $msg ); }

    if ( $args{'RecordTransaction'} == 1 ) {

        my ( $Trans, $Msg, $TransObj ) = $self->_NewTransaction(
                                               Type => $args{'TransactionType'},
                                               Field     => $args{'column'},
                                               NewValue  => $args{'value'},
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

# {{{ sub _value 

=head2 _value

Takes the name of a table column.
Returns its value as a string, if the user passes an ACL check

=cut

sub _value {

    my $self  = shift;
    my $field = shift;

    #If the current user doesn't have ACLs, don't let em at it.  

    my %public_fields = map {$_ => 1 } qw( Name EmailAddress 
    id Organization Disabled
      RealName NickName Gecos ExternalAuthId
      AuthSystem ExternalContactInfoId
      ContactInfoSystem );

    #if the field is public, return it.

    if ($public_fields{$field}) {
        return ( $self->SUPER::_value($field) );

    }

    #If the user wants to see their own values, let them
    # TODO figure ouyt a better way to deal with this
   if ( $self->id && $self->current_user && $self->current_user->id == $self->id ) {
        return ( $self->SUPER::_value($field) );
    }

    #If the user has the admin users right, return the field
    elsif ($self->current_user &&  $self->current_user->has_right(Right =>'AdminUsers', Object => RT->System) ) {
        return ( $self->SUPER::_value($field) );
    }
    else {
        return (undef);
    }

}

# }}}

# {{{ sub FriendlyName

=head2 FriendlyName

  Return the friendly name

=cut

sub FriendlyName {
    my $self = shift;
    return $self->RealName if defined($self->RealName);
    return $self->Name if defined($self->Name);
    return "";
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


