#!perl

use strict;
use warnings;
use vars;
use File::Basename();
use File::Spec();
use lib File::Spec->catdir( File::Basename::dirname( File::Spec->rel2abs(__FILE__) ), q/lib/ );
use Locale::MaybeMaketext::Tests::Base qw/:all/;
my %empty_hash    = ();
my $code_sample   = sub { };
my %expected_hash = ( 'ab::cd' => 'ed::gh' );
my %returned_hash;

my $null_locale = $CLASS->MAYBE_MAKETEXT_NULL_LOCALE;

is(
    $CLASS->maybe_maketext_get_text_domains_to_locales_mappings(), %empty_hash,
    'maybe_maketext_get_text_domains_to_locales_mappings: Mapping should be empty after reset'
);

### check failures in add_text_domains
starts_with(
    dies { $CLASS->maybe_maketext_add_text_domains(undef); },
    'Invalid call. Must be passed a hash/associative array got undef',
    'maybe_maketext_add_text_domains: Should error on undef'
);
starts_with(
    dies { $CLASS->maybe_maketext_add_text_domains($code_sample); },
    'Invalid call. Must be passed a hash/associative array got CODE',
    'maybe_maketext_add_text_domains: Should error on CODE'
);
starts_with(
    dies { $CLASS->maybe_maketext_add_text_domains( 'main', 'Abc::i18n', $code_sample, 'tester' ); },
    'Invalid call. All keys must be scalars - instead got CODE as the 2 entry',
    'maybe_maketext_add_text_domains: Reject invalid keys/text domains'
);
starts_with(
    dies { $CLASS->maybe_maketext_add_text_domains( 'main', undef ); },
    'Invalid locale translation package: "[Undefined]". Only package names as strings are supported on call to maybe_maketext_add_text_domains for text domain "main"',
    'maybe_maketext_add_text_domains: Translation locale packages must not be undefined'
);
starts_with(
    dies { $CLASS->maybe_maketext_add_text_domains( 'main', $code_sample ); },
    'Invalid locale translation package: "[Type CODE]". Only package names as strings are supported on call to maybe_maketext_add_text_domains for text domain "main"',
    'maybe_maketext_add_text_domains: Translation locale packages must not be CODE'
);
starts_with(
    dies { $CLASS->maybe_maketext_add_text_domains( 'test', 'Abc::i18n' ); },
    'Invalid text domain: "test". Only package names, "default" and "main" are supported on call to maybe_maketext_add_text_domains at',
    'maybe_maketext_add_text_domains: Reject arbitary text domains'
);
starts_with(
    dies { $CLASS->maybe_maketext_add_text_domains('B'); },
    '"maybe_maketext_add_text_domains" was supplied with an unbalanced argument list (1 items). If passing an array, pass by reference.',
    'maybe_maketext_add_text_domains: Single strings are not allowed'
);
starts_with(
    dies { $CLASS->maybe_maketext_add_text_domains( 'B' => 'dEF' ); },
    'Invalid text domain: "B". Only package names, "default" and "main" are supported on call to maybe_maketext_add_text_domains at',
    'maybe_maketext_add_text_domains: Reject single letter text domains'
);
starts_with(
    dies { $CLASS->maybe_maketext_add_text_domains( 'aCD::B' => 'def' ); },
    'Invalid text domain: "aCD::B". Only package names, "default" and "main" are supported on call to maybe_maketext_add_text_domains at',
    'maybe_maketext_add_text_domains: Reject short text domains'
);
starts_with(
    dies { $CLASS->maybe_maketext_add_text_domains( 'default', 'testester' ); },
    'Invalid locale translation package: "testester". Only package names as strings are supported '
      . 'on call to maybe_maketext_add_text_domains for text domain "default',
    'maybe_maketext_add_text_domains: Translation destinations must look like packages'
);

# reset for safety
$CLASS->maybe_maketext_reset();
%expected_hash = (
    'Abc::Def' => 'Example::Translation::Package',
    'Ghi::Jkl' => 'Example::I18N',
);
is(
    $CLASS->maybe_maketext_add_text_domains(
        'Abc::Def' => 'Example::Translation::Package', 'Ghi::Jkl' => 'Example::I18N'
    ),
    %expected_hash,
    'maybe_maketext_add_text_domains: Adding a mapping should return mappings'
);
%expected_hash = (
    'Abc::Def'       => 'Example::Translation::Package',
    'Ghi::Jkl'       => 'Example::I18N',
    'default'        => 'Example::DefaultTranslate',
    'Ghi::Jkl::M1no' => 'Example::Translation::Package',
    'main'           => 'Something::Translator',
);
is(
    $CLASS->maybe_maketext_add_text_domains(
        'default' => 'Example::DefaultTranslate', 'Ghi::Jkl::M1no' => 'Example::Translation::Package',
        'main'    => 'Something::Translator'
    ),
    %expected_hash,
    'maybe_maketext_add_text_domains: Adding more should return the entire list'
);

## just try adding in slightly different ways
$CLASS->maybe_maketext_reset();
%expected_hash = (
    'Abc::Def'       => 'Example::Translation::Package',
    'Ghi::Jkl'       => 'Example::I18N',
    'default'        => 'Example::DefaultTranslate',
    'Ghi::Jkl::M1no' => 'Example::Translation::Package',
    'main'           => 'Something::Translator',
);
is(
    $CLASS->maybe_maketext_add_text_domains(%expected_hash),
    %expected_hash,
    'maybe_maketext_add_text_domains: Should accept a straight hash'
);
is(
    $CLASS->maybe_maketext_add_text_domains( (%expected_hash) ),
    %expected_hash,
    'maybe_maketext_add_text_domains: Should accept an array of a hash'
);

$CLASS->maybe_maketext_reset();
$CLASS->maybe_maketext_add_text_domains(
    'Abc::Def'       => 'Example::Translation::Package',
    'Ghi::Jkl'       => 'Example::I18N',
    'Ghi::Jkl::M1no' => 'Example::Translation::Package',
    'main'           => 'Something::Translator',
);
starts_with(
    warning {
        is(
            $CLASS->maybe_maketext_get_locale_for_text_domain('unrecognised::package'), $null_locale,
            'maybe_maketext_get_locale_for_text_domain: If there is no default, MAYBE_MAKETEXT_NULL_LOCALE should be returned with a warning'
        );
    },
    "Missing text_domain mapping. Unable to find a translation package mapping for the text domain \"unrecognised::package\". Returning \"$null_locale\".",
    'maybe_maketext_get_locale_for_text_domain: If there is no default, a warning should be returned with MAYBE_MAKETEXT_NULL_LOCALE'
);

# add the default
$CLASS->maybe_maketext_add_text_domains( 'default' => 'Example::DefaultTranslate' );
## check reading back
is(
    $CLASS->maybe_maketext_get_text_domains_to_locales_mappings(),
    %expected_hash,
    'maybe_maketext_get_text_domains_to_locales_mappings: Should return the entire list'
);
starts_with(
    dies {
        $CLASS->maybe_maketext_get_locale_for_text_domain($code_sample);
    },
    'Invalid text domain: "[Type CODE]". Only package names, "" (empty string), "default" and "main" are supported on call to maybe_maketext_get_locale_for_text_domain at',
    'maybe_maketext_get_locale_for_text_domain: Should check called with scalar'
);

is(
    $CLASS->maybe_maketext_get_locale_for_text_domain('Ghi::Jkl::testing::tester'), 'Example::I18N',
    'maybe_maketext_get_locale_for_text_domain: Should match longest string'
);
is(
    $CLASS->maybe_maketext_get_locale_for_text_domain('Ghi::Jkl::M1no::thing'), 'Example::Translation::Package',
    'maybe_maketext_get_locale_for_text_domain: Should match longest string 2'
);
is(
    $CLASS->maybe_maketext_get_locale_for_text_domain('Ghi::Jkl'), 'Example::I18N',
    'maybe_maketext_get_locale_for_text_domain: Should match appropriate string'
);
is(
    $CLASS->maybe_maketext_get_locale_for_text_domain('main'), 'Something::Translator',
    'maybe_maketext_get_locale_for_text_domain: Should match "main"'
);
is(
    $CLASS->maybe_maketext_get_locale_for_text_domain(), 'Something::Translator',
    'maybe_maketext_get_locale_for_text_domain: Undefined should match "main"'
);
is(
    $CLASS->maybe_maketext_get_locale_for_text_domain(q{}), 'Example::DefaultTranslate',
    'maybe_maketext_get_locale_for_text_domain: Empty string should match "default"'
);
is(
    $CLASS->maybe_maketext_get_locale_for_text_domain('unrecognised::package'), 'Example::DefaultTranslate',
    'maybe_maketext_get_locale_for_text_domain: Should return default setting if no match'
);
#

## now try removing/deleting
starts_with(
    dies {
        $CLASS->maybe_maketext_remove_text_domains($code_sample);
    },
    'Invalid text domain: "[Type CODE]". Only package names, "default" and "main" are supported on call to maybe_maketext_remove_text_domains at',
    'maybe_maketext_remove_text_domains: Should only accept strings.'
);
starts_with(
    dies {
        $CLASS->maybe_maketext_remove_text_domains('bad package');
    },
    'Invalid text domain: "bad package". Only package names, "default" and "main" are supported on call to maybe_maketext_remove_text_domains at',
    'maybe_maketext_remove_text_domains: Should only accept set list'
);
starts_with(
    warning {
        is(
            $CLASS->maybe_maketext_remove_text_domains('KJKS::sklfjdk'), %empty_hash,
            'maybe_maketext_remove_text_domains: Invalid should return empty'
        );
    },
    'Invalid text domain mapping. Text domain "KJKS::sklfjdk" does not have any mappings.',
    'maybe_maketext_remove_text_domains: Invalid should raise warning'
);

# now try deleting and ensure we get the right fallback
$CLASS->maybe_maketext_reset();
$CLASS->maybe_maketext_add_text_domains(
    'Abc::Def'       => 'Example::Translation::Package',
    'Ghi::Jkl'       => 'Example::I18N',
    'default'        => 'Example::DefaultTranslate',
    'Ghi::Jkl::M1no' => 'Example::Translation::Package',
    'main'           => 'Something::Translator',
);

%expected_hash = (
    'main'           => 'Something::Translator',
    'Ghi::Jkl::M1no' => 'Example::Translation::Package',
);
is(
    $CLASS->maybe_maketext_remove_text_domains(qw/main Ghi::Jkl::M1no/), %expected_hash,
    'maybe_maketext_remove_text_domains: Items removed should be returned for reference.'
);
%expected_hash = (
    'Abc::Def' => 'Example::Translation::Package',
    'Ghi::Jkl' => 'Example::I18N',
    'default'  => 'Example::DefaultTranslate',
);
is(
    $CLASS->maybe_maketext_get_locale_for_text_domain('main'), 'Example::DefaultTranslate',
    'maybe_maketext_get_locale_for_text_domain: Removed text domain main should return default'
);
is(
    $CLASS->maybe_maketext_get_locale_for_text_domain('Ghi::Jkl::M1no'), 'Example::I18N',
    'maybe_maketext_get_locale_for_text_domain: Removed text domain Ghi::Jkl::M1no should fall back to Ghi::Jkl'
);
is(
    $CLASS->maybe_maketext_get_locale_for_text_domain('Ghi::Jkl::testing::tester'), 'Example::I18N',
    'maybe_maketext_get_locale_for_text_domain: Ghi::Jkl prefix should not be changed after delete'
);
is(
    $CLASS->maybe_maketext_get_locale_for_text_domain('Ghi::Jkl'), 'Example::I18N',
    'maybe_maketext_get_locale_for_text_domain: Ghi::Jkl Should not be changed after delete'
);

# now try maybe_maketext_remove_text_domains_matching_locales
$CLASS->maybe_maketext_reset();
$CLASS->maybe_maketext_add_text_domains(
    'Abc::Def'       => 'Example::Translation::Package',
    'Ghi::Jkl'       => 'Example::I18N',
    'default'        => 'Example::DefaultTranslate',
    'Ghi::Jkl::M1no' => 'Example::Translation::Package',
    'main'           => 'Something::Translator',
);

# first error cases
starts_with(
    dies {
        $CLASS->maybe_maketext_remove_text_domains_matching_locales($code_sample);
    },
    'Invalid locale translation package: "[Type CODE]". Only package names as strings are supported on call to maybe_maketext_remove_text_domains_matching_locales at',
    'maybe_maketext_remove_text_domains_matching_locales: Should reject none scalars'
);
starts_with(
    dies {
        $CLASS->maybe_maketext_remove_text_domains_matching_locales('2398JHXDS');
    },
    'Invalid locale translation package: "2398JHXDS". Only package names as strings are supported on call to maybe_maketext_remove_text_domains_matching_locales at',
    'maybe_maketext_remove_text_domains_matching_locales: Should reject invalid packages'
);
%expected_hash = ();
starts_with(
    warning {
        is(
            $CLASS->maybe_maketext_remove_text_domains_matching_locales('kfdfs::fdoosdf::fsdfsd'), %expected_hash,
            'maybe_maketext_remove_text_domains_matching_locales: Should return empty if nothing removed'
        );
    },
    'Missing text domain mapping. Locale package "kfdfs::fdoosdf::fsdfsd" does not have any text domain mappings',
    'maybe_maketext_remove_text_domains_matching_locales: Should issue warning if locale is unmatched'
);

$CLASS->maybe_maketext_get_locale_for_text_domain('Abc::Def');    # prime the cache
%expected_hash = ( 'Abc::Def' => 'Example::Translation::Package', 'Ghi::Jkl::M1no' => 'Example::Translation::Package' );
%returned_hash = $CLASS->maybe_maketext_remove_text_domains_matching_locales('Example::Translation::Package');
is(
    \%returned_hash,                                                                       \%expected_hash,
    'maybe_maketext_remove_text_domains_matching_locales: Should return removed packages', %returned_hash
);

# check they are gone
%expected_hash = (
    'Ghi::Jkl' => 'Example::I18N',
    'default'  => 'Example::DefaultTranslate',
    'main'     => 'Something::Translator',
);
%returned_hash = $CLASS->maybe_maketext_get_text_domains_to_locales_mappings();
is(
    $CLASS->maybe_maketext_get_text_domains_to_locales_mappings(),
    %expected_hash,
    'maybe_maketext_remove_text_domains_matching_locales: Should have removed them', %returned_hash
);
is(
    $CLASS->maybe_maketext_get_locale_for_text_domain('Abc::Def'), 'Example::DefaultTranslate',
    'maybe_maketext_remove_text_domains_matching_locales: Removed entries should fall back to default'
);
done_testing();
