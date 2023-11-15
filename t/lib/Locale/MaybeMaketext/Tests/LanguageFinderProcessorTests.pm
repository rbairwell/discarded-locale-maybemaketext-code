package Locale::MaybeMaketext::Tests::LanguageFinderProcessorTests;

use strict;
use warnings;
use vars;
use feature qw/signatures/;
no if $] >= 5.032, q|feature|, qw/indirect/;
no warnings qw/experimental::signatures/;

use Locale::MaybeMaketext::Tests::Base qw/:all/;
use Carp                                 qw/carp croak/;
use Locale::MaybeMaketext::LanguageFinder();
use Locale::MaybeMaketext::Cache();
use Locale::MaybeMaketext::LanguageCodeValidator();
use Locale::MaybeMaketext::Alternatives();
use Locale::MaybeMaketext::Supers();
use Locale::MaybeMaketext::PackageLoader();
use Locale::MaybeMaketext::LanguageFinderProcessor();

my $pkg_obj_languagefinder;
my $pkg_obj_cache;
my $pkg_obj_validator;
my $pkg_obj_alternatives;
my $pkg_obj_supers;
my $pkg_obj_loader;
my $pkg_obj_fake_callback;
my @pkg_return_field_list =
  qw/configuration encountered_languages get_multiple invalid_languages matched_languages previous_languages provided_languages reasoning rejected_languages/;
my @pkg_allow_starts_with = qw/dies reasoning warnings/;
my @pkg_scalar_field_list = qw/dies get_multiple/;
my @pkg_injected_returns  = qw/callbacks dies warnings/;
my @pkg_internal_fields   = qw/compare_messages_starts_with message standardise_messages hasnew/;
my ( $pkg_name,           $pkg_warnings_ref, $pkg_dies, %pkg_allow_starts_with_lookup, %pkg_scalar_field_list_lookup );
my ( %pkg_options,        %pkg_got );
my ( @pkg_callback_codes, @pkg_expected_keys, @pkg_got_keys );

my %detector_list;

sub _setup_dependencies() {
    $pkg_obj_cache         //= Locale::MaybeMaketext::Cache->new();
    $pkg_obj_validator     //= Locale::MaybeMaketext::LanguageCodeValidator->new( 'cache' => $pkg_obj_cache );
    $pkg_obj_alternatives  //= Locale::MaybeMaketext::Alternatives->new( 'cache' => $pkg_obj_cache );
    $pkg_obj_supers        //= Locale::MaybeMaketext::Supers->new( 'language_code_validator' => $pkg_obj_validator ),;
    $pkg_obj_loader        //= Locale::MaybeMaketext::PackageLoader->new( 'cache' => $pkg_obj_cache );
    $pkg_obj_fake_callback //= sub ($langcode) {
        push @pkg_callback_codes, sprintf( 'Langcode %d: "%s"', scalar(@pkg_callback_codes), $langcode );
        return;
    };
    return 1;
}

sub run_processor_directly ( $passed_name, %option_list ) {
    _setup_runner( $passed_name, %option_list );
    $pkg_dies = dies {
        $pkg_warnings_ref = warnings {
            %pkg_got = Locale::MaybeMaketext::LanguageFinderProcessor->run(
                'language_code_validator' => $pkg_obj_validator,
                'alternatives'            => $pkg_obj_alternatives,
                'supers'                  => $pkg_obj_supers,
                'package_loader'          => $pkg_obj_loader,
                'cache'                   => $pkg_obj_cache,
                'configuration'           => \@{ $pkg_options{'configuration'} },
                'callback'                => $pkg_obj_fake_callback,
                'previous_languages'      => $pkg_options{'previous_languages'} || undef,
                'provided_languages'      => $pkg_options{'previous_languages'} || undef,
                'get_multiple'            => $pkg_options{'get_multiple'},
            );
        };
    };
    return _finish_runner();
}

sub run_finder ( $passed_name, %option_list ) {
    _setup_runner( $passed_name, %option_list );
    $pkg_obj_languagefinder //= Locale::MaybeMaketext::LanguageFinder->new(
        'language_code_validator' => $pkg_obj_validator,
        'alternatives'            => $pkg_obj_alternatives,
        'supers'                  => $pkg_obj_supers,
        'package_loader'          => $pkg_obj_loader,
        'cache'                   => $pkg_obj_cache,
    );
    $pkg_dies = dies {
        $pkg_warnings_ref = warnings {
            %pkg_got = $pkg_obj_languagefinder->finder(
                'configuration'      => \@{ $pkg_options{'configuration'} },
                'callback'           => $pkg_obj_fake_callback,
                'previous_languages' => $pkg_options{'previous_languages'} || undef,
                'provided_languages' => $pkg_options{'previous_languages'} || undef,
                'get_multiple'       => $pkg_options{'get_multiple'},
            );
        };
    };
    return _finish_runner();
}

sub _setup_runner ( $passed_name, %option_list ) {
    _setup_dependencies();

    #reset everything
    $pkg_name         = undef;
    $pkg_warnings_ref = undef;
    $pkg_dies         = undef;

    %pkg_options = ();
    %pkg_got     = ();

    @pkg_callback_codes = ();
    @pkg_got_keys       = ();
    @pkg_expected_keys  = ();

    %pkg_allow_starts_with_lookup = map { $_ => 1 } @pkg_allow_starts_with;
    %pkg_scalar_field_list_lookup = map { $_ => 1 } @pkg_scalar_field_list;

    # now let's set it all up
    $pkg_name    = $passed_name;
    %pkg_options = %option_list;
    for (qw/configuration reasoning/) {
        if ( !defined( $pkg_options{$_} ) ) {
            fail( sprintf( '%s: Missing option "%s"', $pkg_name, $_ ) );
        }
        my @temp = @{ $pkg_options{$_} };
        if ( !@temp ) {
            fail( sprintf( '%s: Missing/empty option "%s"', $pkg_name, $_ ) );
        }
    }
    if ( !exists( $pkg_options{'get_multiple'} ) ) {
        $pkg_options{'get_multiple'} = 0;
    }

    _filter_keys(
        [ @pkg_return_field_list, @pkg_internal_fields, @pkg_injected_returns ],
        [ keys(%pkg_options) ],
        'Passed options'
    );

    return 1;
}

sub _filter_keys ( $allowed_ref, $provided_ref, $reason = undef ) {
    my @allowed  = @{$allowed_ref};
    my @provided = @{$provided_ref};
    my %hash     = map { $_ => 1 } @allowed;
    my @out;
    for my $key (@provided) {
        if ( !exists( $hash{$key} ) ) {
            if ($reason) {
                fail( sprintf( '%s: Unrecognised %s: %s', $pkg_name, $reason, $key ) );
                return [];
            }
        }
        else {
            push @out, $key;
        }
    }
    return @out;
}

sub _finish_runner() {
    @pkg_got_keys = ();
    if ( $pkg_dies || $pkg_options{'dies'} ) {
        if ( scalar(%pkg_got) > 0 ) {
            fail( sprintf( '%s: Should have died, instead return values received', $pkg_name ), %pkg_got );
        }
        @pkg_expected_keys = _filter_keys( [ 'dies', @pkg_injected_returns ], [ keys(%pkg_options) ] );
    }
    else {
        note('Expected to run');

        # check that the right fields were returned
        @pkg_got_keys = _filter_keys( [@pkg_return_field_list], [ keys(%pkg_got) ], 'return value' );
        @pkg_expected_keys =
          _filter_keys( [ @pkg_return_field_list, @pkg_injected_returns ], [ keys(%pkg_options) ] );
    }

    $pkg_got{'warnings'}  = $pkg_warnings_ref;
    $pkg_got{'callbacks'} = \@pkg_callback_codes;
    $pkg_got{'dies'}      = $pkg_dies;
    if ( scalar(@pkg_expected_keys) < 1 ) {
        croak('No expected keys');
    }
    for my $key (@pkg_expected_keys) {

        # handle empty arrays being compared to undef.
        if ( !_check_both_set($key) ) {
            next;
        }
        if ( $pkg_scalar_field_list_lookup{$key} ) {
            _extract_check_scalar($key);
            next;
        }
        _extract_check_array($key);
    }
    return 1;
}

sub _check_both_set ($key) {
    my $option_defined = _is_value_actually_set( $key, %pkg_options );
    my $got_defined    = _is_value_actually_set( $key, %pkg_got );
    if ( $option_defined eq '1' && $got_defined ne '1' ) {
        fail(
            sprintf( '%s: Expected return value "%s" to be set - but was not set', $pkg_name, $key ),
            'Expected contents ref',
            ( ref( $pkg_options{$key} ) ? ref( $pkg_options{$key} ) : 'scalar:' . $pkg_options{$key} ),
            'Expected contents', $pkg_options{$key},
            'Is got defined?',
            (
                $got_defined eq '1'
                ? ( 'yes:' . ref( $pkg_got{$key} ) ? ref( $pkg_got{$key} ) : 'scalar' )
                : $got_defined
            ),
            'Got keys', join( q{, }, sort(@pkg_got_keys) ),
            'Expected keys',
            join( q{, }, sort(@pkg_expected_keys) ),
            'All received data',
            %pkg_got
        );
        return 0;
    }
    if ( $option_defined ne '1' && $got_defined eq '1' ) {
        fail(
            sprintf( '%s: Did not expect return value "%s" to be set - but it was set', $pkg_name, $key ),
            'Got contents ref',
            ( ref( $pkg_got{$key} ) ? ref( $pkg_got{$key} ) : 'scalar:' . $pkg_got{$key} ),

            'Is expected defined?',
            (
                $option_defined eq '1'
                ? ( 'yes:' . ref( $pkg_options{$key} ) ? ref( $pkg_options{$key} ) : 'scalar' )
                : $option_defined
            ),
            'Got contents', $pkg_got{$key},
            'Got keys',     join( q{, }, sort(@pkg_got_keys) ),
            'Expected keys',
            join( q{, }, sort(@pkg_expected_keys) )
        );
        return 0;
    }
    if ( $option_defined ne '1' && $got_defined ne '1' ) {
        if ( $option_defined eq $got_defined ) {
            pass( sprintf( '%s: %s both set identically to %s', $pkg_name, $key, $got_defined ) );
        }
        else {
            pass(
                sprintf(
                    '%s: %s both unset/empty (got %s, expected %s)', $pkg_name, $key, $got_defined, $option_defined
                )
            );
            carp(
                sprintf(
                    '%s: Check field "%s" as received data that was "%s", but expected from test "%s"', $pkg_name,
                    $key, $got_defined, $option_defined
                )
            );
        }
        return 0;
    }
    return 1;
}

sub _is_value_actually_set ( $key, %data ) {
    if ( !exists( $data{$key} ) ) {
        return 'not exist';
    }
    if ( !defined( $data{$key} ) ) {
        return 'not defined';
    }
    if ( ref( $data{$key} ) eq 'ARRAY' ) {
        if ( scalar( @{ $data{$key} } ) == 0 ) {
            return 'empty array';
        }
    }
    return '1';
}

sub _extract_check_scalar ($key) {
    my $got_text = $pkg_got{$key};
    if ( defined( $pkg_options{'standardise_messages'} ) ) {
        $got_text = standardise_die_line($got_text);
    }
    if ( _allow_starts_with($key) ) {
        starts_with(
            $got_text,
            $pkg_options{$key},
            sprintf( '%s: %s should match start', $pkg_name, $key ),
            ( 'Got', $got_text, 'Original', $pkg_got{$key}, 'Expected', $pkg_options{$key} )
        );
        return 1;
    }
    is(
        $got_text, $pkg_options{$key}, sprintf( '%s: %s should match', $pkg_name, $key ),
        ( 'Got', $got_text, 'Original', $pkg_got{$key}, 'Expected', $pkg_options{$key} )
    );
    return 1;
}

sub _allow_starts_with ($key) {
    if ( $pkg_options{'compare_messages_starts_with'} || 0 ) {
        if ( $pkg_allow_starts_with_lookup{$key} ) {
            return 1;
        }
    }
    return 0;
}

sub _extract_check_array ($key) {
    my ( @expected_key, @got_key );
    if ( defined( $pkg_got{$key} ) ) {
        if ( ref( $pkg_got{$key} ) ne 'ARRAY' ) {
            fail(
                sprintf(
                    'Expected %s to return data with a key of %s which is an array, but instead got: %s',
                    $pkg_name, $key,
                    defined( $pkg_got{$key} ) ? ( ref( $pkg_got{$key} ) || 'scalar:' . $pkg_got{$key} ) : 'undefined'
                )
            );
        }
        @got_key = @{ $pkg_got{$key} };
    }
    if ( defined( $pkg_options{$key} ) ) {
        if ( ref( $pkg_options{$key} ) ne 'ARRAY' ) {
            fail(
                sprintf(
                    'Expected %s to have a configuration of %s as an array, but instead got: %s',
                    $pkg_name, $key,
                    defined( $pkg_options{$key} )
                    ? ( ref( $pkg_options{$key} ) || 'scalar:' . $pkg_options{$key} )
                    : 'undefined'
                )
            );
        }
        @expected_key = @{ $pkg_options{$key} };
    }
    if ( !@expected_key && !@got_key ) {
        pass( sprintf( '%s: %s Both arrays are empty', $pkg_name, $key ) );
        return 1;
    }
    if ( defined( $pkg_options{'standardise_messages'} ) ) {
        @got_key = _standardise_messages(@got_key);
    }
    if ( _allow_starts_with($key) ) {
        _compare_messages_starts_with(
            $pkg_name, $key, \@got_key, \@expected_key,
            ( 'Original', $pkg_got{$key} )
        );
        return 1;
    }
    is(
        \@got_key, \@expected_key, sprintf( '%s: %s should match', $pkg_name, $key ),
        ( 'Original', $pkg_got{$key} )
    );
    return 1;
}

sub _standardise_messages (@messages) {
    my @output;
    for my $line (@messages) {
        push @output, standardise_die_line($line);
    }
    return @output;
}

sub _compare_messages_starts_with ( $name, $field, $gotref, $expectedref, @diag ) {
    my @got      = @{$gotref};
    my @expected = @{$expectedref};
    my @shortened_gots;
    for my $index ( 0 ... $#got ) {
        if ( defined( $expected[$index] ) ) {
            push @shortened_gots, substr( $got[$index], 0, length( $expected[$index] ) );
        }
        else {
            push @shortened_gots, $got[$index];
        }
    }
    is(
        \@shortened_gots, \@expected, sprintf( '%s: Checking %s should match start', $name, $field ),
        'Got', \@got, 'Expected', \@expected, @diag
    );
    return 1;
}

sub get_working_detectors() {
    my %tests = (
        'Locale::MaybeMaketext::Tests::WorkingDetectors::WorkingReturnLanguagesUndef' => [
            'matched_languages'     => [],
            'encountered_languages' => [],
            'invalid_languages'     => [],
            'reasoning'             => [
                '>>> Detector _!PKG!_ (default): Starting detector',
                '    Detector _!PKG!_ (default): Package loaded',
                '    Detector _!PKG!_ (default): Reasoning: This is a undef_languages_!NEW!_ test',
                '    Detector _!PKG!_ (default): No invalid languages returned internally by detector',
                '<<< Detector _!PKG!_ (default): No languages returned',
                'Callback: Skipping as no valid languages',
                'Failed to find any language settings/configurations accepted by the callback',
            ],
        ],
        'Locale::MaybeMaketext::Tests::WorkingDetectors::WorkingResults' => [
            'rejected_languages'    => [qw/fr_fr en_nz en_us/],
            'encountered_languages' => [qw/fr_fr en_nz en_us/],
            'invalid_languages'     => [qw/i-default gc qk_kng ld_sd/],
            'callbacks'             => [ 'Langcode 0: "fr_fr"', 'Langcode 1: "en_nz"', 'Langcode 2: "en_us"' ],
            'reasoning'             => [
                '>>> Detector _!PKG!_ (default): Starting detector',
                '    Detector _!PKG!_ (default): Package loaded',
                '    Detector _!PKG!_ (default): Reasoning: Got working results _!NEW!_',
                '    Detector _!PKG!_ (default): Reasoning: Should have 3 success, 4 fails and 2 messages',
                '    Detector _!PKG!_ (default): Found 4 invalid languages during detection: i-default, gc, qk_kng, ld_sd',
                '    Detector _!PKG!_ (default): Returned languages: fr_fr, en_nz, en_us',
                '    Detector _!PKG!_ (default): Language "fr_fr" in position 0: OK',
                '    Detector _!PKG!_ (default): Language "en_nz" in position 1: OK',
                '    Detector _!PKG!_ (default): Language "en_us" in position 2: OK',
                '+++ Detector _!PKG!_ (default): Returning with languages: fr_fr, en_nz, en_us',
                '<<< Detector _!PKG!_ (default): Exiting with 3 new languages',
                '>>> Callback: Entering with languages: fr_fr, en_nz, en_us',
                '    Callback: fr_fr: Did not return a result',
                '    Callback: en_nz: Did not return a result',
                '    Callback: en_us: Did not return a result',
                '<<< Callback matched 0 languages',
                'Failed to find any language settings/configurations accepted by the callback',
            ],
        ]
    );
    my %built;
    for my $key ( sort keys %tests ) {
        my %current = @{ $tests{$key} };
        $current{'hasnew'} = 1;
        %built = (
            %built,
            _build_languagefinder_with_without_new( $key, %current )
        );
    }
    return %built;
}

sub _invalid_detectors_loading() {
    my %tests = (
        'Testing::MaybeMaketext::ThisDoesNotExist' => [
            'message' => 'Failed to load "_!PKG!_" because: "Can\'t locate _!PKGPATH!_ in INC',
            'dies'    => 'Checking detector: _!MSG!_',
        ],
        'Locale::MaybeMaketext::Tests::InvalidDetectors::DetectorFaulty' => [
            'message' => 'Failed to load "_!PKG!_" because: "Die die die! This detector is faulty!"',
            'dies'    => 'Checking detector: _!MSG!_',
        ],
        'Locale::MaybeMaketext::Tests::InvalidDetectors::DetectorInvalidReturn' => [
            'message' => 'Failed to load "_!PKG!_" because: "_!PKGPATH!_ did not return a true value"',
            'dies'    => 'Checking detector: _!MSG!_',
        ],
        'Locale::MaybeMaketext::Tests::InvalidDetectors::DetectorMismatch' => [
            'message' =>
              'Unable to load package "_!PKG!_" - load attempt (loaded by filesystem from "PATH") resulted in: No symbols found (before load attempt: Not loaded and no matching symbols found)',
            'dies' => 'Checking detector: _!MSG!_',

        ],
        'Locale::MaybeMaketext::Tests::InvalidDetectors::DetectorWarning' => [
            'message' =>
              'Failed to load "_!PKG!_" because: "Code raises a warning. If we did not cache results, this could be because a module is attempted to be reloaded"',
            'dies' => 'Checking detector: _!MSG!_',
        ],
    );
    my %built;
    for my $key ( sort keys %tests ) {
        my %current = @{ $tests{$key} };
        $current{'stage'} = 'loading';
        if ( !defined( $current{'warnings'} ) ) {
            $current{'warnings'} =
              [ 'During loading: ' . $current{'message'} ];
        }
        if ( !defined( $current{'findercheck_warnings'} ) ) {
            $current{'findercheck_warnings'} = [ 'Checking detector: ' . $current{'message'} ];
        }
        %current = _expand_texts( $key, %current );
        $built{$key} = [%current];
    }
    return \%built;
}

sub _expand_texts ( $package, %current ) {
    my %replace = (
        '_!PKG!_', $package,
        '_!PKGPATH!_' => ( $package =~ tr{:}{\/}rs ) . '.pm',
    );
    my $replacer = sub ($input) {
        for my $replacekey ( keys %replace ) {
            if ( index( $input, $replacekey ) >= 0 ) {
                my $replacement = $replace{$replacekey};
                $input =~ s/${replacekey}/${replacement}/g;
            }
        }
        return $input;
    };
    $replace{'_!MSG!_'} = defined( $current{'message'} ) ? $replacer->( $current{'message'} ) : '-NO MESSAGE-';
    for my $field ( keys(%current) ) {
        my $this_field = $current{$field};
        if ( ref($this_field) eq 'ARRAY' ) {
            my @out;
            for my $line ( @{$this_field} ) {
                push @out, $replacer->($line);
            }
            $current{$field} = \@out;
        }
        else {
            $current{$field} = $replacer->( $current{$field} );
        }
    }

    return %current;
}

sub _invalid_detectors_processing() {
    my %tests = (
        'Locale::MaybeMaketext::Tests::InvalidDetectors::DetectThrowsWarning' => [
            'message' => 'Warning during run_detect_!NEW!_: "Dummy warning"',
        ],
        'Locale::MaybeMaketext::Tests::InvalidDetectors::ReturnScalar' => [
            'message' =>
              'Error during run_detect_!NEW!_: "Invalid return from "detect". Expected a hash to be returned, got what appears to be scalar"',

        ],
        'Locale::MaybeMaketext::Tests::InvalidDetectors::ReturnSub' => [
            'message' =>
              'Error during run_detect_!NEW!_: "Invalid return from "detect". Expected a hash to be returned, got what appears to be CODE"',

        ],
        'Locale::MaybeMaketext::Tests::InvalidDetectors::ReturnUndef' => [
            'message' => 'Error during run_detect_!NEW!_: "Invalid return from "detect". No data returned."',

        ],
    );
    my %built;
    for my $key ( sort keys %tests ) {
        my %current = @{ $tests{$key} };
        $current{'stage'} = 'processing';

        $current{'hasnew'} = 1;
        if ( !defined( $current{'warnings'} ) ) {
            $current{'warnings'} =
              [ 'During processing: ' . $current{'message'} ];
        }
        %built = (
            %built,
            _build_languagefinder_with_without_new( $key, %current )
        );
    }
    return \%built;
}

sub _invalid_detectors_results() {
    my %tests = (
        'Locale::MaybeMaketext::Tests::InvalidDetectors::ReturnInvalidLanguagesNotArray' => [
            'message' => 'Invalid return from "detect". If set, invalid_languages must be an array: got scalar: 1',
        ],
        'Locale::MaybeMaketext::Tests::InvalidDetectors::ReturnLanguagesNotArray' => [
            'message' => 'Invalid return from "detect". Languages not returned as array: got scalar: hello',
        ],
        'Locale::MaybeMaketext::Tests::InvalidDetectors::ReturnLanguagesNotExist' => [
            'message' => 'Invalid return from "detect". No languages returned',
        ],
        'Locale::MaybeMaketext::Tests::InvalidDetectors::ReturnReasoningNotArray' => [
            'message' => 'Invalid return from "detect". Reasoning not returned as array: got scalar: hello',
        ],
        'Locale::MaybeMaketext::Tests::InvalidDetectors::ReturnReasoningNotExist' => [
            'message' => 'Invalid return from "detect". No reasoning returned',
        ],

    );
    my %built;
    for my $key ( sort keys %tests ) {
        my %current = @{ $tests{$key} };
        $current{'stage'}  = 'results';
        $current{'hasnew'} = 1;
        if ( !defined( $current{'warnings'} ) ) {
            $current{'warnings'} =
              [ 'During results processing: ' . $current{'message'} ];
        }
        %built = (
            %built,
            _build_languagefinder_with_without_new( $key, %current )
        );
    }
    return \%built;
}

sub _invalid_detectors_general() {
    my %tests = (
        'Locale::MaybeMaketext::Tests::InvalidDetectors::DetectorMissingDetect' => [
            'message'  => 'No "detect" subroutine found',
            'warnings' => [
                'During processing: _!MSG!_',
            ],
            'findercheck_warnings' => [
                'Checking detector: _!MSG!_',
            ],
            'dies' => 'Checking detector: _!MSG!_',
        ],

        'Locale::MaybeMaketext::Tests::InvalidDetectors::DetectorWarnsOnCan' => [
            'message'  => 'Warning during check_can_detect: "Can warned here!"',
            'warnings' => [
                'During processing: _!MSG!_',
            ],
            'precheck_warnings'    => ['Can warned here'],
            'findercheck_warnings' => ['Checking detector: No "detect" subroutine found'],
            'dies'                 => 'Checking detector: No "detect" subroutine found',
        ],
        'Locale::MaybeMaketext::Tests::InvalidDetectors::DetectorFaultsOnCan' => [
            'message'  => 'Error during check_can_detect: "Can errored here!"',
            'warnings' => [
                'During processing: _!MSG!_',
            ],
            'findercheck_warnings' => [
                'Checking detector: When subroutine "detect" was checked, error message was received: "Can errored here!"',
            ],
            'dies' =>
              'Checking detector: When subroutine "detect" was checked, error message was received: "Can errored here!"',
        ],
        'Locale::MaybeMaketext::Tests::InvalidDetectors::NewReturnsScalar' => [
            'message'  => 'Invalid return from "new". Expected a blessed object: got scalar: 1',
            'warnings' => [
                'During processing: _!MSG!_',
            ]
        ],
        'Locale::MaybeMaketext::Tests::InvalidDetectors::NewReturnsSub' => [
            'message'  => 'Invalid return from "new". Expected a blessed object: got CODE',
            'warnings' => [
                'During processing: _!MSG!_',
            ]
        ],
        'Locale::MaybeMaketext::Tests::InvalidDetectors::NewReturnsUndef' => [
            'message'  => 'Invalid return from "new". Nothing returned',
            'warnings' => [
                'During processing: _!MSG!_',
            ]

        ],
        'Locale::MaybeMaketext::Tests::InvalidDetectors::NewThrowsWarning' => [
            'message'  => 'Warning during run_detect_with_new (preparing new): "Dummy warning"',
            'warnings' => [
                'During processing: _!MSG!_',
            ]
        ],
    );
    my %built;
    for my $key ( sort keys %tests ) {
        my %current = @{ $tests{$key} };
        $current{'stage'} = 'processing';
        $built{$key} = [ _expand_texts( $key, %current ) ];
    }
    return \%built;
}

sub get_invalid_detectors ( $specifics = undef ) {
    $detector_list{'loading'}    //= _invalid_detectors_loading();
    $detector_list{'processing'} //= _invalid_detectors_processing();
    $detector_list{'results'}    //= _invalid_detectors_results();
    $detector_list{'general'}    //= _invalid_detectors_general();
    if ($specifics) {
        if ( defined( $detector_list{$specifics} ) ) {
            return %{ $detector_list{$specifics} };
        }
        croak( sprintf( 'Unrecognised "%s" data set', $specifics ) );
    }
    return keys(%detector_list);
}

sub _build_languagefinder_with_without_new ( $key, %data ) {
    my %built;
    if ( !exists( $data{'hasnew'} ) || !$data{'hasnew'} ) {
        $built{$key} = [ _expand_texts( $key, %data ) ];
        return %built;
    }

    my ( %with_new, %without_new );
    for my $field ( keys(%data) ) {
        my $this_field = $data{$field};
        if ( ref($this_field) eq 'ARRAY' ) {
            my ( @with_new_temp, @without_new_temp );
            for my $line ( @{$this_field} ) {
                push @with_new_temp,    $line =~ s/_!NEW!_/_with_new/r;
                push @without_new_temp, $line =~ s/_!NEW!_/_without_new/r;
            }
            $with_new{$field}    = [@with_new_temp];
            $without_new{$field} = [@without_new_temp];
        }
        else {
            $with_new{$field}    = $this_field =~ s/_!NEW!_/_with_new/r;
            $without_new{$field} = $this_field =~ s/_!NEW!_/_without_new/r;
        }
    }
    $built{$key} = [ _expand_texts( $key, %without_new ) ];
    $built{ sprintf( '%sWithNew', $key ) } = [ _expand_texts( sprintf( '%sWithNew', $key ), %with_new ) ];
    return %built;
}

1;
