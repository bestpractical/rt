
use strict;
use warnings;

use RT::Test tests => undef;

use RT;
my $logo;

BEGIN {
    $logo = -e $RT::StaticPath . '/images/bpslogo.png' ? 'bpslogo.png' : 'bplogo.gif';
}

use constant ImageFile => $RT::StaticPath . "/images/$logo";

use constant ImageFileContent => do {
    local $/;
    open my $fh, '<', ImageFile or die ImageFile . $!;
    binmode($fh);
    scalar <$fh>;
};

my $cf = RT::Test->load_or_create_custom_field(
    TypeComposite => 'Image-0',
    LookupType    => 'RT::Class-RT::Article',
    Name          => 'img' . $$,
    Description   => 'img',
    EntryHint     => 'Upload multiple images'
);
$cf->AddToObject( RT::Class->new( RT->SystemUser ) );
my $cf_id = $cf->Id;

my ( $url, $m ) = RT::Test->started_ok;
ok( $m->login, 'logged in' );

$m->follow_link_ok( { text => 'Articles', url_regex => qr!^/Articles/! }, 'UI -> Articles' );
$m->follow_link( text => 'Create' );
$m->submit_form_ok( { form_id => 'EditArticle', fields => { Class => 1, ClassChanged => 1 } } );
$m->title_is(qq/Create a new article/);

$m->content_like( qr/Upload multiple images/, 'has a upload image field' );

my $upload_field = "Object-RT::Article--CustomField-$cf_id-Upload";

diag("Uploading an image to $upload_field") if $ENV{TEST_VERBOSE};

$m->submit_form(
    form_name => "EditArticle",
    fields    => {
        $upload_field => ImageFile,
        Name          => 'Image Test ' . $$,
        Summary       => 'testing img cf creation',
    },
);

$m->content_like( qr/Article \d+ created/, "an article was created succesfully" );

my $id = $1 if $m->content =~ /Article (\d+) created/;

$m->title_like( qr/Modify article #$id/, "Editing article $id" );

$m->follow_link( text => $logo );
$m->content_is( ImageFileContent, "it links to the uploaded image" );

my $user_a = RT::Test->load_or_create_user(
    Name         => 'user_a',
    Password     => 'password',
    EmailAddress => 'user_a@example.com',
);
ok( $user_a && $user_a->id, 'loaded or created user' );
$user_a->PrincipalObj->GrantRight( Right => $_ ) for qw/ShowArticle SeeCustomField/;

ok( $m->login( 'user_a', 'password', logout => 1 ) );

$m->get_ok( '/Articles/Article/Display.html?id=' . $id );
$m->follow_link_ok( { text => $logo } );
$m->content_is( ImageFileContent, 'Content of img custom field' );
my $download_url = $m->uri;

$user_a->PrincipalObj->RevokeRight( Right => 'SeeCustomField' );
$m->get_ok( '/Articles/Article/Display.html?id=' . $id );
$m->text_lacks( 'img' . $$, 'No img custom field' );
$m->get($download_url);
is( $m->status, 403, 'No access to cf download url' );
$m->warning_like( qr/Permission Denied/, "got a permission denied warning" );

done_testing;
