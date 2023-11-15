package Locale::MaybeMaketext::Tests::PackageLoader::DetectorFaulty;
use strict;
use warnings;
use vars;
use utf8;

die('Die die die! This detector is faulty!');    ## no critic (ErrorHandling::RequireCarping)

sub detect() {

}
1;                                               ## no critic (ControlStructures::ProhibitUnreachableCode)
