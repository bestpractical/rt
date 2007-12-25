use strict;
use warnings;

package RT::Model::User;

use base qw/RT::Record/;

=head1 name

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
    column comments  => type is 'blob', default is '';
    column Signature => type is 'blob', default is '';
    column freeform_contact_info => type is 'blob', default is '';
    column
        organization =>,
        max_length is 200, type is 'varchar(200)', default is '';
    column
        real_name => max_length is 120,
        type is 'varchar(120)', default is '';
    column nickname => max_length is 16, type is 'varchar(16)', default is '';
    column lang     => max_length is 16, type is 'varchar(16)', default is '';
    column
        email_encoding => max_length is 16,
        type is 'varchar(16)', default is '';
    column
        web_encoding => max_length is 16,
        type is 'varchar(16)', default is '';
    column
        ExternalContactInfoId => max_length is 100,
        type is 'varchar(100)', default is '';
    column
        ContactInfoSystem => max_length is 30,
        type is 'varchar(30)', default is '';
    column
        ExternalAuthId => max_length is 100,
        type is 'varchar(100)', default is '';
    column
        auth_system => max_length is 30,
        type is 'varchar(30)', default is '';
    column Gecos => max_length is 16, type is 'varchar(16)', default is '';
    column
        HomePhone => max_length is 30,
        type is 'varchar(30)', default is '';
    column
        WorkPhone => max_length is 30,
        type is 'varchar(30)', default is '';
    column
        MobilePhone => max_length is 30,
        type is 'varchar(30)', default is '';
    column
        PagerPhone => max_length is 30,
        type is 'varchar(30)', default is '';
    column
        Address1 => max_length is 200,
        type is 'varchar(200)', default is '';
    column
        Address2 => max_length is 200,
        type is 'varchar(200)', default is '';
    column City  => max_length is 100, type is 'varchar(100)', default is '';
    column State => max_length is 100, type is 'varchar(100)', default is '';
    column Zip   => max_length is 16,  type is 'varchar(16)',  default is '';
    column Country  => max_length is 50, type is 'varchar(50)', default is '';
    column Timezone => max_length is 50, type is 'varchar(50)', default is '';
    column PGPKey   => type is 'text';

};

use Jifty::Plugin::User::Mixin::Model::User; # name, email, email_confirmed
use Jifty::Plugin::Authentication::Password::Mixin::Model::User;

# XXX TODO, merging params should 'just work' but does not 
 __PACKAGE__->column('email')->writable(1);



# {{{ sub create 

=head2 Create { PARAMHASH }



=cut


sub create {
    my $self = shift;
    my %args = (
        privileged => 0,
        disabled => 0,
        email => '',
        email_confirmed => 1,
        _RecordTransaction => 1,
        @_    # get the real argumentlist
    );

    # remove the value so it does not cripple SUPER::Create
    my $record_transaction = delete $args{'_RecordTransaction'};

    #Check the ACL
    Carp::confess unless($self->current_user);
    unless ( $self->current_user->user_object->has_right(Right => 'AdminUsers', Object => RT->system) ) {
        return ( 0, _('No permission to create users') );
    }


    unless ($self->canonicalize_UserInfo(\%args)) {
        return ( 0, _("Could not set user info") );
    }

    $args{'email'} = $self->canonicalize_email($args{'email'});

    # if the user doesn't have a name defined, set it to the email address
    $args{'name'} = $args{'email'} unless ($args{'name'});



    # privileged is no longer a column in users
    my $privileged = $args{'privileged'};
    delete $args{'privileged'};


    if ( !$args{'password'} ) {
        $args{'password'} = '*NO-PASSWORD*';
    }
    
    elsif ( length( $args{'password'} ) < RT->Config->Get('MinimumpasswordLength') ) {
        return ( 0, _("password needs to be at least %1 characters long",RT->Config->Get('MinimumpasswordLength')) );
    }

    unless ( $args{'name'} ) {
        return ( 0, _("Must specify 'name' attribute") );
    }

    #SANITY CHECK THE name AND ABORT IF IT'S TAKEN
    if (RT->system_user) {   #This only works if RT::system_user has been defined
        my $TempUser = RT::Model::User->new(current_user => RT->system_user);
        $TempUser->load( $args{'name'} );
        return ( 0, _('name in use') ) if ( $TempUser->id );

        return ( 0, _('Email address in use') )
          unless ( $self->validate_email( $args{'email'} ) );
    }
    else {
        $RT::Logger->warning( "$self couldn't check for pre-existing users");
    }


    Jifty->handle->begin_transaction();
    # Groups deal with principal ids, rather than user ids.
    # When creating this user, set up a principal Id for it.
    my $principal = RT::Model::Principal->new;
    my $principal_id = $principal->create(principal_type => 'User',
                                disabled => $args{'disabled'},
                                object_id => '0');
    # If we couldn't create a principal Id, get the fuck out.
    unless ($principal_id) {
        Jifty->handle->rollback();
        $RT::Logger->crit("Couldn't create a Principal on new user create.");
        $RT::Logger->crit("Strange things are afoot at the circle K");
        return ( 0, _('Could not create user') );
    }

    $principal->__set(column => 'object_id', value => $principal_id);
    delete $args{'disabled'};

    $self->SUPER::create(id => $principal_id , %args);
    my $id = $self->id;

    #If the create failed.
    unless ($id) {
        Jifty->handle->rollback();
        $RT::Logger->error("Could not create a new user - " .join('-', %args));

        return ( 0, _('Could not create user') );
    }

    my $aclstash = RT::Model::Group->new;
    my $stash_id = $aclstash->_createacl_equivalence_group($principal);

    unless ($stash_id) {
        Jifty->handle->rollback();
        $RT::Logger->crit("Couldn't stash the user in groupmembers");
        return ( 0, _('Could not create user') );
    }


    my $everyone = RT::Model::Group->new;
    $everyone->load_system_internal_group('Everyone');
    unless ($everyone->id) {
        $RT::Logger->crit("Could not load Everyone group on user creation.");
        Jifty->handle->rollback();
        return ( 0, _('Could not create user') );
    }


    my ($everyone_id, $everyone_msg) = $everyone->_add_member( InsideTransaction => 1, principal_id => $self->principal_id);
    unless ($everyone_id) {
        $RT::Logger->crit("Could not add user to Everyone group on user creation.");
        $RT::Logger->crit($everyone_msg);
        Jifty->handle->rollback();
        return ( 0, _('Could not create user') );
    }


    my $access_class = RT::Model::Group->new;
    if ($privileged)  {
        $access_class->load_system_internal_group('privileged');
    } else {
        $access_class->load_system_internal_group('Unprivileged');
    }

    unless ($access_class->id) {
        $RT::Logger->crit("Could not load privileged or Unprivileged group on user creation");
        Jifty->handle->rollback();
        return ( 0, _('Could not create user') );
    }


    my ($ac_id, $ac_msg) = $access_class->_add_member( InsideTransaction => 1, principal_id => $self->principal_id);  

    unless ($ac_id) {
        $RT::Logger->crit("Could not add user to privileged or Unprivileged group on user creation. Aborted");
        $RT::Logger->crit($ac_msg);
        Jifty->handle->rollback();
        return ( 0, _('Could not create user') );
    }


    if ( $record_transaction ) {
    $self->_NewTransaction( Type => "Create" );
    }

    Jifty->handle->commit;

    return ( $id, _('User Created') );
}

# }}}



# {{{ Setprivileged

=head2 Setprivileged BOOL

If passed a true value, makes this user a member of the "privileged"  PseudoGroup.
Otherwise, makes this user a member of the "Unprivileged" pseudogroup. 

Returns a standard RT tuple of (val, msg);


=cut

sub set_privileged {
    my $self = shift;
    my $val = shift;

    #Check the ACL
    unless ( $self->current_user->has_right(Right => 'AdminUsers', Object => RT->system) ) {
        return ( 0, _('Permission Denied') );
    }
    my $priv = RT::Model::Group->new;
    $priv->load_system_internal_group('privileged');
   
    unless ($priv->id) {
        $RT::Logger->crit("Could not find privileged pseudogroup");
        return(0,_("Failed to find 'privileged' users pseudogroup."));
    }

    my $unpriv = RT::Model::Group->new;
    $unpriv->load_system_internal_group('Unprivileged');
    unless ($unpriv->id) {
        $RT::Logger->crit("Could not find unprivileged pseudogroup");
        return(0,_("Failed to find 'Unprivileged' users pseudogroup"));
    }

    if ($val) {
        if ($priv->has_member($self->principal_object)) {
            #$RT::Logger->debug("That user is already privileged");
            return (0,_("That user is already privileged"));
        }
        if ($unpriv->has_member($self->principal_object)) {
            $unpriv->_delete_member($self->principal_id);
        } else {
        # if we had layered transactions, life would be good
        # sadly, we have to just go ahead, even if something
        # bogus happened
            $RT::Logger->crit("User ".$self->id." is neither privileged nor ".
                "unprivileged. something is drastically wrong.");
        }
        my ($status, $msg) = $priv->_add_member( InsideTransaction => 1, principal_id => $self->principal_id);  
        if ($status) {
            return (1, _("That user is now privileged"));
        } else {
            return (0, $msg);
        }
    }
    else {
        if ($unpriv->has_member($self->principal_object)) {
            #$RT::Logger->debug("That user is already unprivileged");
            return (0,_("That user is already unprivileged"));
        }
        if ($priv->has_member($self->principal_object)) {
            $priv->_delete_member( $self->principal_id);
        } else {
        # if we had layered transactions, life would be good
        # sadly, we have to just go ahead, even if something
        # bogus happened
            $RT::Logger->crit("User ".$self->id." is neither privileged nor ".
                "unprivileged. something is drastically wrong.");
        }
        my ($status, $msg) = $unpriv->_add_member( InsideTransaction => 1, principal_id => $self->principal_id);  
        if ($status) {
            return (1, _("That user is now unprivileged"));
        } else {
            return (0, $msg);
        }
    }
}

# }}}

# {{{ privileged

=head2 privileged

Returns true if this user is privileged. Returns undef otherwise.

=cut

sub privileged {
    my $self = shift;
    my $priv = RT::Model::Group->new;
    $priv->load_system_internal_group('privileged');
    if ($priv->has_member($self->principal_object)) {
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

    Jifty->handle->begin_transaction(); 

    # Groups deal with principal ids, rather than user ids.
    # When creating this user, set up a principal Id for it.
    my $principal = RT::Model::Principal->new(current_user => RT::CurrentUser->new(_bootstrap => 1));
    my ($principal_id , $pmsg) = $principal->create(  principal_type => 'User', object_id => '0', disabled => '0');
    # If we couldn't create a principal Id, get the fuck out.
    unless ($principal_id) {
        Jifty->handle->rollback();
        $RT::Logger->crit("Couldn't create a Principal on new user create. Strange things are afoot at the circle K: $pmsg");
        return ( 0, 'Could not create user' );
    }
    my ($val,$msg)=    $principal->__set(column => 'object_id', value => $principal_id);

    my ($status, $user_msg) = $self->SUPER::create(id => $principal_id, %args, password => '*NO-PASSWORD*');
    unless ($status) {
        die $user_msg;
    }
    my $id = $self->id;
    #If the create failed.
      unless ($id) {
      Jifty->handle->rollback();
      return ( 0, 'Could not create user' ) ; #never loc this
    }

    
    my $aclstash = RT::Model::Group->new;

    my $stash_id  = $aclstash->_createacl_equivalence_group($principal);

    unless ($stash_id) {
        Jifty->handle->rollback();
        $RT::Logger->crit("Couldn't stash the user in groupmembers");
        return ( 0, _('Could not create user') );
    }

                                    
    Jifty->handle->commit();

    return ( $id, 'User Created' );
}

# }}}

# {{{ sub delete 

sub delete {
    my $self = shift;

    return ( 0, _('Deleting this object would violate referential integrity') );

}

# }}}

# {{{ sub load 

=head2 Load

Load a user object from the database. Takes a single argument.
If the argument is numerical, load by the column 'id'. If a user
object or its subclass passed then loads the same user by id.
Otherwise, load by the "name" column which is the user's textual
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
        return $self->load_by_cols( "name", $identifier );
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

    $address = $self->canonicalize_email($address);

    #$RT::Logger->debug("Trying to load an email address: $address\n");
    return $self->load_by_cols( "email", $address );
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
    $message = _('User loaded');

    unless( $self->id ) {
        my $val;
        ($val, $message) = $self->create(
            name         => $email,
            email => $email,
            real_name     => $name,
            privileged   => 0,
            comments     => 'AutoCreated when added as a watcher',
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
                $message = _("User loaded");
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

# {{{ sub validate_email

=head2 Validateemail ADDRESS

Returns true if the email address entered is not in use by another user or is 
undef or ''. Returns false if it's in use. 

=cut

sub validate_email {
    my $self  = shift;
    my $Value = shift;

    # if the email address is null, it's always valid
    return (1) if ( !$Value || $Value eq "" );

    my $TempUser = RT::Model::User->new(current_user => RT->system_user);
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

# {{{ sub canonicalize_email



=head2 canonicalize_email ADDRESS

canonicalize_email converts email addresses into canonical form.
it takes one email address in and returns the proper canonical
form. You can dump whatever your proper local config is in here.  Note
that it may be called as a static method; in this case, $self may be
undef.

=cut

sub canonicalize_email {
    my $self = shift;
    my $email = shift;
    # Example: the following rule would treat all email
    # coming from a subdomain as coming from second level domain
    # foo.com
    if ( my $match   = RT->Config->Get('canonicalize_emailMatch') and
         my $replace = RT->Config->Get('canonicalize_emailReplace') )
    {
        $email =~ s/$match/$replace/gi;
    }
    return ($email);
}


# }}}

# {{{ sub canonicalize_UserInfo



=head2 canonicalize_UserInfo HASH of ARGS

canonicalize_UserInfo can convert all User->create options.
it takes a hashref of all the params sent to User->create and
returns that same hash, by default nothing is done.

This function is intended to allow users to have their info looked up via
an outside source and modified upon creation.

=cut

sub canonicalize_UserInfo {
    my $self = shift;
    my $args = shift;
    my $success = 1;

    return ($success);
}


# }}}


# {{{ password related functions

# {{{ sub set_Randompassword

=head2 SetRandompassword

Takes no arguments. Returns a status code and a new password or an error message.
If the status is 1, the second value returned is the new password.
If the status is anything else, the new value returned is the error code.

=cut

sub set_Randompassword {
    my $self = shift;

    unless ( $self->current_user_can_modify('password') ) {
        return ( 0, _("Permission Denied") );
    }


    my $min = ( RT->Config->Get('MinimumpasswordLength') > 6 ?  RT->Config->Get('MinimumpasswordLength') : 6);
    my $max = ( RT->Config->Get('MinimumpasswordLength') > 8 ?  RT->Config->Get('MinimumpasswordLength') : 8);
    my $pass =    Text::Password::Pronounceable->generate($min => $max);

    # If we have "notify user on 

    my ( $val, $msg ) = $self->set_password($pass);

    #If we got an error return the error.
    return ( 0, $msg ) unless ($val);

    #Otherwise, we changed the password, lets return it.
    return ( 1, $pass );

}

# }}}


# }}}

# {{{ sub set_password

=head2 Setpassword

Takes a string. Checks the string's length and sets this user's password 
to that string.

=cut

sub before_set_password {
    my $self     = shift;
    my $password = shift;

    unless ( $self->current_user_can_modify('password') ) {
        return ( 0, _('password: Permission Denied') );
    }

    if ( !$password ) {
        return ( 0, _("No password set") );
    }
    elsif ( length($password) < RT->Config->Get('MinimumpasswordLength') ) {
        return ( 0, _("password needs to be at least %1 characters long", RT->Config->Get('MinimumpasswordLength')) );
    }
            return ( 1, "ok");

}


# }}}

                                                                                
=head2 has_password
                                                                                
Returns true if the user has a valid password, otherwise returns false.         
                                                                               
=cut


sub has_password {
    my $self = shift;
    my $pwd = $self->__value('password');
    return undef if !defined $pwd
                    || $pwd eq ''
                    || $pwd eq '*NO-PASSWORD*';
    return 1;
}


# }}}

# }}}

# {{{ sub set_disabled

=head2 Sub Setdisabled

Toggles the user's disabled flag.
If this flag is
set, all password checks for this user will fail. All ACL checks for this
user will fail. The user will appear in no user listings.

=cut 

# }}}

sub set_disabled {
    my $self = shift;
    unless ( $self->current_user->has_right(Right => 'AdminUsers', Object => RT->system) ) {
        return (0, _('Permission Denied'));
    }
    return $self->principal_object->set_disabled(@_);
}

sub disabled {
    my $self = shift;
    return $self->principal_object->disabled(@_);
}


# {{{ Principal related routines

=head2 principal_object 

Returns the principal object for this user. returns an empty RT::Model::Principal
if there's no principal object matching this user. 
The response is cached. principal_object should never ever change.


=cut


sub principal_object {
    my $self = shift;

    unless ( $self->id ) {
        $RT::Logger->error('User not found');
        return;
    }

    unless ( $self->{'principal_object'} ) {
        my $obj = RT::Model::Principal->new;
        $obj->load_by_id( $self->id );
        unless ( $obj->id && $obj->principal_type eq 'User' ) {
            Carp::cluck;
            $RT::Logger->crit( 'Wrong principal for user #'. $self->id );
        } else {
            $self->{'principal_object'} = $obj;
        }
    }
    return $self->{'principal_object'};
}


=head2 principal_id  

Returns this user's principal_id

=cut

sub principal_id {
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
        $args{'GroupObj'} = RT::Model::Group->new;
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
    my $groups = RT::Model::GroupCollection->new;
    $groups->LimitToUserDefinedGroups;
    $groups->WithMember(principal_id => $self->id, 
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

Shim around principal_object->has_right. See RT::Model::Principal

=cut

sub has_right {
    my $self = shift;
    return  $self->principal_object->has_right(@_);

}

# }}}

# {{{ sub current_user_can_modify

=head2 current_user_can_modify RIGHT

If the user has rights for this object, either because
he has 'AdminUsers' or (if he\'s trying to edit himself and the right isn\'t an 
admin right) 'ModifySelf', return 1. otherwise, return undef.

=cut

sub current_user_can_modify {
    my $self  = shift;
    my $right = shift;

    if ( $self->current_user->has_right(Right => 'AdminUsers', Object => RT->system) ) {
        return (1);
    }

    #If the field is marked as an "administrators only" field, 
    # don\'t let the user touch it.
    elsif (0) {# $self->_Accessible( $right, 'admin' ) ) {
        return (undef);
    }

    #If the current user is trying to modify themselves
    elsif ( ( $self->id == $self->current_user->id )
        and ( $self->current_user->has_right(Right => 'ModifySelf', Object => RT->system) ) )
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
    return ( $self->current_user->has_right(Right => $right, Object => RT->system) );
}

# }}}

sub _Prefname {
    my $name = shift;
    if (ref $name) {
        $name = ref($name).'-'.$name->id;
    }

    return 'Pref-'.$name;
}

# {{{ sub Preferences

=head2 Preferences name/OBJ DEFAULT

  Obtain user preferences associated with given object or name.
  Returns DEFAULT if no preferences found.  If DEFAULT is a hashref,
  override the entries with user preferences.

=cut

sub Preferences {
    my $self  = shift;
    my $name = _Prefname (shift);
    my $default = shift;

    my $attr = RT::Model::Attribute->new;
    $attr->load_by_nameAndObject( Object => $self, name => $name );

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

=head2 SetPreferences name/OBJ value

  Set user preferences associated with given object or name.

=cut

sub set_Preferences {
    my $self = shift;
    my $name = _Prefname( shift );
    my $value = shift;
    my $attr = RT::Model::Attribute->new;
    $attr->load_by_nameAndObject( Object => $self, name => $name );
    if ( $attr->id ) {
        return $attr->set_Content( $value );
    }
    else {
        return $self->add_attribute( name => $name, Content => $value );
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

    $RT::Logger->debug('WatcheQueues got user ' . $self->name);

    my $watched_queues = RT::Model::QueueCollection->new;

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
                            value => $self->principal_id,
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
                  Object => RT->system));

    # Look up all delegation rights currently posessed by this user.
    my $deleg_acl = RT::Model::ACECollection->new(current_user => RT->system_user);
    $deleg_acl->LimitToPrincipal(Type => 'User',
                 Id => $self->principal_id,
                 IncludeGroupMembership => 1);
    $deleg_acl->limit( column => 'right_name',
               operator => '=',
               value => 'DelegateRights' );
    my @allowed_deleg_objects = map {$_->Object()}
    @{$deleg_acl->items_array_ref()};

    # Look up all rights delegated by this principal which are
    # inconsistent with the allowed delegation objects.
    my $acl_to_del = RT::Model::ACECollection->new(current_user => RT->system_user);
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

    if ( ($self->id == RT->system_user->id )  || 
         ($self->id == RT->nobody->id)) {
        return ( 0, _("Can not modify system users") );
    }
    unless ( $self->current_user_can_modify( $args{'column'} ) ) {
        return ( 0, _("Permission Denied") );
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

    my %public_fields = map {$_ => 1 } qw( name email 
    id organization disabled
      real_name nickname Gecos ExternalAuthId
      auth_system ExternalContactInfoId
      ContactInfoSystem );

    #if the field is public, return it.

    if ($public_fields{$field}) {
        return ( $self->SUPER::_value($field) );

    }

    #If the user wants to see their own values, let them
    # TODO figure ouyt a better way to deal with this
   if ( $self->id && $self->current_user->id && $self->current_user->id == $self->id ) {
        return ( $self->SUPER::_value($field) );
    }

    #If the user has the admin users right, return the field
    elsif ($self->current_user->user_object &&  $self->current_user->user_object->has_right(Right =>'AdminUsers', Object => RT->system) ) {
        return ( $self->SUPER::_value($field) );
    }
    else {
        return (undef);
    }

}

# }}}

# {{{ sub friendly_name

=head2 friendly_name

  Return the friendly name

=cut

sub friendly_name {
    my $self = shift;
    return $self->real_name if defined($self->real_name);
    return $self->name if defined($self->name);
    return "";
}

# }}}

=head2 PreferredKey

Returns the preferred key of the user. If none is set, then this will query
GPG and set the preferred key to the maximally trusted key found (and then
return it). Returns C<undef> if no preferred key can be found.

=cut

sub PreferredKey
{
    my $self = shift;
    return undef unless RT->Config->Get('GnuPG')->{'Enable'};
    my $prefkey = $self->first_attribute('PreferredKey');
    return $prefkey->Content if $prefkey;

    # we don't have a preferred key for this user, so now we must query GPG
    require RT::Crypt::GnuPG;
    my %res = RT::Crypt::GnuPG::GetKeysForEncryption($self->email);
    return undef unless defined $res{'info'};
    my @keys = @{ $res{'info'} };
    return undef if @keys == 0;

    if (@keys == 1) {
        $prefkey = $keys[0]->{'Fingerprint'};
    }
    else {
        # prefer the maximally trusted key
        @keys = sort { $b->{'TrustLevel'} <=> $a->{'TrustLevel'} } @keys;
        $prefkey = $keys[0]->{'Fingerprint'};
    }

    $self->set_attribute(name => 'PreferredKey', Content => $prefkey);
    return $prefkey;
}

sub BasicColumns {
    (
    [ name => 'User Id' ],
    [ email => 'Email' ],
    [ real_name => 'name' ],
    [ organization => 'organization' ],
    );
}


1;


