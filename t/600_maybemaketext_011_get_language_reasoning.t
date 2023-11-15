#!perl

use strict;
use warnings;
use vars;
use File::Basename();
use File::Spec();
use lib File::Spec->catdir( File::Basename::dirname( File::Spec->rel2abs(__FILE__) ), q/lib/ );
use Locale::MaybeMaketext::Tests::Base qw/:all/;
use Test2::Tools::Target 'Locale::MaybeMaketext';

my @test_data = qw/hello is it me you are looking for/;
my @return;
my @empty_array = ();

my $fake_handle = bless { '_maybe_maketext_type' => 'handle' }, $CLASS;
@return = $fake_handle->maybe_maketext_get_language_reasoning();
is(
    \@return, \@empty_array,
    'maybe_maketext_get_language_reasoning: Reasoning should be empty by default'
);
$fake_handle = bless { '_maybe_maketext_type' => 'handle', '_maybe_maketext_language_reasoning' => \@test_data },
  $CLASS;
@return = $fake_handle->maybe_maketext_get_language_reasoning();
is(
    \@return, \@test_data,
    'maybe_maketext_get_language_reasoning: Reasoning should be read from the variable'
);

done_testing();
