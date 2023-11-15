#!perl
use strict;
use warnings;
use vars;
use File::Basename();
use File::Spec();
use lib File::Spec->catdir( File::Basename::dirname( File::Spec->rel2abs(__FILE__) ), q/lib/ );
use Locale::MaybeMaketext::Tests::Base qw/:all/;
use feature                              qw/signatures/;
no warnings qw/experimental::signatures/;
use Test2::Tools::Target 'Locale::MaybeMaketext::PackageLoader';
use Locale::MaybeMaketext::Cache();
use Locale::MaybeMaketext::PackageLoader qw/:all/;
use constant { WITHOUT_FUNCTIONS_OR_SYMBOLS => 0, WITH_FUNCTIONS => 1 };

subtest_buffered( 'is_valid_package_name',                 \&is_valid_package_name );
subtest_buffered( 'attempt_package_load_invalid_packages', \&attempt_package_load_invalid_packages );
subtest_buffered( 'check_attempt_package_load',            \&check_attempt_package_load );

done_testing();

sub _create_random_prefix ($prefix) {
    my @chars = ( 'a' .. 'z', '_', '0' .. '9' );
    for ( 1 ... 8 ) {    ## no critic (ValuesAndExpressions::ProhibitMagicNumbers);
        $prefix .= $chars[ rand @chars ];
    }
    return $prefix;
}

sub _compare_results ( $sut, $description, %this_package ) {
    my %results = $sut->attempt_package_load( $this_package{'name'} );

    is(
        $results{'status'}, $this_package{'status'},
        sprintf( '%s: Status should be the same', $description ),
        'Received',
        %results,
        'Expected',
        %this_package
    );
    my $reasoning = $results{'reasoning'};
    if ( $this_package{'normalize'} ) {
        $reasoning =~ s/\ filesystem\ from\ "\S+\.pm"/ filesystem from "PATH"/gsm;
        starts_with(
            $reasoning, $this_package{'reasoning'},
            sprintf( '%s: (Normalized) Reasoning should be the same', $description ),
            'Received modified reasoning',
            $reasoning,
            'Received',
            %results,
            'Expected',
            %this_package
        );
    }
    else {
        is(
            $results{'reasoning'}, $this_package{'reasoning'},
            sprintf( '%s: Reasoning should be the same', $description ),
            'Received',
            %results,
            'Expected',
            %this_package
        );
    }
    if ( exists( $this_package{'cached'} ) || exists( $results{'_cached'} ) ) {
        is(
            $results{'_cached'} || 0, $this_package{'cached'} || 0,
            sprintf( '%s: Cache status should be the same', $description ),
            'Received',
            %results,
            'Expected',
            %this_package
        );
    }
    return 1;
}

sub is_valid_package_name() {
    my $sut       = $CLASS->new( 'cache' => Locale::MaybeMaketext::Cache->new() );
    my @test_data = (
        {
            'should_pass'  => 1,
            'pass_message' => 'Valid package names (%d) all passed',
            'fail_message' => 'Following valid package names failed: "%s"',
            'packages'     => [
                qw/Locale::MaybeMaketext::BaseUtilities File::Spec File::Spec::Aliens IPC::Open LWP::UserAgent XML::Simple Text::CSV
                  Spreadsheet::WriteExcel DBIx::Class::ResultSet IO::Socket::SSL WWW::Mechanize/
            ],
        },
        {
            'should_pass'  => 0,
            'pass_message' => 'Valid looking but currently rejected packages (%d) were all rejected',
            'fail_message' => 'At the moment, the following package names should have failed, but didn\'t: "%s"',
            'packages'     => [qw/B::Assembler Template DBI JSON DateTime Moo URI 0/],
        },
        {
            'should_pass'  => 0,
            'pass_message' => 'Bad package names (%d) all were rejected',
            'fail_message' => 'Following invalid package names incorrectly passed: "%s"',
            'packages'     => [qw/23SN::dskj2 Some:Thing A::B::C::D/]
        },
        {
            'should_pass'  => 0,
            'pass_message' => 'Not string names (%d) all were rejected',
            'fail_message' => 'Following not scalar string names incorrectly passed: "%s"',
            'packages'     => [ sub() { print 'Hi'; }, [] ]
        },
    );
    for (@test_data) {
        my %test = %{$_};
        my ( @passed, @failed );
        for my $name ( @{ $test{'packages'} } ) {
            my $ref = ref($name);
            $sut->is_valid_package_name($name)
              ? ( push @passed, $ref ? "[Type:$ref]" : $name )
              : ( push @failed, $ref ? "[Type:$ref]" : $name );
        }
        if ( $test{'should_pass'} ) {
            if (@failed) {
                fail( sprintf( $test{'fail_message'}, join( '", "', @failed ) ) );
            }
            else {
                pass( sprintf( $test{'pass_message'}, scalar(@passed) ) );
            }
        }
        else {
            if (@passed) {
                fail( sprintf( $test{'fail_message'}, join( '", "', @passed ) ) );
            }
            else {
                pass( sprintf( $test{'pass_message'}, scalar(@failed) ) );
            }
        }
    }
    is( $sut->is_valid_package_name(undef), 0, 'Undefined package names should fail' );
    return 1;
}

sub attempt_package_load_invalid_packages() {
    my $sut = $CLASS->new( 'cache' => Locale::MaybeMaketext::Cache->new() );
    my @packages;
    for my $package_name (qw/23SN::dskj2 Some:Thing A::B::C::D/) {
        push @packages, {
            'name'      => $package_name,
            'reasoning' => sprintf( 'Invalid package name "%s"', $package_name )
        };
    }
    push @packages, {
        'name'        => undef,
        'description' => 'Package with undef as a name',
        'reasoning'   => sprintf( 'Invalid package name "%s"', '[Undefined]' )
    };
    push @packages, {
        'name'        => sub() { print 'Hi!'; },
        'description' => 'Package with code as a name',
        'reasoning'   => sprintf( 'Invalid package name "%s"', '[Type:CODE]' )
    };
    for (@packages) {
        my %package_data = %{$_};
        my $description  = sprintf(
            'check_attempt_package_load_invalid_packages: %s',
            ( $package_data{'description'} || $package_data{'name'} )
        );
        my %expect_results = (
            'name'      => $package_data{'name'},
            'status'    => 0,
            'reasoning' => $package_data{'reasoning'},
        );
        _compare_results( $sut, $description, %expect_results );
    }
    return 1;
}

sub check_attempt_package_load() {
    my $sut        = $CLASS->new( 'cache' => Locale::MaybeMaketext::Cache->new() );
    my $pkg_prefix = 'Locale::MaybeMaketext::Tests::PackageLoader';
    my @packages   = _get_packages($pkg_prefix);

    for (@packages) {
        my %package_data = %{$_};
        my $description =
          sprintf( 'check_attempt_package_load: %s', ( $package_data{'description'} || $package_data{'name'} ) );
        my %expect_results = (
            'name'      => $package_data{'name'},
            'status'    => $package_data{'status'},
            'reasoning' => $package_data{'reasoning'},
            'normalize' => $package_data{'normalize'} // 0,
        );
        if ( exists( $package_data{'inc_data'} ) ) {
            local $INC{ $package_data{'inc_path'} } = $package_data{'inc_data'};
            _compare_results( $sut, $description, %expect_results );
        }
        else {
            _compare_results( $sut, $description, %expect_results );
        }
    }
    for (@packages) {
        my %package_data = %{$_};
        my $description  = sprintf(
            'check_attempt_package_load: %s - cached',
            ( $package_data{'description'} || $package_data{'name'} )
        );
        my %expect_results = (
            'name'      => $package_data{'name'},
            'status'    => $package_data{'status'},
            'reasoning' => $package_data{'reasoning'},
            'normalize' => $package_data{'normalize'} // 0,
            'cached'    => 1,
        );
        if ( exists( $package_data{'inc_data'} ) ) {
            local $INC{ $package_data{'inc_path'} } = $package_data{'inc_data'};
            _compare_results( $sut, $description, %expect_results );
        }
        else {
            _compare_results( $sut, $description, %expect_results );
        }
    }
    return 1;
}

sub _get_packages ($pkg_prefix) {
    my $tmp_name;

    my @packages;

    my %failures = (
        'DetectorFaulty'   => 'Failed to load "%s" because: "Die die die! This detector is faulty!',
        'DetectorMismatch' =>
          'Unable to load package "%s" - load attempt (loaded by filesystem from "PATH") resulted in: No symbols',
        'DetectorWarning' =>
          'Failed to load "%s" because: "Code raises a warning. If we did not cache results, this could be because a module is attempted to be reloaded',
    );
    for my $package_name ( sort( keys(%failures) ) ) {
        $tmp_name = sprintf( '%s::%s', $pkg_prefix, $package_name );
        push @packages, {
            'name'        => $tmp_name,
            'description' => sprintf( 'Failed detector %s', $tmp_name ),
            'status'      => 0,
            'reasoning'   => sprintf( $failures{$package_name}, $tmp_name ),
            'normalize'   => 1
        };
    }
    $tmp_name = sprintf( '%s::%s', $pkg_prefix, 'DetectorInvalidReturn' );
    push @packages, {
        'name' => $tmp_name,

        'description' => sprintf( 'Failed detector %s', $tmp_name ),
        'status'      => 0,
        'reasoning'   => sprintf(
            'Failed to load "%s" because: "%s did not return a true value',
            $tmp_name, ( $tmp_name =~ tr{:}{\/}rs ) . '.pm'
        ),
        'normalize' => 1
    };
    $tmp_name = sprintf( '%s::%s', $pkg_prefix, 'DetectorDummy' );
    push @packages, {
        'name' => $tmp_name,

        'description' => sprintf( 'Working detector %s', $tmp_name ),
        'status'      => 1,
        'reasoning'   => sprintf(
            'Loaded "%s" - loaded by filesystem from "PATH" (as previously Not loaded and no matching symbols found)',
            $tmp_name
        ),
        'normalize' => 1
    };

    # generate the spoof data
    my $parent_prefix = _create_random_prefix('Generated::Testing::');
    my $parent_data   = join( "\n", sprintf( 'package %s;', $parent_prefix ), '1;' );
    if ( !eval $parent_data ) {    ## no critic (BuiltinFunctions::ProhibitStringyEval)
        croak(
            sprintf(
                'Could not create parent test package %s: %s Data: %s',
                $parent_prefix,
                ( $@ || $! || '[Unknown reasoning]' ),
                $parent_data
            )
        );
    }
    my %prefixes_hash;
    my $get_prefix = sub {
        my $random = _create_random_prefix('Generated::Testing::');
        if ( $random eq $parent_prefix ) {
            fail('Failed to generate unique prefix from parent');
        }
        if ( defined( $prefixes_hash{$random} ) ) {
            fail('Failed to generate unique prefix');
        }
        $prefixes_hash{$random} = 1;
        return $random;
    };
    @packages = (
        @packages,
        _get_faked_package_data( $get_prefix->(), WITH_FUNCTIONS ),
        _get_faked_package_data( $get_prefix->(), WITHOUT_FUNCTIONS_OR_SYMBOLS ),
        _get_faked_package_data( $get_prefix->(), WITH_FUNCTIONS,               $parent_prefix ),
        _get_faked_package_data( $get_prefix->(), WITHOUT_FUNCTIONS_OR_SYMBOLS, $parent_prefix ),
    );
    return @packages;
}

sub _get_faked_package_data ( $prefix, $with = WITH_FUNCTIONS, $parent = undef ) {
    my @package_data;
    my ( $description, $expect_status, $expect_text ) = ( q{}, 0, q{} );
    if ( defined($parent) ) {
        @package_data = ( @package_data, sprintf( 'use parent -norequire, "%s";', $parent ) );
    }
    if ( $with == WITH_FUNCTIONS ) {
        ## no critic (ValuesAndExpressions::RequireInterpolationOfMetachars)
        @package_data = ( @package_data, ( '# Dummy variables', 'my $test="abc";', 'my %testerhash=();' ) );
        @package_data = (
            @package_data,
            (
                '# Dummy functions', 'sub testsub { print "Hello tester!"; }',
                'sub printtest { print "Printed!"; }'
            )
        );
        $expect_status = 1;
        if ( defined($parent) ) {
            $description = '(with parent and functions)';
            $expect_text = 'Already loaded "%s" - %s (Found 4 symbols - with at least one function and ISA/parent)';
        }
        else {
            $description = '(with functions)';
            $expect_text = 'Already loaded "%s" - %s (Found 2 symbols - with at least one function)';
        }
    }
    elsif ( $with == WITHOUT_FUNCTIONS_OR_SYMBOLS ) {
        if ( defined($parent) ) {
            $expect_status = 1;
            $description   = '(with ISA/parent but no functions/symbols)';
            $expect_text   = 'Already loaded "%s" - %s (Found 2 symbols - with ISA/parent but no functions)';
        }
        else {
            $description = '(without anything)';
            $expect_text = 'Previous attempt to load "%s" failed due to "No symbols found" after: %s';
        }
    }
    else {
        croak('Invalid call to _get_faked_package_data: with setting unrecognised');
    }

    # define the test packages
    my @test_packages = (
        {
            'name'          => 'Filesystem',
            'source'        => '/usr/tmp/local/filesystem.pm',
            'load_describe' => 'loaded by filesystem from "/usr/tmp/local/filesystem.pm"'
        },
        {
            'name'          => 'Hooked',
            'source'        => ['test'],
            'load_describe' => 'loaded by hook'
        },
        {
            'name'          => 'Undef',
            'source'        => undef,
            'load_describe' => 'raised error/warning on load'
        },
    );
    my @all_out;

    # add the relevant data to each one

    for (@test_packages) {
        my %test = %{$_};
        my %out;
        $out{'name'} = sprintf(
            '%s::%s::%s',
            $prefix,
            $test{'name'},
            (
                $with == WITH_FUNCTIONS
                ? 'Functions'
                : ( $with == WITHOUT_FUNCTIONS_OR_SYMBOLS ? 'Nowt' : 'Unknown' )
              )
              . ( defined($parent) ? 'WithParent' : q{} )
        );
        $out{'description'} = sprintf( 'Faked %s %s', $out{'name'}, $description );
        $out{'inc_path'}    = ( $out{'name'} =~ tr{:}{\/}rs ) . '.pm';
        $out{'inc_data'}    = $test{'source'};
        my $define = join(
            "\n",
            (
                sprintf( 'package %s;', $out{'name'} ),
                @package_data,
                '1;'
            )
        );
        if ( !eval "$define" ) {    ## no critic (BuiltinFunctions::ProhibitStringyEval)
            croak(
                sprintf(
                    'Could not create test package %s: %s Data: %s',
                    $out{'name'},
                    ( $@ || $! || '[Unknown reasoning]' ),
                    $define
                )
            );
        }
        $out{'reasoning'} = sprintf( $expect_text, $out{'name'}, $test{'load_describe'} );
        $out{'status'}    = $expect_status;
        push @all_out, \%out;
    }
    return @all_out;
}
