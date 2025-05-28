# BEGIN BPS TAGGED BLOCK {{{
#
# COPYRIGHT:
#
# This software is Copyright (c) 1996-2025 Best Practical Solutions, LLC
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

# Portions Copyright 2000 Tobias Brox <tobix@cpan.org> 

=head1 NAME

  RT::Template - RT's template object

=head1 SYNOPSIS

  use RT::Template;

=head1 DESCRIPTION


=head1 METHODS


=cut


package RT::Template;

use strict;
use warnings;

use base 'RT::Record';
use Role::Basic 'with';
with "RT::Record::Role::LookupType";

use RT::Queue;

use Text::Template;
use MIME::Entity;
use MIME::Parser;
use Scalar::Util 'blessed';
use RT::Interface::Web;

sub _Accessible {
    my $self = shift;
    my %Cols = (
        id            => 'read',
        Name          => 'read/write',
        Description   => 'read/write',
        Type          => 'read/write',    #Type is one of Perl or Simple
        Content       => 'read/write',
        ObjectId      => 'read/write',
        LookupType    => 'read/write',
        Creator       => 'read/auto',
        Created       => 'read/auto',
        LastUpdatedBy => 'read/auto',
        LastUpdated   => 'read/auto'
    );
    return $self->SUPER::_Accessible( @_, %Cols );
}

sub _Set {
    my $self = shift;
    my %args = (
        Field => undef,
        Value => undef,
        @_,
    );
    
    unless ( $self->CurrentUserHasObjectRight('ModifyTemplate') ) {
        return ( 0, $self->loc('Permission Denied') );
    }

    if (exists $args{Value}) {
        if ($args{Field} eq 'ObjectId') {
            if ($args{Value}) {
                # moving to another object
                my $class = $self->RecordClassFromLookupType( $self->LookupType );
                my $object = $class->new( $self->CurrentUser );
                $class->Load($args{Value});
                unless ($object->Id and $object->CurrentUserHasRight('ModifyTemplate')) {
                    return ( 0, $self->loc('Permission Denied') );
                }
            } else {
                # moving to global
                unless ($self->CurrentUser->HasRight( Object => RT->System, Right => 'ModifyTemplate' )) {
                    return ( 0, $self->loc('Permission Denied') );
                }
            }
        }
    }

    return $self->SUPER::_Set( @_ );
}

=head2 _Value

Takes the name of a table column. Returns its value as a string,
if the user passes an ACL check, otherwise returns undef.

=cut

sub _Value {
    my $self  = shift;

    unless ( $self->CurrentUserCanRead() ) {
        return undef;
    }
    return $self->__Value( @_ );

}

=head2 Load <identifier>

Load a template, either by number or by name.

Note that loading templates by name using this method B<is
ambiguous>. Several queues may have template with the same name
and as well global template with the same name may exist.
Use L</LoadByName>, L</LoadGlobalTemplate> or L<LoadObjectTemplate> to get
precise result.

=cut

sub Load {
    my $self       = shift;
    my $identifier = shift;
    return undef unless $identifier;

    if ( $identifier =~ /\D/ ) {
        return $self->LoadByCol( 'Name', $identifier );
    }
    return $self->LoadById( $identifier );
}

=head2 LoadByName

Takes Name, LookupType, and ObjectId arguments. Tries to load object specific template
first, then global. If ObjectId argument is omitted then global template
is tried, not template with the name in any object.

=cut

sub LoadByName {
    my $self = shift;
    my %args = (
        ObjectId   => undef,
        Name       => undef,
        LookupType => RT::Ticket->CustomFieldLookupType,
        @_
    );

    # Backwards compatibility
    my $queue = $args{'Queue'};
    if ( blessed $queue ) {
        $queue = $queue->id;
    } elsif ( defined $queue and $queue =~ /\D/ ) {
        my $tmp = RT::Queue->new( $self->CurrentUser );
        $tmp->Load($queue);
        $queue = $tmp->id;
    }

    $args{ObjectId} //= $queue;

    if ( $args{ObjectId} ) {
        $self->LoadObjectTemplate(
            ObjectId   => $args{ObjectId},
            Name       => $args{'Name'},
            LookupType => $args{LookupType},
        );
        return $self->id if $self->id;
    }

    $self->LoadGlobalTemplate( $args{'Name'}, $args{LookupType} );
    return $self->id if $self->id;
}

=head2 LoadGlobalTemplate NAME LOOKUPTYPE

Load the global template with the name NAME and LookupType LOOKUPTYPE.

=cut

sub LoadGlobalTemplate {
    my $self = shift;
    my $name = shift;
    my $type = shift || RT::Ticket->CustomFieldLookupType;

    return ( $self->LoadObjectTemplate( ObjectId => 0, Name => $name, LookupType => $type ) );
}

=head2 LoadObjectTemplate (ObjectId => QUEUEID, Name => NAME, LookupType => LOOKUPTYPE)

Loads the Object template named NAME for Object QUEUE.

Note that this method doesn't load a global template with the same name
if template in the object doesn't exist. Use L</LoadByName>.

=cut

sub LoadObjectTemplate {
    my $self = shift;
    my %args = (
        ObjectId   => undef,
        Name       => undef,
        LookupType => RT::Ticket->CustomFieldLookupType,
        @_
    );

    return (
        $self->LoadByCols(
            Name       => $args{'Name'},
            ObjectId   => $args{'ObjectId'},
            LookupType => $args{'LookupType'},
        )
    );
}

sub LoadQueueTemplate {
    my $self = shift;
    RT->Deprecated(
        Message => 'LoadQueueTemplate is deprecated',
        Instead => 'LoadObjectTemplate',
        Remove  => 6.2,
    );
    my %args = @_;
    $args{ObjectId} //= delete $args{Queue};
    return $self->LoadObjectTemplate(%args);
}

=head2 Create

Takes a paramhash of Content, Object, LookupType, Name, and Description.
Name should be a unique string identifying this Template.
Description and Content should be the template's title and content.
ObjectId should be 0 for a global template and the object id for a object-specific 
template.

Returns the Template's id # if the create was successful. Returns undef for
unknown database failure.

=cut

sub Create {
    my $self = shift;
    my %args = (
        Content     => undef,
        ObjectId    => undef,
        Description => '[no description]',
        Type        => 'Perl',
        Name        => undef,
        LookupType  => 'RT::Queue-RT::Ticket',
        @_
    );

    # Backwards compatibility
    $args{ObjectId} //= $args{Queue};

    if ( $args{Type} eq 'Perl' && !$self->CurrentUser->HasRight(Right => 'ExecuteCode', Object => $RT::System) ) {
        return ( undef, $self->loc('Permission Denied') );
    }

    unless ( $args{'ObjectId'} ) {
        unless ( $self->CurrentUser->HasRight(Right =>'ModifyTemplate', Object => $RT::System) ) {
            return ( undef, $self->loc('Permission Denied') );
        }
        $args{'ObjectId'} = 0;
    }
    else {
        my $class = $self->RecordClassFromLookupType( $args{'LookupType'} );
        my $object = $class->new( $self->CurrentUser );
        $object->Load( $args{'ObjectId'} ) || return ( undef, $self->loc('Invalid ObjectId') );
    
        unless ( $object->CurrentUserHasRight('ModifyTemplate') ) {
            return ( undef, $self->loc('Permission Denied') );
        }
        $args{'ObjectId'} = $object->Id;
    }

    return ( undef, $self->loc('Name is required') )
        unless $args{Name};

    {
        my $tmp = $self->new( RT->SystemUser );
        $tmp->LoadByCols( Name => $args{'Name'}, ObjectId => $args{'ObjectId'}, LookupType => $args{'LookupType'} );
        return ( undef, $self->loc('A Template with that name already exists') )
            if $tmp->id;
    }

    my ( $result, $msg ) = $self->SUPER::Create(
        Content     => $args{'Content'},
        ObjectId    => $args{'ObjectId'},
        Description => $args{'Description'},
        Name        => $args{'Name'},
        Type        => $args{'Type'},
        LookupType  => $args{'LookupType'},
    );

    if ( wantarray ) {
        return ( $result, $msg );
    } else {
        return ( $result );
    }

}

=head2 Delete

Delete this template.

=cut

sub Delete {
    my $self = shift;

    unless ( $self->CurrentUserHasObjectRight('ModifyTemplate') ) {
        return ( 0, $self->loc('Permission Denied') );
    }

    if ( !$self->IsOverride && $self->UsedBy->Count ) {
        return ( 0, $self->loc('Template is in use') );
    }

    return ( $self->SUPER::Delete(@_) );
}

=head2 UsedBy

Returns L<RT::Scrips> limited to scrips that use this template. Takes
into account that template can be overridden in a queue.

=cut

sub UsedBy {
    my $self = shift;

    my $scrips = RT::Scrips->new( $self->CurrentUser );
    $scrips->LimitByTemplate( $self );
    return $scrips;
}

=head2 IsEmpty

Returns true value if content of the template is empty, otherwise
returns false.

=cut

sub IsEmpty {
    my $self = shift;
    my $content = $self->Content;
    return 0 if defined $content && length $content;
    return 1;
}

=head2 IsOverride

Returns true if it's object specific template and there is global
template with the same name.

=cut

sub IsOverride {
    my $self = shift;
    return 0 unless $self->ObjectId;

    my $template = RT::Template->new( $self->CurrentUser );
    $template->LoadGlobalTemplate( $self->Name, $self->LookupType );
    return $template->id;
}


=head2 MIMEObj

Returns L<MIME::Entity> object parsed using L</Parse> method. Returns
undef if last call to L</Parse> failed or never be called.

Note that content of the template is characters, but the contents of all
L<MIME::Entity> objects (including the one returned by this function,
are bytes in UTF-8.

=cut

sub MIMEObj {
    my $self = shift;
    return ( $self->{'MIMEObj'} );
}

=head2 Parse

This routine performs L<Text::Template> parsing on the template and then
imports the results into a L<MIME::Entity> so we can really use it. Use
L</MIMEObj> method to get the L<MIME::Entity> object.

Takes a hash containing Argument, TicketObj, and TransactionObj and other
arguments that will be available in the template's code. TicketObj and
TransactionObj are not mandatory, but highly recommended.

It returns a tuple of (val, message). If val is false, the message contains
an error message.

=cut

sub Parse {
    my $self = shift;
    my ($rv, $msg);

    delete $self->{_AddedAttachments};

    if (not $self->IsEmpty and $self->Content =~ m{^Content-Type:\s+text/html\b}im) {
        local $RT::Transaction::PreferredContentType = 'text/html';
        ($rv, $msg) = $self->_Parse(@_);
    }
    else {
        ($rv, $msg) = $self->_Parse(@_);
    }

    return ($rv, $msg) unless $rv;

    my %args = @_;
    my $mime_type   = $self->MIMEObj->mime_type;
    if ( defined $mime_type and $mime_type eq 'text/html' and $args{TransactionObj} ) {
        if ( my $content_obj = $args{TransactionObj}->ContentObj( Type => 'text/html' ) ) {
            if ( my $related_part = $content_obj->Closest("multipart/related") ) {
                my $body = Encode::decode( "UTF-8", $self->MIMEObj->bodyhandle->as_string );
                my ( @attachments, %added );
                require HTML::RewriteAttributes::Resources;
                HTML::RewriteAttributes::Resources->rewrite(
                    $body,
                    sub {
                        my $cid  = shift;
                        my %meta = @_;
                        return $cid unless lc $meta{tag} eq 'img' && lc $meta{attr} eq 'src' && $cid =~ s/^cid://i;

                        for my $attach ( @{$related_part->Children->ItemsArrayRef } ) {
                            if ( ( $attach->GetHeader('Content-ID') || '' ) =~ /^(<)?\Q$cid\E(?(1)>)$/ ) {
                                push @attachments, $attach unless $added{$attach->Id}++;
                            }
                        }

                        return "cid:$cid";
                    }
                );

                if ( @attachments ) {
                    $self->MIMEObj->make_multipart('related');
                    # RFC2387 3.1 says that "type" must be specified
                    $self->MIMEObj->head->mime_attr('Content-type.type' => 'text/html');
                    for my $attach ( @attachments ) {
                        $self->MIMEObj->attach(
                            Type        => $attach->ContentType,
                            Disposition => $attach->GetHeader('Content-Disposition'),
                            Id          => $attach->GetHeader('Content-ID'),
                            Data        => $attach->OriginalContent,
                        );
                    }
                    $self->{_AddedAttachments} = { map { $_->Id => 1 } @attachments };
                }
            }
        }
        $self->_DowngradeFromHTML(@_);
    }

    return ($rv, $msg);
}

sub _Parse {
    my $self = shift;

    # clear prev MIME object
    $self->{'MIMEObj'} = undef;

    #We're passing in whatever we were passed. it's destined for _ParseContent
    my ($content, $msg) = $self->_ParseContent(@_);
    return ( 0, $msg ) unless defined $content && length $content;

    if ( $content =~ /^\S/s && $content !~ /^\S+:/ ) {
        $RT::Logger->error(
            "Template #". $self->id ." has leading line that doesn't"
            ." look like header field, if you don't want to override"
            ." any headers and don't want to see this error message"
            ." then leave first line of the template empty"
        );
        $content = "\n".$content;
    }

    my $parser = MIME::Parser->new();
    $parser->output_to_core(1);
    $parser->tmp_to_core(1);
    $parser->use_inner_files(1);

    ### Should we forgive normally-fatal errors?
    $parser->ignore_errors(1);
    # Always provide bytes, not characters, to MIME objects
    $content = Encode::encode( 'UTF-8', $content );
    $self->{'MIMEObj'} = eval { $parser->parse_data( \$content ) };
    if ( my $error = $@ || $parser->last_error ) {
        $RT::Logger->error( "$error" );
        return ( 0, $error );
    }

    # Unfold all headers
    $self->{'MIMEObj'}->head->unfold;
    $self->{'MIMEObj'}->head->modify(1);

    return ( 1, $self->loc("Template parsed") );

}

# Perform Template substitutions on the template

sub _ParseContent {
    my $self = shift;
    my %args = (
        Argument       => undef,
        Object         => undef,
        TicketObj      => undef,
        AssetObj       => undef,
        ArticleObj     => undef,
        TransactionObj => undef,
        @_
    );

    unless ( $self->CurrentUserCanRead() ) {
        return (undef, $self->loc("Permission Denied"));
    }

    if ( $self->IsEmpty ) {
        return ( undef, $self->loc("Template is empty") );
    }

    my $content = $self->SUPER::_Value('Content');

    for my $field ( qw/Ticket Asset Article/ ) {
        $args{$field} = delete $args{"${field}Obj"} if $args{"${field}Obj"};
    }
    $args{'Transaction'} = delete $args{'TransactionObj'} if $args{'TransactionObj'};
    $args{'Requestor'} = eval { $args{'Ticket'}->Requestors->UserMembersObj->First->Name }
        if $args{'Ticket'};
    $args{'rtname'}    = RT->Config->Get('rtname');
    if ( $args{'Ticket'} || $args{'Asset'} || $args{'Article'} ) {
        my $t = $args{'Ticket'} || $args{'Asset'} || $args{'Article'}; # avoid memory leak
        $args{'loc'} = sub { $t->loc(@_) };
    } else {
        $args{'loc'} = sub { $self->loc(@_) };
    }

    $args{'EscapeURI'} = sub {
        my $str = shift;
        RT::Interface::Web::EscapeURI( \$str );
        return $str;
    };

    $args{'EscapeHTML'} = sub {
        my $str = shift;
        RT::Interface::Web::EscapeHTML( \$str );
        return $str;
    };

    if ($self->Type eq 'Perl') {
        return $self->_ParseContentPerl(
            Content      => $content,
            TemplateArgs => \%args,
        );
    }
    else {
        return $self->_ParseContentSimple(
            Content      => $content,
            TemplateArgs => \%args,
        );
    }
}

# uses Text::Template for Perl templates
sub _ParseContentPerl {
    my $self = shift;
    my %args = (
        Content      => undef,
        TemplateArgs => {},
        @_,
    );

    foreach my $key ( keys %{ $args{TemplateArgs} } ) {
        my $val = $args{TemplateArgs}{ $key };
        next unless ref $val;
        next if ref($val) =~ /^(ARRAY|HASH|SCALAR|CODE)$/;
        $args{TemplateArgs}{ $key } = \$val;
    }

    my $template = Text::Template->new(
        TYPE   => 'STRING',
        SOURCE => $args{Content},
    );
    my ($ok) = $template->compile;
    unless ($ok) {
        $RT::Logger->error("Template parsing error in @{[$self->Name]} (#@{[$self->id]}): $Text::Template::ERROR");
        return ( undef, $self->loc('Template parsing error: [_1]', $Text::Template::ERROR) );
    }

    my $is_broken = 0;
    my $retval = $template->fill_in(
        HASH => $args{TemplateArgs},
        BROKEN => sub {
            my (%args) = @_;
            $RT::Logger->error("Template parsing error: $args{error}")
                unless $args{error} =~ /^Died at /; # ignore intentional die()
            $is_broken++;
            return undef;
        },
    );
    return ( undef, $self->loc('Template parsing error') ) if $is_broken;

    return ($retval);
}

sub _ParseContentSimple {
    my $self = shift;
    my %args = (
        Content      => undef,
        TemplateArgs => {},
        @_,
    );

    $self->_MassageSimpleTemplateArgs(%args);

    my $template = Text::Template->new(
        TYPE   => 'STRING',
        SOURCE => $args{Content},
    );
    my ($ok) = $template->compile;
    return ( undef, $self->loc('Template parsing error: [_1]', $Text::Template::ERROR) ) if !$ok;

    # copied from Text::Template::fill_in and refactored to be simple variable
    # interpolation
    my $fi_r = '';
    foreach my $fi_item (@{$template->{SOURCE}}) {
        my ($fi_type, $fi_text, $fi_lineno) = @$fi_item;
        if ($fi_type eq 'TEXT') {
            $fi_r .= $fi_text;
        } elsif ($fi_type eq 'PROG') {
            my $fi_res;
            my $original_fi_text = $fi_text;

            # strip surrounding whitespace for simpler regexes
            $fi_text =~ s/^\s+//;
            $fi_text =~ s/\s+$//;

            # if the codeblock is a simple $Variable lookup, use the value from
            # the TemplateArgs hash...
            if (my ($var) = $fi_text =~ /^\$(\w+)$/) {
                if (exists $args{TemplateArgs}{$var}) {
                    $fi_res = $args{TemplateArgs}{$var};
                }
            }

            # if there was no substitution then just reinsert the codeblock
            if (!defined $fi_res) {
                $fi_res = "{$original_fi_text}";
            }

            # If the value of the filled-in text really was undef,
            # change it to an explicit empty string to avoid undefined
            # value warnings later.
            $fi_res = '' unless defined $fi_res;

            $fi_r .= $fi_res;
        }
    }

    return $fi_r;
}

sub _MassageSimpleTemplateArgs {
    my $self = shift;
    my %args = (
        TemplateArgs => {},
        @_,
    );

    my $template_args = $args{TemplateArgs};

    if (my $ticket = $template_args->{Ticket}) {
        for my $column (qw/Id Subject Description Type InitialPriority FinalPriority Priority TimeEstimated TimeWorked Status TimeLeft Told Starts Started Due Resolved RequestorAddresses AdminCcAddresses CcAddresses/) {
            $template_args->{"Ticket".$column} = $ticket->$column;
        }

        $template_args->{"TicketQueueId"}   = $ticket->Queue;
        $template_args->{"TicketQueueName"} = $ticket->QueueObj->Name;

        $template_args->{"TicketOwnerId"}    = $ticket->Owner;
        $template_args->{"TicketOwnerName"}  = $ticket->OwnerObj->Name;
        $template_args->{"TicketOwnerEmailAddress"} = $ticket->OwnerObj->EmailAddress;

        my $cfs = $ticket->CustomFields;
        while (my $cf = $cfs->Next) {
            my $simple = $cf->Name;
            $simple =~ s/\W//g;
            $template_args->{"TicketCF" . $simple}
                = $ticket->CustomFieldValuesAsString($cf->Name);
        }
    }

    if (my $ticket = $template_args->{Ticket}) {
        for my $column (qw/Id Subject Type InitialPriority FinalPriority Priority TimeEstimated TimeWorked Status TimeLeft Told Starts Started Due Resolved RequestorAddresses AdminCcAddresses CcAddresses/) {
            $template_args->{"Ticket".$column} = $ticket->$column;
        }

        $template_args->{"TicketQueueId"}   = $ticket->Queue;
        $template_args->{"TicketQueueName"} = $ticket->QueueObj->Name;

        $template_args->{"TicketOwnerId"}    = $ticket->Owner;
        $template_args->{"TicketOwnerName"}  = $ticket->OwnerObj->Name;
        $template_args->{"TicketOwnerEmailAddress"} = $ticket->OwnerObj->EmailAddress;

        my $cfs = $ticket->CustomFields;
        while (my $cf = $cfs->Next) {
            my $simple = $cf->Name;
            $simple =~ s/\W//g;
            $template_args->{"TicketCF" . $simple}
                = $ticket->CustomFieldValuesAsString($cf->Name);
        }
    }

    if ( my $asset = $template_args->{Asset} ) {
        for my $column (qw/Id Name Description Status/) {
            $template_args->{ "Asset" . $column } = $asset->$column;
        }

        $template_args->{"AssetCatalogId"}   = $asset->Catalog;
        $template_args->{"AssetCatalogName"} = $asset->CatalogObj->Name;

        my $cfs = $asset->CustomFields;
        while ( my $cf = $cfs->Next ) {
            my $simple = $cf->Name;
            $simple =~ s/\W//g;
            $template_args->{ "AssetCF" . $simple } = $asset->CustomFieldValuesAsString( $cf->Name );
        }
    }

    if ( my $article = $template_args->{Article} ) {
        for my $column (qw/Id Name Summary/) {
            $template_args->{ "Article" . $column } = $article->$column;
        }

        $template_args->{"ArticleClassId"}   = $article->Class;
        $template_args->{"ArticleClassName"} = $article->ClassObj->Name;

        my $cfs = $article->CustomFields;
        while ( my $cf = $cfs->Next ) {
            my $simple = $cf->Name;
            $simple =~ s/\W//g;
            $template_args->{ "AssetCF" . $simple } = $article->CustomFieldValuesAsString( $cf->Name );
        }
    }

    if (my $txn = $template_args->{Transaction}) {
        for my $column (qw/Id TimeTaken Type Field OldValue NewValue Data Content Subject Description BriefDescription/) {
            $template_args->{"Transaction".$column} = $txn->$column;
        }

        my $cfs = $txn->CustomFields;
        while (my $cf = $cfs->Next) {
            my $simple = $cf->Name;
            $simple =~ s/\W//g;
            $template_args->{"TransactionCF" . $simple}
                = $txn->CustomFieldValuesAsString($cf->Name);
        }
    }
}

sub _DowngradeFromHTML {
    my $self = shift;
    my $orig_entity = $self->MIMEObj;

    my $html_entity = $orig_entity->is_multipart ? $orig_entity->parts(0) : $orig_entity;
    my $new_entity = $html_entity->dup; # this will fail badly if we go away from InCore parsing

    # We're going to make this multipart/alternative below, so clear out the Subject
    # header copied from the original when we dup'd above.
    # Alternative parts should have just formatting headers like Content-Type
    # so maybe we should clear all, but staying conservative for now.

    if ( $new_entity->head->get('Subject') ) {
        $new_entity->head->delete('Subject');
    }

    $new_entity->head->mime_attr( "Content-Type" => 'text/plain' );
    $new_entity->head->mime_attr( "Content-Type.charset" => 'utf-8' );

    $html_entity->head->mime_attr( "Content-Type" => 'text/html' );
    $html_entity->head->mime_attr( "Content-Type.charset" => 'utf-8' );

    my $body = $new_entity->bodyhandle->as_string;
    $body = Encode::decode( "UTF-8", $body );
    my $html = RT::Interface::Email::ConvertHTMLToText( $body );
    $html = Encode::encode( "UTF-8", $html );
    return unless defined $html;

    $new_entity->bodyhandle(MIME::Body::InCore->new( \$html ));

    $orig_entity->make_multipart('alternative', Force => 1);
    $orig_entity->add_part($new_entity, 0); # plain comes before html
    $self->{MIMEObj} = $orig_entity;

    return;
}

=head2 CurrentUserHasObjectRight

Helper function to call the template's object's CurrentUserHasRight with the passed in args.

=cut

sub CurrentUserHasObjectRight {
    my $self = shift;
    return ( $self->Object->CurrentUserHasRight(@_) );
}

sub CurrentUserHasQueueRight {
    my $self = shift;
    RT->Deprecated(
        Message => 'CurrentUserHasQueueRight is deprecated',
        Instead => 'CurrentUserHasObjectRight',
        Remove  => 6.2,
    );
    return $self->CurrentUserHasObjectRight(@_);
}

=head2 SetObjectId

Changing ObjectId is not implemented.

=cut

sub SetObjectId {
    my $self = shift;
    return ( undef, $self->loc('Changing ObjectId is not implemented') );
}

=head2 SetName

Change name of the template.

=cut

sub SetName {
    my $self = shift;
    my $value = shift;

    return ( undef, $self->loc('Name is required') )
        unless $value;

    return $self->_Set( Field => 'Name', Value => $value )
        if lc($self->Name) eq lc($value);

    my $tmp = $self->new( RT->SystemUser );
    $tmp->LoadByCols( Name => $value, ObjectId => $self->ObjectId, LookupType => $self->LookupType );
    return ( undef, $self->loc('A Template with that name already exists') )
        if $tmp->id;

    return $self->_Set( Field => 'Name', Value => $value );
}

=head2 SetType

If setting Type to Perl, require the ExecuteCode right.

=cut

sub SetType {
    my $self    = shift;
    my $NewType = shift;

    if ($NewType eq 'Perl' && !$self->CurrentUser->HasRight(Right => 'ExecuteCode', Object => $RT::System)) {
        return ( undef, $self->loc('Permission Denied') );
    }

    return $self->_Set( Field => 'Type', Value => $NewType );
}

=head2 SetContent

If changing content and the type is Perl, require the ExecuteCode right.

=cut

sub SetContent {
    my $self       = shift;
    my $NewContent = shift;

    if ($self->Type eq 'Perl' && !$self->CurrentUser->HasRight(Right => 'ExecuteCode', Object => $RT::System)) {
        return ( undef, $self->loc('Permission Denied') );
    }

    return $self->_Set( Field => 'Content', Value => $NewContent );
}

sub _UpdateAttributes {
    my $self = shift;
    my %args = (
        NewValues => {},
        @_,
    );

    my $type = $args{NewValues}{Type} || $self->Type;

    # forbid updating content when the (possibly new) value of Type is Perl
    if ($type eq 'Perl' && exists $args{NewValues}{Content}) {
        if (!$self->CurrentUser->HasRight(Right => 'ExecuteCode', Object => $RT::System)) {
            return $self->loc('Permission Denied');
        }
    }

    return $self->SUPER::_UpdateAttributes(%args);
}

=head2 CompileCheck

If the template's Type is Perl, then compile check all the codeblocks to see if
they are syntactically valid. We eval them in a codeblock to avoid actually
executing the code.

Returns an (ok, message) pair.

=cut

sub CompileCheck {
    my $self = shift;

    return (1, $self->loc("Template does not include Perl code"))
        unless $self->Type eq 'Perl';

    my $content = $self->Content;
    $content = '' if !defined($content);

    my $template = Text::Template->new(
        TYPE   => 'STRING',
        SOURCE => $content,
    );
    my ($ok) = $template->compile;
    return ( undef, $self->loc('Template parsing error: [_1]', $Text::Template::ERROR) ) if !$ok;

    # copied from Text::Template::fill_in and refactored to be compile checks
    foreach my $fi_item (@{$template->{SOURCE}}) {
        my ($fi_type, $fi_text, $fi_lineno) = @$fi_item;
        next unless $fi_type eq 'PROG';

        do {
            no strict 'vars';
            eval "sub { $fi_text }";
        };
        next if !$@;

        my $error = $@;

        # provide a (hopefully) useful line number for the error, but clean up
        # all the other extraneous garbage
        $error =~ s/\(eval \d+\) line (\d+).*/"template line " . ($1+$fi_lineno-1)/es;

        return (0, $self->loc("Couldn't compile template codeblock '[_1]': [_2]", $fi_text, $error));
    }

    return (1, $self->loc("Template compiles"));
}

=head2 CurrentUserCanRead

=cut

sub CurrentUserCanRead {
    my $self = shift;
    return 1 if $self->CurrentUser->Id == RT->SystemUser->id;

    if ($self->__Value('ObjectId')) {
        my $class = $self->RecordClassFromLookupType( $self->__Value('LookupType') );
        my $object = $class->new( RT->SystemUser );
        $object->Load( $self->__Value('ObjectId'));
        return 1 if $self->CurrentUser->HasRight( Right => 'ShowTemplate', Object => $object );
    } else {
        return 1 if $self->CurrentUser->HasRight( Right => 'ShowGlobalTemplates', Object => $RT::System );
        return 1 if $self->CurrentUser->HasRight( Right => 'ShowTemplate',        Object => $RT::System );
    }

    return;
}

1;

sub Table {'Templates'}






=head2 id

Returns the current value of id.
(In the database, id is stored as int(11).)


=cut


=head2 ObjectId

Returns the current value of ObjectId.
(In the database, ObjectId is stored as int(11).)

=cut


=head2 Object

Returns the Object which has the id returned by ObjectId

=cut

sub Object {
    my $self = shift;
    my $class = $self->RecordClassFromLookupType( $self->LookupType );
    my $object = $class->new($self->CurrentUser);
    $object->Load($self->__Value('ObjectId'));
    return $object;
}

sub QueueObj {
    my $self = shift;
    RT->Deprecated(
        Message => 'QueueObj is deprecated',
        Instead => 'Object',
        Remove  => 6.2,
    );
    return $self->Object;
}

=head2 Name

Returns the current value of Name.
(In the database, Name is stored as varchar(200).)



=head2 SetName VALUE


Set Name to VALUE.
Returns (1, 'Status message') on success and (0, 'Error Message') on failure.
(In the database, Name will be stored as a varchar(200).)


=cut


=head2 Description

Returns the current value of Description.
(In the database, Description is stored as varchar(255).)



=head2 SetDescription VALUE


Set Description to VALUE.
Returns (1, 'Status message') on success and (0, 'Error Message') on failure.
(In the database, Description will be stored as a varchar(255).)


=cut


=head2 Type

Returns the current value of Type.
(In the database, Type is stored as varchar(16).)



=head2 SetType VALUE


Set Type to VALUE.
Returns (1, 'Status message') on success and (0, 'Error Message') on failure.
(In the database, Type will be stored as a varchar(16).)


=cut


=head2 Content

Returns the current value of Content.
(In the database, Content is stored as text.)



=head2 SetContent VALUE


Set Content to VALUE.
Returns (1, 'Status message') on success and (0, 'Error Message') on failure.
(In the database, Content will be stored as a text.)


=cut

=head2 LookupType

Returns the current value of LookupType.
(In the database, LookupType is stored as varchar(255).)

=cut

=head2 LastUpdated

Returns the current value of LastUpdated.
(In the database, LastUpdated is stored as datetime.)


=cut


=head2 LastUpdatedBy

Returns the current value of LastUpdatedBy.
(In the database, LastUpdatedBy is stored as int(11).)


=cut


=head2 Creator

Returns the current value of Creator.
(In the database, Creator is stored as int(11).)


=cut


=head2 Created

Returns the current value of Created.
(In the database, Created is stored as datetime.)


=cut



sub _CoreAccessible {
    {

        id =>
                {read => 1, sql_type => 4, length => 11,  is_blob => 0,  is_numeric => 1,  type => 'int(11)', default => ''},
        ObjectId =>
                {read => 1, write => 1, sql_type => 4, length => 11,  is_blob => 0,  is_numeric => 1,  type => 'int(11)', default => '0'},
        Name =>
                {read => 1, write => 1, sql_type => 12, length => 200,  is_blob => 0,  is_numeric => 0,  type => 'varchar(200)', default => ''},
        Description =>
                {read => 1, write => 1, sql_type => 12, length => 255,  is_blob => 0,  is_numeric => 0,  type => 'varchar(255)', default => ''},
        Type =>
                {read => 1, write => 1, sql_type => 12, length => 16,  is_blob => 0,  is_numeric => 0,  type => 'varchar(16)', default => ''},
        Content =>
                {read => 1, write => 1, sql_type => -4, length => 0,  is_blob => 1,  is_numeric => 0,  type => 'text', default => ''},
        LookupType =>
                {read => 1, write => 1, sql_type => 12, length => 255,  is_blob => 0,  is_numeric => 0,  type => 'varchar(255)', default => ''},
        LastUpdated =>
                {read => 1, auto => 1, sql_type => 11, length => 0,  is_blob => 0,  is_numeric => 0,  type => 'datetime', default => ''},
        LastUpdatedBy =>
                {read => 1, auto => 1, sql_type => 4, length => 11,  is_blob => 0,  is_numeric => 1,  type => 'int(11)', default => '0'},
        Creator =>
                {read => 1, auto => 1, sql_type => 4, length => 11,  is_blob => 0,  is_numeric => 1,  type => 'int(11)', default => '0'},
        Created =>
                {read => 1, auto => 1, sql_type => 11, length => 0,  is_blob => 0,  is_numeric => 0,  type => 'datetime', default => ''},

 }
};

sub FindDependencies {
    my $self = shift;
    my ($walker, $deps) = @_;

    $self->SUPER::FindDependencies($walker, $deps);

    $deps->Add( out => $self->Object ) if $self->Object->Id;
}

sub __DependsOn {
    my $self = shift;
    my %args = (
        Shredder => undef,
        Dependencies => undef,
        @_,
    );
    my $deps = $args{'Dependencies'};
    my $list = [];

# Scrips
    push( @$list, $self->UsedBy );

    $deps->_PushDependencies(
        BaseObject => $self,
        Flags => RT::Shredder::Constants::DEPENDS_ON,
        TargetObjects => $list,
        Shredder => $args{'Shredder'},
    );

    return $self->SUPER::__DependsOn( %args );
}

sub PreInflate {
    my $class = shift;
    my ($importer, $uid, $data) = @_;

    $class->SUPER::PreInflate( $importer, $uid, $data );

    my $obj = RT::Template->new( RT->SystemUser );
    if ($data->{ObjectId} == 0) {
        $obj->LoadGlobalTemplate( $data->{Name}, $data->{LookupType} || 'RT::Queue-RT::Ticket' );
    } else {
        $obj->LoadObjectTemplate(
            ObjectId   => $data->{ObjectId},
            Name       => $data->{Name},
            LookupType => $data->{LookupType} || 'RT::Queue-RT::Ticket',
        );
    }

    if ($obj->Id) {
        $importer->Resolve( $uid => ref($obj) => $obj->Id );
        return;
    }

    return 1;
}

RT::Base->_ImportOverlays();

1;
