# BEGIN LICENSE BLOCK
# 
# Copyright (c) 1996-2003 Jesse Vincent <jesse@bestpractical.com>
# 
# (Except where explictly superceded by other copyright notices)
# 
# This work is made available to you under the terms of Version 2 of
# the GNU General Public License. A copy of that license should have
# been provided with this software, but in any event can be snarfed
# from www.gnu.org.
# 
# This work is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# General Public License for more details.
# 
# Unless otherwise specified, all modifications, corrections or
# extensions to this work which alter its source code become the
# property of Best Practical Solutions, LLC when submitted for
# inclusion in the work.
# 
# 
# END LICENSE BLOCK
=head1 NAME

  RT::Action::Generic - a generic baseclass for RT Actions

=head1 SYNOPSIS

  use RT::Action::Generic;

=head1 DESCRIPTION

=head1 METHODS

=begin testing

ok (require RT::Action::Generic);

=end testing

=cut

package RT::Action::Generic;

use strict;

# {{{ sub new 
sub new  {
  my $proto = shift;
  my $class = ref($proto) || $proto;
  my $self  = {};
  bless ($self, $class);
  $self->_Init(@_);
  return $self;
}
# }}}

# {{{ sub new 
sub loc {
    my $self = shift;
    return $self->{'ScripObj'}->loc(@_);
}
# }}}

# {{{ sub _Init 
sub _Init  {
  my $self = shift;
  my %args = ( TransactionObj => undef,
	       TicketObj => undef,
	       ScripObj => undef,
	       TemplateObj => undef,
	       Argument => undef,
	       Type => undef,
	       @_ );
  
  
  $self->{'Argument'} = $args{'Argument'};
  $self->{'ScripObj'} = $args{'ScripObj'};
  $self->{'TicketObj'} = $args{'TicketObj'};
  $self->{'TransactionObj'} = $args{'TransactionObj'};
  $self->{'TemplateObj'} = $args{'TemplateObj'};
  $self->{'Type'} = $args{'Type'};
}
# }}}

# Access Scripwide data

# {{{ sub Argument 
sub Argument  {
  my $self = shift;
  return($self->{'Argument'});
}
# }}}

# {{{ sub TicketObj
sub TicketObj  {
  my $self = shift;
  return($self->{'TicketObj'});
}
# }}}

# {{{ sub TransactionObj
sub TransactionObj  {
  my $self = shift;
  return($self->{'TransactionObj'});
}
# }}}

# {{{ sub TemplateObj
sub TemplateObj  {
  my $self = shift;
  return($self->{'TemplateObj'});
}
# }}}

# {{{ sub ScripObj
sub ScripObj  {
  my $self = shift;
  return($self->{'ScripObj'});
}
# }}}

# {{{ sub Type
sub Type  {
  my $self = shift;
  return($self->{'Type'});
}
# }}}


# Scrip methods

#Do what we need to do and send it out.

# {{{ sub Commit 
sub Commit  {
  my $self = shift;
  return(0, $self->loc("Commit Stubbed"));
}
# }}}


#What does this type of Action does

# {{{ sub Describe 
sub Describe  {
  my $self = shift;
  return $self->loc("No description for [_1]", ref $self);
}
# }}}


#Parse the templates, get things ready to go.

# {{{ sub Prepare 
sub Prepare  {
  my $self = shift;
  return (0, $self->loc("Prepare Stubbed"));
}
# }}}


#If this rule applies to this transaction, return true.

# {{{ sub IsApplicable 
sub IsApplicable  {
  my $self = shift;
  return(undef);
}
# }}}

# {{{ sub DESTROY
sub DESTROY {
    my $self = shift;

    # We need to clean up all the references that might maybe get
    # oddly circular
    $self->{'TemplateObj'} =undef
    $self->{'TicketObj'} = undef;
    $self->{'TransactionObj'} = undef;
    $self->{'ScripObj'} = undef;


     
}

# }}}

eval "require RT::Action::Generic_Vendor";
die $@ if ($@ && $@ !~ qr{^Can't locate RT/Action/Generic_Vendor.pm});
eval "require RT::Action::Generic_Local";
die $@ if ($@ && $@ !~ qr{^Can't locate RT/Action/Generic_Local.pm});

1;
