package RT::View::Form::Field::RuleTextarea;
use warnings;
use strict;
use Jifty::View::Declare;
use JSON;
use base 'Jifty::Web::Form::Field::Textarea';

__PACKAGE__->mk_accessors(qw(signatures return_type));

sub accessors { shift->SUPER::accessors(), 'signatures', 'return_type' }

sub render_widget {
	my $self = shift;
	$self->SUPER::render_widget(@_);
	$self->render_rulebuilder_launcher();
	'';
}

sub render_rulebuilder_launcher {
    my $self = shift;
    my $signatures = $self->attributes->{signatures};
    my $return_type = $self->attributes->{return_type};
    my $params_json = to_json(
        [ map { { expression => $_->{name}, type => $_->{type} } }
              @$signatures ] );
    Jifty->web->out(qq{
<input type="submit" value="Edit!" onClick='RuleBuilder.load_and_edit_lambda($params_json, "$return_type", this);' />
});

}
1;

