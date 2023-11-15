#!perl

use strict;
use warnings;
use vars;
use File::Basename();
use File::Spec();
use lib File::Spec->catdir( File::Basename::dirname( File::Spec->rel2abs(__FILE__) ), q/lib/ );
use Locale::MaybeMaketext::Tests::Base qw/:all/;
use Test2::Tools::Target 'Locale::MaybeMaketext';

my $fake_handle = bless { '_maybe_maketext_type' => 'handle' }, $CLASS;
is(
    $fake_handle->maybe_maketext_get_locale(), undef,
    'maybe_maketext_get_locale: Locale should be undef by default'
);
$fake_handle = bless { '_maybe_maketext_type' => 'handle', '_maybe_maketext_locale' => 'tester' }, $CLASS;
is(
    $fake_handle->maybe_maketext_get_locale(), 'tester',
    'maybe_maketext_get_locale: Locale should be read from the variable'
);

done_testing();
