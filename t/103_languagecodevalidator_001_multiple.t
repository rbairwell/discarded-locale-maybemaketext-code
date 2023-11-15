#!perl
use strict;
use warnings;
use vars;
use File::Basename();
use File::Spec();
use lib File::Spec->catdir( File::Basename::dirname( File::Spec->rel2abs(__FILE__) ), q/lib/ );
use Locale::MaybeMaketext::Tests::Base qw/:all/;
use Locale::MaybeMaketext::Cache();
use Test2::Tools::Target 'Locale::MaybeMaketext::LanguageCodeValidator';
use Locale::MaybeMaketext::LanguageCodeValidator();

my @input = qw/en-gb en-Latn-GB-boont-u-extended-sequence-x-private en-US-t-islamca es-419 hy-Latn-IT-arevela/;
push @input, \sub() { };
push @input, qw/i-enochian de-419-DE de-Qabt en-uk/;
my $object  = Locale::MaybeMaketext::LanguageCodeValidator->new( 'cache' => Locale::MaybeMaketext::Cache->new() );
my %results = $object->validate_multiple(@input);
my @expected_languages =
  qw/en_gb en_latn_gb_boont_u_extended_sequence_x_private en_us_t_islamca es_419 hy_latn_it_arevela i_enochian en_gb/;
my @invalid_languages = ( '[Type: REF] at position 5', 'de-419-DE', 'de-Qabt' );
my @reasonings        = (
    'Language "en-gb" in position 0: OK',
    'Language "en-Latn-GB-boont-u-extended-sequence-x-private" in position 1: OK',
    'Language "en-US-t-islamca" in position 2: OK',
    'Language "es-419" in position 3: OK',
    'Language "hy-Latn-IT-arevela" in position 4: OK',
    'Language "[Type: REF]" in position 5: Language code must be a scalar string',
    'Language "i-enochian" in position 6: OK',
    'Language "de-419-DE" in position 7: Failed regular expression match',
    'Language "de-Qabt" in position 8: Script codes Qaaa-Qabx are reserved for private use only - includes "qabt"',
    'Language "en-uk" in position 9: OK',
);
is(
    $results{'invalid_languages'}, \@invalid_languages,
    'validate_multiple: Multiple invalid languages should match'
);
is( $results{'languages'}, \@expected_languages, 'validate_multiple: Multiple languages should match' );

is( $results{'reasoning'}, \@reasonings, 'validate_multiple: Multiple reasonings should match' );

done_testing();

