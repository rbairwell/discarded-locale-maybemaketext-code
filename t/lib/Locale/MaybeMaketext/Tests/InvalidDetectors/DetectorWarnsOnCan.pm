package Locale::MaybeMaketext::Tests::InvalidDetectors::DetectorWarnsOnCan;
use strict;
use warnings;
use vars;
use utf8;

my $counter = 0;

sub can {
    warn('Can warned here!');    ## no critic (ErrorHandling::RequireCarping)
    return;
}

sub somethingtest {
    return 0;
}

sub othertest {
    return 0;
}

1;
