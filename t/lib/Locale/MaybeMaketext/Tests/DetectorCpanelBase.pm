package Locale::MaybeMaketext::Tests::DetectorCpanelBase;

use strict;
use warnings;
use vars;
use feature qw/signatures/;
no if $] >= 5.032, q|feature|, qw/indirect/;
no warnings qw/experimental::signatures/;
use Scalar::Util                         qw/blessed/;
use Carp                                 qw/carp croak/;
use Locale::MaybeMaketext::Tests::Base qw/:all/;
use Locale::MaybeMaketext::Tests::Overrider();
use Locale::MaybeMaketext::Cache();
use Locale::MaybeMaketext::PackageLoader();
use Locale::MaybeMaketext::LanguageCodeValidator();
use Exporter qw/import/;

our @EXPORT_OK = qw/do_cpanel_detector_compare get_mocked_loader check_detect_call check_new
  get_sut_for_class
  get_sut_for_class_with_mocked_loader
  get_sut_for_class_with_mocked_loader_and_validator
  get_sut_for_class_with_mocked_validator
  get_mocked_validator/;
our %EXPORT_TAGS = ( all => [@EXPORT_OK] );

my $abstact_parent = 'Locale::MaybeMaketext::Detectors::Cpanel::AbstractParent';

sub get_sut_for_class ($class) {
    my $cache = Locale::MaybeMaketext::Cache->new();
    my $sut   = $class->new(
        'cache'                   => $cache,
        'package_loader'          => Locale::MaybeMaketext::PackageLoader->new( 'cache' => $cache ),
        'language_code_validator' => Locale::MaybeMaketext::LanguageCodeValidator->new( 'cache' => $cache )
    );
    return $sut;
}

sub get_sut_for_class_with_mocked_loader (
    $class, $overrider, $return_status = 0,
    $regexp = '\ALocale::MaybeMaketext'
) {
    my $cache = Locale::MaybeMaketext::Cache->new();
    my $sut   = $class->new(
        'cache'                   => $cache,
        'package_loader'          => get_mocked_loader( $overrider, $cache, $return_status, $regexp ),
        'language_code_validator' => Locale::MaybeMaketext::LanguageCodeValidator->new( 'cache' => $cache )
    );
    return $sut;
}

sub get_sut_for_class_with_mocked_loader_and_validator ( $class, $overrider, @allowed ) {
    my $cache = Locale::MaybeMaketext::Cache->new();
    my $sut   = $class->new(
        'cache'                   => $cache,
        'package_loader'          => get_mocked_loader( $overrider, $cache, 1, '\ALocale::MaybeMaketext' ),
        'language_code_validator' => get_mocked_validator( $overrider, $cache, @allowed )
    );
    return $sut;
}

sub get_sut_for_class_with_mocked_validator ( $class, $overrider, @allowed ) {
    my $cache = Locale::MaybeMaketext::Cache->new();
    my $sut   = $class->new(
        'cache'                   => $cache,
        'package_loader'          => Locale::MaybeMaketext::PackageLoader->new( 'cache' => $cache ),
        'language_code_validator' => get_mocked_validator( $overrider, $cache, @allowed )
    );
    return $sut;
}

sub get_mocked_validator ( $overrider, $cache, @allowed ) {
    my $validator = Locale::MaybeMaketext::LanguageCodeValidator->new( 'cache' => $cache );
    my %lookup    = map { $_ => 1 } @allowed;
    $overrider->override(
        'Locale::MaybeMaketext::LanguageCodeValidator::validate_multiple',
        sub ( $self, @languages ) {
            my ( @valid, @invalid, @reasoning );
            for (@languages) {
                if ( defined( $lookup{$_} ) ) {
                    push @reasoning, sprintf( 'Mock validating %s', $_ );
                    push @valid,     $_;
                }
                else {
                    push @reasoning, sprintf( 'Mock failing %s', $_ );
                    push @invalid,   $_;
                }
            }
            return (
                'languages'         => \@valid,
                'invalid_languages' => \@invalid,
                'reasoning'         => \@reasoning
            );
        }
    );
    return $validator;
}

sub get_mocked_loader ( $overrider, $cache, $return_status = 0, $regexp = '\ALocale::MaybeMaketext' ) {
    my $package_loader = Locale::MaybeMaketext::PackageLoader->new( 'cache' => $cache );
    $overrider->wrap(
        'Locale::MaybeMaketext::PackageLoader::attempt_package_load',
        sub ( $original_loader, @params ) {
            my $package_name = $params[1];
            if ( $package_name !~ /$regexp/ ) {
                if ( $return_status == 0 ) {
                    return (
                        'status'    => $return_status,
                        'reasoning' => sprintf( 'Blocked under test conditions %s', $package_name )
                    );
                }
                else {
                    return (
                        'status'    => $return_status,
                        'reasoning' => sprintf( 'Dummy load of %s', $package_name )
                    );
                }
            }
            my @return_data = $original_loader->(@params);
            return @return_data;
        }
    );
    return $package_loader;
}

sub do_cpanel_detector_compare ( $resultsref, $expectedref, $name ) {
    if ( ref($resultsref) ne 'HASH' ) {
        croak(
            sprintf(
                'Results passed to do_cpanel_detector_compare is not a hash reference: instead got %s',
                ref($resultsref) || 'scalar'
            )
        );
    }
    if ( ref($expectedref) ne 'HASH' ) {
        croak(
            sprintf(
                'Expected data passed to do_cpanel_detector_compare is not a hash reference: instead got %s',
                ref($expectedref) || 'scalar'
            )
        );
    }
    my %results  = %{$resultsref};
    my %expected = %{$expectedref};
    my @reasoning;
    for my $line ( @{ $results{'reasoning'} } ) {
        $line =~ s/\APackage Loader: (Loaded|Already loaded) "([^"]+)".*/TEST: Package Loader: Loaded $2/g;
        $line =~ s/TEST - Should have failed - TEST.*/TEST - Should have failed - TEST/gs;
        push @reasoning, $line;
    }
    my $all_ok = 1;
    for my $item (qw/reasoning languages invalid_languages/) {
        if ( !defined( $expected{$item} ) ) {
            croak( sprintf( 'Missing expected item %s: have keys %s', $item, join( q{,}, keys(%expected) ) ) );
        }
        if ( !defined( $results{$item} ) ) {
            croak( sprintf( 'Missing results item %s', $item ) );
        }
        my @expect = @{ $expected{$item} };
        my @got    = @{ $results{$item} };
        if ( $item eq 'reasoning' ) {
            @got = @reasoning;
        }
        if ( $#expect ne $#got ) {
            $all_ok = 0;
            last;
        }
        my $len = $#expect;
        for my $index ( 0 ... $len ) {
            if ( $expect[$index] ne $got[$index] ) {
                $all_ok = 0;
                last;
            }
        }
    }
    if ($all_ok) {
        pass( sprintf( '%s: Passed', $name ) );
    }
    else {

        is(
            $results{'languages'},
            $expected{'languages'},
            sprintf( '%s: Comparing languages', $name ),
            %results
        );
        is(
            $results{'invalid_languages'},
            $expected{'invalid_languages'},
            sprintf( '%s: Comparing invalid languages', $name ),
            %results
        );
        is(
            \@reasoning,
            \@{ $expected{'reasoning'} },
            sprintf( '%s: Comparing reasoning', $name ),
            'Looked for',
            @reasoning,
            'From original',
            $results{'reasoning'},
            'Expected',
            $expected{'reasoning'},
            %results
        );
    }
    return 1;
}

sub check_detect_call ( $class, $subroutine = 'run_detect' ) {
    my $code          = sub() { };
    my $dummy_blessed = bless {}, 'DummyTesting';
    my @tests         = (
        {
            'self'   => undef,
            'reason' => 'Should reject undef',
        },
        {
            'self'   => 'abc',
            'reason' => 'Should reject scalar',
        },
        {
            'self'   => $code,
            'reason' => 'Should reject code',
        },
        {
            'self'   => $dummy_blessed,
            'reason' => 'Should reject other blessed items',
        },
    );
    my $returned_object;
    my $message = sprintf( '%s should be passed an instance of its object %s', $subroutine, $class );

    subtest_buffered(
        sprintf( 'check_detect_call: %s', $subroutine ),
        sub() {
            for my $index ( 0 ... $#tests ) {
                my %test_data = %{ $tests[$index] };
                my $dies      = dies {
                    no strict 'refs';    ## no critic (TestingAndDebugging::ProhibitNoStrict)
                    my $ref = \&{"${class}::${subroutine}"};
                    $returned_object = $ref->( $test_data{'self'} );
                } || 'did not die';
                starts_with(
                    $dies,
                    $message,
                    sprintf( 'check_detect_call: %s %s',  $subroutine, $test_data{'reason'} ),
                    sprintf( 'Original dies message: %s', $dies ),
                    sprintf( 'Expected dies message: %s', $message )
                );

                is(
                    $returned_object, undef,
                    sprintf( 'check_detect_call: %s %s: Should not have returned', $subroutine, $test_data{'reason'} )
                );
            }
        }
    );
    return 1;
}

sub _check_inheritence ($class) {
    isa_ok(
        $class, ['Locale::MaybeMaketext::Detectors::Cpanel::AbstractParent'],
        'check_new (Inheritence): Class should be an instance of AbstractParent'
    );
    my @reserved_methods = (qw/new detect old_name_to_locale validate_add_reasoning load_package_and_run_in_eval/);
    my $class_colon      = "${class}::";
    my $passed           = 1;
    for my $subroutine (@reserved_methods) {
        no strict 'refs';    ## no critic (TestingAndDebugging::ProhibitNoStrict)
        if ( exists( &{ $class_colon . $subroutine } ) ) {
            fail( sprintf( 'check_new (Inheritence): Reserved method "%s" redeclared', $subroutine ) );
            $passed = 0;
        }
    }
    if ($passed) {
        pass('check_new (Inheritence): All reserved methods not redeclared');
    }
    {
        no strict 'refs';    ## no critic (TestingAndDebugging::ProhibitNoStrict)
        if ( exists( &{ $class_colon . 'run_detect' } ) ) {
            pass('check_new (Inheritence): Found "run_detect" declared');
        }
        else {
            fail('check_new (Inheritence): Missing "run_detect" method');
        }
    }
    return 1;
}

sub check_new ($class) {
    if ( $class ne $abstact_parent ) {
        _check_inheritence($class);
    }
    my $code          = sub() { };
    my $dummy_blessed = bless {}, 'DummyTesting';
    my $returned_object;
    my $overrider = Locale::MaybeMaketext::Tests::Overrider->new();
    my %needed    = ( 'cache' => Locale::MaybeMaketext::Cache->new() );
    $needed{'language_code_validator'} =
      Locale::MaybeMaketext::LanguageCodeValidator->new( 'cache' => $needed{'cache'} );
    $needed{'package_loader'} = get_mocked_loader( $overrider, $needed{'cache'} );

    my %built      = ();
    my $copy_built = sub ( $key, $new ) {
        my %return;
        for ( keys(%built) ) { $return{$_} = $built{$_}; }
        $return{$key} = $new;
        return \%return;
    };
    my @tests = (
        {
            'params'  => {},
            'message' => 'Missing needed configuration setting "cache"',
            'reason'  => 'Missing configuration settings',
        },
    );
    for my $key ( sort keys(%needed) ) {
        push @tests, {
            'params'  => $copy_built->( $key, 'abc' ),
            'message' =>
              sprintf( 'Configuration setting "%s" must be a blessed object: instead got %s', $key, 'scalar:abc' ),
            'reason' => sprintf( 'Checking %s is rejected if scalar', $key ),
          },
          {
            'params'  => $copy_built->( $key, $code ),
            'message' => sprintf( 'Configuration setting "%s" must be a blessed object: instead got %s', $key, 'CODE' ),
            'reason'  => sprintf( 'Checking %s is rejected if code', $key ),
          },
          {
            'params'  => $copy_built->( $key, $dummy_blessed ),
            'message' => sprintf(
                'Configuration setting "%s" must be an instance of "%s": got "%s"',
                $key,
                ref( $needed{$key} ),
                'DummyTesting'
            ),
            'reason' => sprintf( 'Checking %s is rejected if incorrect instance', $key ),
          };
        $built{$key} = $needed{$key};
    }
    for my $index ( 0 ... $#tests ) {
        my %test_data = %{ $tests[$index] };
        my %params    = %{ $test_data{'params'} };
        my $dies      = dies {
            $returned_object = undef;
            $returned_object = $class->new(%params);
        } || 'did not die';
        starts_with(
            $dies,
            $test_data{'message'},
            sprintf( 'check_new: %s',             $test_data{'reason'} ),
            sprintf( 'Original dies message: %s', $dies ),
            sprintf( 'Expected dies message: %s', $test_data{'message'} )
        );

        is(
            $returned_object, undef,
            sprintf( 'check_new: %s: Should not have returned an object', $test_data{'reason'} )
        );
    }
    $returned_object = $class->new(%built);
    isa_ok(
        $returned_object, [ $class, $abstact_parent ],
        'check_new: Should have instance returned when called correctly'
    );
    $overrider->reset_all();
    return 1;
}

1;
