#!perl
use strict;
use warnings;
use vars;
use Data::Dumper qw/Dumper/;
use Test2::V0;
use Test2::Tools::Exception qw/dies lives/;
use Test2::Plugin::BailOnFail;
use Test2::Plugin::ExitSummary;
use Test2::Tools::Compare qw/is like/;
use Test2::Tools::Subtest qw/subtest_buffered/;
use Carp                  qw/carp croak/;
use feature               qw/signatures/;
no if $] >= 5.032, q|feature|, qw/indirect/;
no warnings qw/experimental::signatures/;
use File::Basename();
use File::Spec();
use lib File::Spec->catdir( File::Basename::dirname( File::Spec->rel2abs(__FILE__) ), q/lib/ );
use Test2::Tools::Target 'Locale::MaybeMaketext::Tests::Overrider';
use Fcntl qw/:mode :seek/;
use Errno qw/EPERM EIO ENOENT/;    # add file system error messages lookups.
use constant {
    STAT_MODE     => 2,
    STAT_UID      => 4,
    STAT_GID      => 5,
    STAT_FILESIZE => 7,
};
our $GLOBAL_TEST;
test_new_block_multiple();

test_override();

test_wrap();

test_reset_single();
test_reset_single_overridden();
test_reset_single_wrapped();
test_reset_all();
subtest_buffered(
    'mock_stat',
    sub() {
        my $sut = $CLASS->new();
        test_mock_stat_no_mock($sut);
        test_mock_stat_bad_parameters($sut);
        test_mock_stat_no_parameters($sut);
        test_mock_stat_not_exists($sut);
        test_mock_stat_not_readable($sut);
        test_mock_stat_not_file($sut);
        test_mock_stat_specified_size($sut);
        $sut = undef;

        # we want clean instances from now on.
        test_mock_remove_mock_stat();
        test_mock_remove_all_mock_stat();
    }
);
subtest_buffered(
    'mock_filesystem override handlers',
    sub() {
        my $sut = $CLASS->new();
        test_mock_filesytem_override_open($sut);
        test_mock_filesytem_override_read($sut);
        test_mock_filesystem_override_seek($sut);
    }
);
subtest_buffered(
    'mock_filesystem',
    sub() {
        my $sut = $CLASS->new();
        test_mock_filesystem_no_mock($sut);
        test_mock_filesystem_not_openable($sut);
        test_mock_filesystem_not_readable($sut);
        test_mock_filesystem_readable_but_no_contents($sut);
        test_mock_filesystem_not_closable($sut);
        test_mock_filesystem_working($sut);
        test_mock_filesystem_multiple_reads($sut);
        $sut = undef;

        # we want clean instances from now on.
        test_mock_remove_mock_filesystem();
        test_mock_remove_all_mock_filesystem();
    }
);

done_testing();

sub _get_test_file() {
    my $contents = 'This is a test for the Overrider system.';
    return (
        'filename' => sprintf(
            '%s/%s',
            File::Spec->catdir( File::Basename::dirname( File::Spec->rel2abs(__FILE__) ), qw/testdata overrider/ ),
            'main_check.txt'
        ),
        'contents' => $contents,
        'size'     => length($contents)
    );
}

sub _get_secondary_test_file() {
    my $contents = 'Secondary test file for the Overrider system.';
    return (
        'filename' => sprintf(
            '%s/%s',
            File::Spec->catdir( File::Basename::dirname( File::Spec->rel2abs(__FILE__) ), qw/testdata overrider/ ),
            'secondary_check.txt'
        ),
        'contents' => $contents,
        'size'     => length($contents)
    );
}

sub test_new_block_multiple() {
    my $first_line = __LINE__ + 1;
    my $sut        = $CLASS->new();
    my $second_line;
    my $dies = dies {
        $second_line = __LINE__ + 1;
        my $sut2 = $CLASS->new();
    } || 'failed to die';
    my $expected_start  = 'Another override instance is currently active: Started in';
    my $filename        = __FILE__ =~ s/.*(t\/[[[:alpha:]]0-9\_-]+.t)\Z/$1/r;
    my $expected_middle = sprintf( '%s:%d - but just called at', $filename, $first_line );
    my $expected_end    = sprintf( '%s:%d',                      $filename, $second_line );
    my $regexp          = sprintf(
        '%s \S+ %s \S+ %s', quotemeta($expected_start), quotemeta($expected_middle),
        quotemeta($expected_end)
    );
    _like_starts_with( $dies, $regexp, 'test_new_block_multiple: Should stop multiple occurance' );
    return 1;
}

sub _like_starts_with ( $results, $expected, $message, @diag ) {
    my $expect = sprintf( '\A%s', $expected );
    like( $results, qr/$expect/, $message, @diag );
    return 1;
}

sub _test_invalid_subroutine_names ( $label, $callback ) {
    _like_starts_with(
        dies {
            $callback->( sub { } );
        } || 'failed to die',
        quotemeta('Subname must be a scalar string: instead got: CODE'),
        sprintf( '%s should reject code as subroutine name', $label )
    );
    _like_starts_with(
        dies {
            $callback->('he!llo');
        } || 'failed to die',
        quotemeta('Invalid/incomplete subname "he!llo"'),
        sprintf( '%s should reject names with non-alpha', $label )
    );
    _like_starts_with(
        dies {
            $callback->('a::something');
        } || 'failed to die',
        quotemeta('Invalid/incomplete subname "a::something"'),
        sprintf( '%s should reject short initial package names', $label )
    );
    _like_starts_with(
        dies {
            $callback->('123::something');
        } || 'failed to die',
        quotemeta('Invalid/incomplete subname "123::something"'),
        sprintf( '%s should reject package names starting with a digit', $label )
    );
    _like_starts_with(
        dies {
            $callback->('hello::some!thing');
        } || 'failed to die',
        quotemeta('Invalid/incomplete subname "hello::some!thing"'),
        sprintf( '%s should reject subroutine names containing non-alpha/digits/underscore', $label )
    );
    return 1;
}

sub test_override() {
    _test_invalid_subroutine_names(
        'test_override: Override',
        sub ($data) {
            my $sut = $CLASS->new();
            $sut->override( $data, sub { } );
        }
    );
    _like_starts_with(
        dies {
            my $sut = $CLASS->new();
            $sut->override( 'main::dummy_subroutine', 'hello' );
        } || 'did not die',
        quotemeta('Parameter 2 to override (new_sub) must be a code reference: instead got: scalar'),
        'test_override: Should fail to wrap if no code'
    );
    my $sut = $CLASS->new();
    $sut->override(
        'main::dummy_subroutine',
        sub ( $name, $title, $ignore ) {
            return sprintf( 'Overridden to get %s %s', $ignore, $name );
        }
    );
    my $expected = 'Overridden to get something here.';
    my $results  = dummy_subroutine( 'here.', 'should not appear', 'something' );
    is( $results, $expected, 'test_override: Should override code' );
    return 1;
}

sub test_wrap() {
    _test_invalid_subroutine_names(
        'test_wrap: Wrap',
        sub ($data) {
            my $sut = $CLASS->new();
            $sut->wrap( $data, sub { } );
        }
    );
    _like_starts_with(
        dies {
            my $sut = $CLASS->new();
            $sut->wrap( 'testing_does_not_exist', sub { } );
        } || 'did not die',
        quotemeta('Cannot wrap subroutine "testing_does_not_exist" as it does not exist'),
        'test_wrap: Should fail to wrap if no matching sub'
    );
    _like_starts_with(
        dies {
            my $sut = $CLASS->new();
            $sut->wrap( 'main::dummy_subroutine', 'hello' );
        } || 'did not die',
        quotemeta('Parameter 2 to wrap (new_sub) must be a code reference: instead got: scalar'),
        'test_wrap: Should fail to wrap if no code'
    );
    my $sut = $CLASS->new();
    $sut->wrap(
        'main::dummy_subroutine',
        sub ( $existing_sub, @params ) {
            my $demo = $existing_sub->( $params[2], $params[1], 'ignore' );
            return sprintf( 'From the wrapped: %s Wow!', $demo );
        }
    );
    my $expected = 'From the wrapped: Hello there! Wow!';
    my $results  = dummy_subroutine( 'what', 'there', 'Hello' );
    is( $results, $expected, 'test_wrap: Should wrap code' );
    return 1;
}

sub test_reset_single() {
    _test_invalid_subroutine_names(
        'test_reset_single: Reset single',
        sub ($data) {
            my $sut = $CLASS->new();
            $sut->reset_single($data);
        }
    );
    _like_starts_with(
        dies {
            my $sut = $CLASS->new();
            $sut->reset_single('main::not_overriden');
        } || 'did not die',
        quotemeta('Subroutine main::not_overriden is not overriden'),
        'test_reset_single: Should check if it is overridden'
    );
    return 1;
}

sub test_reset_single_overridden() {
    my $sut = $CLASS->new();
    $sut->override( 'main::dummy_subroutine', sub ( $name, $title, $ignore ) { return 'Overridden dummy'; } );
    $sut->override( 'main::other_dummy',      sub ($name) { return 'Overridden other'; } );
    $sut->override( 'main::made_up',          sub { return 'Overridden imaginary'; } );
    is(
        'Overridden dummy', dummy_subroutine( 'a', 'b', 'c' ),
        'test_reset_single_overridden: Ensure dummy subroutine overridden'
    );
    is(
        'Overridden other', other_dummy('d'),
        'test_reset_single_overridden: Ensure other dummy subroutine overridden'
    );
    is( 'Overridden imaginary', made_up(), 'test_reset_single_overridden: Ensure madeup subroutine created' );
    $sut->reset_single('main::other_dummy');
    is(
        'Overridden dummy', dummy_subroutine( 'a', 'b', 'c' ),
        'test_reset_single_overridden: Ensure dummy subroutine still overridden'
    );
    is( 'Test of d',            other_dummy('d'), 'test_reset_single_overridden: Ensure other dummy no longer' );
    is( 'Overridden imaginary', made_up(), 'test_reset_single_overridden: Ensure madeup subroutine still overridden' );
    $sut->reset_single('main::made_up');
    _like_starts_with(
        dies {
            return made_up();
        } || 'did not die',
        quotemeta('Undefined subroutine &main::made_up called'),
        'test_reset_single_overridden: madeup subroutine should no longer exist'
    );
    return 1;
}

# This actually helped diagnose an issue where the overridder was not getting properly
# DESTROYed at the end of a method it was called from as "wrap" was originally calling
# "override" creating a loop which kept it persisting.
sub test_reset_single_wrapped() {

    my $sut = $CLASS->new();
    $sut->wrap( 'main::dummy_subroutine', sub ( $original, $name, $title, $ignore ) { return 'Wrapped dummy'; } );
    $sut->wrap( 'main::other_dummy', sub ( $original, $name ) { return 'Wrapped other'; } );
    is(
        'Wrapped dummy', dummy_subroutine( 'a', 'b', 'c' ),
        'test_reset_single_wrapped: Ensure dummy subroutine wrapped'
    );
    is( 'Wrapped other', other_dummy('d'), 'test_reset_single_wrapped: Ensure other dummy subroutine wrapped' );
    $sut->reset_single('main::other_dummy');
    is(
        'Wrapped dummy', dummy_subroutine( 'a', 'b', 'c' ),
        'test_reset_single_wrapped: Ensure dummy subroutine still wrapped'
    );
    is( 'Test of d', other_dummy('d'), 'test_reset_single_wrapped: Ensure other dummy no longer' );

    return 1;
}

sub test_reset_all() {
    my $sut = $CLASS->new();
    $sut->override( 'main::dummy_subroutine', sub ( $name, $title, $ignore ) { return 'Overridden dummy'; } );
    $sut->wrap( 'main::other_dummy', sub ( $original, $name ) { return 'Wrapped other'; } );
    $sut->override( 'main::made_up', sub { return 'Overridden imaginary'; } );
    is(
        'Overridden dummy', dummy_subroutine( 'a', 'b', 'c' ),
        'test_reset_all: Ensure dummy subroutine overridden'
    );
    is(
        'Wrapped other', other_dummy('d'),
        'test_reset_all: Ensure other dummy subroutine wrapped'
    );
    is( 'Overridden imaginary', made_up(), 'test_reset_all: Ensure madeup subroutine created' );
    $sut->reset_all();
    is( 'a b!',      dummy_subroutine( 'a', 'b', 'c' ), 'test_reset_all: Ensure dummy no longer overridden' );
    is( 'Test of d', other_dummy('d'),                  'test_reset_all: Ensure other dummy no longer wrapped' );
    _like_starts_with(
        dies {
            return made_up();
        } || 'did not die',
        quotemeta('Undefined subroutine &main::made_up called'),
        'test_reset_all: madeup subroutine should no longer exist'
    );
    return 1;
}

sub _test_stats_zero_values ( $test_name, @stats ) {
    ## no critic (ValuesAndExpressions::ProhibitMagicNumbers)
    my %should_be_empty = (
        0  => 'dev',
        1  => 'ino',
        3  => 'nlink',
        4  => 'uid',
        5  => 'gid',
        6  => 'rdev',
        8  => 'atime',
        9  => 'mtime',
        10 => 'ctime',
        11 => 'blksize',
        12 => 'blocks',
    );
    for my $index ( keys(%should_be_empty) ) {
        if ( $stats[$index] != 0 ) {
            fail(
                sprintf(
                    '%s : Value of %d (%s) should be empty if mocked', $test_name, $index, $should_be_empty{$index}
                )
            );
        }
    }
    return 1;
}

sub test_mock_stat_no_mock ($sut) {
    my %test_file = _get_test_file();
    my ( $mode, $uid, $gid, $size, @stats );
    is( $sut->is_mock_stat( $test_file{'filename'} ), 0, 'test_mock_stat_no_mock: Unmocked file should not be mocked' );
    @stats = stat( $test_file{'filename'} );
    isnt( [], \@stats, 'test_mock_stat_no_mock: Unmocked example file must be found', 'File', $test_file{'filename'} );
    ( $mode, $uid, $gid, $size ) = ( $stats[STAT_MODE], $stats[STAT_UID], $stats[STAT_GID], $stats[STAT_FILESIZE] );
    is(
        S_ISREG($mode) ? 1 : 0,
        1,
        'test_mock_stat_no_mock: Unmocked example file must be a file',
        'File',
        $test_file{'filename'}
    );
    is(
        ( $mode & S_IRUSR ) ? 1 : 0,
        1,
        'test_mock_stat_no_mock: Unmocked example file must be readable by current user',
        'File',
        $test_file{'filename'}
    );
    is(
        $size,
        $test_file{'size'},
        'test_mock_stat_no_mock: Unmocked example file must be correct size',
        'File',
        $test_file{'filename'}
    );
    return 1;
}

sub test_mock_stat_bad_parameters ($sut) {
    my %test_file = _get_test_file();
    for my $current (qw/exists readable file/) {
        my $dies = dies { $sut->mock_stat( $test_file{'filename'}, sprintf( '%s=46', $current ) ); } || 'did not die';
        starts_with(
            $dies, sprintf( '%s is a boolean only setting. It cannot use =', $current ),
            sprintf( 'test_mock_stat_bad_parameters: %s should be a boolean only setting', $current )
        );
    }
    return 1;
}

sub starts_with ( $received, $expected, $message, @diag ) {
    if ( !defined($received) ) {
        if ( defined($expected) ) {
            fail(
                $message,
                'starts_with expected a defined string, but the received data was UNDEFINED'
            );
        }
        pass($message);
    }
    elsif ( !defined($expected) ) {
        fail(
            $message, 'starts_with expected text to be undefined, but received: ' . $received,
            ( @diag, "Received: $received" )
        );
    }
    my $length = length($expected);
    is( substr( $received, 0, $length ), $expected, $message, ( @diag, "Received: $received" ) );
    return 1;
}

sub test_mock_stat_no_parameters ($sut) {
    my %test_file = _get_test_file();
    my ( $mode, $uid, $gid, $size, @stats );
    $sut->mock_stat( $test_file{'filename'} );
    is(
        $sut->is_mock_stat( $test_file{'filename'} ), 1,
        'test_mock_stat_no_parameters: Mocked file should be mocked'
    );

    @stats = stat( $test_file{'filename'} );
    isnt(
        [], \@stats, 'test_mock_stat_no_parameters: Mocked example file must be found', 'File',
        $test_file{'filename'}
    );
    ( $mode, $uid, $gid, $size ) = ( $stats[STAT_MODE], $stats[STAT_UID], $stats[STAT_GID], $stats[STAT_FILESIZE] );
    _test_stats_zero_values( 'test_mock_stat_no_parameters', @stats );
    is(
        S_ISREG($mode) ? 1 : 0, 1, 'test_mock_stat_no_parameters: Mocked example file must be a file', 'File',
        $test_file{'filename'}
    );
    is(
        ( $mode & S_IRUSR ) ? 1 : 0, 1,
        'test_mock_stat_no_parameters: Mocked example file must be readable by current user',
        'File',
        $test_file{'filename'}
    );
    is( $size, 0, 'test_mock_stat_no_parameters: Mocked example file must be 0 bytes', 'File', $test_file{'filename'} );
    return 1;
}

sub test_mock_stat_not_exists ($sut) {
    my %test_file = _get_test_file();
    my ( $mode, $uid, $gid, $size, @stats );
    $sut->mock_stat( $test_file{'filename'}, ('-exists') );
    @stats = stat( $test_file{'filename'} );
    is(
        [], \@stats, 'test_mock_stat_not_exists: Mocked file must be not found if -exists', 'File',
        $test_file{'filename'}
    );
    return 1;
}

sub test_mock_stat_not_readable ($sut) {
    my %test_file = _get_test_file();
    my ( $mode, $uid, $gid, $size, @stats );
    $sut->mock_stat( $test_file{'filename'}, ('-readable') );
    is(
        $sut->is_mock_stat( $test_file{'filename'} ), 1,
        'test_mock_stat_not_readable: Mocked file should be mocked'
    );
    @stats = stat( $test_file{'filename'} );
    isnt(
        [], \@stats, 'test_mock_stat_not_readable: Mocked example file must be found in -readable', 'File',
        $test_file{'filename'}
    );
    ( $mode, $uid, $gid, $size ) = ( $stats[STAT_MODE], $stats[STAT_UID], $stats[STAT_GID], $stats[STAT_FILESIZE] );

    _test_stats_zero_values( 'test_mock_stat_not_readable', @stats );
    is(
        S_ISREG($mode) ? 1 : 0, 1, 'test_mock_stat_not_readable: Mocked example file must be a file in -readable',
        'File',
        $test_file{'filename'}
    );
    is(
        ( $mode & S_IRUSR ) ? 1 : 0, 0,
        'test_mock_stat_not_readable: Mocked example file must be not be readable by current user if -readable',
        'File',
        $test_file{'filename'}
    );

    is( $size, 0, 'test_mock_stat_not_readable: Mocked example file must be 0 bytes', 'File', $test_file{'filename'} );
    return 1;
}

sub test_mock_stat_not_file ($sut) {
    my %test_file = _get_test_file();
    my ( $mode, $uid, $gid, $size, @stats );
    $sut->mock_stat( $test_file{'filename'}, ('-file') );
    is(
        $sut->is_mock_stat( $test_file{'filename'} ), 1,
        'test_mock_stat_not_file: Mocked file should be mocked'
    );
    @stats = stat( $test_file{'filename'} );
    isnt(
        [], \@stats, 'test_mock_stat_not_file: Mocked example file must be found in -file', 'File',
        $test_file{'filename'}
    );
    ( $mode, $uid, $gid, $size ) = ( $stats[STAT_MODE], $stats[STAT_UID], $stats[STAT_GID], $stats[STAT_FILESIZE] );

    _test_stats_zero_values( 'test_mock_stat_not_file', @stats );
    is(
        S_ISREG($mode) ? 1 : 0, 0, 'test_mock_stat_not_file: Mocked example file must not be a file in -file', 'File',
        $test_file{'filename'}
    );
    is(
        ( $mode & S_IRUSR ) ? 1 : 0, 1,
        'test_mock_stat_not_file: Mocked example file must be readable by current user if -file',
        'File',
        $test_file{'filename'}
    );

    is( $size, 0, 'test_mock_stat_not_file: Mocked example file must be 0 bytes', 'File', $test_file{'filename'} );
    return 1;
}

sub test_mock_stat_specified_size ($sut) {
    ## no critic (ValuesAndExpressions::ProhibitMagicNumbers)
    my %test_file = _get_test_file();
    my ( $mode, $uid, $gid, $size, @stats );
    my $test_size = 46;
    $sut->mock_stat( $test_file{'filename'}, ( sprintf( 'size=%d', $test_size ) ) );
    is(
        $sut->is_mock_stat( $test_file{'filename'} ), 1,
        'test_mock_stat_specified_size: Mocked file should be mocked'
    );
    @stats = stat( $test_file{'filename'} );
    isnt(
        [], \@stats, 'test_mock_stat_specified: Mocked example file must be found with size', 'File',
        $test_file{'filename'}
    );
    ( $mode, $uid, $gid, $size ) = ( $stats[STAT_MODE], $stats[STAT_UID], $stats[STAT_GID], $stats[STAT_FILESIZE] );

    _test_stats_zero_values( 'test_mock_stat_specified_size', @stats );
    is(
        S_ISREG($mode) ? 1 : 0, 1, 'test_mock_stat_specified_size: Mocked example file must be a file with size',
        'File',
        $test_file{'filename'}
    );
    is(
        ( $mode & S_IRUSR ) ? 1 : 0, 1,
        'test_mock_stat_specified_size: Mocked example file must be readable by current user with size',
        'File',
        $test_file{'filename'}
    );

    is(
        $size, $test_size, sprintf( 'test_mock_stat_specified_size: Mocked example file must be %d bytes', $test_size ),
        'File', $test_file{'filename'}
    );
    return 1;
}

sub test_mock_remove_mock_stat () {
## no critic (ValuesAndExpressions::ProhibitMagicNumbers)
    my $sut       = $CLASS->new();                # we want a clean instance
    my %test_file = _get_test_file();
    my %secondary = _get_secondary_test_file();
    my ( $size, @stats );
    is(
        $sut->is_mock_stat( $test_file{'filename'} ), 0,
        'test_mock_remove_mock_stat: Main check should not be mocked'
    );
    @stats = stat( $test_file{'filename'} );
    ($size) = ( $stats[STAT_FILESIZE] );
    is(
        $size, $test_file{'size'},
        sprintf( 'test_mock_remove_mock_stat: Unmocked example file must be %d bytes', $test_file{'size'} ), 'File',
        $test_file{'filename'}
    );
    is(
        $sut->is_mock_stat( $secondary{'filename'} ), 0,
        'test_mock_remove_mock_stat: Secondary check should not be mocked'
    );
    @stats = stat( $secondary{'filename'} );
    ($size) = ( $stats[STAT_FILESIZE] );
    is(
        $size, $secondary{'size'},
        sprintf( 'test_mock_remove_mock_stat: Unmocked secondary example file must be %d bytes', $secondary{'size'} ),
        'File',
        $secondary{'filename'}
    );
    $sut->mock_stat( $test_file{'filename'}, 'size=45' );
    $sut->mock_stat( $secondary{'filename'}, 'size=234' );
    is(
        $sut->is_mock_stat( $test_file{'filename'} ), 1,
        'test_mock_remove_mock_stat: Main check should be mocked'
    );
    @stats = stat( $test_file{'filename'} );
    ($size) = ( $stats[STAT_FILESIZE] );
    is( $size, 45, 'test_mock_remove_mock_stat: Mocked example file must be 45 bytes', 'File', $test_file{'filename'} );
    is(
        $sut->is_mock_stat( $secondary{'filename'} ), 1,
        'test_mock_remove_mock_stat: Secondary check should be mocked'
    );
    @stats = stat( $secondary{'filename'} );
    ($size) = ( $stats[STAT_FILESIZE] );
    is(
        $size, 234, 'test_mock_remove_mock_stat: Mocked secondary example file must be 234 bytes', 'File',
        $secondary{'filename'}
    );

    # now to remove
    $sut->remove_mock_stat( $test_file{'filename'} );
    is(
        $sut->is_mock_stat( $test_file{'filename'} ), 0,
        'test_mock_remove_mock_stat: Main check should not be mocked'
    );
    @stats = stat( $test_file{'filename'} );
    ($size) = ( $stats[STAT_FILESIZE] );
    is(
        $size, $test_file{'size'}, 'test_mock_remove_mock_stat: Reverted example file must be correct size', 'File',
        $test_file{'filename'}
    );
    is(
        $sut->is_mock_stat( $secondary{'filename'} ), 1,
        'test_mock_remove_mock_stat: Secondary check should be mocked'
    );
    @stats = stat( $secondary{'filename'} );
    ($size) = ( $stats[STAT_FILESIZE] );
    is(
        $size, 234, 'test_mock_remove_mock_stat: Secondary example file should still be be 234 bytes', 'File',
        $secondary{'filename'}
    );
    return 1;
}

sub test_mock_remove_all_mock_stat () {
## no critic (ValuesAndExpressions::ProhibitMagicNumbers)
    my $sut       = $CLASS->new();                # we want a clean instance
    my %test_file = _get_test_file();
    my %secondary = _get_secondary_test_file();

    my ( $size, @stats );
    @stats = stat( $test_file{'filename'} );
    ($size) = ( $stats[STAT_FILESIZE] );
    is(
        $size, $test_file{'size'}, 'test_mock_remove_all_mock_stat: Unmocked example file must be correct size', 'File',
        $test_file{'filename'}
    );
    @stats = stat( $secondary{'filename'} );
    ($size) = ( $stats[STAT_FILESIZE] );
    is(
        $size,                                                                                  $secondary{'size'},
        'test_mock_remove_all_mock_stat: Unmocked secondary example file must be correct size', 'File',
        $secondary{'filename'}
    );
    $sut->mock_stat( $test_file{'filename'}, 'size=45' );
    $sut->mock_stat( $secondary{'filename'}, 'size=234' );
    is(
        $sut->is_mock_stat( $test_file{'filename'} ), 1,
        'test_mock_remove_all_mock_stat: Main check should be mocked'
    );
    is(
        $sut->is_mock_stat( $secondary{'filename'} ), 1,
        'test_mock_remove_all_mock_stat: Secondary check should be mocked'
    );
    @stats = stat( $test_file{'filename'} );
    ($size) = ( $stats[STAT_FILESIZE] );
    is(
        $size, 45, 'test_mock_remove_all_mock_stat: Mocked example file must be 45 bytes', 'File',
        $test_file{'filename'}
    );
    @stats = stat( $secondary{'filename'} );
    ($size) = ( $stats[STAT_FILESIZE] );
    is(
        $size, 234, 'test_mock_remove_all_mock_stat: Secondary example file must be 234 bytes', 'File',
        $secondary{'filename'}
    );

    # now to remove
    $sut->remove_all_mock_stat();
    is(
        $sut->is_mock_stat( $test_file{'filename'} ), 0,
        'test_mock_remove_all_mock_stat: Main check should be not be mocked'
    );
    is(
        $sut->is_mock_stat( $secondary{'filename'} ), 0,
        'test_mock_remove_all_mock_stat: Secondary check should not be mocked'
    );
    @stats = stat( $test_file{'filename'} );
    ($size) = ( $stats[STAT_FILESIZE] );
    is(
        $size, $test_file{'size'}, 'test_mock_remove_all_mock_stat: Unmocked example file must be correct size', 'File',
        $test_file{'filename'}
    );

    @stats = stat( $secondary{'filename'} );
    ($size) = ( $stats[STAT_FILESIZE] );
    is(
        $size, $secondary{'size'},
        'test_mock_remove_all_mock_stat: Unmocked secondary example file must be correct size',
        'File',
        $secondary{'filename'}
    );
    return 1;
}

sub _filesystem_check ( $filename, $length = 8192, $offset = undef, $contents = undef ) {
    my ($read);
    if ( defined($offset) && !defined($contents) ) {
        croak('Contents (even as an empty string) must be defined if offset is provided');
    }
    if ( open( my $filehandle, '<', $filename ) ) {    ## no critic(InputOutput::RequireBriefOpen)
        if ( defined($offset) ) {
            $read = read( $filehandle, $contents, $length, $offset );
            if ( !defined($read) ) {
                croak( sprintf( 'Unable to read file "%s": %s', $filename, ( $! || '[no error]' ) ) );
            }
        }
        else {
            $read = read( $filehandle, $contents, $length );
            if ( !defined($read) ) {
                croak( sprintf( 'Unable to read file "%s": %s', $filename, ( $! || '[no error]' ) ) );
            }
        }
        if ( !close $filehandle ) {
            croak( sprintf( 'Unable to close file "%s": %s', $filename, ( $! || '[no error]' ) ) );
        }
    }
    else {
        croak( sprintf( 'Unable to open file "%s": %s', $filename, ( $! || '[no error]' ) ) );
    }
    return $contents;
}

sub test_mock_filesystem_no_mock ($sut) {
    my %test_file = _get_test_file();
    my ( $mode, $uid, $gid, $size, @stats );
    is(
        $sut->is_mock_filesystem( $test_file{'filename'} ), 0,
        'test_mock_filesystem_no_mock: Main check should be not be mocked'
    );
    @stats = stat( $test_file{'filename'} );
    ( $mode, $uid, $gid, $size ) = ( $stats[STAT_MODE], $stats[STAT_UID], $stats[STAT_GID], $stats[STAT_FILESIZE] );
    is(
        $size,
        $test_file{'size'},
        'test_mock_filesystem_no_mock: Unmocked example file must be correct size',
        'File',
        $test_file{'filename'}
    );
    my $results = _filesystem_check( $test_file{'filename'} );
    is(
        $results,
        $test_file{'contents'},
        'test_mock_filesystem_no_mock: Should return contents of file with no errors'
    );
    return 1;
}

sub test_mock_filesystem_not_openable ($sut) {
    my %test_file = _get_test_file();
    $sut->mock_filesystem( $test_file{'filename'}, undef, ('-open') );
    is(
        $sut->is_mock_filesystem( $test_file{'filename'} ), 1,
        'test_mock_filesystem_no_mock: Main check should be be mocked'
    );
    my ( $results, $dies, $expected, $size, @stats );
    @stats = stat( $test_file{'filename'} );
    ($size) = ( $stats[STAT_FILESIZE] );
    is(
        $size, 0, 'test_mock_filesystem_not_openable: If not openable, size should be 0', 'File',
        $test_file{'filename'}
    );
    $dies = dies {
        $results = _filesystem_check( $test_file{'filename'} );
    } || 'did not die';
    $expected = sprintf( 'Unable to open file "%s": %s', $test_file{'filename'}, 'Operation not permitted' );
    starts_with( $dies, $expected, 'test_mock_filesystem_not_openable: Should provide default error' );
    $sut->mock_filesystem( $test_file{'filename'}, undef, ( 'open=' . ENOENT ) );
    @stats = stat( $test_file{'filename'} );
    ($size) = ( $stats[STAT_FILESIZE] );
    is(
        $size, 0, 'test_mock_filesystem_not_openable: If not openable, size should be 0', 'File',
        $test_file{'filename'}
    );
    $dies = dies {
        $results = _filesystem_check( $test_file{'filename'} );
    } || 'did not die';
    $expected = sprintf( 'Unable to open file "%s": %s', $test_file{'filename'}, 'No such file or directory' );
    starts_with( $dies, $expected, 'test_mock_filesystem_not_openable: Should provide specified error' );
    return 1;
}

sub test_mock_filesystem_not_readable ($sut) {
    my %test_file = _get_test_file();
    my ( $results, $dies, $expected, $size, $dummy_content, @stats );
    $dummy_content = 'hello there';

    # first with default error and no content
    $sut->mock_filesystem( $test_file{'filename'}, undef, ('-read') );
    @stats = stat( $test_file{'filename'} );
    ($size) = ( $stats[STAT_FILESIZE] );
    is(
        $size, 0, 'test_mock_filesystem_not_readable: If not readable, size should default to 0',
        'File',
        $test_file{'filename'}
    );
    $dies = dies {
        $results = _filesystem_check( $test_file{'filename'} );
    } || 'did not die';
    $expected = sprintf( 'Unable to read file "%s": %s', $test_file{'filename'}, 'Input/output error' );
    starts_with( $dies, $expected, 'test_mock_filesystem_not_readable: Should provide default error' );

    # now with default error and fake content
    $sut->mock_filesystem( $test_file{'filename'}, $dummy_content, ('-read') );
    @stats = stat( $test_file{'filename'} );
    ($size) = ( $stats[STAT_FILESIZE] );
    is(
        $size,
        length($dummy_content),
        'test_mock_filesystem_not_readable: If not readable, size should be provided content',
        'File',
        $test_file{'filename'}
    );
    $dies = dies {
        $results = _filesystem_check( $test_file{'filename'} );
    } || 'did not die';
    $expected = sprintf( 'Unable to read file "%s": %s', $test_file{'filename'}, 'Input/output error' );
    starts_with( $dies, $expected, 'test_mock_filesystem_not_readable: Should provide default error' );

    # now with specified error
    $sut->mock_filesystem( $test_file{'filename'}, undef, ( 'read=' . ENOENT ) );
    @stats = stat( $test_file{'filename'} );
    ($size) = ( $stats[STAT_FILESIZE] );
    is(
        $size, 0, 'test_mock_filesystem_not_readable: If not readable, size should default to 0', 'File',
        $test_file{'filename'}
    );
    $dies = dies {
        $results = _filesystem_check( $test_file{'filename'} );
    } || 'did not die';
    $expected = sprintf( 'Unable to read file "%s": %s', $test_file{'filename'}, 'No such file or directory' );
    starts_with( $dies, $expected, 'test_mock_filesystem_not_readable: Should provide specified error' );

    # now with specified error and fake content
    $sut->mock_filesystem( $test_file{'filename'}, $dummy_content, ( 'read=' . ENOENT ) );
    @stats = stat( $test_file{'filename'} );
    ($size) = ( $stats[STAT_FILESIZE] );
    is(
        $size,
        length($dummy_content),
        'test_mock_filesystem_not_readable: If not readable, size should be provided content',
        'File',
        $test_file{'filename'}
    );
    $dies = dies {
        $results = _filesystem_check( $test_file{'filename'} );
    } || 'did not die';
    $expected = sprintf( 'Unable to read file "%s": %s', $test_file{'filename'}, 'No such file or directory' );
    starts_with( $dies, $expected, 'test_mock_filesystem_not_readable: Should provide specified error' );
    return 1;
}

sub test_mock_filesystem_readable_but_no_contents ($sut) {
    my %test_file = _get_test_file();
    my $dies      = dies {
        $sut->mock_filesystem( $test_file{'filename'}, undef, ('-close') );
    };
    starts_with(
        $dies, 'mock_filesystem: If read is enabled, contents must be set',
        'test_mock_filesystem_readable_but_no_contents: If mocked file is readable, there needs to be contents'
    );
    return 1;
}

sub test_mock_filesystem_not_closable ($sut) {
    my %test_file = _get_test_file();
    my ( $results, $dies, $expected, $dummy_content, $size, @stats );
    $dummy_content = 'something goes here';

    # first with default error
    $sut->mock_filesystem( $test_file{'filename'}, $dummy_content, ('-close') );
    @stats = stat( $test_file{'filename'} );
    ($size) = ( $stats[STAT_FILESIZE] );
    is(
        $size, length($dummy_content),
        'test_mock_filesystem_not_closable: If not closable, size should default content size',
        'File',
        $test_file{'filename'}
    );
    $dies = dies {
        $results = _filesystem_check( $test_file{'filename'} );
    } || 'did not die';
    $expected = sprintf( 'Unable to close file "%s": %s', $test_file{'filename'}, 'Input/output error' );
    starts_with( $dies, $expected, 'test_mock_filesystem_not_closable: Should provide default error' );

    # and now specified error
    $sut->mock_filesystem( $test_file{'filename'}, $dummy_content, ( 'close=' . ENOENT ) );
    @stats = stat( $test_file{'filename'} );
    ($size) = ( $stats[STAT_FILESIZE] );
    is(
        $size, length($dummy_content),
        'test_mock_filesystem_not_closable: If not closable, size should default content size',
        'File',
        $test_file{'filename'}
    );
    $dies = dies {
        $results = _filesystem_check( $test_file{'filename'} );
    } || 'did not die';
    $expected = sprintf( 'Unable to close file "%s": %s', $test_file{'filename'}, 'No such file or directory' );
    starts_with( $dies, $expected, 'test_mock_filesystem_not_closable: Should provide specified error' );
    return 1;
}

sub test_mock_filesystem_working ($sut) {
    my %test_file = _get_test_file();
    my ( $results, $dies, $expected, $dummy_content, $size, @stats );
    $dummy_content = 'hello';

    $sut->mock_filesystem( $test_file{'filename'}, $dummy_content, ('+open +read +close') );
    @stats = stat( $test_file{'filename'} );
    ($size) = ( $stats[STAT_FILESIZE] );
    is(
        $size, length($dummy_content),
        'test_mock_filesystem_working: If working, size should be content size',
        'File',
        $test_file{'filename'}
    );
    $results = _filesystem_check( $test_file{'filename'} );
    starts_with( $results, $dummy_content, 'test_mock_filesystem_working: Should provide content' );
    $sut->remove_mock_filesystem( $test_file{'filename'} );
    return 1;
}

sub test_mock_filesytem_override_open ($sut) {
    ## no critic (ValuesAndExpressions::ProhibitMagicNumbers)
    my $contents;
    my %test_file = _get_test_file();
    my %secondary = _get_secondary_test_file();

    # 3 argument: check for non-scalars
    my $temp = 'hello testing goes here';
    $contents = _filesystem_check( \$temp );
    is( $contents, $temp, 'test_mock_filesytem_override_open: Non-scalar filehandles should bypass' );

    # 3 argument: not recognised
    $sut->mock_filesystem( $test_file{'filename'}, undef, ('-open') );
    $contents = _filesystem_check( $secondary{'filename'} );
    is( $contents, $secondary{'contents'}, 'test_mock_filesytem_override_open: Non-matching should bypass' );

    # 1 argument via global variable
    my $dies = dies {
        open(GLOBAL_TEST)    ## no critic (InputOutput::ProhibitBarewordFileHandles,InputOutput::ProhibitTwoArgOpen)
          || croak( sprintf( 'Unable to open %s: %s', $GLOBAL_TEST . $! ) );
    }
      || 'failed to die';
    starts_with(
        $dies,
        'Overrider cannot cope with 1 argument "Open" commands: only 2 (with no override) or 3 (with or without override)',
        'test_mock_filesytem_override_open: Should reject single args'
    );

    # 4 arguments (?!?)
    $dies = dies {
        open( my $a, '<', $test_file{'filename'}, 'dummy' )
          || croak( sprintf( 'Unable to open %s: %s', $test_file{'filename'} . $! ) );
        close($a) || croak( sprintf( 'Unable to close %s: %s', $test_file{'filename'} . $! ) );
    }
      || 'failed to die';
    starts_with(
        $dies,
        'Overrider cannot cope with 4 argument "Open" commands: only 2 (with no override) or 3 (with or without override)',
        'test_mock_filesytem_override_open: Should reject 4 or more args'
    );

    # 2 arguments (old style)
    my $two_arg = sprintf( '<%s', $test_file{'filename'} );
    open( my $fh, $two_arg )    ## no critic (InputOutput::ProhibitTwoArgOpen)
      || croak( sprintf( 'Unable to open %s using 2 args', $test_file{'filename'} ) );
    read( $fh, $contents, 8192 ) || croak( sprintf( 'Unable to read %s using open 2 args',  $test_file{'filename'} ) );
    close($fh)                   || croak( sprintf( 'Unable to close %s using open 2 args', $test_file{'filename'} ) );
    is(
        $contents, $test_file{'contents'},
        'test_mock_filesytem_override_open: 2 arg open Should bypass the overrider'
    );

    # cannot handle write mode
    $dies = dies {
        open( my $fh, '>', $test_file{'filename'} ) || croak('did not open');
        close($fh)                                  || croak('did not close');
    } || 'failed to die';
    starts_with(
        $dies, 'Only read "<" is currently accepted as a mocked "open mode" option',
        'test_mock_filesytem_override_open: Confirm only read accepted'
    );
    $sut->remove_all_mock_filesystem();
    return 1;
}

sub test_mock_filesytem_override_read ($sut) {
    my %test_file = _get_test_file();
    is(
        $sut->is_mock_filesystem( $test_file{'filename'} ), 0,
        'test_mock_filesytem_override_read: Should not be mocked'
    );
    _run_read_tests(
        $test_file{'filename'}, $test_file{'contents'},
        'test_mock_filesytem_override_read: Unmocked main'
    );
    my $expected_full_text = 'testing content goes here';
    $sut->mock_filesystem( $test_file{'filename'}, $expected_full_text );
    is(
        $sut->is_mock_filesystem( $test_file{'filename'} ), 1,
        'test_mock_filesytem_override_read: Should be mocked'
    );

    _run_read_tests(
        $test_file{'filename'}, $expected_full_text,
        'test_mock_filesytem_override_read: Mocked main'
    );
    $sut->remove_all_mock_filesystem();
    return 1;
}

sub _run_read_tests ( $filename, $string, $testname ) {
## no critic (ValuesAndExpressions::ProhibitMagicNumbers)
    my $dies;
    _read_test( $filename, $string, $testname, 10 );
    _read_test( $filename, $string, $testname, 3,  2 );
    _read_test( $filename, $string, $testname, 10, 5 );

    # negative offsets (too low)
    my $crmsg = 'Unable to %s for negative offset read failure: %s';
    $dies = dies {
        my $contents;
        open( my $fh, '<', $filename )     || croak( sprintf( $crmsg, 'open',  $! || '[no error]' ) );
        read( $fh, $contents, 8192, -200 ) || croak( sprintf( $crmsg, 'read',  $! || '[no error]' ) );
        close($fh)                         || croak( sprintf( $crmsg, 'close', $! || '[no error]' ) );
    } || 'failed to die for negative offset read';
    starts_with(
        $dies, 'Offset outside string ',
        sprintf( '%s: Negative offset check', $testname )
    );

    # high offsets
    $crmsg = 'Unable to %s for high offset read failure: %s';
    $dies  = dies {
        my $contents = 'some dummy contents go here.';
        my $expected = $contents . "\0" x ( 50 - length($contents) ) . $string;
        open( my $fh, '<', $filename )   || croak( sprintf( $crmsg, 'open',  $! || '[no error]' ) );
        read( $fh, $contents, 8192, 50 ) || croak( sprintf( $crmsg, 'read',  $! || '[no error]' ) );
        close($fh)                       || croak( sprintf( $crmsg, 'close', $! || '[no error]' ) );
        is(
            $contents, $expected,
            sprintf( '%s: High offset should be null byte padded', $testname )
        );
    } || 'should not die during high offset tests';
    is(
        $dies, 'should not die during high offset tests',
        sprintf( '%s: Should not die during high offset read tests', $testname ), 'die message', $! || '[no error]'
    );
    return 1;
}

sub test_mock_filesystem_override_seek ($sut) {

    my %test_file = _get_test_file();
    my $check     = sub ( $filename, $text, $testname ) {
## no critic (ValuesAndExpressions::ProhibitMagicNumbers,InputOutput::RequireBriefOpen)
        my ( $size, $extract, $curpos ) = ( 4, q{}, 0 );
        my $crmsg = '%s: Unable to %s: %s';
        open( my $fh, '<', $filename ) || croak( sprintf( $crmsg, $testname, 'open',  $! || '[no error]' ) );
        read( $fh, $extract, $size )   || croak( sprintf( $crmsg, $testname, 'read1', $! || '[no error]' ) );
        is(
            $extract, substr( $text, $curpos, $size ),
            sprintf( '%s: Extracted text from %d for %d bytes should be identical', $testname, $curpos, $size )
        );
        seek( $fh, 2, SEEK_SET ) || croak( sprintf( $crmsg, $testname, 'seek2', $! || '[no error]' ) );
        $curpos = 2;
        read( $fh, $extract, $size ) || croak( sprintf( $crmsg, $testname, 'read2', $! || '[no error]' ) );
        is(
            $extract, substr( $text, $curpos, $size ),
            sprintf( '%s: Extracted text from %d for %d bytes should be identical', $testname, $curpos, $size )
        );
        $curpos += $size;
        seek( $fh, 3, SEEK_CUR ) || croak( sprintf( $crmsg, $testname, 'seek3', $! || '[no error]' ) );
        $curpos += 3;
        read( $fh, $extract, $size ) || croak( sprintf( $crmsg, $testname, 'read3', $! || '[no error]' ) );
        is(
            $extract, substr( $text, $curpos, $size ),
            sprintf( '%s: Extracted text from %d for %d bytes should be identical', $testname, $curpos, $size ), $text
        );
        seek( $fh, -6, SEEK_END )    || croak( sprintf( $crmsg, $testname, 'seek4', $! || '[no error]' ) );
        read( $fh, $extract, $size ) || croak( sprintf( $crmsg, $testname, 'read4', $! || '[no error]' ) );
        is(
            $extract, substr( $text, -6, $size ),
            sprintf( '%s: Extracted text from -6 from end for %d bytes should be identical', $testname, $size )
        );
        close($fh) || croak( sprintf( $crmsg, $testname, 'close', $! || '[no error]' ) );
        return 1;
    };
    is(
        $sut->is_mock_filesystem( $test_file{'filename'} ), 0,
        'test_mock_filesystem_seek: Should not be mocked'
    );
    $check->( $test_file{'filename'}, $test_file{'contents'}, 'test_mock_filesystem_override_seek: Unmocked' );

    # now to replace with a mock.
    my $expected_full_text = 'testing content goes here yes it does';
    $sut->mock_filesystem( $test_file{'filename'}, $expected_full_text );
    $check->( $test_file{'filename'}, $expected_full_text, 'test_mock_filesystem_override_seek: Mocked' );

    $sut->remove_all_mock_filesystem();
    return 1;
}

sub test_mock_filesystem_multiple_reads ($sut) {

    my ( %results, %expect );
    my @default_blocksizes = ( 3, 6, 12 );                  ## no critic (ValuesAndExpressions::ProhibitMagicNumbers)
    my $comp               = sub ( $text, @blocksizes ) {
        my ( $counter, $curpos, $current_contents ) = ( 0, 0, q{} );
        my %expected;
        $expected{'original'} = $current_contents;
        for my $blocksize (@blocksizes) {
            $current_contents                    = substr( $text, $curpos, $blocksize );
            $expected{ 'contents_' . $counter }  = $current_contents;
            $expected{ 'blocksize_' . $counter } = $blocksize;
            $expected{ 'read_' . $counter }      = length($current_contents);
            $curpos += $blocksize;
            $counter++;
        }
        $expected{'counter'} = $counter;
        return %expected;
    };
    my %test_file = _get_test_file();

    # start tests
    is(
        $sut->is_mock_filesystem( $test_file{'filename'} ), 0,
        'test_mock_filesystem_override_multiple_reads: Should not be mocked'
    );
    %results = _multiple_read_test( $test_file{'filename'}, \@default_blocksizes );
    %expect  = $comp->( $test_file{'contents'}, @default_blocksizes );

    is(
        \%results, \%expect,
        'test_mock_filesystem_override_multiple_reads: Unmocked details should match',
        'Results', %results,
        'Expect',  %expect
    );

    # now to replace with a mock.
    my $expected_full_text = 'testing content goes here';
    $sut->mock_filesystem( $test_file{'filename'}, $expected_full_text );
    is(
        $sut->is_mock_filesystem( $test_file{'filename'} ), 1,
        'test_mock_filesystem_override_multiple_reads: Should be mocked'
    );
    %results = _multiple_read_test( $test_file{'filename'}, \@default_blocksizes );
    %expect  = $comp->( $expected_full_text, @default_blocksizes );
    is(
        \%results, \%expect,
        'test_mock_filesystem_override_multiple_reads: Mocked details should match',
        'Results', %results,
        'Expect',  %expect
    );
    $sut->remove_mock_filesystem( $test_file{'filename'} );

    $sut->remove_all_mock_filesystem();
    return 1;
}

sub _multiple_read_test ( $filename, $blocksizeref, $offset = undef, $contents = undef ) {
    my ($read) = (0);
    my @default_blocksizes = ( 3, 6, 12 );    ## no critic (ValuesAndExpressions::ProhibitMagicNumbers)
    my ( %return, @blocksizes );
    @blocksizes = @default_blocksizes;
    if ( defined($blocksizeref) ) {
        if ( ref($blocksizeref) eq 'ARRAY' ) {
            @blocksizes = @{$blocksizeref};
        }
        else {
            croak(
                sprintf(
                    'Invalid blocksizeref passed to _multiple_read_test: %s',
                    ref($blocksizeref) || 'scalar:' . $blocksizeref
                )
            );
        }
    }

    if ( defined($offset) && !defined($contents) ) {
        croak('Contents (even as an empty string) must be defined if offset is provided');
    }
    $return{'original'} = $contents || q{};
    ## no critic (InputOutput::RequireBriefOpen)
    open( my $filehandle, '<', $filename )
      || croak( sprintf( 'Failed to open "%s": %s', $filename, ( $! || '[no error]' ) ) );
    my $counter = 0;
    for my $blocksize (@blocksizes) {
        if ( defined($offset) ) {
            $read = read( $filehandle, $contents, $blocksize, $offset );
        }
        else {
            $read = read( $filehandle, $contents, $blocksize );
        }
        $return{ 'contents_' . $counter }  = $contents || q{};
        $return{ 'blocksize_' . $counter } = $blocksize;
        $return{ 'read_' . $counter }      = $read;
        $counter++;
    }
    $return{'counter'} = $counter;
    close($filehandle) || croak( sprintf( 'Failed to close "%s": %s', $filename, ( $! || '[no error]' ) ) );
    return %return;
}

sub _read_test ( $filename, $string, $testname, $length = undef, $offset = undef ) {
    my $message = sprintf(
        '%s: Should not die testing length %d and offset %d', $testname,
        ( defined($length) ? $length : 'any' ),
        ( defined($offset) ? $offset : 0 )
    );

    my $original_contents = undef;
    if ( defined($offset) ) {
        $original_contents = '0123456789012345678901234567890123456789012345678901234567890123456789';
    }
    my $contents = $original_contents;
    my $dies     = dies {
        my $got      = _filesystem_check( $filename, $length, $offset, $contents );
        my $expected = $string;
        if ( defined($length) ) {
            $expected = substr( $expected, 0, $length );
        }
        if ( defined($offset) ) {
            $expected = substr( $original_contents, 0, $offset ) . $expected;
        }
        is(
            $got,
            $expected,
            sprintf(
                '%s: Expected read text of length %d from offset %d',
                $testname,
                ( defined($length) ? $length : 'any' ),
                ( defined($offset) ? $offset : 0 )
            ),
            'File',
            $filename
        );
    } || $message;
    is(
        $dies,
        $message,
        $message,
        'Error', ( $! || '[no error message]' )
    );
    return 1;
}

sub test_mock_remove_mock_filesystem () {
    my $sut       = $CLASS->new();                # we want a clean instance
    my %test_file = _get_test_file();
    my %secondary = _get_secondary_test_file();
    is(
        $sut->is_mock_filesystem( $test_file{'filename'} ), 0,
        'test_mock_remove_mock_filesystem: Main check should not be mocked at start'
    );
    is(
        _filesystem_check( $test_file{'filename'} ), $test_file{'contents'},
        'test_mock_remove_mock_filesystem: Main check should return contents at start'
    );
    is(
        $sut->is_mock_filesystem( $secondary{'filename'} ), 0,
        'test_mock_remove_mock_filesystem: Secondary check should not be mocked at start'
    );
    is(
        _filesystem_check( $secondary{'filename'} ), $secondary{'contents'},
        'test_mock_remove_mock_filesystem: Secondary check should return contents at start'
    );
    my $main_mocked      = 'hello there';
    my $secondary_mocked = 'something else';
    $sut->mock_filesystem( $test_file{'filename'}, $main_mocked );
    $sut->mock_filesystem( $secondary{'filename'}, $secondary_mocked );
    is(
        $sut->is_mock_filesystem( $test_file{'filename'} ), 1,
        'test_mock_remove_mock_filesystem: Main check should be mocked'
    );
    is(
        _filesystem_check( $test_file{'filename'} ), $main_mocked,
        'test_mock_remove_mock_filesystem: Main check should return mocked contents'
    );
    is(
        $sut->is_mock_filesystem( $secondary{'filename'} ), 1,
        'test_mock_remove_mock_filesystem: Secondary check should be mocked'
    );
    is(
        _filesystem_check( $secondary{'filename'} ), $secondary_mocked,
        'test_mock_remove_mock_filesystem: Secondary check should return mocked contents'
    );

    # now to remove
    $sut->remove_mock_filesystem( $test_file{'filename'} );
    is(
        $sut->is_mock_filesystem( $test_file{'filename'} ), 0,
        'test_mock_remove_mock_filesystem: Main check should not be mocked after remove'
    );
    is(
        _filesystem_check( $test_file{'filename'} ), $test_file{'contents'},
        'test_mock_remove_mock_filesystem: Main check should return original contents after remove'
    );
    is(
        $sut->is_mock_filesystem( $secondary{'filename'} ), 1,
        'test_mock_remove_mock_filesystem: Secondary check should still be mocked after remove'
    );
    is(
        _filesystem_check( $secondary{'filename'} ), $secondary_mocked,
        'test_mock_remove_mock_filesystem: Secondary check should return mocked contents after remove'
    );
    return 1;
}

sub test_mock_remove_all_mock_filesystem () {
    my $sut       = $CLASS->new();                # we want a clean instance
    my %test_file = _get_test_file();
    my %secondary = _get_secondary_test_file();
    is(
        $sut->is_mock_filesystem( $test_file{'filename'} ), 0,
        'test_mock_remove_all_mock_filesystem: Main check should not be mocked'
    );
    is(
        _filesystem_check( $test_file{'filename'} ), $test_file{'contents'},
        'test_mock_remove_all_mock_filesystem: Main check should return contents'
    );
    is(
        $sut->is_mock_filesystem( $secondary{'filename'} ), 0,
        'test_mock_remove_all_mock_filesystem: Secondary check should not be mocked'
    );
    is(
        _filesystem_check( $secondary{'filename'} ), $secondary{'contents'},
        'test_mock_remove_all_mock_filesystem: Secondary check should return contents'
    );
    my $main_mocked      = 'hello there';
    my $secondary_mocked = 'something else';
    $sut->mock_filesystem( $test_file{'filename'}, $main_mocked );
    $sut->mock_filesystem( $secondary{'filename'}, $secondary_mocked );
    is(
        $sut->is_mock_filesystem( $test_file{'filename'} ), 1,
        'test_mock_remove_all_mock_filesystem: Main check should be mocked'
    );
    is(
        _filesystem_check( $test_file{'filename'} ), $main_mocked,
        'test_mock_remove_all_mock_filesystem: Main check should return mocked contents'
    );
    is(
        $sut->is_mock_filesystem( $secondary{'filename'} ), 1,
        'test_mock_remove_all_mock_filesystem: Secondary check should be mocked'
    );
    is(
        _filesystem_check( $secondary{'filename'} ), $secondary_mocked,
        'test_mock_remove_all_mock_filesystem: Secondary check should return mocked contents'
    );

    # now to remove
    $sut->remove_all_mock_filesystem();
    is(
        $sut->is_mock_filesystem( $test_file{'filename'} ), 0,
        'test_mock_remove_all_mock_filesystem: Main check should not be mocked'
    );
    is(
        _filesystem_check( $test_file{'filename'} ), $test_file{'contents'},
        'test_mock_remove_all_mock_filesystem: Main check should return contents'
    );
    is(
        $sut->is_mock_filesystem( $secondary{'filename'} ), 0,
        'test_mock_remove_all_mock_filesystem: Secondary check should not be mocked'
    );
    is(
        _filesystem_check( $secondary{'filename'} ), $secondary{'contents'},
        'test_mock_remove_all_mock_filesystem: Secondary check should return contents'
    );
    return 1;
}

sub dummy_subroutine ( $name, $title, $ignore ) {
    return sprintf( '%s %s!', $name, $title );
}

sub other_dummy ($name) {
    return sprintf( 'Test of %s', $name );
}
