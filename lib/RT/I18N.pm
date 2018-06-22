# BEGIN BPS TAGGED BLOCK {{{
#
# COPYRIGHT:
#
# This software is Copyright (c) 1996-2018 Best Practical Solutions, LLC
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

=head1 NAME

RT::I18N - a base class for localization of RT

=cut

package RT::I18N;

use strict;
use warnings;
use Cwd ();


use Locale::Maketext 1.04;
use Locale::Maketext::Lexicon 0.25;
use base 'Locale::Maketext::Fuzzy';

use MIME::Entity;
use MIME::Head;
use File::Glob;

# I decree that this project's first language is English.

our %Lexicon = (
   'TEST_STRING' => 'Concrete Mixer',

    '__Content-Type' => 'text/plain; charset=utf-8',

  '_AUTO' => 1,
  # That means that lookup failures can't happen -- if we get as far
  #  as looking for something in this lexicon, and we don't find it,
  #  then automagically set $Lexicon{$key} = $key, before possibly
  #  compiling it.
  
  # The exception is keys that start with "_" -- they aren't auto-makeable.

);
# End of lexicon.

=head2 Init

Initializes the lexicons used for localization.


=cut

sub Init {

    my @lang = RT->Config->Get('LexiconLanguages');
    @lang = ('*') unless @lang;

    # load default functions
    require substr(Cwd::abs_path(__FILE__), 0, -3) . '/i_default.pm';

    # Load language-specific functions
    foreach my $file ( File::Glob::bsd_glob(substr(Cwd::abs_path(__FILE__), 0, -3) . "/*.pm") ) {
        my ($lang) = ($file =~ /([^\\\/]+?)\.pm$/);
        next if $lang eq 'Extract';  # Avoid loading non-language utility module
        next unless grep $_ eq '*' || $_ eq $lang, @lang;
        require $file;
    }

    my %import;
    foreach my $l ( @lang ) {
        $import{$l} = [
            Gettext => $RT::LexiconPath."/$l.po",
        ];
        push @{ $import{$l} }, map {(Gettext => "$_/$l.po")} RT->PluginDirs('po');
        push @{ $import{$l} }, (Gettext => $RT::LocalLexiconPath."/*/$l.po",
                                Gettext => $RT::LocalLexiconPath."/$l.po");
    }

    # Acquire all .po files and iterate them into lexicons
    Locale::Maketext::Lexicon->import({ _decode => 1, %import });

    return 1;
}

sub LoadLexicons {

    no strict 'refs';
    foreach my $k (keys %{RT::I18N::} ) {
        next if $k eq 'main::';
        next unless index($k, '::', -2) >= 0;
        next unless exists ${ 'RT::I18N::'. $k }{'Lexicon'};

        my $lex = *{ ${'RT::I18N::'. $k }{'Lexicon'} }{HASH};
        # run fetch to force load
        my $tmp = $lex->{'foo'};
        # XXX: untie may fail with "untie attempted
        # while 1 inner references still exist"
        # TODO: untie that has to lower fetch impact
        # untie %$lex if tied %$lex;
    }
}

=head2 encoding

Returns the encoding of the current lexicon, as yanked out of __ContentType's "charset" field.
If it can't find anything, it returns 'ISO-8859-1'



=cut


sub encoding { 'utf-8' }


=head2 SetMIMEEntityToUTF8 $entity

An utility function which will try to convert entity body into utf8.
It's now a wrap-up of SetMIMEEntityToEncoding($entity, 'utf-8').

=cut

sub SetMIMEEntityToUTF8 {
    RT::I18N::SetMIMEEntityToEncoding(shift, 'utf-8');
}



=head2 IsTextualContentType $type

An utility function that determines whether $type is I<textual>, meaning
that it can sensibly be converted to Unicode text.

Currently, it returns true iff $type matches this regular expression
(case-insensitively):

    ^(?:text/(?:plain|html)|message/rfc822)\b


=cut

sub IsTextualContentType {
    my $type = shift;
    ($type =~ m{^(?:text/(?:plain|html)|message/rfc822)\b}i) ? 1 : 0;
}


=head2 SetMIMEEntityToEncoding Entity => ENTITY, Encoding => ENCODING, PreserveWords => BOOL, IsOut => BOOL

An utility function which will try to convert entity body into specified
charset encoding (encoded as octets, *not* unicode-strings).  It will
iterate all the entities in $entity, and try to convert each one into
specified charset if whose Content-Type is 'text/plain'.

If PreserveWords is true, values in mime head will be decoded.(default is false)

Incoming and outgoing mails are handled differently, if IsOut is true(default
is false), it'll be treated as outgoing mail, otherwise incomding mail:

incoming mail:
1) find encoding
2) if found then try to convert to utf-8 in croak mode, return if success
3) guess encoding
4) if guessed differently then try to convert to utf-8 in croak mode, return
   if success
5) mark part as application/octet-stream instead of falling back to any
   encoding

outgoing mail:
1) find encoding
2) if didn't find then do nothing, send as is, let MUA deal with it
3) if found then try to convert it to outgoing encoding in croak mode, return
   if success
4) do nothing otherwise, keep original encoding

This function doesn't return anything meaningful.

=cut

sub SetMIMEEntityToEncoding {
    my ( $entity, $enc, $preserve_words, $is_out );

    if ( @_ <= 3 ) {
        ( $entity, $enc, $preserve_words ) = @_;
    }
    else {
        my %args = (
            Entity        => undef,
            Encoding      => undef,
            PreserveWords => undef,
            IsOut         => undef,
            @_,
        );

        $entity         = $args{Entity};
        $enc            = $args{Encoding};
        $preserve_words = $args{PreserveWords};
        $is_out         = $args{IsOut};
    }

    unless ( $entity && $enc ) {
        RT->Logger->error("Missing Entity or Encoding arguments");
        return;
    }

    # do the same for parts first of all
    SetMIMEEntityToEncoding(
        Entity        => $_,
        Encoding      => $enc,
        PreserveWords => $preserve_words,
        IsOut         => $is_out,
    ) foreach $entity->parts;

    my $head = $entity->head;

    my $charset = _FindOrGuessCharset($entity);
    if ( $charset ) {
        unless( Encode::find_encoding($charset) ) {
            $RT::Logger->warning("Encoding '$charset' is not supported");
            $charset = undef;
        }
    }
    unless ( $charset ) {
        $head->replace( "X-RT-Original-Content-Type" => $head->mime_attr('Content-Type') );
        $head->mime_attr('Content-Type' => 'application/octet-stream');
        return;
    }

    SetMIMEHeadToEncoding(
        Head          => $head,
        From          => _FindOrGuessCharset( $entity, 1 ),
        To            => $enc,
        PreserveWords => $preserve_words,
        IsOut         => $is_out,
    );

    # If this is a textual entity, we'd need to preserve its original encoding
    $head->replace( "X-RT-Original-Encoding" => Encode::encode( "UTF-8", $charset ) )
        if $head->mime_attr('content-type.charset') or IsTextualContentType($head->mime_type);

    return unless IsTextualContentType($head->mime_type);

    my $body = $entity->bodyhandle;

    if ( $body && ($enc ne $charset || $enc =~ /^utf-?8(?:-strict)?$/i) ) {
        my $string = $body->as_string or return;
        RT::Util::assert_bytes($string);

        $RT::Logger->debug( "Converting '$charset' to '$enc' for "
              . $head->mime_type . " - "
              . ( Encode::decode("UTF-8",$head->get('subject')) || 'Subjectless message' ) );

        my $orig_string = $string;
        ( my $success, $string ) = EncodeFromToWithCroak( $orig_string, $charset => $enc );
        if ( !$success ) {
            return if $is_out;
            my $error = $string;

            my $guess = _GuessCharset($orig_string);
            if ( $guess && $guess ne $charset ) {
                $RT::Logger->error( "Encoding error: " . $error . " falling back to Guess($guess) => $enc" );
                ( $success, $string ) = EncodeFromToWithCroak( $orig_string, $guess, $enc );
                $error = $string unless $success;
            }

            if ( !$success ) {
                $RT::Logger->error( "Encoding error: " . $error . " falling back to application/octet-stream" );
                $head->mime_attr( "content-type" => 'application/octet-stream' );
                return;
            }
        }

        my $new_body = MIME::Body::InCore->new($string);

        # set up the new entity
        $head->mime_attr( "content-type" => 'text/plain' )
          unless ( $head->mime_attr("content-type") );
        $head->mime_attr( "content-type.charset" => $enc );
        $entity->bodyhandle($new_body);
    }
}

=head2 DecodeMIMEWordsToUTF8 $raw

An utility method which mimics MIME::Words::decode_mimewords, but only
limited functionality.  Despite its name, this function returns the
bytes of the string, in UTF-8.

=cut

sub DecodeMIMEWordsToUTF8 {
    my $str = shift;
    return DecodeMIMEWordsToEncoding($str, 'utf-8', @_);
}

sub DecodeMIMEWordsToEncoding {
    my $str = shift;
    my $to_charset = _CanonicalizeCharset(shift);
    my $field = shift || '';
    $RT::Logger->warning(
        "DecodeMIMEWordsToEncoding was called without field name."
        ."It's known to cause troubles with decoding fields properly."
    ) unless $field;

    # XXX TODO: RT doesn't currently do the right thing with mime-encoded headers
    # We _should_ be preserving them encoded until after parsing is completed and
    # THEN undo the mime-encoding.
    #
    # This routine should be translating the existing mimeencoding to utf8 but leaving
    # things encoded.
    #
    # It's legal for headers to contain mime-encoded commas and semicolons which
    # should not be treated as address separators. (Encoding == quoting here)
    #
    # until this is fixed, we must escape any string containing a comma or semicolon
    # this is only a bandaid

    # Some _other_ MUAs encode quotes _already_, and double quotes
    # confuse us a lot, so only quote it if it isn't quoted
    # already.

    # handle filename*=ISO-8859-1''%74%E9%73%74%2E%74%78%74, parameter value
    # continuations, and similar syntax from RFC 2231
    if ($field =~ /^Content-/i) {
        # This concatenates continued parameters and normalizes encoded params
        # to QB encoded-words which we handle below
        my $params = MIME::Field::ParamVal->parse_params($str);
        foreach my $v ( values %$params ) {
            $v = _DecodeMIMEWordsToEncoding( $v, $to_charset );
            # de-quote in case those were hidden inside encoded part
            $v =~ s/\\(.)/$1/g if $v =~ s/^"(.*)"$/$1/;
        }
        $str = bless({}, 'MIME::Field::ParamVal')->set($params)->stringify;
    }
    elsif ( $field =~ /^(?:Resent-)?(?:To|From|B?Cc|Sender|Reply-To)$/i ) {
        my @addresses = RT::EmailParser->ParseEmailAddress( $str );
        foreach my $address ( @addresses ) {
            foreach my $field (qw(phrase comment)) {
                my $v = $address->$field() or next;
                $v = _DecodeMIMEWordsToEncoding( $v, $to_charset );
                if ( $field eq 'phrase' ) {
                    # de-quote in case quoted value were hidden inside encoded part
                    $v =~ s/\\(.)/$1/g if $v =~ s/^"(.*)"$/$1/;
                }
                $address->$field($v);
            }
        }
        $str = join ', ', map $_->format, @addresses;
    }
    else {
        $str = _DecodeMIMEWordsToEncoding( $str, $to_charset );
    }


    # We might have \n without trailing whitespace, which will result in
    # invalid headers.
    $str =~ s/\n//g;

    return ($str)
}

sub _DecodeMIMEWordsToEncoding {
    my $str = shift;
    my $to_charset = shift;

    # Pre-parse by removing all whitespace between encoded words
    my $encoded_word = qr/
                 =\?            # =?
                 ([^?]+?)       # charset
                 (?:\*[^?]+)?   # optional '*language'
                 \?             # ?
                 ([QqBb])       # encoding
                 \?             # ?
                 ([^?]+)        # encoded string
                 \?=            # ?=
                 /x;
    $str =~ s/($encoded_word)\s+(?=$encoded_word)/$1/g;

    # Also merge quoted-printable sections together, in case multiple
    # octets of a single encoded character were split between chunks.
    # Though not valid according to RFC 2047, this has been seen in the
    # wild.
    1 while $str =~ s/(=\?[^?]+\?[Qq]\?)([^?]+)\?=\1([^?]+)\?=/$1$2$3?=/i;

    # XXX TODO: use decode('MIME-Header', ...) and Encode::Alias to replace our
    # custom MIME word decoding and charset canonicalization.  We can't do this
    # until we parse before decode, instead of the other way around.
    my @list = $str =~ m/(.*?)          # prefix
                         $encoded_word
                         ([^=]*)        # trailing
                        /xgcs;
    return $str unless @list;

    # add everything that hasn't matched to the end of the latest
    # string in array this happen when we have 'key="=?encoded?="; key="plain"'
    $list[-1] .= substr($str, pos $str);

    $str = '';
    while (@list) {
        my ($prefix, $charset, $encoding, $enc_str, $trailing) =
                splice @list, 0, 5;
        $charset  = _CanonicalizeCharset($charset);
        $encoding = lc $encoding;

        if ( $encoding eq 'q' ) {
            use MIME::QuotedPrint;
            $enc_str =~ tr/_/ /;              # RFC 2047, 4.2 (2)
            $enc_str = decode_qp($enc_str);
        } elsif ( $encoding eq 'b' ) {
            use MIME::Base64;
            $enc_str = decode_base64($enc_str);
        } else {
            $RT::Logger->warning("Incorrect encoding '$encoding' in '$str', "
                ."only Q(uoted-printable) and B(ase64) are supported");
        }

        # now we have got a decoded subject, try to convert into the encoding
        if ( $charset ne $to_charset || $charset =~ /^utf-?8(?:-strict)?$/i ) {
            if ( Encode::find_encoding($charset) ) {
                Encode::from_to( $enc_str, $charset, $to_charset );
            } else {
                $RT::Logger->warning("Charset '$charset' is not supported");
                $enc_str =~ s/[^[:print:]]/\357\277\275/g;
                Encode::from_to( $enc_str, 'UTF-8', $to_charset )
                    unless $to_charset eq 'utf-8';
            }
        }
        $str .= $prefix . $enc_str . $trailing;
    }

    return ($str)
}


=head2 _FindOrGuessCharset MIME::Entity, $head_only

When handed a MIME::Entity will first attempt to read what charset the message is encoded in. Failing that, will use Encode::Guess to try to figure it out

If $head_only is true, only guesses charset for head parts.  This is because header's encoding (e.g. filename="...") may be different from that of body's.

=cut

sub _FindOrGuessCharset {
    my $entity = shift;
    my $head_only = shift;
    my $head = $entity->head;

    if ( my $charset = $head->mime_attr("content-type.charset") ) {
        return _CanonicalizeCharset($charset);
    }

    if ( !$head_only and $head->mime_type =~ m{^text/} ) {
        my $body = $entity->bodyhandle or return;
        return _GuessCharset( $body->as_string );
    }
    else {

        # potentially binary data -- don't guess the body
        return _GuessCharset( $head->as_string );
    }
}



=head2 _GuessCharset STRING

use Encode::Guess to try to figure it out the string's encoding.

=cut

use constant HAS_ENCODE_GUESS => Encode::Guess->require;
use constant HAS_ENCODE_DETECT => Encode::Detect::Detector->require;

sub _GuessCharset {
    my $fallback = _CanonicalizeCharset('iso-8859-1');

    # if $_[0] is null/empty, we don't guess its encoding
    return $fallback
        unless defined $_[0] && length $_[0];

    my @encodings = RT->Config->Get('EmailInputEncodings');
    unless ( @encodings ) {
        $RT::Logger->warning("No EmailInputEncodings set, fallback to $fallback");
        return $fallback;
    }

    if ( $encodings[0] eq '*' ) {
        shift @encodings;
        if ( HAS_ENCODE_DETECT ) {
            my $charset = Encode::Detect::Detector::detect( $_[0] );
            if ( $charset ) {
                $RT::Logger->debug("Encode::Detect::Detector guessed encoding: $charset");
                return _CanonicalizeCharset( Encode::resolve_alias( $charset ) );
            }
            else {
                $RT::Logger->debug("Encode::Detect::Detector failed to guess encoding");
            }
        }
        else {
            $RT::Logger->error(
                "You requested to guess encoding, but we couldn't"
                ." load Encode::Detect::Detector module"
            );
        }
    }

    unless ( @encodings ) {
        $RT::Logger->warning("No EmailInputEncodings set except '*', fallback to $fallback");
        return $fallback;
    }

    unless ( HAS_ENCODE_GUESS ) {
        $RT::Logger->error("We couldn't load Encode::Guess module, fallback to $fallback");
        return $fallback;
    }

    Encode::Guess->set_suspects( @encodings );
    my $decoder = Encode::Guess->guess( $_[0] );
    unless ( defined $decoder ) {
        $RT::Logger->warning("Encode::Guess failed: decoder is undefined; fallback to $fallback");
        return $fallback;
    }

    if ( ref $decoder ) {
        my $charset = $decoder->name;
        $RT::Logger->debug("Encode::Guess guessed encoding: $charset");
        return _CanonicalizeCharset( $charset );
    }
    elsif ($decoder =~ /(\S+ or .+)/) {
        my %matched = map { $_ => 1 } split(/ or /, $1);
        return 'utf-8' if $matched{'utf8'}; # one and only normalization

        foreach my $suspect (RT->Config->Get('EmailInputEncodings')) {
            next unless $matched{$suspect};
            $RT::Logger->debug("Encode::Guess ambiguous ($decoder); using $suspect");
            return _CanonicalizeCharset( $suspect );
        }
    }
    else {
        $RT::Logger->warning("Encode::Guess failed: $decoder; fallback to $fallback");
    }

    return $fallback;
}

=head2 _CanonicalizeCharset NAME

canonicalize charset, return lowercase version.
special cases are: gb2312 => gbk, utf8 => utf-8

=cut

sub _CanonicalizeCharset {
    my $charset = lc shift;
    return $charset unless $charset;

    # Canonicalize aliases if they're known
    if (my $canonical = Encode::resolve_alias($charset)) {
        $charset = $canonical;
    }

    if ( $charset eq 'utf8' || $charset eq 'utf-8-strict' ) {
        return 'utf-8';
    }
    elsif ( $charset eq 'euc-cn' ) {
        # gbk is superset of gb2312/euc-cn so it's safe
        return 'gbk';
    }
    elsif ( $charset =~ /^(?:(?:big5(-1984|-2003|ext|plus))|cccii|unisys|euc-tw|gb18030|(?:cns11643-\d+))$/ ) {
        unless ( Encode::HanExtra->require ) {
            RT->Logger->error("Please install Encode::HanExtra to handle $charset");
        }
        return $charset;
    }
    else {
        return $charset;
    }
}


=head2 SetMIMEHeadToEncoding MIMEHead => HEAD, From => OLD_ENCODING, To => NEW_Encoding, PreserveWords => BOOL, IsOut => BOOL

Converts a MIME Head from one encoding to another. This totally violates the RFC.
We should never need this. But, Surprise!, MUAs are badly broken and do this kind of stuff
all the time


=cut

sub SetMIMEHeadToEncoding {
    my ( $head, $charset, $enc, $preserve_words, $is_out );

    if ( @_ <= 4 ) {
        ( $head, $charset, $enc, $preserve_words ) = @_;
    }
    else {
        my %args = (
            Head      => undef,
            From          => undef,
            To            => undef,
            PreserveWords => undef,
            IsOut         => undef,
            @_,
        );

        $head           = $args{Head};
        $charset        = $args{From};
        $enc            = $args{To};
        $preserve_words = $args{PreserveWords};
        $is_out         = $args{IsOut};
    }

    unless ( $head && $charset && $enc ) {
        RT->Logger->error(
            "Missing Head or From or To arguments");
        return;
    }

    $charset = _CanonicalizeCharset($charset);
    $enc     = _CanonicalizeCharset($enc);

    return if $charset eq $enc and $preserve_words;

    RT::Util::assert_bytes( $head->as_string );
    foreach my $tag ( $head->tags ) {
        next unless $tag; # seen in wild: headers with no name
        my @values = $head->get_all($tag);
        $head->delete($tag);
        foreach my $value (@values) {
            if ( $charset ne $enc || $enc =~ /^utf-?8(?:-strict)?$/i ) {
                my $orig_value = $value;
                ( my $success, $value ) = EncodeFromToWithCroak( $orig_value, $charset => $enc );
                if ( !$success ) {
                    my $error = $value;
                    if ($is_out) {
                        $value = $orig_value;
                        $head->add( $tag, $value );
                        next;
                    }

                    my $guess = _GuessCharset($orig_value);
                    if ( $guess && $guess ne $charset ) {
                        $RT::Logger->error( "Encoding error: " . $error . " falling back to Guess($guess) => $enc" );
                        ( $success, $value ) = EncodeFromToWithCroak( $orig_value, $guess, $enc );
                        $error = $value unless $success;
                    }

                    if ( !$success ) {
                        $RT::Logger->error( "Encoding error: " . $error . " forcing conversion to $charset => $enc" );
                        $value = $orig_value;
                        Encode::from_to( $value, $charset => $enc );
                    }
                }
            }

            $value = DecodeMIMEWordsToEncoding( $value, $enc, $tag )
                unless $preserve_words;

            # We intentionally add a leading space when re-adding the
            # header; Mail::Header strips it before storing, but it
            # serves to prevent it from "helpfully" canonicalizing
            # $head->add("Subject", "Subject: foo") into the same as
            # $head->add("Subject", "foo");
            $head->add( $tag, " " . $value );
        }
    }

}

=head2 EncodeFromToWithCroak $string, $from, $to

Try to encode string from encoding $from to encoding $to in croak mode

return (1, $encoded_string) if success, otherwise (0, $error)

=cut

sub EncodeFromToWithCroak {
    my $string = shift;
    my $from   = shift;
    my $to     = shift;

    eval {
        no warnings 'utf8';
        $string = Encode::encode( $to, Encode::decode( $from, $string ), Encode::FB_CROAK );
    };
    return $@ ? ( 0, $@ ) : ( 1, $string );
}

RT::Base->_ImportOverlays();

1;  # End of module.

