# BEGIN BPS TAGGED BLOCK {{{
#
# COPYRIGHT:
#
# This software is Copyright (c) 1996-2011 Best Practical Solutions, LLC
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

package RT::CustomField::Type;
use strict;
use warnings;

=head1 NAME

  RT::CustomField::Type - Custom Field Type definition

=head1 DESCRIPTION

You can define types for RT's custom field.  For example, if you want
to create a type ImageWithCatpion, which consists of an uploaded
image, and an user-entered caption.  You can define how the CF is
stored, displayed, or even searched.

To define a type, you want to register it in your subclass of
L<RT::CustomField::Type>:

  RT::CustomField->RegisterType(
    ImageWithCaption => {
        sort_order => 55,
        selection_type => 0,
        labels         => [
                    'Upload multiple images with caption',   # loc
                    'Upload one image with caption',         # loc
                    'Upload up to [_1] images with caption', # loc
                  ],
        class => 'RT::CustomField::Type::ImageWithCaption',
    }
  );

You should then override the following methods to customize the type-specific behavior.

=head1 methods for storage and display

for storage, per-object custom field values are stored as
L<RT::ObjectCustomFieldValue> objects, and the commonly used fields
are C<ContentType>, C<Content> and C<LargeContent>.

=head2 $class->CanonicalizeForCreate($cf, $ocfv, $args)

Called when the value is being validated or created.  You should
example C<$args> and make modifications before it is passed to
C<RT::ObjectCustomFieldValue-E<gt>Create>.  C<$ocfv> can be used to get
CurrentUser, should you need to access it.

=cut

sub CanonicalizeForCreate {
    my ($self, $cf, $ocfv, $args) = @_;
    return wantarray ? (1) : 1;
}

=head2 $class->Stringify($ocfv)

for displaying the custom field value in summary.  The default
behavior pulls C<Content> if it exists, otherwise C<LargeContent> if
C<ContentType> is text/plain.

=cut

sub Stringify {
    my ($self, $ocfv) = @_;
    my $content = $ocfv->_Value('Content');

    if ( !(defined $content && length $content) && $ocfv->ContentType && $ocfv->ContentType eq 'text/plain' ) {
        return $ocfv->LargeContent;
    } else {
        return $content;
    }
}

=head2 $class->StringifyForDisplay($ocfv)

=cut

sub StringifyForDisplay {
    my ($self, $ocfv) = @_;
    return $self->Stringify($ocfv);
}

=head1 methods for web interaction

The mason component F<share/html/Elements/EditCustomField$TypeName>
will be used for creating or editing a custom field value of type
C<$TypeName>.  F<share/html/Elements/ShowCustomField$TypeName> will be
used for displaying the value.

=head2 $class->CreateArgsFromWebArgs($cf, $web_args)

This is used for processing cf values when creating a new ticket.

The C<$web_args> are the form values without prefix, from the type's
corresponding form.

The value returned will be used as the value of the cf when calling
C<RT::Ticket-E<gt>Create>.  An entry or an arrayref of entries can be
returned.  Each entry can be a plaintext value, or a hashref for
creating L<RT::ObjectCustomFieldValue> where the C<Content> field
should be passed in as C<Value>, for historical reasons.

=cut

sub CreateArgsFromWebArgs {
    my ($self, $cf, $web_args) = @_;

    for my $arg (keys %$web_args) {
        next if $arg =~ /^(?:Magic|Category)$/;

        if ( $arg eq 'Upload'  && $web_args->{$arg}) {
            return HTML::Mason::Commands::_UploadedFileArgs($web_args->{Upload});
        }

        return [$self->ValuesFromWeb($cf, $web_args->{$arg})];
    }
}


=head2 ValuesFromWeb C<$args>

Helper method for parsing the args passed in from web.

=cut

sub ValuesFromWeb {
    my ($self, $cf, $args) = @_;

    my $type = $cf->Type || '';

    my @values = ();
    if ( ref $args eq 'ARRAY' ) {
        @values = @$args;
    } elsif ( $type =~ /text/i ) {    # Both Text and Wikitext
        @values = $args;
    } else {
        @values = split /\r*\n/, $args if defined $args;
    }
    return grep length, map {
        s/\r+\n/\n/g;
        s/^\s+//;
        s/\s+$//;
        $_;
    } grep defined, @values;
}

=head1 methods for search and search builder

By default the search behavor works on the custom field value's
C<Content>, and provides some default op for the user to choose from
in the search builder.  If you want to perform different types of
search, you need to override some of the methods here.

=head2 $class->CanonicalizeForSearch($cf, $value, $op)

Canonicalize user-entered value for searching.

=cut

sub CanonicalizeForSearch {
    my ($self, $cf, $value, $op ) = @_;
    return $value;
}

=head2 $class->Limit($tickets, $field, $value, $op, %rest)

If you want to perform search other than simple C<==> and C<!=> on
C<Content> of the custom field value, you need to write your own
DBIx::SearchBuilder rules here.  see
L<RT::CustomField::Type::IPAddressRange> for examples.

=cut

sub Limit {
    return;
}

=head2 $class->SearchBuilderUIArguments($cf)

Returns a hash where key C<Op> is a hashref of spec for the mason
component for showing operators in search builder, and optionally key
C<Value> for mason conponents for entering/selecting values during
search.

=cut

sub SearchBuilderUIArguments {
    my ($self, $cf) = @_;

    return (
        Op => {
            Type => 'component',
            Path => '/Elements/SelectCustomFieldOperator',
            Arguments => { True => $cf->loc("is"),
                           False => $cf->loc("isn't"),
                           TrueVal=> '=',
                           FalseVal => '!=',
                       },
        },
        Value => {
            Type => 'component',
            Path => '/Elements/SelectCustomFieldValue',
            Arguments => { CustomField => $cf },
        });
}

=head1 SEE ALSO

L<RT::CustomField::Type::IPAddress> and L<RT::CustomField::Type::Date> for examples.

=cut

1;

