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
    local ($in_template,$in_queue_id, $in_recipient, $in_serial_num, $in_transaction, $in_subject, $in_current_user, $in_custom_content) = @_;
    my ($mailto, $template);

    $template=&template_read($in_template, $in_queue_id);
    $template=&template_replace_tokens($template,$in_serial_num,$in_transaction, $in_custom_content, $in_current_user);
    $subject=&template_replace_tokens($subject,$in_serial_num,$in_transaction, $in_custom_content, $in_current_user);
#    print STDERR "Debug 1\n";
    
    if ($in_recipient eq "") {
	return("template_mail:No Recipient Specified!");
    }
    $mailto = "$mailprog -f$rt::mail_alias \"$in_recipient\" >/dev/null 2>/dev/null";
    $mailto =~ /^(.*)/;  
    $mailto = $1;          # a nasty hack, but we've gotta untaint things
 #   print STDERR "Debug 2 [$mailto]\n";
    open (MAIL2, "|$mailto");
    print MAIL2"Subject: [$rt::rtname \#". $in_serial_num . "] ($in_queue_id) $in_subject\n";


    print MAIL2 "Reply-To: $rt::mail_alias\n";
    print MAIL2 "X-Request-ID: $in_serial_num\n";
    print MAIL2 "X-Sender: $in_current_user\n";
    print MAIL2 "X-Managed-By: Request Tracker ($rt::version)\n";
    print MAIL2 "To: $in_recipient\n";          

    print MAIL2 "\n\n";
    print MAIL2 "$template";
    print MAIL2 "\n-------------------------------------------- Managed by Request Tracker\n";
    close (MAIL2);

    return("template_mail:Message Sent");
}

1;
