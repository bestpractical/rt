package rt::ui::cli::manipulate;


sub activate {

	($current_user,$tmp)=getpwuid($<);

	($value, $message)=&rt::initialize($current_user);
	if ($value == 0) {
	    print "$message\n";
	    exit(0);
	} 
	else {
	    print "$message\n";
	}
	&parse_args;
}

sub print_transaction
{
    my ($index, $in_serial_num) =@_;
    print "==========================================================================\n";
    print "Date: $rt::req[$in_serial_num]{'trans'}[$index]{'text_time'}\n";
    print "$rt::req[$in_serial_num]{'trans'}[$index]{'text'}\n";
    if ($rt::req[$in_serial_num]{'trans'}[$index]{'content'}) {
	print "$rt::req[$in_serial_num]{'trans'}[$index]{'content'}\n";
    }


    
}


sub parse_args {
  for ($i=0;$i<=$#ARGV;$i++) {
    if ($ARGV[$i] eq "-create")   {
      &cli_create_req;
    }
    elsif (($ARGV[$i] eq "-history") || ($ARGV[$i] eq "-show")){
      $serial_num=int($ARGV[++$i]);
      if (&rt::can_display_request($serial_num, $current_user)) {
	&cli_show_req($serial_num);
	&cli_history_req($serial_num);
      }
      else {
	print "You don't have permission to display request #$serial_num\n";
      }
    }
    
    
	elsif ($ARGV[$i] eq "-trans") {

		$serial = int($ARGV[++$i]);
		$trans = int($ARGV[++$i]);
		&rt::req_in($serial,$current_user);
		&print_transaction($serial, $trans);	

	}
	
	elsif ($ARGV[$i] eq "-comment")	{
	    $arg=int($ARGV[++$i]);
	    &cli_comment_req($arg);
	}

        elsif ($ARGV[$i] eq "-respond") {
            $arg=int($ARGV[++$i]);
            &cli_respond_req($arg);
        }      	
	elsif ($ARGV[$i] eq "-take")	{
	    $serial_num=int($ARGV[++$i]);
	    ($trans,$message)=&rt::take($serial_num, $current_user);
	    print "$message\n";
	}
	
	elsif ($ARGV[$i] eq "-stall")	{
	    $serial_num=int($ARGV[++$i]);
	
	    ($trans,$message)=&rt::stall ($serial_num, $current_user);
	    print "$message\n";
	}

	elsif ($ARGV[$i] eq "-kill")	{
	    $serial_num=int($ARGV[++$i]);
	    $response=&rt::ui::cli::question_string("Type 'yes' if you REALLY want to KILL request \#$serial_num",);
	    if ($response eq 'yes') { 
		($trans,$message)=&rt::kill ($serial_num, $current_user);
		print "$message\n";
	    }
	    else {
		print "Kill aborted.\n";
		
	    }
	}
	
	elsif ($ARGV[$i] eq "-steal")	{
	    $serial_num=int($ARGV[++$i]);
	    ($trans,$message)=&rt::steal($serial_num, $current_user);
	    print "$message\n";
	    
	}
	
	elsif ($ARGV[$i] eq "-user")	{
	    $serial_num=int($ARGV[++$i]);
	    $new_user=$ARGV[++$i];
	    ($trans,  $message)=&rt::change_requestors($serial_num, $new_user, $current_user);
	    print "$message\n";
	}
	
	elsif ($ARGV[$i] eq "-untake")	{
	    $serial_num=int($ARGV[++$i]);
	    ($trans,$message)=&rt::untake($serial_num, $current_user);
	    print "$message\n";
	}
	
	elsif ($ARGV[$i] eq "-subject")	{
	    $serial_num=int($ARGV[++$i]);
	    $subject=$ARGV[++$i];
	    ($trans,  $message)=&rt::change_subject ($serial_num, $subject, $current_user);
	    print "$message\n";
	}
	
	elsif ($ARGV[$i] eq "-queue")	{
	    $serial_num=int($ARGV[++$i]);
	    $queue=$ARGV[++$i];
	    ($trans,$message)=&rt::change_queue($serial_num, $queue, $current_user);
	    print "$message\n";
	}
	elsif ($ARGV[$i] eq "-area")	{
	    $serial_num=int($ARGV[++$i]);
	    $area=$ARGV[++$i];
	    ($trans,$message)=&rt::change_area($serial_num, $area, $current_user);
	    print "$message\n";
	}

	elsif ($ARGV[$i] eq "-merge")	{
	    $serial_num=int($ARGV[++$i]);
	    $merge_into=int($ARGV[++$i]);
	    ($trans,$message)=&rt::merge($serial_num, $merge_into, $current_user);
	    print "$message\n";	}
	elsif ($ARGV[$i] eq "-due")	{
	    $due_string=$ARGV[++$i];
	    $due_date = &rt::date_parse($due_string);
	    ($trans,$message)=&rt::change_date_due($serial_num, $due_date, $current_user);
	    print "$message\n";	}
	
	elsif ($ARGV[$i] eq "-prio") {
	    $serial_num=int($ARGV[++$i]);
	    $priority=int($ARGV[++$i]);
	    ($trans,  $message)=&rt::change_priority ($serial_num, $priority,$current_user);
	    print "$message\n";
	}
	
	elsif ($ARGV[$i] eq "-finalprio") {
	    $serial_num=int($ARGV[++$i]);
	    $priority=int($ARGV[++$i]);
	    ($trans,  $message)=&rt::change_final_priority ($serial_num, $priority,$current_user);
	    print "$message\n";
	}
	elsif ($ARGV[$i] eq "-notify") {
	    $serial_num=int($ARGV[++$i]);
	    ($trans,$message)=&rt::notify($serial_num, $rt::time, $current_user);
	    print "$message\n";	
	}
	
	elsif ($ARGV[$i] eq "-give")	{
	    $serial_num=int($ARGV[++$i]);
	    $owner=$ARGV[++$i];
	    ($trans,  $message)=&rt::give($serial_num, $owner, $current_user);
	    print "$message\n";
	}
	
	elsif ($ARGV[$i] eq "-resolve")	{
	    $serial_num=int($ARGV[++$i]);
	    ($trans,$message)=&rt::resolve($serial_num, $current_user);
	    print "$message\n";
	}
	
	elsif ($ARGV[$i] eq "-open")	{
	    $serial_num=int($ARGV[++$i]);
	    ($trans,$message)=&rt::open ($serial_num, $current_user);
	    print "$message\n";
	}

	else {
	    &cli_help_req;
	}
	next
    }
}

   
 


sub cli_create_req {	
    my ($queue_id,$owner,$requestors,$status,$priority,$subject,$final_prio,$date_due);
    $queue_id=&rt::ui::cli::question_string("Place Request in queue",);
    $area=&rt::ui::cli::question_string("Place Request in area",);
    $owner=&rt::ui::cli::question_string( "Give request to");
    $requestors=&rt::ui::cli::question_string("Requestor(s)",);
    $subject=&rt::ui::cli::question_string("Subject",);
    $priority=&rt::ui::cli::question_int("Starting Priority",$queues{$queue_id}{default_prio});
    $final_priority=&rt::ui::cli::question_int("Final Priority",$queues{$queue_id}{default_final_prio});
    $due_string=&rt::ui::cli::question_string("Date due (MM/DD/YY)",);
    if ($due_string ne '') {
	 $date_due = &rt::date_parse($due_string);
	}  
  print "Please enter a detailed description of this request, terminated\nby a line containing only a period:\n";
    while (<STDIN>) {
	if(/^\.\n/) {
	    last;
	}
	else {
	    $content .= $_;
	}
  	}	  
    ($serial_num,$trans,$message)=&rt::add_new_request($queue_id,$area,$requestors,$alias,$owner,$subject,$final_priority,$priority,'open', $rt::time, 0, $date_due, $content,$current_user);
    print "$message\n";
}

sub cli_comment_req {	
    my ($serial_num)=@_;
    my ($subject,$content,$trans,$message,$cc,$bcc );
   
#    if (&rt::can_manipulate_request($serial_num, $current_user)) {
    $subject=&rt::ui::cli::question_string("Subject",);
    $cc=&rt::ui::cli::question_string("Cc",);
    $bcc=&rt::ui::cli::question_string("Bcc",);   
    print "Please enter your comments this request, terminated\nby a line containing only a period:\n";
    while (<STDIN>) {
	if(/^\.\n/) {
	    last;
	}
	else {
	    $content .= $_;
		}
  	}
    
    ($trans,  $message)=&rt::comment($serial_num,$content,$subject,$cc,$bcc,$current_user);
    print $message;
#	}
#	else {
#	print "You do not have permission to work with this request\n";
#	}
}
sub cli_respond_req {
    my ($serial_num)=@_;
    my ($subject,$content,$trans,$message,$cc,$bcc );

    $subject=&rt::ui::cli::question_string("Subject",);
    $cc=&rt::ui::cli::question_string("Cc",);
    $bcc=&rt::ui::cli::question_string("Bcc",);      
    print "Please enter your response to this request, terminated\nby a line containing only a period:\
n";
    while (<STDIN>) {
        if(/^\.\n/) {
            last;
        }
        else {
            $content .= $_;
                }
        }

    ($trans,  $message)=&rt::add_correspondence($serial_num,$content,$subject,$cc,$bcc,"",1,$current_user);
    print $message;
}                   

sub cli_history_req {
    my ($in_serial_num)=@_;
    $total_transactions=&rt::transaction_history_in($in_serial_num,$current_user);
    for ($temp=0; $temp < $total_transactions; $temp++){
	&print_transaction($temp, $in_serial_num);
    }   
}

sub cli_help_req {
    print "
    
    RT CLI Flags and their arguments
    -----------------------------------------------
    -create		  Interactively create a new request
    -resolve <num>	  Change <num>'s status to resolved
    -open <num>		  Change <num>'s status to open
    -stall <num>	  Change <num>'s status to stalled
    -show <num>		  Display transaction history current status of <num>
    -take <num>		  Become owner of <num> (if unowned)
    -steal <num>	  Become owner of <num> (if owned by another)
    -untake <num>	  Make <num> ownerless (if owned by you) 
    -give <num> <user>	  Make <user> owner of <num>
    -user <num> <user>	  Change the requestor ID of <num> to <user>
    -due <num< <date>     Change <num>'s due date to <date> (MM/DD/YY)
    -comment <num>	  Add comments about <num> from STDIN
    -respond <num>	  Respond to <num>
    -subject <num> <sub>  Change <num>'s subject to <sub>
    -queue <num> <queue>  Change <num>'s queue to <queue>
    -area <num> <area>    Change <num>'s area to <area>
    -prio <num> <int>	  Change <num>'s priority to <int>
    -finalprio <num <int> Change <num>'s final priority to <int>
    -notify <num>	  Note that <num>'s requestor was notified
    -merge <num1> <num2>  Merge <num1> into <num2>
    -trans <ser> <trans>  Display ticket <ser> transaction <trans>
    -kill <num>           Permanently remove <num> from the database\n";

}

sub cli_show_req {
    my ($in_serial_num)=@_;
use Time::Local;

    &rt::req_in($in_serial_num,$current_user);
    print "        Serial Number:$in_serial_num\n";
    print "               Queue:$rt::req[$in_serial_num]{'queue_id'}\n";
    print "                Area:$rt::req[$in_serial_num]{'area'}\n";
    print "          Requestors:$rt::req[$in_serial_num]{'requestors'}\n";
    print "               Owner:$rt::req[$in_serial_num]{'owner'} \n";
    print "             Subject:$rt::req[$in_serial_num]{'subject'}\n";
    print "      Final Priority:$rt::req[$in_serial_num]{'final_priority'}\n";
    print "    Current Priority:$rt::req[$in_serial_num]{'priority'}\n";
    print "              Status:$rt::req[$in_serial_num]{'status'}\n";
    print "             Created:". localtime($rt::req[$in_serial_num]{'date_created'})."\n";
    print "   Last User Contact:".localtime($rt::req[$in_serial_num]{'date_told'})."\n";
    print "        Last Contact:$rt::req[$in_serial_num]{'since_told'}\n";
    print "                 Due:".localtime($rt::req[$in_serial_num]{'date_due'})."\n";
    print "                 Age:$rt::req[$in_serial_num]{'age'}\n";
    
}



1;
