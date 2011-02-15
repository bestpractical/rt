# BEGIN BPS TAGGED BLOCK {{{
#
# COPYRIGHT:
#
# This software is Copyright (c) 1996-2010 Best Practical Solutions, LLC
#                                          <jesse@bestpractical.com>
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


use Locale::Maketext 1.04;
use Locale::Maketext::Lexicon 0.25;
use base 'Locale::Maketext::Fuzzy';

use Encode;
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
    require substr(__FILE__, 0, -3) . '/i_default.pm';

    # Load language-specific functions
    foreach my $file ( File::Glob::bsd_glob(substr(__FILE__, 0, -3) . "/*.pm") ) {
        unless ( $file =~ /^([-\w\s\.\/\\~:]+)$/ ) {
            warn("$file is tainted. not loading");
            next;
        }
        $file = $1;

        my ($lang) = ($file =~ /([^\\\/]+?)\.pm$/);
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


=head2 SetMIMEEntityToEncoding $entity, $encoding

An utility function which will try to convert entity body into specified
charset encoding (encoded as octets, *not* unicode-strings).  It will
iterate all the entities in $entity, and try to convert each one into
specified charset if whose Content-Type is 'text/plain'.

the methods are tries in order:
1) to convert the entity to $encoding, 
2) to interpret the entity as iso-8859-1 and then convert it to $encoding,
3) forcibly convert it to $encoding.

This function doesn't return anything meaningful.

=cut

sub SetMIMEEntityToEncoding {
    my ( $entity, $enc, $preserve_words ) = ( shift, shift, shift );

    # do the same for parts first of all
    SetMIMEEntityToEncoding( $_, $enc, $preserve_words ) foreach $entity->parts;

    my $charset = _FindOrGuessCharset($entity) or return;

    SetMIMEHeadToEncoding(
	$entity->head,
	_FindOrGuessCharset($entity, 1) => $enc,
	$preserve_words
    );

    my $head = $entity->head;

    # convert at least MIME word encoded attachment filename
    foreach my $attr (qw(content-type.name content-disposition.filename)) {
	if ( my $name = $head->mime_attr($attr) and !$preserve_words ) {
	    $head->mime_attr( $attr => DecodeMIMEWordsToUTF8($name) );
	}
    }

    # If this is a textual entity, we'd need to preserve its original encoding
    $head->replace( "X-RT-Original-Encoding" => $charset )
	if $head->mime_attr('content-type.charset') or IsTextualContentType($head->mime_type);

    return unless IsTextualContentType($head->mime_type);

    my $body = $entity->bodyhandle;

    if ( $enc ne $charset && $body ) {
        my $string = $body->as_string or return;
        # NOTE:: see the comments at the end of the sub.
        Encode::_utf8_off($string);
        my $orig_string = $string;

        # Convert the body
        eval {
            $RT::Logger->debug( "Converting '$charset' to '$enc' for "
                  . $head->mime_type . " - "
                  . ( $head->get('subject') || 'Subjectless message' ) );
            Encode::from_to( $string, $charset => $enc, Encode::FB_CROAK );
        };

        if ($@) {
            $RT::Logger->error( "Encoding error: " 
                  . $@
                  . " falling back to iso-8859-1 => $enc" );
            $string = $orig_string;
            eval {
                Encode::from_to(
                    $string,
                    'iso-8859-1' => $enc,
                    Encode::FB_CROAK
                );
            };
            if ($@) {
                $RT::Logger->error( "Encoding error: " 
                      . $@
                      . " forcing conversion to $charset => $enc" );
                $string = $orig_string;
                Encode::from_to( $string, $charset => $enc );
            }
        }

        # }}}

        my $new_body = MIME::Body::InCore->new($string);

        # set up the new entity
        $head->mime_attr( "content-type" => 'text/plain' )
          unless ( $head->mime_attr("content-type") );
        $head->mime_attr( "content-type.charset" => $enc );
        $entity->bodyhandle($new_body);
    }
}

# NOTES:  Why Encode::_utf8_off before Encode::from_to
#
# All the strings in RT are utf-8 now.  Quotes from Encode POD:
#
# [$length =] from_to($octets, FROM_ENC, TO_ENC [, CHECK])
# ... The data in $octets must be encoded as octets and not as
# characters in Perl's internal format. ...
#
# Not turning off the UTF-8 flag in the string will prevent the string
# from conversion.



=head2 DecodeMIMEWordsToUTF8 $raw

An utility method which mimics MIME::Words::decode_mimewords, but only
limited functionality.  This function returns an utf-8 string.

It returns the decoded string, or the original string if it's not
encoded.  Since the subroutine converts specified string into utf-8
charset, it should not alter a subject written in English.

Why not use MIME::Words directly?  Because it fails in RT when I
tried.  Maybe it's ok now.

=cut

sub DecodeMIMEWordsToUTF8 {
    my $str = shift;
    return DecodeMIMEWordsToEncoding($str, 'utf-8', @_);
}

sub DecodeMIMEWordsToEncoding {
    my $str = shift;
    my $to_charset = shift;
    my $field = shift || '';

    my @list = $str =~ m/(.*?)=\?([^?]+)\?([QqBb])\?([^?]+)\?=([^=]*)/gcs;

    if ( @list ) {
    # add everything that hasn't matched to the end of the latest
    # string in array this happen when we have 'key="=?encoded?="; key="plain"'
    $list[-1] .= substr($str, pos $str);

    $str = "";
    while (@list) {
	my ($prefix, $charset, $encoding, $enc_str, $trailing) =
            splice @list, 0, 5;
        $encoding = lc $encoding;

        $trailing =~ s/\s?\t?$//;               # Observed from Outlook Express

	if ( $encoding eq 'q' ) {
	    use MIME::QuotedPrint;
	    $enc_str =~ tr/_/ /;		# Observed from Outlook Express
	    $enc_str = decode_qp($enc_str);
	} elsif ( $encoding eq 'b' ) {
	    use MIME::Base64;
	    $enc_str = decode_base64($enc_str);
	} else {
	    $RT::Logger->warning("Incorrect encoding '$encoding' in '$str', "
            ."only Q(uoted-printable) and B(ase64) are supported");
	}

        # now we have got a decoded subject, try to convert into the encoding
        unless ( $charset eq $to_charset ) {
            my $orig_str = $enc_str;
            eval { Encode::from_to( $enc_str, $charset, $to_charset, Encode::FB_CROAK ) };
            if ($@) {
                $enc_str = $orig_str;
                $charset = _GuessCharset( $enc_str );
                Encode::from_to( $enc_str, $charset, $to_charset );
            }
        }

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
        $enc_str = qq{"$enc_str"}
            if $enc_str =~ /[,;]/
            and $enc_str !~ /^".*"$/
            and (!$field || $field =~ /^(?:To$|From$|B?Cc$|Content-)/i);

	$str .= $prefix . $enc_str . $trailing;
    }
    }

# handle filename*=ISO-8859-1''%74%E9%73%74%2E%74%78%74, see also rfc 2231
    @list = $str =~ m/(.*?\*=)([^']*?)'([^']*?)'(\S+)(.*?)(?=(?:\*=|$))/gcs;
    if (@list) {
        $str = '';
        while (@list) {
            my ( $prefix, $charset, $language, $enc_str, $trailing ) =
              splice @list, 0, 5;
            $prefix =~ s/\*=$/=/; # remove the *
            $enc_str =~ s/%(\w{2})/chr hex $1/eg;
            unless ( $charset eq $to_charset ) {
                my $orig_str = $enc_str;
                local $@;
                eval {
                    Encode::from_to( $enc_str, $charset, $to_charset,
                        Encode::FB_CROAK );
                };
                if ($@) {
                    $enc_str = $orig_str;
                    $charset = _GuessCharset($enc_str);
                    Encode::from_to( $enc_str, $charset, $to_charset );
                }
            }
            $enc_str = qq{"$enc_str"}
              if $enc_str =~ /[,;]/
              and $enc_str !~ /^".*"$/
              and (!$field || $field =~ /^(?:To$|From$|B?Cc$|Content-)/i);
            $str .= $prefix . $enc_str . $trailing;
        }
     }

    # We might have \n without trailing whitespace, which will result in
    # invalid headers.
    $str =~ s/\n//g;

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

use constant HAS_ENCODE_GUESS => do { local $@; eval { require Encode::Guess; 1 } };
use constant HAS_ENCODE_DETECT => do { local $@; eval { require Encode::Detect::Detector; 1 } };

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

    if ( $charset eq 'utf8' || $charset eq 'utf-8-strict' ) {
        return 'utf-8';
    }
    elsif ( $charset eq 'gb2312' ) {
        # gbk is superset of gb2312 so it's safe
        return 'gbk';
    }
    else {
        return $charset;
    }
}


=head2 SetMIMEHeadToEncoding HEAD OLD_CHARSET NEW_CHARSET

Converts a MIME Head from one encoding to another. This totally violates the RFC.
We should never need this. But, Surprise!, MUAs are badly broken and do this kind of stuff
all the time


=cut

sub SetMIMEHeadToEncoding {
    my ( $head, $charset, $enc, $preserve_words ) = ( shift, shift, shift, shift );

    $charset = _CanonicalizeCharset($charset);
    $enc     = _CanonicalizeCharset($enc);

    return if $charset eq $enc and $preserve_words;

    foreach my $tag ( $head->tags ) {
        next unless $tag; # seen in wild: headers with no name
        my @values = $head->get_all($tag);
        $head->delete($tag);
        foreach my $value (@values) {
            Encode::_utf8_off($value);
            my $orig_value = $value;
            if ( $charset ne $enc ) {
                eval {
                    Encode::from_to( $value, $charset => $enc, Encode::FB_CROAK );
                };
                if ($@) {
                    $RT::Logger->error( "Encoding error: " 
                          . $@
                          . " falling back to iso-8859-1 => $enc" );
                    $value = $orig_value;
                    eval {
                        Encode::from_to(
                            $value,
                            'iso-8859-1' => $enc,
                            Encode::FB_CROAK
                        );
                    };
                    if ($@) {
                        $RT::Logger->error( "Encoding error: " 
                              . $@
                              . " forcing conversion to $charset => $enc" );
                        $value = $orig_value;
                        Encode::from_to( $value, $charset => $enc );
                    }
                }
            }
            $value = DecodeMIMEWordsToEncoding( $value, $enc, $tag )
                unless $preserve_words;
            $head->add( $tag, $value );
        }
    }

}

RT::Base->_ImportOverlays();

1;  # End of module.

