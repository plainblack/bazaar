package WebGUI::Asset::Wobject::Bazaar;

#-------------------------------------------------------------------
# WebGUI is Copyright 2001-2008 Plain Black Corporation.
#-------------------------------------------------------------------
# Please read the legal notices (docs/legal.txt) and the license
# (docs/license.txt) that came with this distribution before using
# this software.
#-------------------------------------------------------------------
# http://www.plainblack.com                     info@plainblack.com
#-------------------------------------------------------------------

use strict;
use Tie::IxHash;
use WebGUI::Utility;
use base 'WebGUI::Asset::Wobject';


#-------------------------------------------------------------------
sub canEdit {
        my $self    = shift;
        my $userId  = shift     || $self->session->user->userId;
        return (
		(
			(
				$self->session->form->process("func") eq "add" || 
				(
					$self->session->form->process("assetId") eq "new" && 
					$self->session->form->process("func") eq "editSave" && 
					$self->session->form->process("class") eq "WebGUI::Asset::Sku::BazaarItem"
				)
			) && 
			$self->canUpload( $userId )
		) || # account for new items
		$self->SUPER::canEdit( $userId )
	);
}

#-------------------------------------------------------------------

sub canUpload {
	my $self = shift;
	return $self->session->user->isInGroup($self->get('groupToUpload')) || $self->canEdit;
}

#-------------------------------------------------------------------

=head2 definition ( )

defines wobject properties for New Wobject instances.  You absolutely need 
this method in your new Wobjects.  If you choose to "autoGenerateForms", the
getEditForm method is unnecessary/redundant/useless.  

=cut

sub definition {
	my $class = shift;
	my $session = shift;
	my $definition = shift;
	my %properties;
	tie %properties, 'Tie::IxHash';
	%properties = (
		groupToUpload => {
			fieldType       => "group",
			defaultValue    => 2,
			label			=> "Group To Upload",
			tab				=> "security",
			},
		listLimit => {
			fieldType		=> "integer",
			defaultValue	=> 50,
			label			=> "List Limit",
			tab				=> "display",
			},
	);
	push(@{$definition}, {
		assetName=>'Bazaar',
		icon=>'assets.gif',
		autoGenerateForms=>1,
		tableName=>'bazaar',
		className=>'WebGUI::Asset::Wobject::Bazaar',
		properties=>\%properties
		});
        return $class->SUPER::definition($session, $definition);
}


#-------------------------------------------------------------------
sub formatList {
	my ($self, $assetIds, $title) = @_;
	my $limit = $self->get('listLimit');
	my $out = '<h3>'.$title.'</h3>';
	my $session = $self->session;
	$session->style->setRawHeadTags(q{
	<style type="text/css">
	.thumbpic {
		float: right;
	}
	.thumbpic:hover {
		background-color: transparent;
		z-index: 50;
	}

	.thumbpic span {
		background-color: black;
		padding: 5px;
		border: 1px dashed gray;
		visibility: hidden;
		color: black;
		text-decoration: none;
		display: none;
		position: absolute;
	}

	.thumbpic span img { 
		border-width: 0;
		padding: 2px;
		max-height: 480px;
		max-width: 640px;
	}

	.thumbpic:hover span { 
		visibility: visible;
		display: block;
		right: 100px;
	}		
</style>							   
		});
	foreach my $id (@$assetIds) {
		my $asset = WebGUI::Asset::Sku::BazaarItem->new($session, $id);
		if (defined $asset) {
			$out .= q{<p style="clear: both;"><img src="}.$self->session->url->extras('wobject/Bazaar/rating/'.round($asset->get('averageRating'),0).'.png').q{" style="float: left;" alt="}.$asset->get('averageRating').q{" />};
			
			my $screens = $asset->getScreenStorage;
			my $firstScreen = $screens->getFiles->[0];
			if ($firstScreen ne "") {
				$out .= q{<a class="thumbpic" href="}.$asset->getUrl.q{"><img src="}.$screens->getThumbnailUrl($firstScreen).q{" alt="}.$firstScreen.q{" class="thumbnail" /><span><img src="}.$screens->getUrl($firstScreen).q{" /></span></a> };
			}
			$out .= q{<b><a href="}.$asset->getUrl.q{">}.$asset->getTitle.q{</a></b><br />}.$asset->get('synopsis').q{</p>};
		}
		$limit--;
		last unless $limit;
	}
	$out .= '<div style="float: right;"><a href="'.$self->getUrl.'">Back to the Bazaar</a></div><div style="clear: both;"></div>';
	return $self->processStyle($out);
}

#-------------------------------------------------------------------
sub formatShortList {
	my ($self, $url, $title, $query, $params) = @_;
	my $out = q{<fieldset class="bazaarList"><legend><a href="}.$url.q{">}.$title.q{ &raquo;</a></legend>};
	my $session = $self->session;
	my $revisions = $self->session->db->read($query, $params);
	my $first = 1;
    while (my ($id) = $revisions->array) {
		my $asset = WebGUI::Asset::Sku::BazaarItem->new($session, $id);
		if (defined $asset) {
			if ($first) {
				$out .= q{<div class="firstBazaarItem">};
				my $screens = $asset->getScreenStorage;
				my $firstScreen = $screens->getFiles->[0];
				if ($firstScreen ne "") {
					$out .= q{<a class="thumbpic" href="}.$asset->getUrl.q{"><img src="}.$screens->getThumbnailUrl($firstScreen).q{" alt="}.$firstScreen.q{" class="thumbnail" /><span><img src="}.$screens->getUrl($firstScreen).q{" /></span></a>};
				}
				$out .= q{<a href="}.$asset->getUrl.q{">}.$asset->getTitle.q{</a> - }.$asset->get('synopsis').q{<br />};
				$out .= q{</div><ul>};
				$first = 0;
			}
			else {
				$out .= q{<li>&#187;<a href="}.$asset->getUrl.q{">}.$asset->getTitle.q{</a></li>};
			}
		}
	}
	$out .= q{</ul></fieldset>};
	return $out;
}

#-------------------------------------------------------------------
sub prepareView {
	my $self = shift;
	$self->SUPER::prepareView;
	$self->session->style->setRawHeadTags(q{
	<style type="text/css">
	.bazaarList {
		width: 220px;
		display: -moz-inline-box;  /* Moz */
		display: inline-block;  /* Op, Saf, IE \*/
		vertical-align: top;  /* IE Mac non capisce e a volte crea extra v space */
		font-size: 12px;
		margin-right: 20px;
		margin-bottom: 20px;
		border: 1px solid #bbbbbb;
		padding: 5px;
	}
	.bazaarList ul {
		margin: 5px;
		padding: 5px;
		list-style-type: none;
		text-indent: -5px;
	}
	.bazaarList ul li {
		margin-bottom: 5px;
	}
	.bazaarList legend, .bazaarList legend a {
		text-decoration: none;
		color: #555555;
		font-size: 15px;
		font-weight: bold;
	}
	.firstBazaarItem {
		margin-bottom: 10px;
		padding: 10px;
		color: black;
		background-color: #eeffee;
	}
	.thumbpic {
		z-index: 0;
		margin-left: 5px;
		margin-bottom: 5px;
		float: right;
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
		left: 20px;
		visibility: visible;
		z-index: 5000;
	}		
</style>							   
		});}

#-------------------------------------------------------------------

=head2 view ( )

method called by the www_view method.  Returns a processed template
to be displayed within the page style.  

=cut

sub view {
	my $self = shift;
	my $session = $self->session;	
	my $out = "";
	if ($session->var->isAdminOn) {
		$out .= q{<p>}.$self->getToolbar.q{</p>};
	}
	if ($self->get("displayTitle")) {
		$out .= q{<h3>}.$self->getTitle.q{</h3>};
	}
	if ($self->canUpload) {
		$out .= q{<p><a href="}.$self->getUrl('func=add;class=WebGUI::Asset::Sku::BazaarItem').q{">Upload to the Bazaar</a></p>};
	}
	
	$out .= $self->get('description');
	
	# featured
	$out .= $self->formatShortList(
		$self->getUrl('func=byFeatured'),
		'Featured',
		"select distinct assetId from bazaarItem where price > 0 and revisionDate > unix_timestamp() - 60*60*24*365*2 order by revisionDate desc limit 10"
	);

	# newest
	$out .= $self->formatShortList(
		$self->getUrl('func=byCreation'),
		'Newest',
		"select assetId from asset where parentId=? and className like 'WebGUI::Asset::Sku::BazaarItem%' order by creationDate desc limit 10",
		[$self->getId]
	);

	# most downloaded
	$out .= $self->formatShortList(
		$self->getUrl('func=byDownloads'),
		'Most Downloaded',
		"select distinct assetId from bazaarItem where revisionDate > unix_timestamp() - 60*60*24*365*2 order by downloads desc limit 10"
	);

	# most highly rated
	$out .= $self->formatShortList(
		$self->getUrl('func=byRating'),
		'Highly Rated',
		"select distinct assetId from bazaarItem where revisionDate > unix_timestamp() - 60*60*24*365*2 order by averageRating desc limit 10"
	);
	# most viewed
	$out .= $self->formatShortList(
		$self->getUrl('func=byViews'),
		'Most Viewed',
		"select distinct assetId from bazaarItem where revisionDate > unix_timestamp() - 60*60*24*365*2 order by views desc limit 10"
	);

	# most recently updated
	$out .= $self->formatShortList(
		$self->getUrl('func=byRecent'),
		'Recently Updated',
		"select distinct assetId from bazaarItem order by revisionDate desc limit 10"
	);

	# keywords
	$out .= q{<fieldset class="bazaarList"><legend>Keywords</legend>}.WebGUI::Keyword->new($self->session)->generateCloud({
        startAsset=>$self,
        displayFunc=>"byKeyword",
        }).q{</fieldset>};

	# output
	return $out;
}


#-------------------------------------------------------------------
sub www_byCreation {
	my $self = shift;
	my $ids = $self->session->db->buildArrayRef("select assetId from asset where parentId=?
		and className like 'WebGUI::Asset::Sku::BazaarItem%'
		order by creationDate desc", [$self->getId]);
	return $self->formatList($ids,'New in the Bazaar');
}

#-------------------------------------------------------------------
sub www_byDownloads {
	my $self = shift;
	my $ids = $self->session->db->buildArrayRef("select distinct assetId from bazaarItem where revisionDate > unix_timestamp() - 60*60*24*365*2 order by downloads desc");
	return $self->formatList($ids,'Most Downloaded');
}

#-------------------------------------------------------------------
sub www_byFeatured {
	my $self = shift;
	my $ids = $self->session->db->buildArrayRef("select distinct assetId from bazaarItem where price > 0 and revisionDate > unix_timestamp() - 60*60*24*365*2 order by revisionDate desc");
	return $self->formatList($ids,'Featured');
}

#-------------------------------------------------------------------
sub www_byKeyword {
	my $self = shift;
	my $word = $self->session->form->get('keyword');
	my $ids = WebGUI::Keyword->new($self->session)->getMatchingAssets({startAsset=>$self, keywords=>[$word]});
	return $self->formatList($ids, q{Keyword: }.$word);
}

#-------------------------------------------------------------------
sub www_byRating {
	my $self = shift;
	my $ids = $self->session->db->buildArrayRef("select distinct assetId from bazaarItem where revisionDate > unix_timestamp() - 60*60*24*365*2 order by averageRating desc");
	return $self->formatList($ids, 'Best Rated');
}

#-------------------------------------------------------------------
sub www_byRecent {
	my $self = shift;
	my $ids = $self->session->db->buildArrayRef("select distinct assetId from bazaarItem order by revisionDate desc");
	return $self->formatList($ids, 'Recently Updated');
}

#-------------------------------------------------------------------
sub www_byViews {
	my $self = shift;
	my $ids = $self->session->db->buildArrayRef("select distinct assetId from bazaarItem where revisionDate > unix_timestamp() - 60*60*24*365*2 order by views desc");
	return $self->formatList($ids,'Most Viewed');
}

#-------------------------------------------------------------------
sub www_byVendor {
	my $self = shift;
	my $vendorId = $self->session->form->get('vendorId');
	my $vendor = WebGUI::Shop::Vendor->new($self->session, $vendorId);
	my $ids = $self->session->db->buildArrayRef("select distinct assetId from bazaarItem left join sku using (assetId, revisionDate) where vendorId=? group by assetId",[$vendorId]);
	return $self->formatList($ids, $vendor->get('name'));
}

#-------------------------------------------------------------------

=head2 www_editSave ( )

We're extending www_editSave() stop the creation of non-bazaar items as children.

=cut

sub www_editSave {
	my $self    = shift;
    my $session = $self->session;
    my $className = $session->form->param("class");
	# if it's not what we expect, don't add it.
    if ($className ne "WebGUI::Asset::Sku::BazaarItem" && $className ne "") {
		return $self->getParent->www_view;
    }    
    return $self->SUPER::www_editSave(@_);
}



1;
