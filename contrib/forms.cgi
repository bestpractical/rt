#!/usr/bin/perl


#Return-Path: <rwest@sarnoff.com>
#Received: from horked.fsck.com (jesse@localhost [127.0.0.1])
#	by horked.fsck.com (8.8.7/8.8.7) with ESMTP id MAA12918
#	for <jesse@localhost>; Fri, 3 Apr 1998 12:53:03 -0500
#Received: from mail.wesleyan.edu
#	by horked.fsck.com (fetchmail-4.3.2 POP3 run by jrvincent)
#	for <jesse@localhost> (single-drop); Fri Apr  3 12:53:03 1998
#Received: from postoffice.sarnoff.com (postoffice.sarnoff.com [130.33.10.147]) by mail.wesleyan.edu (8.8.6/8.7.3) with ESMTP id MAA18546 for <jrvincent@wesleyan.edu>; Fri, 3 Apr 1998 12:50:00 -0500 (EST)
#Received: from [130.33.15.12] by postoffice.sarnoff.com
#          (Netscape Messaging Server 3.5)  with ESMTP id AAA1314
#          for <jrvincent@wesleyan.edu>; Fri, 3 Apr 1998 12:49:16 -0500
#X-Sender: rwest@postoffice.sarnoff.com
#Message-Id: <v03020907b14ac20abebb@[130.33.15.12]>
#In-Reply-To: <19980402213924.00208@horked.fsck.com>
#Mime-Version: 1.0
#Date: Fri, 3 Apr 1998 12:48:40 -0400
#To: Jesse <jrvincent@mail.wesleyan.edu>
#From: "Richard West" <rwest@sarnoff.com>
#Subject: forms.cgi script
#Content-Type: multipart/mixed; boundary="#============_-1320500337==_============"
#X-UIDL: 29384df84fef6b1f8f561bcd635f9cd3

#--#============_-1320500337==_============
#Content-Type: text/plain; charset="us-ascii"

#Here's a copy of the forms script that I put together.  It doesn't really
#take advantage of all of the options available, such as setting the
#destination queue and setting the date due or priority, but I think the
#basic structure is there and it seems to work well...

#I'm not sure if you would consider it "workable" in the general RT
#environment without some minor changes.

#It is, however, rather easy to configure.  The script dynamically loads in
#the ADMIN-made html forms from the user_forms directory.  Within THOSE
#pages, you can configure whatever information you want.. there could be
#default forms distributed with RT, and the rest is left up to the person
#installing the software.

#I do believe that the forms.cgi script should be tweaked to handle
#date_due, priority, and destination queue.  It shouldn't be hard... I tried
#to make forms.cgi as "generic" as possible without going too overboard.  I
#did steal the template_replace_tokens and template_mail routines from the
#older rt distribution, but, if it were integrated into the RT distribution,
#those could be loaded in as perl modules rather than existing separately in
#the script..

#-Rich

##--============_-1320500337==_============
#Content-Type: text/plain; name="forms.cgi"; charset="us-ascii"
#Content-Disposition: attachment; filename="forms.cgi"


$FORM_LOCATION = "/sc/adm/rt/user_forms";
$MAILPROG = "/usr/lib/sendmail";
$ALIAS = "itd-help\@your.domain.com";
$rtversion = "0.9.11";

# code between the lines was mostly grabbed from form-mail.pl by MIT's "The Tech"
######cut here ###################################################
# Get the input
read(STDIN, $buffer, $ENV{'CONTENT_LENGTH'});
# Split the name-value pairs
if ($buffer) {
    @pairs = split(/&/, $buffer);
}
else {

    @pairs = split(/&/,$ENV{'QUERY_STRING'});
}

foreach $pair (@pairs)
{
    ($name, $value) = split(/=/, $pair);
    # Un-Webify plus signs and %-encoding
    $value =~ tr/+/ /;
    $value =~ s/%([a-fA-F0-9][a-fA-F0-9])/pack("C", hex($1))/eg;
    $value =~ s/&lt/</g;
    $value =~ s/&gt/>/g;
    # Stop people from using subshells to execute commands
    # Not a big deal when using sendmail, but very important
    # when using UCB mail (aka mailx).
    $value =~ s/~!/ ~!/g;
    # Uncomment for debugging purposes
    #print "A gnarled troll tells you that $name was set to $value<br>";
    $FORM{$name} = $value;
}
#### ----cut here

	# Process
	# Variables of the form $FORM{<name here>} are acted upon.
	# They should be of the same name as in the form.

sub FormNewRequest
{
   print "
<FONT size=2>
<FORM METHOD=\"POST\" ACTION=\"$ENV{'SCRIPT_NAME'}\" method=\"post\">
<TABLE width = 100% border = 0>
<TR>

<TD>
Use a handy form :
<SELECT NAME=\"Create_Form\" Size=1>";
%list=&Get_Form_List();
foreach $list (keys %list)
{
   print "<OPTION> $list" if ($FORM{'Create_Form'} ne "$list");
   print "<OPTION SELECTED> $list" if ($FORM{'Create_Form'} eq "$list");
}
print "
</SELECT>
</TD>
<TD>
<input type=\"submit\" value=\"Load Form\">
</TD>

</TR>
</TABLE>
</FORM>
</FONT>";

   $_ = $FORM{'Create_Form'};
   s/ /_/g;
   if ( (!$_) || (/Default/) )
   {
      $command = `cat $FORM_LOCATION/Default.html`;
   }
   else
   {
      if (/New_Account/)
      {
         $command = `cat $FORM_LOCATION/New_Account.html`;
      }
      else
      {
         $command = `cat $FORM_LOCATION/New_WorkStation.html`;
      }
   }
   &show_form;
   return;
}

sub show_form
{
   print "<FORM METHOD=\"POST\" ACTION=\"$ENV{'SCRIPT_NAME'}\">";
   print "$command";
   print "</FORM>";
}

sub Get_Form_List
{
   open (FORMS, "cd $FORM_LOCATION; ls \*.html |") || die "Could not read
forms directory.\n";
   while (<FORMS>)
   {
      chop;
      s/_/ /g;
      ($name) = (split(/.html/,$_))[0];
      $formlist{$name} = 1;
   }
   close(FORMS);
   return (%formlist);
}

sub template_replace_tokens
{
   local ($template, $in_custom_content) = @_;

   $template =~ s/%phone%/$FORM{'phone'}/g;
   $template =~ s/%shoporder%/$FORM{'shoporder'}/g;
   $template =~ s/%newuser%/$FORM{'newuser'}/g;
   $template =~ s/%machine%/$FORM{'machine'}/g;
   $template =~ s/%oldmachine%/$FORM{'oldmachine'}/g;
   $template =~ s/%groups%/$FORM{'groups'}/g;
   $template =~ s/%manager%/$FORM{'manager'}/g;
   $template =~ s/%employeenum%/$FORM{'employeenum'}/g;
   $template =~ s/%primary%/$FORM{'primary'}/g;
   $template =~ s/%room%/$FORM{'room'}/g;
   $template =~ s/%subject%/$FORM('subject'}/g;
   $template =~ s/%content%/$in_custom_content\n/g;

   return ($template);
}

sub template_mail{
    local ($in_template,$in_queue_id, $in_subject, $in_current_user,
$in_custom_content) = @_;
    my ($template);

   $template=&template_read($FORM{'form_name'}, $FORM{'queue_id'});
   $template=&template_replace_tokens($template, $FORM{'content'});

    open (MAIL, "|$MAILPROG -oi -t ") || die "Could not open $MAILPROG\n";

    print  MAIL
"To: $ALIAS
From: $FORM{'username'}
Subject: $FORM{'subject'}
X-Managed-By: Request Tracker ($rtversion)

$template
";
   close (MAIL);

   return("template_mail:Message Sent");
}

sub template_read
{

    local ($in_template, $in_queue) =@_;
    local ($template_content="");


    if (! (-f "$FORM_LOCATION/$in_queue/$in_template"))
    {
        return ("The specified template is missing or inaccessable.\n
($FORM_LOCATION/$in_queue/$in_template)\n However, the custom content which
was supposed to fill the template was:\n %content%");
    }
    open(CONTENT, "$FORM_LOCATION/$in_queue/$in_template");
    while (<CONTENT>)
    {
        $template_content .= $_;
    }
    close (CONTENT);
    return ($template_content);
}

sub main
{
   print "Content-type: text/html\n\n";
   print "<HTML>\n";
   print "<HEAD>\n";
   print "<TITLE>Title</TITLE>\n";
   print "</HEAD>\n";
   print "<SCRIPT LANGUAGE=\"JavaScript\"
SRC=\"/JavaScripts/background.js\"></SCRIPT>";
   print "<BODY>\n";

   if ( $FORM{'Create_Form'} || ($FORM{'display'} eq "Create"))
   {
      if ( !$FORM{'Create_Form'})
      {
         $FORM{'Create_Form'} = "Default";
      }
      &FormNewRequest();
   }
   else
   {
      &template_mail($FORM{'form_name'}, $FORM{'queue'}, $FORM{'subject'},
$FORM{'username'}, $FORM{'content'});
      print "
Your message has been <B>SENT</B>.  Check the
<A HREF=\"http://www.my.domain.com/rt/nph-webrt.cgi\">queue</A>
for further status information on your ticket.";
   }

   print "\n";
   print "<SCRIPT LANGUAGE=\"JavaScript\"
SRC=\"/JavaScripts/footer.js\"></SCRIPT>";
   print "</BODY>";
   print "</HTML>";
}

&main();
exit(0);

#--============_-1320500337==_============--


