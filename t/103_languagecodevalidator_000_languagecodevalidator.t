#!perl
use strict;
use warnings;
use vars;
use File::Basename();
use File::Spec();
use lib File::Spec->catdir( File::Basename::dirname( File::Spec->rel2abs(__FILE__) ), q/lib/ );
use feature qw/signatures/;
no if $] >= 5.032, q|feature|, qw/indirect/;
no warnings qw/experimental::signatures/;
use Locale::MaybeMaketext::Tests::Base qw/:all/;
use Locale::MaybeMaketext::Cache();

use Test2::Tools::Target 'Locale::MaybeMaketext::LanguageCodeValidator';
use Locale::MaybeMaketext::LanguageCodeValidator();
my $sut = 'LanguageCodeValidator';

# @TODO: Add tests for validate_multiple with duplicate tags

subtest_buffered "$sut: Checking repeated tests work" => sub {

    # https://www.rfc-editor.org/rfc/rfc5646.html#appendix-A
    _run_regexp_test(
        { 'code' => 'en-GB',   'language' => 'en', 'region' => 'gb' },
        { 'code' => 'zh-Hans', 'language' => 'zh', 'script' => 'hans' },
        { 'code' => 'en-GB',   'language' => 'en', 'region' => 'gb' },
        { 'code' => 'zh-Hans', 'language' => 'zh', 'script' => 'hans' },
    );
};

subtest_buffered "$sut: W3 org Primary language" => sub {

    # https://www.w3.org/International/articles/language-tags/#language
    _run_regexp_test(

        { 'code' => 'en',  'language' => 'en' },
        { 'code' => 'ast', 'language' => 'ast' },
        { 'code' => 'MAS', 'language' => 'mas' },
    );
};
subtest_buffered "$sut: W3 org Extended language" => sub {

    # https://www.w3.org/International/articles/language-tags/#extlang
    _run_regexp_test(
        { 'code' => 'zh-yue', 'language' => 'zh', 'extlang' => 'yue' },
        { 'code' => 'ar-afb', 'language' => 'ar', 'extlang' => 'afb' },
    );
};
subtest_buffered "$sut: W3 org Script" => sub {

    # https://www.w3.org/International/articles/language-tags/#script
    _run_regexp_test(
        { 'code' => 'zh-Hans', 'language' => 'zh', 'script' => 'hans' },
        { 'code' => 'az-Latn', 'language' => 'az', 'script' => 'latn' },
    );
};
subtest_buffered "$sut: W3 org Region" => sub {

    # https://www.w3.org/International/articles/language-tags/#region
    _run_regexp_test(
        { 'code' => 'en-GB',      'language' => 'en', 'region' => 'gb' },
        { 'code' => 'es-005',     'language' => 'es', 'region' => '005' },
        { 'code' => 'fr-CA',      'language' => 'fr', 'region' => 'ca' },
        { 'code' => 'es-419',     'language' => 'es', 'region' => '419' },
        { 'code' => 'zh-Hant-HK', 'language' => 'zh', 'script' => 'hant', 'region' => 'hk' },
    );
};
subtest_buffered "$sut: W3 org Variants" => sub {

    # https://www.w3.org/International/articles/language-tags/#variants
    _run_regexp_test(
        { 'code' => 'sl-nedis', 'language' => 'sl', 'variant' => 'nedis', 'variants' => ['nedis'] },
        { 'code' => 'sl-rozaj', 'language' => 'sl', 'variant' => 'rozaj', 'variants' => ['rozaj'] },
        {
            'code' => 'sl-IT-nedis', 'language' => 'sl', 'region' => 'it', 'variant' => 'nedis', 'variants' => ['nedis']
        },
        { 'code' => 'de-CH-1901', 'language' => 'de', 'region' => 'ch', 'variant' => '1901', 'variants' => ['1901'] },
    );
};
subtest_buffered "$sut: W3 org Extensions/private" => sub {

    # https://www.w3.org/International/articles/language-tags/#variants
    _run_regexp_test(
        {
            'code'       => 'de-DE-u-co-phonebk', 'language' => 'de', 'region' => 'de', 'extension' => 'u_co_phonebk',
            'extensions' => ['u_co_phonebk']
        },
        {
            'code'     => 'en-US-x-twain', 'language' => 'en', 'region' => 'us', 'private' => 'x_twain',
            'privates' => ['twain']
        },
    );
};
subtest_buffered "$sut: RFC primary language" => sub {

    # https://www.rfc-editor.org/rfc/rfc5646.html#appendix-A
    _run_regexp_test(
        { 'code' => 'de', 'language' => 'de' },
        { 'code' => 'fr', 'language' => 'fr' },
        { 'code' => 'ja', 'language' => 'ja' },
    );
};
subtest_buffered "$sut: RFC grandfathered irregular" => sub {
    _run_regexp_test(

        # https://www.rfc-editor.org/rfc/rfc5646.html#appendix-A
        { 'code' => 'i-enochian', 'irregular' => 'i_enochian' },
    );
};
subtest_buffered "$sut: RFC Language Script" => sub {

    # https://www.rfc-editor.org/rfc/rfc5646.html#appendix-A
    _run_regexp_test(
        { 'code' => 'zh-Hant', 'language' => 'zh', 'script' => 'hant' },
        { 'code' => 'zh-Hans', 'language' => 'zh', 'script' => 'hans' },
        { 'code' => 'sr-Cyrl', 'language' => 'sr', 'script' => 'cyrl' },
        { 'code' => 'sr-Latn', 'language' => 'sr', 'script' => 'latn' },
    );
};
subtest_buffered "$sut: RFC Extended language subtags+primary language subtag" => sub {

    # https://www.rfc-editor.org/rfc/rfc5646.html#appendix-A
    _run_regexp_test(
        { 'code' => 'zh-cmn-Hans-CN', 'language' => 'zh',  'extlang' => 'cmn',  'script' => 'hans', 'region' => 'cn' },
        { 'code' => 'cmn-Hans-CN',    'language' => 'cmn', 'script'  => 'hans', 'region' => 'cn' },
        { 'code' => 'zh-yue-HK',      'language' => 'zh',  'extlang' => 'yue',  'region' => 'hk' },
        { 'code' => 'yue-HK',         'language' => 'yue', 'region'  => 'hk' },
    );
};
subtest_buffered "$sut: RFC Language-Script-Region" => sub {

    # https://www.rfc-editor.org/rfc/rfc5646.html#appendix-A
    _run_regexp_test(
        { 'code' => 'zh-Hans-CN', 'language' => 'zh', 'script' => 'hans', 'region' => 'cn' },
        { 'code' => 'sr-Latn-RS', 'language' => 'sr', 'script' => 'latn', 'region' => 'rs' },
    );
};
subtest_buffered "$sut: RFC Language-Variant" => sub {

    # https://www.rfc-editor.org/rfc/rfc5646.html#appendix-A
    _run_regexp_test(

        { 'code' => 'sl-rozaj', 'language' => 'sl', 'variant' => 'rozaj', 'variants' => ['rozaj'] },
        { 'code' => 'sl-nedis', 'language' => 'sl', 'variant' => 'nedis', 'variants' => ['nedis'] },
    );
};
subtest_buffered "$sut: RFC Language-Variant rozaj-biske special case" => sub {

    # special case as "rozaj-biske" is actually a single word variant and should not be split
    # https://www.rfc-editor.org/rfc/rfc5646.html#appendix-A
    # https://www.iana.org/assignments/language-subtag-registry/language-subtag-registry
    _run_regexp_test(

        { 'code' => 'sl-rozaj-biske', 'language' => 'sl', 'variant' => 'rozaj_biske', 'variants' => ['rozaj_biske'] },
    );
};
subtest_buffered "$sut: RFC Language-Region-Variant" => sub {

    # https://www.rfc-editor.org/rfc/rfc5646.html#appendix-A
    _run_regexp_test(
        { 'code' => 'de-CH-1901', 'language' => 'de', 'region' => 'ch', 'variant' => '1901', 'variants' => ['1901'] },
        {
            'code' => 'sl-IT-nedis', 'language' => 'sl', 'region' => 'it', 'variant' => 'nedis', 'variants' => ['nedis']
        },
    );
};
subtest_buffered "$sut: RFC Language-Script-Region-Variant" => sub {

    # https://www.rfc-editor.org/rfc/rfc5646.html#appendix-A
    _run_regexp_test(
        {
            'code'    => 'hy-Latn-IT-arevela', 'language' => 'hy', 'script' => 'latn', 'region' => 'it',
            'variant' => 'arevela',            'variants' => ['arevela'],
        },
    );
};
subtest_buffered "$sut: RFC Language-Region" => sub {

    # https://www.rfc-editor.org/rfc/rfc5646.html#appendix-A
    _run_regexp_test(
        { 'code' => 'de-DE',  'language' => 'de', 'region' => 'de' },
        { 'code' => 'en-US',  'language' => 'en', 'region' => 'us' },
        { 'code' => 'es-419', 'language' => 'es', 'region' => '419' },
    );
};
subtest_buffered "$sut: RFC Private Usage" => sub {

    # https://www.rfc-editor.org/rfc/rfc5646.html#appendix-A
    _run_regexp_test(
        {
            'code'     => 'de-CH-x-phonebk', 'language' => 'de', 'region' => 'ch', 'private' => 'x_phonebk',
            'privates' => ['phonebk']
        },
        {
            'code'     => 'az-Arab-x-AZE-derbend', 'language' => 'az', 'script' => 'arab', 'private' => 'x_aze_derbend',
            'privates' => [ 'aze', 'derbend' ]
        },
        { 'code' => 'x-whatever', 'private' => 'x_whatever', 'privates' => ['whatever'] },
    );
};
subtest_buffered "$sut: RFC Extensions" => sub {

    # https://www.rfc-editor.org/rfc/rfc5646.html#appendix-A
    # Note: "Tags that use extensions (examples ONLY -- extensions MUST be defined
    # by revision or update to this document, or by RFC". zh-CN-a... has therefore been changed
    # to zh-CN-t... and en-a-myext-b-another to en-u-myext-t-another
    _run_regexp_test(
        {
            'code'       => 'en-US-u-islamcal', 'language' => 'en', 'region' => 'us', 'extension' => 'u_islamcal',
            'extensions' => ['u_islamcal']
        },
        {
            'code'    => 'zh-CN-t-myext-x-private', 'language' => 'zh', 'region' => 'cn', 'extension' => 't_myext',
            'private' => 'x_private', 'extensions' => ['t_myext'], 'privates' => ['private']
        },
        {
            'code'       => 'en-u-myext-t-another',
            'new_code'   => 'en_t_another_u_myext', 'language' => 'en', 'extension' => 't_another_u_myext',
            'extensions' => [ 't_another', 'u_myext' ]
        },
    );
};
subtest_buffered "$sut: RFC Invalid" => sub {

    # https://www.rfc-editor.org/rfc/rfc5646.html#appendix-A
    _run_regexp_test(

        { 'code' => 'de-419-DE', 'fail' => 'two region tags', 'reasoning' => 'Failed regular expression match' },
        {
            'code'      => 'a-DE', 'fail' => 'use of a single character subtag in primary position',
            'reasoning' => 'Language code "a" is an invalid length (1) - it should be between 2 and 3 inclusive'
        },
    );
};
subtest_buffered "$sut: RFC Others" => sub {
    _run_regexp_test(

        # https://www.rfc-editor.org/rfc/rfc5646.html#section-2.2.6 :
        # 3. Each singleton subtag MUST appear at most one time in each tag
        # (other than as a private use subtag).  That is, singleton subtags
        # MUST NOT be repeated.  For example, the tag "en-a-bbb-a-ccc" is
        # invalid because the subtag 'a' appears twice.  Note that the tag
        # "en-a-bbb-x-a-ccc" is valid because the second appearance of the
        # singleton 'a' is in a private use sequence.
        # Note from Appendix A " Tags that use extensions (examples ONLY --
        # extensions MUST be defined by revision or update to this document,
        # or by RFC):". As of August 2023, only "U" and "T" have been allocated
        # and hence only those letters are used in these examples.
        {
            'code'      => 'en-u-bbb-u-cc',
            'fail'      => 'duplicated singleton',
            'reasoning' => 'Bad singletons: Duplicated singleton "u"'
        },
        {
            'code'       => 'en-u-bbb-x-u-ccc',
            'language'   => 'en',
            'extension'  => 'u_bbb',
            'extensions' => ['u_bbb'],
            'private'    => 'x_u_ccc',
            'privates'   => [ 'u', 'ccc' ],
        },

        # https://www.rfc-editor.org/rfc/rfc5646.html#section-2.2.6 :
        # 6. Each singleton MUST be followed by at least one extension subtag.
        # For example, the tag "tlh-a-b-foo" is invalid because the first
        # singleton 't' is followed immediately by another singleton 'u'.
        {
            'code'      => 'tlh-t-u-foo',
            'fail'      => 'singletons follow each other',
            'reasoning' => 'Failed regular expression match'
        },

        # https://www.rfc-editor.org/rfc/rfc5646.html#section-2.2.6 :
        # "8. All subtags following the singleton and before another singleton
        # are part of the extension.  Example: In the tag "fr-a-Latn", the
        # subtag 'Latn' does not represent the script subtag 'Latn' defined
        # in the IANA Language Subtag Registry.  Its meaning is defined by
        # the extension 'a'."
        # (subsituted for "u" as "a" is not a valid extension)
        {
            'code'       => 'fr-u-Latn',
            'language'   => 'fr',
            'extension'  => 'u_latn',
            'extensions' => ['u_latn'],
        },

        # https://www.rfc-editor.org/rfc/rfc5646.html#section-2.2.6 :
        # "(after point 9)
        # For example, if an extension were defined for the singleton 'r' and
        # it defined the subtags shown, then the following tag would be a valid
        # example: "en-Latn-GB-boont-r-extended-sequence-x-private"."
        # However, as of August 2023, "r" is not a valid extension singleton
        # and so has been replaced here with "t" which is.
        {
            'code'       => 'en-Latn-GB-boont-t-extended-sequence-x-private',
            'language'   => 'en',
            'script'     => 'latn',
            'region'     => 'gb',
            'variant'    => 'boont',
            'variants'   => ['boont'],
            'extension'  => 't_extended_sequence',
            'extensions' => ['t_extended_sequence'],
            'private'    => 'x_private',
            'privates'   => ['private']
        }
    );
};
subtest_buffered "$sut: Just made up invalid ones" => sub {
    _run_regexp_test(
        {
            'code'      => 'hello', 'fail' => '5 letters should not language',
            'reasoning' => 'Language code "hello" is an invalid length (5) - it should be between 2 and 3 inclusive'
        },
        {
            'code'      => 'something', 'fail' => 'too long',
            'reasoning' =>
              'Language code "something" is an invalid length (9) - it should be between 2 and 3 inclusive'
        },
        {
            'code'      => '123', 'fail' => 'numerics',
            'reasoning' => 'Language code "123" has invalid characters - only lower case a-z is permitted'
        },
        { 'code' => 'a', 'fail' => 'Whole code too short', 'reasoning' => 'Language code is empty/too short' },
        {
            'code'      => 'a-gb', 'fail' => 'Too short',
            'reasoning' => 'Language code "a" is an invalid length (1) - it should be between 2 and 3 inclusive'
        }
    );
};
subtest_buffered "$sut: Private values from RFC" => sub {

    # https://www.rfc-editor.org/rfc/rfc5646.html#appendix-A
    _run_regexp_test(
        {
            'code'      => 'qaa-Qaaa-QM-x-southern',
            'fail'      => 'Private language code',
            'reasoning' => 'Language codes qaa-qtz are reserved for private use only - includes "qaa"'
        },

        {
            'code'      => 'sr-Latn-QM',
            'fail'      => 'Private region code',
            'reasoning' => 'Region code "qm" is reserved for private use only'
        },
        {
            'code'      => 'sr-Qaaa-RS',
            'fail'      => 'Private script code',
            'reasoning' => 'Script codes Qaaa-Qabx are reserved for private use only - includes "qaaa"',
        },

        {
            'code'      => 'de-Qabt',
            'fail'      => 'Private script code',
            'reasoning' => 'Script codes Qaaa-Qabx are reserved for private use only - includes "qabt"',
        }
    );
};
subtest_buffered "$sut: Ones which change" => sub {
    _run_regexp_test(
        { 'code' => 'en-uk', 'new_code' => 'en_gb', 'language' => 'en', 'region' => 'gb' },
    );
};
subtest_buffered "$sut: Grandfathered codes tests" => sub {

    # these should not be individually parsed or changed in any way.
    _run_regexp_test(
        { 'code' => 'en_gb_oed',   'irregular' => 'en_gb_oed' },
        { 'code' => 'sgn_be_ft',   'irregular' => 'sgn_be_ft' },
        { 'code' => 'sgn_be_nl',   'irregular' => 'sgn_be_nl' },
        { 'code' => 'sgn_ch_de',   'irregular' => 'sgn_ch_de' },
        { 'code' => 'i_ami',       'irregular' => 'i_ami' },
        { 'code' => 'i_bnn',       'irregular' => 'i_bnn' },
        { 'code' => 'i_default',   'irregular' => 'i_default' },
        { 'code' => 'i_enochian',  'irregular' => 'i_enochian' },
        { 'code' => 'i_hak',       'irregular' => 'i_hak' },
        { 'code' => 'i_klingon',   'irregular' => 'i_klingon' },
        { 'code' => 'i_lux',       'irregular' => 'i_lux' },
        { 'code' => 'i_mingo',     'irregular' => 'i_mingo' },
        { 'code' => 'i_navajo',    'irregular' => 'i_navajo' },
        { 'code' => 'i_pwn',       'irregular' => 'i_pwn' },
        { 'code' => 'i_tao',       'irregular' => 'i_tao' },
        { 'code' => 'i_tay',       'irregular' => 'i_tay' },
        { 'code' => 'i_tsu',       'irregular' => 'i_tsu' },
        { 'code' => 'art_lojban',  'regular'   => 'art_lojban' },
        { 'code' => 'cel_gaulish', 'regular'   => 'cel_gaulish' },
        { 'code' => 'no_bok',      'regular'   => 'no_bok' },
        { 'code' => 'no_nyn',      'regular'   => 'no_nyn' },
        { 'code' => 'zh_guoyu',    'regular'   => 'zh_guoyu' },
        { 'code' => 'zh_hakka',    'regular'   => 'zh_hakka' },
        { 'code' => 'zh_min',      'regular'   => 'zh_min' },
        { 'code' => 'zh_min_nan',  'regular'   => 'zh_min_nan' },
        { 'code' => 'zh_xiang',    'regular'   => 'zh_xiang' },
    );
};
subtest_buffered "$sut: Made up variant tests" => sub {
    _run_regexp_test(
        { 'code' => 'de-DE-1901-1901', 'fail' => 'Duplicate variants', 'reasoning' => 'Duplicated variants: 1901' },
        {
            'code'     => 'de-DE-1966-1901', 'new_code' => 'de_de_1901_1966', 'language' => 'de', 'region' => 'de',
            'variant'  => '1901_1966',
            'variants' => [ '1901', '1966' ]
        },
        {
            'code'     => 'de-CH-1996', 'language' => 'de', 'region' => 'ch', 'variant' => '1996',
            'variants' => ['1996']
        },
    );
};

subtest_buffered "$sut: Made up extension tests" => sub {
    _run_regexp_test(
        {
            'code'      => 'en-latn-gb-e-dsome', 'fail' => 'Invalid extension singleton',
            'reasoning' => 'Bad singletons: Invalid singleton "e" - only "t" and "u" are accepted for extensions'
        },
        {
            'code'       => 'en-latn-gb-u-dsome',
            'language'   => 'en', 'script' => 'latn', 'region' => 'gb', 'extension' => 'u_dsome',
            'extensions' => ['u_dsome']
        },
        {
            'code'      => 'en-latn-gb-t-dsome',
            'language'  => 'en',      'script'     => 'latn', 'region' => 'gb',
            'extension' => 't_dsome', 'extensions' => ['t_dsome']
        },
        {
            'code'      => 'pt-br-t-exte1-t-exte2', 'fail' => 'Duplicate singletons',
            'reasoning' => 'Bad singletons: Duplicated singleton "t"'
        },
        {
            'code'      => 'en-latn-gb-u-gkje-t-osjkd-u-cklsd-tester', 'fail' => 'Duplicate singletons with others',
            'reasoning' => 'Bad singletons: Duplicated singleton "u"'
        },
        {
            'code'      => 'en-latn-gb-u-xdf-t-cklsd-tester-dlsk-tester', 'fail' => 'Duplicate extension',
            'reasoning' => 'Bad singletons: Singleton "t" has duplicated extension: tester'
        },

        {
            'code'     => 'en-latn-gb-u-jxds-t-cklsd-tester-dlsk-cx',
            'new_code' => 'en_latn_gb_t_cklsd_cx_dlsk_tester_u_jxds',
            'language' => 'en',
            'script'   => 'latn',
            'region'   => 'gb',

            # extensions should be ordered
            # https://www.rfc-editor.org/rfc/rfc5646.html#section-2.2.1 :
            # 9. In the event that more than one extension appears in a single
            # tag, the tag SHOULD be canonicalized as described in Section 4.5,
            # by ordering the various extension sequences into case -insensitive ASCII order .
            'extension'  => 't_cklsd_cx_dlsk_tester_u_jxds',
            'extensions' => [ 't_cklsd_cx_dlsk_tester', 'u_jxds' ],
        },
    );
};
subtest_buffered "$sut: Made up private tests" => sub {
    for my $prefix ( 0 .. 1 ) {
        _run_regexp_test(
            {
                'code'      => ( $prefix ? 'en_'         : q{} ) . 'x__some_thing',
                'fail'      => ( $prefix ? 'With prefix' : 'Direct' ) . ' Missing entry',
                'reasoning' => 'Bad private entries: Private entry 1 has no text'
            },
            {
                'code'      => ( $prefix ? 'en_'         : q{} ) . 'x_x_something',
                'fail'      => ( $prefix ? 'With prefix' : 'Direct' ) . ' Too long',
                'reasoning' =>
                  'Bad private entries: Private entry 2 ("something") exceeds maximum length (it is 9 characters in length)'
            },
            {
                'code'      => ( $prefix ? 'en_'         : q{} ) . 'x_xjks_k2!3',
                'fail'      => ( $prefix ? 'With prefix' : 'Direct' ) . ' Invalid characters',
                'reasoning' => 'Bad private entries: Private entry 2 ("k2!3") has invalid characters'
            },
            {
                'code'      => ( $prefix ? 'en_' : q{} ) . 'x_hay_ho_here_we_go_with_a_little_bit_high_little_bit_low',
                'fail'      => ( $prefix ? 'With prefix' : 'Direct' ) . ' Duplicated tag',
                'reasoning' => 'Bad private entries: '
                  . 'Private entry 11 ("little") is a duplicate of that found in position 8, '
                  . 'Private entry 12 ("bit") is a duplicate of that found in position 9'
            },
            {
                'code'      => ( $prefix ? 'en_'         : q{} ) . 'x_xjks_k2!3_hey_kxk_k23_hey_k2!3',
                'fail'      => ( $prefix ? 'With prefix' : 'Direct' ) . ' Invalid characters',
                'reasoning' => 'Bad private entries: '
                  . 'Private entry 2 ("k2!3") has invalid characters, '
                  . 'Private entry 6 ("hey") is a duplicate of that found in position 3, '
                  . 'Private entry 7 ("k2!3") has invalid characters'
            },
            {
                'code'      => ( $prefix ? 'en_'         : q{} ) . 'x_xjks_k2!3_hey_kxk_k23_hey_k2!3',
                'fail'      => ( $prefix ? 'With prefix' : 'Direct' ) . ' Invalid characters',
                'reasoning' => 'Bad private entries: '
                  . 'Private entry 2 ("k2!3") has invalid characters, '
                  . 'Private entry 6 ("hey") is a duplicate of that found in position 3, '
                  . 'Private entry 7 ("k2!3") has invalid characters'
            },
        );
    }
    _run_regexp_test(
        {
            'code'     => 'x_entirely_made_up_of-private-entries',
            'private'  => 'x_entirely_made_up_of_private_entries',
            'privates' => [qw/entirely made up of private entries/]
        },
        {
            'code'     => 'en-latn-gb-x_entirely_made_up_of-private-entries',
            'private'  => 'x_entirely_made_up_of_private_entries',
            'language' => 'en',
            'script'   => 'latn',
            'region'   => 'gb',
            'privates' => [qw/entirely made up of private entries/]
        },
    );
};
done_testing();

sub _run_regexp_test {
    my (@test_data) = @_;
    my $validator = $CLASS->new( 'cache' => Locale::MaybeMaketext::Cache->new() );
    for (@test_data) {
        my %item    = %{$_};
        my $code    = $item{'code'};
        my %results = $validator->validate($code);
        if ( !$results{'status'} ) {

            # it failed the check - did we expect that?
            if ( defined( $item{'fail'} ) ) {
                is(
                    $results{'reasoning'} || 'undef', $item{'reasoning'} || 'undef',
                    "Code '$code': Failed as expected.",
                    add_diag()
                );
                next;
            }
            fail(
                "Code '$code': Failed to validate (expected to pass): " . ( $results{'reasoning'} || 'no reasoning' ),
                add_diag()
            );

            next;
        }
        if ( defined( $item{'fail'} ) ) {

            # we passed the check, but we were expected to fail.
            fail(
                    "Code '$code': Expected to fail because: "
                  . $item{'fail'}
                  . ' Got: '
                  . join( q{, }, _list_found(%results) ),
                add_diag()
            );
            next;
        }

        my %updated_item = %item;
        if ( defined( $item{'new_code'} ) ) {
            $updated_item{'code'} = $item{'new_code'};
            delete $updated_item{'new_code'};
        }
        my $list_compare_results = _list_compared( { 'matches' => \%results, 'item' => \%updated_item } );
        my %list_compared        = %{$list_compare_results};
        my @errors               = @{ $list_compared{'errors'} };
        my @success              = @{ $list_compared{'success'} };
        if (@errors) {
            for (@success) {
                pass("Code '$code': Partially passed: $_");
            }
            my $receive_keys  = join( ', ', keys(%results) );
            my $expected_keys = join( ', ', keys(%updated_item) );
            fail(
                    "Code '$code' Failed with "
                  . ( scalar @errors )
                  . " errors.\n    Error: "
                  . join( "\n    Error: ", @errors ),
                add_diag( [ "Received keys: $receive_keys", "Expected keys: $expected_keys" ] )
            );
            next;
        }
        pass("Code '$code': Passed");
    }
    return 1;
}

sub _list_compared {
    my ($temp_input) = @_;
    my %input        = %{$temp_input};
    my %matches      = %{ $input{'matches'} };
    my %item         = %{ $input{'item'} };
    my ( @errors, @success );

    if ( !defined( $item{'code'} ) || !defined( $matches{'code'} ) ) {
        croak('Missing code from passed data');
    }
    my $code = ( lc( $item{'code'} =~ tr{-}{_}r ) =~ s/\s//gr );    # normalise the provided code
    if ( $code ne $matches{'code'} ) {
        push @errors, sprintf(
            'Expected code to be "%s" (from "%s"), but received "%s"',
            $code, $item{'code'}, $matches{'code'}
        );
    }
    else {
        push @success, sprintf( '"%s": Matched with value "%s"', 'code', $code );
    }
    for my $cur (
        qw/language extlang script region variant extension private irregular regular variants extensions privates/) {
        my $itemdefined   = defined( $item{$cur} );
        my $regexedefined = defined( $matches{$cur} );
        if ( !$itemdefined && !$regexedefined ) {
            next;
        }

        if ( $itemdefined && !$regexedefined ) {
            if ( ref( $item{$cur} ) eq 'ARRAY' ) {
                push @errors,
                  sprintf( 'Missing "%s". Expected to have array value "%s"', $cur, join( ', ', @{ $item{$cur} } ) );
            }
            else {
                push @errors, sprintf( 'Missing "%s". Expected to have value "%s"', $cur, $item{$cur} );
            }
            next;
        }
        if ( !$itemdefined && $regexedefined ) {
            if ( ref( $matches{$cur} ) eq 'ARRAY' ) {
                push @errors,
                  sprintf( 'Unexpectedly found "%s" with array value "%s"', $cur, join( ', ', @{ $matches{$cur} } ) );

            }
            else {
                push @errors, sprintf( 'Unexpectedly found "%s" with value "%s"', $cur, $matches{$cur} );
            }
            next;
        }
        if ( $cur eq 'variants' || $cur eq 'extensions' || $cur eq 'privates' ) {
            is( $matches{$cur}, $item{$cur}, 'Code: \'' . $matches{'code'} . "': $cur" );
            next;
        }
        if ( $item{$cur} eq $matches{$cur} ) {
            push @success, sprintf( '"%s": Matched with value "%s"', $cur, $item{$cur} );
            next;
        }
        push @errors,
          sprintf(
            '"%s": Mismatched. Expected to have value "%s", but found with value "%s"', $cur,
            $item{$cur},                                                                $matches{$cur}
          );
    }
    my $out = { 'errors' => \@errors, 'success' => \@success };
    return $out;
}

sub _list_found {
    my (%matches) = @_;
    my @found_items = ();
    for my $cur (qw/language extlang script region variant extension private irregular regular/) {
        if ( defined( $matches{$cur} ) ) { push @found_items, "Found $cur set as: " . $matches{$cur}; }
    }
    return @found_items;
}
