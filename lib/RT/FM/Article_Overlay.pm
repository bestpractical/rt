# BEGIN LICENSE BLOCK
# 
#  Copyright (c) 2002 Jesse Vincent <jesse@bestpractical.com>
#  
#  This program is free software; you can redistribute it and/or modify
#  it under the terms of version 2 of the GNU General Public License 
#  as published by the Free Software Foundation.
# 
#  A copy of that license should have arrived with this
#  software, but in any event can be snarfed from www.gnu.org.
# 
#  This program is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#  GNU General Public License for more details.
# 
# END LICENSE BLOCK

no warnings qw/redefine/;


use RT::FM::CustomField;
use RT::FM::Class;

# {{{ Create


=item Create PARAMHASH

Create takes a hash of values and creates a row in the database:

  varchar(200) 'Name'.
  varchar(200) 'Summary'.
  int(11) 'Content'.
  Class ID  'Class'

  A paramhash called  'CustomFields', which contains 
  arrays of values for each custom field you want to fill in.
  Arrays aRe ordered. 



=begin testing

use_ok(RT::FM::Article);
use_ok(RT::FM::Class);

my $user = RT::CurrentUser->new('root');

my $article = RT::FM::Article->new($user);
ok (UNIVERSAL::isa($article, 'RT::FM::Article'));
ok (UNIVERSAL::isa($article, 'RT::FM::Record'));
ok (UNIVERSAL::isa($article, 'RT::Record'));
ok (UNIVERSAL::isa($article, 'DBIx::SearchBuilder::Record'));

my $class = RT::FM::Class->new($user);


my ($id, $msg) = $class->Create(Name =>'ArticleTest');
ok ($id, $msg);

($id, $msg) = $article->Create( Class => 'ArticleTest', Summary => "ArticleTest");
ok ($id, $msg);
$article->Load($id);
is ($article->Summary, 'ArticleTest');
my $at = RT::FM::Article->new($RT::SystemUser);
$at->Load($id);
is ($at->id , $id);
is ($at->Summary, $article->Summary);


=end testing


=cut




sub Create {
    my $self = shift;
    my %args = ( 
                Name => undef,
                Summary => undef,
                Class => undef,
                CustomFields => { },
		  @_);

    my $class = RT::FM::Class->new($RT::SystemUser);
    $class->Load($args{'Class'});
    unless ($class->Id) {
        return(0,$self->loc('Invalid Class'));
    }

    $RT::Handle->BeginTransaction();
    my ($id, $msg) =  $self->SUPER::Create(
                         Name => $args{'Name'},
                         Class => $class->Id,
                         Summary => $args{'Summary'},
			);
    unless ($id) {
        $RT::Handle->Rollback();
        return (undef, $msg);
    }

    my %cfs  = %{$args{'CustomFields'}};


    foreach my $cf (keys %cfs) {
        # Process custom field values
    }


    $RT::Handle->Commit();

    return($id, $msg);
}

# }}}

# {{{ Children

=item Children

Returns an RT::FM::ArticleCollection object which contains
all articles which have this article as their parent.  This 
routine will not recurse and will not find grandchildren, great-grandchildren, uncles, aunts, nephews or any other such thing.  

=cut

sub Children {
    my $self = shift;
    my $kids = new RT::FM::ArticleCollection($self->CurrentUser);
    $kids->LimitToParent($self->Id);
    return($kids);
}

# }}}


# {{{ CustomFieldValues

=item CustomFieldValues CUSTOMFIELD_ID

Returns an RT::FM::CustomFieldObjectValueCollection object containing
the values of CustomField CUSTOMFIELDID for this Article


=cut

sub CustomFieldValues {
    my $self = shift;
    my $customfield = shift;
    
    my $cfovc = new RT::FM::ArticleCFValueCollection($self->CurrentUser);
    $cfovc->LimitToArticle($self->Id);
    $cfovc->LimitToCustomField($customfield);
    return ($cfovc);
}

# }}}

# {{{ AddCustomFieldValue

=item AddCustomFieldValue { Field => FIELD, Value => VALUE }

VALUE can either be a CustomFieldValue object or a string.
FIELD can be a CustomField object OR a CustomField ID.


Adds VALUE as a value of CustomField FIELD.  If this is a single-value custom field,
deletes the old value. 
If VALUE isn't a valid value for the custom field, returns 
(0, 'Error message' ) otherwise, returns (1, 'Success Message')


=begin testing


my $art = RT::FM::Article->new($RT::SystemUser);
my ($id,$msg) =$art->Create(Class => 'ArticleTest');
ok ($id, $msg);

my $cf = RT::FM::CustomField->new($RT::SystemUser);
($id, $msg) =$cf->Create(Name => "Test", Type => "SelectMultiple");
ok ($id, $msg);
($id, $msg) = $cf->AddValue(Name => "Test1");
ok ($id, $msg);

($id, $msg) = $cf->AddValue(Name => "Testy");
ok ($id, $msg);

($id, $msg )= $cf->AddToClass('ArticleTest');
ok ($id, $msg);

$id = $cf->ValidForClass('ArticleTest');
ok ($id, "This cf is good for the class 'ArticleTest'");
$id = $cf->ValidForClass($art->ClassObj->Name);
ok ($id, "This cf is good for the class ".$art->ClassObj->Name);

($id, $msg) = $art->AddCustomFieldValue( Field => "Test", Content => "Test1");
ok ($id, $msg);
($id, $msg) = $art->AddCustomFieldValue( Field => "Test", Content => "Test1");
ok (!$id, "Can't add a duplicate value to a custom field that's a 'select multiple' - $msg");

($id, $msg) = $art->AddCustomFieldValue( Field => "Test", Content => "Testy");
ok ($id, $msg);


($id, $msg) = $art->AddCustomFieldValue( Field => "Test", Content => "TestFroboz");
ok (!$id, "Can't add a non-existent value to a custom field that's a 'select multiple' - $msg");

=end testing




=cut

sub AddCustomFieldValue {
    my $self = shift;
  #  unless ( $self->CurrentUserHasRight('ModifyTicket') ) {
  #      return ( 0, $self->loc("Permission Denied") );
  #  }
    $self->_AddCustomFieldValue(@_);
}

sub _AddCustomFieldValue {
    my $self = shift;
    my %args = ( Field             => undef,
                 Content            => undef,
                 RecordTransaction => 1,
                 @_ );

    # {{{ Get the custom field we're talking about

    my $cf = RT::FM::CustomField->new( $self->CurrentUser );
    if ( UNIVERSAL::isa( $args{'Field'}, "RT::FM::CustomField" ) ) {
        $cf->Load( $args{'Field'}->id );
    }
    else {
        $cf->Load( $args{'Field'} );
    }


    unless ($cf->ValidForClass($self->__Value('Class')) ) {
        return( 0, $self->loc("Custom field [_1] not valid for that article", $args{'Field'}));
    }

    unless ( $cf->Id ) {
        return ( 0,
                 $self->loc( "Custom field [_1] not found", $args{'Field'} ) );
    }
    # }}}



    # Load up a ArticleCFValueCollection object for this custom field 
    my $values = $cf->ValuesForArticle( $self->id );


    # If the custom field only accepts a single value, delete the existing
    # value and record a "changed from foo to bar" transaction
    if ( $cf->SingleValue ) {
        # {{{ We need to whack any old values here.  In most cases, the custom field should
        # only have one value to delete.  In the pathalogical case, this custom field
        # used to be a multiple and we have many values to whack....
        my $cf_values = $values->Count;

        if ( $cf_values > 1 ) {
            my $i = 0;   #We want to delete all but the last one, so we can then
                 # execute the same code to "change" the value from old to new
            while ( my $value = $values->Next ) {
                $i++;
                if ( $i < $cf_values ) {
                    my $old_value = $value->Content;
                    my ( $val, $msg ) = $cf->DeleteValueForArticle(
                                                      Article => $self->Id,
                                                      Content => $value->Content
                    );
                    unless ($val) {
                        return ( 0, $msg );
                    }
                    my ( $TransactionId, $Msg, $TransactionObj ) =
                      $self->_NewTransaction( Type     => 'CustomField',
                                              Field    => $cf->Id,
                                              OldValue => $old_value );
                }
            }
        }
        # }}}


        # {{{ Add a new custom field value
        my $value     = $cf->ValuesForArticle( $self->Id )->First;
        my $old_value = $value->Content();

        my ( $new_value_id, $value_msg ) = $cf->AddValueForArticle(
                                                       Article  => $self->Id,
                                                       Content => $args{'Content'}
        );

     
        unless ($new_value_id) {
            return ( 0, $self->loc( "Could not add new custom field value for Article. [_1] ", $value_msg ) );
        }
        # }}}

        # {{{ Kill the old value
        my $new_value = RT::ArticleCustomFieldValue->new( $self->CurrentUser );
        $new_value->Load($value_id);

        # now that adding the new value was successful, delete the old one
        my ( $val, $msg ) = $cf->DeleteValueForArticle(Article  => $self->Id,
                                                      Content => $value->Content
        );
        unless ($val) {
            return ( 0, $msg );
        }


        # }}} 

        # {{{ Record the "Changed" transaction
        if ( $args{'RecordTransaction'} ) {
            my ( $TransactionId, $Msg, $TransactionObj ) =
              $self->_NewTransaction( Type     => 'CustomField',
                                      Field    => $cf->Id,
                                      OldValue => $old_value,
                                      NewValue => $new_value->Content );
        }
        return ( 1, $self->loc( "Custom field value changed from [_1] to [_2]", $old_value, $new_value->Content ) );
        # }}}
    }

    # otherwise, just add a new value and record "new value added"
    else {

        # {{{ Add a custom field value
        my ($new_value_id, $new_value_msg) = $cf->AddValueForArticle( Article  => $self->Id, Content => $args{'Content'});

        unless ($new_value_id) {
            return ( 0, $self->loc( "Could not add new custom field value for Article. [_1]", $new_value_msg) );
        }
        # }}}

        # {{{ Record a tranaction
        if ( $args{'RecordTransaction'} ) {
            my ( $TransactionId, $Msg, $TransactionObj ) =
              $self->_NewTransaction( Type     => 'CustomField',
                                      Field    => $cf->Id,
                                      NewValue => $args{'Value'} );
            unless ($TransactionId) {
                return ( 0, $self->loc( "Couldn't create a transaction: [_1]", $Msg) );
            }
        }
        return ( $new_value_id , $self->loc( "[_1] added as a value for [_2]", $args{'Value'}, $cf->Name ) );

        # }}}
    }

}

# }}}

# {{{ DeleteCustomFieldValue

=item DeleteCustomFieldValue
  
  Takes a paramhash. Deletes the Keyword denoted by the I<Keyword> parameter from this
  ticket's object keywords.

=cut

sub DeleteCustomFieldValue {
    my $self = shift;
    my %args = ( Value => undef,
		 CustomField => undef,
		 @_ );

    #Load up the ObjectKeyword we\'re talking about
    my $CFObjectValue = new RT::FM::CustomFieldObjectValue($self->CurrentUser);
    $CFObjectValue->LoadByCols( Content  => $args{'Value'},
			        CustomField => $args{'CustomField'},
			        Article => $self->id()
			      );
    
    #if we can\'t find it, bail
    unless ($CFObjectValue->id) {
	return (undef, "Couldn't load custom field valuewhile trying to delete it.");
    };
    
    #record transaction here.
   
    $CFObjectValue->Delete();
    
    return (1, "Value ".$CFObjectValue-Name ." deleted from custom field ".$CustomField.".");
    
}

# }}}

# {{{ _NewTransaction

=head2 _NewTransaction

NOT IMPLEMENTED YET

=cut

sub _NewTransaction {
    my $self = shift;
    $RT::Logger->crit("$self _NewTransaction not implemented");
    return 1;
}

# }}}
1;
