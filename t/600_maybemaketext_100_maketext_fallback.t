#!perl

use strict;
use warnings;
use vars;
use File::Basename();
use File::Spec();
use lib File::Spec->catdir( File::Basename::dirname( File::Spec->rel2abs(__FILE__) ), q/lib/ );
use Locale::MaybeMaketext::Tests::Base qw/:all/;

use Test2::Tools::Target 'Locale::MaybeMaketext';
my $lh;

# check fallback first
Locale::MaybeMaketext::maybe_maketext_set_only_specified_localizers(qw/Locale::MaybeMaketext::FallbackLocalizer/);
can_ok( $CLASS, ['get_handle'], 'Fallback: Should support get_handle' );
starts_with(
    warning {
        ok( $lh = $CLASS->get_handle('en-gb'), 'Fallback: Should get a handle' );
    },
    "Missing text_domain mapping. Unable to find a translation package mapping for the text domain \"main\". Returning \"${CLASS}::NullLocale\"",
    'Fallback: Expect a warning as no text_domains are set up'
);
is( ref($lh), 'Locale::MaybeMaketext::FallbackLocalizer', 'Fallback: Ensure we got our fallback handler' );
check_isas(
    $CLASS, [q/Locale::MaybeMaketext::FallbackLocalizer/],
    'Fallback'
);
can_ok( $lh, ['maketext'], 'Fallback: Should support maketext' );

is(
    $lh->maketext( 'This is a test translation [_1] for [_2]', 'passed', $CLASS ),
    "This is a test translation passed for $CLASS",
    'Fallback: Checking translation via handle (only simple subsitution is supported)'
);
is(
    maketext( 'This is a test translation [_1] for [_2]', 'passed', $CLASS ),
    "This is a test translation passed for $CLASS",
    'Fallback: Checking translation via exported reference to maketext (only simple subsitution is supported)'
);

done_testing();
