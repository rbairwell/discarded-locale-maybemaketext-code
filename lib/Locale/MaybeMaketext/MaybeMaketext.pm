package Locale::MaybeMaketext;

# pragmas
use v5.20.0;    # minimum of v5.20.0 due to use of signatures.
                # suggest v5.36.0 (where signatures were no longer considered experimental)
use strict;
use warnings;
use vars;
use utf8;

use autodie  qw/:all/;
use feature  qw/signatures state lexical_subs/;    # state=5.10.0,others=5.20
use Exporter qw/import/;

use Carp qw/carp croak/;
use Locale::MaybeMaketext::Cache();
use Locale::MaybeMaketext::PackageLoader();

# indirect references (such as new Class instead of Class->new)
# are discouraged. can only be disabled on v5.32.0 onwards and is disabled by default on v5.36.0+.
# https://metacpan.org/dist/perl/view/pod/perlobj.pod#Indirect-Object-Syntax
# need to use the old decimal version + (patch level / 1000) version strings here
no if $] >= 5.032, q|feature|, qw/indirect/;
no warnings qw/experimental::signatures experimental::lexical_subs/;

# constants
use constant MAYBE_MAKETEXT_SELF_VARIABLE_PREFIX => '_maybe_maketext_';
use constant MAYBE_MAKETEXT_NULL_LOCALE          => 'Locale::MaybeMaketext::NullLocale';
use constant MAYBE_MAKETEXT_DEFAULT_LANGUAGE_SETTINGS => (
    'previous',
    'provided',
    'alternatives',
    'supers',
    'Locale::MaybeMaketext::Detectors::Cpanel',
    'Locale::MaybeMaketext::Detectors::Http',
    'Locale::MaybeMaketext::Detectors::I18N',
    qw/i_default en en_us alternatives supers/,
);
use constant MAYBE_MAKETEXT_KNOWN_LOCALIZERS => (
    'Cpanel::CPAN::Locale::Maketext::Utils',
    'Locale::Maketext::Utils',
    'Locale::Maketext',
    'Locale::MaybeMaketext::FallbackLocalizer',
);

# "our" variables
our $maybe_maketext_currently_making_handle = undef;         ## no critic (Variables::ProhibitPackageVars)
our $VERSION                                = 'v0.00.1';
our @EXPORT_OK                              = qw/translate
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
  /;
our %EXPORT_TAGS         = ( all => [@EXPORT_OK] );
our $USING_LANGUAGE_TAGS = 0;

# ISA is needed to allow us to pick our parent
our @ISA = ();    ## no critic (ClassHierarchies::ProhibitExplicitISA)

# Encoding is Needed for consistency with Maketext libraries
our $Encoding = 'utf-8';    ## no critic (NamingConventions::Capitalization,Variables::ProhibitPackageVars)

# "my" internal variables
my %maybe_maketext_text_domains               = ();       # the mapping of package names to translation files
my %maybe_maketext_cached_packages_to_locales = ();
my @maybe_maketext_last_languages_used        = ();
my $maybe_maketext_localizer                  = undef;    # same localizer used for everything as system dependent.
my @maybe_maketext_localizer_reasoning        = ();
my @maybe_maketext_language_settings          = MAYBE_MAKETEXT_DEFAULT_LANGUAGE_SETTINGS;
my @maybe_maketext_localizers_to_use          = MAYBE_MAKETEXT_KNOWN_LOCALIZERS;
my %maybe_maketext_packages                   = ();
my %maybe_maketext_packages_to_use            = (
    'language_code_validator' => 'Locale::MaybeMaketext::LanguageCodeValidator',
    'alternatives'            => 'Locale::MaybeMaketext::Alternatives',
    'supers'                  => 'Locale::MaybeMaketext::Supers',
    'package_loader'          => 'Locale::MaybeMaketext::PackageLoader',
    'cache'                   => 'Locale::MaybeMaketext::Cache',
    'language_finder'         => 'Locale::MaybeMaketext::LanguageFinder',
);

=encoding utf8

=head1 NAME

Locale::MaybeMaketext - A package to find available localization / localisation / translation services .

=head1 SYNOPSIS

    use Locale::MaybeMaketext qw/translate/;
    Locale::MaybeMaketext->maybe_maketext_add_text_domains(
                'main'=>'My::Translations','My:App'=>'My::App::Translations'
    );
    $lh=Locale::MaybeMaketext->get_handle();
    $lh->maketext('Hello [_1]!','there!');

    package My::App::Translations::en_us;
    use parent 'Locale::MaybeMaketext';
    our %LEXICON=('Hello [_1]!'=>'Howdy [_1],');

=head1 DESCRIPTION

C<Locale::MaybeMaketext> allows to specify multiple "I<text domains>" for translation purposes
and have the appropriate "I<locale>" maketext locale returned
(for example, having anything under My::Application translated differently to those in OtherPersons::App )
It will also automatically "pick" the most appropriate/available "I<localizer>" (localization tool support Maketext)
found on the system - along with automatically detecting available languages.

The I<locale> is selected by the longest matching package name listed as a I<text domain>.

By default, it will try the following "maketext" supporting packages in this order:
L<Cpanel::CPAN::Locale::Maketext::Utils> L<Locale::Maketext::Utils> L<Locale::Maketext>

In your "Locale"/"i10n"/"i18n"/"Lexicon" files, you just need to include this base class as the parent - you
do not need to worry about what the underlying maketext implementation is.

All the text domains, localizers and language detection can be overriden.

Inspired by L<JSON::MaybeXS> for picking JSON encoders and forced into being by invalid documentation about
translations by Cpanel Inc and my want for reusable code.

=cut

=head1 DEVELOPMENT

=head2 Terminology

=over

=item I<text domain> is a "package/class" prefix where your code resides (such as My::App)

=item I<locale> is the package/directory where your translations reside (such as My::App::I18N).

=item I<localizer> is a specific implentation of the C<maketext> system.

=back

=head2 Variable/Subroutine Naming

As we may be a "child" to many different packages there is the possibility of clashes of variable
and subroutine names. Therefore all subroutines (which aren't part of the "I<maketext> standard":
i.e. C<get_handle> and C<new> - and the standard C<import>) are prefixed with C<maybe_maketext_>
(with an underscore for private variables/functions). Class constants are prefixed, as per
Perl convention, in upper case (i.e. C<MAYBE_MAKETEXT_>).

Where we "inject" data into third party code (for example, C<_maybe_maketext_get_handle> adds
which languages were accepted, which ones were rejected and the reasoning of them), the
properties are prefixed with the contents of the C<MAYBE_MAKETEXT_SELF_VARIABLE_PREFIX> constant
to prevent clashes.

=head2 Dynamically Created Packages

If the system needs to create a dummy locale package (for example, under base C<maketext>
implementations it is expected for you to have the classes in the style C<MyApp::App>, C<MyApp::App::I18N>
and C<MyApp::App::I18N::en>) but this module means you do not need to both creating the "base" C<MyApp::App::I18N>
package yourself), it will generate it using that name.

If there is no "default text domain" configured and the system is unable to find a matching
locale, then one will be created called C<Locale::MaybeMaketext::NullLocale>
(as per the constant C<MAYBE_MAKETEXT_NULL_LOCALE>).

=head2 Features Used

=head3 Subroutine Signatures

Where possible, L<Subroutine Signatures|https://perldoc.perl.org/perlsub#Signatures>
have been implemented (a new feature in experimental mode with
L<Perl 5.20|https://perldoc.perl.org/feature#The-'signatures'-feature> and stable in
Perl 5.36) to help reduce the "boiler plate" code needed to validate calls to subroutines
and to help "hint" what is required to use a subroutine.

=head3 State Feature

From L<Perl 5.10|https://perldoc.perl.org/feature#The-'state'-feature>, Perl has supported the
C<state> feature to enable L<Persistent Private Variables|https://perldoc.perl.org/perlsub#Persistent-Private-Variables>
and is mainly used to offer subroutines an ability to do some level of local caching.

=head3 Lexical Subroutines

Where possible, L<Lexical Subroutines|https://perldoc.perl.org/perlsub#Lexical-Subroutines>
(a new feature with L<Perl 5.18|https://perldoc.perl.org/feature#The-'lexical_subs'-feature>
in experimental mode and stable in version 5.26) are used to improve
performance (if a subroutine will return the same thing every call, then C<state> is used)
and help isolate private subroutines (prefixed with C<an _ underscore>) from the main
code.

These subroutines should be "predeclared" near the start of each package as so:

    my sub _maybe_maketext_create_localizer;
    state sub _maybe_maketext_parameters_validate;

This is to save having to change the order of subroutines to support this feature (if
they are not predeclared, then the subroutine needs to be fully declared before any
code that references it is found).

=cut

# Predeclare lexial subroutines
my sub _maybe_maketext_get_handle;
my sub _maybe_maketext_create_localizer;
state sub _maybe_maketext_parameters_validate;
state sub _maybe_maketext_args_to_hash;
state sub _maybe_maketext_create_fake_locale;
state sub _maybe_maketext_exit_if_invalid_text_domain;

=head1 FUNCTIONS

=cut

=head2 translate

Allows you to translate text with a simple subroutine call.

=over

=item C<translate>

Simple way of getting a string translated without having to worry about getting/passing handles etc.

Uses the I<text_domain> based off the package it was called from.

Called in the same way as L<Locale::Maketext|Locale::Maketext/"The "maketext" Method"> in that the first
parameter is expected to be a string with L<bracket notation|Locale::Maketext/"BRACKET NOTATION">
with square brackets - and the remaining parameters include data to "fill in" that brackets.

The following description is heavily based from
L<"The "maketext" Method"|Locale::Maketext/"The "maketext" Method">:

This looks in the C<%Lexicon> of the autodetected language handle and all its superclasses, looking
for an entry whose key is the string I<key>.  Assuming such an entry is found, various things
then happen, depending on the value found:

If the value is a scalarref, the scalar is dereferenced and returned
(and any parameters are ignored).

If the value is a coderef, we return C<&$value($lh, ...parameters...)>.

If the value is a string that I<doesn't> look like it's in Bracket Notation,
we return it (after replacing it with a scalarref, in its %Lexicon).

If the value I<does> look like it's in Bracket Notation, then we compile
it into a sub, replace the string in the C<%Lexicon> with the new coderef,
and then we return C<&$new_sub($lh, ...parameters...)>.

Bracket Notation is discussed in a later section.  Note
that trying to compile a string into Bracket Notation can throw
an exception if the string is not syntactically valid (say, by not
balancing brackets right.)

=over

=item B<Example usage>

    use Locale::MaybeMaketext qw/translate/;
    my $translated=translate( <phrase>,...parameters for this phrase...);

=item B<Parameters>

=over

=item scalar: The first item is expected to be a string with optional L<bracket notation|Locale::Maketext/"BRACKET NOTATION">

=item mixed: (usually scalar strings) Subsequent items should be data to fill in the notations.

=back

=item B<Returns>

scalar: The translated text.

=back

=back

=cut

sub translate ( $phrase, @args ) {
    return _maybe_maketext_get_handle( 'text_domain' => ( caller(0) )[0] )->maketext( $phrase, @args );
}

=head2 get_handle

Gets the appropriate translation handle.

Uses the I<text_domain> based off the package it was called from.

The following description is heavily based from
L<Locale::Maketext Construction Methods|Locale::Maketext/"Construction Methods">:
This tries loading classes based on the language-tags you give (like
C<("en-US", "sk", "kon", "es-MX", "ja", "i-klingon")>, and for the first class
that succeeds, returns an instance of this class.

If it runs thru the entire given list of language-tags, and finds no classes
for those exact terms, it then tries "superordinate" language classes.
So if no "en-US" class (i.e., YourProjClass::en_us)
was found, nor classes for anything else in that list, we then try
its superordinate, "en" (i.e., YourProjClass::en), and so on thru
the other language-tags in the given list: "es".
(The other language-tags in our example list:
happen to have no superordinates.)

If none of those language-tags leads to loadable classes OR there are no
language tags provided, we then utilise the detectors listed in
C<maybe_maketext_language_settings> to try and figure out
which to use.

=over

=item B<Example usage>

    use Locale::MaybeMaketext qw/translate/;
    my $handle = Locale::MaybeMaketext->get_handle(@languages);
    $handle->maketext( 'My test [_1]', 'Text' );

=item B<Parameters>

=over

=item array: C<@languages>: (optional) List of language codes (such as C<en_us>, C<en>) to try for translations.

=back

=item B<Returns>

object: Instance of this class which will have a parent of the appropriate localization class.

=back

=cut

sub get_handle ( $class, @languages ) {
    return _maybe_maketext_get_handle(
        'text_domain' => ( caller(0) )[0],
        'languages'   => \@languages
    );
}

=head2 fallback_languages

Part of the C<maketext> "specification". We override this to return an empty array as everything
which would normally be handled by it is handled by ourselves.

From L<Locale::Maketext|Locale::Maketext/"Construction Methods"> :

C<get_handle> appends the return value of this to the end of whatever list of languages you
pass get_handle. Unless you override this method, your project class will inherit
Locale::Maketext's C<fallback_languages>, which currently returns
(C<'i-default', 'en', 'en-US'>). ("i-default" is defined in RFC 2277).

This method (by having it return the name of a language-tag that has an existing
language class) can be used for making sure that C<get_handle> will always manage to
construct a language handle (assuming your language classes are in an
appropriate @INC directory). Or you can use the next method:

=over

=item B<Parameters>

None.

=item B<Returns>

array: Always empty

=back

=cut

sub fallback_languages {
    return ();
}

=head2 fallback_language_classes

Part of the C<maketext> "specification". We override this to return an empty array as everything
which would normally be handled by it is handled by ourselves.

From L<Locale::Maketext|Locale::Maketext/"Construction Methods"> :

C<get_handle> appends the return value of this to the end of the list of classes it will try using.
Unless you override this method, your project class will inherit Locale::Maketext's
C<fallback_language_classes>, which currently returns an empty list, C<()> .
By setting this to some value( namely, the name of a loadable language class ),
you can be sure that get_handle will always manage to construct a language handle .

=over

=item B<Parameters>

None.

=item B<Returns>

array: Always empty

=back

=cut

sub fallback_language_classes {
    return ();
}

=head2 new

Part of the C<maketext> "specification". It's recommended that this subroutine is B<NOT> called directly, but
instead let C <get_handle> find a language class to C <use> and to then call C<< ->new >> on.

C<maketext> calls C<(locale)::new> which then calls this new and then calls C<Maketext::Utils> and then C<Maketext>
- all times C<self> is set to locale. We therefore return what is left after maketext adds stuff, then utils,
then "us" and then the locale.

Example call stack for us calling: C<Cpanel::CPAN::Locale::Maketext::Utils::get_handle("Testing::Abcdef", "en-us")>
#results in a call to: C<< Locale::MaybeMaketext->new("Testing::Abcdef::en_us") >>

=over

=item B<Parameters>

None.

=item B<Returns>

object: Ourselves.

=back

=cut

sub new ($class) {
    my ( $is_locale_calling, $current_domain, $prefix, $prefix_length ) =
      ( 0, undef, MAYBE_MAKETEXT_SELF_VARIABLE_PREFIX, undef );
    print "====== NEW $class CALLED!!!\n";
    print 'ISA: ' . ( join( q{, }, @ISA ) ) . "\n";
    $class = $class->SUPER::new();
    print "==== NEW SUPER CALLED\n";
    if ( $maybe_maketext_currently_making_handle && ref($maybe_maketext_currently_making_handle) eq __PACKAGE__ ) {

        # copy our data across
        $prefix_length = length($prefix);
        for my $item ( keys %{$maybe_maketext_currently_making_handle} ) {
            if ( substr( $item, 0, $prefix_length ) eq $prefix ) {
                $class->{$item} = $maybe_maketext_currently_making_handle->{$item};
            }
        }
        $class->{"${prefix}type"} = 'handle';
    }

    return $class;
}

##############################################################################################
#
#
# End of maketext "compatibility" subroutines
#
#
##############################################################################################

=head2 maybe_maketext_get_languages

Try and pick the most suitable language code available based on user provided data (languages provided) and anything we can detect.

=over

=item B<Example usage>

    package My::Application::Test;
    use Locale::MaybeMaketext qw/translate maybe_maketext_get_languages/;
    my $callback= sub($language) { print sprintf('Found language %s',$language); };
    my @languages_in_preference_order = maybe_maketext_get_languages(['en-nz','en-au','en_GB'],0,$callback);

=item B<Parameters>

=over

=item ref: C<$languagesref>: Reference to a scalar list of languages to start with

=item bool: C<$get_multiple>: Are multiple results wanted? 1= yes/true, 0= 0/false.

=item code: C<$callback>: Optional callback when a language is found/matched. Passed the found language as a sole parameter.


=back

=item B<Returns>

A Hash with the following entries:

=over

=item array: C<languages>: A list of acceptable language codes in preferred order

=item array: C<invalid_languages>: A list of language codes which were rejected

=item array: C<reasoning>: Any reasoning behind the rejection/inclusion.

=back

=item B<Warnings/Exceptions>

None

=back

=cut

sub maybe_maketext_get_languages ( $languages_ref, $get_multiple = 0, $callback = undef ) {
    my ( @languages, @invalid_languages, @reasoning ) = ( (), (), () );
    my (%results);

    # validate any provided languages
    if ( @{$languages_ref} ) {
        my @temp_languages;
        for my $lang ( @{$languages_ref} ) {
            if ( ref($lang) eq 'ARRAY' ) {
                @temp_languages = ( @temp_languages, @{$lang} );
            }
            else {
                push @temp_languages, $lang;
            }
        }
        my %langresults = _maybe_maketext_get_language_code_validator()->validate_multiple(@temp_languages);
        @languages         = @{ $langresults{'languages'} };
        @invalid_languages = @{ $langresults{'invalid_languages'} };
        @reasoning         = @{ $langresults{'reasoning'} };
        push @reasoning, sprintf(
            'Provided %d languages - of which %d were accepted as valid (%s).',
            scalar(@temp_languages), scalar(@languages), join( q{ ,}, @languages )
        );
    }
    my @found_languages;
    %results = _maybe_maketext_get_language_finder()->finder(
        'provided_languages' => \@languages,
        'configuration'      => \@maybe_maketext_language_settings,
        'previous_languages' => \@maybe_maketext_last_languages_used,
        'get_multiple'       => $get_multiple,
        'callback'           => $callback
    );
    for ( @{ $results{'reasoning'} } ) {
        push @reasoning, 'Finder: ' . $_;
    }

    @invalid_languages =
      ( @invalid_languages, @{ $results{'invalid_languages'} }, @{ $results{'rejected_languages'} } );
    return (
        'languages' => \@found_languages, 'invalid_languages' => \@invalid_languages,
        'reasoning' => \@reasoning
    );
}

=head2 maybe_maketext_get_language_reasoning

Returns an array detailing why a language was chosen. Usually only useful to check Detectors. Mainly used to debugging/checking.

=over

=item B<Example usage>

    package My::Application::Test;
    use Locale::MaybeMaketext qw/translate/;
    Locale::MaybeMaketext->maybe_maketext_add_text_domains('My::Application'=>'My::Translations');
    my $handle = Locale::MaybeMaketext->get_handle('en_us');
    print $handle->maybe_maketext_get_language_reasoning();    # ("Previous: No languages previously used","Detector...")

=item B<Parameters>

None.

=item B<Returns>

array: Scalars detailing why the language was chosen.

=back

=cut

sub maybe_maketext_get_language_reasoning ($class) {
    my $key = MAYBE_MAKETEXT_SELF_VARIABLE_PREFIX . 'language_reasoning';

    return defined( $class->{$key} ) ? @{ $class->{$key} } : ();
}

=head2 maybe_maketext_get_language_configuration

Returns an array with the current order of how to process languages. Mainly used to debugging/checking.

=over

=item B<Example usage>

    package My::Application::Test;
    use Locale::MaybeMaketext qw/translate maybe_maketext_get_language_configuration/;
    my @empty_language_actions = maybe_maketext_get_language_configuration();

=item B<Parameters>

None.

=item B<Returns>

array: Scalars (in order) of what to do when a language is requested.

=back

=cut

sub maybe_maketext_get_language_configuration () {
    return @maybe_maketext_language_settings;
}

=head2 maybe_maketext_set_language_configuration

Sets the language configuration - i.e. what to do in what order to find the perfect language.

Really just a hook through to C<< Locale::MaybeMaketext::LanguageFinder->set_configuration >> to
build up the configuration and then stores in in C<@maybe_maketext_language_settings>.

=over

=item B<Example usage>

    package My::Application::Test;
    use Locale::MaybeMaketext qw/translate maybe_maketext_set_language_configuration/;
    my @empty_language_actions = maybe_maketext_set_language_configuration('en_gb','try','die')

=item B<Parameters>

=over

=item array: C<@list_of_actions>: A list of actions, in order, to take to find out the perfect language.

=back

=item B<Returns>

array: Scalars (in order) of what to do when a language is requested.

=item B<Warnings/Exceptions>

=over

=item Exception: C<Invalid call: Must be passed a list of actions>

From C<< Locale::MaybeMaketext::LanguageFinder->set_configuration >>:
If the list of actions is empty.

=item Exception: C<Invalid position of %s: Nothing to "%s" which hasn't already been tried...>

From C<< Locale::MaybeMaketext::LanguageFinder->set_configuration >>:
If C<try> or C<empty> is called before anything else is setup.

=item Exception: C<Invalid position of die: it must be in the last position if used...>

From C<< Locale::MaybeMaketext::LanguageFinder->set_configuration >>:
If die is called anywhere but the final position.

=item Exception: C<Invalid looking language passed: "%s">

From C<< Locale::MaybeMaketext::LanguageFinder->set_configuration >>:
If a non-keyword entry is passed (without colons), it will be processed as a potential language code. This error is
thrown if the language code does not look valid.

=item Exception: C<Unrecognised language configuration setting: "%s" Accepted values are:...>

From C<< Locale::MaybeMaketext::LanguageFinder->set_configuration >>:
Thrown if a non-keyword entry is passed which does not look like a language code or a detector name.

=item Exception: C<Invalid looking language code passed in array: "%s">

From C<< Locale::MaybeMaketext::LanguageFinder->set_configuration >>:
If an array is passed as an entry, it should consist of one or more language
codes - if it doesn't, then this error is raised.

=item Exception: C<Unrecognised language configuration of type: %s>

From C<< Locale::MaybeMaketext::LanguageFinder->set_configuration >>:
If something that is not a scalar string or array is passed as an entry, then this error is raised.

=item Exception: C<No valid language configuration provided>

From C<< Locale::MaybeMaketext::LanguageFinder->set_configuration >>:
If, after processing/validation, there is no configuration left as "valid", then this error is raised.

=back

=back

=cut

sub maybe_maketext_set_language_configuration (@list_of_actions) {
    @maybe_maketext_language_settings = _maybe_maketext_get_language_finder()->set_configuration(@list_of_actions);
    return @maybe_maketext_language_settings;
}

=head2 maybe_maketext_get_name_of_localizer

Returns the name of the localizer package (or undef if not generated yet). Mainly used to debugging/checking.

=over

=item B<Example usage>

    package My::Application::Test;
    use Locale::MaybeMaketext qw/translate maybe_maketext_get_name_of_localizer/;
    my $localizer = maybe_maketext_get_name_of_localizer();

=item B<Parameters>

None.

=item B<Returns>

scalar: Name of the localizer package.

=back

=cut

sub maybe_maketext_get_name_of_localizer () {
    _maybe_maketext_create_localizer();
    return $maybe_maketext_localizer;
}

# Intended for testing as I can't think of any other occasion when you would want to specifically
# block packages.
sub maybe_maketext_set_only_specified_localizers (@packages) {

    @maybe_maketext_localizers_to_use = ();
  OUTER: for my $package_name (@packages) {
        for my $allowed_package (MAYBE_MAKETEXT_KNOWN_LOCALIZERS) {
            if ( $allowed_package eq $package_name ) {
                push @maybe_maketext_localizers_to_use, $package_name;
                next OUTER;
            }
        }
        croak( sprintf( 'Localizer "%s" not recognised.', $package_name ) );
    }
    return @maybe_maketext_localizers_to_use;
}

=head2 maybe_maketext_get_localizer_reasoning

Returns an array detailing why a localizer was chosen (the localizer is reused for all translations). Mainly used to debugging/checking.

=over

=item B<Example usage>

    package My::Application::Test;
    use Locale::MaybeMaketext qw/translate maybe_maketext_get_localizer_reasoning/;
    my @reasons=maybe_maketext_get_localizer_reasoning();

=item B<Parameters>

None.

=item B<Returns>

array: Scalars detailing why the localizer was chosen.

=back

=cut

sub maybe_maketext_get_localizer_reasoning () {
    _maybe_maketext_create_localizer();
    return @maybe_maketext_localizer_reasoning;
}

=head2 maybe_maketext_add_text_domains

Add one or more packages (I<text domains>) to translation files (I<locales>) mappings.
You probably want to use this every time you "use" this package.

Accepts "C<default>" for anything not matching and "C<main>" for calls from non-namedspaced code.
Tries to match the longest possible string - if there are multiple matching entries with the same
length, then the first declared will be selected.

Given the C<Example usage> setup, if maketext was called the subroutine from
C<My::Example::Code::Frank::Hello::test()> with a language code of "C<en-GB>", then the locale
file C<Somebody::Elses::I18N::en_gb.pm> will be attempted to load
(as C<My::Example::Code::Frank> is the longest text domain match). Calling from
the package C<Hello::Is::There::anyone()> won't match anything in the list and
so the "C<default>" entry would be processed to result in
C<Test::Example::EverythingElse::en_gb.pm> being used.

=over

=item B<Example usage>

    package My::Application::Test;
    use Locale::MaybeMaketext qw/translate maybe_maketext_add_text_domains /;
    maybe_maketext_add_text_domains(
        'My::Example::Code'        => 'Test::Example::Translations',
        'My::Example::Code::Frank' => 'Somebody::Elses::I18N',
        'main'                     => 'General::Translations');
    maybe_maketext_add_text_domains(
        'default'                  => 'Test::Example::EverythingElse',
    );

=item B<Parameters>

=over

=item array: C<@mappings>: An array of hash entries.

The list should comprise of the text domain (i.e. the package namespace your code resides under/package prefix) as the hash key and
then the translation locale directory/folder as the value (i.e. where files such as "en_us" reside).

=back

=item B<Returns>

hash: Current list of the text domain to locale mappings.

=item B<Warnings/Exceptions>

=over

=item Exception: C<Invalid text domain: "%s". Only package names...>

From C<_maybe_maketext_exit_if_invalid_text_domain>:
If an text domain is undefined, not a string, is not a package name and is not the keywords "C<default>" or "C<main>".

=item Exception: C<Invalid locale translation package: "%s". Only package names as strings are supported...>

From  C<_maybe_maketext_exit_if_invalid_locale>:
If the locale/translation package is undefined, not a string or is not a package name.

=back

=back

=cut

sub maybe_maketext_add_text_domains (@mappings) {
    if ( defined( $mappings[0] ) && ( ref( $mappings[0] ) || $mappings[0] eq __PACKAGE__ ) ) {
        croak('maybe_maketext_add_text_domains should be called as a subroutine, not as a method');
    }
    my ( %mappings, $ref );

    %mappings = _maybe_maketext_args_to_hash(@mappings);
    for my $text_domain ( keys %mappings ) {
        _maybe_maketext_exit_if_invalid_text_domain( $text_domain, 'on call to maybe_maketext_add_text_domains' );
        my $locale = $mappings{$text_domain};
        _maybe_maketext_exit_if_invalid_locale(
            $locale,
            sprintf( 'on call to maybe_maketext_add_text_domains for text domain "%s"', $text_domain )
        );
        $maybe_maketext_text_domains{$text_domain} = $locale;
    }

    # invalidate caches
    %maybe_maketext_cached_packages_to_locales = ();
    return %maybe_maketext_text_domains;
}

=head2 maybe_maketext_remove_text_domains

Removes one or more text domain (package prefix) settings.

=over

=item B<Example usage>

    package My::Application::Test;
    use Locale::MaybeMaketext qw/translate maybe_maketext_add_text_domains maybe_maketext_remove_text_domains/;
    maybe_maketext_add_text_domains(
        'Somebody::Else' => 'Some::Global::Translation::Files::Somebody::Else',
        'Jeff::Bloggs'   => 'Some::Global::Translation::Files::Jeff::Bloggs'
    );
    my %removed = maybe_maketext_remove_text_domains('Jeff::Bloggs');

=item B<Parameters>

=over

=item @list_of_text_domains array: Scalars of the package/text domains to be removed from the mapping.

=back

=item B<Returns>

hash: List of what was removed and the locales they were mapped to.

=item B<Warnings/Exceptions>

=over

=item Exception: C<Invalid call. Text domains must all be strings>

Dies if any text domain is not a string/scalar.

=item Exception: C<Invalid call. Invalid text domain: "%s". Only packages, "default" and "main" are supported>

Dies if a text domain is not "default", "main" or looks like a package (according to MAYBE_MAKETEXT_PERL_PACKAGE_NAME_REGEXP)

=item Warning: C<Invalid text domain mapping. Text domain "%s" does not have any mappings.>

Warns if an attempt to remove a text domain mapping which does not exist (either never been created or has already been removed)

=back

=back

=cut

sub maybe_maketext_remove_text_domains (@list_of_text_domains) {
    my %removed = ();
    for my $text_domain (@list_of_text_domains) {
        _maybe_maketext_exit_if_invalid_text_domain( $text_domain, 'on call to maybe_maketext_remove_text_domains' );
        if ( defined( $maybe_maketext_text_domains{$text_domain} ) ) {
            $removed{$text_domain} = $maybe_maketext_text_domains{$text_domain};
            delete $maybe_maketext_text_domains{$text_domain};
        }
        else {
            carp(
                sprintf(
                    'Invalid text domain mapping. Text domain "%s" does not have any mappings.',
                    $text_domain,
                )
            );
        }
    }

    # invalidate caches
    %maybe_maketext_cached_packages_to_locales = ();
    return %removed;
}

=head2 maybe_maketext_remove_text_domains_matching_locales

Removes text domains entries which match any of the provided locales/translation packages.

=over

=item B<Example usage>

    package My::Application::Test;
    use Locale::MaybeMaketext
      qw/translate maybe_maketext_add_text_domains maybe_maketext_remove_text_domains_matching_locales/;
    maybe_maketext_add_text_domains(
        'Somebody::Else' => 'Some::Global::Translation',
        'Tester::McTest'   => 'Some::Translation::Gubbins',
        'Jeff::Bloggs'   => 'Some::Global::Translation',

    );
    my %removed = maybe_maketext_remove_text_domains_matching_locales('Some::Global::Translation');

=item B<Parameters>

=over

=item array: Scalars of the package/text domains to be removed from the mapping.

=back

=item B<Returns>

hash: List of what was removed and the locales they were mapped to.

=item B<Warnings/Exceptions>

=over

=item Exception: C<Invalid call. Text domains must all be strings>

Dies if any text domain is not a string/scalar.

=item Exception: C<Invalid call. Invalid text domain: "%s". Only packages, "default" and "main" are supported>

Dies if a text domain is not "default", "main" or looks like a package (according to MAYBE_MAKETEXT_PERL_PACKAGE_NAME_REGEXP)

=item Warning: C<Invalid text domain mapping. Text domain "%s" does not have any mappings.>

Warns if an attempt to remove a text domain mapping which does not exist (either never been created or has already been removed)

=back

=back

=cut

sub maybe_maketext_remove_text_domains_matching_locales (@list_of_locales) {
    my %locales_to_domains;

    # loop through the text domains storing which locales match to what domains.
    while ( my ( $domain, $package ) = each %maybe_maketext_text_domains ) {
        if ( !defined( $locales_to_domains{$package} ) ) {
            $locales_to_domains{$package} = ();
        }
        push @{ $locales_to_domains{$package} }, $domain;
    }
    my %removed = ();
    for my $locale (@list_of_locales) {
        _maybe_maketext_exit_if_invalid_locale(
            $locale,
            'on call to maybe_maketext_remove_text_domains_matching_locales'
        );
        if ( defined( $locales_to_domains{$locale} ) ) {
            for my $remove ( @{ $locales_to_domains{$locale} } ) {
                $removed{$remove} = $locale;
                delete $maybe_maketext_text_domains{$remove};
            }
        }
        else {
            carp(
                sprintf(
                    'Missing text domain mapping. Locale package "%s" does not have any text domain mappings',
                    $locale,
                )
            );
        }
    }

    # invalid caches
    %maybe_maketext_cached_packages_to_locales = ();
    return %removed;
}

=head2 maybe_maketext_get_text_domains_to_locales_mappings

Gets the hash of all currently defined/configured text domains/package prefixes (such as C<My::App::Something>) to the
locales (such as C<My::I18N::Something::App>). Mainly used to debugging/checking.

=over

=item B<Example usage>

    package My::Application::Test;
    use Locale::MaybeMaketext qw/translate maybe_maketext_get_text_domains_to_locales_mappings/;
    my %text_domains = maybe_maketext_get_text_domains_to_locales_mappings();

=item B<Parameters>

None.

=item B<Returns>

hash: Key is the package name/text domain we will match against. Value is the package which supplies the translations.

=back

=cut

sub maybe_maketext_get_text_domains_to_locales_mappings () {

    return %maybe_maketext_text_domains;
}

=head2 maybe_maketext_get_locale_for_text_domain

Gets the most appropriate locale translation package for a given text domain/package prefix.

If nothing found, and "default" is not set as a text domain mapping, then the constant C<MAYBE_MAKETEXT_NULL_LOCALE> will be returned
and a "Missing text_domain mapping" warning will be raised.

=over

=item B<Example usage>

    package My::Application::Test;
    use Locale::MaybeMaketext qw/translate maybe_maketext_get_locale_for_text_domain/;
    my $locale = maybe_maketext_get_locale_for_text_domain('My::Example::Package');

=item B<Parameters>

=over

=item string: C<$text_domain>: Which text domain we are fetching for.

=back

=item B<Returns>

scalar: The translation package to use (or, if not found and no "default" configured C<MAYBE_MAKETEXT_NULL_LOCALE>).

=item B<Warnings/Exceptions>

=over

=item Exception: C<Invalid text domain: "%s". Only package names...>

From C<_maybe_maketext_exit_if_invalid_text_domain>:
If an text domain is undefined, not a string, is not a package name and is not the keywords "C<default>" or "C<main>".

=item Warning: C<Missing text_domain mapping. Unable to find a translation package mapping for the text domain "%s". Returning "%s">

If the passed C<text_domain> is could not be matched to a locale (and there is no default) - causing the fallback locale to be returned.

=back

=back

=cut

sub maybe_maketext_get_locale_for_text_domain ( $text_domain = 'main' ) {
    my $package;
    if ( $text_domain eq q{} ) { $text_domain = 'default'; }
    _maybe_maketext_exit_if_invalid_text_domain(
        $text_domain, 'on call to maybe_maketext_get_locale_for_text_domain',
        1
    );

    # check the cache
    if ( defined( $maybe_maketext_cached_packages_to_locales{$text_domain} ) ) {
        return $maybe_maketext_cached_packages_to_locales{$text_domain};
    }

    # no cache entry, try and match by longest string against package/text domain name.

    # sort the text domain keys by length
    my @keys = reverse sort { length($a) <=> length($b) } ( keys %maybe_maketext_text_domains );

    for my $domain (@keys) {
        if ( substr( $text_domain, 0, length($domain) ) eq $domain ) {
            $package = $maybe_maketext_text_domains{$domain};
            last;
        }
    }

    # nothing found
    if ( !$package ) {

        # use the default
        if ( defined( $maybe_maketext_text_domains{'default'} ) ) {
            $package = $maybe_maketext_text_domains{'default'};
        }
        else {
            # if no default, use the null lang domain
            $package = MAYBE_MAKETEXT_NULL_LOCALE;
            carp(
                sprintf(
                    'Missing text_domain mapping. Unable to find a translation package mapping for the text domain "%s". Using null locale "%s".',
                    $text_domain,
                    $package
                )
            );
        }
    }

    $maybe_maketext_cached_packages_to_locales{$text_domain} = $package;
    return $package;
}

=head2 maybe_maketext_get_locale

Returns the name of the locale package (or undef if not generated yet). Mainly used to debugging/checking.

=over

=item B<Example usage>

    package My::Application::Test;
    use Locale::MaybeMaketext qw/translate maybe_maketext_add_text_domains/;
    maybe_maketext_add_text_domains('My::Application'=>'My::Translations');
    my $handle = Locale::MaybeMaketext->get_handle('en_us');
    print $handle->maybe_maketext_get_locale(); # "My::Translations"

=item B<Parameters>

None.

=item B<Returns>

scalar: Name of the locale package used (i.e. where the translations are sourced from).

=back

=cut

sub maybe_maketext_get_locale ($class) {
    return $class->{ MAYBE_MAKETEXT_SELF_VARIABLE_PREFIX . 'locale' };
}

# returns a near empty copy of this package with just text_domain completed.
sub maybe_maketext_get_instance ( $class, %named_arguments ) {
    state %locales_to_instances;
    if (
        (
              !defined( $named_arguments{'text_domain'} )
            || ref( $named_arguments{'text_domain'} ) ne q{}
            || $named_arguments{'text_domain'} eq q{}
        )
        && (  !defined( $named_arguments{'locale'} )
            || ref( $named_arguments{'locale'} ) ne q{}
            || $named_arguments{'locale'} eq q{} )
    ) {
        croak('Either "text_domain" or "locale" must be set to a scalar string');
    }

    my ( $locale, $instance );

    # first find out what "locale" (localization realm) we should be operating under.
    # if locale is not a specified parameter, then use text_domain.
    $locale = $named_arguments{'locale'}
      || maybe_maketext_get_locale_for_text_domain( $named_arguments{'text_domain'} );

    # are we cached for this locale? if so, just return.
    if ( defined( $locales_to_instances{$locale} ) ) {
        return $locales_to_instances{$locale};
    }

    # if we are using our null lang domain (defined in MAYBE_MAKETEXT_NULL_LOCALE )
    # or the base package of the lang does not exist, create a fake.
    my %load_result = _maybe_maketext_get_packageloader()->attempt_package_load($locale);
    if ( !$load_result{'status'} ) {
        _maybe_maketext_create_fake_locale($locale);
    }

    # not cached? then generate the cache

    $instance = bless {
        MAYBE_MAKETEXT_SELF_VARIABLE_PREFIX . 'locale' => $locale,
        MAYBE_MAKETEXT_SELF_VARIABLE_PREFIX . 'type'   => 'instance'
    }, $class;

    $locales_to_instances{$locale} = $instance;
    return $instance;
}

sub maybe_maketext_with_specifics ( $class, %settings ) {
    if (
        (
              !defined( $settings{'text_domain'} )
            || ref( $settings{'text_domain'} ) ne q{}
            || $settings{'text_domain'} eq q{}
        )
        && (  !defined( $settings{'locale'} )
            || ref( $settings{'locale'} ) ne q{}
            || $settings{'locale'} eq q{} )
    ) {
        croak('Either "text_domain" or "locale" must be set to a scalar string');
    }
    if (  !defined( $settings{'language'} )
        || ref( $settings{'language'} ) ne q{}
        || $settings{'language'} eq q{} ) {
        croak('"language" must be set to a scalar string');
    }
    if (  !defined( $settings{'text_to_make'} )
        || ref( $settings{'text_to_make'} ) ne 'ARRAY' ) {
        croak('"text_to_make" must be set to an array');
    }

    my $handle = _maybe_maketext_get_handle(
        'force_language' => $settings{'language'},
        'text_domain'    => $settings{'text_domain'},
        'locale'         => $settings{'locale'}
    );
    return $handle->maketext( @{ $settings{'text_to_make'} } );
}

sub maybe_maketext_reset ( $class = undef ) {

    # remove parent/inheritance.
    if ($maybe_maketext_localizer) {
        ## no critic (ClassHierarchies::ProhibitExplicitISA)
        @ISA = grep { !/$maybe_maketext_localizer/ } @ISA;
        no warnings 'redefine', 'once';    ## no critic (TestingAndDebugging::ProhibitNoWarnings)
        undef *maketext;
        undef *lh;
    }
    %maybe_maketext_text_domains               = ();
    %maybe_maketext_cached_packages_to_locales = ();
    @maybe_maketext_last_languages_used        = ();
    $maybe_maketext_localizer                  = undef;
    @maybe_maketext_localizer_reasoning        = ();
    @maybe_maketext_language_settings          = MAYBE_MAKETEXT_DEFAULT_LANGUAGE_SETTINGS;
    @maybe_maketext_localizers_to_use          = MAYBE_MAKETEXT_KNOWN_LOCALIZERS;

    return;
}

sub _maybe_maketext_get_handle_found_language ( $instance, $language ) {
    my ( $ref, $handle, $locale, $base_class );
    $handle     = undef;
    $locale     = $instance->{ MAYBE_MAKETEXT_SELF_VARIABLE_PREFIX . 'locale' };
    $base_class = ref($locale) || $locale;

    print "_maybe_maketext_get_handle_found_language calling for $base_class and $language\n";
    my $module_name = ( sprintf( '%s::%s', $base_class, $language ) =~ tr|/-||r );

    # try loading

    if (
        !eval {

            # first record we are creating the handle (as we may call ourselves via new)
            $maybe_maketext_currently_making_handle = $instance;
            print "Attempting to load $module_name\n";
            my %load_result = _maybe_maketext_get_packageloader()->attempt_package_load($module_name);
            print "LOADED!\n";
            if ( !$load_result{'status'} ) {
                print "------ Status failed! " . $load_result{'reasoning'} . "\n";
                carp( sprintf( 'Unable to use %s: %s', $module_name, $load_result{'reasoning'} ) );
                1;
            }
            print "=== Going to create new ===\n";
            $handle = $module_name->new();
            print "CREATED\n";
            1;
        }
    ) {
        print "Failed to create=========\n";
        carp(
            sprintf(
                'Failed to create handle via "%s" with locale "%s" and language: "%s" because: "%s"',
                $maybe_maketext_localizer, $locale, $language, ( $@ || $! || '[Unknown reasoning]' )
            )
        );
    }
    undef $maybe_maketext_currently_making_handle;
    return $handle;
}

# allowed parameters:
# - languages
# - locale
# - text_domain (must be specified if languages is not)
sub _maybe_maketext_get_handle (@named_arguments) {
    my %settings = _maybe_maketext_args_to_hash(@named_arguments);
    my ( @languages, $handle, $handle_cache_key, $instance );
    my ( $ref, $locale, %lang_data );

    # gets a (possibly cached) instance of ourselves
    $instance = __PACKAGE__->maybe_maketext_get_instance(
        'text_domain' => $settings{'text_domain'},
        'locale'      => $settings{'locale'}
    );

    # let's setup the localizer (if necessary)
    _maybe_maketext_create_localizer();
    $handle = undef;
    if ( defined( $settings{'force_language'} ) ) {
        $handle_cache_key =
          sprintf( '%s_localizer_handle_%s', MAYBE_MAKETEXT_SELF_VARIABLE_PREFIX, $settings{'force_language'} );
        if ( !exists( $instance->{$handle_cache_key} ) ) {
            $instance->{$handle_cache_key} =
              _maybe_maketext_get_handle_found_language( $instance, $settings{'force_language'} );
        }
        $handle = $instance->{$handle_cache_key};
    }
    else {
        %lang_data = maybe_maketext_get_languages(
            $settings{'languages'} || [],
            0,
            sub ($language) {
                $handle_cache_key = sprintf( '%s_localizer_handle_%s', MAYBE_MAKETEXT_SELF_VARIABLE_PREFIX, $language );
                if ( !exists( $instance->{$handle_cache_key} ) ) {
                    $instance->{$handle_cache_key} = _maybe_maketext_get_handle_found_language( $instance, $language );
                }
                $handle = $instance->{$handle_cache_key};
                return defined( $instance->{$handle_cache_key} ) ? 1 : 0;
            }
        );
    }

    if ( !$handle ) {
        my $bad_languages = '[Unknown]';
        if (%lang_data) {
            $bad_languages = join( q{, }, @{ $lang_data{'invalid_languages'} } );
        }
        elsif ( defined( $settings{'force_language'} ) ) {
            $bad_languages = $settings{'force_language'};
        }
        croak(

            # @TODO HANDLE!
            sprintf(
                    'TEMPORARY ERROR: NO HANDLE RECEIVED: NO MATCHING LANGUAGE FOR HANDLE! '
                  . ' Languages: %s, Localizer: %s, Localizer reasoning: %s',
                $bad_languages,
                $maybe_maketext_localizer,
                join( q{, }, @maybe_maketext_localizer_reasoning )
            )
        );
    }
    undef $maybe_maketext_currently_making_handle;
    if (%lang_data) {
        $handle->{ MAYBE_MAKETEXT_SELF_VARIABLE_PREFIX . 'language_reasoning' } = $lang_data{'reasoning'};
        $handle->{ MAYBE_MAKETEXT_SELF_VARIABLE_PREFIX . 'languages_accepted' } = $lang_data{'languages'};
        $handle->{ MAYBE_MAKETEXT_SELF_VARIABLE_PREFIX . 'languages_rejected' } = $lang_data{'invalid_languages'};
    }
    return $handle;
}

sub _maybe_maketext_args_to_hash (@args) {
    if ( !@args ) {
        my ( $caller_package, $caller_file, $caller_line, $called_sub ) = caller(1);
        croak(
            sprintf(
                '"%s" was not supplied with a referenced hash list/associated array or named parameter from %s line %d',
                $called_sub, $caller_file, $caller_line
            )
        );
    }
    my $ref = defined( $args[0] ) ? ( ref( $args[0] ) || 'scalar' ) : 'undef';
    if ( $ref eq 'ARRAY' ) {
        @args = @{ $args[0] };
        $ref  = defined( $args[0] ) ? ( ref( $args[0] ) || 'scalar' ) : 'undef';
    }
    my %results;
    if ( $ref eq 'scalar' ) {
        my $counter = scalar(@args);

        # if passed named parameters, map it to the hash.
        if ( !( $counter % 2 ) ) {
            my $current = 0;
            while ( $current <= $counter ) {
                if ( ref( $args[$current] ) ) {
                    croak(  'Invalid call. All keys must be scalars - instead got '
                          . ref( $args[$current] )
                          . " as the $current entry" );
                }
                $current += 2;
            }
            %results = @args;
        }
        else {
            my ( $caller_package, $caller_file, $caller_line, $called_sub ) = caller(1);
            my $just_sub_name =
              ( split( /::/, $called_sub ) )[-1];    ## no critic (ValuesAndExpressions::ProhibitMagicNumbers)
            croak(
                sprintf(
                    '"%s" was supplied with an unbalanced argument list (%d items). If passing an array, pass by reference. Called from %s line %d',
                    $just_sub_name, $counter, $caller_file, $caller_line
                )
            );
        }
    }
    elsif ( $ref eq 'HASH' ) {
        %results = $args[0];
    }
    else {
        croak("Invalid call. Must be passed a hash/associative array got $ref");
    }
    return %results;
}

sub _maybe_maketext_create_localizer () {

    # check if we already exist.
    if ( defined($maybe_maketext_localizer) ) {
        return $maybe_maketext_localizer;
    }

    my ( $package_name, $our_package, $package_data, $package_name_as_pm, @reasoning ) =
      ( undef, __PACKAGE__, undef, undef, () );

    # loop through the enabled ones
    push @reasoning, 'Found ' . ( scalar @maybe_maketext_localizers_to_use ) . ' possible localizers';
    for my $package_name (@maybe_maketext_localizers_to_use) {
        my %load_result = _maybe_maketext_get_packageloader()->attempt_package_load($package_name);
        if ( !$load_result{'status'} ) {
            push @reasoning, sprintf( 'Unable to get localizer %s as %s', $package_name, $load_result{'reasoning'} );
            next;
        }
        if (
            !eval {

                #  Needed to allow us to pick our parent
                push @ISA, $package_name;    ## no critic (ClassHierarchies::ProhibitExplicitISA)
                1;
            }
        ) {
            push @reasoning, sprintf( 'Unable to set parent localizer to %s due to %s', $package_name, $@ );
            next;
        }
        push @reasoning, sprintf( 'Set localizer to %s', $package_name );
        $maybe_maketext_localizer           = $package_name;
        @maybe_maketext_localizer_reasoning = @reasoning;
        return $maybe_maketext_localizer;

    }
    croak( sprintf( "No localizer found: \n    -%s\n", join( "\n    -", @reasoning ) ) );
}

sub _maybe_maketext_create_fake_locale ($locale) {
    state %locales_built;
    if ( exists( $locales_built{$locale} ) ) {
        my %current_status = @{ $locales_built{$locale} };
        if ( $current_status{'status'} == 1 ) {
            return 1;
        }
    }
    my ( $package_name_as_pm, $package ) = ( ( $locale =~ tr{:}{\/}rs ) . '.pm', __PACKAGE__ );

    # safety check
    if ( defined( $INC{$package_name_as_pm} ) ) {
        return $locales_built{$locale} = [ 'status' => 1, 'reasoning' => 'Already loaded' ];
    }

    my $package_data = sprintf( "package %s;\nuse parent '%s';\nour %%Lexicon=('_AUTO'=>1);\n1;\n", $locale, $package );

    if ( !eval "$package_data" ) {    ## no critic (BuiltinFunctions::ProhibitStringyEval)
        croak(
            sprintf(
                '_maybe_maketext_create_fake_locale: Unable to make fake package %s, %s', $locale,
                ( $@ || $! || '[Unknown reasoning]' )
            )
        );
    }

    $locales_built{$locale} = [ 'status' => 1, 'reasoning' => 'Generated' ];
    return 1;
}

=head2 _maybe_maketext_exit_if_invalid_text_domain

Validates that a string passed looks like it could be a valid text domain (either a package name,
an empty string or the keywords "default" or "main").

Internal Usage only.

=over

=item B<Parameters>

=over

=item string: C<$text_domain>: What is being validated.

=item string: C<$reason>: Why it is being validated.

=item boolean: C<$allow_blank>: Should a blank entry be allowed.

=back

=item B<Returns>

scalar: 1. Always

=item B<Warnings/Exceptions>

=over

=item Exception: C<Invalid text domain: "%s". Only package names...>

If the passed C<text_domain> is not a string/scalar or could not be matched to a locale

=back

=back

=cut

sub _maybe_maketext_exit_if_invalid_text_domain ( $text_domain, $reason, $allow_blank = 0 ) {
    my $failed =
      !defined($text_domain) ? '[Undefined]'
      : (
        ref($text_domain) // 0 ? sprintf( '[Type %s]', ref($text_domain) )
        : ( $text_domain eq q{} ? '[Empty string]' : 0 )
      );

    if ( !$failed ) {
        if (   $text_domain eq 'default'
            || $text_domain eq 'main'
            || _maybe_maketext_get_packageloader()->is_valid_package_name($text_domain) ) {
            return 1;
        }
    }
    if ($allow_blank) {
        return croak(
            sprintf(
                'Invalid text domain: "%s". Only package names, "" (empty string), "default" and "main" are supported %s',
                $failed || $text_domain, $reason
            )
        );
    }
    return croak(
        sprintf(
            'Invalid text domain: "%s". Only package names, "default" and "main" are supported %s',
            $failed || $text_domain, $reason
        )
    );
}

=head2 _maybe_maketext_exit_if_invalid_locale

Validates that a string passed looks like it could be a valid locale translation package name.

Internal Usage only.

=over

=item B<Parameters>

=over

=item string: C<$locale>: What is being validated.

=item string: C<$reason>: Why it is being validated.


=back

=item B<Returns>

scalar: 1. Always

=item B<Warnings/Exceptions>

=over


=item Exception: C<Invalid locale translation package: "%s". Only package names as strings are supported>

If the passed C<locale> is not a string/scalar or does not look like a package name.

=back

=back

=cut

sub _maybe_maketext_exit_if_invalid_locale ( $locale, $reason ) {
    my $failed =
      !defined($locale) ? '[Undefined]'
      : (
        ref($locale) // 0 ? sprintf( '[Type %s]', ref($locale) )
        : ( $locale eq q{} ? '[Empty string]' : 0 )
      );

    if ( !$failed && _maybe_maketext_get_packageloader()->is_valid_package_name($locale) ) {
        return 1;
    }
    return croak(
        sprintf(
            'Invalid locale translation package: "%s". Only package names as strings are supported %s',
            $failed || $locale, $reason
        )
    );
}

sub _maybe_maketext_get_raw_cache() {
    if ( !defined( $maybe_maketext_packages{'raw_cache'} ) ) {
        my $package = $maybe_maketext_packages_to_use{'cache'};
        $maybe_maketext_packages{'raw_cache'} = $package->new();
    }
    return $maybe_maketext_packages{'raw_cache'};
}

sub _maybe_maketext_get_our_cache() {
    if ( !defined( $maybe_maketext_packages{'our_cache'} ) ) {
        my $cache = _maybe_maketext_get_raw_cache();
        $maybe_maketext_packages{'our_cache'} = $cache->get_namespaced(__PACKAGE__);
    }
    return $maybe_maketext_packages{'our_cache'};
}

sub _maybe_maketext_get_language_code_validator() {
    if ( !defined( $maybe_maketext_packages{'language_code_validator'} ) ) {
        my $cache   = _maybe_maketext_get_raw_cache();
        my $package = _maybe_maketext_load_package('language_code_validator');
        $maybe_maketext_packages{'language_code_validator'} = $package->new( 'cache' => $cache );
    }
    return $maybe_maketext_packages{'language_code_validator'};
}

sub _maybe_maketext_load_package ($package_reference) {
    if ( !defined( $maybe_maketext_packages_to_use{$package_reference} ) ) {
        croak( sprintf( 'Unrecognised package reference %s', $package_reference ) );
    }
    my $package_to_use = $maybe_maketext_packages_to_use{$package_reference};
    my %results        = _maybe_maketext_get_packageloader()->attempt_package_load($package_to_use);
    if ( $results{'status'} != 1 ) {
        croak( sprintf( 'Unable to load %s (%s): %s', $package_reference, $package_to_use, $results{'reasoning'} ) );
    }
    return $maybe_maketext_packages_to_use{$package_reference};
}

sub _maybe_maketext_get_language_finder() {
    if ( !defined( $maybe_maketext_packages{'language_finder'} ) ) {
        my $cache = _maybe_maketext_get_raw_cache();
        my $package;
        if ( !defined( $maybe_maketext_packages{'alternatives'} ) ) {
            $package = _maybe_maketext_load_package('alternatives');
            $maybe_maketext_packages{'alternatives'} = $package->new( 'cache' => $cache );
        }
        if ( !defined( $maybe_maketext_packages{'supers'} ) ) {
            $package = _maybe_maketext_load_package('supers');
            $maybe_maketext_packages{'supers'} = $package->new();
        }
        $package = _maybe_maketext_load_package('language_finder');
        $maybe_maketext_packages{'language_finder'} = $package->new(
            'language_code_validator' => _maybe_maketext_get_language_code_validator(),
            'alternatives'            => $maybe_maketext_packages{'alternatives'},
            'supers'                  => $maybe_maketext_packages{'supers'},
            'package_loader'          => _maybe_maketext_get_packageloader(),
            'cache'                   => $cache
        );
    }
    return $maybe_maketext_packages{'language_finder'};
}

sub _maybe_maketext_get_packageloader() {
    if ( !defined( $maybe_maketext_packages{'package_loader'} ) ) {
        my $package_to_use = $maybe_maketext_packages_to_use{'package_loader'};
        my $cache          = _maybe_maketext_get_raw_cache();
        $maybe_maketext_packages{'package_loader'} = $package_to_use->new( 'cache' => $cache );
    }
    return $maybe_maketext_packages{'package_loader'};
}

1;
