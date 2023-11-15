## no critic (NamingConventions::Capitalization,Variables::ProhibitPackageVars)
package Locale::MaybeMaketext::en;
use strict;
use warnings;
use vars;
use utf8;
use parent 'Locale::MaybeMaketext';
our $VERSION = '0.01';

our %Lexicon = ( 'This is a test translation [_1] for [_2]' => 'Test translation [_1]!' );
1;
