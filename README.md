Whilst developing the Perl module [Locale::MaybeMaketext](https://github.com/bairwell/Locale-MaybeMaketext) (now available on [CPAN](https://metacpan.org/pod/Locale::MaybeMaketext)!) , I started off in in one direction but decided it was all overkill in more than one way - but at least it helped me ease back into Perl development.

I've kept this code though as it may be useful for myself, or others, to revisit in the future. For example, it has:
* Various in-built language detection files (based on third party code which was difficult to invoke seperately/directly) within `Detectors`
* It has a better language code validator (`LanguageCodeValidator`) which is based off [RFC5646](https://www.rfc-editor.org/rfc/rfc5646.html) meaning it can cope with language codes such as `en-latn-gb-u-jxds-t-cklsd-tester-dlsk-cx` along with "grandfathered" codes such as `en-gb-oed` and can handle alternatives (such as converting `en-uk` to `en-gb` and can be updated from the [IANA list](https://www.iana.org/assignments/language-subtag-registry/language-subtag-registry) using `tools/build_alternatives.pl`
* Has got the ability to change alternatives (see above) using `Alternatives` and `Supers` (including all permutations of any language extensions)
* Has a very flexible configuration system(`LanguageFinder` and `LanguageFinderProcessor`) allowing you to specify in detail how a language code should be detected and handled (want to check the CLI first and then expand any alternatives before checking web codes - then that is possible!)
* Has a nifty `PackageLoader` which can check if a module is already loaded, load it (and handle errors appropriately) and double check if it was actually loaded or failed on loading.
* Has its own mock system (in `t/lib/Locale/MaybeMaketext/Tests/Overrider`) which not only allows classes/packages to be easily mocked for testing, but also for file system level calls (such as `open`, `close` and `read`) to be mocked.
* Has quite extensive testing of all of the above (although the tests are probably outdated by now)

Hopefully some use will come to this unused code! It's MIT licensed so feel free to play!