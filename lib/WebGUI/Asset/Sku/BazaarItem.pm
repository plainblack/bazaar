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

use Moose;
use WebGUI::Definition::Asset;
extends 'WebGUI::Asset::Sku';
with 'WebGUI::Role::Asset::Comments';

use JSON;
use WebGUI::Asset::Template;
use WebGUI::Exception;
use WebGUI::Form;
use WebGUI::FormBuilder;
use WebGUI::Group;
use WebGUI::Keyword;
use WebGUI::Macro;
use WebGUI::Shop::Vendor;
use WebGUI::Storage;
use WebGUI::Storage::Image;
use WebGUI::User;

sub _negate_macros {
    my $orig = shift;
    my $self = shift;
    return $self->$orig if !@_;
    my $value = shift;
    WebGUI::Macro::negate(\$value);
    return $self->$orig($value);
}

define assetName           => 'Bazaar Item';
define icon                => 'assets.gif';
define tableName           => 'bazaarItem';

property product => (
    tab             => "properties",
    fieldType       => "file",
    default         => undef,
    label           => 'Product',
    maxAttachments  => 5,
    hoverHelp       => 'The file that can be downloaded.',
);
property screenshots => (
    tab             => "properties",
    fieldType       => "image",
    default         => undef,
    label           => 'Screen Shots',
    maxAttachments  => 5,
    hoverHelp       => 'Images captured of the product.',
);
property requirements => (
    tab             => "properties",
    fieldType       => "HTMLArea",
    default         => undef,
    label           => 'Requirements',
    hoverHelp       => 'The prerequisites to use this product.',
);
around requirements => \&_negate_macros;

property versionNumber => (
    tab             => "properties",
    fieldType       => "text",
    default         => 1,
    label           => 'Version Number',
    hoverHelp       => 'What release number is it?',
);
property releaseDate => (
    tab             => "properties",
    fieldType       => "date",
    lazy            => 1,
    default         => sub { WebGUI::DateTime->new(shift->session, time())->toDatabaseDate },
    label           => 'Release Date',
    hoverHelp       => 'The date this version of the product was released publicly.',
);
property releaseNotes => (
    tab             => "properties",
    fieldType       => "HTMLArea",
    default         => undef,
    label           => 'Release Notes',
    hoverHelp       => 'Information about this release or the release history.',
);
around releaseNotes => \&_negate_macros;

property supportUrl => (
    tab             => "properties",
    fieldType       => "url",
    default         => undef,
    label           => 'Support URL',
    hoverHelp       => 'A URL where a user can find help for this product.',
);
property moreInfoUrl => (
    tab             => "properties",
    fieldType       => "url",
    default         => undef,
    label           => 'More Info URL',
    hoverHelp       => 'A URL where a user can find out more details about this product.',
);
property demoUrl => (
    tab             => "properties",
    fieldType       => "url",
    default         => undef,
    label           => 'Demo URL',
    hoverHelp       => 'A URL where a user can see this product in action.',
);
property price => (
    tab             => "shop",
    fieldType       => "float",
    default         => 0.00,
    label           => 'Price',
    hoverHelp       => 'The amount to be paid to download this item.',
);
property downloadPeriod => (
    tab             => "shop",
    fieldType       => "interval",
    default         => 60*60*24*365,
    label           => 'Download Period',
    hoverHelp       => 'The amount of time the user will have to download the item and updates.',
);
property groupToDownload => (
    noFormPost      => 1,
    fieldType       => "hidden",
    default         => 7,
);
property groupToSubscribe => (
    noFormPost      => 1,
    fieldType       => "hidden",
    default         => undef,
);
property views => (
    noFormPost      => 1,
    fieldType       => "hidden",
    default         => 0,
);
property downloads => (
    noFormPost      => 1,
    fieldType       => "hidden",
    default         => 0,
);
around description  => \&_negate_macros;

around url => sub {
    my $orig = shift;
    my $self = shift;
    return $self->$orig() if !@_;
    my $url = join '/', $self->getParent->getUrl, $self->title;
    return $self->$orig($url);
};

around title => sub {
    my $orig = shift;
    my $self = shift;
    return $self->$orig() if !@_;
    my $title = shift;
    WebGUI::Macro::negate(\$title);
    $self->$orig($title);
    $self->url($title);  ##Argument is thrown away, but it needs to be called
    $self->menuTitle($title);
};

=head1 NAME

Package WebGUI::Asset::Sku::BazaarItem

=head1 DESCRIPTION



=head1 SYNOPSIS

use WebGUI::Asset::Sku::Bazaar;

=head1 METHODS

These methods are available from this class:

=cut

#-------------------------------------------------------------------
around canAdd => sub {
    my $orig    = shift;
	my $class = shift;
	my $session = shift;
	return $class->$orig($session, undef, '7');
};

#-------------------------------------------------------------------
sub canDownload {
	my $self = shift;
	return $self->getPrice < 0.01
        || $self->session->user->userId eq $self->ownerUserId
		|| $self->session->user->isInGroup($self->getDownloadGroup->getId)
		|| $self->canEdit;
}

#-------------------------------------------------------------------
override canEdit => sub {
	my $self = shift;
	my $form = $self->session->form;
	return super()  # account for normal editing
		|| $self->getParent->canEdit; # account for admins
};

#-------------------------------------------------------------------

=head2 canView ( )

Returns a boolean indicating whether the user can view the current item.

=cut

sub canView {
	my $self = shift;
	if (($self->status eq "approved" || $self->status eq "archived") && $self->getParent->canView) {
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
	elsif ($self->groupToDownload eq '7' && $self->getPrice > 0) {
		my $g = WebGUI::Group->new($self->session,'new');
		$g->name('Download Group for '.$self->getTitle.' ('.$self->getId.')');
		$g->description('This group can download the files attached to bazaar item '.$self->getTitle.' ('.$self->getId.')');
		$self->update({groupToDownload=>$g->getId});
		$self->{_groupToDownload} = $g;
	}
	else {
		$self->{_groupToDownload} = WebGUI::Group->new($self->session, $self->groupToDownload);
	}
	return $self->{_groupToDownload};
}


#-------------------------------------------------------------------
sub getEditForm {
	my $self = shift;
	my $session = $self->session;
	my $form = $session->form;
	my $bazaar = $self->getParent;
	my $url = ($self->getId eq "new") ? $bazaar->getUrl : $self->getUrl;
	my $f = WebGUI::FormBuilder->new($session, action => $url);
	if ($self->getId eq "new") {
		$f->addField(
            'hidden',
			name	=> "assetId",
			value	=> "new"
		);
		$f->addField(
            'hidden',
			name	=> "className",
			value	=> $form->process("className","className")
		);
	}
	
	# product info
    my $set = $f->addFieldset( legend => 'Product Information', name => 'product' );
	$set->addField(
	    'text',
		label	=> 'Title',
		name	=> 'title',
		value	=> $self->title,
	);
	$set->addField(
	    'textarea',
		label	=> 'Short Description',
		name	=> 'synopsis',
		value	=> $self->synopsis,
	);
	$set->addField(
	    'HTMLArea',
		label		=> 'Full Description',
		richEditId	=> 'PBrichedit000000000002',
		name		=> 'description',
		value		=> $self->description,
	);
	$set->addField(
	    'url',
		label	=> 'More Information URL',
		name	=> 'moreInfoUrl',
		value	=> $self->moreInfoUrl,
	);
	$set->addField(
	    'url',
		label	=> 'Support URL',
		name	=> 'supportUrl',
		value	=> $self->supportUrl,
	);
	$set->addField(
	    'url',
		label	=> 'Demo URL',
		name	=> 'demoUrl',
		value	=> $self->demoUrl,
	);
	$set->addField(
	    'image',
		name			=> "screenshots",
		label			=> "Screen Shots",
		maxAttachments	=> 5,
		value			=> $self->screenshots,
	);
	$set->addField(
	    'file',
		name			=> "product",
		label			=> "Product File(s)",
		maxAttachments	=> 5,
		value			=> $self->product,
	);
	
	# release info
    $set = $f->addFieldset( legend => 'This Release', name => 'this' );
	$set->addField(
	    'text',
		label			=> 'Version Number',
		name			=> 'versionNumber',
		value			=> $self->versionNumber,
		defaultValue	=> 1,
	);
	$set->addField(
	    'date',
		label			=> 'Release Date',
		name			=> 'releaseDate',
		defaultValue	=> WebGUI::DateTime->new($session, time())->toDatabaseDate,
	);
	$set->addField(
	    'HTMLArea',
		label		=> 'Release Notes',
		richEditId	=> 'PBrichedit000000000002',
		name		=> 'releaseNotes',
		value		=> $self->releaseNotes,
	);
	$set->addField(
	    'HTMLArea',
		label		=> 'Requirements',
		richEditId	=> 'PBrichedit000000000002',
		name		=> 'requirements',
		value		=> $self->requirements,
	);

	# vendor info
    $set = $f->addFieldset( legend => 'Vendor Information', name => 'vendor' );
	if ($session->user->isAdmin) {
		$set->addField(
		    'vendor',
			label	=> 'Vendor',
			name	=> 'vendorId',
			value	=> $self->vendorId,
		);
	}
	elsif( $self->getParent->autoCreateVendors ) {
		my $vendor = eval { WebGUI::Shop::Vendor->newByUserId($session)};
		my $vendorInfo = {};
		unless (WebGUI::Error->caught) {
			$vendorInfo = $vendor->get;
		}
		$set->addField(
		    'text',
			label	=> 'Name',
			name	=> 'vendorName',
			value	=> $vendorInfo->{name},
		);
		$set->addField(
		    'text',
			label	=> 'URL',
			name	=> 'vendorUrl',
			value	=> $vendorInfo->{url},
		);
		$set->addField(
		    'selectBox',
			label			=> 'Preferred Payment Method',
			name			=> 'vendorPaymentMethod',
			options			=> {PayPal => 'PayPal'},
			value			=> $vendorInfo->{preferredPaymentType},
		);
		$set->addField(
		    'textarea',
			label			=> 'Payment Address',
			name			=> 'vendorPaymentInformation',
			value			=> $vendorInfo->{paymentInformation},
		);
	}

	# bazaar info
    $set = $f->addFieldset( legend => 'Bazaar Settings', name => 'settings' );
	$set->addField(
	    'float',
		label		=> 'Price',
        name		=> 'price',
        value   	=> $self->price,
		defaultValue	=> 0.00,
 	);
	$set->addField(
	    'interval',
		label		=> 'Download Period',
        name		=> 'downloadPeriod',
		hoverHelp	=> 'The amount of time the user will have to download the product and updates.',
        value   	=> $self->downloadPeriod,
		defaultValue	=> 60*60*24*365,
 	);
	$set->addField(
	    'text',
		label	=> 'Keywords',
		subtext	=> 'eg: asset utility',
        name	=> 'keywords',
        value   => WebGUI::Keyword->new($session)->getKeywordsForAsset({asset=>$self}),
 	);
	return $f;
}

#-------------------------------------------------------------------

=head2 getEditTemplate

Override the base method to use the style template from the parent bazaar.

=cut

around getEditTemplate => sub {
    my $orig = shift;
    my $self = shift;
    my $template = $self->$orig(@_);
    $template->style($self->getParent->getStyleTemplateId);
    return $template;
};

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
    return $self->price || 0.00;
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
		if ($self->product eq "") {
			$self->{_productStorage} = WebGUI::Storage->create($self->session);
			$self->update({product=>$self->{_productStorage}->getId});
		}
		else {
			$self->{_productStorage} = WebGUI::Storage->get($self->session,$self->product);
		}
		$self->{_productStorage}->setPrivileges(
			$self->ownerUserId,
			$self->getDownloadGroup->getId,
			$self->getParent->groupIdEdit
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
            screen_filename     => $file,
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
		if ($self->screenshots eq "") {
			$self->{_screenStorage} = WebGUI::Storage::Image->create($self->session);
			$self->update({screenshots=>$self->{_screenStorage}->getId});
		}
		else {
			$self->{_screenStorage} = WebGUI::Storage::Image->get($self->session,$self->screenshots);
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
	elsif ($self->groupToSubscribe eq '') {
		my $g = WebGUI::Group->new($self->session,'new');
		$g->name('Subscribtion Group for '.$self->getTitle.' ('.$self->getId.')');
		$g->description('This group can subscribe to the bazaar item '.$self->getTitle.' ('.$self->getId.')');
		$self->update({groupToSubscribe=>$g->getId});
		$g->deleteGroups([3]);
		$self->{_groupToSubscribe} = $g;
	}
	else {
		$self->{_groupToSubscribe} = WebGUI::Group->new($self->session, $self->groupToSubscribe);
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
    my $vendor      = WebGUI::Shop::Vendor->new( $session, $self->vendorId );
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
            $datetime->setToEpoch( $self->releaseDate ), 
            '%z' 
        );
    $vars->{ productFiles_loop      } = $self->getProductLoopVars;
    $vars->{ screenFiles_loop       } = $self->getScreenLoopVars;
    $vars->{ price                  } = sprintf '%.2f', $self->getPrice;
    $vars->{ hasPrice               } = $self->getPrice > 0;
    $vars->{ isInCart               } = $self->{ _hasAddedToCart };
    $vars->{ addToCart_form         } = $self->getAddToCartForm;

    $vars->{ rating                 } = $self->getAverageCommentRatingIcon;
    $vars->{ lastUpdated            } = $datetime->epochToHuman( $self->revisionDate, '%z' );

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
override indexContent => sub {
	my $self = shift;
	my $indexer = super();
	$indexer->addKeywords($self->releaseNotes);
	$indexer->addKeywords($self->requirements);
};

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
	my $from = shift || WebGUI::User->new($self->session, $self->ownerUserId)->profileField('email');
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
	$self->getDownloadGroup->addUsers([$item->transaction->get('userId')], $self->downloadPeriod);
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
override prepareView => sub {
	my $self    = shift;
    my $session = $self->session;
	my $bazaar  = $self->getParent;

	super();

	$self->session->style->setCss(
		$self->session->url->extras("yui/build/grids/grids-min.css"),
	);

    my $template = WebGUI::Asset::Template->newById( $session, $bazaar->bazaarItemTemplateId );
    $template->prepare;
    $self->{_viewTemplate} = $template;
};


#-------------------------------------------------------------------
override processEditForm => sub {
    my $self        = shift;
    my $session     = $self->session;
    my $form        = $session->form;
    my $user        = $session->user;
    my $properties = {};

    ##Have to save this before we call the parent method.
    my $oldVersion  = $self->versionNumber;

    super();

	if ( $self->ownerUserId eq '3' ) {
		$properties->{ownerUserId} = $user->userId;
	}

	if ( !$user->isAdmin && $self->getParent->autoCreateVendors ) {
		my %vendorInfo = (
			preferredPaymentType	=> $form->get( 'vendorPaymentMethod', 'selectBox', 'PayPal' ),
			name					=> $form->get( 'vendorName', 'text', $user->username ),
			url						=> $form->get( 'vendorUrl', 'url' ),
			paymentInformation		=> $form->get( 'vendorPaymentInformation','textarea' ),
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
	if ($oldVersion ne $self->versionNumber) {
		$user->karma(100, $self->getId, 'Uploading '.$self->versionNumber.' of Bazaar Item '.$self->getTitle);
		$self->notifySubscribers(
			$self->getTitle .' has been updated to version '.$self->versionNumber.'.',
			$self->getTitle . ' Updated'
			);
	}
};

#-------------------------------------------------------------------
override purge => sub {
	my $self = shift;
	foreach my $g ($self->getDownloadGroup, $self->getSubscriptionGroup) {
		unless (grep { $_ eq $g->getId } qw(1 2 3 7 12)) {
			$g->delete;	
		}
	}
	foreach my $s ($self->getProductStorage, $self->getScreenStorage) {
		$s->delete;	
	}
	return super();
};

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
		$self->update({downloads=>$self->downloads + 1});
		$self->session->http->setRedirect($self->getProductStorage->getUrl($self->session->form->get('filename')));
		return "redirect";
    }
    return $self->www_view;
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
