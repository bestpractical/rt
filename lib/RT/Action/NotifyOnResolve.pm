# $Header$
# Copyright 2000 Tobias Brox <tobix@cpan.org> and  Jesse Vincent <jesse@fsck.com>
# Released under the terms of the GNU Public License

package RT::Action::NotifyOnResolve;

require RT::Action::Notify;

@ISA = qw(RT::Action::Notify);


#
# NotifyOnResolve is an example action which subclasses
# NotifyWatchers to show how to build a special Action to
# only act when something interesting happens.
#

# {{{ sub IsApplicable 

#
# If this transaction is "Set the Status to Resolved", then this is applicable.
# Otherwise it's not.
sub IsApplicable {
  my $self = shift;
  
  if (($self->Transaction->Field eq 'Status') and 
      ($self->Transaction->NewValue() eq 'Resolved')) {
    return(1);
  }
  else {
    return(0);
  }

}

# }}}
