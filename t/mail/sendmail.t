#!/usr/bin/perl -w

use strict;
use File::Spec ();

use RT::Test tests => 137;

use RT::EmailParser;
use RT::Tickets;
use RT::Action::SendEmail;

my @_outgoing_messages;
my @scrips_fired;

#We're not testing acls here.
my $everyone = RT::Group->new($RT::SystemUser);
$everyone->LoadSystemInternalGroup('Everyone');
$everyone->PrincipalObj->GrantRight( Right =>'SuperUser' );


is (__PACKAGE__, 'main', "We're operating in the main package");

{
    no warnings qw/redefine/;
    sub RT::Action::SendEmail::SendMessage {
        my $self = shift;
        my $MIME = shift;

        main::_fired_scrip($self->ScripObj);
        main::is(ref($MIME) , 'MIME::Entity', "hey, look. it's a mime entity");
    }
}

# some utils
sub first_txn    { return $_[0]->Transactions->First }
sub first_attach { return first_txn($_[0])->Attachments->First }

sub count_txns { return $_[0]->Transactions->Count }
sub count_attachs { return first_txn($_[0])->Attachments->Count }

# instrument SendEmail to pass us what it's about to send.
# create a regular ticket

my $parser = RT::EmailParser->new();

# Let's test to make sure a multipart/report is processed correctly
my $multipart_report_email = RT::Test::get_relocatable_file('multipart-report',
    (File::Spec->updir(), 'data', 'emails'));
my $content =  RT::Test->file_content($multipart_report_email);
# be as much like the mail gateway as possible.
use RT::Interface::Email;
my %args =        (message => $content, queue => 1, action => 'correspond');
my ($status, $msg) = RT::Interface::Email::Gateway(\%args);
ok($status, "successfuly used Email::Gateway interface") or diag("error: $msg");
my $tickets = RT::Tickets->new($RT::SystemUser);
$tickets->OrderBy(FIELD => 'id', ORDER => 'DESC');
$tickets->Limit(FIELD => 'id' ,OPERATOR => '>', VALUE => '0');
my $tick= $tickets->First();
isa_ok($tick, "RT::Ticket", "got a ticket object");
ok ($tick->Id, "found ticket ".$tick->Id);
like (first_txn($tick)->Content , qr/The original message was received/, "It's the bounce");


# make sure it fires scrips.
is ($#scrips_fired, 1, "Fired 2 scrips on ticket creation");

undef @scrips_fired;




$parser->ParseMIMEEntityFromScalar('From: root@localhost
To: rt@example.com
Subject: This is a test of new ticket creation as an unknown user

Blah!
Foob!');

                                  
use Data::Dumper;

my $ticket = RT::Ticket->new($RT::SystemUser);
my  ($id,  undef, $create_msg ) = $ticket->Create(Requestor => ['root@localhost'], Queue => 'general', Subject => 'I18NTest', MIMEObj => $parser->Entity);
ok ($id,$create_msg);
$tickets = RT::Tickets->new($RT::SystemUser);
$tickets->OrderBy(FIELD => 'id', ORDER => 'DESC');
$tickets->Limit(FIELD => 'id' ,OPERATOR => '>', VALUE => '0');
 $tick = $tickets->First();
ok ($tick->Id, "found ticket ".$tick->Id);
is ($tick->Subject , 'I18NTest', "failed to create the new ticket from an unprivileged account");

# make sure it fires scrips.
is ($#scrips_fired, 1, "Fired 2 scrips on ticket creation");
# make sure it sends an autoreply
# make sure it sends a notification to adminccs


# we need to swap out SendMessage to test the new things we care about;
&utf8_redef_sendmessage;

# create an iso 8859-1 ticket
@scrips_fired = ();

my $iso_8859_1_ticket_email = RT::Test::get_relocatable_file(
    'new-ticket-from-iso-8859-1', (File::Spec->updir(), 'data', 'emails'));
$content =  RT::Test->file_content($iso_8859_1_ticket_email);



$parser->ParseMIMEEntityFromScalar($content);


# be as much like the mail gateway as possible.
use RT::Interface::Email;
                           
 %args =        (message => $content, queue => 1, action => 'correspond');
 RT::Interface::Email::Gateway(\%args);
 $tickets = RT::Tickets->new($RT::SystemUser);
$tickets->OrderBy(FIELD => 'id', ORDER => 'DESC');
$tickets->Limit(FIELD => 'id' ,OPERATOR => '>', VALUE => '0');
 $tick = $tickets->First();
ok ($tick->Id, "found ticket ".$tick->Id);

like (first_txn($tick)->Content , qr/H\x{e5}vard/, "It's signed by havard. yay");


# make sure it fires scrips.
is ($#scrips_fired, 1, "Fired 2 scrips on ticket creation");
# make sure it sends an autoreply


# make sure it sends a notification to adminccs

# If we correspond, does it do the right thing to the outbound messages?

$parser->ParseMIMEEntityFromScalar($content);
  ($id, $msg) = $tick->Comment(MIMEObj => $parser->Entity);
ok ($id, $msg);

$parser->ParseMIMEEntityFromScalar($content);
($id, $msg) = $tick->Correspond(MIMEObj => $parser->Entity);
ok ($id, $msg);





# we need to swap out SendMessage to test the new things we care about;
&iso8859_redef_sendmessage;
RT->Config->Set( EmailOutputEncoding => 'iso-8859-1' );
# create an iso 8859-1 ticket
@scrips_fired = ();

 $content =  RT::Test->file_content($iso_8859_1_ticket_email);
# be as much like the mail gateway as possible.
use RT::Interface::Email;
                                  
 %args =        (message => $content, queue => 1, action => 'correspond');
 RT::Interface::Email::Gateway(\%args);
$tickets = RT::Tickets->new($RT::SystemUser);
$tickets->OrderBy(FIELD => 'id', ORDER => 'DESC');
$tickets->Limit(FIELD => 'id' ,OPERATOR => '>', VALUE => '0');
 $tick = $tickets->First();
ok ($tick->Id, "found ticket ".$tick->Id);

like (first_txn($tick)->Content , qr/H\x{e5}vard/, "It's signed by havard. yay");


# make sure it fires scrips.
is ($#scrips_fired, 1, "Fired 2 scrips on ticket creation");
# make sure it sends an autoreply


# make sure it sends a notification to adminccs


# If we correspond, does it do the right thing to the outbound messages?

$parser->ParseMIMEEntityFromScalar($content);
 ($id, $msg) = $tick->Comment(MIMEObj => $parser->Entity);
ok ($id, $msg);

$parser->ParseMIMEEntityFromScalar($content);
($id, $msg) = $tick->Correspond(MIMEObj => $parser->Entity);
ok ($id, $msg);


sub _fired_scrip {
        my $scrip = shift;
        push @scrips_fired, $scrip;
}       

sub utf8_redef_sendmessage {
    no warnings qw/redefine/;
    eval ' 
    sub RT::Action::SendEmail::SendMessage {
        my $self = shift;
        my $MIME = shift;

        my $scrip = $self->ScripObj->id;
        ok(1, $self->ScripObj->ConditionObj->Name . " ".$self->ScripObj->ActionObj->Name);
        main::_fired_scrip($self->ScripObj);
        $MIME->make_singlepart;
        main::is( ref($MIME) , \'MIME::Entity\',
                  "hey, look. it\'s a mime entity" );
        main::is( ref( $MIME->head ) , \'MIME::Head\',
                  "its mime header is a mime header. yay" );
        main::like( $MIME->head->get(\'Content-Type\') , qr/utf-8/,
                  "Its content type is utf-8" );
        my $message_as_string = $MIME->bodyhandle->as_string();
        use Encode;
        $message_as_string = Encode::decode_utf8($message_as_string);
        main::like(
            $message_as_string , qr/H\x{e5}vard/,
"The message\'s content contains havard\'s name. this will fail if it\'s not utf8 out");

    }';
}

sub iso8859_redef_sendmessage {
    no warnings qw/redefine/;
    eval ' 
    sub RT::Action::SendEmail::SendMessage {
        my $self = shift;
        my $MIME = shift;

        my $scrip = $self->ScripObj->id;
        ok(1, $self->ScripObj->ConditionObj->Name . " ".$self->ScripObj->ActionObj->Name);
        main::_fired_scrip($self->ScripObj);
        $MIME->make_singlepart;
        main::is( ref($MIME) , \'MIME::Entity\',
                  "hey, look. it\'s a mime entity" );
        main::is( ref( $MIME->head ) , \'MIME::Head\',
                  "its mime header is a mime header. yay" );
        main::like( $MIME->head->get(\'Content-Type\') , qr/iso-8859-1/,
                  "Its content type is iso-8859-1 - " . $MIME->head->get("Content-Type") );
        my $message_as_string = $MIME->bodyhandle->as_string();
        use Encode;
        $message_as_string = Encode::decode("iso-8859-1",$message_as_string);
        main::like(
            $message_as_string , qr/H\x{e5}vard/, "The message\'s content contains havard\'s name. this will fail if it\'s not utf8 out");

    }';
}

# {{{ test a multipart alternative containing a text-html part with an umlaut

 my $alt_umlaut_email = RT::Test::get_relocatable_file(
     'multipart-alternative-with-umlaut', (File::Spec->updir(), 'data', 'emails'));
 $content =  RT::Test->file_content($alt_umlaut_email);

$parser->ParseMIMEEntityFromScalar($content);


# be as much like the mail gateway as possible.
{
    no warnings qw/redefine/;
    local *RT::Action::SendEmail::SendMessage = sub { return 1};

    %args = (message => $content, queue => 1, action => 'correspond');
    RT::Interface::Email::Gateway(\%args);
    # TODO: following 5 lines should replaced by get_latest_ticket_ok()
    $tickets = RT::Tickets->new($RT::SystemUser);
    $tickets->OrderBy(FIELD => 'id', ORDER => 'DESC');
    $tickets->Limit(FIELD => 'id' ,OPERATOR => '>', VALUE => '0');
    $tick = $tickets->First();

    ok ($tick->Id, "found ticket ".$tick->Id);

    like (first_txn($tick)->Content , qr/causes Error/, "We recorded the content right as text-plain");
    is (count_attachs($tick) , 3 , "Has three attachments, presumably a text-plain, a text-html and a multipart alternative");

}

# }}}

# {{{ test a text-html message with an umlaut
 my $text_html_email = RT::Test::get_relocatable_file('text-html-with-umlaut',
     (File::Spec->updir(), 'data', 'emails'));
 $content =  RT::Test->file_content($text_html_email);

$parser->ParseMIMEEntityFromScalar($content);


# be as much like the mail gateway as possible.
&text_html_redef_sendmessage;

 %args =        (message => $content, queue => 1, action => 'correspond');
 RT::Interface::Email::Gateway(\%args);
 $tickets = RT::Tickets->new($RT::SystemUser);
$tickets->OrderBy(FIELD => 'id', ORDER => 'DESC');
$tickets->Limit(FIELD => 'id' ,OPERATOR => '>', VALUE => '0');
 $tick = $tickets->First();
ok ($tick->Id, "found ticket ".$tick->Id);

like (first_attach($tick)->Content , qr/causes Error/, "We recorded the content as containing 'causes error'") or diag( first_attach($tick)->Content );
like (first_attach($tick)->ContentType , qr/text\/html/, "We recorded the content as text/html");
is (count_attachs($tick), 1 , "Has one attachment, presumably a text-html and a multipart alternative");

sub text_html_redef_sendmessage {
    no warnings qw/redefine/;
    eval 'sub RT::Action::SendEmail::SendMessage { 
                my $self = shift;
                my $MIME = shift;
                return (1) unless ($self->ScripObj->ScripActionObj->Name eq "Notify AdminCcs" );
                is ($MIME->parts, 0, "generated correspondence mime entity
                        does not have parts");
                is ($MIME->head->mime_type , "text/plain", "The mime type is a plain");
         }';
}

# }}}

# {{{ test a text-html message with russian characters
 my $russian_email = RT::Test::get_relocatable_file('text-html-in-russian',
     (File::Spec->updir(), 'data', 'emails'));
 $content =  RT::Test->file_content($russian_email);

$parser->ParseMIMEEntityFromScalar($content);


# be as much like the mail gateway as possible.
&text_html_redef_sendmessage;

 %args =        (message => $content, queue => 1, action => 'correspond');
 RT::Interface::Email::Gateway(\%args);
 $tickets = RT::Tickets->new($RT::SystemUser);
$tickets->OrderBy(FIELD => 'id', ORDER => 'DESC');
$tickets->Limit(FIELD => 'id' ,OPERATOR => '>', VALUE => '0');
 $tick = $tickets->First();
ok ($tick->Id, "found ticket ".$tick->Id);

like (first_attach($tick)->ContentType , qr/text\/html/, "We recorded the content right as text-html");

is (count_attachs($tick) ,1 , "Has one attachment, presumably a text-html and a multipart alternative");

# }}}

# {{{ test a message containing a russian subject and NO content type

RT->Config->Set( EmailInputEncodings => 'koi8-r', RT->Config->Get('EmailInputEncodings') );
RT->Config->Set( EmailOutputEncoding => 'koi8-r' );
my $russian_subject_email = RT::Test::get_relocatable_file(
    'russian-subject-no-content-type', (File::Spec->updir(), 'data', 'emails'));
$content = RT::Test->file_content($russian_subject_email);

$parser->ParseMIMEEntityFromScalar($content);


# be as much like the mail gateway as possible.
&text_plain_russian_redef_sendmessage;
 %args =        (message => $content, queue => 1, action => 'correspond');
 RT::Interface::Email::Gateway(\%args);
 $tickets = RT::Tickets->new($RT::SystemUser);
$tickets->OrderBy(FIELD => 'id', ORDER => 'DESC');
$tickets->Limit(FIELD => 'id' ,OPERATOR => '>', VALUE => '0');
$tick= $tickets->First();
ok ($tick->Id, "found ticket ".$tick->Id);

like (first_attach($tick)->ContentType , qr/text\/plain/, "We recorded the content type right");
is (count_attachs($tick) ,1 , "Has one attachment, presumably a text-plain");
is ($tick->Subject, "\x{442}\x{435}\x{441}\x{442} \x{442}\x{435}\x{441}\x{442}", "Recorded the subject right");
sub text_plain_russian_redef_sendmessage {
    no warnings qw/redefine/;
    eval 'sub RT::Action::SendEmail::SendMessage { 
                my $self = shift; 
                my $MIME = shift; 
                return (1) unless ($self->ScripObj->ScripActionObj->Name eq "Notify AdminCcs" );
                is ($MIME->head->mime_type , "text/plain", "The only part is text/plain ");
                 my $subject  = $MIME->head->get("subject");
                chomp($subject);
                #is( $subject ,      /^=\?KOI8-R\?B\?W2V4YW1wbGUuY39tICM3XSDUxdPUINTF09Q=\?=/ , "The $subject is encoded correctly");
                };
                 ';
}

my @input_encodings = RT->Config->Get( 'EmailInputEncodings' );
shift @input_encodings;
RT->Config->Set(EmailInputEncodings => @input_encodings );
RT->Config->Set(EmailOutputEncoding => 'utf-8');
# }}}


# {{{ test a message containing a nested RFC 822 message

my $nested_rfc822_email = RT::Test::get_relocatable_file('nested-rfc-822',
    (File::Spec->updir(), 'data', 'emails'));
$content =  RT::Test->file_content($nested_rfc822_email);
ok ($content, "Loaded nested-rfc-822 to test");

$parser->ParseMIMEEntityFromScalar($content);


# be as much like the mail gateway as possible.
&text_plain_nested_redef_sendmessage;
 %args =        (message => $content, queue => 1, action => 'correspond');
 RT::Interface::Email::Gateway(\%args);
 $tickets = RT::Tickets->new($RT::SystemUser);
$tickets->OrderBy(FIELD => 'id', ORDER => 'DESC');
$tickets->Limit(FIELD => 'id' ,OPERATOR => '>', VALUE => '0');
$tick= $tickets->First();
ok ($tick->Id, "found ticket ".$tick->Id);
is ($tick->Subject, "[Jonas Liljegren] Re: [Para] Niv\x{e5}er?");
like (first_attach($tick)->ContentType , qr/multipart\/mixed/, "We recorded the content type right");
is (count_attachs($tick) , 5 , "Has one attachment, presumably a text-plain and a message RFC 822 and another plain");
sub text_plain_nested_redef_sendmessage {
    no warnings qw/redefine/;
    eval 'sub RT::Action::SendEmail::SendMessage { 
                my $self = shift; 
                my $MIME = shift; 
                return (1) unless ($self->ScripObj->ScripActionObj->Name eq "Notify AdminCcs" );
                is ($MIME->head->mime_type , "multipart/mixed", "It is a mixed multipart");
                 my $subject  =  $MIME->head->get("subject");
                 $subject  = MIME::Base64::decode_base64( $subject);
                chomp($subject);
                # TODO, why does this test fail
                #ok($subject =~ qr{Niv\x{e5}er}, "The subject matches the word - $subject");
                1;
                 }';
}

# }}}


# {{{ test a multipart alternative containing a uuencoded mesage generated by lotus notes

 my $uuencoded_email = RT::Test::get_relocatable_file('notes-uuencoded',
     (File::Spec->updir(), 'data', 'emails'));
 $content =  RT::Test->file_content($uuencoded_email);

$parser->ParseMIMEEntityFromScalar($content);


# be as much like the mail gateway as possible.
{
    no warnings qw/redefine/;
    local *RT::Action::SendEmail::SendMessage = sub { return 1};
    %args =        (message => $content, queue => 1, action => 'correspond');
    RT::Interface::Email::Gateway(\%args);
    $tickets = RT::Tickets->new($RT::SystemUser);
    $tickets->OrderBy(FIELD => 'id', ORDER => 'DESC');
    $tickets->Limit(FIELD => 'id' ,OPERATOR => '>', VALUE => '0');
    $tick= $tickets->First();
    ok ($tick->Id, "found ticket ".$tick->Id);

    like (first_txn($tick)->Content , qr/from Lotus Notes/, "We recorded the content right");
    is (count_attachs($tick) , 3 , "Has three attachments");
}

# }}}

# {{{ test a multipart that crashes the file-based mime-parser works

 my $crashes_file_based_parser_email = RT::Test::get_relocatable_file(
     'crashes-file-based-parser', (File::Spec->updir(), 'data', 'emails'));
 $content = RT::Test->file_content($crashes_file_based_parser_email);

$parser->ParseMIMEEntityFromScalar($content);


# be as much like the mail gateway as possible.

no warnings qw/redefine/;
local *RT::Action::SendEmail::SendMessage = sub { return 1};
 %args =        (message => $content, queue => 1, action => 'correspond');
 RT::Interface::Email::Gateway(\%args);
 $tickets = RT::Tickets->new($RT::SystemUser);
$tickets->OrderBy(FIELD => 'id', ORDER => 'DESC');
$tickets->Limit(FIELD => 'id' ,OPERATOR => '>', VALUE => '0');
$tick= $tickets->First();
ok ($tick->Id, "found ticket ".$tick->Id);

like (first_txn($tick)->Content , qr/FYI/, "We recorded the content right");
is (count_attachs($tick) , 5 , "Has three attachments");




# }}}

# {{{ test a multi-line RT-Send-CC header

 my $rt_send_cc_email = RT::Test::get_relocatable_file('rt-send-cc',
     (File::Spec->updir(), 'data', 'emails'));
 $content =  RT::Test->file_content($rt_send_cc_email);

$parser->ParseMIMEEntityFromScalar($content);



 %args =        (message => $content, queue => 1, action => 'correspond');
 RT::Interface::Email::Gateway(\%args);
 $tickets = RT::Tickets->new($RT::SystemUser);
$tickets->OrderBy(FIELD => 'id', ORDER => 'DESC');
$tickets->Limit(FIELD => 'id' ,OPERATOR => '>', VALUE => '0');
$tick= $tickets->First();
ok ($tick->Id, "found ticket ".$tick->Id);

my $cc = first_attach($tick)->GetHeader('RT-Send-Cc');
like ($cc , qr/test1/, "Found test 1");
like ($cc , qr/test2/, "Found test 2");
like ($cc , qr/test3/, "Found test 3");
like ($cc , qr/test4/, "Found test 4");
like ($cc , qr/test5/, "Found test 5");

# }}}

diag q{regression test for #5248 from rt3.fsck.com} if $ENV{TEST_VERBOSE};
{
    my $subject_folding_email = RT::Test::get_relocatable_file(
        'subject-with-folding-ws', (File::Spec->updir(), 'data', 'emails'));
    my $content = RT::Test->file_content($subject_folding_email);
    my ($status, $msg, $ticket) = RT::Interface::Email::Gateway(
        { message => $content, queue => 1, action => 'correspond' }
    );
    ok ($status, 'created ticket') or diag "error: $msg";
    ok ($ticket->id, "found ticket ". $ticket->id);
    is ($ticket->Subject, 'test', 'correct subject');
}

diag q{regression test for #5248 from rt3.fsck.com} if $ENV{TEST_VERBOSE};
{
    my $long_subject_email = RT::Test::get_relocatable_file('very-long-subject',
        (File::Spec->updir(), 'data', 'emails'));
    my $content = RT::Test->file_content($long_subject_email);
    my ($status, $msg, $ticket) = RT::Interface::Email::Gateway(
        { message => $content, queue => 1, action => 'correspond' }
    );
    ok ($status, 'created ticket') or diag "error: $msg";
    ok ($ticket->id, "found ticket ". $ticket->id);
    is ($ticket->Subject, '0123456789'x20, 'correct subject');
}



# Don't taint the environment
$everyone->PrincipalObj->RevokeRight(Right =>'SuperUser');
1;
