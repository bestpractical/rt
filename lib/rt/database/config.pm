{
 

    package rt;

	sub read_config {
		&load_user_info();
		&load_queue_conf();
		&load_queue_acls();
		&load_queue_areas();      
	}	
    
    sub load_queue_acls {
	
	my ($user_id, $queue_id);
	$sth = $dbh->Query("SELECT queue_acl.queue_id, users.user_id, queue_acl.display, queue_acl.manipulate, queue_acl.admin, users.email, queue_acl.mail FROM queue_acl, users WHERE users.user_id = queue_acl.user_id") or warn "Query had some problem: $Mysql::db_errstr\n";
	while (@row=$sth->FetchRow) {
	    $queue_id=$row[0];
	    $user_id=$row[1];
	    if (!&is_a_queue($queue_id)) {next;} #the queue doesn't exist
	    if (!&is_a_user($user_id)) {next;}
	    $rt::queues{$queue_id}{acls}{$user_id}{'display'}=$row[2];
	    $rt::queues{$queue_id}{acls}{$user_id}{'manipulate'}=$row[3];
	    $rt::queues{$queue_id}{acls}{$user_id}{'admin'}=$row[4];

# TODO: The email-field (#6) should be used. What is most easy is to
# let it be binary "user should get mail" or not. In that case, just
# add $row[6] in the if-statement below (and update ui/*/admin.pm). A
# more featuristic schema is to let it be a bitmap of what emails he
# should get. In that case dist_list must be made into a hash ... that
# seems like WORK to me, so I've postponed it for now.
	    if ($row[5] and $row[3]) {
		if ($queues{$queue_id}{'dist_list'}) {
		    $queues{$queue_id}{'dist_list'} .= ", " . $row[5];
		}
		else {
		    $queues{$queue_id}{'dist_list'} = $row[5];
		}
	    }
	}
	return(1);
    }

sub load_queue_areas {
    
    my ($queue_id, $row);
    $sth = $dbh->Query("SELECT queue_areas.queue_id, queue_areas.area FROM queue_areas") or warn "Query had some problem: $Mysql::db_errstr\n";

    while (@row=$sth->FetchRow) {
        $queue_id=$row[0];
        $area=$row[1];
        if (!&is_a_queue($queue_id)) {next;} #the queue doesn't exist
        $rt::queues{$queue_id}{areas}{$area}=1;
    }
}         



sub load_user_info {
    my ($row);

    $query_string="SELECT user_id, password, email,  phone, office, comments, admin_rt, real_name FROM users";
    $sth = $dbh->Query($query_string) or warn "[load_user_info] Query had some problem: $Mysql::db_errstr\n$query_string\n";
    while (@row=$sth->FetchRow) { 
	$user_id=$row[0];
	$emails{$row[2]}=$user_id;
	$users{$user_id}{name}=$user_id;
	$users{$user_id}{password}="";
	$users{$user_id}{email}=$row[2];
	$users{$user_id}{phone}=$row[3];
	$users{$user_id}{office}=$row[4];
	$users{$user_id}{comments}=$row[5];
	$users{$user_id}{admin_rt}=$row[6];
	$users{$user_id}{real_name}=$row[7];
    }
    
}

sub is_hash_of_password_and_ip {
  my $in_user_id = shift;
  my $in_ip = shift;
  my $in_hash = shift;
  my ($password,$hash, $ctx);
  
  if (!&is_a_user($in_user_id)) {
   
    return(0);
  }
  
  
  my $user_id=$dbh->quote($in_user_id);
  $query_string="SELECT password FROM users WHERE user_id = $user_id";
  $sth = $dbh->Query($query_string) or warn "[is_password] Query had some problem: $Mysql::db_errstr\n$query_string\n";
  @row=$sth->FetchRow;
  
  $password=$row[0];
  
  use Digest::MD5;
    $ctx = Digest::MD5->new;
  $ctx->add($in_user_id);
  $ctx->add($in_ip);
  $ctx->add($password);
    $hash = $ctx->hexdigest();
 

  
  if ($hash eq $in_hash) {
    return (1);
  }
  else {
    return(0);
  }
    
}



sub is_password {
    my ($in_user_id, $in_password) = @_;
    my ($row, $password);

   
    if (!&is_a_user ($in_user_id)) {
	return(0);
    }

     my $user_id=$dbh->quote($in_user_id);
    $query_string="SELECT password FROM users WHERE user_id = $user_id";
       
    $sth = $dbh->Query($query_string) or warn "[is_password] Query had some problem: $Mysql::db_errstr\n$query_string\n";
    @row=$sth->FetchRow;

    $password=$row[0];
   

    
    if ($password eq $in_password) {
	return (1);
    }
    else {
	return(0);
    }
    
}

sub is_a_user {
    my ($in_user_id) = shift;
    if ($users{"$in_user_id"}{name} eq $in_user_id) {
	return (1);
    }
    else {
	return(0);
    }
}
    

sub load_queue_conf {
#    local ($in_queue_id)=@_;
    my ($row,$queue_id);
    $sth = $dbh->Query("SELECT queue_id, mail_alias, m_owner_trans,  m_members_trans, m_user_trans, m_user_create, m_members_corresp,m_members_comment, allow_user_create, default_prio, default_final_prio FROM queues") or warn "Query had some problem: $Mysql::db_errstr\n";
    while (@row=$sth->FetchRow) {
	$queue_id=$row[0];
	$queues{$queue_id}{name}=$queue_id;
	$queues{$queue_id}{mail_alias}=$row[1];
	$queues{$queue_id}{m_owner_trans}=$row[2];
	$queues{$queue_id}{m_members_trans}=$row[3];
	$queues{$queue_id}{m_user_trans}=$row[4];
	$queues{$queue_id}{m_user_create}=$row[5];
	$queues{$queue_id}{m_members_correspond}=$row[6];
	$queues{$queue_id}{m_members_comment}=$row[7];
	$queues{$queue_id}{allow_user_create}=$row[8];
	$queues{$queue_id}{default_prio}=$row[9];
	$queues{$queue_id}{default_final_prio}=$row[10];
    }
}

sub is_an_area {
	my ($in_queue_id, $in_area) = @_;
	if ($rt::queues{$in_queue_id}{areas}{$in_area})
	{
	    return (1);
	}
	return (0);
}

sub is_a_queue {
    local ($in_queue_id) = @_;
    if (exists($queues{$in_queue_id}{name})){ 
    return(1);
    }
    else {
	return(0);
    }
    
}

}
1;
