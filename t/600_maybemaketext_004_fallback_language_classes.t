#!perl

use strict;
use warnings;
use vars;
use File::Basename();
use File::Spec();
use lib File::Spec->catdir( File::Basename::dirname( File::Spec->rel2abs(__FILE__) ), q/lib/ );
use Locale::MaybeMaketext::Tests::Base qw/:all/;

use Test2::Tools::Target 'Locale::MaybeMaketext';
is(
    [], [ $CLASS->fallback_language_classes() ],
    'Fallback language classes should always return empty array'
);

done_testing();
