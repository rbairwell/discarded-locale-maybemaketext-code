package Locale::MaybeMaketext::Tests::DummyLangs::en_nz;    ## no critic (NamingConventions::Capitalization)
use strict;
use warnings;
use parent 'Locale::MaybeMaketext';
our %Lexicon = (    ## no critic (NamingConventions::Capitalization,Variables::ProhibitPackageVars)
    'Hello get handle [_1]!'     => 'Kia ora get handle test [_1]',
    'Another lexicon entry [_1]' => 'Translated [_1]'
);
1;
