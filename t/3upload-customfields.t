#!/usr/bin/perl -w
use strict;

BEGIN {
    use RT;
    RT::LoadConfig;
    RT::Init;
}
use Test::More qw/no_plan/;
use Test::WWW::Mechanize;
BEGIN { 
$RT::WebPort ||= '80';
$RT::WebPath ||= ''; # Shut up a warning
};
use constant BaseURL => "http://localhost:".$RT::WebPort.$RT::WebPath."/";
use constant ImageFile => $RT::MasonComponentRoot .'/NoAuth/images/bplogo.gif';
use constant ImageFileContent => do {
    local $/;
    open my $fh, '<', ImageFile or die $!;
    binmode($fh);
    scalar <$fh>;
};

my $m = Test::WWW::Mechanize->new;
isa_ok($m, 'Test::WWW::Mechanize');
ok(1, "Connecting to ".BaseURL);
$m->get( BaseURL."?user=root;pass=password" );
$m->content_like(qr/Logout/, 'we did log in');
$m->follow_link( text => 'Configuration' );
$m->title_is(q/RT Administration/, 'admin screen');
$m->follow_link( text => 'Custom Fields' );
$m->title_is(q/Select a Custom Field/, 'admin-cf screen');
$m->follow_link( text => 'New custom field' );
$m->submit_form(
    form_name => "ModifyCustomField",
    fields => {
        TypeComposite => 'Image-0',
        LookupType => 'RT::FM::Class-RT::FM::Article',
        Name => 'img'.$$,
        Description => 'img',
    },
);
$m->title_is(qq/Created CustomField img$$/, 'admin-cf created');
$m->follow_link( text => 'Applies to' );
$m->title_is(qq/Modify associated objects for img$$/, 'pick cf screenadmin screen');
$m->form_number(3);
# Sort by numeric IDs in names
my @names = map  { $_->[1] }
            sort { $a->[0] <=> $b->[0] }
            map  { /Object-1-CF-(\d+)/ ? [ $1 => $_ ] : () }
            map  $_->name, $m->current_form->inputs;
my $tcf = pop(@names);
$m->field( $tcf => 1 );         # Associate the new CF with this queue
$m->field( $_ => undef ) for @names;    # ...and not any other. ;-)
$m->submit;

$m->content_like( qr/Object created/, 'TCF added to the queue' );
$m->follow_link( text => 'RTFM');
$m->follow_link( text => 'Articles');
$m->follow_link( text => 'New Article');

$m->title_is(qq/Create an article in class.../);

$m->follow_link( url_regex => qr/Edit.html\?Class=1/ );
$m->title_is(qq/Create a new article/);

$m->content_like(qr/Upload multiple images/, 'has a upload image field');

$tcf =~ /(\d+)$/ or die "Hey this is impossible dude";
my $upload_field = "Object-RT::FM::Article--CustomField-$1-Upload";

diag("Uploading an image to $upload_field");

$m->submit_form(
    form_name => "EditArticle",
    fields => {
        $upload_field => ImageFile,
        Name => 'Image Test '.$$,
        Summary => 'testing img cf creation',
    },
);

$m->content_like(qr/Article \d+ created/, "an article was created succesfully");

my $id = $1 if $m->content =~ /Article (\d+) created/;

$m->title_like(qr/Modify article #$id/, "Editing article $id");

$m->follow_link( text => 'bplogo.gif' );
$m->content_is(ImageFileContent, "it links to the uploaded image");
