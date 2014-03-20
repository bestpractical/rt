package RT::Extension::PSGIWrap;

use base 'Plack::Middleware';

sub call {
    my ( $self, $env ) = @_;
    my $res = $self->app->($env);
    return $self->response_cb( $res, sub {
        my $headers = shift->[1];
        Plack::Util::header_set($headers, 'X-RT-PSGIWrap' => '1');
    } );
}

sub PSGIWrap { return shift->wrap(@_) }

1;
