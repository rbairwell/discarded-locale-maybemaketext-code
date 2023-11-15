package Locale::MaybeMaketext::Tests::InvalidDetectors::DetectorFaultsOnCan;
use strict;
use warnings;
use vars;
use utf8;

sub can {
    die('Can errored here!');    ## no critic (ErrorHandling::RequireCarping)
}

sub somethingtest {
    return 0;
}

sub othertest {
    return 0;
}

1;
