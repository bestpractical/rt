# $Header$
#
# WebAuth is part of RT: Request Tracker.
# RT is (c) Copyright 1996-1999 Jesse Vincent
# RT is distributed under the terms of the GNU General Public License
#
package WebAuth;
#$AuthRealm="Default Realm Name";
require rt::database;
use CGI::Cookie;
&rt::connectdb();

sub AuthCheck () {
    my ($AuthRealm) = @_;
    my ($hash, $Name, $ctx, $Pass,$path, $set_user, $set_pass);
    #lets get the cookies
    
if ($rt::program =~ /nph-/) {

      print "HTTP/1.0 200 Ok\n";
    }
	
    #get the path
    if ($ENV{'SCRIPT_NAME'} =~ m|^(.*)/(.*?)$|) {
      	$path=$1;
	# remove trailing slashes
    	$path =~ s|/+$||;
	}
    


    #lets generate that hash.

  use Digest::MD5;
  $ctx = Digest::MD5->new;
  $ctx->add($rt::ui::web::FORM{'username'});
  $ctx->add($ENV{'REMOTE_ADDR'});
  $ctx->add($rt::ui::web::FORM{'password'});
    $hash = $ctx->hexdigest();
    
   



   
    # lets set the user/pass cookies
    

    if  ( ( length($rt::ui::web::FORM{'username'}) ) and 
	  ( length($rt::ui::web::FORM{'password'}) >= $rt::user_passwd_min) ) {

#if we have a $path to play with...
#not doing this breaks netscape
    if ($path ne '') { 
     
      $set_user = new CGI::Cookie(-name => 'RT_USERNAME',
                                  -value => "$rt::ui::web::FORM{'username'}",
                                  -expires => '+6M',
                                  -path => $path);
      
      $set_password = new CGI::Cookie(-name => 'RT_PASSWORD',
                                      -value =>$hash,
                                      -path => $path);
      
 }
else {
      $set_user = new CGI::Cookie(-name => 'RT_USERNAME',
                                  -value => "$rt::ui::web::FORM{'username'}",
                                  -expires => '+6M');

      $set_password = new CGI::Cookie(-name => 'RT_PASSWORD',
                                      -value =>$hash);

}

      if (($rt::web_auth_cookies_allow_no_path =~ /yes/i) and
	  ($rt::ui::web::FORM{'insecure_path'})) {
      	$set_password =~ s/; path=(.*?); /; /;
      	$set_user =~ s/; path=(.*?); /; /
      } 
       
      print "Set-Cookie: $set_password\n";
      print "Set-Cookie: $set_user\n";   


      
      return( $rt::ui::web::FORM{'username'}, $hash);
    }
    
    #otherwise, we've got cookies.
    elsif (!($rt::ui::web::cookies{'RT_PASSWORD'}) or !($rt::ui::web::cookies{'RT_USERNAME'})) {
      return (undef,undef); 
    }

    else {
      return( $rt::ui::web::cookies{'RT_USERNAME'}->value, $rt::ui::web::cookies{'RT_PASSWORD'}->value );
    }
    
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
  
  # check for existing cookies and kill 'em
  #
  # be carefull here, according to RFC 2109 a cookie can only
  # be deleted, if it has existed before and "Max-Age" (aka expires)
  # is zero. A non-existing cookie with Max-Age 0 is *created* instead
  #
  %cookies = fetch CGI::Cookie;
  if(exists $cookies{'RT_PASSWORD'}) {
    my $path;
    
	$pass_cookie = $cookies{'RT_PASSWORD'};
	$pass_cookie->value('');
 	
    $path = $pass_cookie->path();
    $path =~ s|/$||;
	if ($path ne '') {
    $pass_cookie->path($path);
    }
	print "Set-Cookie: ", $pass_cookie, "\n";

  }

  # comment this, if you want to keep your username (we don't)
  if(exists $cookies{'RT_USERNAME'}) {
    my $path;
    
    $name_cookie = $cookies{'RT_USERNAME'};
	
	$name_cookie->value('');
    $path = $name_cookie->path();
    $path =~ s|/$||;
   if ($path ne '') {
    
		$name_cookie->path($path);	

}
 	print "Set-Cookie: ", $name_cookie, "\n";
 }
  
  &rt::ui::web::header;

  if  ($rt::ui::web::cookies{'RT_USERNAME'}) {
    $default_user =  $rt::ui::web::cookies{'RT_USERNAME'}->value;
    
  }
  if ($ENV{'QUERY_STRING'} ne 'display=Logout') {
	$NewQuery = $ENV{'QUERY_STRING'};
  }
  else {
	$NewQuery= "";
  }
  print "
<TABLE cellpadding=10 cellspacing=0 border=0>
<TR><TD BGCOLOR=\"#cccccc\"><FONT SIZE=\"+2\" COLOR=\"#bb0000\"><b>You are not logged in</b></FONT></TD></TR>
<TR><TD BGCOLOR=\"#eeeeee\">
  This RT Server requires you to log in with your RT username and password.  If you are unsure of your RT username or password, please seek out your local RT administrator.</TD>
</TR>
</TABLE>
    
    <FORM ACTION=\"$rt::ui::web::ScriptURL?$NewQuery\" METHOD=\"POST\">


<CENTER>
      <TABLE CELLPADDING=0 CELLSPACING=0 BORDER=0 BGCOLOR=\"#EEEEEE\">

<TR VALIGN=\"TOP\">
<TD COLSPAN=3>
<TABLE WIDTH=\"100%\" CELLPADDING=10 CELLSPACING=0 BORDER=0>
<TR ALIGN=\"LEFT\">
<TD VALIGN=\"MIDDLE\" BGCOLOR=\"#CCCCCC\">
<b>$AuthRealm Login:</b>
</TD></TR>
</TABLE>
</TD>

 <TD ROWSPAN=\"4\" width=8 bgcolor=\"#ffffff\">
<IMG SRC=\"/webrt/srs.gif\" width=16 height=250 alt=\"\"></TD>
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
<TR><TD align=\"right\" VALIGN=\"TOP\">";
  if ($rt::web_auth_cookies_allow_no_path =~ /yes/i) {
  
print "
<INPUT TYPE=\"CHECKBOX\" name=\"insecure_path\">
</td>
<td ALIGN=\"LEFT\" VALIGN=\"TOP\">
&nbsp;
<font size=\"-1\">
<B>
Send authentication info to all scripts on this server.
</B>
</font>
<br>
<font size=\"-1\">
(If you're having trouble with RT and IE4.01sp1, check here.)
<BR>
<font size=\"-2\" color=\"red\">
&nbsp;On a server with potentially malicious scripts, this could be a security risk.
</font>
<br>";
}
else {
print "&nbsp;</TD><TD>";
}  
print "&nbsp;</td>
<TD ALIGN=\"LEFT\">
<INPUT TYPE=\"SUBMIT\" VALUE=\"Login\">
</TD>
</TR>


<TR VALIGN=\"TOP\">
<TD COLSPAN=3><img src=\"/webrt/sbs.gif\" width=520 height=16 alt=\"\"></TD>
<TD ALIGN=\"LEFT\" BGCOLOR=\"#ffffff\"><img src=\"/webrt/sbc.gif\" width=12 alt=\"\" height=16></TD>
</TR>
</TABLE>
</CENTER>

<br><br>


<TABLE BORDER=0>
<TR><TD>
<A HREF=\"http://fsck.com/projects/rt\"><img border=0 src=\"/webrt/rt.jpeg\" ALT=\"[RT Now!]\"></a>
</TD><TD VALIGN=\"BOTTOM\">

<font size=\"-1\">
This is Request Tracker version $rt::rtversion.<br><br>
Development was initially comissioned by <a href=\"http://www.utopia.com\">Utopia Inc</a>.  Further work has been funded by <a href=\"http://www.leftbank.com\">The Leftbank Operation</a>. and <a href=\"http://www.wesleyan.edu\">Wesleyan University</a>. <a href=\"http://www.arepa.com\">Arepa</a> currently underwrites development of RT.
<br>
This program is redistributable under the terms of the <A HREF=\"http://www.gnu.org/copyleft\"><b>GNU GPL.</b></a>

<br>
Copyright &copy; 1996-1999
<a href=\"http://www.fsck.com/~jesse/\">Jesse Vincent</a>.
</font>
</TD></TR></TABLE>

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



1;

