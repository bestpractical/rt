package RT::Crypt::GnuPG::CRLFHandle;
use strict;
use warnings;

use base qw(IO::Handle);

# https://metacpan.org/module/MIME::Tools#Fuzzing-of-CRLF-and-newline-when-encoding-composing
# means that the output of $entity->print contains lines terminated by
# "\n"; however, signatures are generated off of the "correct" form of
# the MIME entity, which uses "\r\n" as the newline separator.  This
# class, used only when generating signatures, transparently munges "\n"
# newlines into "\r\n" newlines such that the generated signature is
# correct for the "\r\n"-newline version of the MIME entity which will
# eventually be sent over the wire.

sub print {
    my ($self, @args) = (@_);
    s/\r*\n/\x0D\x0A/g foreach @args;
    return $self->SUPER::print( @args );
}

1;
