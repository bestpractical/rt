package RT::Extension::REST2::Resource::ObjectCustomFieldValue;
use strict;
use warnings;

use Moose;
use namespace::autoclean;
use RT::Extension::REST2::Util qw( error_as_json );

extends 'RT::Extension::REST2::Resource::Record';
with 'RT::Extension::REST2::Resource::Record::WithETag';

sub dispatch_rules {
    Path::Dispatcher::Rule::Regex->new(
        regex => qr{^/download/cf/(\d+)/?$},
        block => sub { { record_class => 'RT::ObjectCustomFieldValue', record_id => shift->pos(1) } },
    )
}

sub allowed_methods { ['GET', 'HEAD'] }

sub content_types_provided {
    my $self = shift;
    { [ {$self->record->ContentType || 'text/plain; charset=utf-8' => 'to_binary'} ] };
}

sub forbidden {
    my $self = shift;
    return 0 unless $self->record->id;
    return !$self->record->CurrentUserHasRight('SeeCustomField');
}

sub to_binary {
    my $self = shift;
    unless ($self->record->CustomFieldObj->Type =~ /^(?:Image|Binary)$/) {
        return error_as_json(
            $self->response,
            \400, "Only Image and Binary CustomFields can be downloaded");
    }

    my $content_type = $self->record->ContentType || 'text/plain; charset=utf-8';
    if (RT->Config->Get('AlwaysDownloadAttachments')) {
        $self->response->headers_out->{'Content-Disposition'} = "attachment";
    }
    elsif (!RT->Config->Get('TrustHTMLAttachments')) {
        $content_type = 'text/plain; charset=utf-8' if ($content_type =~ /^text\/html/i);
    }

    $self->response->content_type($content_type);

    my $content = $self->record->LargeContent;
    $self->response->content_length(length $content);
    $self->response->body($content);
}

__PACKAGE__->meta->make_immutable;

1;
