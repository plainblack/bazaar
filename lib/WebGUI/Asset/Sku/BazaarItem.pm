package WebGUI::Asset::Sku::BazaarItem;

=head1 LEGAL

 -------------------------------------------------------------------
  WebGUI is Copyright 2001-2008 Plain Black Corporation.
 -------------------------------------------------------------------
  Please read the legal notices (docs/legal.txt) and the license
  (docs/license.txt) that came with this distribution before using
  this software.
 -------------------------------------------------------------------
  http://www.plainblack.com                     info@plainblack.com
 -------------------------------------------------------------------

=cut

use strict;
use Tie::IxHash;
use Class::C3;
use base qw(WebGUI::AssetAspect::Comments WebGUI::Asset::Sku);
use JSON;
use WebGUI::Asset::Template;
use WebGUI::Exception;
use WebGUI::Form;
use WebGUI::Group;
use WebGUI::Keyword;
use WebGUI::Macro;
use WebGUI::Shop::Vendor;
use WebGUI::Storage;
use WebGUI::Storage::Image;
use WebGUI::User;
use WebGUI::Utility qw/isIn/;


=head1 NAME

Package WebGUI::Asset::Sku::BazaarItem

=head1 DESCRIPTION

This sku works in conjunction with WebGUI::Asset::Wobject::Bazaar to build a digital download system.

=head1 SYNOPSIS

use WebGUI::Asset::Sku::Bazaar;

=head1 METHODS

These methods are available from this class:

=cut

#-------------------------------------------------------------------
sub canAdd {
	my $class = shift;
	my $session = shift;
	return $class->next::method($session, undef, '7');
}

#-------------------------------------------------------------------
sub canDownload {
	my $self = shift;
	return $self->session->user->userId eq $self->get('ownerUserId')
		|| $self->session->user->isInGroup($self->getDownloadGroup->getId)
		|| $self->canEdit;
}

#-------------------------------------------------------------------
sub canEdit {
	my $self = shift;
	my $form = $self->session->form;
	return $self->next::method  # account for normal editing
		|| $self->getParent->canEdit; # account for admins
}

#-------------------------------------------------------------------

=head2 canView ( )

Returns a boolean indicating whether the user can view the current item.

=cut

sub canView {
	my $self = shift;
	if (($self->get("status") eq "approved" || $self->get("status") eq "archived") && $self->getParent->canView) {
			return 1;
	}
	elsif ($self->canEdit) {
			return 1;
	}
	else {
			$self->getParent->canEdit;
	}
}


#-------------------------------------------------------------------

=head2 definition

Adds fields custom to this class.

=cut

sub definition {
	my $class = shift;
	my $session = shift;
	my $definition = shift;
	my %properties;
	tie %properties, 'Tie::IxHash';
	%properties = (
		product => {
			tab             => "properties",
			fieldType       => "file",
			defaultValue    => undef,
			label           => 'Product',
			maxAttachments	=> 5,
			hoverHelp       => 'The file that can be downloaded.',
			},
		screenshots => {
			tab             => "properties",
			fieldType       => "image",
			defaultValue    => undef,
			label           => 'Screen Shots',
			maxAttachments	=> 5,
			hoverHelp       => 'Images captured of the product.',
			},
		requirements => {
			tab             => "properties",
			fieldType       => "HTMLArea",
			defaultValue    => undef,
			label           => 'Requirements',
			hoverHelp       => 'The prerequisites to use this product.',
			},
		versionNumber => {
			tab             => "properties",
			fieldType       => "text",
			defaultValue    => 1,
			label           => 'Version Number',
			hoverHelp       => 'What release number is it?',
			},
		releaseDate => {
			tab             => "properties",
			fieldType       => "date",
			defaultValue    => WebGUI::DateTime->new($session, time())->toDatabaseDate,
			label           => 'Release Date',
			hoverHelp       => 'The date this version of the product was released publicly.',
			},
		releaseNotes => {
			tab             => "properties",
			fieldType       => "HTMLArea",
			defaultValue    => undef,
			label           => 'Release Notes',
			hoverHelp       => 'Information about this release or the release history.',
			},
		supportUrl => {
			tab             => "properties",
			fieldType       => "url",
			defaultValue    => undef,
			label           => 'Support URL',
			hoverHelp       => 'A URL where a user can find help for this product.',
			},
		moreInfoUrl => {
			tab             => "properties",
			fieldType       => "url",
			defaultValue    => undef,
			label           => 'More Info URL',
			hoverHelp       => 'A URL where a user can find out more details about this product.',
			},
		demoUrl => {
			tab             => "properties",
			fieldType       => "url",
			defaultValue    => undef,
			label           => 'Demo URL',
			hoverHelp       => 'A URL where a user can see this product in action.',
			},
		price => {
			tab             => "shop",
			fieldType       => "float",
			defaultValue    => 0.00,
			label           => 'Price',
			hoverHelp       => 'The amount to be paid to download this item.',
			},
		downloadPeriod => {
			tab             => "shop",
			fieldType       => "interval",
			defaultValue    => 60*60*24*365,
			label           => 'Download Period',
			hoverHelp       => 'The amount of time the user will have to download the item and updates.',
			},
		groupToDownload => {
			noFormPost		=> 1,
			fieldType       => "hidden",
			defaultValue    => 7,
			},
		groupToSubscribe => {
			noFormPost		=> 1,
			fieldType       => "hidden",
			defaultValue    => undef,
			},
		views => {
			noFormPost		=> 1,
			fieldType       => "hidden",
			defaultValue    => 0,
			},
		downloads => {
			noFormPost		=> 1,
			fieldType       => "hidden",
			defaultValue    => 0,
			},
	    );
	push(@{$definition}, {
		assetName           => 'Bazaar Item',
		icon                => 'assets.gif',
		autoGenerateForms   => 1,
		tableName           => 'bazaarItem',
		className           => 'WebGUI::Asset::Sku::BazaarItem',
		properties          => \%properties
	    });
	return $class->next::method($session, $definition);
}

#-------------------------------------------------------------------
sub getAddToCartForm {
    my $self    = shift;
    my $session = $self->session;

    my $form = 
        WebGUI::Form::formHeader($session,  { action    => $self->getUrl                    } )
        . WebGUI::Form::hidden($session,    { name      => 'func',          value => 'buy'  } )
        . WebGUI::Form::submit($session,    { value     => 'Add to Cart'                    } )
        . WebGUI::Form::formFooter($session);

    return $form;
}

#-------------------------------------------------------------------
sub getAutoCommitWorkflowId {
	my $self = shift;
	return qw( pbworkflow000000000003 );
}

#-------------------------------------------------------------------
sub getDownloadGroup {
	my $self = shift;
	if (exists $self->{_groupToDownload}) {
		return $self->{_groupToDownload};
	}
	elsif ($self->get('groupToDownload') eq '7' && $self->getPrice > 0) {
		my $g = WebGUI::Group->new($self->session,'new');
		$g->name('Download Group for '.$self->getTitle.' ('.$self->getId.')');
		$g->description('This group can download the files attached to bazaar item '.$self->getTitle.' ('.$self->getId.')');
		$self->update({groupToDownload=>$g->getId});
		$self->{_groupToDownload} = $g;
	}
	else {
		$self->{_groupToDownload} = WebGUI::Group->new($self->session, $self->get('groupToDownload'));
	}
	return $self->{_groupToDownload};
}


#-------------------------------------------------------------------
sub getEditForm {
	my $self = shift;
	my $session = $self->session;
	my $form = $session->form;
	my $newPage = 0;
	my $out = "";
	my $bazaar = $self->getParent;
	my $url = ($self->getId eq "new") ? $bazaar->getUrl : $self->getUrl;
	my $f = WebGUI::HTMLForm->new($session, {action=>$url});
	$f->hidden(
		name	=> 'func',
		value 	=> 'editSave'
		);
	$f->hidden(
		name	=>"proceed",
		value	=>"view"
		);
	if ($self->getId eq "new") {
		$f->hidden(
			name	=> "assetId",
			value	=> "new"
		);
		$f->hidden(
			name	=> "class",
			value	=> $form->process("class","className")
		);
	}
	
	# product info
	$f->fieldSetStart('Product Information');
	$f->text(
		label	=> 'Title',
		name	=> 'title',
		value	=> $self->get('title'),
	);
	$f->textarea(
		label	=> 'Short Description',
		name	=> 'synopsis',
		value	=> $self->get('synopsis'),
	);
	$f->HTMLArea(
		label		=> 'Full Description',
		richEditId	=> 'PBrichedit000000000002',
		name		=> 'description',
		value		=> $self->get('description'),
	);
	$f->url(
		label	=> 'More Information URL',
		name	=> 'moreInfoUrl',
		value	=> $self->get('moreInfoUrl'),
	);
	$f->url(
		label	=> 'Support URL',
		name	=> 'supportUrl',
		value	=> $self->get('supportUrl'),
	);
	$f->url(
		label	=> 'Demo URL',
		name	=> 'demoUrl',
		value	=> $self->get('demoUrl'),
	);
	$f->image(
		name			=> "screenshots",
		label			=> "Screen Shots",
		maxAttachments	=> 5,
		value			=> $self->get('screenshots'),
	);
	$f->file(
		name			=> "product",
		label			=> "Product File(s)",
		maxAttachments	=> 5,
		value			=> $self->get('product'),
	);
	$f->fieldSetEnd;
	
	# release info
	$f->fieldSetStart('This Release');
	$f->text(
		label			=> 'Version Number',
		name			=> 'versionNumber',
		value			=> $self->get('versionNumber'),
		defaultValue	=> 1,
	);
	$f->date(
		label			=> 'Release Date',
		name			=> 'releaseDate',
		defaultValue	=> WebGUI::DateTime->new($session, time())->toDatabaseDate,
	);
	$f->HTMLArea(
		label		=> 'Release Notes',
		richEditId	=> 'PBrichedit000000000002',
		name		=> 'releaseNotes',
		value		=> $self->get('releaseNotes'),
	);
	$f->HTMLArea(
		label		=> 'Requirements',
		richEditId	=> 'PBrichedit000000000002',
		name		=> 'requirements',
		value		=> $self->get('requirements'),
	);
	$f->fieldSetEnd;

	# vendor info
	$f->fieldSetStart('Vendor Information');
	if ($session->user->isAdmin) {
		$f->vendor(
			label	=> 'Vendor',
			name	=> 'vendorId',
			value	=> $self->get('vendorId'),
		);
	}
	else {
		my $vendor = eval { WebGUI::Shop::Vendor->newByUserId($session)};
		my $vendorInfo = {};
		unless (WebGUI::Error->caught) {
			$vendorInfo = $vendor->get;
		}
		$f->text(
			label	=> 'Name',
			name	=> 'vendorName',
			value	=> $vendorInfo->{name},
		);
		$f->text(
			label	=> 'URL',
			name	=> 'vendorUrl',
			value	=> $vendorInfo->{url},
		);
		$f->selectBox(
			label			=> 'Preferred Payment Method',
			name			=> 'vendorPaymentMethod',
			options			=> {PayPal => 'PayPal'},
			value			=> $vendorInfo->{preferredPaymentType},
		);
		$f->textarea(
			label			=> 'Payment Address',
			name			=> 'vendorPaymentInformation',
			value			=> $vendorInfo->{paymentInformation},
		);
	}
	$f->fieldSetEnd;

	# bazaar info
	$f->fieldSetStart('Bazaar Settings');
	$f->float(
		label		=> 'Price',
        name		=> 'price',
        value   	=> $self->get('price'),
		defaultValue	=> 0.00,
 	);
	$f->interval(
		label		=> 'Download Period',
        name		=> 'downloadPeriod',
		hoverHelp	=> 'The amount of time the user will have to download the product and updates.',
        value   	=> $self->get('downloadPeriod'),
		defaultValue	=> 60*60*24*365,
 	);
	$f->text(
		label	=> 'Keywords',
		subtext	=> 'eg: asset utility',
        name	=> 'keywords',
        value   => WebGUI::Keyword->new($session)->getKeywordsForAsset({asset=>$self}),
 	);
	$f->fieldSetEnd;
	$f->submit;
	return $f;
}

#-------------------------------------------------------------------
sub getKeywordLoopVars {
    my $self    = shift;
    my $session = $self->session;
    my $bazaar  = $self->getParent; 

	my $keywords = WebGUI::Keyword->new( $session )->getKeywordsForAsset( {
        asset		=> $self,
        asArrayRef	=> 1,
    } );

    my @keywordLoop;
    foreach my $word ( @{ $keywords } ) {
        push @keywordLoop, {
            keyword_word        => $word,
            keyword_searchUrl   => $bazaar->getUrl( "func=byKeyword;keyword=" . $word ),
        }
    }

    return \@keywordLoop;
}

#-------------------------------------------------------------------

sub getMaxAllowedInCart {
	my $self = shift;
    return 1;
}


#-------------------------------------------------------------------

=head2 getPrice

Returns the price field.

=cut

sub getPrice {
    my $self = shift;
    return $self->get("price") || 0.00;
}

#-------------------------------------------------------------------
sub getProductLoopVars {
    my $self    = shift;
    my $storage = $self->getProductStorage;

    my @productFiles;
    foreach my $file ( @{ $storage->getFiles } ) {
        push @productFiles, {
            product_icon        => $storage->getFileIconUrl( $file ),
            product_filename    => $file,
            product_downloadUrl => $self->getUrl( 'func=download;filename=' . $file ),
            product_url         => $storage->getUrl( $file ),
        };
    }

    return \@productFiles;
}

#-------------------------------------------------------------------
sub getProductStorage {
	my $self = shift;
	unless (exists $self->{_productStorage}) {
		if ($self->get("product") eq "") {
			$self->{_productStorage} = WebGUI::Storage->create($self->session);
			$self->update({product=>$self->{_productStorage}->getId});
		}
		else {
			$self->{_productStorage} = WebGUI::Storage->get($self->session,$self->get("product"));
		}
		$self->{_productStorage}->setPrivileges(
			$self->get('ownerUserId'),
			$self->getDownloadGroup->getId,
			$self->getParent->get('groupIdEdit')
			);
	}
	return $self->{_productStorage};
}

#-------------------------------------------------------------------
sub getScreenLoopVars {
    my $self    = shift;
    my $storage = $self->getScreenStorage;

    my @screenFiles;
    foreach my $file ( @{ $storage->getFiles } ) {
        push @screenFiles, {
            screen_url          => $storage->getUrl( $file ),
            screen_thumbnailUrl => $storage->getThumbnailUrl( $file ),
        };
    }

    return \@screenFiles;
}

#-------------------------------------------------------------------
sub getScreenStorage {
	my $self = shift;
	unless (exists $self->{_screenStorage}) {
		if ($self->get("screenshots") eq "") {
			$self->{_screenStorage} = WebGUI::Storage::Image->create($self->session);
			$self->update({screenshots=>$self->{_screenStorage}->getId});
		}
		else {
			$self->{_screenStorage} = WebGUI::Storage::Image->get($self->session,$self->get("screenshots"));
		}
	}
	return $self->{_screenStorage};
}

#-------------------------------------------------------------------
sub getSubscriptionGroup {
	my $self = shift;
	if (exists $self->{_groupToSubscribe}) {
		return $self->{_groupToSubscribe};
	}
	elsif ($self->get('groupToSubscribe') eq '') {
		my $g = WebGUI::Group->new($self->session,'new');
		$g->name('Subscribtion Group for '.$self->getTitle.' ('.$self->getId.')');
		$g->description('This group can subscribe to the bazaar item '.$self->getTitle.' ('.$self->getId.')');
		$self->update({groupToSubscribe=>$g->getId});
		$g->deleteGroups([3]);
		$self->{_groupToSubscribe} = $g;
	}
	else {
		$self->{_groupToSubscribe} = WebGUI::Group->new($self->session, $self->get('groupToSubscribe'));
	}
	return $self->{_groupToSubscribe};
}

#-------------------------------------------------------------------

=head2 getThumbnailUrl ( )

Returns a screenshot thumbnail.

=cut

sub getThumbnailUrl {
    my $self = shift;
	my $screens = $self->getScreenStorage;
	my $file = $screens->getFiles->[0];
	if ($file) {
		return $screens->getThumbnailUrl($file);
	}
	return undef;
}

#-------------------------------------------------------------------
sub getViewVars {
    my $self        = shift;
    my $session     = $self->session;
    my $datetime    = $session->datetime;
    my $bazaar      = $self->getParent;

    # Fetch asset properties
    my $vars    = $self->get;

    # Fetch vendor information
    my $vendor      = WebGUI::Shop::Vendor->new( $session, $self->get('vendorId') );
    unless (WebGUI::Error->caught || $vendor->get('name') eq 'Default Vendor') {
        my $vendorInfo  = $vendor->get;
        foreach my $key (keys %{ $vendorInfo }) {
            $vars->{ "vendor_$key"    } = $vendorInfo->{ $key };
        }
    }

    $vars->{ title                  } = $self->getTitle;
    $vars->{ canDownload            } = $self->canDownload;
    $vars->{ releaseDate            } = 
        $datetime->epochToHuman( 
            $datetime->setToEpoch( $self->get('releaseDate') ), 
            '%z' 
        );
    $vars->{ productFiles_loop      } = $self->getProductLoopVars;
    $vars->{ screenFiles_loop       } = $self->getScreenLoopVars;
    $vars->{ price                  } = sprintf '%.2f', $self->getPrice;
    $vars->{ hasPrice               } = $self->getPrice > 0;
    $vars->{ isInCart               } = $self->{ _hasAddedToCart };
    $vars->{ addToCart_form         } = $self->getAddToCartForm;

    $vars->{ rating                 } = $self->getAverageCommentRatingIcon;
    $vars->{ lastUpdated            } = $datetime->epochToHuman( $self->get('revisionDate'), '%z' );

    $vars->{ comments               } = $self->getFormattedComments;

    # subscription
    $vars->{ isVisitor              } = $session->user->userId eq 1;
    $vars->{ isSubScribed           } = $self->isSubscribed;
    $vars->{ subscriptionToggleUrl  } = $self->getUrl( 'func=toggleSubscription' );

    # keywords
    $vars->{ keyword_loop           } = $self->getKeywordLoopVars;
   
    # management
    $vars->{ canEdit                } = $self->canEdit;
    $vars->{ delete_url             } = $self->getUrl( 'func=delete' );
    $vars->{ edit_url               } = $self->getUrl( 'func=edit' );

    # navigation
    $vars->{ search_byVendorUrl     } = $bazaar->getUrl( 'func=byVendor;vendorId=' . $vars->{ 'vendor_vendorId' } );
    $vars->{ bazaar_url             } = $bazaar->getUrl;

    return $vars;
}

#-------------------------------------------------------------------
sub indexContent {
	my $self = shift;
	my $indexer = $self->next::method;
	$indexer->addKeywords($self->get("releaseNotes"));
	$indexer->addKeywords($self->get("requirements"));
}

#-------------------------------------------------------------------
sub isSubscribed {
	my $self = shift;
	return $self->session->user->isInGroup($self->getSubscriptionGroup->getId);
}

#-------------------------------------------------------------------
sub leaveComment {
	my $self = shift;
	$self->next::method(@_);
	$self->notifySubscribers($_[0]);
}

#-------------------------------------------------------------------

=head2 notifySubscribers ( message )

Send notifications to the thread and forum subscribers that a new post has been made.

=cut

sub notifySubscribers {
    my $self = shift;
	my $message = shift;
	my $subject = shift || $self->getTitle." - Subscription Notification";
	my $from = shift || WebGUI::User->new($self->session, $self->get('ownerUserId'))->profileField('email');
	my $siteurl =  $self->session->url->getSiteURL();
    my $mail = WebGUI::Mail::Send->create($self->session, {
			from=>"<".$from.">",
			toGroup=>$self->getSubscriptionGroup,
			subject=>$subject,
			});
    $mail->addHeaderField("List-ID", $self->getTitle." <".$self->getId.">");
    $mail->addHeaderField("List-Unsubscribe", "<".$siteurl.$self->getUrl('func=toggleSubscription').">");
    $mail->addHeaderField("List-Subscribe", "<".$siteurl.$self->getUrl('func=toggleSubscription').">");
    $mail->addHeaderField("Sender", "<".$from.">");
    $mail->addHeaderField("List-Post", "No");
    $mail->addHeaderField("List-Archive", "<".$siteurl.$self->getUrl.">");
    $mail->addHeaderField("X-Unsubscribe-Web", "<".$siteurl.$self->getUrl('func=toggleSubscription').">");
    $mail->addHeaderField("X-Subscribe-Web", "<".$siteurl.$self->getUrl('func=toggleSubscription').">");
    $mail->addHeaderField("X-Archives", "<".$siteurl.$self->getUrl.">");
	$mail->addHtml($message . '<p><a href="'.$siteurl.$self->getUrl.'">View Online</a></p>');
	$mail->addFooter;
	$mail->queue;
}

#-------------------------------------------------------------------

=head2 onCompletePurchase ( item )

Adds the user to the download group.

=cut

sub onCompletePurchase {
	my ($self, $item) = @_;
	$self->getDownloadGroup->addUsers([$item->transaction->get('userId')], $self->get('downloadPeriod'));
	my $user = WebGUI::User->new($self->session, $item->transaction->get('userId'));
	if (defined $user) {
		$user->karma(10,$self->getId, 'Purchased Bazaar Item '.$self->getTitle);
	}
}

#-------------------------------------------------------------------

=head2 onRefund ( item )

Remove the user from the download group.

=cut

sub onRefund {
	my ($self, $item) = @_;
	$self->getDownloadGroup->deleteUsers([$item->transaction->get('userId')]);
	my $user = WebGUI::User->new($self->session, $item->transaction->get('userId'));
	if (defined $user) {
		$user->karma(-20,$self->getId, 'Returned Bazaar Item '.$self->getTitle);
	}
}

#-------------------------------------------------------------------
sub prepareView {
	my $self    = shift;
    my $session = $self->session;
	my $bazaar  = $self->getParent;

	$self->next::method;

	$self->session->style->setLink(
		$self->session->url->extras("yui/build/grids/grids-min.css"),
		{ rel => 'stylesheet', type => "text/css" }
	);

    my $template = WebGUI::Asset::Template->new( $session, $bazaar->getValue('bazaarItemTemplateId') );
    $template->prepare;
    $self->{_viewTemplate} = $template;
}


#-------------------------------------------------------------------
sub processPropertiesFromFormPost {
	my $self = shift;
	my $oldVersion = $self->get('versionNumber');
	$self->next::method(@_);
	my $session = $self->session;
	my $form = $session->form;
	my $user = $session->user;
	my $properties = {};
	if ($self->get('ownerUserId') eq '3') {
		$properties->{ownerUserId} = $user->userId;
	}
	unless ($user->isAdmin) {
		my %vendorInfo = (
			preferredPaymentType	=> $form->get('vendorPaymentMethod','selectBox','PayPal'),
			name					=> $form->get('vendorName','text', $user->username),
			url						=> $form->get('vendorUrl','url'),
			paymentInformation		=> $form->get('vendorPaymentInformation','textarea'),
			userId					=> $user->userId,
		);
		my $vendor = eval { WebGUI::Shop::Vendor->newByUserId($session)};
		if (WebGUI::Error->caught) {
			$vendor = WebGUI::Shop::Vendor->create($session, \%vendorInfo);
		}
		else {
			$vendor->update(\%vendorInfo);
		}
		$properties->{vendorId} = $vendor->getId;
	}
	$self->update($properties);
	$self->requestAutoCommit;
	# this is a new version of the product
	if ($oldVersion ne $self->get('versionNumber')) {
		$user->karma(100, $self->getId, 'Uploading '.$self->get('versionNumber').' of Bazaar Item '.$self->getTitle);
		$self->notifySubscribers(
			$self->getTitle .' has been updated to version '.$self->get('versionNumber').'.',
			$self->getTitle . ' Updated'
			);
	}
}

#-------------------------------------------------------------------
sub purge {
	my $self = shift;
	foreach my $g ($self->getDownloadGroup, $self->getSubscriptionGroup) {
		unless (isIn($g->getId, qw(1 2 3 7 12)) ) {
			$g->delete;	
		}
	}
	foreach my $s ($self->getProductStorage, $self->getScreenStorage) {
		$s->delete;	
	}
	$self->next::method(@_);
}

#-------------------------------------------------------------------
sub subscribe {
	my $self = shift;
	$self->getSubscriptionGroup->addUsers([$self->session->user->userId]);
}

#-------------------------------------------------------------------
sub toggleSubscription {
	my $self = shift;
	if ($self->isSubscribed) {
		$self->unsubscribe;
	}
	else {
		$self->subscribe;
	}
}

#-------------------------------------------------------------------
sub update {
	my $self = shift;
	my $properties = shift;
	if (exists $properties->{url}) {
		$properties->{url} = $self->getParent->getUrl.'/'.$self->getTitle;
	}
	if (exists $properties->{title}) {
		WebGUI::Macro::negate(\$properties->{title});
		$properties->{url} = $self->getParent->getUrl.'/'.$properties->{title};
		$properties->{menuTitle} = $properties->{title};
	}
	if (exists $properties->{releaseNotes}) {
		WebGUI::Macro::negate(\$properties->{releaseNotes});
	}
	if (exists $properties->{description}) {
		WebGUI::Macro::negate(\$properties->{description});
	}
	if (exists $properties->{requirements}) {
		WebGUI::Macro::negate(\$properties->{requirements});
	}
	$self->next::method($properties, @_);
}

#-------------------------------------------------------------------
sub unsubscribe {
	my $self = shift;
	$self->getSubscriptionGroup->deleteUsers([$self->session->user->userId]);
}

#-------------------------------------------------------------------

=head2 view

Displays the product.

=cut

sub view {
    my $self = shift;

    my $template = $self->{ _viewTemplate };
    return $template->process( $self->getViewVars );
}

#-------------------------------------------------------------------

=head2 www_buy

Adds the item to the cart.

=cut

sub www_buy {
    my $self = shift;
    if ($self->canView) {
        $self->{_hasAddedToCart} = 1;
        $self->addToCart;
    }
    return $self->www_view;
}

#-------------------------------------------------------------------

=head2 www_download

Allows the user to make the download.

=cut

sub www_download {
    my $self = shift;
    if ($self->canDownload) {
		$self->update({downloads=>$self->get('downloads') + 1});
		$self->session->http->setRedirect($self->getProductStorage->getUrl($self->session->form->get('filename')));
		return "redirect";
    }
    return $self->www_view;
}

#-------------------------------------------------------------------

=head2 www_edit

Displays edit form.

=cut

sub www_edit {
	my $self = shift;
	return $self->session->privilege->insufficient unless $self->canEdit;
	return $self->session->privilege->locked unless $self->canEditIfLocked;
	return $self->getParent->processStyle($self->getEditForm->print);
}

#-------------------------------------------------------------------
sub www_toggleSubscription {
	my $self = shift;
	return $self->session->privilege->insufficient if ($self->session->user->isVisitor);
	unless ($self->session->user->isVisitor) {
		$self->toggleSubscription;
	}
	return $self->www_view;
}

1;
