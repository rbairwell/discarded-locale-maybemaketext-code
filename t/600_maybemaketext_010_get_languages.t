#!perl

use strict;
use warnings;
use vars;
use File::Basename();
use File::Spec();
use lib File::Spec->catdir( File::Basename::dirname( File::Spec->rel2abs(__FILE__) ), q/lib/ );
use Locale::MaybeMaketext::Tests::Base qw/:all/;
use Test2::Tools::Target 'Locale::MaybeMaketext';

# Dependency on _maybe_maketext_create_localizer
todo 'Needs tests' => sub { note('Needs tests writing'); };    # TODO::Needs writing

done_testing();
