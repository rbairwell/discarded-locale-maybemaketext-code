package Locale::MaybeMaketext::Detectors::Cpanel;

use strict;
use warnings;
use vars;
use utf8;
use Carp         qw/croak carp/;
use Scalar::Util qw/blessed/;
use feature      qw/signatures/;
no warnings qw/experimental::signatures/;
use parent 'Locale::MaybeMaketext::Detectors::Cpanel::AbstractParent';

=encoding utf8

=head1 NAME

Locale::MaybeMaketext::Detectors::Cpanel - Find a user's preferred locale on a cPanel based server.

=head1 SYNOPSIS

=head1 DESCRIPTION

According to L<Cpanel's Guide to Locales - Basic Usage|https://api.docs.cpanel.net/guides/guide-to-locales/guide-to-locales-basic-usage/> ,
to find out the user's locale you use:
    use Cpanel::Locale();
    my $locale = Cpanel::Locale->get_handle();

which calls C<preinit>:
    * If C<Cpanel.pm> is loaded but there is no C<$Cpanel::CPDATA{'LOCALE'}> then
      - Call C<Cpanel::Locale::Utils::User::init_cpdata_keys()>
    * If there is an C<$ENV{'HTTP_COOKIE'> and no C<%Cpanel::Cookies:>
       - Set C<%Cpanel::Cookies> to C<%Cpanel::Cookies::get_cookie_hashref()>

C<get_handle> then calls an alias to C<_real_get_handle> which calls C<_setup_for_real_get_handle>
    - If C<Cpanel::App::appname> is set and is 'C<whostmgr>' and if C<$ENV{'REMOTE_USER'}> is set and is not root:
        * Uses C<Cpanel::Config::HasCpUserFile::has_readable_cpuser_file()> to lookup the C<$ENV{'REMOTE_USER'}>
        * Reads in the data from C<Cpanel::Config::LoadCpUserFile::CurrentUser::load()>
        * Stores it into C<$Cpanel::CPDATA>
    - Then it checks the following, stopping once one matches:
    - If C<$Cpanel::Cookies{'session_locale'}> is set, then pass to
       C<Cpanel::Locale::Utils::Legacy::_map_any_old_style_to_new_style>
    - Then it checks C<$Cpanel::CPDATA{'LOCALE'}>
    - Then it checks C<$Cpanel::CPDATA{'LANG'}> (passing to C<_map_any_old_style_to_new_style>)
    - Then it checks C<get_server_locale()>
        * C<get_server_locale> returns C<$ENV{'CPANEL_SERVER_LOCALE'}> if it passes a regexp test.
        * If the environment variable isn't set, but C<$main::CPCONF{'server_locale'}> is set,
          then that is returned.
        * If not, it returns the contents of C</var/cpanel/server_locale> (which isn't needed since cPanel v70)
C<_real_get_handle> then filters them through C<cpanel_is_valid_locale> (replacing C<en_us> or C<i_default> with just C<en>).

C<cpanel_is_valid_locale> filters against the list of locales provided by
C<Cpanel::CPAN::Locale::Maketext::Utils::list_available_locales> which
reads in the list of files from C<_base_class_dir> which then
gets reads the location of C<Cpanel::Locale> and returns that respective directory
(usually F</usr/local/cpanel/Cpanel/Locale/> ) after filtering out some files.

=head2 Other Locale Sources

=head3 Cpanel::Locale

Cpanel::Locale 

- C<get_user_locale> returns C<$Cpanel::CPDATA{'LOCALE'}> if set, if not, returns
  C<Cpanel::Locale::Utils::User::get_user_locale()>

- C<get_user_locale_name> returns C<Cpanel::Locale::Utils::User::get_user_locale>

For L<api2_|https://documentation.cpanel.net/display/DD/Guide+to+cPanel+API+2> compatibility, it also has
the following alaises:

- C<api2_get_user_locale> is an alias to C<get_user_locale>

- C<api2_get_user_locale_name> is an alias to C<get_user_locale_name>

=head3 LiveAPI

- L<get_attributes call|https://api.docs.cpanel.net/openapi/cpanel/operation/get_attributes/>
  will return the direction, encoding and language name.

- L<get_user_information call|https://api.docs.cpanel.net/openapi/cpanel/operation/Variables-get_user_information/>
  will return the "lang" along with other data.

=cut

sub run_detect ($self) {

    if ( !blessed($self) || !( $self->isa(__PACKAGE__) ) ) {
        croak( sprintf( 'run_detect should be passed an instance of its object %s', __PACKAGE__ ) );
    }
    my ( @reasoning, @languages ) = ( (), () );

    my @check_classes = qw/Cookies CPData I18N Env ServerLocale/;
    my $prefix        = __PACKAGE__;
    for my $current_class (@check_classes) {
        my $full_class_name = sprintf( '%s::%s', $prefix, $current_class );
        my @current_languages;
        @reasoning = $self->load_package_and_run_in_eval(
            $full_class_name,
            sub {
                my $detecting = $full_class_name->new(
                    'language_code_validator' => $self->{'language_code_validator'},
                    'package_loader'          => $self->{'package_loader'},
                    'cache'                   => $self->{'_raw_cache'},
                );
                my %results = $detecting->run_detect();
                @current_languages = @{ $results{'languages'} };
                my @temp_reasoning;
                for my $line ( @{ $results{'reasoning'} } ) {
                    push @temp_reasoning, sprintf( '  %s: %s', $current_class, $line );
                }
                return @temp_reasoning;
            },
            @reasoning
        );
        push @reasoning, sprintf( '%s: Found %d potential languages', $current_class, scalar(@current_languages) );
        @languages = ( @languages, @current_languages );
    }
    return ( 'languages' => \@languages, 'reasoning' => \@reasoning );
}

1;
