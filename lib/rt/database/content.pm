package rt;

sub write_content {
    local ($time, $serial_num,$transaction_num,$content) =@_;
     my ($temp,$file);


    require rt::support::utils; # for untaint

    $serial_num=int($serial_num);
    $transaction_num=int($transaction_num);
    ($weekday, $month, $monthday, $hour, $min, $sec, $TZ, $year)=&parse_time($time);
	$serial_num = &rt::untaint($serial_num);
	$transaction_num = &rt::untaint($transaction_num);
	$weekday= &rt::untaint($weekday);
	$month= &rt::untaint($month);
	$monthday = &rt::untaint($monthday);
	$hour = &rt::untaint($hour);
	$min = &rt::untaint($min);
	$sec = &rt::untaint($sec);
#	$TZ= &rt::untaint($TZ);
	$year = &rt::untaint($year);

    $temp = $<;
    $< = $>; #set real to effective uid
    
    #these 0700s should be $dirmodes..but perl doesn't like that.
    if (! (-d "$transaction_dir/$year")) {
	mkdir ("$transaction_dir/$year",0700);
#	chown $rtusernum, $rtgroupnum, "$transaction_dir/$year";
    }
    $month_dir = "$transaction_dir/$year/$month"; 

    if (! (-d "$month_dir"))  {
	mkdir("$month_dir",0700);
	#chown $rtusernum, $rtgroupnum, "$transaction_dir/$year/$month";
    }

    $day_dir = "$month_dir/$monthday";
  

  if (! (-d "$day_dir"))  {
	mkdir ("$day_dir", 0700);
#	chown $rtusernum, $rtgroupnum, "$transaction_dir/$year/$month/$monthday";
    }
    $file="$transaction_dir/$year/$month/$monthday/$serial_num.$transaction_num";



    open(CONTENT, ">$file"); 
    print CONTENT "$content";
    close (CONTENT);

    $< = $temp;    
    
    #add this note to the glimpse database
    if ($glimpse_index) {
	
	open (GLIMPSE ,"$rt::glimpse_index -H $rt::glimpse_dir -a $file");
	while (<GLIMPSE>) {}
	close (GLIMPSE);
    }
}




sub read_content {
    
    local ($in_time, $in_serial_num,$in_transaction_num) =@_;
    local ($content="");
    
    $in_serial_num=int($in_serial_num);
    $in_transaction_num=int($in_transaction_num);
    
    ($weekday, $month, $monthday, $hour, $min, $sec, $TZ, $year)=&parse_time($in_time);
    $file="$transaction_dir/$year/$month/$monthday/$in_serial_num.$in_transaction_num";
    if (! (-r $file)) 
    {
	$file="$transaction_dir/$year/$month/$in_serial_num.$in_transaction_num";
	if (! (-r $file))
        {                                  	
	    
	    return (0,"The specified transaction's content is missing or inaccessable. ($in_time, $in_serial_num:$in_transaction_num)");
	}
    }
    open(CONTENT, $file); 
    while (<CONTENT>)
    {
	$content .= $_;
    }
    close (CONTENT);
    return (1,$content);
}

1;
