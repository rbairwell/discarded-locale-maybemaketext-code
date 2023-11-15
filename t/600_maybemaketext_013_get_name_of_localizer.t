#!perl

use strict;
use warnings;
use vars;
use File::Basename();
use File::Spec();
use lib File::Spec->catdir( File::Basename::dirname( File::Spec->rel2abs(__FILE__) ), q/lib/ );
use Locale::MaybeMaketext::Tests::Base qw/:all/;
use Test2::Tools::Target 'Locale::MaybeMaketext';

my $current_localizer = Locale::MaybeMaketext->maybe_maketext_get_name_of_localizer();
my @all_localizers    = Locale::MaybeMaketext::MAYBE_MAKETEXT_KNOWN_LOCALIZERS;
my $matched           = any { $_ eq $current_localizer } @all_localizers;
ok( $matched, 'maybe_maketext_get_name_of_localizer: Should match a known localizer' );

done_testing();
