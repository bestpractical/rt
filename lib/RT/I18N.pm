# BEGIN LICENSE BLOCK
# 
# Copyright (c) 1996-2003 Jesse Vincent <jesse@bestpractical.com>
# 
# (Except where explictly superceded by other copyright notices)
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
# Unless otherwise specified, all modifications, corrections or
# extensions to this work which alter its source code become the
# property of Best Practical Solutions, LLC when submitted for
# inclusion in the work.
# 
# 
# END LICENSE BLOCK
=head1 NAME

RT::I18N - a base class for localization of RT

=cut

package RT::I18N;

use strict;
use Locale::Maketext 1.04;
use Locale::Maketext::Lexicon 0.25;
use base ('Locale::Maketext::Fuzzy');
use vars qw( %Lexicon );

#If we're running on 5.6, we desperately need Encode::compat. But if we're on 5.8, we don't really need it.
BEGIN { if ($] < 5.007001) {
require Encode::compat;
} }
use Encode;

use MIME::Entity;
use MIME::Head;

# I decree that this project's first language is English.

%Lexicon = (
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

=begin testing

use_ok (RT::I18N);
ok(RT::I18N->Init);

=end testing

=cut

sub Init {
    # Load language-specific functions
    foreach my $language ( glob(substr(__FILE__, 0, -3) . "/*.pm")) {
        if ($language =~ /^([-\w.\/\\~:]+)$/) {
            require $1;
        }
        else {
	    warn("$language is tainted. not loading");
        } 
    }

    my @lang = @RT::LexiconLanguages;
    @lang = ('*') unless @lang;

    # Acquire all .po files and iterate them into lexicons
    Locale::Maketext::Lexicon->import({
	_decode	=> 1, map {
	    $_	=> [
		Gettext => (substr(__FILE__, 0, -3) . "/$_.po"),
		Gettext => "$RT::LocalLexiconPath/*/$_.po",
	    ],
	} @lang
    });

    return 1;
}

=head2 encoding

Returns the encoding of the current lexicon, as yanked out of __ContentType's "charset" field.
If it can't find anything, it returns 'ISO-8859-1'

=begin testing

ok(my $chinese = RT::I18N->get_handle('zh_tw'));
ok(UNIVERSAL::can($chinese, 'maketext'));
ok($chinese->maketext('__Content-Type') =~ /utf-8/i, "Found the utf-8 charset for traditional chinese in the string ".$chinese->maketext('__Content-Type'));
ok($chinese->encoding eq 'utf-8', "The encoding is 'utf-8' -".$chinese->encoding);

ok(my $en = RT::I18N->get_handle('en'));
ok(UNIVERSAL::can($en, 'maketext'));
ok($en->encoding eq 'utf-8', "The encoding ".$en->encoding." is 'utf-8'");

=end testing


=cut


sub encoding { 'utf-8' }

# {{{ SetMIMEEntityToUTF8

=head2 SetMIMEEntityToUTF8 $entity

An utility method which will try to convert entity body into utf8.
It's now a wrap-up of SetMIMEEntityToEncoding($entity, 'utf-8').

=cut

sub SetMIMEEntityToUTF8 {
    RT::I18N::SetMIMEEntityToEncoding(shift, 'utf-8');
}

# }}}

# {{{ SetMIMEEntityToEncoding

=head2 SetMIMEEntityToEncoding $entity, $encoding

An utility method which will try to convert entity body into specified
charset encoding (encoded as octets, *not* unicode-strings).  It will
iterate all the entities in $entity, and try to convert each one into
specified charset if whose Content-Type is 'text/plain'.

This method doesn't return anything meaningful.

=cut

sub SetMIMEEntityToEncoding {
    my ( $entity, $enc ) = ( shift, shift );

    if ( $entity->is_multipart ) {
	SetMIMEEntityToEncoding( $_, $enc ) foreach $entity->parts;
    }

    my $charset = _FindOrGuessCharset($entity) or return;
    # one and only normalization
    $charset = 'utf-8' if $charset eq 'utf8';
    $enc     = 'utf-8' if $enc     eq 'utf8';

    SetMIMEHeadToEncoding($entity->head, $charset => $enc);

    my ( $head, $body ) = ( $entity->head, $entity->bodyhandle );

    if ( $head->mime_type !~ /^text\/plain$/i ) {
	# the entity is not text; convert at least MIME word encoded attachment filename
	foreach my $attr (qw(content-type.name content-disposition.filename)) {
	    if ( my $name = $head->mime_attr($attr) ) {
		$head->mime_attr( $attr => DecodeMIMEWordsToUTF8($name) );
	    }
	}
	return;
    }

    if ( $enc ne $charset ) {
	my @lines = $body->as_lines or return;

	# {{{ Convert the body
	eval {
	    $RT::Logger->debug("Converting '$charset' to '$enc'");

	    # NOTE:: see the comments at the end of the sub.
	    Encode::_utf8_off( $lines[$_] ) foreach ( 0 .. $#lines );
	    Encode::from_to( $lines[$_], $charset => $enc ) for ( 0 .. $#lines );
	};

	if ($@) {
	    $RT::Logger->error( "Encoding error: " . $@ . " defaulting to ISO-8859-1 -> UTF-8" );
	    eval {
		Encode::from_to( $lines[$_], 'iso-8859-1' => $enc ) foreach ( 0 .. $#lines );
	    };
	    if ($@) {
		$RT::Logger->crit( "Totally failed to convert to utf-8: " . $@ . " I give up" );
	    }
	}
	# }}}

        my $new_body = MIME::Body::InCore->new( \@lines );

	use Data::Dumper;
	open X, ">/tmp/foo.txt" or die $!;
	print X Data::Dumper::Dumper(\@lines);
	close X;
        # set up the new entity
        $head->mime_attr( "content-type" => 'text/plain' )
          unless ( $head->mime_attr("content-type") );
        $head->mime_attr( "content-type.charset" => $enc );
        $head->add( "X-RT-Original-Encoding" => $charset );
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

# }}}

# {{{ DecodeMIMEWordsToUTF8

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

    @_ = $str =~ m/([^=]*)=\?([^?]+)\?([QqBb])\?([^?]+)\?=([^=]*)/g;

    return ($str, '') unless (@_);

    $str = "";
    while (@_) {
	my ($prefix, $charset, $encoding, $enc_str, $trailing) =
	    (shift, shift, shift, shift, shift);

        $trailing =~ s/\s?\t?$//;               # Observed from Outlook Express

	if ($encoding eq 'Q' or $encoding eq 'q') {
	    use MIME::QuotedPrint;
	    $enc_str =~ tr/_/ /;		# Observed from Outlook Express
	    $enc_str = decode_qp($enc_str);
	} elsif ($encoding eq 'B' or $encoding eq 'b') {
	    use MIME::Base64;
	    $enc_str = decode_base64($enc_str);
	} else {
	    $RT::Logger->warning("RT::I18N::DecodeMIMEWordsUTF8 got a " .
			      "strange encoding: $encoding.");
	}

	# now we have got a decoded subject, try to convert into
	# utf-8 encoding
	unless ($charset =~ m/utf-8/i) {
	    Encode::from_to($enc_str, $charset, "utf8");
	}

	$str .= $prefix . $enc_str . $trailing;
    }

    return ($str)
}

# }}}

# {{{ _FindOrGuessCharset

=head2 _FindOrGuessCharset MIME::Entity

When handed a MIME::Entity will first attempt to read what charset the message is encoded in. Failing that, 
will use Encode::Guess to try to figure it out

=cut

sub _FindOrGuessCharset {
    my $entity = shift;
    my $head = $entity->head;
    my $charset;
    my $fallback = 'iso-8859-1';

    return $charset if ($charset = $head->mime_attr("content-type.charset"));

    my $body = $entity->bodyhandle or return;
    return 'utf-8' if Encode::is_utf8( $body->as_string );

    if ( @RT::EmailInputEncodings and eval { require Encode::Guess; 1 } ) {
	Encode::Guess->set_suspects(@RT::EmailInputEncodings);
	my $decoder = Encode::Guess->guess( $head->as_string . $body->as_string );

	if ( ref $decoder ) {
	    $charset = $decoder->name;
	    $RT::Logger->debug("Guessed encoding: $charset");
	    return $charset;
	}
	elsif ($decoder =~ /Encodings too ambiguous: (.+)/) {
	    my %matched = map { $_ => 1 } split(/ or /, $1);
	    foreach my $suspect (@RT::EmailInputEncodings) {
		next unless $matched{$suspect};
		$RT::Logger->debug("Encode::Guess ambiguous ($decoder); using $suspect");
		$charset = $suspect;
		last;
	    }
	}
	else {
	    $RT::Logger->warning("Encode::Guess failed: $decoder; fallback to $fallback");
	}
    }
    else {
	$RT::Logger->warning("Cannot Encode::Guess; fallback to $fallback");
    }

    return($charset || $fallback);
}

# }}}

# {{{ SetMIMEHeadToEncoding

=head2 SetMIMEHeadToEncoding HEAD OLD_CHARSET NEW_CHARSET

Converts a MIME Head from one encoding to another. This totally violates the RFC.
We should never need this. But, Surprise!, MUAs are badly broken and do this kind of stuff
all the time


=cut

sub SetMIMEHeadToEncoding {
    my ($head, $enc, $charset)   = (shift, shift, shift);

    $charset = 'utf-8' if $charset eq 'utf8';
    $enc     = 'utf-8' if $enc     eq 'utf8';
    return if $charset eq $enc;

    foreach my $tag ( $head->tags) {
	my @values = $head->get_all($tag);
	$head->delete($tag);
	foreach my $value (@values) {
	    eval {
		Encode::_utf8_off($value);
		Encode::from_to( $value, $charset => $enc );
	    };
	    if ($@) {
		$RT::Logger->error( "Encoding error: " . $@ . " defaulting to ISO-8859-1 -> UTF-8" );
		eval { Encode::from_to( $value, 'iso-8859-1' => $enc ) };
		if ($@) {
		    $RT::Logger->crit( "Totally failed to convert to utf-8: " . $@ . " I give up" );
		}
	    }
	    $head->add( $tag, $value );
	}
    }
}
# }}}

eval "require RT::I18N_Vendor";
die $@ if ($@ && $@ !~ qr{^Can't locate RT/I18N_Vendor.pm});
eval "require RT::I18N_Local";
die $@ if ($@ && $@ !~ qr{^Can't locate RT/I18N_Local.pm});

1;  # End of module.

