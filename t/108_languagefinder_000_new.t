#!perl
## no critic (RegularExpressions::ProhibitComplexRegexes)
use strict;
use warnings;
use vars;
use File::Basename();
use File::Spec();
use lib File::Spec->catdir( File::Basename::dirname( File::Spec->rel2abs(__FILE__) ), q/lib/ );
use Locale::MaybeMaketext::Tests::Base qw/:all/;
use feature                              qw/signatures/;
no warnings qw/experimental::signatures/;
use Test2::Tools::Target 'Locale::MaybeMaketext::LanguageFinder';
use Locale::MaybeMaketext::Cache();
use Locale::MaybeMaketext::LanguageCodeValidator();
use Locale::MaybeMaketext::Alternatives();
use Locale::MaybeMaketext::Supers();
use Locale::MaybeMaketext::PackageLoader();

my $cache     = Locale::MaybeMaketext::Cache->new();
my $validator = Locale::MaybeMaketext::LanguageCodeValidator->new( 'cache' => $cache );
my %expected  = (
    'language_code_validator' => $validator,
    'alternatives'            => Locale::MaybeMaketext::Alternatives->new( 'cache' => $cache ),
    'supers'                  => Locale::MaybeMaketext::Supers->new( 'language_code_validator' => $validator ),
    'package_loader'          => Locale::MaybeMaketext::PackageLoader->new( 'cache' => $cache ),
    'cache'                   => $cache,
);
my %needed = (
    'language_code_validator' => 'Locale::MaybeMaketext::LanguageCodeValidator',
    'alternatives'            => 'Locale::MaybeMaketext::Alternatives',
    'supers'                  => 'Locale::MaybeMaketext::Supers',
    'package_loader'          => 'Locale::MaybeMaketext::PackageLoader',
    'cache'                   => 'Locale::MaybeMaketext::Cache',
);
my %to_use     = ();
my $temp_bless = bless {}, 'Testing';
for my $key ( sort keys(%expected) ) {
    my $spacedkey = $key =~ tr{_}{ }r;
    like(
        dies { $CLASS->new(%to_use); } || 'did not die',
        qr/\AMissing needed configuration setting "$key"/,
        "Should check that $key is set"
    );
    $to_use{$key} = 'hello';
    like(
        dies { $CLASS->new(%to_use); } || 'did not die',
        qr/\AConfiguration setting "$key" must be a blessed object/,
        "Should check that $key is blessed"
    );
    $to_use{$key} = $temp_bless;
    my $class = $needed{$key};
    like(
        dies { $CLASS->new(%to_use); } || 'did not die',
        qr/\AConfiguration setting "$key" must be an instance of "$class": got "Testing"/,
        "Should check that $key is a type of $class"
    );
    $to_use{$key} = $expected{$key};
}
done_testing();
