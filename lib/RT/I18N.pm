package RT::I18N;
  # This is the project base class for "findgrep", an example application
  # using Locale::Maketext;

use Locale::Maketext 1.01;
use base ('Locale::Maketext');

# I decree that this project's first language is English.

%Lexicon = (
  '_AUTO' => 1,

   'TEST_STRING' => 'Concrete Mixer',

  # That means that lookup failures can't happen -- if we get as far
  #  as looking for something in this lexicon, and we don't find it,
  #  then automagically set $Lexicon{$key} = $key, before possibly
  #  compiling it.
  
  # The exception is keys that start with "_" -- they aren't auto-makeable.

);
# End of lexicon.



1;  # End of module.

