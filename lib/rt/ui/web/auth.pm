package WebAuth;
#$AuthRealm="Default Realm Name";
require rt::database;
use CGI::Cookie;
&rt::connectdb();

sub AuthCheck () {
    my ($AuthRealm) = @_;
    my ($Name, $Pass,$path, $set_user, $set_pass);
    #lets get the cookies
    print "HTTP/1.0 200 Ok\n";
  
    if ($ENV{'SCRIPT_NAME'} =~ /(.*)\/(.*?)/) {
      $path=$1;

      
      
    }
    #strip a trailing /
    $path =~ s/\/$//;
    
    

    # lets set the user/pass cookies
    if (($rt::ui::web::FORM{'username'}) and ($rt::ui::web::FORM{'password'})) {
      
      
      $set_user = new CGI::Cookie(-name => 'RT_USERNAME',
				    -value => "$rt::ui::web::FORM{'username'}",
				  -expires => '+6M',
				  -path => $path);
      
	$set_password = new CGI::Cookie(-name => 'RT_PASSWORD',
					-value => "$rt::ui::web::FORM{'password'}",
					-expires => '+1h',
					-path => $path);
      
	
      
      
      #works well enough while we're nph-
      if ($rt::ui::web::FORM{'insecure_path'}) {
      $set_password =~ s/; path=(.*?); /; /;
      $set_user =~ s/; path=(.*?); /; /
    }
      

      print "Set-Cookie: $set_password\n";
      print "Set-Cookie: $set_user\n";   
    }

    
    #if we don't have cookies, it means we just logged in.
    if (!($rt::ui::web::cookies{'RT_PASSWORD'}) or !($rt::ui::web::cookies{'RT_USERNAME'})) {
      $Name = $rt::ui::web::FORM{'username'};
      $Pass = $rt::ui::web::FORM{'password'};
    }
    
    #otherwise, we've got cookies.
    else {
      $Name = $rt::ui::web::cookies{'RT_USERNAME'}->value;
      $Pass = $rt::ui::web::cookies{'RT_PASSWORD'}->value;
    }

    
    return ($Name, $Pass);
  }




sub AuthForceLogout () {
  #this routine is deprecated

  return(&AuthForceLogin(@_));
  
}



sub AuthForceLogin () {
  local ($AuthRealm) = @_;
  my ($default_user, $path);
  
   # lets set the user/pass cookies
  
    if ($ENV{'SCRIPT_NAME'} =~ /(.*)\/(.*?)/) {
      $path=$1;      
    }

  
#kill the auth cookies of both sorts...
  $set_password = new CGI::Cookie(-name => 'RT_PASSWORD',
				  -value => "",
				  -expires => '-1M'
				  -path => $path);
  
  $set_password =~ s/; path=(.*?)\/; /; path=$1; /;
  
  
  #works well enough while we're nph-
  print "Set-Cookie: $set_password\n";
  
  #now do it without hte path. yes this is a hack
  $set_password =~ s/; path=(.*?); /; /;
  print "Set-Cookie: $set_password\n";


  &rt::ui::web::header;

  if  ($rt::ui::web::cookies{'RT_USERNAME'}) {
    $default_user =  $rt::ui::web::cookies{'RT_USERNAME'}->value;
    
  }
  print "
<TABLE cellpadding=10 cellspacing=0 border=0>
<TR><TD BGCOLOR=\"#cccccc\"><FONT SIZE=\"+2\" COLOR=\"#bb0000\"><b>No valid RT Credentials found</b></FONT></TD></TR>
<TR><TD BGCOLOR=\"#eeeeee\">
  This RT Server requires you to log in with your RT username and password.  If you are unsure of your RT username or password, please seek out your local RT administrator.</TD>
</TR>
</TABLE>
    
    <FORM ACTION=\"$rt::ui::web::ScriptURL\" METHOD=\"POST\">


<CENTER>
      <TABLE CELLPADDING=0 CELLSPACING=0 BORDER=0 BGCOLOR=\"#EEEEEE\">

<TR VALIGN=\"TOP\">
<TD COLSPAN=3>
<TABLE WIDTH=\"100%\" CELLPADDING=10 CELLSPACING=0 BORDER=0>
<TR ALIGN=\"LEFT\"><TD VALIGN=\"CENTER\" BGCOLOR=\"#CCCCCC\">
<b>$AuthRealm Login:</b>
</TD></TR>
</TABLE>
</TD>

 <TD ROWSPAN=\"4\" width=8 bgcolor=\"#ffffff\"><IMG SRC=\"/webrt/srs.gif\" width=16 height=250 alt=''></TD>
</TR>  
<TR>
<TD ALIGN=\"RIGHT\">
Username:&nbsp;
</TD>
<TD >
<input name=\"username\" VALUE=\"$default_user\" size=\"20\">
</TD>
<TD>&nbsp;</TD>
</TR>
<TR>
<TD ALIGN=\"RIGHT\">
Password:&nbsp;
</TD>
<TD>
<input name=\"password\" type=\"password\" size=\"20\">
</TD>
<TD>&nbsp;</TD>
</TR>
<TR><TD align=\"right\" VALIGN=\"TOP\">
<INPUT TYPE=\"CHECKBOX\" name=\"insecure_path\"></td><td ALIGN=\"LEFT\" VALIGN=\"TOP\">&nbsp;<font size=\"-1\"><B>Send authentication info to all scripts on this server.</B></font><br><font size=\"-1\">(If you're having trouble with RT and IE4.01sp1, check here.)<BR> <font size=\"-2\" color=\"red\">&nbsp;On a server with potentially malicious scripts, this could be a security risk.</font><br>
</td>
<TD ALIGN=\"LEFT\">
<INPUT TYPE=\"SUBMIT\" VALUE=\"Login\">
</TD>
</TR>


<TR VALIGN=\"TOP\"><TD COLSPAN=3><img src=\"/webrt/sbs.gif\" width=520 height=16 alt=''></TD>
<TD ALIGN=\"LEFT\" BGCOLOR=\"#ffffff\"><img src=\"/webrt/sbc.gif\" width=12 alt='' height=16></TD></TR>
</TABLE>
</CENTER>

<br><br>
";

&rt::ui::web::credits();

print "
</FORM>

</BODY>
";
  
  &rt::ui::web::content_footer;
  
}

# return a username if the HTTPd has authenticated for us
# undefined otherwise
sub HTTP_AuthAvailable() {
  # make sure that we are called by the httpd or by the rt-user
    if(($EUID == $UID) || ($UID == $http_user)) {
      return $ENV{'REMOTE_USER'};
    }
    return undef;
  }    

sub Headers_Authenticated(){
  #We simply DO NOT NEED THIS HERE
  
  return();   
  
  
}



1;
