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

  RT::Templates - a collection of RT Template objects

=head1 SYNOPSIS

  use RT::Templates;

=head1 DESCRIPTION


=head1 METHODS

=begin testing

ok (require RT::Templates);

=end testing

=cut

use strict;
no warnings qw(redefine);


# {{{ sub _Init

=head2 _Init

  Returns RT::Templates specific init info like table and primary key names

=cut

sub _Init {
    
    my $self = shift;
    $self->{'table'} = "Templates";
    $self->{'primary_key'} = "id";
    return ($self->SUPER::_Init(@_));
}
# }}}

# {{{ LimitToNotInQueue

=head2 LimitToNotInQueue

Takes a queue id # and limits the returned set of templates to those which 
aren't that queue's templates.

=cut

sub LimitToNotInQueue {
    my $self = shift;
    my $queue_id = shift;
    $self->Limit(FIELD => 'Queue',
                 VALUE => "$queue_id",
                 OPERATOR => '!='
                );
}
# }}}

# {{{ LimitToGlobal

=head2 LimitToGlobal

Takes no arguments. Limits the returned set to "Global" templates
which can be used with any queue.

=cut

sub LimitToGlobal {
    my $self = shift;
    my $queue_id = shift;
    $self->Limit(FIELD => 'Queue',
                 VALUE => "0",
                 OPERATOR => '='
                );
}
# }}}

# {{{ LimitToQueue

=head2 LimitToQueue

Takes a queue id # and limits the returned set of templates to that queue's
templates

=cut

sub LimitToQueue {
    my $self = shift;
    my $queue_id = shift;
    $self->Limit(FIELD => 'Queue',
                 VALUE => "$queue_id",
                 OPERATOR => '='
                );
}
# }}}

# {{{ sub NewItem 

=head2 NewItem

Returns a new empty Template object

=cut

sub NewItem  {
  my $self = shift;

  use RT::Template;
  my $item = new RT::Template($self->CurrentUser);
  return($item);
}
# }}}

1;

