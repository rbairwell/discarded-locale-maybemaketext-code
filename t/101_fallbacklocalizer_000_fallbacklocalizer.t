#!perl
## no critic (RegularExpressions::ProhibitComplexRegexes)
use strict;
use warnings;
use vars;
use File::Basename();
use File::Spec();
use lib File::Spec->catdir( File::Basename::dirname( File::Spec->rel2abs(__FILE__) ), q/lib/ );
use Locale::MaybeMaketext::Tests::Base qw/:all/;
use feature                            qw/signatures/;
no warnings qw/experimental::signatures/;
use Test2::Tools::Target 'Locale::MaybeMaketext::FallbackLocalizer';
use Locale::MaybeMaketext::FallbackLocalizer();

subtest_buffered( 'check_get_handle',               \&check_get_handle );
subtest_buffered( 'check_not_implemented',          \&check_not_implemented );
subtest_buffered( 'check_maketext',                 \&check_maketext );
subtest_buffered( 'check_maketext_not_interpreted', \&check_maketext_not_interpreted );
done_testing();

sub check_get_handle {
    my $handle = $CLASS->get_handle();
    is(
        ref($handle), $CLASS,
        'FallbackLocalizer: check_get_handle Should return a blessed instance of itself with no languages'
    );
    $handle = $CLASS->get_handle(qw/en-gb en en-us/);
    is(
        ref($handle), $CLASS,
        'FallbackLocalizer: check_get_handle Should return a blessed instance of itself with random languages'
    );

    # new should work the same
    $handle = $CLASS->new();
    is(
        ref($handle), $CLASS,
        'FallbackLocalizer: check_get_handle: new Should return a blessed instance of itself with no languages'
    );
    $handle = $CLASS->new(qw/en-gb en en-us/);
    is(
        ref($handle), $CLASS,
        'FallbackLocalizer: check_get_handle: new Should return a blessed instance of itself with random languages'
    );
    return 1;
}

sub check_not_implemented {
    my @not_implemented = qw/allowlist whitelist denylist blacklist fail_with failure_handler_auto/;
    my $handle          = $CLASS->get_handle();
    for my $method (@not_implemented) {
        like(
            dies {
                no strict 'refs';    ## no critic (TestingAndDebugging::ProhibitNoStrict)
                my $ref = \&{"${CLASS}::${method}"};
                $ref->('xyz');
            },
            qr/\A$method must be called as a method. Use get_handle to get an instance. Otherwise not implemented./,
            sprintf( 'FallbackLocalizer: %s call syntax', $method )
        );
        like(
            warning {
                is( $handle->$method('hello'), 1, sprintf( 'FallbackLocalizer: %s should return 1', $method ) );
            },
            qr/\A$method called - not implemented./,
            sprintf( 'FallbackLocalizer: %s should issue a warning that it is not implemented if called', $method )
        );
    }
    return 1;
}

sub check_maketext {
    my $handle = $CLASS->get_handle();
    is(
        $handle->maketext('Test of [_0]'), 'Test of i-default',
        'FallbackLocalizer: Index 0 should be language and should default to i-default'
    );

    $handle = $CLASS->get_handle( 'en_gb', 'en_us' );
    is( ref($handle), $CLASS, 'FallbackLocalizer: Should return a blessed instance of itself' );
    is(
        $handle->maketext( 'Hello [_1] there. How are you [_2] [_1]?', 'tester', 'today' ),
        'Hello tester there. How are you today tester?',
        'FallbackLocalizer: Simple replacements should work'
    );
    is(
        $handle->maketext(
            'This [_1] is a [_2 ,_3] in [  _0 ]. Okay [ _4 ]? This concludes [ _-2 ]/[_-2].', 'here', 'complex', 'test',
            'person'
        ),
        'This here is a complex test in   en_gb . Okay  person ? This concludes  test /test.',
        'FallbackLocalizer: More complex replacements should work (should preserve spaces)'
    );
    is(
        $handle->maketext(
            'Hello, [ ] empty [    ] brackets should be ignored/left in place, okay? [_1] - along with [,_2,] empty commas!',
            'Yep!', 'multiple'
        ),
        'Hello, [ ] empty [    ] brackets should be ignored/left in place, okay? Yep! - along with multiple empty commas!',
        'FallbackLocalizer: Empty brackets should be left in place'
    );

    like(
        dies {
            $handle->maketext( 'Let\'s replace [_1], [_2], [_3], [_45] items!', 'one', 'two', 'three', 'four' );
        },
        qr/\Amaketext parameter mismsatched. Passed in 45 : only 4 parameters sent/,
        'FallbackLocalizer: check parameter counts'
    );
    return 1;
}

sub check_maketext_not_interpreted {
    my $handle = $CLASS->get_handle();
    my @inputs = (
        'Your search matched [quant,_1,document]!',
        '[quant,_1,file,files,No files] matched your query.',
        '[quant,_1,document] were matched',
        '[quant,_1,document was, documents were]',
        'Couldn\'t access datanode [sprintf,%10x=~[%s~],_1,_2]!',
    );
    for (@inputs) {
        is( $_, $_, sprintf( 'Expected string "%s" to remain same as we are simple localizer', $_ ), $_ );
    }
    return 1;
}
