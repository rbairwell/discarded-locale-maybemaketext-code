package Locale::MaybeMaketext::Tests::InvalidDetectors::DetectorWarning;
use strict;
use warnings;
use vars;
use utf8;
## no critic (ErrorHandling::RequireCarping)
warn('Code raises a warning. If we did not cache results, this could be because a module is attempted to be reloaded');

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
