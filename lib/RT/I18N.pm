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

    '__Content-Type' => 'text/plain; charset=ISO-8859-1',

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
ok($chinese->maketext('__Content-Type') =~ /big5/i, "Found the big5 charset for traditional chinese in the string ".$chinese->maketext('__Content-Type'));
ok($chinese->encoding eq 'big5', "The encoding is 'big5' -".$chinese->encoding);

ok(my $en = RT::I18N->get_handle('en'));
ok(UNIVERSAL::can($en, 'maketext'));
ok($en->encoding eq 'ISO-8859-1', "The encoding is 'ISO-8859-1'");

=end testing


=cut

sub encoding { 
    my $self = shift;
    if ($self->maketext('__Content-Type') =~ /charset=\s*([-\w]+)/i) {
        return ($1);
     }
     else {
        return ('ISO-8859-1');
    } 
}

1;  # End of module.

