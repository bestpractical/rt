package RT::Extension::REST2::Resource::Message;
use strict;
use warnings;

use Moose;
use namespace::autoclean;
use MIME::Base64;

extends 'RT::Extension::REST2::Resource';
use RT::Extension::REST2::Util qw( error_as_json update_custom_fields );

sub dispatch_rules {
    Path::Dispatcher::Rule::Regex->new(
        regex => qr{^/ticket/(\d+)/(correspond|comment)$},
        block => sub {
            my ($match, $req) = @_;
            my $ticket = RT::Ticket->new($req->env->{"rt.current_user"});
            $ticket->Load($match->pos(1));
            return { record => $ticket, type => $match->pos(2) },
        },
    );
}

has record => (
    is       => 'ro',
    isa      => 'RT::Record',
    required => 1,
);

has type => (
    is       => 'ro',
    isa      => 'Str',
    required => 1,
);

has created_transaction => (
    is  => 'rw',
    isa => 'RT::Transaction',
);

sub post_is_create            { 1 }
sub create_path_after_handler { 1 }
sub allowed_methods           { ['POST'] }
sub charsets_provided         { [ 'utf-8' ] }
sub default_charset           { 'utf-8' }
sub content_types_provided    { [ { 'application/json' => sub {} } ] }
sub content_types_accepted    { [ { 'text/plain' => 'add_message' }, { 'text/html' => 'add_message' }, { 'application/json' => 'from_json' }, { 'multipart/form-data' => 'from_multipart' } ] }

sub from_multipart {
    my $self = shift;
    my $json_str = $self->request->parameters->{JSON};
    return error_as_json(
        $self->response,
        \400, "JSON is a required field for multipart/form-data")
            unless $json_str;

    my $json = JSON::decode_json($json_str);

    my @attachments = $self->request->upload('Attachments');
    foreach my $attachment (@attachments) {
        open my $filehandle, '<', $attachment->tempname;
        if (defined $filehandle && length $filehandle) {
            my ( @content, $buffer );
            while ( my $bytesread = read( $filehandle, $buffer, 72*57 ) ) {
                push @content, MIME::Base64::encode_base64($buffer);
            }
            close $filehandle;

            push @{$json->{Attachments}},
                {
                    FileName    => $attachment->filename,
                    FileType    => $attachment->headers->{'content-type'},
                    FileContent => join("\n", @content),
                };
        }
    }

    return $self->from_json($json);
}

sub from_json {
    my $self = shift;
    my $body = shift || JSON::decode_json( $self->request->content );

    if ($body->{Attachments}) {
        foreach my $attachment (@{$body->{Attachments}}) {
            foreach my $field ('FileName', 'FileType', 'FileContent') {
                return error_as_json(
                    $self->response,
                    \400, "$field is a required field for each attachment in Attachments")
                unless $attachment->{$field};
            }
        }

        $body->{NoContent} = 1 unless $body->{Content};
    }

    if (!$body->{NoContent} && !$body->{ContentType}) {
        return error_as_json(
            $self->response,
            \400, "ContentType is a required field for application/json");
    }

    $self->add_message(%$body);
}

sub add_message {
    my $self = shift;
    my %args = @_;
    my @results;

    my $MIME = HTML::Mason::Commands::MakeMIMEEntity(
        Interface => 'REST',
        $args{NoContent} ? () : (Body => $args{Content} || $self->request->content),
        Type      => $args{ContentType} || $self->request->content_type,
        Subject   => $args{Subject},
    );

    # Process attachments
    foreach my $attachment (@{$args{Attachments}}) {
        $MIME->attach(
            Type => $attachment->{FileType},
            Filename => $attachment->{FileName},
            Data => MIME::Base64::decode_base64($attachment->{FileContent}),
        );
    }

    my ( $Trans, $msg, $TransObj );
    if ($self->type eq 'correspond') {
        ( $Trans, $msg, $TransObj ) = $self->record->Correspond(
            MIMEObj   => $MIME,
            TimeTaken => ($args{TimeTaken} || 0),
        );
    }
    elsif ($self->type eq 'comment') {
        ( $Trans, $msg, $TransObj ) = $self->record->Comment(
            MIMEObj   => $MIME,
            TimeTaken => ($args{TimeTaken} || 0),
        );
    }
    else {
        return \400;
    }

    if (!$Trans) {
        return error_as_json(
            $self->response,
            \400, $msg || "Message failed for unknown reason");
    }

    push @results, $msg;
    push @results, update_custom_fields($self->record, $args{CustomFields});
    push @results, $self->_update_txn_custom_fields( $TransObj, $args{TxnCustomFields} || $args{TransactionCustomFields} );

    $self->created_transaction($TransObj);
    $self->response->body(JSON::to_json(\@results, { pretty => 1 }));

    return 1;
}

sub _update_txn_custom_fields {
    my $self = shift;
    my $TransObj = shift;
    my $TxnCustomFields = shift;
    my @results;

    # generate a hash suitable for UpdateCustomFields
    # ie the keys are the "full names" of the custom fields
    my %txn_custom_fields;

    foreach my $cf_name ( keys %{$TxnCustomFields} ) {
        my $cf_obj = $TransObj->LoadCustomFieldByIdentifier($cf_name);

        unless ( $cf_obj and $cf_obj->Id ) {
            RT->Logger->error( "Unable to load transaction custom field: $cf_name" );
            push @results, "Unable to load transaction custom field: $cf_name";
            next;
        }

        my $txn_input_name = RT::Interface::Web::GetCustomFieldInputName(
                             CustomField => $cf_obj,
                             Grouping    => undef
        );

        $txn_custom_fields{$txn_input_name} = $TxnCustomFields->{$cf_name};
    }

    # UpdateCustomFields currently doesn't return messages on updates
    # Stub it out for now.
    my @return = $TransObj->UpdateCustomFields( %txn_custom_fields );

    if ( keys %txn_custom_fields ) {
        # Simulate return messages until we get real results
        if ( @return && $return[0] == 1 ) {
            push @results, 'Custom fields updated';
        }
    }

    return @results;
}

sub create_path {
    my $self = shift;
    my $id = $self->created_transaction->Id;
    return "/transaction/$id";
}

__PACKAGE__->meta->make_immutable;

1;

