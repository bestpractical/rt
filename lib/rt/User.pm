# $Header$
# (c) 1996-1999 Jesse Vincent <jesse@fsck.com>
# This software is redistributable under the terms of the GNU GPL
#


package RT::User;

@ISA= qw(RT::Record);

sub new {
  my $proto = shift;
  my $class = ref($proto) || $proto;
  my $self  = {};
  bless ($self, $class);
  $self->{'table'} = "users";
  $self->{'user'} = shift;
  return $self;


sub create {
  my $self = shift;

  
  return (0,$passwd_err) if length($in_password) < $user_passwd_min;

  my $id = $self->SUPER::create(@_);
  $self->load_by_reference($id);

  #TODO: this is horrificially wasteful. we shouldn't commit 
  # to the db and then instantly turn around and load the same data

#sub create is handled by the baseclass. we should be calling it like this:
#$id = $article->create( title => "This is a a title",
#		  mimetype => "text/plain",
#		  author => "jesse@arepa.com",
#		  summary => "this article explains how to from a widget",
#		  content => "lots and lots of content goes here. it doesn't 
#                              need to be preqoted");
# TODO: created is not autoset


 
 
sub delete {
  my $self = shift;
  my $new_owner = shift;
  
  #TODO: Here, we should take all this admin's tickets that
  #      are stalled or open and reassign them to $new_owner;
  #      additionally, we should nuke this user's acls

  

  my ($query_string,$update_clause, $user_id);
  
  
  
  $user_id=$rt::dbh->quote($self->user_id);
  
  if ($users{$in_current_user}{admin_rt}) {

    
    if ($self->user_id  ne $self->{'user'}) {
      $query_string = "DELETE FROM users WHERE user_id = $user_id";
      $sth = $dbh->prepare($query_string) or return (0, "[delete_user] prepare had some problem: $DBI::errstr\n$query_string\n");
      $sth->execute or return (0, "[delete_user] execute had some problem: $DBI::errstr\n$query_string\n");
      $query_string = "DELETE FROM queue_acl WHERE user_id = $user_id";
      $sth = $dbh->prepare($query_string) or 
	return (0, "[delete_user] Query had some problem: $DBI::errstr\n$query_string\n");
      $sth->execute or return (0, "[delete_user] Query had some problem: $DBI::errstr\n$query_string\n");  
      return (1, "User deleted.");
      
    }
    else {
      return(0,"You may not delete yourself. (Do you know why?)");
      }
    }
    else {
       return(0, "You do not have the privileges to delete user $in_user_id.");
     }
  }
}

sub add_modify_queue_acl {
  my  ( $in_queue_id,$in_user_id,$in_display,$in_manipulate,$in_admin,$in_current_user) = @_;
  my ($query_string,$update_clause);
  
  
  if (!(&is_a_queue($in_queue_id))){
    return(0,"That queue does not exist");
  }
  if (!(&is_a_user($in_user_id))){
    return(0,"That user does not exist");
  }
  
  $queue_id = $rt::dbh->quote($in_queue_id);
  $user_id = $rt::dbh->quote($in_user_id);
  
  
  if (($users{$in_current_user}{admin_rt}) or ($queues{$in_queue_id}{acls}{$in_current_user}{admin})) {
    # don't lock yourself out
    
    if (($in_user_id eq $in_current_user) && (! $in_admin) && ($queues{$in_queue_id}{acls}{$in_current_user}{admin})) {
      $in_admin = 1;
      
    }
    
    #if the user can't display this queue
    if (!($queues{"$in_queue_id"}{'acls'}{"$in_user_id"}{'display'})){
      
      #clear the acl
      $query_string = "DELETE FROM queue_acl WHERE queue_id = $queue_id AND user_id = $user_id";
      $rt::dbh->prepare($query_string) or 
	return (0,"[add_modify_queue] Query had some problem: $DBI::errstr\n$query_string\n");
      $rv = $sth->execute or return (0,"[add_modify_queue] execute had some problem: $DBI::errstr\n$query_string\n");
      
      # if we're not granting anything
      if( ! (($in_admin == 0) and ($in_display == 0) and ($in_manipulate == 0)) ) {
	$query_string="INSERT INTO queue_acl (queue_id, user_id, display, manipulate, admin) VALUES ($queue_id, $user_id, $in_display, $in_manipulate, $in_admin)";
	$dbh->do($query_string) or 
	  return (0, "[add_modify_queue_acl] Query had some problem: $DBI::errstr\n");
	
       }
      
      $queues{$in_queue_id}{acls}{$in_user_id}{display}=$in_display;
      $queues{$in_queue_id}{acls}{$in_user_id}{manipulate}=$in_manipulate;
      $queues{$in_queue_id}{acls}{$in_user_id}{admin}=$in_admin;
      return(1,"User $user_id has been granted permissions to queue $in_queue_id");   
    }
    
    elsif (($in_admin == 0) and ($in_display == 0) and ($in_manipulate == 0)) {
      $query_string = "DELETE FROM queue_acl WHERE queue_id = $queue_id AND user_id = $user_id";
      $sth = $dbh->prepare($query_string) 
	  or return (0,"[add_modify_queue] prepare had some problem: $DBI::errstr\n$query_string\n");
      $rv = $sth->execute 
	  or return (0,"[add_modify_queue] execute had some problem: $DBI::errstr\n$query_sring\n");
      delete $rt::queues{$in_queue_id}{acls}{$in_user_id};
      return (1, "User $in_user_id\'s credentials for queue $queue_id have been revoked.");
    }
    else {
      
      if ($in_display ne $queues{$in_queue_id}{acls}{$in_user_id}{display}) {
	$update_clause = "display = $in_display, ";
	$queues{$in_queue_id}{acls}{$in_user_id}{display}=$in_display;
      }
      if ($in_manipulate ne $queues{$in_queue_id}{acls}{$in_user_id}{manipulate}) {
	$update_clause .= "manipulate = $in_manipulate, ";
	$queues{$in_queue_id}{acls}{$in_user_id}{manipulate}=$in_manipulate;
      }
      
      if ($in_admin ne $queues{$in_queue_id}{acls}{$in_user_id}{admin}) {
	$update_clause .= "admin = $in_admin, ";
	$queues{$in_queue_id}{acls}{$in_user_id}{admin}=$in_admin;
      }
      
      if ($update_clause) {
	$update_clause =~ s/,(\s),/, /g;
	$query_string = "UPDATE queue_acl SET $update_clause WHERE queue_id = $queue_id AND user_id = $user_id";
	$query_string =~ s/,(\s*)WHERE/ WHERE/g;
	#  print "UPDATING WITH QUERY $query_string\n";
 	$sth = $dbh->prepare($query_string) or warn "[add_modify_queue] prepare had some problem: $DBI::errstr\n$query_string\n";
 	$rv = $sth->execute or warn "[add_modify_queue] execute had some problem: $DBI::errstr\n$query_string\n";
	delete $rt::queues{$in_queue_id}{acls}{$in_user_id};
	&rt::load_queue_acls();
	return (1, "User $in_user_id\'s ACLs for queue $queue_id updated.");
      }
    }
  }
  
  else {
    
    
    return(0, "You do not have the privileges to modify users' ACLs for queue $in_queue_id.");
  }
 }




sub load;
sub user_id { 
my $self = shift;
  $self->_set_and_return('user_id',@_);

}
sub password { 
my $self = shift;
  $self->_set_and_return('password',@_);

}

#used to check if a password is correct
sub is_password { 
my $self = shift;
my $value = shift;
if ($value = $self->password) {
  return (1);
}
else {
  return (undef);
}


sub email_address { 
my $self = shift;
  $self->_set_and_return('priority',@_);

}
sub phone  { 
my $self = shift;
  $self->_set_and_return('phone',@_);

}
sub office { 
my $self = shift;
  $self->_set_and_return('office',@_);

}
sub comments {
  my $self = shift;
  $self->_set_and_return('priority',@_);

}
sub administrator {
 my $self = shift;
 #todo validate input

 $self->_set_and_return('admin_rt',@_);
};




sub create {

    if ($users{$in_current_user}{admin_rt}){
      #if the password length is too short and we're creating a user

      
      $query_string="INSERT INTO users (user_id, real_name, password, email, phone,  office, comments, admin_rt) VALUES ($new_user_id, $new_real_name, $new_password, $new_email, $new_phone, $new_office, $new_comments, $in_admin_rt)";
       
      $sth = $dbh->prepare($query_string) 
	  or warn "[add_modify_user_info] prepare had some problem: $DBI::errstr\n";
      $sth->execute 
	  or warn "[add_modify_user_info] execute had some problem: $DBI::errstr\n";
         
      
      &rt::load_user_info();
      return(1,"User $in_user_id created");
    }
}


sub add_modify_user_info {
  my  $in_user_id = shift;
  my $in_real_name = shift;
  my $in_password = shift;
  my $in_email = shift;
  my $in_phone = shift;
  my $in_office = shift; 
  my $in_comments = shift;
  my $in_admin_rt = shift;
  my $in_current_user = shift;
  
  my ($query_string,$update_clause, $new_user_id, $new_password, $new_email, $new_phone, $new_office, $new_comments);
  
  my $passwd_err = "User create/modify failed: Use longer password ($user_passwd_min chars minimum)";
  
 

  

  
  if ($in_user_id) {
    $new_user_id = $rt::dbh->quote($in_user_id);
  }
  if ($in_real_name) {
    
    $new_real_name = $rt::dbh->quote($in_real_name);
  }   
  else {
    $new_real_name="''";
    
  }
  
  $in_password =~ s/\s//g;
  if ($in_password) {
    $in_password =~ s/\s//g;
    $new_password =$rt::dbh->quote($in_password);
  }   
  else {
    $new_password="''";
  }
  
    
  if ($in_email) {
     
     $new_email = $rt::dbh->quote($in_email);
   } 
   else {
     $new_email="''";
     
   }
   if ($in_phone) {
     
     $new_phone = $rt::dbh->quote($in_phone);
   }
   else {
     $new_phone="''";
     
   }

   if ($in_office) {
     
     $new_office = $rt::dbh->quote ($in_office);
   } 
   else {
     $new_office="''";
     
   }
   if ($in_comments) {
     
     $new_comments = $rt::dbh->quote ($in_comments);
   }
   else {
     $new_comments="''";
     
   }
  
   
  if (!(&is_a_user($in_user_id))){
    # make sure one didn't specify too short password
    
    if ($users{$in_current_user}{admin_rt}){
      #if the password length is too short and we're creating a user
      return (0,$passwd_err) if length($in_password) < $user_passwd_min;
      
      $query_string="INSERT INTO users (user_id, real_name, password, email, phone,  office, comments, admin_rt) VALUES ($new_user_id, $new_real_name, $new_password, $new_email, $new_phone, $new_office, $new_comments, $in_admin_rt)";
       
      $sth = $dbh->prepare($query_string) 
	  or warn "[add_modify_user_info] prepare had some problem: $DBI::errstr\n";
      $sth->execute 
	  or warn "[add_modify_user_info] execute had some problem: $DBI::errstr\n";
         
      
      &rt::load_user_info();
      return(1,"User $in_user_id created");
    }
    else {
      return (0, "You do not have privileges to add users to RT");
    }
  }
  elsif (($in_current_user eq $in_user_id) and ($in_admin_rt ne $users{$in_user_id}{admin_rt})){
    return(0,"A user may not modify his or her own admin status");
  }
  else {
    if ($users{$in_current_user}{admin_rt} or ($in_current_user eq $in_user_id)) {
      if ($in_real_name ne $users{$in_user_id}{'real_name'}) {$update_clause .= "real_name = $new_real_name, ";}
      if ($in_email ne $users{$in_user_id}{'email'}) {$update_clause .= "email = $new_email, ";}
      if ($in_user_id ne $users{$in_user_id}{'user_id'}) {$update_clause .= "user_id = $new_user_id, ";}
      if ($in_phone ne $users{$in_user_id}{'phone'}) {$update_clause .= "phone = $new_phone, ";}
      if ($in_office ne $users{$in_user_id}{'office'}) {$update_clause .= "office = $new_office, ";}
      if ($in_comments ne $users{$in_user_id}{'comments'}) {$update_clause .= "comments = $new_comments, ";}
      if ($in_admin_rt ne $users{$in_user_id}{'admin_rt'}) {$update_clause .= "admin_rt = $in_admin_rt, ";}
      if (($in_password ne $users{$in_user_id}{'password'}) && ($in_password ne '')) {
	 #if the password is too short, return,
	return (0,$passwd_err) if length($in_password) < $user_passwd_min;
	$update_clause .= "password = $new_password ";
      }
      if ($update_clause) {
	$query_string = "UPDATE users SET $update_clause WHERE user_id = $new_user_id";
	$query_string =~ s/,(\s*)WHERE/ WHERE/g;
	$dbh->do($query_string) or warn "[add_modify_user] Query had some problem: $DBI::errstr\n$query_string";
	&rt::load_user_info();
	return(1, "User record updated");
      }
      return(0,"No updates needed to be performed");
    }
    else {
      return(0,"You do not have privileges to modify this user's vital info");
    }
  }
} 
1;
 
