# $Version$
#
# RT is (c) Copyright 1996-1999 Jesse Vincent
# RT is distributed under the terms of the GNU General Public License


package rt::ui::web;

sub check_auth() {
    my ($name,$pass);
    
    # If we're doing external authentication

    if ($rt::web_auth_mechanism =~ /external/i) {
      $current_user = $ENV{REMOTE_USER};                                        
      &WebAuth::Headers_Authenticated();  
      return (0);
      
    }
    
    else {
          
    require rt::database::config;	
    
    $AuthRealm="WebRT for $rt::rtname";
    
    
    ($name, $pass)=&WebAuth::AuthCheck($AuthRealm);
       #if the user isn't even authenticating
    if ($name eq '') {
      &WebAuth::AuthForceLogin($AuthRealm);
      exit(0)
    }
 
    #if the user's password is bad
    elsif (!(&rt::is_hash_of_password_and_ip($name,$ENV{'REMOTE_ADDR'}, $pass))) {
      
      &WebAuth::AuthForceLogin($AuthRealm);
      exit(0);
    }
    
    #if the user is trying to log out
    if ($rt::ui::web::FORM{'display'} eq 'Logout') {
      &WebAuth::AuthForceLogin($AuthRealm);
      exit(0);
    }
    else { #authentication has succeeded
      $current_user = $name;
      
    }
  }    
    
}

sub print_html{
    my ($value) = shift;
    $value =~ s/</&lt;/g;
    $value =~ s/>/&gt;/g;
    print "$value";
}


sub print_transaction {
    my $header_mode = shift;
    my $headers_ignore = shift;
    my $lines = shift;

    # print "Pay attention to $header_mode\n";
    # print "Ignore $headers_ignore\n";

    #   print "lines is $lines\n";
    #   accept rfc822 messages and stupid RT format

    ((($body,$headers) =  split (/--- Headers Follow ---\n\n/, $lines,2))) or 
	(($headers, $body) = split ('\n\n',$lines)) or
	    $body = $lines;
    
    
    
    # join continuation lines 
    $headers =~ s/\n\s+/ /g;
    @header_lines = split (/^/m, $headers);

    if ($header_mode ne 'none') {
	


	&new_table(); {
	foreach $line (@header_lines) {
	    ($field, $value)= split (/:/,$line, 2);
	    #we want to nuke the From a@b.c line
	    if ($field =~ /From\s+/) {
		next;}
	    
	    if ((($header_mode eq 'all') or ($field =~ /$header_mode/i)) and 
		($field !~ /$headers_ignore/i)) {
		&new_row(); {
		    &new_col("align=\"right\""); {
			&print_html($field); 
		    } &end_col();
		    
		    &new_col(); {
			&print_html($value);
		    } &end_col;
		} &end_row();
	    }

	    }
    } &end_table;
	
    }

     $body =~ s/(.{76})\s+/$1\n/g;                                             
     $body =~ s/(.{100})/$1\n/g;   
    
    print "<pre>";
    &print_html($body);
    print "</pre>";
}

	
sub dump_env
{
# Get the input
    foreach $pair (%ENV)    {
	print STDERR "$pair\n";
	
    }
    foreach $pair (%FORM)    {
	print STDERR "$pair\n";
	
    }
}


sub frames {
    if ($ENV{'PATH_INFO'} =~ /\/frames/) {

	return(1);
    }
    else {
	return(0);
    }
}

sub cgi_vars_in {
    my ($buffer,$name, $value);
    local($^W) = 0; #we're told that the value =~ lines are uninitialized vals
                    #but they're not.
# code between the lines was grabbed from form-mail.pl by MIT's the tech
# Get the input
    
    #let's get the cookies
    use CGI::Cookie;
    %rt::ui::web::cookies = fetch CGI::Cookie;
# Split the name-value pairs
    if ($ENV{'CONTENT_LENGTH'}) {
	read(STDIN, $buffer, $ENV{'CONTENT_LENGTH'});
    }
    if ($buffer) {
	@pairs = split(/&/, $buffer);
    }
    else {
	
	@pairs = split(/&/,$ENV{'QUERY_STRING'});
    }
    
    foreach $pair (@pairs)   {
	($name, $value) = split(/=/, $pair);
	# Un-Webify plus signs and %-encoding
	$value =~ tr/+/ /;
	$name  =~ tr/+/ /;
	$value =~ s/%([a-fA-F0-9][a-fA-F0-9])/pack("C", hex($1))/eg;
	$name  =~ s/%([a-fA-F0-9][a-fA-F0-9])/pack("C", hex($1))/eg;
	$value =~ s/&lt/</g;
	$value =~ s/&gt/>/g;
	# Stop people from using subshells to execute commands
	# Not a big deal when using sendmail, but very important
	# when using UCB mail (aka mailx).
	$value =~ s/~!/ ~!/g;
	
	#untaint as per perl sec
	if (0){ #($name ne 'content') { # we can't hack up content this way or we 
	    $value =~ /^(\w+)$/;  # may not be able to read it
	    $value = $1;          # a nasty hack, but we've gotta untaint things
	}                         # although it may simply be better to untaint when we
	# actually open a filehandle.

	# Uncomment for debugging purposes
	 # print STDERR "A gnarled troll tells you that $name was set to $value\n";
	$FORM{$name} = $value;
	
    }
}



sub select_an_int{
    my ($default, $name) = @_;
    my ($ones, $tens, $counter);
    $tens = int($default / 10);
    $ones = int($default % 10);
    print "<select name=\"".$name."_tens\">\n";
    for ($counter=0;$counter<=9;$counter++) {
	print "<option";
	if ($tens==$counter) {print " SELECTED";}
	print ">$counter\n";
    }
    print "</select><select name=\"".$name."_ones\">\n";
    for ($counter=0;$counter<=9;$counter++) {
	print "<option";
	if ($ones==$counter) {print " SELECTED";}
	print ">$counter\n";
    }
    print "</select>\n"; 
    
}
sub select_a_date{
    my ($default, $name) = @_;
    my ($wday, $mon, $mday, $hour, $min, $sec, $TZ, $year, $temp, $counter, $now_year);
    local (@MoY = ('Jan','Feb','Mar','Apr','May','Jun',
	       	   'Jul','Aug','Sep','Oct','Nov','Dec'));

    if (!$default) { # if we don't supply a default, say it will be done next week
	$default=$rt::time+604800;
    }
   
   ($wday, $mon, $mday, $hour, $min, $sec, $TZ, $now_year)=&rt::parse_time($rt::time);
  print "<select name=\"".$name."_mday\">\n";
    for ($counter=1;$counter<=31;$counter++) {
	print "<option";
	if ($mday==$counter) {print " SELECTED";}
	print ">$counter\n";
    }
    print "</select><select name=\"".$name."_month\">\n";
    for ($counter=0;$counter<=11;$counter++) {
	print "<option value=\"$counter\" ";
	if ($mon eq $MoY[$counter]) {print " SELECTED";}
	print ">$MoY[$counter]\n";
    }
    print "</select><select name=\"".$name."_year\">\n";
    for ($counter=$now_year;$counter<=($now_year+5);$counter++) {
	print "<option value=\"".($counter-1900)."\" "; #apparently, timelocal
	                                            #likes dates to be 2 digits
	                                            #that sucks
	if ($now_year==$counter) {print " SELECTED";}
	print ">$counter\n";
    }
    print "</select>\n"; 

}


sub header {
    if ($header_printed) {
	return();
    }
    print "Content-type: text/html\n\n";
    print '<HTML>
<head><title>WebRT</title>
<META HTTP-EQUIV="PRAGMA" CONTENT="NO-CACHE">
</head>
<BODY  bgcolor="#ffffff">
';
    #   if (!&frames()) {
    #	#&head_foot_options;
    #	print "<hr>";
    #    }
    $header_printed=1; #this is so we only print one header...even if we call header twide
}


sub footer {
    if (!&frames()) {

	
	print "<center>
You are currently authenticated as $current_user. <br><a href=\"$rt::ui::web::ScriptURL?display=Logout\">Be careful not to leave yourself logged in from a <b>public terminal.</b></a><br>
Please report all bugs to <a href=\"mailto:rt-devel\@lists.fsck.com\">the RT Developers</a>.
</center>\n";
    }
    print "</body>\n</html>";
}
			
sub content_header {
    if ($header_printed) {
	return();
    }
    print "Content-type: text/html\n\n";
    print "<HTML>\n";
    print "<head><title>WebRT</title>
<META HTTP-EQUIV=\"PRAGMA\" CONTENT=\"NO-CACHE\">
</head>\n";
    $header_printed=1;
}
sub content_footer {
    print "</html>";
}


sub table_label {
    my ($label) = shift;
    print "<sup><font size=-2>$label:</font></sup> ";
}

sub new_table {
    my ($options) = shift;
    print "<table $options>\n";
}

sub end_table {
    print "</table>\n";
}
sub new_row {
    my ($options) = shift;
    print "<tr $options>\n";
    
}
sub end_row {
    
    print "</tr>\n";
}
sub new_col {
    my ($options) = shift;
    if (!$options) { 
	print "<td valign=\"top\">\n";
    }
    else {
	print "<td $options>\n";
    }
}
sub end_col {
    print "</td>\n";
}


1;
