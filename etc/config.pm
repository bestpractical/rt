    # This is where RT's preferences are kept track of
    # Since RT runs with taint checks in place, we need to specify
    # a path explicitly.  Unless sendmail is installed elsewhere,
    # there should be no need to change it


    #Where you keep you transaction texts
    $transaction_dir="!!RT_TRANSACTIONS_PATH!!";

    #Where you're sticking the glimpse index files;
    $glimpse_dir= "!!RT_GLIMPSE_PATH!!|";

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
    $rtpass="!!RT_MYSQL_PASS!!";


    #name of RT installation
    #rt will look for this string in the headers of incoming mail
    #once you set it, you should NEVER change it.
    # (if you do, users will have no end to problems with their old
    #tickets getting new requests opened for them)

    $rtname="!!RT_MAIL_TAG!!";  
 

    # host is the fqdn of your Mysql server
    # if it's on localhost, leave it blank for enhanced performance
    $host="!!RT_MYSQL_HOST!!";
    
    #$dbname is the name of the RT's database on the Mysql server 
    $dbname="!!RT_MYSQL_DATABASE!!";

    #$mysql_version determines the order the rt username and password
    #are passed to mysqlperl.  it changed between 3.20 and 3.21

    $mysql_version="!!MYSQL_VERSION!!";

    #$mail_alias is a generic alias to send mail to for any request
    #already in a queue because of the nature of RT, mail sent to any
    #correspondence address will get put in the right place and mail sent
    #to any comment address will also get sent to the right place.  The
    #queue_dependent ones are only really important for assigning new
    #requests to the correct queue
    #This is the address that will be listed in From: and Reply-To:
    #headers of mail tracked by RT

    $mail_alias = "!!RT_MAIL_ALIAS!!";


    #set this to whatever program you want to send the mail that RT generates
    #be aware, however, that RT expects to be able to set the From: line
    #with sendmail's command line syntax
    $mailprog = "!!MAIL_PROG!!";
    $mail_options = "!!MAIL_OPTIONS";


    #glimpse_index is where you keep the glimpseindex binary
    #set it to null if you don't have glimpse
    $glimpse_index = "!!GLIMPSE_INDEX!!";


1;
