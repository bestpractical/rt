=head1 NAME

RT::I18N - a base class for localization of RT

=cut

package RT::I18N;
use Locale::Maketext 1.01;
use base ('Locale::Maketext');

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

my %decoder; # shared cache of Text::Iconv decoder

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

        if ( $] >= 5.007003 and eval { require Encode; 1 } ) {

            # perl 5.7.3 or above with Encode module - normalize to utf8
            no strict 'refs';
            *{ ref($self) . '::maketext' } = sub {
                my $self = shift;
                return Encode::decode( $encoding, $self->SUPER::maketext(@_) );
            };

            return ('utf-8');
        }
        elsif ( $] >= 5.006 and eval { require Text::Iconv; 1 } ) {
            $decoder{$encoding} ||= Text::Iconv->new( $encoding, 'utf-8' );

            # different quite broken ways to force utf8ness.
            *{ ref($self) . '::maketext' } = sub {
                my $self = shift;
		my @args;
		foreach my $arg (@_) {
		    push @args, pack( 'C*', unpack('C*', $arg) );
		}

                return pack( 'U*', unpack('U0U*',
		    $decoder{$encoding}->convert( $self->SUPER::maketext(@_) )
                ) );
            };

            return ('utf-8');
        }
        else {
            # assume byte semantic
            return ($encoding);
        }
    }
}
}

# Force UTF8 flag on if we're sure it's utf8 already
no strict 'refs';
foreach my $lang (@languages) {
    my $pkg = __PACKAGE__ . "::$lang";
    next unless $pkg->encoding eq 'utf-8';

    if ($] >= 5.007003) {
	require Encode;
	Encode::_utf8_on($_) for values %{"$pkg\::Lexicon"};
    }
}

1;  # End of module.

