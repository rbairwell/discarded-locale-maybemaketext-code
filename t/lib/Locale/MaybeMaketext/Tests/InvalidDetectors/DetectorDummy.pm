package Locale::MaybeMaketext::Tests::InvalidDetectors::DetectorDummy;
use strict;
use warnings;
use vars;
use utf8;

sub detect {
    return 'Detected!';
}

sub somethingtest {
    return 0;
}

sub othertest {
    return 0;
}

1;
