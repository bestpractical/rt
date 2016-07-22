package RT::Interface::Web::Scrubber;
use 5.010;
use base qw/HTML::Scrubber/;

use HTML::Gumbo;

=head1 NAME

RT::Interface::Web::Scrubber

=head1 DESCRIPTION

This is a subclass of L<HTML::Scrubber> which automatically configures
itself with a sane and safe default set of rules.  Additionally, it
ensures that the input is balanced HTML by use of the L<HTML::Gumbo>
on the input to L</scrub>.

=head1 VARIABLES

These variables can be altered by creating a C<Scrubber_Local.pm>
file, containing something of the form:

    package RT::Interface::Web::Scrubber;

    # Allow the "title" attribute
    $ALLOWED_ATTRIBUTES{title} = 1;

=over

=item C<@ALLOWED_TAGS>

Passed to L<HTML::Scrubber/allow>.

=item C<%ALLOWED_ATTRIBUTES>

Passed into L<HTML::Scrubber/default>.

=item C<%RULES>

Passed to L<HTML::Scrubber/rules>.

=back

=cut

our @ALLOWED_TAGS = qw(
    A B U P BR I HR BR SMALL EM FONT SPAN STRONG SUB SUP S DEL STRIKE H1 H2 H3 H4 H5
    H6 DIV UL OL LI DL DT DD PRE BLOCKQUOTE BDO TABLE THEAD TBODY TFOOT TR TD TH
);

our %ALLOWED_ATTRIBUTES = (
    # Match http, https, ftp, mailto and relative urls
    # XXX: we also scrub format strings with this module then allow simple config options
    href   => qr{^(?:https?:|ftp:|mailto:|/|__Web(?:Path|HomePath|BaseURL|URL)__)}i,
    face   => 1,
    size   => 1,
    color  => 1,
    target => 1,
    style  => qr{
        ^(?:\s*
            (?:(?:background-)?color: \s*
                    (?:rgb\(\s* \d+, \s* \d+, \s* \d+ \s*\) |   # rgb(d,d,d)
                       \#[a-f0-9]{3,6}                      |   # #fff or #ffffff
                       [\w\-]+                                  # green, light-blue, etc.
                       )                            |
               text-align: \s* \w+                  |
               font-size: \s* [\w.\-]+              |
               font-family: \s* [\w\s"',.\-]+       |
               font-weight: \s* [\w\-]+             |

               border-style: \s* \w+                |
               border-color: \s* [#\w]+             |
               border-width: \s* [\s\w]+            |
               padding: \s* [\s\w]+                 |
               margin: \s* [\s\w]+                  |

               # MS Office styles, which are probably fine.  If we don't, then any
               # associated styles in the same attribute get stripped.
               mso-[\w\-]+?: \s* [\w\s"',.\-]+
            )\s* ;? \s*)
         +$ # one or more of these allowed properties from here 'till sunset
    }ix,
    dir    => qr/^(rtl|ltr)$/i,
    lang   => qr/^\w+(-\w+)?$/,

    colspan     => 1,
    rowspan     => 1,
    align       => 1,
    valign      => 1,
    cellspacing => 1,
    cellpadding => 1,
    border      => 1,
    width       => 1,
    height      => 1,

    # timeworked per user attributes
    'data-ticket-id'    => 1,
    'data-ticket-class' => 1,
);

our %RULES = ();

=head1 METHODS

=head2 new

Returns a new L<RT::Interface::Web::Scrubber> object, configured with
the above globals.  Takes no arguments.

=cut

sub new {
    my $class = shift;
    $self = $class->SUPER::new(@_);

    $self->default(
        0,
        {
            %ALLOWED_ATTRIBUTES,
            '*' => 0, # require attributes be explicitly allowed
        },
    );
    $self->deny(qw[*]);
    $self->allow(@ALLOWED_TAGS);

    # If we're displaying images, let embedded ones through
    if (RT->Config->Get('ShowTransactionImages') or RT->Config->Get('ShowRemoteImages')) {
        my @src;
        push @src, qr/^cid:/i
            if RT->Config->Get('ShowTransactionImages');

        push @src, $ALLOWED_ATTRIBUTES{'href'}
            if RT->Config->Get('ShowRemoteImages');

        $RULES{'img'} ||= {
            '*' => 0,
            alt => 1,
            src => join("|", @src),
        };
    }
    $self->rules(%RULES);

    # Scrubbing comments is vital since IE conditional comments can contain
    # arbitrary HTML and we'd pass it right on through.
    $self->comment(0);

    return $self;
}

=head2 gumbo

Returns a L<HTML::Gumbo> object.

=cut

sub gumbo {
    my $self = shift;
    return $self->{_gumbo} //= HTML::Gumbo->new;
}

=head2 scrub TEXT

Takes a string of HTML, and returns it scrubbed, via L<HTML::Gumbo>
then the rules.  This is a more limited interface than
L<HTML::Scrubber/scrub>.

=cut

sub scrub {
    my $self = shift;
    my $Content = shift // '';

    # First pass through HTML::Gumbo to balance the tags
    eval { $Content = $self->gumbo->parse( $Content ); chomp $Content };
    warn "HTML::Gumbo pre-parse failed: $@" if $@;

    return $self->SUPER::scrub($Content);
}

RT::Base->_ImportOverlays();
1;
