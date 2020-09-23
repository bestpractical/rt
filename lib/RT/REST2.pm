# BEGIN BPS TAGGED BLOCK {{{
#
# COPYRIGHT:
#
# This software is Copyright (c) 1996-2020 Best Practical Solutions, LLC
#                                          <sales@bestpractical.com>
#
# (Except where explicitly superseded by other copyright notices)
#
#
# LICENSE:
#
# This work is made available to you under the terms of Version 2 of
# the GNU General Public License. A copy of that license should have
# been provided with this software, but in any event can be snarfed
# from www.gnu.org.
#
# This work is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA
# 02110-1301 or visit their web page on the internet at
# http://www.gnu.org/licenses/old-licenses/gpl-2.0.html.
#
#
# CONTRIBUTION SUBMISSION POLICY:
#
# (The following paragraph is not intended to limit the rights granted
# to you to modify and distribute this software under the terms of
# the GNU General Public License and is only of importance to you if
# you choose to contribute your changes and enhancements to the
# community by submitting them to Best Practical Solutions, LLC.)
#
# By intentionally submitting any modifications, corrections or
# derivatives to this work, or any other work intended for use with
# Request Tracker, to Best Practical Solutions, LLC, you confirm that
# you are the copyright holder for those contributions and you grant
# Best Practical Solutions,  LLC a nonexclusive, worldwide, irrevocable,
# royalty-free, perpetual, license to use, copy, create derivative
# works based on those contributions, and sublicense and distribute
# those contributions and any derivatives thereof.
#
# END BPS TAGGED BLOCK }}}

use strict;
use warnings;
use 5.010001;

package RT::REST2;

our $REST_PATH = '/REST/2.0';

use Plack::Builder;
use RT::REST2::Dispatcher;

=encoding utf-8

=head1 NAME

RT::REST2 - RT REST API v. 2.0 under /REST/2.0/

=head1 USAGE

=head2 Tutorial

To make it easier to authenticate to REST2, we recommend also using
L<RT::Authen::Token>. Visit "Logged in as ___" -> Settings -> Auth
Tokens. Create an Auth Token, give it any description (such as "REST2
with curl"). Make note of the authentication token it provides to you.

For other authentication options see the section
L<Authentication Methods> below.

=head3 Authentication

Run the following in a terminal, filling in XX_TOKEN_XX from the auth
token above and XX_RT_URL_XX with the URL for your RT instance.

    curl -H 'Authorization: token XX_TOKEN_XX' 'XX_RT_URL_XX/REST/2.0/queues/all'

This does an authenticated request (using the C<Authorization> HTTP
header with type C<token>) for all of the queues you can see. You should
see a response, typical of search results, like this:

    {
       "total" : 1,
       "count" : 1,
       "page" : 1,
       "pages" : 1,
       "per_page" : 20,
       "items" : [
          {
             "type" : "queue",
             "id" : "1",
             "_url" : "XX_RT_URL_XX/REST/2.0/queue/1"
          }
       ]
    }

This format is JSON, which is a format for which many programming languages
provide libraries for parsing and generating.

(If you instead see a response like C<{"message":"Unauthorized"}> that
indicates RT couldn't process your authentication token successfully;
make sure the word "token" appears between "Authorization:" and the auth
token that RT provided to you)

=head3 Following Links

You can request one of the provided C<_url>s to get more information
about that queue.

    curl -H 'Authorization: token XX_TOKEN_XX' 'XX_QUEUE_URL_XX'

This will give a lot of information, like so:

    {
       "id" : 1,
       "Name" : "General",
       "Description" : "The default queue",
       "Lifecycle" : "default",
       ...
       "CustomFields" : {},
       "_hyperlinks" : [
          {
             "id" : "1",
             "ref" : "self",
             "type" : "queue",
             "_url" : "XX_RT_URL_XX/REST/2.0/queue/1"
          },
          {
             "ref" : "history",
             "_url" : "XX_RT_URL_XX/REST/2.0/queue/1/history"
          },
          {
             "ref" : "create",
             "type" : "ticket",
             "_url" : "XX_RT_URL_XX/REST/2.0/ticket?Queue=1"
          }
       ],
    }

Of particular note is the C<_hyperlinks> key, which gives you a list of
related resources to examine (following the
L<https://en.wikipedia.org/wiki/HATEOAS> principle). For example an
entry with a C<ref> of C<history> lets you examine the transaction log
for a record. You can implement your REST API client knowing that any
other hypermedia link with a C<ref> of C<history> has the same meaning,
regardless of whether it's the history of a queue, ticket, asset, etc.

Another C<ref> you'll see in C<_hyperlinks> is C<create>, with a C<type>
of C<ticket>. This of course gives you the URL to create tickets
I<in this queue>. Importantly, if your user does I<not> have the
C<CreateTicket> permission in this queue, then REST2 would simply not
include this hyperlink in its response to your request. This allows you
to dynamically adapt your client's behavior to its presence or absence,
just like the web version of RT does.

=head3 Creating Tickets

Let's use the C<_url> from the C<create> hyperlink with type C<ticket>.

To create a ticket is a bit more involved, since it requires providing a
different HTTP verb (C<POST> instead of C<GET>), a C<Content-Type>
header (to tell REST2 that your content is JSON instead of, say, XML),
and the fields for your new ticket such as Subject. Here is the curl
invocation, wrapped to multiple lines for readability.

    curl -X POST
         -H "Content-Type: application/json"
         -d '{ "Subject": "hello world" }'
         -H 'Authorization: token XX_TOKEN_XX'
            'XX_TICKET_CREATE_URL_XX'

If successful, that will provide output like so:

    {
        "_url" : "XX_RT_URL_XX/REST/2.0/ticket/20",
        "type" : "ticket",
        "id"   : "20"
    }

(REST2 also produces the status code of C<201 Created> with a C<Location>
header of the new ticket, which you may choose to use instead of the
JSON response)

We can fetch that C<_url> to continue working with this newly-created
ticket. Request the ticket like so (make sure to include the C<-i> flag
to see response's HTTP headers).

    curl -i -H 'Authorization: token XX_TOKEN_XX' 'XX_TICKET_URL_XX'

You'll first see that there are many hyperlinks for tickets, including
one for each Lifecycle action you can perform, history, comment,
correspond, etc. Again these adapt to whether you have the appropriate
permissions to do these actions.

Additionally you'll see an C<ETag> header for this record, which can be
used for conflict avoidance
(L<https://en.wikipedia.org/wiki/HTTP_ETag>). We'll first try updating this
ticket with an I<invalid> C<ETag> to see what happens.

=head3 Updating Tickets

For updating tickets we use the C<PUT> verb, but otherwise it looks much
like a ticket creation.

    curl -X PUT
         -H "Content-Type: application/json"
         -H "If-Match: invalid-etag"
         -d '{ "Subject": "trial update" }'
         -H 'Authorization: token XX_TOKEN_XX'
            'XX_TICKET_URL_XX'

You'll get an error response like C<{"message":"Precondition Failed"}>
and a status code of 412. If you examine the ticket, you'll also see
that its Subject was not changed. This is because the C<If-Match> header
advises the server to make changes I<if and only if> the ticket's
C<ETag> matches what you provide. Since it differed, the server refused
the request and made no changes.

Now, try the same request by replacing the value "invalid-etag" in the
C<If-Match> request header with the real C<ETag> you'd received when you
requested the ticket previously. You'll then get a JSON response like:

    ["Ticket 1: Subject changed from 'hello world' to 'trial update'"]

which is a list of messages meant for displaying to an end-user.

If you C<GET> the ticket again, you'll observe that the C<ETag>
header now has a different value, indicating that the ticket itself has
changed. This means if you were to retry the C<PUT> update with the
previous (at the time, expected) C<ETag> you would instead be rejected
by the server with Precondition Failed.

You can use C<ETag> and C<If-Match> headers to avoid race conditions
such as two people updating a ticket at the same time. Depending on the
sophistication of your client, you may be able to automatically retry
the change by incorporating the changes made on the server (for example
adding time worked can be automatically be recalculated).

You may of course choose to ignore the C<ETag> header and not provide
C<If-Match> in your requests; RT doesn't require its use.

=head3 Replying/Commenting Tickets

You can reply to or comment a ticket by C<POST>ing to C<_url> from the
C<correspond> or C<comment> hyperlinks that were returned when fetching the
ticket.

    curl -X POST
         -H "Content-Type: application/json"
         -d '{
              "Subject"    : "response",
              "Content"    : "What is your <em>issue</em>?",
              "ContentType": "text/html",
              "TimeTaken"  : "1"
            }'
         -H 'Authorization: token XX_TOKEN_XX'
            'XX_TICKET_URL_XX'/correspond

Replying or commenting a ticket is quite similar to a ticket creation: you
send a C<POST> request, with data encoded in C<JSON>. The difference lies in
the properties of the JSON data object you can pass:

=over 4

=item C<Subject>

The subject of your response/comment, optional

=item C<Content>

The content of your response/comment, mandatory unless there is a non empty
C<Attachments> property to add at least one attachment to the ticket (see
L<Add Attachments> section below).

=item C<ContentType>

The MIME content type of your response/comment, typically C<text/plain> or
C</text/html>, mandatory unless there is a non empty C<Attachments> property
to add at least one attachment to the ticket (see L<Add Attachments> section
below).

=item C<TimeTaken>

The time, in minutes, you've taken to work on your response/comment, optional.

=back

=head3 Add Attachments

You can attach any binary or text file to your response or comment by
specifying C<Attachements> property in the JSON object, which should be a
JSON array where each item represents a file you want to attach. Each item
is a JSON object with the following properties:

=over 4

=item C<FileName>

The name of the file to attach to your response/comment, mandatory.

=item C<FileType>

The MIME type of the file to attach to your response/comment, mandatory.

=item C<FileContent>

The content, I<encoded in C<MIME Base64>> of the file to attach to your
response/comment, mandatory.

=back

The reason why you should encode the content of any file to C<MIME Base64>
is that a JSON string value should be a sequence of zero or more Unicode
characters. C<MIME Base64> is a binary-to-text encoding scheme widely used
(for eg. by web browser) to send binary data when text data is required.
Most popular language have C<MIME Base64> libraries that you can use to
encode the content of your attached files (see L<MIME::Base64> for C<Perl>).
Note that even text files should be C<MIME Base64> encoded to be passed in
the C<FileContent> property.

Here's a Perl example to send an image and a plain text file attached to a
comment:

    #!/usr/bin/perl
    use strict;
    use warnings;

    use LWP::UserAgent;
    use JSON;
    use MIME::Base64;
    use Data::Dumper;

    my $url = 'http://rt.local/REST/2.0/ticket/1/comment';

    my $img_path = '/tmp/my_image.png';
    my $img_content;
    open my $img_fh, '<', $img_path or die "Cannot read $img_path: $!\n";
    {
        local $/;
        $img_content = <$img_fh>;
    }
    close $img_fh;
    $img_content = MIME::Base64::encode_base64($img_content);

    my $txt_path = '~/.bashrc';
    my $txt_content;
    open my $txt_fh, '<', glob($txt_path) or die "Cannot read $txt_path: $!\n";
    {
        local $/;
        $txt_content = <$txt_fh>;
    }
    close $txt_fh;
    $txt_content = MIME::Base64::encode_base64($txt_content);

    my $json = JSON->new->utf8;
    my $payload = {
        Content => '<p>I want <b>two</b> <em>attachments</em></p>',
        ContentType => 'text/html',
        Subject => 'Attachments in JSON Array',
        Attachments => [
            {
                FileName => 'my_image.png',
                FileType => 'image/png',
                FileContent => $img_content,
            },
            {
                FileName => '.bashrc',
                FileType => 'text/plain',
                FileContent => $txt_content,
            },
        ],
    };

    my $req = HTTP::Request->new(POST => $url);
    $req->header('Authorization' => 'token 6-66-66666666666666666666666666666666');
    $req->header('Content-Type'  => 'application/json' );
    $req->header('Accept'        => 'application/json' );
    $req->content($json->encode($payload));

    my $ua = LWP::UserAgent->new;
    my $res = $ua->request($req);
    print Dumper($json->decode($res->content)) . "\n";

Encoding the content of attachments file in C<MIME Base64> has the drawback
of adding some processing overhead and to increase the sent data size by
around 33%. RT's REST2 API provides another way to attach any binary or text
file to your response or comment by C<POST>ing, instead of a JSON request, a
C<multipart/form-data> request. This kind of request is similar to what the
browser sends when you add attachments in RT's reply or comment form. As its
name suggests, a C<multipart/form-data> request message contains a series of
parts, each representing a form field. To reply to or comment a ticket, the
request has to include a field named C<JSON>, which, as previously, is a
JSON object with C<Subject>, C<Content>, C<ContentType>, C<TimeTaken>
properties. Files can then be attached by specifying a field named
C<Attachments> for each of them, with the content of the file as value and
the appropriate MIME type.

The curl invocation is quite straightforward:

    curl -X POST
         -H "Content-Type: multipart/form-data"
         -F 'JSON={
                    "Subject"    : "Attachments in multipart/form-data",
                    "Content"    : "<p>I want <b>two</b> <em>attachments</em></p>",
                    "ContentType": "text/html",
                    "TimeTaken"  : "1"
                  };type=application/json'
         -F 'Attachments=@/tmp/my_image.png;type=image/png'
         -F 'Attachments=@/tmp/.bashrc;type=text/plain'
         -H 'Authorization: token XX_TOKEN_XX'
            'XX_TICKET_URL_XX'/comment

=head3 Summary

RT's REST2 API provides the tools you need to build robust and dynamic
integrations. Tools like C<ETag>/C<If-Match> allow you to avoid
conflicts such as two people taking a ticket at the same time. Using
JSON for all data interchange avoids problems caused by parsing text.
Hypermedia links inform your client application of what the user has the
ability to do.

Careful readers will see that, other than our initial entry into the
system, we did not I<generate> any URLs. We only I<followed> links, just
like you do when browsing a website on your computer. We've better
decoupled the client's implementation from the server's REST API.
Additionally, this system lets you be informed of new capabilities in
the form of additional hyperlinks.

Using these tools and principles, REST2 will help you build rich,
robust, and powerful integrations with the other applications and
services that your team uses.

=head2 Endpoints

Currently provided endpoints under C</REST/2.0/> are described below.
Wherever possible please consider using C<_hyperlinks> hypermedia
controls available in response bodies rather than hardcoding URLs.

For simplicity, the examples below omit the extra options to
curl for SSL like --cacert.

=head3 Tickets

    GET /tickets?query=<TicketSQL>
        search for tickets using TicketSQL

    GET /tickets?simple=1;query=<simple search query>
        search for tickets using simple search syntax

    POST /tickets
        search for tickets with the 'query' and optional 'simple' parameters

    POST /ticket
        create a ticket; provide JSON content

    GET /ticket/:id
        retrieve a ticket

    PUT /ticket/:id
        update a ticket's metadata; provide JSON content

    DELETE /ticket/:id
        set status to deleted

    POST /ticket/:id/correspond
    POST /ticket/:id/comment
        add a reply or comment to the ticket

    GET /ticket/:id/history
        retrieve list of transactions for ticket

    POST /tickets/bulk
        create multiple tickets; provide JSON content(array of hashes)

    PUT /tickets/bulk
        update multiple tickets' metadata; provide JSON content(array of hashes)

=head3 Ticket Examples

Below are some examples using the endpoints above.

    # Create a ticket, setting some custom fields
    curl -X POST -H "Content-Type: application/json" -u 'root:password'
        -d '{ "Queue": "General", "Subject": "Create ticket test",
            "Requestor": "user1@example.com", "Cc": "user2@example.com",
            "Content": "Testing a create",
            "CustomFields": {"Severity": "Low"}}'
        'https://myrt.com/REST/2.0/ticket'

    # Update a ticket, with a custom field update
    curl -X PUT -H "Content-Type: application/json" -u 'root:password'
        -d '{ "Subject": "Update test", "CustomFields": {"Severity": "High"}}'
        'https://myrt.com/REST/2.0/ticket/6'

    # Correspond a ticket
    curl -X POST -H "Content-Type: application/json" -u 'root:password'
        -d '{ "Content": "Testing a correspondence", "ContentType": "text/plain" }'
        'https://myrt.com/REST/2.0/ticket/6/correspond'

    # Correspond a ticket with a transaction custom field
    curl -X POST -H "Content-Type: application/json" -u 'root:password'
        -d '{ "Content": "Testing a correspondence", "ContentType": "text/plain",
              "TxnCustomFields": {"MyField": "custom field value"} }'
        'https://myrt.com/REST/2.0/ticket/6/correspond'

    # Comment on a ticket
    curl -X POST -H "Content-Type: text/plain" -u 'root:password'
        -d 'Testing a comment'
        'https://myrt.com/REST/2.0/ticket/6/comment'

    # Comment on a ticket with custom field update
    curl -X POST -H "Content-Type: text/plain" -u 'root:password'
        -d '{ "Content": "Testing a comment", "ContentType": "text/plain", "CustomFields": {"Severity": "High"} }'
        'https://myrt.com/REST/2.0/ticket/6/comment'

    # Create an Asset
    curl -X POST -H "Content-Type: application/json" -u 'root:password'
        -d '{"Name" : "Asset From Rest", "Catalog" : "General assets", "Content" : "Some content"}'
        'https://myrt.com/REST/2.0/asset'

    # Search Assets
    curl -X POST -H "Content-Type: application/json" -u 'root:password'
    -d '[{ "field" : "id", "operator" : ">=", "value" : 0 }]'
    'https://myrt.com/REST/2.0/asset'

    # Search Attachments by ticket
    curl -X POST -H "Content-Type: application/json" -u 'root:password'
    -d '[{ "field": "ContentType", "operator": "=", "value": "image/png" }, { "field": "TicketId", "value": 6 } ]'
    'https://myrt.com/REST/2.0/attachments'

=head3 Transactions

    GET /transactions?query=<JSON>
    POST /transactions
        search for transactions using L</JSON searches> syntax

    GET /ticket/:id/history
    GET /queue/:id/history
    GET /queue/:name/history
    GET /asset/:id/history
    GET /user/:id/history
    GET /user/:name/history
    GET /group/:id/history
        get transactions for record

    GET /transaction/:id
        retrieve a transaction

=head3 Attachments and Messages

    GET /attachments?query=<JSON>
    POST /attachments
        search for attachments using L</JSON searches> syntax

    GET /transaction/:id/attachments
        get attachments for transaction

    GET /attachment/:id
        retrieve an attachment

=head3 Image and Binary Object Custom Field Values

    GET /download/cf/:id
        retrieve an image or a binary file as an object custom field value

=head3 Queues

    GET /queues/all
        retrieve list of all queues you can see

    GET /queues?query=<JSON>
    POST /queues
        search for queues using L</JSON searches> syntax

    POST /queue
        create a queue; provide JSON content

    GET /queue/:id
    GET /queue/:name
        retrieve a queue by numeric id or name

    PUT /queue/:id
    PUT /queue/:name
        update a queue's metadata; provide JSON content

    DELETE /queue/:id
    DELETE /queue/:name
        disable queue

    GET /queue/:id/history
    GET /queue/:name/history
        retrieve list of transactions for queue

=head3 Assets

    GET /assets?query=<JSON>
    POST /assets
        search for assets using L</JSON searches> syntax

    POST /asset
        create an asset; provide JSON content

    GET /asset/:id
        retrieve an asset

    PUT /asset/:id
        update an asset's metadata; provide JSON content

    DELETE /asset/:id
        set status to deleted

    GET /asset/:id/history
        retrieve list of transactions for asset

=head3 Catalogs

    GET /catalogs/all
        retrieve list of all catalogs you can see

    GET /catalogs?query=<JSON>
    POST /catalogs
        search for catalogs using L</JSON searches> syntax

    POST /catalog
        create a catalog; provide JSON content

    GET /catalog/:id
    GET /catalog/:name
        retrieve a catalog by numeric id or name

    PUT /catalog/:id
    PUT /catalog/:name
        update a catalog's metadata; provide JSON content

    DELETE /catalog/:id
    DELETE /catalog/:name
        disable catalog

=head3 Articles

    GET /articles?query=<JSON>
    POST /articles
        search for articles using L</JSON searches> syntax

    POST /article
        create an article; provide JSON content

    GET /article/:id
        retrieve an article

    PUT /article/:id
        update an article's metadata; provide JSON content

    DELETE /article/:id
        set status to deleted

    GET /article/:id/history
        retrieve list of transactions for article

=head3 Classes

    GET /classes/all
        retrieve list of all classes you can see

    GET /classes?query=<JSON>
    POST /classes
        search for classes using L</JSON searches> syntax

    POST /class
        create a class; provide JSON content

    GET /class/:id
    GET /class/:name
        retrieve a class by numeric id or name

    PUT /class/:id
    PUT /class/:name
        update a class's metadata; provide JSON content

    DELETE /class/:id
    DELETE /class/:name
        disable class

=head3 Users

    GET /users?query=<JSON>
    POST /users
        search for users using L</JSON searches> syntax

    POST /user
        create a user; provide JSON content

    GET /user/:id
    GET /user/:name
        retrieve a user by numeric id or username (including its memberships and whether it is disabled)

    PUT /user/:id
    PUT /user/:name
        update a user's metadata (including its Disabled status); provide JSON content

    DELETE /user/:id
    DELETE /user/:name
        disable user

    GET /user/:id/history
    GET /user/:name/history
        retrieve list of transactions for user

=head3 Groups

    GET /groups?query=<JSON>
    POST /groups
        search for groups using L</JSON searches> syntax

    POST /group
        create a (user defined) group; provide JSON content

    GET /group/:id
        retrieve a group (including its members and whether it is disabled)

    PUT /group/:id
        update a groups's metadata (including its Disabled status); provide JSON content

    DELETE /group/:id
        disable group

    GET /group/:id/history
        retrieve list of transactions for group

=head3 User Memberships

    GET /user/:id/groups
    GET /user/:name/groups
        retrieve list of groups which a user is a member of

    PUT /user/:id/groups
    PUT /user/:name/groups
        add a user to groups; provide a JSON array of groups ids

    DELETE /user/:id/group/:id
    DELETE /user/:name/group/:id
        remove a user from a group

    DELETE /user/:id/groups
    DELETE /user/:name/groups
        remove a user from all groups

=head3 Group Members

    GET /group/:id/members
        retrieve list of direct members of a group

    GET /group/:id/members?recursively=1
        retrieve list of direct and recursive members of a group

    GET /group/:id/members?users=0
        retrieve list of direct group members of a group

    GET /group/:id/members?users=0&recursively=1
        retrieve list of direct and recursive group members of a group

    GET /group/:id/members?groups=0
        retrieve list of direct user members of a group

    GET /group/:id/members?groups=0&recursively=1
        retrieve list of direct and recursive user members of a group

    PUT /group/:id/members
        add members to a group; provide a JSON array of principal ids

    DELETE /group/:id/member/:id
        remove a member from a group

    DELETE /group/:id/members
        remove all members from a group

=head3 Custom Fields

    GET /customfields?query=<JSON>
    POST /customfields
        search for custom fields using L</JSON searches> syntax

    POST /customfield
        create a customfield; provide JSON content

    GET /catalog/:id/customfields?query=<JSON>
    POST /catalog/:id/customfields
        search for custom fields attached to a catalog using L</JSON searches> syntax

    GET /class/:id/customfields?query=<JSON>
    POST /class/:id/customfields
        search for custom fields attached to a class using L</JSON searches> syntax

    GET /queue/:id/customfields?query=<JSON>
    POST /queue/:id/customfields
        search for custom fields attached to a queue using L</JSON searches> syntax

    GET /customfield/:id
        retrieve a custom field, with values if type is Select

    GET /customfield/:id?category=<category name>
        retrieve a custom field, with values filtered by category if type is Select

    PUT /customfield/:id
        update a custom field's metadata; provide JSON content

    DELETE /customfield/:id
        disable customfield

=head3 Custom Field Values

    GET /customfield/:id/values?query=<JSON>
    POST /customfield/:id/values
        search for values of a custom field  using L</JSON searches> syntax

    POST /customfield/:id/value
        add a value to a custom field; provide JSON content

    GET /customfield/:id/value/:id
        retrieve a value of a custom field

    PUT /customfield/:id/value/:id
        update a value of a custom field; provide JSON content

    DELETE /customfield/:id/value/:id
        remove a value from a custom field

=head3 Custom Roles

    GET /customroles?query=<JSON>
    POST /customroles
        search for custom roles using L</JSON searches> syntax

    GET /customrole/:id
        retrieve a custom role

=head3 Miscellaneous

    GET /
        produces this documentation

    GET /rt
        produces system information

=head2 JSON searches

Some resources accept a basic JSON structure as the search conditions which
specifies one or more fields to limit on (using specified operators and
values).  An example:

    curl -si -u user:pass https://rt.example.com/REST/2.0/queues -XPOST --data-binary '
        [
            { "field":    "Name",
              "operator": "LIKE",
              "value":    "Engineering" },

            { "field":    "Lifecycle",
              "value":    "helpdesk" }
        ]
    '

The JSON payload must be an array of hashes with the keys C<field> and C<value>
and optionally C<operator>.

Results can be sorted by using multiple query parameter arguments
C<orderby> and C<order>. Each C<orderby> query parameter specify a field
to be used for sorting results. If the request includes more than one
C<orderby> query parameter, results are sorted according to
corresponding fields in the same order than they are specified. For
instance, if you want to sort results according to creation date and
then by id (in case of some items have the same creation date), your
request should specify C<?orderby=Created&orderby=id>. By default,
results are sorted in ascending order. To sort results in descending
order, you should use C<order=DESC> query parameter. Any other value for
C<order> query parameter will be treated as C<order=ASC>, for ascending
order. The order of the C<order> query parameters should be the same as
the C<orderby> query parameters. Therefore, if you specify two fields to
sort the results (with two C<orderby> parameters) and you want to sort
the second field by descending order, you should also explicitely
specify C<order=ASC> for the first field:
C<orderby=Created&order=ASC&orderby=id&order=DESC>. C<orderby> and
C<order> query parameters are supported in both JSON and TicketSQL
searches.

The same C<field> is specified more than one time to express more than one
condition on this field. For example:

    [
        { "field":    "id",
          "operator": ">",
          "value":    $min },

        { "field":     "id",
          "operator": "<",
          "value":    $max }
    ]

By default, RT will aggregate these conditions with an C<OR>, except for
when searching queues, where an C<AND> is applied. If you want to search for
multiple conditions on the same field aggregated with an C<AND> (or an C<OR>
for queues), you can specify C<entry_aggregator> keys in corresponding
hashes:

    [
        { "field":    "id",
          "operator": ">",
          "value":    $min },

        { "field":             "id",
          "operator":         "<",
          "value":            $max,
          "entry_aggregator": "AND" }
    ]

Results are returned in
L<the format described below|/"Example of plural resources (collections)">.

=head2 Example of plural resources (collections)

Resources which represent a collection of other resources use the following
standard JSON format:

    {
       "count" : 20,
       "page" : 1,
       "pages" : 191,
       "per_page" : 20,
       "next_page" : "<collection path>?page=2"
       "total" : 3810,
       "items" : [
          { … },
          { … },
          …
       ]
    }

Each item is nearly the same representation used when an individual resource
is requested.

=head2 Object Custom Field Values

When creating (via C<POST>) or updating (via C<PUT>) a resource which has
some custom fields attached to, you can specify the value(s) for these
customfields in the C<CustomFields> property of the JSON object parameter.
The C<CustomFields> property should be a JSON object, with each property
being the custom field identifier or name. If the custom field can have only
one value, you just have to speciy the value as JSON string for this custom
field. If the customfield can have several value, you have to specify a JSON
array of each value you want for this custom field.

    "CustomFields": {
        "XX_SINGLE_CF_ID_XX"   : "My Single Value",
        "XX_MULTI_VALUE_CF_ID": [
            "My First Value",
            "My Second Value"
        ]
    }

Note that for a multi-value custom field, you have to specify all the values
for this custom field. Therefore if the customfield for this resource
already has some values, the existing values must be including in your
update request if you want to keep them (and add some new values).
Conversely, if you want to delete some existing values, do not include them
in your update request (including only values you wan to keep). The
following example deletes "My Second Value" from the previous example:

    "CustomFields": {
        "XX_MULTI_VALUE_CF_ID": [
            "My First Value"
        ]
    }

To delete a single-value custom field, set its value to JSON C<null>
(C<undef> in Perl):

    "CustomFields": {
        "XX_SINGLE_CF_ID_XX" : null
    }

New values for Image and Binary custom fields can be set by specifying a
JSON object as value for the custom field identifier or name with the
following properties:

=over 4

=item C<FileName>

The name of the file to attach, mandatory.

=item C<FileType>

The MIME type of the file to attach, mandatory.

=item C<FileContent>

The content, I<encoded in C<MIME Base64>> of the file to attach, mandatory.

=back

The reason why you should encode the content of the image or binary file to
C<MIME Base64> is that a JSON string value should be a sequence of zero or
more Unicode characters. C<MIME Base64> is a binary-to-text encoding scheme
widely used (for eg. by web browser) to send binary data when text data is
required. Most popular language have C<MIME Base64> libraries that you can
use to encode the content of your attached files (see L<MIME::Base64> for
C<Perl>). Note that even text files should be C<MIME Base64> encoded to be
passed in the C<FileContent> property.

    "CustomFields": {
        "XX_SINGLE_IMAGE_OR_BINARY_CF_ID_XX"   : {
            "FileName"   : "image.png",
            "FileType"   : "image/png",
            "FileContent": "XX_BASE_64_STRING_XX"
        },
        "XX_MULTI_VALUE_IMAGE_OR_BINARY_CF_ID": [
            {
                "FileName"   : "another_image.png",
                "FileType"   : "image/png",
                "FileContent": "XX_BASE_64_STRING_XX"
            },
            {
                "FileName"   : "hello_world.txt",
                "FileType"   : "text/plain",
                "FileContent": "SGVsbG8gV29ybGQh"
            }
        ]
    }

Encoding the content of image or binary files in C<MIME Base64> has the
drawback of adding some processing overhead and to increase the sent data
size by around 33%. RT's REST2 API provides another way to upload image or
binary files as custom field alues by sending, instead of a JSON request, a
C<multipart/form-data> request. This kind of request is similar to what the
browser sends when you upload a file in RT's ticket creation or update
forms. As its name suggests, a C<multipart/form-data> request message
contains a series of parts, each representing a form field. To create or
update a ticket with image or binary file, the C<multipart/form-data>
request has to include a field named C<JSON>, which, as previously, is a
JSON object with C<Queue>, C<Subject>, C<Content>, C<ContentType>, etc.
properties. But instead of specifying each custom field value as a JSON
object with C<FileName>, C<FileType> and C<FileContent> properties, each
custom field value should be a JSON object with C<UploadField>. You can
choose anything you want for this field name, except I<Attachments>, which
should be reserved for attaching files to a response or a comment to a
ticket. Files can then be attached by specifying a field named as specified
in the C<CustomFields> property for each of them, with the content of the
file as value and the appropriate MIME type.

Here is an exemple of a curl invocation, wrapped to multiple lines for
readability, to create a ticket with a multipart/request to upload some
image or binary files as custom fields values.

    curl -X POST
         -H "Content-Type: multipart/form-data"
         -F 'JSON={
                    "Queue"      : "General",
                    "Subject"    : "hello world",
                    "Content"    : "That <em>damned</em> printer is out of order <b>again</b>!",
                    "ContentType": "text/html",
                    "CustomFields"  : {
                        "XX_SINGLE_IMAGE_OR_BINARY_CF_ID_XX"   => { "UploadField": "FILE_1",
                        "XX_MULTI_VALUE_IMAGE_OR_BINARY_CF_ID" => [ { "UploadField": "FILE_2" }, { "UploadField": "FILE_3" } ]
                    }
                  };type=application/json'
         -F 'FILE_1=@/tmp/image.png;type=image/png'
         -F 'FILE_2=@/tmp/another_image.png;type=image/png'
         -F 'FILE_3=@/etc/cups/cupsd.conf;type=text/plain'
         -H 'Authorization: token XX_TOKEN_XX'
            'XX_RT_URL_XX'/tickets

If you want to delete some existing values from a multi-value image or
binary custom field, you can just pass the existing filename as value for
the custom field identifier or name, no need to upload again the content of
the file. The following example will delete the text file and keep the image
upload in previous example:

    "CustomFields": {
        "XX_MULTI_VALUE_IMAGE_OR_BINARY_CF_ID": [
                "image.png"
        ]
    }

To download an image or binary file which is the custom field value of a
resource, you just have to make a C<GET> request to the entry point returned
for the corresponding custom field when fetching this resource, and it will
return the content of the file as an octet string:

    curl -i -H 'Authorization: token XX_TOKEN_XX' 'XX_TICKET_URL_XX'

    {
        […]
        "XX_IMAGE_OR_BINARY_CF_ID_XX" : [
            {
                "content_type" : "image/png",
                "filename" : "image.png",
                "_url" : "XX_RT_URL_XX/REST/2.0/download/cf/XX_IMAGE_OR_BINARY_OCFV_ID_XX"
            }
        ],
        […]
    },

    curl -i -H 'Authorization: token XX_TOKEN_XX'
        'XX_RT_URL_XX/REST/2.0/download/cf/XX_IMAGE_OR_BINARY_OCFV_ID_XX'
        > file.png

=head2 Paging

All plural resources (such as C</tickets>) require pagination, controlled by
the query parameters C<page> and C<per_page>.  The default page size is 20
items, but it may be increased up to 100 (or decreased if desired).  Page
numbers start at 1. The number of pages is returned, and if there is a next
or previous page, then the URL for that page is returned in the next_page
and prev_page variables respectively. It is up to you to store the required
JSON to pass with the following page request.

=head2 Disabled items

By default, only enabled objects are returned. To include disabled objects
you can specify C<find_disabled_rows=1> as a query parameter.

=head2 Fields

When fetching search results you can include additional fields by adding
a query parameter C<fields> which is a comma seperated list of fields
to include. You must use the camel case version of the name as included
in the results for the actual item.

You can use additional fields parameters to expand child blocks, for
example (line wrapping inserted for readability):

    XX_RT_URL_XX/REST/2.0/tickets
      ?fields=Owner,Status,Created,Subject,Queue,CustomFields
      &fields[Queue]=Name,Description

Says that in the result set for tickets, the extra fields for Owner, Status,
Created, Subject, Queue and CustomFields should be included. But in
addition, for the Queue block, also include Name and Description. The
results would be similar to this (only one ticket is displayed in this
example):

   "items" : [
      {
         "Subject" : "Sample Ticket",
         "id" : "2",
         "type" : "ticket",
         "Owner" : {
            "id" : "root",
            "_url" : "XX_RT_URL_XX/REST/2.0/user/root",
            "type" : "user"
         },
         "_url" : "XX_RT_URL_XX/REST/2.0/ticket/2",
         "Status" : "resolved",
         "Created" : "2018-06-29:10:25Z",
         "Queue" : {
            "id" : "1",
            "type" : "queue",
            "Name" : "General",
            "Description" : "The default queue",
            "_url" : "XX_RT_URL_XX/REST/2.0/queue/1"
         },
         "CustomFields" : [
             {
                 "id" : "1",
                 "type" : "customfield",
                 "_url" : "XX_RT_URL_XX/REST/2.0/customfield/1",
                 "name" : "My Custom Field",
                 "values" : [
                     "CustomField value"
                 },
             }
         ]
      }
      { … },
      …
   ],

If the user performing the query doesn't have rights to view the record
(or sub record), then the empty string will be returned.

For single object URLs like /ticket/:id, as it already contains all the
fields by default, parameter "fields" is not needed, but you can still
use additional fields parameters to expand child blocks:

    XX_RT_URL_XX/REST/2.0/ticket/1?fields[Queue]=Name,Description

=head2 Authentication Methods

Authentication should B<always> be done over HTTPS/SSL for
security. You should only serve up the C</REST/2.0/> endpoint over SSL.

=head3 Basic Auth

Authentication may use internal RT usernames and passwords, provided via
HTTP Basic auth. Most HTTP libraries already have a way of providing basic
auth credentials when making requests.  Using curl, for example:

    curl -u 'username:password' /path/to/REST/2.0

=head3 Token Auth

You may use the L<RT::Authen::Token> extension to authenticate to the
REST 2 API. Once you've acquired an authentication token in the web
interface, specify the C<Authorization> header with a value of "token"
like so:

    curl -H 'Authorization: token …' /path/to/REST/2.0

If the library or application you're using does not support specifying
additional HTTP headers, you may also pass the authentication token as a
query parameter like so:

    curl /path/to/REST/2.0?token=…

=head3 Cookie Auth

Finally, you may reuse an existing cookie from an ordinary web session
to authenticate against REST2. This is primarily intended for
interacting with REST2 via JavaScript in the browser. Other REST
consumers are advised to use the alternatives above.

=head2 Conditional requests (If-Modified-Since, If-Match)

You can take advantage of the C<Last-Modified> headers returned by most
single resource endpoints.  Add a C<If-Modified-Since> header to your
requests for the same resource, using the most recent C<Last-Modified>
value seen, and the API may respond with a 304 Not Modified.  You can
also use HEAD requests to check for updates without receiving the actual
content when there is a newer version. You may also add an
C<If-Unmodified-Since> header to your updates to tell the server to
refuse updates if the record had been changed since you last retrieved
it.

C<ETag>, C<If-Match>, and C<If-None-Match> work similarly to
C<Last-Modified>, C<If-Modified-Since>, and C<If-Unmodified-Since>,
except that they don't use a timestamp, which has its own set of
tradeoffs. C<ETag> is an opaque value, so it has no meaning to consumers
(unlike timestamps). However, timestamps have the disadvantage of having
a resolution of seconds, so two updates happening in the same second
would produce incorrect results, whereas C<ETag> does not suffer from
that problem.

=head2 Status codes

The REST API uses the full range of HTTP status codes, and your client should
handle them appropriately.

=cut

# XXX TODO: API doc

sub to_psgi_app {
    my $self = shift;
    my $res = $self->to_app(@_);

    return Plack::Util::response_cb($res, sub {
        my $res = shift;
        $self->CleanupRequest;
    });
}

sub to_app {
    my $class = shift;

    return builder {
        enable '+RT::REST2::Middleware::ErrorAsJSON';
        enable '+RT::REST2::Middleware::Log';
        enable '+RT::REST2::Middleware::Auth';
        RT::REST2::Dispatcher->to_psgi_app;
    };
}

sub base_path {
    RT->Config->Get('WebPath') . $REST_PATH
}

sub base_uri {
    RT->Config->Get('WebBaseURL') . shift->base_path
}

# Called by RT::Interface::Web::Handler->PSGIApp
sub PSGIWrap {
    my ($class, $app) = @_;
    return builder {
        mount $REST_PATH => $class->to_app;
        mount '/' => $app;
    };
}

sub CleanupRequest {

    if ( $RT::Handle && $RT::Handle->TransactionDepth ) {
        $RT::Handle->ForceRollback;
        $RT::Logger->crit(
            "Transaction not committed. Usually indicates a software fault."
            . "Data loss may have occurred" );
    }

    # Clean out the ACL cache. the performance impact should be marginal.
    # Consistency is imprived, too.
    RT::Principal->InvalidateACLCache();
    DBIx::SearchBuilder::Record::Cachable->FlushCache
      if ( RT->Config->Get('WebFlushDbCacheEveryRequest')
        and UNIVERSAL::can(
            'DBIx::SearchBuilder::Record::Cachable' => 'FlushCache' ) );
}

1;
