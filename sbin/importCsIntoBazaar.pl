#-------------------------------------------------------------------
# WebGUI is Copyright 2001-2008 Plain Black Corporation.
#-------------------------------------------------------------------
# Please read the legal notices (docs/legal.txt) and the license
# (docs/license.txt) that came with this distribution before using
# this software.
#-------------------------------------------------------------------
# http://www.plainblack.com                     info@plainblack.com
#-------------------------------------------------------------------

our ($webguiRoot);

BEGIN {
    $webguiRoot = "..";
    unshift (@INC, $webguiRoot."/lib");
}

use strict;
use Pod::Usage;
use Getopt::Long;
use WebGUI::Session;
use WebGUI::Asset::Wobject::Collaboration;
use WebGUI::Asset::Wobject::Bazaar;
use WebGUI::HTML;
use WebGUI::DateTime;
use WebGUI::Group;

my $csId;
my $bazaarId;



print "Starting....\n";

my $session = start();

my $cs = WebGUI::Asset::Wobject::Collaboration->new($session, $csId);
die "bad cs" unless $cs->isa('WebGUI::Asset::Wobject::Collaboration');
my $bazaar = WebGUI::Asset::Wobject::Bazaar->new($session, $bazaarId);
die "bad bazaar" unless $bazaar->isa('WebGUI::Asset::Wobject::Bazaar');

print "Finding threads\n";
foreach my $thread (@{$cs->getLineage(['children'],{returnObjects=>1, includeOnlyClasses=>['WebGUI::Asset::Post::Thread']})}) {
    if (defined $thread) {
        print "Working with thread ".$thread->getId."\n";

        # figure out key words
        print "\tFiguring out keywords\n";
        my @keywords = ($cs->get('title'));
        my $title = $thread->get('title');
        if ($title =~ m/Theme/i || $title =~ m/Style/i) {
            push @keywords, 'style', 'template';
        }
        if ($title =~ m/template/i || $title =~ m/skin/i) {
            push @keywords, 'template';
        }
        if ($title =~ m/workflow/i || $title =~ m/activity/i) {
            push @keywords, 'workflow';
        }
        if ($title =~ m/tool/i || $title =~ m/script/i || $title =~ m/utility/i) {
            push @keywords, 'utility';
        }
        if ($title =~ m/help/i || $title =~ m/documentation/i || $title =~ m/docs/i || $title =~ m/manual/i || $title =~ m/guide/i) {
            push @keywords, 'documentation';
        }
        
        # create the bazaar item
        my $item = $bazaar->addChild({
            className   => 'WebGUI::Asset::Sku::BazaarItem',
            ownerUserId => $thread->get('ownerUserId'),
            title       => $title,
            menuTitle   => $title,
            url         => $bazaar->get('url').'/'.$title,
            synopsis    => substr(WebGUI::HTML::html2text($thread->get('content')),0,250),
            description => $thread->get('content'),
            releaseDate => WebGUI::DateTime->new($session, $thread->get('revisionDate'))->toDatabaseDate,
            views       => $thread->get('views'),
            downloads      => ($thread->get('views')*.01),
            keywords    => join(' ', @keywords),
            requirements=> 'Please be advised: this contribution was tested with something older than WebGUI 7.5. When this contribution was uploaded there was no field for the author to fill out regarding it\'s requirements.',
            },
            undef,
            $thread->get('revisionDate'),
            { skipAutoCommitWorkflows => 1 });
        print "\tCreated item ".$item->getId."\n";
        
        # deal with subscriptions
        print "\tMigrating subscriptions\n";
        if ($thread->get('subscriptionGroupId') ne '') {
            my $threadSubGrp = WebGUI::Group->new($session, $thread->get('subscriptionGroupId'));
            if (defined $threadSubGrp) {
                $item->getSubscriptionGroup->addUsers($threadSubGrp->getUsers);
            }
        }
        
        # attach screen shots and downloadables
        print "\tmigrating storables\n";
        my $threadStorage = $thread->getStorageLocation;
        my $screenStorage = $item->getScreenStorage;
        my $productStorage = $item->getProductStorage;
        foreach my $file (@{$threadStorage->getFiles}) {
            if ($threadStorage->isImage($file)) {
                $screenStorage->addFileFromFilesystem($threadStorage->getPath($file));
                $screenStorage->generateThumbnail($file);
            }
            else {
                $productStorage->addFileFromFilesystem($threadStorage->getPath($file));
            }
        }
        
        # import comments
        print "\tmigrating comments\n";
        my @comments = ();
        my $count = 0;
        my $sum = 0;
        foreach my $post (@{$thread->getLineage(['descendants'],{returnObjects=>1, includeOnlyClasses=>['WebGUI::Asset::Post']})}) {
            if (defined $post) {
                print "\t\tpost ".$post->getId."\n";
                my $rating = ($post->get('rating') > 0) ? 4 : 2;
                $rating = 3 if ($post->get('rating') == 0);
                $count++;
                $sum += $rating;
                my $comment = WebGUI::HTML::html2text($post->get('content'));
                WebGUI::Macro::negate(\$comment);
                push @comments, {
                    userId      => $post->get('ownerUserId'),
                    alias		=> $post->get('username'),
        			comment		=> $comment,
        			rating		=> $rating,
        			date		=> $post->get('revisionDate'),
                    };
            }
        }
        my $averageRating = 0;
        if ($count > 0) {
            $averageRating = $sum/$count;
        }
        $item->update({averageRating=>$averageRating, comments=>\@comments});
        $item->requestAutoCommit;
    }
}



finish($session);

print "Whew!! All done.\n";

#-------------------------------------------------
# Your sub here

#-------------------------------------------------
sub start {
    my $configFile;
    $| = 1; #disable output buffering
    GetOptions(
        'configFile=s' => \$configFile,
        'bazaar=s' => \$bazaarId,
        'cs=s' => \$csId,
    );
    my $session = WebGUI::Session->open($webguiRoot,$configFile);
    $session->user({userId=>3});
    
    ## If your script is adding or changing content you need these lines, otherwise leave them commented
    #
    my $versionTag = WebGUI::VersionTag->getWorking($session);
    $versionTag->set({name => 'Bazaar Migration'});
    #
    ##
    
    return $session;
}

#-------------------------------------------------
sub finish {
    my $session = shift;
    
    ## If your script is adding or changing content you need these lines, otherwise leave them commented
    #
    my $versionTag = WebGUI::VersionTag->getWorking($session);
    $versionTag->commit;
    ##
    
    $session->var->end;
    $session->close;
}

__END__


=head1 NAME

utility - A template for WebGUI utility scripts

=head1 SYNOPSIS

 utility --configFile config.conf ...

 utility --help

=head1 DESCRIPTION

This WebGUI utility script helps you...

=over

=item B<--configFile config.conf>

The WebGUI config file to use. Only the file name needs to be specified,
since it will be looked up inside WebGUI's configuration directory.
This parameter is required.

=item B<--help>

Shows this documentation, then exits.

=back

=head1 AUTHOR

Copyright 2001-2008 Plain Black Corporation.

=cut
