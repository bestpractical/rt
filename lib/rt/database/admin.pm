# $Header$
# (c) 1996-1999 Jesse Vincent <jesse@fsck.com>
# This software is redistributable under the terms of the GNU GPL
#


package rt;
require rt::database;
 
 
 
sub delete_queue_area {
  # TODO: this function needs to move all requests into some other area!
  my  ($in_queue_id,$in_area, $in_current_user) = @_;
  my ($query_string,$update_clause);
  
  
  if (!(&is_an_area($in_queue_id, $in_area))){
    return(0,"Queue $in_queue_id doesn't have an area \"$in_area\"");
  }
  else {
    
    $queue_id=$rt::dbh->quote($in_queue_id);
    $area=$rt::dbh->quote($in_area);
    if (($users{$in_current_user}{admin_rt}) or ($queues{$in_queue_id}{acls}{$in_current_user}{admin})) {
      $query_string = "DELETE FROM queue_areas WHERE queue_id = $queue_id AND area = $area";

      $dbh->prepare($query_string) 
	  or return (0, 
		     "[delete_area] Query had some problem: $DBI::errstr\n$query_string\n");
      $sth->execute 
	  or return (0, 
		     "[delete_area] Query had some problem: $DBI::errstr\n$query_string\n"); 
     
      delete $rt::queues{$in_queue_id}{areas}{$in_area};
      return (1, "Area $in_area in queue $in_queue_id deleted.");
    }
    else {
      return(0, "You do not have the privileges to delete areas in queue $in_queue_id.");
    }
  }
}          


sub add_queue_area {
  my  ( $in_queue_id,$in_area,$in_current_user) = @_;
   my ($query_string,$update_clause, $queue_id, $area);
  
  
  if ((&is_an_area($in_queue_id, $in_area))){
    return(0,"Queue $in_queue_id already has an area \"$in_area\"");
  }
   
  if (!(&is_a_queue($in_queue_id))){
    return(0,"That queue does not exist");
  }
  
   $queue_id = $rt::dbh->quote($in_queue_id);
  $area = $rt::dbh->quote($in_area);
  
  if (($users{$in_current_user}{admin_rt}) 
    or ($queues{$in_queue_id}{acls}{$in_current_user}{admin})) {
      $query_string="INSERT INTO queue_areas (queue_id, area) VALUES ($queue_id, $area)";
    
      $sth=$rt::dbh->prepare($query_string) 
	  or return (0, "[add_modify_queue_areas] prepare had some problem: $DBI::errstr\n");
      $sth->execute 
	  or return (0,"[add_modify_queue_areas] execute had some problem: $DBI::errstr\n$query_string\n");
      $rt::queues{$in_queue_id}{areas}{$in_area}=1;
      return(1,"Area $area has been added to queue $in_queue_id");
  }
  else {
      return(0, "You do not have the privileges to add areas to queue $in_queue_id.");
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

1;
 
