#############################################################################
#
# If you experience problems with Apache::Session, you might want to use
# this one instead of Apache::Session::File.  It will use no locking, so
# don't expect it to be stable.  It just temporarly hides problems for you,
# unless you really know what you're doing.
#
# This is a hacked (Tobias Brox, april 2000) version of ...
#
# Apache::Session::File
# Apache persistent user sessions in the filesystem
# Copyright(c) 1998, 1999 Jeffrey William Baker (jeffrey@kathyandjeffrey.net)
# Distribute under the Artistic License
#
############################################################################

package ApacheSessionFile;

use strict;
use vars qw(@ISA $VERSION);

$VERSION = '1.00';
@ISA = qw(Apache::Session);

use Apache::Session;
use Apache::Session::NullLocker;
use Apache::Session::FileStore;

sub get_object_store {
    my $self = shift;

    return new Apache::Session::FileStore $self;
}

sub get_lock_manager {
    my $self = shift;
    
    return new Apache::Session::NullLocker $self;
}

1;
