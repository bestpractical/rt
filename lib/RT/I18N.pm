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



use Locale::Maketext 1.01;
use base ('Locale::Maketext::Fuzzy');

#If we're running on 5.6, we desperately need Encode::compat. But if we're on 5.8, we don't want it.
if ($] < 5.008) {
require Encode::compat;
}
use Encode;

use MIME::Entity;
use MIME::Head;

my @languages;

BEGIN {
    # Acquire all .po files and iterate them into lexicons
    @languages = map {
	m|/(\w+).po$|g
    } glob(substr(__FILE__, 0, -3) . "/*.po");

    require Locale::Maketext::Lexicon;
    Locale::Maketext::Lexicon->import({ map {
	$_ => [Gettext => "$_.po"]
    } @languages });
}


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

=head2 encoding

Returns the encoding of the current lexicon, as yanked out of __ContentType's "charset" field.
If it can't find anything, it returns 'ISO-8859-1'

=begin testing

use_ok (RT::I18N);
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
	    return 'utf-8' if $] >= 5.007003 or $] < 5.006;

	    # 5.6.x is 1)stupid 2)special case.
            no strict 'refs';
            *{ ref($self) . '::maketext' } = sub {
                my $self = shift;
		my @args;
		foreach my $arg (@_) {
		    push @args, pack( 'C*', unpack('C*', $arg) );
		}

                return pack( 'U*', unpack('U0U*', $self->SUPER::maketext(@args) ) );
            };

            return ('utf-8');
	}

	no strict 'refs';
	*{ ref($self) . '::maketext' } = sub {
	    my $self = shift;
	    return Encode::decode( $encoding, $self->SUPER::maketext(@_) );
	};

	return ('utf-8');
    }
}

}

# Force UTF8 flag on if we're sure it's utf8 already
foreach my $lang (@languages) {
    my $pkg = __PACKAGE__ . "::$lang";
    next unless $pkg->encoding eq 'utf-8';

    no strict 'refs';
    my $lexicon = \%{"$pkg\::Lexicon"};
    Encode::_utf8_on($lexicon->{$_}) for keys %{$lexicon};
}

# {{{ SetMIMEEntityToUTF8

=head2 SetMIMEEntityToUTF8 $entity

An utility method which will try to convert entity body into utf8.
It will iterate all the entities in $entity, and try to convert each
one into utf-8 charset if whose Content-Type is 'text/plain'.

This method doesn't return anything meaningful.

=cut

sub SetMIMEEntityToUTF8 {
    my $entity = shift;

    if ($entity->is_multipart) {
	RT::I18N::SetMIMEEntityToUTF8($_) foreach $entity->parts;
    } else {
	my ($head, $body) = ($entity->head, $entity->bodyhandle);
	my ($mime_type, $charset) =
	    ($head->mime_type, $head->mime_attr("content-type.charset") || "");
	$RT::Logger->debug("MIME type and charset of MIME Entity is " .
			   "'$mime_type' and '$charset'");

	# the entity is not text, nothing to do with it.
	return unless ($mime_type eq 'text/plain');

	# the entity is text and has charset setting, try convert
	# message body into utf8
	my @lines;
	if ($charset) {
	    # charset is specified, we'll use it to convert message body
	    @lines = $body->as_lines;
	    Encode::from_to($lines[$_], $charset, "utf8") foreach (0..$#lines);
	} elsif (@RT::EmailInputEncodings) {
	    # charset is not specified, and guess it using
	    # @RT::EmailInputEncodings

	    require Encode::Guess;
	    Encode::Guess->set_suspects(@RT::EmailInputEncodings);
	    my $decoder = Encode::Guess->guess($body->as_string);

	    if (ref $decoder) {
		# convert to utf8 is ok, replace the original body with
		# the utf-8 body
		$RT::Logger->debug("Guessed encoding is: ". $decoder->name);
		@lines = map { $decoder->decode($_) } $body->as_lines;
	    }
	    # on failure, $decoder now contains an error message.
	    else {
		$RT::Logger->debug("Cannot Encode::Guess: $decoder");
		return;
	    }
	}

	# if empty body, no need to replace it with a new body.
	if (@lines) {
	    my $new_body = new MIME::Body::InCore \@lines;
	    # set up the new entity
	    $head->mime_attr("content-type.charset" => 'utf-8');
	    $entity->bodyhandle($new_body);
	}
    }
}

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
	    $RT::Logger->warn("RT::I18N::DecodeMIMEWordsUTF8 got a " .
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

