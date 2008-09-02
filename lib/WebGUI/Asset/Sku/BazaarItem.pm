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
use base 'WebGUI::Asset::Sku';
use JSON;
use WebGUI::Asset::Template;
use WebGUI::Exception;
use WebGUI::Form;
use WebGUI::Group;
use WebGUI::HTML;
use WebGUI::Keyword;
use WebGUI::Macro;
use WebGUI::Shop::Vendor;
use WebGUI::Storage;
use WebGUI::Storage::Image;
use WebGUI::User;
use WebGUI::Utility;


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
	return $class->SUPER::canAdd($session, undef, '7');
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
	return $self->SUPER::canEdit  # account for normal editing
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
		comments => {
			noFormPost		=> 1,
			fieldType       => "hidden",
			defaultValue    => [],
			},
		averageRating => {
			noFormPost		=> 1,
			fieldType       => "hidden",
			defaultValue    => 0,
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
	return $class->SUPER::definition($session, $definition);
}


#-------------------------------------------------------------------
sub get {
	my $self = shift;
	my $param = shift;
	if ($param eq 'comments') {
		return JSON->new->decode($self->SUPER::get('comments')||'[]');
	}
	return $self->SUPER::get($param, @_);
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
	if ($session->user->isInGroup(3)) {
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
sub indexContent {
	my $self = shift;
	my $indexer = $self->SUPER::indexContent;
	$indexer->addKeywords($self->get("releaseNotes"));
	$indexer->addKeywords($self->get("requirements"));
}

#-------------------------------------------------------------------
sub isSubscribed {
	my $self = shift;
	return $self->session->user->isInGroup($self->getSubscriptionGroup->getId);
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
sub notifySubscribersAboutComment {
	my $self = shift;
	$self->notifySubscribers(
		$self->getTitle .' has been updated to version '.$self->get('versionNumber').'.',
		$self->getTitle . ' Updated',
		);
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
	my $self = shift;
	$self->SUPER::prepareView;
	$self->session->style->setLink(
		$self->session->url->extras("yui/build/grids/grids-min.css"),
		{rel=>'stylesheet', type=>"text/css"}
		);
	$self->session->style->setRawHeadTags(q{
	<style type="text/css">
	fieldset {
		border: 1px solid #bbbbbb;
		padding: 5px;
		margin: 0;
		margin-bottom: 10px;
	}
	legend {
		color: #555555;
		font-size: 10px;
		margin-left: 10px;
	}
	.thumbpic {
		z-index: 0;
	}

	.thumbpic:hover {
		background-color: transparent;
		z-index: 50;
	}

	.thumbpic span {
		position: absolute;
		background-color: black;
		padding: 5px;
		left: -1000px;
		border: 1px dashed gray;
		visibility: hidden;
		color: black;
		text-decoration: none;
	}

	.thumbpic span img { 
		border-width: 0;
		padding: 2px;
		max-height: 480px;
		max-width: 640px;
	}

	.thumbpic:hover span { 
		left: -650px;
		top: 0;
		visibility: visible;
		z-index: 5000;
	}		
</style>							   
		});
}


#-------------------------------------------------------------------
sub processPropertiesFromFormPost {
	my $self = shift;
	my $oldVersion = $self->get('versionNumber');
	$self->SUPER::processPropertiesFromFormPost(@_);
	my $session = $self->session;
	my $form = $session->form;
	my $user = $session->user;
	my $properties = {};
	if ($self->get('ownerUserId') eq '3') {
		$properties->{ownerUserId} = $user->userId;
	}
	unless ($user->isInGroup(3)) {
		my %vendorInfo = (
			preferredPaymentType	=> $form->get('vendorPaymentMethod','selectBox','PayPal'),
			name					=> $form->get('vendorName','text') || $user->username,
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
	$self->SUPER::purge(@_);
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
	if (exists $properties->{comments}) {
            my $comments = $properties->{comments};
            if (ref $comments ne 'ARRAY') {
                $comments = eval{JSON->new->decode($comments)};
                if (WebGUI::Error->caught) {
                  $comments = [];
		}
            }
            $properties->{comments} = JSON->new->encode($comments);
        }
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
	$self->SUPER::update($properties, @_);
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
    my ($self) = @_;
    my $session = $self->session;
	my $bazaar = $self->getParent;
	my $datetime = $session->datetime;
	my $out = '';
	if ($session->var->isAdminOn) {
		$out .= q{<p>}.$self->getToolbar.q{</p>};
	}
	$out .= q{<div id="doc3" class="yui-t5"><div id="hd"><h3>}.$self->getTitle.q{</h3></div><div id="bd"><div id="yui-main"><div class="yui-b"><div class="yui-g">};
	### start main
	
	# description
	$out .= q{<p>}.$self->get('description').q{</p>};
	
	# requirements
	if ($self->get('requirements')) {
		$out .= q{<fieldset><legend>System Requirements</legend>}.$self->get('requirements').q{</fieldset>};
	}
	
	# release notes
	if ($self->get('releaseNotes')) {
		$out .= q{<fieldset><legend>Release Notes for Version }.$self->get('versionNumber').q{ (}.$datetime->epochToHuman($datetime->setToEpoch($self->get('releaseDate')),'%z').q{)</legend>}.$self->get('releaseNotes').q{</fieldset>};
	}
	
	# comments
	$out .= q{<fieldset><legend>Comments</legend>};
	my $comments = $self->get('comments');
	foreach my $comment (@$comments) {
		$out .= q{<p><img src="}.$session->url->extras('wobject/Bazaar/rating/'.$comment->{rating}.'.png').q{" alt="}.$comment->{rating}.q{" style="vertical-align: bottom;" />};
		$out .= q{<b>}.$comment->{alias}.q{ said:</b> "}.WebGUI::HTML::format($comment->{comment},'text').q{"</p>};
	}
	unless ($self->session->user->userId eq '1') {
		$out .= WebGUI::Form::formHeader($session, {action=>$self->getUrl});
		$out .= WebGUI::Form::hidden($session, {name=>"func",value=>"leaveComment"});
		$out .= WebGUI::Form::textarea($session, {name=>"comment"});
		$out .= WebGUI::Form::commentRating($session, {name=>"rating"});
		$out .= WebGUI::Form::submit($session);
		$out .= WebGUI::Form::formFooter($session);
	}
	$out .= q{</fieldset>};

	### end main
	$out .= q{</div></div></div><div class="yui-b">};
	### start sidebar
	
	# buy / download
	$out .= q{<fieldset>};
	if ($self->canDownload) {
		$out .= q{<legend>Download</legend>};
		my $storage = $self->getProductStorage;
		foreach my $file (@{$storage->getFiles}) {
			$out .= q{<img src="}.$storage->getFileIconUrl($file).q{" alt="}.$file.q{" style="vertical-align: middle;" /> <a href="}.$self->getUrl('func=download;filename='.$file).q{">}.$file.q{</a><br />};
		}
	}
	elsif ($self->getPrice > 0) {
		$out .= q{<legend>Purchase</legend>};
		if ($self->{_hasAddedToCart}) {
			$out .= $self->getTitle.q{ has been added to your cart. ^ViewCart;};
		}
		$out .= q{<p><b>}.sprintf("%.2f", $self->getPrice).q{</b><br />};
		$out .= WebGUI::Form::formHeader($session, {action=>$self->getUrl});
		$out .= WebGUI::Form::hidden($session, {name=>'func', value=>'buy'});
		$out .= WebGUI::Form::submit($session, {value=>'Add to Cart'});
		$out .= WebGUI::Form::formFooter($session);
		$out .= q{</p>};
	}
	else {
		$out .= q{<b>You don't have permission to download this.</b>};
	}
	$out .= q{</fieldset>};
		
	# links
	my $vendorInfo = {};
	my $vendor = WebGUI::Shop::Vendor->new($session, $self->get('vendorId'));
	unless (WebGUI::Error->caught) {
		unless ($vendor->get('name') eq 'Default Vendor') {
			$vendorInfo = $vendor->get;
		}
	}
	$out .= q{<fieldset><legend>Links</legend>};
	if ($vendorInfo->{url} ne '' && $vendorInfo->{name} ne '') {
		$out .= q{<a href="}.$vendorInfo->{url}.q{">}.$vendorInfo->{name}.q{</a><br />};
	}
	if ($self->get('demoUrl') ne '') {
		$out .= q{<a href="}.$self->get('demoUrl').q{">Demo</a><br />};
	}
	if ($self->get('moreInfoUrl') ne '') {
		$out .= q{<a href="}.$self->get('moreInfoUrl').q{">More Information</a><br />};
	}
	if ($self->get('supportUrl') ne '') {
		$out .= q{<a href="}.$self->get('supportUrl').q{">Support</a><br />};
	}
	else {
		$out .= '<b>No Support Offered</b><br />';
	}
	$out .= q{</fieldset>};

	# screen shots
	my $screens = $self->getScreenStorage;
	my $files = $screens->getFiles;
	if (scalar(@$files)) {
		$out .= q{<fieldset><legend>Screenshots</legend>};
		foreach my $image (@{$screens->getFiles}) {
			$out .= q{<a class="thumbpic" href="}.$screens->getUrl($image).q{"><img src="}.$screens->getThumbnailUrl($image).q{" alt="}.$image.q{" class="thumbnail" /><span><img src="}.$screens->getUrl($image).q{" /></span></a> };
		}
		$out .= q{</fieldset>};
	}
	
	# stats
	$out .= q{<fieldset><legend>Statistics</legend>
		<b>Downloads:</b> }.$self->get('downloads').q{<br />
		<b>Views:</b> }.$self->get('views').q{<br />
		<b>Rating:</b> <img src="}.$session->url->extras('wobject/Bazaar/rating/'.round($self->get('averageRating'),0).'.png').q{" style="vertical-align: middle;" alt="}.$self->get('averageRating').q{" /><br />
		<b>Updated:</b> }.$datetime->epochToHuman($self->get('revisionDate'),'%z').q{<br />
		</fieldset>
	};
	
	# subscription
	unless ($self->session->user->userId eq '1') {
		$out .= q{<fieldset><legend>Notifications</legend><a href="}.$self->getUrl('func=toggleSubscription').q{">};
		if ($self->isSubscribed) {
			$out .= q{Unsubscribe};
		}
		else {
			$out .= q{Subscribe};
		}
		$out .= q{</a></fieldset>};
	}
	
	# keywords
	$out .= q{<fieldset><legend>Keywords</legend> };
	my $keywords = WebGUI::Keyword->new($self->session)->getKeywordsForAsset({
        asset		=> $self,
        asArrayRef	=> 1,
        });
    foreach my $word (@{$keywords}) {
		$out .= q{<a href="}.$bazaar->getUrl("func=byKeyword;keyword=".$word).q{">}.$word.q{</a> };
    }
	$out .= q{</fieldset>};

	# management
	if ($self->canEdit ) {
		$out .= q{<fieldset><legend>Management</legend><a href="}.$self->getUrl("func=delete").q{">Delete</a> / <a href="}.$self->getUrl("func=edit").q{">Edit</a></fieldset>};
	}
	
	# navigation
	$out .= q{<fieldset><legend>Navigation</legend>};
	if ($vendorInfo->{name} ne '') {
		$out .= q{<a href="}.$bazaar->getUrl('func=byVendor;vendorId='.$vendorInfo->{vendorId}).q{">More from }.$vendorInfo->{name}.q{</a><br />};
	}
	$out .= q{<a href="}.$self->getParent->getUrl.q{">Back to the Bazaar</a><br /></fieldset>};

	### end sidebar
	$out .= q{</div></div><div id="ft"></div></div>};
	
	$self->update({views=>$self->get('views') + 1});
	return $out;
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
sub www_leaveComment {
	my $self = shift;
	my $comment = $self->session->form->get('comment','textarea');
	WebGUI::Macro::negate(\$comment);
	my $user = $self->session->user;
	my $rating = $self->session->form->get('rating','commentRating');
	if (
		$user->userId ne '1'
		&& $rating > 0
		&& $comment ne ''
		) {

		my $comments = $self->get('comments');
		push @$comments, {
			alias		=> $user->profileField('alias'),
			userId		=> $user->userId,
			comment		=> $comment,
			rating		=> $rating,
			date		=> time(),
			ip			=> $self->session->var->get('lastIP'),
			};
		my $sum = 0;
		my $count = 0;
		foreach my $comment (@$comments) {
			$count++;
			$sum += $comment->{rating};
		}
		$self->update({comments=>$comments, averageRating=>$sum/$count});
		$user->karma(3, $self->getId, 'Left comment for Bazaar Item '.$self->getTitle);
	}
	$self->notifySubscribers(
		$self->session->user->profileField('alias') .' said:<br /> '.WebGUI::HTML::format($comment,'text'),
		$self->getTitle . ' Comment',
		$user->profileField('email')
		);
	$self->www_view;
}

#-------------------------------------------------------------------
sub www_toggleSubscription {
	my $self = shift;
	return $self->session->privilege->insufficient if ($self->session->user->userId eq '1');
	unless ($self->session->user->userId eq '1') {
		$self->toggleSubscription;
	}
	return $self->www_view;
}

1;
