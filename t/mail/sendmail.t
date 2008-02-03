#!/usr/bin/perl -w

use strict;
use RT::Test; use Test::More tests => 131;



use RT::EmailParser;
use RT::Model::TicketCollection;
use RT::ScripAction::SendEmail;

my @_outgoing_messages;
my @scrips_fired;

#Were not testing acls here.
my $everyone = RT::Model::Group->new(current_user => RT->system_user);
$everyone->load_system_internal_group('Everyone');
$everyone->principal_object->grant_right( right =>'SuperUser' );


is (__PACKAGE__, 'main', "We're operating in the main package");

{
    no warnings qw/redefine/;
    sub RT::ScripAction::SendEmail::send_message {
        my $self = shift;
        my $MIME = shift;

        main::_fired_scrip($self->scrip_obj);
        main::is(ref($MIME) , 'MIME::Entity', "hey, look. it's a mime entity");
    }
}

# some utils
sub first_txn    { return $_[0]->transactions->first }
sub first_attach { return first_txn($_[0])->attachments->first }

sub count_txns { return $_[0]->transactions->count }
sub count_attachs { return first_txn($_[0])->attachments->count }

# instrument SendEmail to pass us what it's about to send.
# create a regular ticket

my $parser = RT::EmailParser->new(current_user => RT->system_user);


# Let's test to make sure a multipart/report is processed correctly
my $content =  RT::Test->file_content("$RT::BASE_PATH/lib/t/data/multipart-report");
# be as much like the mail gateway as possible.
use RT::Interface::Email;
my %args =        (message => $content, queue => 1, action => 'correspond');
my ($status, $msg) = RT::Interface::Email::gateway(\%args);
ok($status, "successfuly used Email::gateway interface") or diag("error: $msg");
my $tickets = RT::Model::TicketCollection->new(current_user => RT->system_user);
$tickets->order_by({column => 'id', order => 'DESC'});
$tickets->limit(column => 'id' ,operator => '>', value => '0');
my $tick= $tickets->first();
isa_ok($tick, "RT::Model::Ticket", "got a ticket object");
ok ($tick->id, "found ticket ".$tick->id);
like (first_txn($tick)->content , qr/The original message was received/, "It's the bounce");


# make sure it fires scrips.
is ($#scrips_fired, 1, "Fired 2 scrips on ticket creation");

undef @scrips_fired;




$parser->parse_mime_entity_from_scalar('From: root@localhost
To: rt@example.com
Subject: This is a test of new ticket creation as an unknown user

Blah!
Foob!');

                                  
use Data::Dumper;

my $ticket = RT::Model::Ticket->new(current_user => RT->system_user);
my  ($id,  undef, $create_msg ) = $ticket->create(requestor => ['root@localhost'], queue => 'general', subject => 'I18NTest', mime_obj => $parser->entity);
ok ($id,$create_msg);
$tickets = RT::Model::TicketCollection->new(current_user => RT->system_user);
$tickets->order_by({column => 'id', order => 'DESC'});

$tickets->limit(column => 'id' ,operator => '>', value => '0');
 $tick = $tickets->first();
ok ($tick->id, "found ticket ".$tick->id);
is ($tick->subject , 'I18NTest', "failed to create the new ticket from an unprivileged account");

# make sure it fires scrips.
is ($#scrips_fired, 1, "Fired 2 scrips on ticket creation");
# make sure it sends an autoreply
# make sure it sends a notification to adminccs


# we need to swap out send_message to test the new things we care about;
&utf8_redef_sendmessage;

# create an iso 8859-1 ticket
@scrips_fired = ();

$content =  RT::Test->file_content("$RT::BASE_PATH/lib/t/data/new-ticket-from-iso-8859-1");



$parser->parse_mime_entity_from_scalar($content);


# be as much like the mail gateway as possible.
use RT::Interface::Email;
                           
 %args =        (message => $content, queue => 1, action => 'correspond');
 RT::Interface::Email::gateway(\%args);
 $tickets = RT::Model::TicketCollection->new(current_user => RT->system_user);
$tickets->order_by({column => 'id', order => 'DESC'});
$tickets->limit(column => 'id' ,operator => '>', value => '0');
 $tick = $tickets->first();
ok ($tick->id, "found ticket ".$tick->id);

like (first_txn($tick)->content , qr/H\x{e5}vard/, "It's signed by havard. yay");


# make sure it fires scrips.
is ($#scrips_fired, 1, "Fired 2 scrips on ticket creation");
# make sure it sends an autoreply


# make sure it sends a notification to adminccs

# If we correspond, does it do the right thing to the outbound messages?

$parser->parse_mime_entity_from_scalar($content);
  ($id, $msg) = $tick->comment(mime_obj => $parser->entity);
ok ($id, $msg);

$parser->parse_mime_entity_from_scalar($content);
($id, $msg) = $tick->correspond(mime_obj => $parser->entity);
ok ($id, $msg);





# we need to swap out send_message to test the new things we care about;
&iso8859_redef_sendmessage;
RT->config->set( EmailOutputEncoding => 'iso-8859-1' );
# create an iso 8859-1 ticket
@scrips_fired = ();

 $content =  RT::Test->file_content("$RT::BASE_PATH/lib/t/data/new-ticket-from-iso-8859-1");
# be as much like the mail gateway as possible.
use RT::Interface::Email;
                                  
 %args =        (message => $content, queue => 1, action => 'correspond');
 RT::Interface::Email::gateway(\%args);
$tickets = RT::Model::TicketCollection->new(current_user => RT->system_user);
$tickets->order_by({column => 'id', order => 'DESC'});
$tickets->limit(column => 'id' ,operator => '>', value => '0');
 $tick = $tickets->first();
ok ($tick->id, "found ticket ".$tick->id);

like (first_txn($tick)->content , qr/H\x{e5}vard/, "It's signed by havard. yay");


# make sure it fires scrips.
is ($#scrips_fired, 1, "Fired 2 scrips on ticket creation");
# make sure it sends an autoreply


# make sure it sends a notification to adminccs


# If we correspond, does it do the right thing to the outbound messages?

$parser->parse_mime_entity_from_scalar($content);
 ($id, $msg) = $tick->comment(mime_obj => $parser->entity);
ok ($id, $msg);

$parser->parse_mime_entity_from_scalar($content);
($id, $msg) = $tick->correspond(mime_obj => $parser->entity);
ok ($id, $msg);


sub _fired_scrip {
        my $scrip = shift;
        push @scrips_fired, $scrip;
}       

sub utf8_redef_sendmessage {
    no warnings qw/redefine/;
    eval ' 
    sub RT::ScripAction::SendEmail::send_message {
        my $self = shift;
        my $MIME = shift;

        my $scrip = $self->scrip_obj->id;
        ok(1, $self->scrip_obj->condition_obj->name . " ".$self->scrip_obj->action_obj->name);
        main::_fired_scrip($self->scrip_obj);
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
    sub RT::ScripAction::SendEmail::send_message {
        my $self = shift;
        my $MIME = shift;

        my $scrip = $self->scrip_obj->id;
        ok(1, $self->scrip_obj->condition_obj->name . " ".$self->scrip_obj->action_obj->name);
        main::_fired_scrip($self->scrip_obj);
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

 $content =  RT::Test->file_content("$RT::BASE_PATH/lib/t/data/multipart-alternative-with-umlaut");

$parser->parse_mime_entity_from_scalar($content);


# be as much like the mail gateway as possible.
{
    no warnings qw/redefine/;
    local *RT::ScripAction::SendEmail::send_message = sub  { return 1};

    %args = (message => $content, queue => 1, action => 'correspond');
    RT::Interface::Email::gateway(\%args);
    # TODO: following 5 lines should replaced by get_latest_ticket_ok()
    $tickets = RT::Model::TicketCollection->new(current_user => RT->system_user);
    $tickets->order_by({column => 'id', order => 'DESC'});
    $tickets->limit(column => 'id' ,operator => '>', value => '0');
    $tick = $tickets->first();

    ok ($tick->id, "found ticket ".$tick->id);

    like (first_txn($tick)->content , qr/causes Error/, "We recorded the content right as text-plain");
    is (count_attachs($tick) , 3 , "Has three attachments, presumably a text-plain, a text-html and a multipart alternative");

}

# }}}

# {{{ test a text-html message with an umlaut

 $content =  RT::Test->file_content("$RT::BASE_PATH/lib/t/data/text-html-with-umlaut");

$parser->parse_mime_entity_from_scalar($content);


# be as much like the mail gateway as possible.
&text_html_umlauts_redef_sendmessage;

 %args =        (message => $content, queue => 1, action => 'correspond');
 RT::Interface::Email::gateway(\%args);
 $tickets = RT::Model::TicketCollection->new(current_user => RT->system_user);
$tickets->order_by({column => 'id', order => 'DESC'});
$tickets->limit(column => 'id' ,operator => '>', value => '0');
 $tick = $tickets->first();
ok ($tick->id, "found ticket ".$tick->id);

like (first_attach($tick)->content , qr/causes Error/, "We recorded the content as containing 'causes error'") or diag( first_attach($tick)->content );
like (first_attach($tick)->content_type , qr/text\/html/, "We recorded the content as text/html");
is (count_attachs($tick), 1 , "Has one attachment, presumably a text-html and a multipart alternative");

sub text_html_umlauts_redef_sendmessage {
    no warnings qw/redefine/;
    eval 'sub RT::ScripAction::SendEmail::send_message { 
                my $self = shift;
                my $MIME = shift;
                return (1) unless ($self->scrip_obj->action_obj->name eq "Notify AdminCcs" );
                is ($MIME->parts, 2, "generated correspondence mime entityis composed of three parts");
                is ($MIME->head->mime_type , "multipart/mixed", "The first part is a multipart mixed". $MIME->head->mime_type);
                is ($MIME->parts(0)->head->mime_type , "text/plain", "The second part is a plain");
                is ($MIME->parts(1)->head->mime_type , "text/html", "The third part is an html ");
         }';
}

# }}}

# {{{ test a text-html message with russian characters

 $content =  RT::Test->file_content("$RT::BASE_PATH/lib/t/data/text-html-in-russian");

$parser->parse_mime_entity_from_scalar($content);


# be as much like the mail gateway as possible.
&text_html_russian_redef_sendmessage;

 %args =        (message => $content, queue => 1, action => 'correspond');
 RT::Interface::Email::gateway(\%args);
 $tickets = RT::Model::TicketCollection->new(current_user => RT->system_user);
$tickets->order_by({column => 'id', order => 'DESC'});
$tickets->limit(column => 'id' ,operator => '>', value => '0');
 $tick = $tickets->first();
ok ($tick->id, "found ticket ".$tick->id);

like (first_attach($tick)->content_type , qr/text\/html/, "We recorded the content right as text-html");
is (count_attachs($tick) ,1 , "Has one attachment, presumably a text-html and a multipart alternative");

sub text_html_russian_redef_sendmessage {
    no warnings qw/redefine/;
    eval 'sub RT::ScripAction::SendEmail::send_message { 
                my $self = shift; 
                my $MIME = shift; 
                use Data::Dumper;
                return (1) unless ($self->scrip_obj->action_obj->name eq "Notify AdminCcs" );
                ok (is $MIME->parts, 2, "generated correspondence mime entityis composed of three parts");
                is ($MIME->head->mime_type , "multipart/mixed", "The first part is a multipart mixed". $MIME->head->mime_type);
                is ($MIME->parts(0)->head->mime_type , "text/plain", "The second part is a plain");
                is ($MIME->parts(1)->head->mime_type , "text/html", "The third part is an html ");
                my $content_1251;
                $content_1251 = $MIME->parts(1)->bodyhandle->as_string();
                like ($content_1251 , qr{Ó÷eáíûé Öeíòp "ÊÀÄÐÛ ÄÅËÎÂÎÃÎ ÌÈÐÀ" ïpèãëaøaeò ía òpeíèíã:},
"content matches drugim in codepage 1251" );
                 }';
}

# }}}

# {{{ test a message containing a russian subject and NO content type

RT->config->set( EmailInputEncodings => 'koi8-r', RT->config->get('EmailInputEncodings') );
RT->config->set( EmailOutputEncoding => 'koi8-r' );
 $content =  RT::Test->file_content("$RT::BASE_PATH/lib/t/data/russian-subject-no-content-type");

$parser->parse_mime_entity_from_scalar($content);


# be as much like the mail gateway as possible.
&text_plain_russian_redef_sendmessage;
 %args =        (message => $content, queue => 1, action => 'correspond');
 RT::Interface::Email::gateway(\%args);
 $tickets = RT::Model::TicketCollection->new(current_user => RT->system_user);
$tickets->order_by({column => 'id', order => 'DESC'});
$tickets->limit(column => 'id' ,operator => '>', value => '0');
$tick= $tickets->first();
ok ($tick->id, "found ticket ".$tick->id);

like (first_attach($tick)->content_type , qr/text\/plain/, "We recorded the content type right");
is (count_attachs($tick) ,1 , "Has one attachment, presumably a text-plain");
is ($tick->subject, "\x{442}\x{435}\x{441}\x{442} \x{442}\x{435}\x{441}\x{442}", "Recorded the subject right");
sub text_plain_russian_redef_sendmessage {
    no warnings qw/redefine/;
    eval 'sub RT::ScripAction::SendEmail::send_message { 
                my $self = shift; 
                my $MIME = shift; 
                return (1) unless ($self->scrip_obj->action_obj->name eq "Notify AdminCcs" );
                is ($MIME->head->mime_type , "text/plain", "The only part is text/plain ");
                 my $subject  = $MIME->head->get("subject");
                chomp($subject);
                #is( $subject ,      /^=\?KOI8-R\?B\?W2V4YW1wbGUuY39tICM3XSDUxdPUINTF09Q=\?=/ , "The $subject is encoded correctly");
                };
                 ';
}

my @input_encodings = RT->config->get( 'EmailInputEncodings' );
shift @input_encodings;
RT->config->set(EmailInputEncodings => @input_encodings );
RT->config->set(EmailOutputEncoding => 'utf-8');
# }}}


# {{{ test a message containing a nested RFC 822 message

 $content =  RT::Test->file_content("$RT::BASE_PATH/lib/t/data/nested-rfc-822");
ok ($content, "Loaded nested-rfc-822 to test");

$parser->parse_mime_entity_from_scalar($content);


# be as much like the mail gateway as possible.
&text_plain_nested_redef_sendmessage;
 %args =        (message => $content, queue => 1, action => 'correspond');
 RT::Interface::Email::gateway(\%args);
 $tickets = RT::Model::TicketCollection->new(current_user => RT->system_user);
$tickets->order_by({column => 'id', order => 'DESC'});
$tickets->limit(column => 'id' ,operator => '>', value => '0');
$tick= $tickets->first();
ok ($tick->id, "found ticket ".$tick->id);
is ($tick->subject, "[Jonas Liljegren] Re: [Para] Niv\x{e5}er?");
like (first_attach($tick)->content_type , qr/multipart\/mixed/, "We recorded the content type right");
is (count_attachs($tick) , 5 , "Has one attachment, presumably a text-plain and a message RFC 822 and another plain");
sub text_plain_nested_redef_sendmessage {
    no warnings qw/redefine/;
    eval 'sub RT::ScripAction::SendEmail::send_message { 
                my $self = shift; 
                my $MIME = shift; 
                return (1) unless ($self->scrip_obj->action_obj->name eq "Notify AdminCcs" );
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

 $content =  RT::Test->file_content("$RT::BASE_PATH/lib/t/data/notes-uuencoded");

$parser->parse_mime_entity_from_scalar($content);


# be as much like the mail gateway as possible.
{
    no warnings qw/redefine/;
    local *RT::ScripAction::SendEmail::send_message = sub  { return 1};
    %args =        (message => $content, queue => 1, action => 'correspond');
    RT::Interface::Email::gateway(\%args);
    $tickets = RT::Model::TicketCollection->new(current_user => RT->system_user);
    $tickets->order_by({column => 'id', order => 'DESC'});
    $tickets->limit(column => 'id' ,operator => '>', value => '0');
    $tick= $tickets->first();
    ok ($tick->id, "found ticket ".$tick->id);

    like (first_txn($tick)->content , qr/from Lotus Notes/, "We recorded the content right");
    is (count_attachs($tick) , 3 , "Has three attachments");
}

# }}}

# {{{ test a multipart that crashes the file-based mime-parser works

 $content =  RT::Test->file_content("$RT::BASE_PATH/lib/t/data/crashes-file-based-parser");

$parser->parse_mime_entity_from_scalar($content);


# be as much like the mail gateway as possible.

no warnings qw/redefine/;
local *RT::ScripAction::SendEmail::send_message = sub  { return 1};
 %args =        (message => $content, queue => 1, action => 'correspond');
 RT::Interface::Email::gateway(\%args);
 $tickets = RT::Model::TicketCollection->new(current_user => RT->system_user);
$tickets->order_by({column => 'id', order => 'DESC'});
$tickets->limit(column => 'id' ,operator => '>', value => '0');
$tick= $tickets->first();
ok ($tick->id, "found ticket ".$tick->id);

like (first_txn($tick)->content , qr/FYI/, "We recorded the content right");
is (count_attachs($tick) , 5 , "Has three attachments");




# }}}

# {{{ test a multi-line RT-Send-CC header

 $content =  RT::Test->file_content("$RT::BASE_PATH/lib/t/data/rt-send-cc");

$parser->parse_mime_entity_from_scalar($content);



 %args =        (message => $content, queue => 1, action => 'correspond');
 RT::Interface::Email::gateway(\%args);
 $tickets = RT::Model::TicketCollection->new(current_user => RT->system_user);
$tickets->order_by({column => 'id', order => 'DESC'});
$tickets->limit(column => 'id' ,operator => '>', value => '0');
$tick= $tickets->first();
ok ($tick->id, "found ticket ".$tick->id);

my $cc = first_attach($tick)->get_header('RT-Send-Cc');
like ($cc , qr/test1/, "Found test 1");
like ($cc , qr/test2/, "Found test 2");
like ($cc , qr/test3/, "Found test 3");
like ($cc , qr/test4/, "Found test 4");
like ($cc , qr/test5/, "Found test 5");

# }}}

diag q{regression test for #5248 from rt3.fsck.com} if $ENV{TEST_VERBOSE};
{
    my $content = RT::Test->file_content("$RT::BASE_PATH/lib/t/data/subject-with-folding-ws");
    my ($status, $msg, $ticket) = RT::Interface::Email::gateway(
        { message => $content, queue => 1, action => 'correspond' }
    );
    ok ($status, 'Created ticket') or diag "error: $msg";
    ok ($ticket->id, "found ticket ". $ticket->id);
    is ($ticket->subject, 'test', 'correct subject');
}

diag q{regression test for #5248 from rt3.fsck.com} if $ENV{TEST_VERBOSE};
{
    my $content = RT::Test->file_content("$RT::BASE_PATH/lib/t/data/very-long-subject");
    my ($status, $msg, $ticket) = RT::Interface::Email::gateway(
        { message => $content, queue => 1, action => 'correspond' }
    );
    ok ($status, 'Created ticket') or diag "error: $msg";
    ok ($ticket->id, "found ticket ". $ticket->id);
    is ($ticket->subject, '0123456789'x20, 'correct subject');
}



# Don't taint the environment
$everyone->principal_object->revoke_right(right =>'SuperUser');
1;
