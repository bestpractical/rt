{

 # This is a comment. I love comments.
 
 package rt;
 
 sub prepare_sql {
   $rt::AddLink=$dbh->prepare
     ('INSERT into links 
                     (serial_num, foreign_db, foreign_id) 
                     values (?, ?, ?, ?)');

	$rt::GetStalledParents=$dbh->prepare
	    ("SELECT foreign_id,url from links,relship,each_req 
              WHERE relship.type='dependency' 
                and links.foreign_db=relship.id 
                and links.serial_num=?
                and each_req.serial_num=links.foreign_id
                and each_req.status='stalled'");

	unless ($rt::AddLink && $rt::GetStalledParents) {
	    warn "SQL statement failed ($DBI::errstr)";
	}
     }

     sub load_relationships {
	 # should load all entries in the `relationship' table into some
	 # %rt::relship hash.
	 my $rv=0;

	 # I wanted to use sth->fetchrow_hashref, but it's not
	 # portable due to uppercase/lowercase differences in
	 # different DBMSes. I'll keep UPPERCASE for data fetched
	 # directly from the DB, MixedCase for bitmap data, etc, and
	 # maybe eventually lowercase for extra options or similar.
	 
	 my @relshipkeys=('ID','TYPE','BASE_URL','TITLE');
	 
	 my $sth = $dbh->prepare('SELECT '.join(',',@relshipkeys).' FROM relship');
	 $rv = $sth ? $sth->execute() : 0;
	 $rv || warn "[load_relationships] query had some problem: $DBI::errstr\n$query_string\n";
	 while (my $row=$sth->fetchrow_arrayref) {
	     my $id=$row->[0];
	     my $i=0;
	     for (@relshipkeys) {
		 $relship{$id}{$_}=$row->[$i++];
	     }
	     
	     $relship{$relship{$id}{TITLE}}=$relship{$id};
	 }
	 $sth->finish;
     }

  

    
    sub load_queue_acls {
	
	my ($user_id, $queue_id);


	$sth = $dbh->prepare("SELECT queue_acl.queue_id,
	   users.user_id, queue_acl.display, queue_acl.manipulate,
	   queue_acl.admin, users.email, queue_acl.mail FROM
	   queue_acl, users WHERE users.id = queue_acl.user_id");
	$sth->execute()
	    or warn "execute query had some problem: $DBI::errstr\n";

	while (@row=$sth->fetchrow) {
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
# seems like WORK to me, so I've postponed it for now. Tobix.
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

sub is_hash_of_password_and_ip {
  my $in_user_id = shift;
  my $in_ip = shift;
  my $in_hash = shift;
  my ($password,$hash, $ctx);
  
  if (!&is_a_user($in_user_id)) {
   
    return(0);
  }
  
  
  my $user_id=$dbh->quote($in_user_id);
  $query_string="SELECT password FROM users WHERE id = $user_id";
  $sth = $dbh->prepare($query_string) or warn "[is_password] prepare had some problem: $DBI::errstr\n$query_string\n";
  $rv = $sth->execute or warn "[is_password] execute had some problem: $DBI::errstr\n$query_string\n";
  @row=$sth->fetchrow_array;
  
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



sub is_a_user {
    my ($in_user_id) = shift;
    if ($users{"$in_user_id"}{name} eq $in_user_id) {
	return (1);
    }
    else {
	return(0);
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
