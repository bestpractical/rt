package RT::Action::CommentOnTicket;
use strict;
use warnings;
use base 'RT::Action::ReplyToTicket';

sub type { 'comment' }

1;
