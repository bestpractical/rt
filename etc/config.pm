    # This is where RT's preferences are kept track of
    # Since RT runs with taint checks in place, we need to specify
    # a path explicitly.  Unless sendmail is installed elsewhere,
    # there should be no need to change it


    #Where you keep you transaction texts
    $transaction_dir="!!RT_TRANSACTIONS_PATH!!";

    #Where you keep templates for each of your queues
    $template_dir="!!RT_TEMPLATE_PATH!!";


    # these modes don't do much right now...i had to hard code them in because 
    # perl ws being nasty about the leading 0  check RT_Content.pl for hacking
    $dirmode="0700";
    $transactionmode="0700";
    umask(0700);
	
    # rt runs setuid to this user and group to keep its datafile private
    # no users should be in the rt group
    # if you change these, make sure to edit the makefile and
    # to chown the rt directory structure
    $rtuser="!!RTUSER!!";
    $rtgroup="!!RTGROUP!!";


    # before doing a "make install" in /usr/local/rt/src you NEED to change the 
    # password below and change the apropriate line in /usr/local/rt/etc/mysql.acl	
    $rtpass="!!RT_DB_PASS!!";


    #name of RT installation
    #rt will look for this string in the headers of incoming mail
    #once you set it, you should NEVER change it.
    # (if you do, users will have no end to problems with their old
    #tickets getting new requests opened for them)

    $rtname="!!RT_MAIL_TAG!!";  
 

    # host is the fqdn of your Mysql server
    # if it's on localhost, leave it blank for enhanced performance
    $host="!!RT_DB_HOST!!";
    
    #$dbname is the name of the RT's database on the Mysql server 
    $dbname="!!RT_DATABASE!!";

    # $rt_db is the database driver beeing used - i.e. MySQL.
    $rt_db="!!RT_DB!!";

    #$mysql_version determines the order the rt username and password
    #are passed to mysqlperl.  it changed between 3.20 and 3.21

    $mysql_version="!!MYSQL_VERSION!!";

    # $passwd_min defines the minimum length for user passwords.
    $user_passwd_min = "!!RT_USER_PASSWD_MIN!!";

    #$mail_alias is a generic alias to send mail to for any request
    #already in a queue because of the nature of RT, mail sent to any
    #correspondence address will get put in the right place and mail sent
    #to any comment address will also get sent to the right place.  The
    #queue_dependent ones are only really important for assigning new
    #requests to the correct queue
    #This is the address that will be listed in From: and Reply-To:
    #headers of mail tracked by RT

    $mail_alias = "!!RT_MAIL_ALIAS!!";


    # (TODO) Internet::Mail might need some configuration.


    # WEB_AUTH_MECHANISM defines what sort of authentication you'd like to use
    # for the web ui.  Valid choices are: "cookies" and "external".  Cookies
    # uses http cookies to keep track of authentication. External means that
    # you will have configured your web server to prompt for the user's
    # credentials and authenticate them before RT ever sees the request.
    
    $web_auth_mechanism = "!!WEB_AUTH_MECHANISM!!";
    
    
    
    
    # WEB_AUTH_COOKIES_ALLOW_NO_PATH allows RT users to check a box which sends
    # their authentication cookies to any CGI on the server.  This could be a
    # security hole. You'll _never_ want to enable it, unless you have clients
    # with IE4.01sp1..which chokes unless this is enabled.
    
    $web_auth_cookies_allow_no_path = "!!WEB_AUTH_COOKIES_ALLOW_NO_PATH!!";

1;
