# BEGIN LICENSE BLOCK
# 
# Copyright (c) 1996-2002 Jesse Vincent <jesse@bestpractical.com>
# 
# (Except where explictly superceded by other copyright notices)
# 
# This work is made available to you under the terms of Version 2 of
# the GNU General Public License. A copy of that license should have
# been provided with this software, but in any event can be snarfed
# from www.gnu.org
# 
# This work is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# General Public License for more details.
# 
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
use Locale::Maketext 1.01;
use Locale::Maketext::Lexicon 0.10;
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
    # Acquire all .po files and iterate them into lexicons
    my @languages = map {
	m|/(\w+).po$|g
    } glob(substr(__FILE__, 0, -3) . "/*.po");

    Locale::Maketext::Lexicon->import({ map {
	$_ => [Gettext => "$_.po"]
    } @languages });

    # allow user to override lexicons using local/po/...
    if (-d $RT::LocalLexiconPath) {
	require File::Find;
	File::Find::find( {
	    wanted		=> sub {
		return unless /(\w+)\.po$/;
		Locale::Maketext::Lexicon->import({
		    $1 => [Gettext => $File::Find::name],
		});
	    },
	    follow		=> 0,
	    untaint		=> 1,
	    untaint_skip	=> 1,
	}, $RT::LocalLexiconPath );
    }

    # Force UTF8 flag on if we're sure it's utf8 already
    foreach my $lang (@languages) {
	my $pkg = __PACKAGE__ . "::$lang";
	next unless $pkg->encoding eq 'utf-8';

	no strict 'refs';
	my $lexicon = \%{"$pkg\::Lexicon"};
	Encode::_utf8_on($lexicon->{$_}) for keys %{$lexicon};
    }

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

{

sub encoding { 
    my $self = shift;

    if ( $self->maketext('__Content-Type') =~ /charset=\s*([-\w]+)/i ) {
        my $encoding = $1;

	# Doesn't make any sense if it's already utf8
	if ($encoding =~ /^utf-?8$/i) {
	    no strict 'refs';

	    if ($] >= 5.007001) {
		*{ ref($self) . '::maketext' } = sub {
		    my $self = shift;
		    my @args;
		    foreach (@_) {
			my $arg = $_;
			Encode::_utf8_on($arg);
			push @args, $arg;
		    }

		    my $val = $self->SUPER::maketext(@args);
		    Encode::_utf8_on( $val );
		    return $val;
		};
	    }
	    else {
		# 5.6.x is 1)stupid 2)special case.
		*{ ref($self) . '::maketext' } = sub {
		    my $self = shift;
		    my @args;
		    foreach my $arg (@_) {
			push @args, pack( 'C*', unpack('C*', $arg) );
		    }

		    return pack( 'U*', unpack('U0U*', $self->SUPER::maketext(@args) ) );
		};
	    }

            return ('utf-8');
	}

	no warnings 'redefine';
	no strict 'refs';
	*{ ref($self) . '::maketext' } = sub {
	    my $self = shift;
	    return Encode::decode( $encoding, $self->SUPER::maketext(@_) );
	};

	return ('utf-8');
    }
}

}

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
charset encoding.  It will iterate all the entities in $entity, and
try to convert each one into specified charset if whose Content-Type
is 'text/plain'.

This method doesn't return anything meaningful.

=cut

sub SetMIMEEntityToEncoding {
    my ($entity, $enc) = (shift, shift);

    if ($entity->is_multipart) {
	RT::I18N::SetMIMEEntityToEncoding($_, $enc) foreach $entity->parts;
    } else {
	my ($head, $body) = ($entity->head, $entity->bodyhandle);
	my ($mime_type, $charset) =
	    ($head->mime_type, $head->mime_attr("content-type.charset") || "");

	# the entity is not text, nothing to do with it.
	return unless ($mime_type eq 'text/plain');

	# the entity is text and has charset setting, try convert
	# message body into $enc
	my @lines = $body->as_lines or return;

	if (!$charset) {
	    if ( @RT::EmailInputEncodings and eval { require Encode::Guess; 1 } ) {
		Encode::Guess->set_suspects(@RT::EmailInputEncodings);
		my $decoder = Encode::Guess->guess($body->as_string);

		if (ref $decoder) {
		    $charset = $decoder->name;
		    $RT::Logger->debug("Guessed encoding: $charset");
		}
		else {
		    $charset = 'utf-8';
		    $RT::Logger->warning("Cannot Encode::Guess: $decoder; fallback to utf-8");
		}
	    }
	    else {
		$charset = 'utf-8';
	    }
	}

	# one and only normalization
	$charset = 'utf-8' if $charset eq 'utf8';
	$enc     = 'utf-8' if $enc     eq 'utf8';

	if ($enc ne $charset) {
      eval {

	    $RT::Logger->debug("Converting '$charset' to '$enc'");

	    # NOTE:: see the comments at the end of the sub.
	    Encode::_utf8_off($lines[$_]) foreach (0 .. $#lines);

	    if ($enc eq 'utf-8') {
		$lines[$_] = Encode::decode($charset, $lines[$_]) foreach (0 .. $#lines);
	    }
	    else {
		Encode::from_to($lines[$_], $charset => $enc) foreach (0 .. $#lines);
	    }
      }; 
      if ($@) {
        $RT::Logger->error("Encoding error: ".$@);
       }
	}
	elsif ($enc eq 'utf-8') {
	    Encode::_utf8_on($lines[$_]) foreach (0 .. $#lines);
	}

	my $new_body = MIME::Body::InCore->new(\@lines);
	# set up the new entity
	$head->mime_attr("content-type.charset" => $enc);
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

1;  # End of module.

