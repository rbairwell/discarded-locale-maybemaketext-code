#!perl
## no critic (RegularExpressions::ProhibitComplexRegexes)
use strict;
use warnings;
use vars;
use File::Basename();
use File::Spec();
use lib File::Spec->catdir( File::Basename::dirname( File::Spec->rel2abs(__FILE__) ), q/lib/ );
use Locale::MaybeMaketext::Tests::Base qw/:all/;
use Locale::MaybeMaketext::Tests::Overrider();
use feature qw/signatures/;
no warnings qw/experimental::signatures/;
use Test2::Tools::Target 'Locale::MaybeMaketext::LanguageFinder';
use Locale::MaybeMaketext::Cache();
use Locale::MaybeMaketext::LanguageCodeValidator();
use Locale::MaybeMaketext::Alternatives();
use Locale::MaybeMaketext::Supers();
use Locale::MaybeMaketext::PackageLoader();
use Locale::MaybeMaketext::Tests::LanguageFinderProcessorTests();
my @callstack;

subtest_buffered( 'set_configuration: Check Unrecognised',         sub() { check_unrecognised(); } );
subtest_buffered( 'set_configuration: Check keywords',             sub() { check_keywords(); } );
subtest_buffered( 'set_configuration: Check basic languages',      sub() { check_basic_languages(); } );
subtest_buffered( 'set_configuration: Check array languages',      sub() { check_array_languages(); } );
subtest_buffered( 'set_configuration: Check duplicated languages', sub() { check_duplicated_languages(); } );

subtest_buffered( 'set_configuration: Check packages', sub() { check_packages(); } );
subtest_buffered( 'set_configuration: With mocks',     sub() { check_withmocks(); } );

done_testing();

sub _get_sut() {
    my $cache     = Locale::MaybeMaketext::Cache->new();
    my $validator = Locale::MaybeMaketext::LanguageCodeValidator->new( 'cache' => $cache );
    return $CLASS->new(
        'language_code_validator' => $validator,
        'alternatives'            => Locale::MaybeMaketext::Alternatives->new( 'cache' => $cache ),
        'supers'                  => Locale::MaybeMaketext::Supers->new( 'language_code_validator' => $validator ),
        'package_loader'          => Locale::MaybeMaketext::PackageLoader->new( 'cache' => $cache ),
        'cache'                   => $cache,
    );
}

sub check_unrecognised() {
    my @settings;
    my $sut = _get_sut();
    like(
        dies {
            $sut->set_configuration(qw/previous jeFf die/);
        },
        qr/\AInvalid looking language passed: "jeFf"/,
        'set_configuration: unrecognised: Invalid looking language'
    );
    like(
        dies {
            $sut->set_configuration(qw/previous je!ff die/);
        },
        qr/\AUnrecognised language configuration setting: "je!ff"/,
        'set_configuration: unrecognised: Unrecognised string'
    );
    like(
        dies {
            $sut->set_configuration(qw/previous die supers/);
        },
        qr/\AInvalid position of keyword "die": it must be in the last position if used \(found in position 2 of 3\)/,
        'set_configuration: unrecognised: die in wrong position'
    );
    my $coderef = sub { };
    like(
        dies {
            $sut->set_configuration( 'en', $coderef, 'en-US' );
        },
        qr/\AUnrecognised language configuration setting: "\[Type CODE\]" \(found in position 2 of 3\)/,
        'set_configuration: unrecognised: Coderef sent'
    );
    like(
        dies {
            $sut->set_configuration( 'en', [qw/de invalidlang/] );
        },
        qr/\AInvalid looking language code passed in array: "invalidlang/,
        'set_configuration: unrecognised: Unrecognised language in array'
    );
    like(
        dies {
            $sut->set_configuration( \() );
        },
        qr/\Aset_configuration: Invalid call: Must be passed a list of actions/,
        'set_configuration: unrecognised: Empty array'
    );
    @settings = qw/provided en-gb az-Arab-IR alternatives supers previous en-us-latn die/;
    like(
        dies {
            $sut->set_configuration(@settings);
        },
        qr/\AInvalid looking language passed: "en-us-latn" - Failed regular expression match \(found in position 7 of 8\)/,
        'set_configuration: unrecognised: Should reject bad languages (in this case, the script setting)'
    );
    @settings = qw/provided en-gb az-Arab-IR alternatives supers previous en-latn-us die/;
    my @expected_settings = qw/provided en_gb az_arab_ir alternatives supers previous en_latn_us die/;
    is(
        [ $sut->set_configuration(@settings) ],
        \@expected_settings,
        'set_configuration: unrecognised: Full test should return what is set'
    );
    return 1;
}

sub check_duplicated_languages() {
    my @settings;
    my $sut = _get_sut();
    like(
        dies {
            $sut->set_configuration(qw/en-gb en-gb/);
        },
        qr/\ADuplicate language passed: "en-gb" \(found in position 2 of 2\) already set in position 1/,
        'check_duplicated_languages: Duplicated languages should be flagged'
    );
    like(
        dies {
            $sut->set_configuration(qw/en-gb en-us empty en-gb en-us en-gb/);
        },
        qr/\ADuplicate language passed: "en-gb" \(found in position 6 of 6\) already set in position 4/,
        'check_duplicated_languages: Duplicated languages should be flagged - but only after emptying'
    );
    return 1;
}

sub check_basic_languages() {
    my @settings;
    my $sut = _get_sut();
    @settings = qw/en-gb FR pt-es/;

    # now we've checked, lets set what we are expecting
    @settings = qw/en_gb fr pt_es/;
    is(
        [ $sut->set_configuration(@settings) ], \@settings,
        'set_basic_languages: Valid languages should be accepted'
    );

    # here we have to pass the "speedy check" (which is just "is string letters numbers and underscores")
    # before we actually get to the language check.
    # There will only be one returned as it bails out on the first invalid language.
    like(
        dies {
            $sut->set_configuration(qw/en-gb FR invalidlang  pt-es franky 12 ko cd-es-ea-es-es-es de/);
        },
        qr/\AInvalid looking language passed: "invalidlang"/,
        'set_basic_languages: Invalid languages should be rejected'
    );
    return 1;
}

sub check_array_languages() {
    my @settings;
    @settings = qw/en_nz de_de es/;

    my $sut = _get_sut();
    is(
        [ $sut->set_configuration( [qw/en-NZ de-DE es/] ) ], \@settings,
        'set_array_languages: Valid languages should be accepted (as array)'
    );

    # here we have to pass the "speedy check" (which is just "is string letters numbers and underscores")
    # before we actually get to the language check.
    # Multiple should be returned as we are testing an array
    like(
        dies {
            $sut->set_configuration( [qw/en-gb FR arraylanginvalid  pt-es frank3ly 12 ko cd-es-ea-es-es-es de/] );
        },
        qr/\AInvalid looking language code passed in array: "arraylanginvalid", "frank3ly", "12", "cd-es-ea-es-es-es"/,
        'set_array_languages: Invalid languages (as array) should be rejected'
    );
    return 1;
}

sub check_keywords() {
    my @settings = qw/provided supers alternatives previous empty die/;

    my $sut = _get_sut();
    is(
        [ $sut->set_configuration(@settings) ], \@settings,
        'set_configuration: keywords: Should match'
    );
    @settings = qw/previous die/;
    is(
        [ $sut->set_configuration(@settings) ], \@settings,
        'set_configuration: keywords: Should return what is set (ensuring "previous" is accepted)'
    );
    @settings = qw/previous die empty/;
    like(
        dies {
            $sut->set_configuration(@settings);
        },
        qr/\AInvalid position of keyword "die": it must be in the last position if used \(found in position 2 of 3\)/,
        'set_configuration: keywords: : Ensure "die" is the last position if used'
    );
    return 1;
}

sub check_packages() {
    my ( $dies, $original_dies, $expected_message, $warnings_ref );
    my $sut      = _get_sut();
    my %packages = get_invalid_detectors('loading');
    for my $package ( sort keys(%packages) ) {
        my %data = @{ $packages{$package} };
        $original_dies = dies {
            $sut->set_configuration($package);
        } || 'NO ERROR';
        $dies             = standardise_die_line($original_dies);
        $expected_message = sprintf( 'Detector %s (default): %s', $package, $data{'dies'} );
        starts_with(
            $dies,               $expected_message, sprintf( 'check_packages: Checking %s %s', 'loading', $package ),
            'Original dies',     $original_dies,
            'Standardised dies', $dies,
            'Expected dies',     $expected_message
        );
    }
    %packages = get_invalid_detectors('general');
    for my $package ( sort keys(%packages) ) {
        my %data = @{ $packages{$package} };
        if ( !defined( $data{'dies'} ) ) {
            next;
        }
        $original_dies = dies {
            $warnings_ref = warnings {
                $sut->set_configuration($package);
            };
        } || 'NO ERROR';
        $dies             = standardise_die_line($original_dies);
        $expected_message = sprintf( 'Detector %s (default): %s', $package, $data{'dies'} );
        starts_with(
            $dies,               $expected_message, sprintf( 'check_packages: Checking %s %s', 'general', $package ),
            'Original dies',     $original_dies,
            'Standardised dies', $dies,
            'Expected dies',     $expected_message
        );
    }

    my $package;

    # now fake that we have a module already loaded
    local $INC{'Bairwell/MaybeMaketext/Tests/LanguageFinderSetConfiguration/AlreadyLoaded.pm'} = 'invalid path';
    $package = 'Locale::MaybeMaketext::Tests::LanguageFinderSetConfiguration::AlreadyLoaded';
    $dies    = dies {
        $sut->set_configuration($package);
    } || 'NO ERROR';
    $dies             = standardise_die_line($dies);
    $expected_message = sprintf(
        'Detector %s (default): Checking detector: Previous attempt to load "%s" failed due to "No symbols found" after: %s',
        $package, $package, 'loaded by filesystem from "invalid path"'
    );
    starts_with(
        $dies,      $expected_message, 'check_packages: Checking if we have a module already loaded',
        'Original', $dies
    );

    # and fake that we tried to load something.

    local $INC{'Bairwell/MaybeMaketext/Tests/LanguageFinderSetConfiguration/LoadFailed.pm'} = undef;
    $package = 'Locale::MaybeMaketext::Tests::LanguageFinderSetConfiguration::LoadFailed';
    $dies    = dies {
        $sut->set_configuration($package);
    } || 'NO ERROR';
    $dies             = standardise_die_line($dies);
    $expected_message = sprintf(
        'Detector %s (default): Checking detector: Previous attempt to load "%s" failed due to "No symbols found" after: %s',
        $package, $package, 'raised error/warning on load'
    );
    starts_with(
        $dies,      $expected_message, 'check_packages: Checking if we have a module already failed to load',
        'Original', $dies
    );

    # check it actually accepts what we want
    my @settings = qw/Locale::MaybeMaketext::Tests::InvalidDetectors::DetectorDummy/;
    is(
        [ $sut->set_configuration(@settings) ], \@settings,
        'check_packages: DetectorDummy: Valid packages should be accepted'
    );

    # warn if ! is set in package name and package does not exist.
    $warnings_ref = warnings {
        $sut->set_configuration(
            qw/previous
              !Locale::MaybeMaketext::Tests::LanguageFinderSetConfiguration::InvalidExclamation
              ~Locale::MaybeMaketext::Tests::LanguageFinderSetConfiguration::MaybeTryThis/
        );
    };
    is(
        1, scalar( @{$warnings_ref} ),
        'check_packages: Expected exactly one warning from tilde/exclamation mark test'
    );
    my $warning = standardise_die_line( @{$warnings_ref}[0] );
    $package          = 'Locale::MaybeMaketext::Tests::LanguageFinderSetConfiguration::InvalidExclamation';
    $expected_message = sprintf(
        'Detector %s (warn-errors): Checking detector: Failed to load "%s" because: "Can\'t locate',
        $package, $package
    );
    starts_with(
        $warning,   $expected_message, 'check_packages: Only exclamation marked prefixed packages should raise warning',
        'Original', $warning
    );
    return 1;
}

sub _setup_mocks ($overrider) {
    $overrider->override(
        'Locale::MaybeMaketext::LanguageCodeValidator::validate',
        sub ( $class, $langcode ) {
            push @callstack, "validate_language:$langcode";
            return ( 'status' => 0, 'reasoning' => 'language mocked' );
        }
    );
    $overrider->override(
        'Locale::MaybeMaketext::PackageLoader::is_valid_package_name',
        sub ( $class, $package_name ) {
            push @callstack, "valid_package:$package_name";
            return 0;
        }
    );
    $overrider->wrap(
        'Locale::MaybeMaketext::PackageLoader::attempt_package_load',
        sub ( $original_sub, $class, $package_name ) {
            if ( $package_name eq q/Locale::MaybeMaketext::LanguageCodeValidator/ ) {
                return $original_sub->( $class, $package_name );
            }
            push @callstack, "attempt_load:$package_name";
            return ( 'status' => 0, 'reasoning' => "loader mocked for $package_name" );
        }
    );
    $overrider->wrap(
        'Locale::MaybeMaketext::Cache::set_cache',
        sub ( $original_sub, $class, $method, %data ) {
            my %results = $original_sub->( $class, $method, %data );
            push @callstack, "set_cache:[$method]";
            return %results;
        }
    );
    $overrider->wrap(
        'Locale::MaybeMaketext::Cache::get_cache',
        sub ( $original_sub, $class, $method ) {
            if (wantarray) {
                my %out = $original_sub->( $class, $method );
                if (%out) {
                    push @callstack, "get_cache:[$method]";
                }
                else {
                    push @callstack, "get_cache:[$method](not found)";
                }
                return %out;
            }
            my $out = $original_sub->( $class, $method );
            push @callstack, "get_cache:[$method](bool:" . ( $out ? 'found' : 'missing' ) . q{)};
            return $out;
        }
    );
    return 1;
}

sub check_withmocks() {
    my $overrider = Locale::MaybeMaketext::Tests::Overrider->new();
    _setup_mocks($overrider);

    my $sut = _get_sut();
    like(
        dies {
            $sut->set_configuration(qw/provided supers en-gb die/);
        },
        qr/\AInvalid looking language passed: "en-gb" - language mocked \(found in position 3 of 4\)/,
        'check_withmocks: with mocks: Language should not be recognised by mock',
        @callstack
    );
    is(
        join( q{,}, @callstack ), 'validate_language:en_gb',
        'check_withmocks: with mocks: Language should not be recognised by mock (checking call stack)',
        @callstack
    );

    # check reject on invalid name
    @callstack = ();
    my $dies = dies {
        $sut->set_configuration(qw/provided couldbeapackage::name die/);
    } || 'FAILES TO DIE';
    $dies = standardise_die_line($dies);
    my $expected_message = sprintf(
        'Detector %s (default): Checking detector: Invalid package name %s',
        'couldbeapackage::name', 'couldbeapackage::name'
    );
    starts_with(
        $dies,       $expected_message, 'check_withmocks: Packages names should be rejected by mock', 'Original', $dies,
        'Callstack', @callstack
    );

    my @expected_stack = (
        'get_cache:[_is_detector.c.couldbeapackage::name](bool:missing)',
        'valid_package:couldbeapackage::name',
        'set_cache:[_is_detector.c.couldbeapackage::name]',
    );
    my $joined_callstack = join( q{, }, @callstack );
    my $starts           = join( q{, }, @expected_stack );
    like(
        $joined_callstack, $starts,
        'set_configuration: with mocks: invalid name: Expected call stack to match',
        @callstack
    );

    # cache check
    @callstack = ();
    like(
        dies {
            $sut->set_configuration(qw/provided couldbeapackage::name die/);
        },
        qr/Checking detector: Invalid package name couldbeapackage::name at/,
        'set_configuration: with mocks: Packages names should be rejected by mock (cache check)',
        @callstack
    );
    $joined_callstack = join( q{, }, @callstack );
    @expected_stack   = (
        'get_cache:[_is_detector.c.couldbeapackage::name](bool:found)',
        'get_cache:[_is_detector.c.couldbeapackage::name]'
    );
    $starts = join( q{, }, @expected_stack );
    like(
        $joined_callstack, $starts,
        'set_configuration: with mocks: invalid name: Expected call stack to match (cached)'
    );

    # check reject on unable to load
    @callstack = ();
    $overrider->override(
        'Locale::MaybeMaketext::PackageLoader::is_valid_package_name',
        sub ( $class, $package_name ) {
            push @callstack, "valid_package:$package_name";
            return 1;
        }
    );
    like(
        dies {
            $sut->set_configuration(qw/provided anotherpotential::package::name die/);
        },
        qr/Checking detector: loader mocked for anotherpotential::package::name at/,
        'set_configuration: with mocks: Loader should be rejected'
    );
    $joined_callstack = join( q{, }, @callstack );
    if (   $joined_callstack !~ /, \Qvalid_package:anotherpotential::package::name\E/
        || $joined_callstack !~ /, \Qattempt_load:anotherpotential::package::name\E/ ) {
        fail('set_configuration: with mocks: Loader did not make the required calls');
    }

    # check call to detect subroutine

    $overrider->override(
        'Locale::MaybeMaketext::PackageLoader::attempt_package_load',
        sub ( $class, $package_name ) {
            push @callstack, "attempt_load:$package_name";
            return ( 'status' => 1, 'reasoning' => "loader mocked for $package_name" );
        }
    );

    # can returning undef
    @callstack = ();
    $overrider->override(
        'TesterLanguageFinder::Tester1::can',
        sub ( $class, $method ) {
            push @callstack, "tester1:can:$class+$method";
            return;
        }
    );
    my @settings = qw/provided TesterLanguageFinder::Tester1 die/;
    $dies = dies {
        $sut->set_configuration(@settings);
    } || 'DID NOT DIE';
    $expected_message =
      'Detector TesterLanguageFinder::Tester1 (default): Checking detector: No "detect" subroutine found';
    starts_with(
        $dies, $expected_message,
        'set_configuration: with mocks: Can returns undef', 'Original', $dies
    );
    $joined_callstack = join( q{, }, @callstack );
    if (   $joined_callstack !~ /, \Qvalid_package:TesterLanguageFinder::Tester1\E/
        || $joined_callstack !~ /, \Qattempt_load:TesterLanguageFinder::Tester1\E/
        || $joined_callstack !~ /, \Qtester1:can:TesterLanguageFinder::Tester1+detect\E/ ) {
        fail('set_configuration: with mocks: can returning undef: Checking callstack');
    }

    # can returning correctly
    @callstack = ();
    $overrider->override(
        'TesterLanguageFinder::Tester2::can',
        sub ( $class, $method ) {
            push @callstack, "tester2:can:$class+$method";
            return \sub() { };
        }
    );
    @settings = qw/provided TesterLanguageFinder::Tester2 die/;
    is(
        [ $sut->set_configuration(@settings) ],
        [@settings],
        'set_configuration: with mocks: can returning correctly'
    );
    $joined_callstack = join( q{, }, @callstack );
    if (   $joined_callstack !~ /, \Qvalid_package:TesterLanguageFinder::Tester2\E/
        || $joined_callstack !~ /, \Qattempt_load:TesterLanguageFinder::Tester2\E/
        || $joined_callstack !~ /, \Qtester2:can:TesterLanguageFinder::Tester2+detect\E/ ) {
        fail( 'set_configuration: can returning correctly: Checking callstack', @callstack );
    }

    # check call to detect subroutine if it errors
    @callstack = ();
    $overrider->override(
        'TesterLanguageFinder::Tester3::can',
        sub ( $class, $method ) {
            push @callstack, "tester3:can:$class+$method";
            die('Testing error');    ## no critic (ErrorHandling::RequireCarping)
        }
    );
    @settings = qw/provided TesterLanguageFinder::Tester3 die/;
    $dies     = dies {
        $sut->set_configuration(@settings);
    } || 'DID NOT DIE';
    $expected_message =
      'Detector TesterLanguageFinder::Tester3 (default): Checking detector: When subroutine "detect" was checked, error message was received: "Testing error';
    starts_with(
        $dies, $expected_message,
        'set_configuration: with mocks: Can returns error', 'Original', $dies
    );

    $joined_callstack = join( q{, }, @callstack );
    if (   $joined_callstack !~ /, \Qvalid_package:TesterLanguageFinder::Tester3\E/
        || $joined_callstack !~ /, \Qattempt_load:TesterLanguageFinder::Tester3\E/
        || $joined_callstack !~ /, \Qtester3:can:TesterLanguageFinder::Tester3+detect\E/ ) {
        fail('set_configuration: can returns error: Checking callstack');
    }

    # now this time, with tilde (maybe use)
    @callstack = ('start');
    @settings  = qw/provided ~TesterLanguageFinder::Tester3 die/;
    is(
        [ $sut->set_configuration(@settings) ],
        [@settings],
        'set_configuration: with mocks: Can returns error on tilde'
    );
    $joined_callstack = join( q{, }, @callstack );
    my $expected_callstack = join(
        q{, },
        'start',
        'get_cache:[_is_detector.~.TesterLanguageFinder::Tester3](bool:missing)',
        'valid_package:TesterLanguageFinder::Tester3',
        'attempt_load:TesterLanguageFinder::Tester3',
        'tester3:can:TesterLanguageFinder::Tester3+detect',
        'set_cache:[_is_detector.~.TesterLanguageFinder::Tester3]'
    );
    is(
        $joined_callstack, $expected_callstack, 'set_configuration: can returns error on tilde: Checking callstack',
        @callstack
    );

    # now this time, with exclamatioin (raise warning use)
    @callstack = ('start');
    @settings  = qw/provided !TesterLanguageFinder::Tester3 die/;
    my @config;
    my $warnings_ref = warnings {
        @config = $sut->set_configuration(@settings);
    };
    is(
        [@config],
        [@settings],
        'set_configuration: with mocks: Can returns error on exclamation'
    );
    my @warnings = @{$warnings_ref};
    is(
        scalar(@warnings),
        1,
        'set_configuration: with mocks: Can returns error on exclamation: Expected a single warning',
        @warnings
    );
    $expected_message =
      'Detector TesterLanguageFinder::Tester3 (warn-errors): Checking detector: When subroutine "detect" was checked, error message was received: "Testing error at';
    starts_with(
        $warnings[0],
        $expected_message,
        'set_configuration: with mocks: Can returns error on exclamation: expected warning',
        $warnings[0]
    );

    $joined_callstack   = join( q{, }, @callstack );
    $expected_callstack = join(
        q{, },
        'start',
        'get_cache:[_is_detector.!.TesterLanguageFinder::Tester3](bool:missing)',
        'valid_package:TesterLanguageFinder::Tester3',
        'attempt_load:TesterLanguageFinder::Tester3',
        'tester3:can:TesterLanguageFinder::Tester3+detect',
        'set_cache:[_is_detector.!.TesterLanguageFinder::Tester3]'
    );
    is(
        $joined_callstack, $expected_callstack,
        'set_configuration: can returns error on exclamation: Checking callstack',
        @callstack
    );
    $overrider->reset_all();
    return 1;
}

sub get_invalid_detectors ( $specifics = undef ) {
    return Locale::MaybeMaketext::Tests::LanguageFinderProcessorTests::get_invalid_detectors($specifics);
}
