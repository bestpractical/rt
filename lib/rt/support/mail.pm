package rt;

#####
##### Mailing Routines
#####



sub template_replace_tokens {
    local ($template,$in_serial_num,$in_id, $in_custom_content, $in_current_user) = @_;

	&rt::req_in($in_serial_num,'_rt_system');
	&rt::transaction_in($in_id,'_rt_system');
    $template =~ s/%rtname%/$rtname/g;
    $template =~ s/%rtversion%/$rtversion/g;
    $template =~ s/%actor%/$in_current_user/g;
    $template =~ s/%subject%/$in_subject/g;
    $template =~ s/%serial_num%/$in_serial_num/g;
    $template =~ s/%mailalias%/$mail_alias/g;
    $template =~ s/%content%/$in_custom_content\n/g;
    $template =~ s/%req:(\w+)%/$rt::eq[$in_serial_num]{$1}/g;
    $template =~ s/%trans:(\w+)%/$rt::req[$in_serial_num]{'trans'}[$in_id]{$1}/g;
    $template =~ s/%queue:(\w+)%/$rt::queues{$rt::req[$in_serial_num]{'queue_id'}}{$1}/g;

    if ($in_serial_num > 0){
	&req_in($in_serial_num,$in_current_user);
  	&transaction_in($in_transaction,$in_current_user);
	} 

    return ($template);
}

sub template_mail{
    local ($in_template,$in_queue_id, $in_recipient, $in_cc, $in_bcc, $in_serial_num, $in_transaction, $in_subject, $in_current_user, $in_custom_content) = @_;
    my ($mailto, $template);

    $template=&template_read($in_template, $in_queue_id);
    $template=&template_replace_tokens($template,$in_serial_num,$in_transaction, $in_custom_content, $in_current_user);
    $subject=&template_replace_tokens($subject,$in_serial_num,$in_transaction, $in_custom_content, $in_current_user);
#    print STDERR "Debug 1\n";
    
    if ($in_recipient eq "") {
	return("template_mail:No Recipient Specified!");
    }

    open (MAIL, "|$rt::mailprog -f$rt::mail_alias -oi -t -OErrorMode=m ");

    print  MAIL "Subject: [$rt::rtname \#". $in_serial_num . "] ($in_queue_id) $in_subject
Reply-To: $rt::mail_alias
To: $in_recipient   
Cc: $in_cc
Bcc: $in_bcc
X-Request-ID: $in_serial_num
X-Sender: $in_current_user
X-Managed-By: Request Tracker ($rt::rtversion)
	 
$template
-------------------------------------------- Managed by Request Tracker\n";
    close (MAIL);
    
    return("template_mail:Message Sent");
}

1;
