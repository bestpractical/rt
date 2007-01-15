package RT::Interface::Web::Request;

use strict;
use warnings;

our $VERSION = '0.30';
use base qw(HTML::Mason::Request);

sub new {
    my $class = shift;

    my $new_class = $HTML::Mason::ApacheHandler::VERSION ?
        'HTML::Mason::Request::ApacheHandler' :
            $HTML::Mason::CGIHandler::VERSION ?
                'HTML::Mason::Request::CGI' :
                    'HTML::Mason::Request';

    $class->alter_superclass( $new_class );
    $class->valid_params( %{ $new_class->valid_params } );
    my $self = $class->SUPER::new(@_);
    return if $self->is_subrequest;
    return $self;
}

=head2 callback

Method replaces deprecated component C<Element/Callback>.

Takes hash with optional C<CallbackPage>, C<CallbackName>
and C<CallabckOnce> arguments, other arguments are passed
throught to callback components.

=over4

=item CallbackPage

Page path relative to the root, leading slash is mandatory.
By default is equal to path of the caller component.

=item CallbackName

Name of the callback. C<Default> is used unless specified.

=item CallbackOnce

By default is false, otherwise runs callbacks only once per
process of the server. Such callbacks can be used to fill
structures.

=back

Searches for callback components in
F<< /Callbacks/<any dir>/CallbackPage/CallbackName >>, for
example F</Callbacks/MyExtension/autohandler/Default> would
be called as default callback for F</autohandler>.

=cut

{
my %cache = ();
my %called = ();
sub callback {
    my ($self, %args) = @_;

    my $page = delete $args{'CallbackPage'} || $self->callers(0)->path;
    my $name = delete $args{'CallbackName'} || 'Default';

    my $CacheKey = "$page--$name";
    return 1 if delete $args{'CallbackOnce'} && $called{ $CacheKey };
    ++$called{ $CacheKey };

    my $callbacks = $cache{ $CacheKey };
    unless ( $callbacks ) {
        my $path  = "/Callbacks/*$page/$name";
        my @roots = map $_->[1],
                        $HTML::Mason::VERSION <= 1.28
                            ? $self->interp->resolver->comp_root_array
                            : $self->interp->comp_root_array;

        my %seen;
        @$callbacks = sort map { 
                # Skip backup files, files without a leading package name,
                # and files we've already seen
                grep !$seen{$_}++ && !m{/\.} && !m{~$} && m{^/Callbacks/[^/]+\Q$page/$name\E$},
                $self->interp->resolver->glob_path($path, $_);
            } @roots;

        $cache{ $CacheKey } = $callbacks unless RT->Config->Get('DevelMode');
    }

    my @rv;
    push @rv, scalar $self->comp( $_, %args) foreach @$callbacks;
    return @rv;
}
}

1;
