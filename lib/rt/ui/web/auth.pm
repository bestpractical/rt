package WebAuth;
#$AuthRealm="Default Realm Name";
require rt::database;
&rt::connectdb();

sub AuthCheck () {
    my ($AuthRealm) = @_;
    my ($Scheme, $Hash, $Unhash, $Name, $Pass);
    if (!$ENV{'HTTP_AUTHORIZATION'}) {
	&AuthForceLogin($AuthRealm);
	exit(0);
    }
    ($Scheme, $Hash)= split (/ /,  $ENV{'HTTP_AUTHORIZATION'});
    
    if ($Scheme ne "Basic") {
	&AuthFail($AuthRealm, "Wrong Authentication Scheme.  We only support the insanely insecure Basic Authentication type.");
	exit(0);
    }
    $Unhash=&decode_base64 ($Hash);
    ($Name, $Pass)=split(/:/,$Unhash);
    return ($Name, $Pass);
}


sub AuthFail () {
    local ($AuthRealm, $AuthError) = @_;
    print "HTTP/1.0 401 Unauthorized -- authentication failed
WWW-Authenticate: Basic realm=\"$AuthRealm\"
Content Type: text/plain

Error $AuthError";


}

sub AuthForceLogout () {
    local ($AuthRealm) = @_;
    print "HTTP/1.0 401 Unauthorized -- authentication failed
WWW-Authenticate: Basic realm=\"$AuthRealm\"
Content Type: text/html

<html><head><title>Logged out</title></head><body bgcolor=\"#ffffff\"><center><TABLE WIDTH=\"80%\" border=0 cellpadding=20><TR><TD>You have been logged out of RT.  To log back in, please click <a HREF=\"$rt::ui::web::ScriptURL\"> here.</a>
</TD></TR></TABLE></center></body></html>
";

}                           
sub AuthForceLogin () {
    local ($AuthRealm) = @_;
    print "HTTP/1.0 401 Unauthorized -- authentication failed
WWW-Authenticate: Basic realm=\"$AuthRealm\"
Content Type: text/plain

This RT Server requires you to log in with your RT username and password.  If you are unsure of your RT username or password, please seek out your local RT administrator.
";
    
}
sub Headers_Authenticated(){
    local ($Name, $Pass)= @_;
    print "HTTP/1.0 200 Ok
";
}





# Base 64 decoder ripped from libwww-perl 5.0.6
#
#
#=head1 COPYRIGHT
#
#Copyright 1995, 1996 Gisle Aas.
#
#This library is free software; you can redistribute it and/or
#modify it under the same terms as Perl itself.
#
#=head1 AUTHOR
#
#Gisle Aas <aas@sn.no>
#
#Based on LWP::Base64 written by Martijn Koster <m.koster@nexor.co.uk>
#and Joerg Reichelt <j.reichelt@nexor.co.uk> and code posted to
#comp.lang.perl <3pd2lp$6gf@wsinti07.win.tue.nl> by Hans Mulder
#<hansm@wsinti07.win.tue.nl>
#
#=cut                      

sub decode_base64 ()
{
    local ($str) = "@_";
    local ($res, $len) = "";
    local($^W) = 0; # unpack("u",...) gives bogus warning in 5.00[123]


    $str =~ tr|A-Za-z0-9+=/||cd;            # remove non-base64 chars
    Carp::croak("Base64 decoder requires string length to be a multiple of 4")
      if length($str) % 4;
    $str =~ s/=+$//;                        # remove padding
    $str =~ tr|A-Za-z0-9+/| -_|;            # convert to uuencoded format
    while ($str =~ /(.{1,60})/gs) {
        $len = chr(32 + length($1)*3/4); # compute length byte
        $res .= unpack("u", $len . $1 );    # uudecode
    }
    return ($res);
}

1;
