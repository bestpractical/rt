package rt;

sub write_content {
    local ($time, $serial_num,$transaction_num,$content) =@_;
     my ($temp,$file);

    $serial_num=int($serial_num);
    $transaction_num=int($transaction_num);
    ($weekday, $month, $monthday, $hour, $min, $sec, $TZ, $year)=&parse_time($time);
    $temp = $<;
    $< = $>; #set real to effective uid
    
    #these 0700s should be $dirmodes..but perl doesn't like that.
    if (! (-d "$transaction_dir/$year")) {
	mkdir ("$transaction_dir/$year",0700);
#	chown $rtusernum, $rtgroupnum, "$transaction_dir/$year";
    }
    if (! (-d "$transaction_dir/$year/$month"))  {
	mkdir("$transaction_dir/$year/$month",0700);
	#chown $rtusernum, $rtgroupnum, "$transaction_dir/$year/$month";
    }
    if (! (-d "$transaction_dir/$year/$month/$monthday"))  {
	mkdir ("$transaction_dir/$year/$month/$monthday", 0700);
#	chown $rtusernum, $rtgroupnum, "$transaction_dir/$year/$month/$monthday";
    }
    $file="$transaction_dir/$year/$month/$monthday/$serial_num.$transaction_num";
    $file =~ /^(.*)$/g;            #I hate fucking taint checks
    $file = $1;                    #especially when there isn't an elegant override
                                   #and they only appear to work sometimes
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
