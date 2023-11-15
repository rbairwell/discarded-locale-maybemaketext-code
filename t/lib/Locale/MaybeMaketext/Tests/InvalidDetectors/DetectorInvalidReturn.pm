package Locale::MaybeMaketext::Tests::InvalidDetectors::DetectorInvalidReturn;
use strict;
use warnings;
use vars;
use utf8;

sub somethingtest {
    return 0;
}

sub othertest {
    return 0;
}

0;    ## no critic (Modules::RequireEndWithOne)
