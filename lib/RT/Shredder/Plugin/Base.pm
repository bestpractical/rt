package RT::Shredder::Plugin::Base;

use strict;
use warnings FATAL => 'all';

=head1 NAME

RT::Shredder::Plugin::Base - base class for Shredder plugins.

=cut

sub new
{
    my $proto = shift;
    my $self = bless( {}, ref $proto || $proto );
    $self->_Init( @_ );
    return $self;
}

sub _Init
{
    my $self = shift;
    $self->{'opt'} = { @_ };
}

=head1 USAGE

=head2 masks

If any argument is marked with keyword C<mask> then it means
that this argument support two special characters:

1) C<*> matches any non empty sequence of the characters.
For example C<*@example.com> will match any email address in
C<example.com> domain.

2) C<?> matches exactly one character.
For example C<????> will match any string four characters long.

=head1 METHODS

=head2 for subclassing in plugins

=head3 Type - is not supported yet

See F<Todo> for more info.

=cut

sub Type { return '' }

=head3 SupportArgs

Takes nothing.
Returns list of the supported plugin arguments.

Base class returns list of the arguments which all
classes B<must> support.

=cut

sub SupportArgs { return () }

=head3 HasSupportForArgs

Takes a list of argument names. Returns true if
all arguments are supported by plugin and returns
C<(0, $msg)> in other case.

=cut

sub HasSupportForArgs
{
    my $self = shift;
    my @args = @_;
    my @unsupported = ();
    foreach my $a( @args ) {
        push @unsupported, $a unless grep $_ eq $a, $self->SupportArgs;
    }
    return( 1 ) unless @unsupported;
    return( 0, "Plugin doesn't support argument(s): @unsupported" ) if @unsupported;
}

=head3 TestArgs

Takes hash with arguments and thier values and returns true
if all values pass testing otherwise returns C<(0, $msg)>.

Stores arguments hash in C<$self->{'opt'}>, you can access this hash
from C<Run> method.

Method should be subclassed if plugin support non standard arguments.

=cut

sub TestArgs
{
    my $self = shift;
    my %args = @_;
    if ( $self->{'opt'} ) {
        $self->{'opt'} = { %{$self->{'opt'}}, %args };
    } else {
        $self->{'opt'} = \%args;
    }
    return 1;
}

=head3 Run

Takes no arguments.
Executes plugin and return C<(1, @objs)> on success or
C<(0, $msg)> if error had happenned.

Method B<must> be subclassed, this class always returns error.

Method B<must> be called only after C<TestArgs> method in other
case values of the arguments are not available.

=cut

sub Run { return (0, "This is abstract plugin, you couldn't use it directly") }

=head2 utils

=head3 ConvertMaskToSQL

Takes one argument - mask with C<*> and C<?> chars and
return mask SQL chars.

=cut

sub ConvertMaskToSQL {
    my $self = shift;
    my $mask = shift || '';
    $mask =~ s/\*/%/g;
    $mask =~ s/\?/_/g;
    return $mask;
}

1;
