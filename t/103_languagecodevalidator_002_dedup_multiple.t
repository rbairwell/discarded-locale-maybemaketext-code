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

my @input =
  qw/en-gb en-Latn-GB-boont-u-extended-sequence-x-private en en-US-t-islamca es-419 en-gb en-us hy-Latn-IT-arevela en-us en_gb/;
push @input, \sub() { };
push @input, qw/i-enochian de-419-DE de-Qabt en-uk/;
my $object  = Locale::MaybeMaketext::LanguageCodeValidator->new( 'cache' => Locale::MaybeMaketext::Cache->new() );
my %results = $object->dedup_multiple(@input);
my @expected_languages =
  qw/en_gb en_latn_gb_boont_u_extended_sequence_x_private en en_us_t_islamca es_419 en_us hy_latn_it_arevela i_enochian/;
my @invalid_languages = ( '[Type: REF] at position 10', 'de-419-DE', 'de-Qabt' );
my @reasonings        = (
    'Language "en-gb" in position 0: OK',
    'Language "en-Latn-GB-boont-u-extended-sequence-x-private" in position 1: OK',
    'Language "en" in position 2: OK',
    'Language "en-US-t-islamca" in position 3: OK',
    'Language "es-419" in position 4: OK',
    'Language "en-gb" in position 5: OK',
    'Language "en-us" in position 6: OK',
    'Language "hy-Latn-IT-arevela" in position 7: OK',
    'Language "en-us" in position 8: OK',
    'Language "en_gb" in position 9: OK',
    'Language "[Type: REF]" in position 10: Language code must be a scalar string',
    'Language "i-enochian" in position 11: OK',
    'Language "de-419-DE" in position 12: Failed regular expression match',
    'Language "de-Qabt" in position 13: Script codes Qaaa-Qabx are reserved for private use only - includes "qabt"',
    'Language "en-uk" in position 14: OK',
    'Removed 3 duplicates of "en_gb"',
    'Removed 1 duplicates of "en_us"',
);
is(
    $results{'invalid_languages'}, \@invalid_languages,
    'dedup_multiple: Multiple invalid languages should match'
);
is(
    $results{'languages'}, \@expected_languages, 'dedup_multiple: Multiple languages should match',
    $results{'languages'}
);

is( $results{'reasoning'}, \@reasonings, 'dedup_multiple: Multiple reasonings should match', $results{'reasoning'} );

done_testing();

