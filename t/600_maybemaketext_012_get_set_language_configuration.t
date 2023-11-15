#!perl

# covers:
#  - maybe_maketext_get_language_configuration
#  - maybe_maketext_set_language_configuration
use strict;
use warnings;
use vars;
use File::Basename();
use File::Spec();
use lib File::Spec->catdir( File::Basename::dirname( File::Spec->rel2abs(__FILE__) ), q/lib/ );
use Locale::MaybeMaketext::Tests::Base qw/:all/;
use Locale::MaybeMaketext::Tests::Overrider();
use Test2::Tools::Target 'Locale::MaybeMaketext';
use feature qw/signatures state lexical_subs/;
no if $] >= 5.032, q|feature|, qw/indirect/;
no warnings qw/experimental::signatures experimental::lexical_subs/;

my $overrider = Locale::MaybeMaketext::Tests::Overrider->new();

subtest_buffered(
    'initial_check',
    sub {
        my @settings = $CLASS->MAYBE_MAKETEXT_DEFAULT_LANGUAGE_SETTINGS;
        is(
            [ $CLASS->maybe_maketext_get_language_configuration() ], \@settings,
            'initial_check: "No language settings" should be the default'
        );

        starts_with(
            dies {
                $CLASS->maybe_maketext_set_language_configuration();
            },
            'Invalid call: Must be passed a list of actions',
            'initial_check: Should die if no parameters'
        );
        $CLASS->maybe_maketext_reset();
        is(
            [ $CLASS->maybe_maketext_get_language_configuration() ], \@settings,
            'initial_check: Should be empty after reset'
        );
    }
);

my @callstack = ();
$overrider->override(
    'Locale::MaybeMaketext::LanguageFinder::set_configuration',
    sub ( $class, @list_of_actions ) {
        push @callstack, 'set_configuration: ' . join( ', ', @list_of_actions );
        return qw/hello this works/;
    }
);
is(
    [ $CLASS->maybe_maketext_set_language_configuration(qw/testing something here/) ],
    [qw/hello this works/], 'initial_check: ensure it is all routed through the main method'
);
is( \@callstack, ['set_configuration: testing, something, here'], 'initial check: Checking callstack' );
$overrider->reset_all();

done_testing();
