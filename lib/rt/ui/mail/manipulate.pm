package rt::ui::mail::manipulate;

sub activate {
  
  my $in_queue=$ARGV[0];
  my $in_action=$ARGV[1];
  my $in_area = $ARGV[2];
  
  if (!$in_queue){
    $in_queue="general";
  }
  if (!$in_action){
    $in_action='correspond';
  }
  
  
  
  my $time = time;
  my $AttachmentDir = "/tmp/rt/$time";
  mkdir "$AttachmentDir", 0700;
  # Create a new parser object:
  use MIME::Parser;
  


  #Set up a MIME::Parser

  my $parser = new MIME::Parser;
  
  # Set up output directory for files:
  $parser->output_dir("$AttachmentDir");
  
  # Set up the prefix for files with auto-generated names:
  $parser->output_prefix("part");
  
  # If content length is <= 20000 bytes, store each msg as in-core scalar;
  # Else, write to a disk file (the default action):
  $parser->output_to_core(20000);
  


  
  #Ok. now that we're set up, let's get the stdin.
  $entity = $parser->read(\*STDIN) or die "couldn't parse MIME stream";
  

  # Get the head, a MIME::Head:
  $head = $entity->head;

  #Lets check for mail loops of various sorts.
  my $IsALoop = &CheckForLoops($head);
  
  if ($IsALoop) {
    #TODO Send mail to an administrator
    die "RT Recieved a message it should not process";
    
  }

  
  # Get the body, as a MIME::Body;
  $bodyh = $entity->bodyhandle;
  
  
  # Get the actual MIME type, in the header:
  $type = $entity->mime_type;
  
  # Get the effective MIME type (for dealing with nonstandard encodings):
  $eff_type = $entity->effective_type;
  
  
  # Get preamble, parts, and epilogue:
  $preamble   = $entity->preamble;          # ref to array of lines
  $num_parts  = $entity->parts;
  $first_part = $entity->parts(0);          # an entity
  $epilogue   = $entity->epilogue;          # ref to array of lines
  
  


  $entity->dump_skeleton;

  if ($type eq 'multipart/alternative') {
    print "EEK an ugly html message";
  }
  else {
    print "It's not multipart/alternative";
  }


  # TODO
  # Recurse through all parts of the message. If any of them
  # are multipart-alternative and RT can find a text/plain,
  # remove the html part and promote the text part
  # to replace the multipart/alternative.

  

  #Figure out who's sending this message.

  #Pull apart the subject line




  #If the message applies to an existing ticket

  #   If the message contains commands, execute them

  #   If the mail message is a comment, add a comment.


  #   If the message is correspondence, add it to the ticket



  #If the message doesn't reference a ticket #,

  #    If the message is meant to be a comment, return an error.

  #    open a new ticket 



}  

sub parse_headers {
  my ($content) ="@_";
  ($headers, $body) = split (/\n\n/, $content, 2);
  
  foreach $line (split (/\n/,$headers)) {
    
    elsif (($line =~ /^Subject:(.*)\[$rt::rtname\s*\#(\d+)\]\s*(.*)/i) and (!$subject)){
      $serial_num=$2;
      &rt::req_in($serial_num,$current_user);
      $subject=$3;
      $subject =~ s/\($rt::req[$serial_num]{'queue_id'}\)//i;
    }
    
    elsif (($line =~ /^Subject: (.*)/) and (!$subject)){
      $subject=$1;
    }
    
    elsif (($line =~ /^Reply-To: (.*)/)) {
      $replyto = $1;
    }
    
    elsif ($line =~ /^From: (.*)/) {
      $from = $1;
    }
    
    elsif ($line =~ /^Sender: (.*)/){
      $sender = $1;
      
    }
    elsif ($line =~ /^Date: (.*)/) {
      $time_in_text = $1;
    }
  }
     
  $current_user = $replyto || $from || $sender;
  
  # Get the real name of the current user from the
  # replyto/from/sender .. etc
  
  $name_temp = $current_user;
  
  
  if ($current_user =~/<(\S*\@\S*)>/){
    $current_user =$1;
    $rt::users{$current_user}{real_name}=$`
      if (!exists $rt::users{$current_user}{real_name});
  }
  if ($current_user =~/(\S*\@\S*)/) {
    $current_user =$1;
    $rt::users{$current_user}{real_name}=$'
      if (!exists $rt::users{$current_user}{real_name});
  }
  if ($current_user =~/<(\S*)>/){
    $current_user =$1;
    $rt::users{$current_user}{real_name}=$`
      if (!exists $rt::users{$current_user}{real_name});
  }
  
  if (!$subject) {
    $subject = "[No Subject Given]";
  }
  
}

  
  
  
  




sub CheckForLoops {
  my $head = shift;

  #If this instance of RT sent it our, we don't want to take it in
  my $RTLoop = $head->get("X-RT-Loop-Prevention");
  if ($RTLoop eq "$RT::rtname") {
    return(1);
  }
 
  #if it's from a postmaster or mailer daemon, it's likely a bounce.
  my $From = $head->get("From");
  
  if (($From =~ /^mailer-daemon/i) or
      ($From =~ /^postmaster/i)){
    return (1);
  }

  #If it claims to be bulk mail, discard it
  my $Precedence = $head->get("Precedence");

  if ($Precedence =~ /^bulk/i) {
    return (1);
  }


1;
