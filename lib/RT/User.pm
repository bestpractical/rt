# $Header$
# (c) 1996-2000 Jesse Vincent <jesse@fsck.com>
# This software is redistributable under the terms of the GNU GPL

=head1 NAME

  RT::User - RT User object

=head1 SYNOPSIS

  use RT::User;

=head1 DESCRIPTION


=head1 METHODS

=begin testing

ok(require RT::TestHarness);
ok(require RT::User);

=end testing


=cut


package RT::User;
use RT::Record;
@ISA= qw(RT::Record);

# {{{ sub _Init
sub _Init  {
    my $self = shift;
    $self->{'table'} = "Users";
    return($self->SUPER::_Init(@_));
}
# }}}

# {{{ sub _Accessible 

sub _Accessible  {
  my $self = shift;
  my %Cols = (
	      # {{{ Core RT info
	      Name => 'public/read/write/admin',
	      Password => 'write',
	      Comments => 'read/write/admin',
	      Signature => 'read/write',
	      EmailAddress => 'public/read/write',
	      PagerEmailAddress => 'read/write',
	      FreeformContactInfo => 'read/write',
	      Organization => 'public/read/write/admin',
	      Disabled => 'public/read/write/admin', #To modify this attribute, we have helper
	      #methods
	      Privileged => 'read/write/admin', # 0=no 1=user 2=system

	      # }}}
	      
	      # {{{ Names
	      
	      RealName => 'public/read/write',
	      NickName => 'public/read/write',
	      # }}}
	      	      
	      # {{{ Localization and Internationalization
	      Lang => 'public/read/write',
	      EmailEncoding => 'public/read/write',
	      WebEncoding => 'public/read/write',
	      # }}}
	      
	      # {{{ External ContactInfo Linkage
	      ExternalContactInfoId => 'public/read/write/admin',
	      ContactInfoSystem => 'public/read/write/admin',
	      # }}}
	      
	      # {{{ User Authentication identifier
	      ExternalAuthId => 'public/read/write/admin',
	      #Authentication system used for user 
	      AuthSystem => 'public/read/write/admin',
	      Gecos => 'public/read/write/admin', #Gecos is the name of the fields in a 
	      # unix passwd file. In this case, it refers to "Unix Username"
	      # }}}
	      
	      # {{{ Telephone numbers
	      HomePhone =>  'read/write',
	      WorkPhone => 'read/write',
	      MobilePhone => 'read/write',
	      PagerPhone => 'read/write',

	      # }}}
	      
	      # {{{ Paper Address
	      Address1 => 'read/write',
	      Address2 => 'read/write',
	      City => 'read/write',
	      State => 'read/write',
	      Zip => 'read/write',
	      Country => 'read/write',
	      # }}}
	      
	      # {{{ Core DBIx::Record Attributes
	      Creator => 'read/auto',
	      Created => 'read/auto',
	      LastUpdatedBy => 'read/auto',
	      LastUpdated => 'read/auto'

	      # }}}
	     );
  return($self->SUPER::_Accessible(@_, %Cols));
}

# }}}

# {{{ sub Create 

sub Create  {
    my $self = shift;
    my %args = (Privileged => 0,
		@_ # get the real argumentlist
	       );
    
    #Check the ACL
    unless ($self->CurrentUserHasRight('AdminUsers')) {
	return (0, 'No permission to create users');
    }
    
    if (! $args{'Password'})  {
	$args{'Password'} = '*NO-PASSWORD*';
    }
    elsif (length($args{'Password'}) < $RT::MinimumPasswordLength) {
        return(0,"Password too short");
    }
    else {
        my $salt = join '', ('.','/',0..9,'A'..'Z','a'..'z')[rand 64, rand 64];
        $args{'Password'} = crypt($args{'Password'}, $salt);     
    }   
        
    
    #TODO Specify some sensible defaults.
    
    unless (defined ($args{'Name'})) {
	return(0, "Must specify 'Name' attribute");
    }	
    
    
    #SANITY CHECK THE NAME AND ABORT IF IT'S TAKEN
    if ($RT::SystemUser) { #This only works if RT::SystemUser has been defined
		my $TempUser = RT::User->new($RT::SystemUser);
		$TempUser->Load($args{'Name'});
		return (0, 'Name in use') if ($TempUser->Id);
	
		return(0, 'Email address in use') 
			unless ($self->ValidateEmailAddress($args{'EmailAddress'}));
    }
    else {
		$RT::Logger->warning("$self couldn't check for pre-existing ".
			     " users on create. This will happen".
			     " on installation\n");
    }
    
    my $id = $self->SUPER::Create(%args);
    
    #If the create failed.
    unless ($id) {
		return (0, 'Could not create user');
    }
      
    
    #TODO post 2.0
    #if ($args{'SendWelcomeMessage'}) {
    #	#TODO: Check if the email exists and looks valid
    #	#TODO: Send the user a "welcome message" 
    #}
    
    return ($id, 'User created');
}

# }}}

# {{{ sub _BootstrapCreate 

#create a user without validating _any_ data.

#To be used only on database init.

sub _BootstrapCreate {
    my $self = shift;
    my %args = (@_);

    $args{'Password'} = "*NO-PASSWORD*";
    my $id = $self->SUPER::Create(%args);
    
    #If the create failed.
    return (0, 'Could not create user') 
      unless ($id);

    return ($id, 'User created');
}

# }}}

# {{{ sub Delete 

sub Delete  {
    my $self = shift;
    
    return(0, 'Deleting this object would violate referential integrity');
    
}

# }}}

# {{{ sub Load 

=head2 Load

Load a user object from the database. Takes a single argument.
If the argument is numerical, load by the column 'id'. Otherwise, load by
the "Name" column which is the user's textual username.

=cut

sub Load  {
    my $self = shift;
    my $identifier = shift || return undef;
    
    #if it's an int, load by id. otherwise, load by name.
    if ($identifier !~ /\D/) {
	$self->SUPER::LoadById($identifier);
    }
    else {
	$self->LoadByCol("Name",$identifier);
    }
}

# }}}


# {{{ sub LoadByEmail

=head2 LoadByEmail

Tries to load this user object from the database by the user's email address.


=cut

sub LoadByEmail {
    my $self=shift;
    my $address = shift;

    # Never load an empty address as an email address.
    unless ($address) {
	return(undef);
    }

    $address = RT::CanonicalizeAddress($address);
    #$RT::Logger->debug("Trying to load an email address: $address\n");
    return $self->LoadByCol("EmailAddress", $address);
}
# }}}


# {{{ sub ValidateEmailAddress

=head2 ValidateEmailAddress ADDRESS

Returns true if the email address entered is not in use by another user or is 
undef or ''. Returns false if it's in use. 

=cut

sub ValidateEmailAddress {
	my $self = shift;
	my $Value = shift;

 	# if the email address is null, it's always valid
 	return (1) if(!$Value || $Value eq "");

 	my $TempUser = RT::User->new($RT::SystemUser);
 	$TempUser->LoadByEmail($Value);

 	if( $TempUser->id && 
	   ($TempUser->id != $self->id)) { # if we found a user with that address 
					# it's invalid to set this user's address to it
 		return(undef);
 	}
 	else { #it's a valid email address
 		return(1);
 	}
}

# }}}




# {{{ sub SetRandomPassword

=head2 SetRandomPassword

Takes no arguments. Returns a status code and a new password or an error message.
If the status is 1, the second value returned is the new password.
If the status is anything else, the new value returned is the error code.

=cut

sub SetRandomPassword  {
    my $self = shift;


    unless ($self->CurrentUserCanModify('Password')) {
	return (0, "Permission Denied");
    }
    
    my $pass = $self->GenerateRandomPassword(6,8);

    # If we have "notify user on 

    my ($val, $msg) = $self->SetPassword($pass);
    
    #If we got an error return the error.
    return (0, $msg) unless ($val);
    
    #Otherwise, we changed the password, lets return it.
    return (1, $pass);
    
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
    
    unless ($self->CurrentUserCanModify('Password')) {
	return (0, "Permission Denied");
    }
    my ($status, $pass) = $self->SetRandomPassword();

    unless ($status) {
	return (0, "$pass");
    }
    
    my $template = RT::Template->new($self->CurrentUser);


    if ($self->IsPrivileged) {
	$template->LoadGlobalTemplate('RT_PasswordChange_Privileged');
    } 
    else {
	$template->LoadGlobalTemplate('RT_PasswordChange_Privileged');
    }	
    
    unless ($template->Id) {
	$template->LoadGlobalTemplate('RT_PasswordChange');
    }	
    
    unless ($template->Id) {
	$RT::Logger->crit("$self tried to send ".$self->Name." a password reminder ".
			  "but couldn't find a password change template");
    }	

    my $notification =  RT::Action::SendPasswordEmail->new(TemplateObj => $template,
							   Argument => $pass);
    
    $notification->SetTo($self->EmailAddress);

    my ($ret);
    $ret = $notification->Prepare();
    if ($ret) {
	$ret = $notification->Commit();
    }
    
    if ($ret) {
	return(1, 'New password notification sent');
    }	else {
	return (0, 'Notification could not be sent');
    }	
    
}


# }}}

# {{{ sub GenerateRandomPassword

=head2 GenerateRandomPassword MIN_LEN and MAX_LEN

Returns a random password between MIN_LEN and MAX_LEN characters long.

=cut

sub GenerateRandomPassword {
    my $self = shift;
    my $min_length = shift;
    my $max_length = shift;
    
    #This code derived from mpw.pl, a bit of code with a sordid history
    # Its notes: 
    
    # Perl cleaned up a bit by Jesse Vincent 1/14/2001.
    # Converted to perl from C by Marc Horowitz, 1/20/2000.
    # Converted to C from Multics PL/I by Bill Sommerfeld, 4/21/86.
    # Original PL/I version provided by Jerry Saltzer.

    
    my ($frequency, $start_freq, $total_sum, $row_sums);

    #When munging characters, we need to know where to start counting letters from
    my $a = ord('a');

    # frequency of English digraphs (from D Edwards 1/27/66) 
    $frequency =
      [ [ 4, 20, 28, 52, 2, 11, 28, 4, 32, 4, 6, 62, 23,
	  167, 2, 14, 0, 83, 76, 127, 7, 25, 8, 1, 9, 1 ], # aa - az
	[ 13, 0, 0, 0, 55, 0, 0, 0, 8, 2, 0, 22, 0,
	  0, 11, 0, 0, 15, 4, 2, 13, 0, 0, 0, 15, 0 ], # ba - bz
	[ 32, 0, 7, 1, 69, 0, 0, 33, 17, 0, 10, 9, 1,
	  0, 50, 3, 0, 10, 0, 28, 11, 0, 0, 0, 3, 0 ], # ca - cz
	[ 40, 16, 9, 5, 65, 18, 3, 9, 56, 0, 1, 4, 15,
	  6, 16, 4, 0, 21, 18, 53, 19, 5, 15, 0, 3, 0 ], # da - dz
	[ 84, 20, 55, 125, 51, 40, 19, 16, 50, 1, 4, 55, 54,
	  146, 35, 37, 6, 191, 149, 65, 9, 26, 21, 12, 5, 0 ], # ea - ez
	[ 19, 3, 5, 1, 19, 21, 1, 3, 30, 2, 0, 11, 1,
	  0, 51, 0, 0, 26, 8, 47, 6, 3, 3, 0, 2, 0 ], # fa - fz
	[ 20, 4, 3, 2, 35, 1, 3, 15, 18, 0, 0, 5, 1,
	  4, 21, 1, 1, 20, 9, 21, 9, 0, 5, 0, 1, 0 ], # ga - gz
	[ 101, 1, 3, 0, 270, 5, 1, 6, 57, 0, 0, 0, 3,
	  2, 44, 1, 0, 3, 10, 18, 6, 0, 5, 0, 3, 0 ], # ha - hz
	[ 40, 7, 51, 23, 25, 9, 11, 3, 0, 0, 2, 38, 25,
	  202, 56, 12, 1, 46, 79, 117, 1, 22, 0, 4, 0, 3 ], # ia - iz
	[ 3, 0, 0, 0, 5, 0, 0, 0, 1, 0, 0, 0, 0,
	  0, 4, 0, 0, 0, 0, 0, 3, 0, 0, 0, 0, 0 ], # ja - jz
	[ 1, 0, 0, 0, 11, 0, 0, 0, 13, 0, 0, 0, 0,
	  2, 0, 0, 0, 0, 6, 2, 1, 0, 2, 0, 1, 0 ], # ka - kz
	[ 44, 2, 5, 12, 62, 7, 5, 2, 42, 1, 1, 53, 2,
	  2, 25, 1, 1, 2, 16, 23, 9, 0, 1, 0, 33, 0 ], # la - lz
	[ 52, 14, 1, 0, 64, 0, 0, 3, 37, 0, 0, 0, 7,
	  1, 17, 18, 1, 2, 12, 3, 8, 0, 1, 0, 2, 0 ], # ma - mz
	[ 42, 10, 47, 122, 63, 19, 106, 12, 30, 1, 6, 6, 9,
	  7, 54, 7, 1, 7, 44, 124, 6, 1, 15, 0, 12, 0 ], # na - nz
	[ 7, 12, 14, 17, 5, 95, 3, 5, 14, 0, 0, 19, 41,
	  134, 13, 23, 0, 91, 23, 42, 55, 16, 28, 0, 4, 1 ], # oa - oz
	[ 19, 1, 0, 0, 37, 0, 0, 4, 8, 0, 0, 15, 1,
	  0, 27, 9, 0, 33, 14, 7, 6, 0, 0, 0, 0, 0 ], # pa - pz
	[ 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
	  0, 0, 0, 0, 0, 0, 0, 17, 0, 0, 0, 0, 0 ], # qa - qz
	[ 83, 8, 16, 23, 169, 4, 8, 8, 77, 1, 10, 5, 26,
	  16, 60, 4, 0, 24, 37, 55, 6, 11, 4, 0, 28, 0 ], # ra - rz
	[ 65, 9, 17, 9, 73, 13, 1, 47, 75, 3, 0, 7, 11,
	  12, 56, 17, 6, 9, 48, 116, 35, 1, 28, 0, 4, 0 ], # sa - sz
	[ 57, 22, 3, 1, 76, 5, 2, 330, 126, 1, 0, 14, 10,
	  6, 79, 7, 0, 49, 50, 56, 21, 2, 27, 0, 24, 0 ], # ta - tz
	[ 11, 5, 9, 6, 9, 1, 6, 0, 9, 0, 1, 19, 5,
	  31, 1, 15, 0, 47, 39, 31, 0, 3, 0, 0, 0, 0 ],	# ua - uz
	[ 7, 0, 0, 0, 72, 0, 0, 0, 28, 0, 0, 0, 0,
	  0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 3, 0 ], # va - vz
	[ 36, 1, 1, 0, 38, 0, 0, 33, 36, 0, 0, 4, 1,
	  8, 15, 0, 0, 0, 4, 2, 0, 0, 1, 0, 0, 0 ], # wa - wz
	[ 1, 0, 2, 0, 0, 1, 0, 0, 3, 0, 0, 0, 0,
	  0, 1, 5, 0, 0, 0, 3, 0, 0, 1, 0, 0, 0 ], # xa - xz
	[ 14, 5, 4, 2, 7, 12, 12, 6, 10, 0, 0, 3, 7,
	  5, 17, 3, 0, 4, 16, 30, 0, 0, 5, 0, 0, 0 ], # ya - yz
	[ 1, 0, 0, 0, 4, 0, 0, 0, 0, 0, 0, 0, 0,
	  0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 ] ]; # za - zz

    #We need to know the totals for each row 
    $row_sums =
      [ map { my $sum = 0; map { $sum += $_ } @$_; $sum } @$frequency ];
    

    #Frequency with which a given letter starts a word.
    $start_freq =
      [ 1299, 425, 725, 271, 375, 470, 93, 223, 1009, 24, 20, 355, 379,
	319, 823, 618, 21, 317, 962, 1991, 271, 104, 516, 6, 16, 14 ];
    
    $total_sum = 0; map { $total_sum += $_ } @$start_freq;
    
    
    my $length = $min_length + int(rand($max_length-$min_length));
    
    my $char = $self->GenerateRandomNextChar($total_sum, $start_freq);
    my @word = ($char+$a);
    for (2..$length) {
	$char = $self->_GenerateRandomNextChar($row_sums->[$char], $frequency->[$char]);
	push(@word, $char+$a);
    }
    
    #Return the password
    return pack("C*",@word);
    
}


#A private helper function for RandomPassword
# Takes a row summary and a frequency chart for the next character to be searched
sub _GenerateRandomNextChar {
    my $self = shift;
    my($all, $freq) = @_;
    my($pos, $i);
    
    for ($pos = int(rand($all)), $i=0;
	 $pos >= $freq->[$i];
	 $pos -= $freq->[$i], $i++) {};
    
    return($i);
}

# }}}

# {{{ sub SetPassword

=head2 SetPassword

Takes a string. Checks the string's length and sets this user's password 
to that string.

=cut

sub SetPassword {
    my $self = shift;
    my $password = shift;
    
    unless ($self->CurrentUserCanModify('Password')) {
	return(0, 'Permission Denied');
    }
    
    if (! $password)  {
        return(0, "No password set");
    }
    elsif (length($password) < $RT::MinimumPasswordLength) {
        return(0,"Password too short");
    }
    else {
        my $salt = join '', ('.','/',0..9,'A'..'Z','a'..'z')[rand 64, rand 64];
        return ( $self->SUPER::SetPassword(crypt($password, $salt)) );
    }   
    
}

# }}}

# {{{ sub IsPassword 

=head2 IsPassword

Returns true if the passed in value is this user's password.
Returns undef otherwise.

=cut

sub IsPassword { 
    my $self = shift;
    my $value = shift;

    #TODO there isn't any apparent way to legitimately ACL this

    # RT does not allow null passwords 
    if ((!defined ($value)) or ($value eq '')) {
	return(undef);
    } 
    if ($self->Disabled) {
  	$RT::Logger->info("Disabled user ".$self->Name." tried to log in");
	return(undef);
    }

    if ( ($self->__Value('Password') eq '') || 
         ($self->__Value('Password') eq undef) )  {
        return(undef);
     }
    if ($self->__Value('Password') eq crypt($value, $self->__Value('Password'))) {
	return (1);
    }
    else {
	return (undef);
    }
}

# }}}

# {{{ sub SetDisabled

=head2 Sub SetDisabled

Toggles the user's disabled flag.
If this flag is
set, all password checks for this user will fail. All ACL checks for this
user will fail. The user will appear in no user listings.

=cut 

# }}}

# {{{ ACL Related routines

# {{{ GrantQueueRight

=head2 GrantQueueRight

Grant a queue right to this user.  Takes a paramhash of which the elements
RightAppliesTo and RightName are important.

=cut

sub GrantQueueRight {
    
    my $self = shift;
    my %args = ( RightScope => 'Queue',
		 RightName => undef,
		 RightAppliesTo => undef,
		 PrincipalType => 'User',
		 PrincipalId => $self->Id,
		 @_);
   
    #ACL check handled in ACE.pm

    require RT::ACE;

#    $RT::Logger->debug("$self ->GrantQueueRight right:". $args{'RightName'} .
#		       " applies to queue ".$args{'RightAppliesTo'}."\n");
    
    my $ace = new RT::ACE($self->CurrentUser);
    
    return ($ace->Create(%args));
}

# }}}

# {{{ GrantSystemRight

=head2 GrantSystemRight

Grant a system right to this user. 
The only element that's important to set is RightName.

=cut
sub GrantSystemRight {
    
    my $self = shift;
    my %args = ( RightScope => 'System',
		 RightName => undef,
		 RightAppliesTo => 0,
		 PrincipalType => 'User',
		 PrincipalId => $self->Id,
		 @_);
   

    #ACL check handled in ACE.pm

    require RT::ACE;    
    my $ace = new RT::ACE($self->CurrentUser);
    
    return ($ace->Create(%args));
}


# }}}

# {{{ sub HasQueueRight

=head2 HasQueueRight

Takes a paramhash which can contain
these items:
    TicketObj => RT::Ticket or QueueObj => RT::Queue or Queue => integer
    IsRequestor => undef, (for bootstrapping create)
    Right => 'Right' 


Returns 1 if this user has the right specified in the paramhash. for the queue
passed in.

Returns undef if they don't

=cut

sub HasQueueRight {
    my $self = shift;
    my %args = ( TicketObj => undef,
                 QueueObj => undef,
		 Queue => undef,
		 IsRequestor => undef,
		 Right => undef,
		 @_);
    
    my ($IsRequestor, $IsCc, $IsAdminCc, $IsOwner);
    
    if (defined $args{'Queue'}) {
	$args{'QueueObj'} = new RT::Queue($self->CurrentUser);
	$args{'QueueObj'}->Load($args{'Queue'});
    }
    
    if (defined $args{'TicketObj'}) {
	$args{'QueueObj'} = $args{'TicketObj'}->QueueObj();
    }

    # {{{ Validate and load up the QueueId
    unless ((defined $args{'QueueObj'}) and ($args{'QueueObj'}->Id)) {
	require Carp;
	$RT::Logger->debug(Carp::cluck ("$self->HasQueueRight Couldn't find a queue id"));
	return undef;
    }

    # }}}

        
    # Figure out whether a user has the right we're asking about.
    # first see if they have the right personally for the queue in question. 
    my $retval = $self->_HasRight(Scope => 'Queue',
				  AppliesTo => $args{'QueueObj'}->Id,
				  Right => $args{'Right'},
				  IsOwner => $IsOwner);

    return ($retval) if (defined $retval);
    
    # then we see whether they have the right personally globally. 
    $retval = $self->HasSystemRight( $args{'Right'});

    return ($retval) if (defined $retval);
    
    # now that we know they don't have the right personally,
    
    # {{{ Find out about whether the current user is a Requestor, Cc, AdminCc or Owner

    if (defined $args{'TicketObj'}) {
	if ($args{'TicketObj'}->IsRequestor($self)) {#user is requestor
	    $IsRequestor = 1;
	}	

	if ($args{'TicketObj'}->IsCc($self)) { #If user is a cc
	    $IsCc = 1;
	}

	if ($args{'TicketObj'}->IsAdminCc($self)) { #If user is an admin cc
	    $IsAdminCc = 1;
	}	
	
	if ($args{'TicketObj'}->IsOwner($self)) { #If user is an owner
	    $IsOwner = 1;
	}
    }
    
    if (defined $args{'QueueObj'}) {
	if ($args{'QueueObj'}->IsCc($self)) { #If user is a cc
	    $IsCc = 1;
	}
	if ($args{'QueueObj'}->IsAdminCc($self)) { #If user is an admin cc
	    $IsAdminCc = 1;
	}
	
    } 
    # }}}
    
    # then see whether they have the right for the queue as a member of a metagroup 

    $retval = $self->_HasRight(Scope => 'Queue',
				  AppliesTo => $args{'QueueObj'}->Id,
				  Right => $args{'Right'},
				  IsOwner => $IsOwner,
				  IsCc => $IsCc,
				  IsAdminCc => $IsAdminCc,
				  IsRequestor => $IsRequestor
				 );

    return ($retval) if (defined $retval);

    #   then we see whether they have the right globally as a member of a metagroup
    $retval = $self->HasSystemRight( $args{'Right'},
				     (IsOwner => $IsOwner,
				      IsCc => $IsCc,
				      IsAdminCc => $IsAdminCc,
				      IsRequestor => $IsRequestor
				     ) );

    #If they haven't gotten it by now, they just lose.
    return ($retval);
    
}

# }}}
  
# {{{ sub HasSystemRight

=head2 HasSystemRight

takes an array of a single value and a paramhash.
The single argument is the right being passed in.
the param hash is some additional data. (IsCc, IsOwner, IsAdminCc and IsRequestor)

Returns 1 if this user has the listed 'right'. Returns undef if this user doesn't.

=cut

sub HasSystemRight {
    my $self = shift;
    my $right = shift;

    my %args = ( IsOwner => undef,
		 IsCc => undef,
		 IsAdminCc => undef,
		 IsRequestor => undef,
		 @_);
    
    unless (defined $right) {

	$RT::Logger->debug("$self RT::User::HasSystemRight was passed in no right.");
	return(undef);
    }	
    return ( $self->_HasRight ( Scope => 'System',
				AppliesTo => '0',
				Right => $right,
				IsOwner => $args{'IsOwner'},
				IsCc => $args{'IsCc'},
				IsAdminCc => $args{'IsAdminCc'},
				IsRequestor => $args{'IsRequestor'},
				
			      )
	   );
    
}

# }}}

# {{{ sub _HasRight

=head2 sub _HasRight (Right => 'right', Scope => 'scope',  AppliesTo => int, ExtendedPrincipals => SQL)

_HasRight is a private helper method for checking a user's rights. It takes
several options:

=item Right is a textual right name

=item Scope is a textual scope name. (As of July these were Queue, Ticket and System

=item AppliesTo is the numerical Id of the object identified in the scope. For tickets, this is the queue #. for queues, this is the queue #

=item ExtendedPrincipals is an  SQL select clause which assumes that the only
table in play is ACL.  It's used by HasQueueRight to pass in which 
metaprincipals apply. Actually, it's probably obsolete. TODO: remove it.

Returns 1 if a matching ACE was found.

Returns undef if no ACE was found.

=cut


sub _HasRight {
    
    my $self = shift;
    my %args = ( Right => undef,
		 Scope => undef,
		 AppliesTo => undef,
		 IsRequestor => undef,
		 IsCc => undef,
		 IsAdminCc => undef,
		 IsOwner => undef,
		 ExtendedPrincipals => undef,
		 @_);
    
    if ($self->Disabled) {
	$RT::Logger->debug ("Disabled User:  ".$self->Name.
			    " failed access check for ".$args{'Right'}.
			    " to object ".$args{'Scope'}."/".
			    $args{'AppliesTo'}."\n");
	return (undef);
    }
    
    if (!defined $args{'Right'}) {
    	$RT::Logger->debug("_HasRight called without a right\n");
    	return(undef);
    }
    elsif (!defined $args{'Scope'}) {
    	$RT::Logger->debug("_HasRight called without a scope\n");
    	return(undef);
    }
    elsif (!defined $args{'AppliesTo'}) {
    	$RT::Logger->debug("_HasRight called without an AppliesTo object\n");
    	return(undef);
    }
    
    #If we've cached a win or loss for this lookup say so
    
    #TODO Security +++ check to make sure this is complete and right
    
    #Construct a hashkey to cache decisions in
    my ($hashkey);
    { #it's ugly, but we need to turn off warning, cuz we're joining nulls.
	local $^W=0;
	$hashkey =$self->Id .":". join(':',%args);
    }	
    
  # $RT::Logger->debug($hashkey."\n");
    
    #Anything older than 10 seconds needs to be rechecked
    my $cache_timeout = (time - 10);
    
    
    if ((defined $self->{'rights'}{"$hashkey"}) &&
	    ($self->{'rights'}{"$hashkey"} == 1 ) &&
        (defined $self->{'rights'}{"$hashkey"}{'set'} ) &&
	    ($self->{'rights'}{"$hashkey"}{'set'} > $cache_timeout)) {
#	  $RT::Logger->debug("Cached ACL win for ". 
#			     $args{'Right'}.$args{'Scope'}.
#			     $args{'AppliesTo'}."\n");	    
	return ($self->{'rights'}{"$hashkey"});
    }
    elsif ((defined $self->{'rights'}{"$hashkey"}) &&
	       ($self->{'rights'}{"$hashkey"} == -1)  &&
           (defined $self->{'rights'}{"$hashkey"}{'set'}) &&
	       ($self->{'rights'}{"$hashkey"}{'set'} > $cache_timeout)) {
	
#	$RT::Logger->debug("Cached ACL loss decision for ". 
#			   $args{'Right'}.$args{'Scope'}.
#			   $args{'AppliesTo'}."\n");	    
	
	return(undef);
    }
    
    
    my $RightClause = "(RightName = '$args{'Right'}')";
    my $ScopeClause = "(RightScope = '$args{'Scope'}')";
    
    #If an AppliesTo was passed in, we should pay attention to it.
    #otherwise, none is needed
    
    $ScopeClause = "($ScopeClause AND (RightAppliesTo = $args{'AppliesTo'}))"
      if ($args{'AppliesTo'});
    
    
    # The generic principals clause looks for users with my id
    # and Rights that apply to _everyone_
    my $PrincipalsClause = "((PrincipalType = 'User') AND (PrincipalId = ".$self->Id."))";
    
    
    # If the user is the superuser, grant them the damn right ;)
    my $SuperUserClause = 
      "(RightName = 'SuperUser') AND (RightScope = 'System') AND (RightAppliesTo = 0)";
    
    # If we've been passed in an extended principals clause, we should lump it
    # on to the existing principals clause. it'll make life easier
    if ($args{'ExtendedPrincipals'}) {
	$PrincipalsClause = "(($PrincipalsClause) OR ".
	  "($args{'ExtendedPrincipalsClause'}))";
    }
    
    my $GroupPrincipalsClause = "((ACL.PrincipalType = 'Group') ".
      "AND (ACL.PrincipalId = Groups.Id) AND (GroupMembers.GroupId = Groups.Id) ".
     " AND (GroupMembers.UserId = ".$self->Id."))";
    
    


    # {{{ A bunch of magic statements that make the metagroups listed
    # work. basically, we if the user falls into the right group,
    # we add the type of ACL check needed
    my (@MetaPrincipalsSubClauses, $MetaPrincipalsClause);
    
    #The user is always part of the 'Everyone' Group
    push (@MetaPrincipalsSubClauses,  "((Groups.Name = 'Everyone') AND 
                                       (PrincipalType = 'Group') AND 
                                       (Groups.Id = PrincipalId))");

    if ($args{'IsAdminCc'}) {
	push (@MetaPrincipalsSubClauses,  "((Groups.Name = 'AdminCc') AND 
                                       (PrincipalType = 'Group') AND 
                                       (Groups.Id = PrincipalId))");
    }
    if ($args{'IsCc'}) {
	push (@MetaPrincipalsSubClauses, " ((Groups.Name = 'Cc') AND 
                                       (PrincipalType = 'Group') AND 
                                       (Groups.Id = PrincipalId))");
    }
    if ($args{'IsRequestor'}) {
	push (@MetaPrincipalsSubClauses,  " ((Groups.Name = 'Requestor') AND 
                                       (PrincipalType = 'Group') AND 
                                       (Groups.Id = PrincipalId))");
    }
    if ($args{'IsOwner'}) {
	
	push (@MetaPrincipalsSubClauses, " ((Groups.Name = 'Owner') AND 
                                       (PrincipalType = 'Group') AND 
                                       (Groups.Id = PrincipalId))");
    }

    # }}}
    
    my ($GroupRightsQuery, $MetaGroupRightsQuery, $IndividualRightsQuery, $hitcount);
    
    # {{{ If there are any metaprincipals to be checked
    if (@MetaPrincipalsSubClauses) {
	#chop off the leading or
	#TODO redo this with an array and a join
	$MetaPrincipalsClause = join (" OR ", @MetaPrincipalsSubClauses);
	
	$MetaGroupRightsQuery =  "SELECT COUNT(ACL.id) FROM ACL, Groups".
	  " WHERE " .
	    " ($ScopeClause) AND ($RightClause) AND ($MetaPrincipalsClause)";
	
	# {{{ deal with checking if the user has a right as a member of a metagroup

#	$RT::Logger->debug("Now Trying $MetaGroupRightsQuery\n");	
	$hitcount = $self->_Handle->FetchResult($MetaGroupRightsQuery);
	
	#if there's a match, the right is granted
	if ($hitcount) {
	    $self->{'rights'}{"$hashkey"}{'set'} = time;
	    $self->{'rights'}{"$hashkey"} = 1;
	    return (1);
	}
	
#	$RT::Logger->debug("No ACL matched MetaGroups query: $MetaGroupRightsQuery\n");	

	# }}}    
	
    }
    # }}}

    # {{{ deal with checking if the user has a right as a member of a group
    # This query checks to se whether the user has the right as a member of a
    # group
    $GroupRightsQuery = "SELECT COUNT(ACL.id) FROM ACL, GroupMembers, Groups".
      " WHERE " .
	" (((($ScopeClause) AND ($RightClause)) OR ($SuperUserClause)) ".
	  " AND ($GroupPrincipalsClause))";    
    
    #  $RT::Logger->debug("Now Trying $GroupRightsQuery\n");	
    $hitcount = $self->_Handle->FetchResult($GroupRightsQuery);
    
    #if there's a match, the right is granted
    if ($hitcount) {
	$self->{'rights'}{"$hashkey"}{'set'} = time;
	$self->{'rights'}{"$hashkey"} = 1;
	return (1);
    }
    
#    $RT::Logger->debug("No ACL matched $GroupRightsQuery\n");	
    
    # }}}

    # {{{ Check to see whether the user has a right as an individual
    
    # This query checks to see whether the current user has the right directly
    $IndividualRightsQuery = "SELECT COUNT(ACL.id) FROM ACL WHERE ".
      " ((($ScopeClause) AND ($RightClause)) OR ($SuperUserClause)) " .
	" AND ($PrincipalsClause)";

    
    $hitcount = $self->_Handle->FetchResult($IndividualRightsQuery);
    
    if ($hitcount) {
	$self->{'rights'}{"$hashkey"}{'set'} = time;
	$self->{'rights'}{"$hashkey"} = 1;
	return (1);
    }
    # }}}

    else { #If the user just doesn't have the right
	
#	$RT::Logger->debug("No ACL matched $IndividualRightsQuery\n");
	
	#If nothing matched, return 0.
	$self->{'rights'}{"$hashkey"}{'set'} = time;
	$self->{'rights'}{"$hashkey"} = -1;

	
	return (undef);
    }
}

# }}}

# {{{ sub CurrentUserCanModify

=head2 CurrentUserCanModify RIGHT

If the user has rights for this object, either because
he has 'AdminUsers' or (if he\'s trying to edit himself and the right isn\'t an 
admin right) 'ModifySelf', return 1. otherwise, return undef.

=cut

sub CurrentUserCanModify {
    my $self = shift;
    my $right = shift;

    if ($self->CurrentUserHasRight('AdminUsers')) {
	return (1);
    }
    #If the field is marked as an "administrators only" field, 
    # don\'t let the user touch it.
    elsif ($self->_Accessible($right, 'admin')) {
	return(undef);
    }
    
    #If the current user is trying to modify themselves
    elsif ( ($self->id == $self->CurrentUser->id)  and
	    ($self->CurrentUserHasRight('ModifySelf'))) {
	return(1);
    }
 
    #If we don\'t have a good reason to grant them rights to modify
    # by now, they lose
    else {
	return(undef);
    }
    
}

# }}}

# {{{ sub CurrentUserHasRight

=head2 CurrentUserHasRight
  
  Takes a single argument. returns 1 if $Self->CurrentUser
  has the requested right. returns undef otherwise

=cut

sub CurrentUserHasRight {
    my $self = shift;
    my $right = shift;
    
    return ($self->CurrentUser->HasSystemRight($right));
}

# }}}


# {{{ sub _Set

sub _Set {
  my $self = shift;
  
  my %args = (Field => undef,
	      Value => undef,
	      @_
	     );

  # Nobody is allowed to futz with RT_System or Nobody unless they
  # want to change an email address. For 2.2, neither should have an email address

  if ($self->Privileged == 2) {
    return (0, "Can not modify system users"); 
  }
  unless ($self->CurrentUserCanModify($args{'Field'})) {
      return (0, "Permission Denied");
  }


  
  #Set the new value
  my ($ret, $msg)=$self->SUPER::_Set(Field => $args{'Field'}, 
				     Value=> $args{'Value'});
  
    return ($ret, $msg);
}

# }}}

# {{{ sub _Value 

=head2 _Value

Takes the name of a table column.
Returns its value as a string, if the user passes an ACL check

=cut

sub _Value  {

  my $self = shift;
  my $field = shift;
  
  #If the current user doesn't have ACLs, don't let em at it.  
  
  my @PublicFields = qw( Name EmailAddress Organization Disabled
			 RealName NickName Gecos ExternalAuthId 
			 AuthSystem ExternalContactInfoId 
			 ContactInfoSystem );

  #if the field is public, return it.
  if ($self->_Accessible($field, 'public')) {
      return($self->SUPER::_Value($field));
      
  }
  #If the user wants to see their own values, let them
  elsif ($self->CurrentUser->Id == $self->Id) {	
      return($self->SUPER::_Value($field));
  } 
  #If the user has the admin users right, return the field
  elsif ($self->CurrentUserHasRight('AdminUsers')) {
      return($self->SUPER::_Value($field));
  }
  else {
      return(undef);
  }	
 

}

# }}}

# }}}
1;
 
