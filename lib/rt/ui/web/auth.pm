package WebAuth;
#$AuthRealm="Default Realm Name";
require rt::database;
use CGI::Cookie;
&rt::connectdb();

sub AuthCheck () {
    my ($AuthRealm) = @_;
    my ($Name, $Pass, $set_user, $set_pass);
    #lets get the cookies
    print "HTTP/1.0 200 Ok\n";
  




# lets set the user/pass cookies
    if ($rt::ui::web::FORM{'username'} and $rt::ui::web::FORM{'password'}) {
      $set_user = new CGI::Cookie(-name => 'RT_USERNAME',
				     -value => "$rt::ui::web::FORM{'username'}",
				     -expires => '+6M',
				     -path => "$ENV{'SCRIPT_NAME'}");
      #works well enough while we're nph-
      print "Set-Cookie: $set_user\n";
      
      $set_password = new CGI::Cookie(-name => 'RT_PASSWORD',
				      -value => "$rt::ui::web::FORM{'password'}",
				      -expires => '+1h',
				      -path => "$ENV{'SCRIPT_NAME'}"	    );
      #works well enough while we're nph-
      print "Set-Cookie: $set_password\n";
      
    }


 if (!($rt::ui::web::cookies{'RT_PASSWORD'}) or !($rt::ui::web::cookies{'RT_USERNAME'})) {

      $Name = $rt::ui::web::FORM{'username'};
    
      
      $Pass = $rt::ui::web::FORM{'password'};
    }
    

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
  my ($default_user);
  
   # lets set the user/pass cookies
  


  $set_password = new CGI::Cookie(-name => 'RT_PASSWORD',
				   -value => "",
				-expires => '-1M',
				-path => "$ENV{'SCRIPT_NAME'}"	    );
  #works well enough while we're nph-
  print "Set-Cookie: $set_password\n";

  &rt::ui::web::header;

  if  ($rt::ui::web::cookies{'RT_USERNAME'}) {
    $default_user =  $rt::ui::web::cookies{'RT_USERNAME'}->value;
    
  }
  print "
<CENTER><B><FONT SIZE=\"+4\">No valid RT Credentials found</FONT></B></CENTER>
  This RT Server requires you to log in with your RT username and password.  If you are unsure of your RT username or password, please seek out your local RT administrator.
    
    <FORM ACTION=\"$rt::ui::web::ScriptURL\" METHOD=\"POST\">
<CENTER>
      <TABLE><TR><TD COLSPAN=2>
	$AuthRealm Login:
	</TD></TR>  
	  <TR><TD ALIGN=\"RIGHT\">Username:</TD><TD><input name=\"username\" VALUE=\"$default_user\" size=\"20\"></TD></TR>
	    <TR><TD ALIGN=\"RIGHT\">Password:</TD><TD><input name=\"password\" type=\"password\" size=\"20\"></TD></TR>
	      <TR><TD COLSPAN=2 ALIGN=\"RIGHT\">
		
		<INPUT TYPE=\"SUBMIT\" VALUE=\"Login\"></TD></TR>
		  </TABLE>
</CENTER>
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
