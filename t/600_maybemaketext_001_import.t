#!perl
use strict;
use warnings;
use vars;
use File::Basename();
use File::Spec();
use lib File::Spec->catdir( File::Basename::dirname( File::Spec->rel2abs(__FILE__) ), q/lib/ );
use Locale::MaybeMaketext::Tests::Base qw/:all/;
use Locale::MaybeMaketext              qw/:all/;
use Test2::Tools::Target 'Locale::MaybeMaketext';
imported_ok(
    qw/translate
      maybe_maketext_get_languages
      maybe_maketext_get_language_configuration
      maybe_maketext_set_language_configuration
      maybe_maketext_get_name_of_localizer
      maybe_maketext_get_localizer_reasoning
      maybe_maketext_add_text_domains
      maybe_maketext_remove_text_domains
      maybe_maketext_remove_text_domains_matching_locales
      maybe_maketext_get_text_domains_to_locales_mappings
      maybe_maketext_get_locale_for_text_domain
      /
);

done_testing();
