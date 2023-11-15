#!perl

use strict;
use warnings;
use vars;
use feature qw/signatures/;
no warnings qw/experimental::signatures/;
use File::Basename();
use File::Spec();
use lib File::Spec->catdir( File::Basename::dirname( File::Spec->rel2abs(__FILE__) ), q/lib/ );
use Locale::MaybeMaketext::Tests::Base qw/:all/;
use Test2::Tools::Target 'Locale::MaybeMaketext';
use Locale::MaybeMaketext qw/:all/;

# Dependency on _maybe_maketext_create_localizer
test_get_handle();
test_get_handle_not_found();

done_testing();

sub test_get_handle() {
    Locale::MaybeMaketext::maybe_maketext_reset();
    Locale::MaybeMaketext::maybe_maketext_add_text_domains( 'main' => 'Locale::MaybeMaketext::Tests::DummyLangs' );
    Locale::MaybeMaketext::maybe_maketext_set_language_configuration(qw/provided die/);
    Locale::MaybeMaketext::maybe_maketext_set_only_specified_localizers(qw/Locale::MaybeMaketext::FallbackLocalizer/);
    print "==== Fetching handle ====\n";
    my $handle = $CLASS->get_handle(qw/en-nz/);
    print "==== Translating ...\n";
    my $text = $handle->maketext( 'Hello get handle [_1]!', 'here' );

    is( $text, 'Kia ora get handle test here', 'test_get_handle_default: Should translate' );
    return 1;
}

sub test_get_handle_not_found() {
    Locale::MaybeMaketext::maybe_maketext_reset();
    maybe_maketext_add_text_domains( 'main' => 'Locale::MaybeMaketext::Tests::DummyLangs' );
    my $handle = $CLASS->get_handle(qw/fr de en/);
    warn('Processing text!**************************');
    my $text = $handle->maketext( 'Hello get handle [_1]!', 'here' );

    is( $text, 'Kia ora get handle test here', 'test_get_handle_default: Should translate' );
    return 1;
}
