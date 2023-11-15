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
    $CLASS->MAYBE_MAKETEXT_SELF_VARIABLE_PREFIX, '_maybe_maketext_',
    'Checking MAYBE_MAKETEXT_SELF_VARIABLE_PREFIX is as expected'
);
is(
    $CLASS->MAYBE_MAKETEXT_NULL_LOCALE, 'Locale::MaybeMaketext::NullLocale',
    'Checking MAYBE_MAKETEXT_NULL_LOCALE is as expected'
);

my @settings = (
    'previous',
    'provided',
    'alternatives',
    'supers',
    'Locale::MaybeMaketext::Detectors::Cpanel',
    'Locale::MaybeMaketext::Detectors::Http',
    'Locale::MaybeMaketext::Detectors::I18N',
    qw/i_default en en_us alternatives supers/,
);
is(
    [ $CLASS->MAYBE_MAKETEXT_DEFAULT_LANGUAGE_SETTINGS ],
    \@settings,
    'Checking MAYBE_MAKETEXT_DEFAULT_LANGUAGE_SETTINGS is as expected'
);
@settings = (
    'Cpanel::CPAN::Locale::Maketext::Utils',
    'Locale::Maketext::Utils',
    'Locale::Maketext',
    'Locale::MaybeMaketext::FallbackLocalizer',
);
is(
    [ $CLASS->MAYBE_MAKETEXT_KNOWN_LOCALIZERS ],
    \@settings,
    'Checking MAYBE_MAKETEXT_KNOWN_LOCALIZERS is as expected'
);
done_testing();
