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

my $session = start();

$session->db->write(<<EOSQL1);
ALTER TABLE bazaar 
   ADD COLUMN templateId char(22) binary not null default 'vhNlRmwdrZivIk1IzEpvYQ',
   ADD COLUMN bazaarItemTemplateId char(22) binary not null default 'VlkZo8ew56Yns_6WMIU8BQ',
   ADD COLUMN searchTemplateId char(22) binary not null default 'ddc-E8lgRHBsSzOSr4aNrw',
   ADD COLUMN vendorsOnly tinyint(1) not null default 0,
   ADD COLUMN autoCreateVendors tinyint(1) not null default 1
EOSQL1

$session->db->write(<<EOSQL2);
ALTER TABLE bazaarItem ADD COLUMN
   ADD COLUMN comments mediumtext,
   ADD COLUMN averageRating float
EOSQL2

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
    );
    my $session = WebGUI::Session->open($configFile);
    $session->user({userId=>3});

    return $session;
}

#-------------------------------------------------
sub finish {
    my $session = shift;
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
