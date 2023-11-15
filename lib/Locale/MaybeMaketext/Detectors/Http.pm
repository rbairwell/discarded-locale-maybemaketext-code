package Locale::MaybeMaketext::Detectors::Http;

use strict;
use warnings;
use vars;
use utf8;
use autodie      qw/:all/;
use feature      qw/signatures/;
use Carp         qw/croak/;
use Scalar::Util qw/blessed/;
no warnings qw/experimental::signatures/;
use constant QUALITY_ORDER_DIVIDER => 1000;
our $VERSION = '0.01';

=head1 NAME

Locale::MaybeMaketext::Detectors::Http - Detect user specified languages from the HTTP Accept-Language tag.

=head1 SYNOPSIS

    use Locale::MaybeMaketext::Detectors::Http;
    my $results=Locale::MaybeMaketext::Detectors::Http->detect();
    print "Detected languages (in preference order): ".join(q{, },$results->['languages'})."\n";
    print "Why this list?: ".join("\n",$results->{'reasoning'})."\n";

=head1 DESCRIPTION

C<Locale::MaybeMaketext::Detectors::Http> reads the environment variable
HTTP_ACCEPT_LANGUAGE (i.e. a web browser sent the header Accept-Language) and tries to extract the relevant
language codes in the correct order from the it.

=cut

=for comment

The standard for the HTTP header Accept-Language is defined under
L<RFC9110 s12.5.4|https://www.rfc-editor.org/rfc/rfc9110.html#name-accept-language> :
  Accept-Language = #( language-range [ weight ] )
     language-range = <language-range, see [RFC4647], Section 2.1>

"Language-range" is also defined in the same RFC under:
L<s12.4.2|https://www.rfc-editor.org/rfc/rfc9110.html#language.tags|s8.5.1>
and "Weight" is defined in L<https://www.rfc-editor.org/rfc/rfc9110.html#quality.values>
   weight = OWS ";" OWS "q=" qvalue
    qvalue = ( "0" [ "." 0 * 3 DIGIT ] ) / ( "1" [ "." 0 * 3 ("0") ] )

Tracking down this is a bit tricky as:
 RFC9110 "HTTP Semantics" updates
  - RFC3864 "Registration Procedures for Message Header Fields"
 and obsoletes:
  - RFC2818 "HTTP Over TLS"
  - RFC7230 "Hypertext Transfer Protocol (HTTP/1.1): Message Syntax and Routing"
  - RFC7231 "Hypertext Transfer Protocol (HTTP/1.1): Semantics and Content"
  - RFC7232 "Hypertext Transfer Protocol (HTTP/1.1): Conditional Requests"
  - RFC7233 "Hypertext Transfer Protocol (HTTP/1.1): Range Requests"
  - RFC7235 "Hypertext Transfer Protocol (HTTP/1.1): Authentication"
  - RFC7238 "The Hypertext Transfer Protocol Status Code 308 (Permanent Redirect)"
  - RFC7615 "HTTP Authentication-Info and Proxy-Authentication-Info Response Header Fields"
  - RFC7694 "Hypertext Transfer Protocol (HTTP) Client-Initiated Content-Encoding"

 RFC4647 "Matching of Language Tags" which (with RFC4646 "Tags for identifying languages") obsoleted:
  -  RFC3066 "Tags for the Identification of Languages" which obsoleted
       - RFC1766 "Tags for the Identification of Languages"

=cut

=head1 FUNCTIONS

=cut

=head2 detect

Detects the appropriate language.

=over

=item B<Example usage>

    use Locale::MaybeMaketext::Detectors::Http;
    my $results = Locale::MaybeMaketext::Detectors::Http->detect();

=item B<Parameters>

None

=item B<Returns>

hash: Containing two values "languages" (an array in order of preference) and "reasoning" (an array of reasonss for that list).

=back

=cut

sub detect (%params) {
    my %needed = (
        'language_code_validator' => 'Locale::MaybeMaketext::LanguageCodeValidator',
    );
    for my $field ( sort keys(%needed) ) {
        if ( !defined( $params{$field} ) ) {
            croak( sprintf( 'Missing needed configuration setting "%s"', $field ) );
        }
        if ( !blessed( $params{$field} ) ) {
            croak(
                sprintf(
                    'Configuration setting "%s" must be a blessed object: instead got %s', $field,
                    ref( $params{$field} ) ? ref( $params{$field} ) : 'scalar:' . $params{$field}
                )
            );
        }
        if ( !$params{$field}->isa( $needed{$field} ) ) {
            croak(
                sprintf(
                    'Configuration setting "%s" must be an instance of "%s": got "%s"',
                    $field, $needed{$field}, ref( $params{$field} )
                )
            );
        }
    }

    # main code
    my ( @reasoning, @sorted_languages, @invalid_languages ) = ( (), (), () );
    if ( !defined( $ENV{'HTTP_ACCEPT_LANGUAGE'} ) ) {
        push @reasoning, 'No HTTP_ACCEPT_LANGUAGE environment set';
        return (
            'languages'         => \@sorted_languages,
            'invalid_languages' => \@invalid_languages,
            'reasoning'         => \@reasoning
        );
    }
    my $accept_language_header = $ENV{'HTTP_ACCEPT_LANGUAGE'};
    my $quality_regexp =
      '(?:0(?:\.\d{0,3})?|1(?:\.0{0,3})?)';    # levels can be 0.000 to 1.000 (decimals precision 0 to 3).
    my %highest_quality_per_language;
    push @reasoning, sprintf( 'Processing HTTP_ACCEPT_LANGUAGE: %s', $accept_language_header );

    # change dashes to underscores, lowercase and then remove spaces.
    $accept_language_header = lc( $accept_language_header =~ tr{-}{_}r ) =~ s/\s//gr;
    my @split_langs    = split( /,+/, $accept_language_header );
    my $order_priority = scalar(@split_langs);

    for my $current (@split_langs) {
        $order_priority--;
        my @split_item = split( /;/, $current, 2 );
        push @reasoning, sprintf( 'Processing %s - split into %s', $current, join( q{' and '}, @split_item ) );
        my %lang_validated = $params{'language_code_validator'}->validate( $split_item[0] );
        if ( $lang_validated{'status'} ) {
            my ( $lang, $quality ) = ( $lang_validated{'code'}, 1 );
            if ( defined( $split_item[1] ) && $split_item[1] =~ /\Aq=(?<quality>$quality_regexp)\z/ ) {
                $quality = $+{'quality'};
            }
            if ( $quality == 0 ) {
                push @reasoning,         sprintf( 'Zero Quality setting for %s . Skipping', $current );
                push @invalid_languages, $lang;
                next;
            }

            # add a larger (tiny) increment the earlier we find the language to aid in later sorting
            $quality = $quality + ( $order_priority / QUALITY_ORDER_DIVIDER );
            if ( !exists( $highest_quality_per_language{$lang} ) || $quality > $highest_quality_per_language{$lang} ) {
                push @reasoning, sprintf( 'Storing %s with quality score of %d', $lang, $quality );
                $highest_quality_per_language{$lang} = $quality;
            }

        }
        else {
            push @reasoning,         sprintf( 'Rejected invalid language line: %s', $split_item[0] );
            push @invalid_languages, $split_item[0];
            next;
        }
    }

    # now to figure out which language has the highest quality
    @sorted_languages = reverse sort { $highest_quality_per_language{$a} <=> $highest_quality_per_language{$b} }
      keys(%highest_quality_per_language);
    return (
        'languages'         => \@sorted_languages,
        'reasoning'         => \@reasoning,
        'invalid_languages' => \@invalid_languages
    );
}

1;
