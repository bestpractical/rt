=head1 NAME

RT::I18N - a base class for localization of RT

=cut

package RT::I18N;
  # This is the project base class for "findgrep", an example application
  # using Locale::Maketext;

use Locale::Maketext 1.01;
use base ('Locale::Maketext');

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
            my $force_utf8 = sub {
                return pack( 'U0A*', $_[0] );
              };

            *{ ref($self) . '::maketext' } = sub {
                my $self = shift;

                return $force_utf8->(
                      $decoder{$encoding}->convert( $self->SUPER::maketext(@_) )
                );
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
1;  # End of module.

