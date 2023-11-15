package Locale::MaybeMaketext::Alternatives;

# pragmas
use v5.20.0;
use strict;
use warnings;
use vars;
use utf8;

use autodie      qw/:all/;
use feature      qw/signatures/;
use Scalar::Util qw/blessed/;
no if $] >= 5.032, q|feature|, qw/indirect/;
no warnings qw/experimental::signatures/;

my @field_parts = qw/language extlang script region variant extension irregular regular/;

# Generated languages
my %languages = (
    'aam' => 'aas',
    'adp' => 'dz',
    'ajp' => 'apc',
    'ajt' => 'aeb',
    'asd' => 'snz',
    'aue' => 'ktz',
    'ayx' => 'nun',
    'bgm' => 'bcg',
    'bic' => 'bir',
    'bjd' => 'drl',
    'blg' => 'iba',
    'ccq' => 'rki',
    'cjr' => 'mom',
    'cka' => 'cmr',
    'cmk' => 'xch',
    'coy' => 'pij',
    'cqu' => 'quh',
    'dit' => 'dif',
    'drh' => 'khk',
    'drr' => 'kzk',
    'drw' => 'prs',
    'gav' => 'dev',
    'gfx' => 'vaj',
    'ggn' => 'gvr',
    'gli' => 'kzk',
    'gti' => 'nyc',
    'guv' => 'duz',
    'hrr' => 'jal',
    'ibi' => 'opa',
    'ilw' => 'gal',
    'in'  => 'id',
    'iw'  => 'he',
    'jeg' => 'oyb',
    'ji'  => 'yi',
    'jw'  => 'jv',
    'kgc' => 'tdf',
    'kgh' => 'kml',
    'kgm' => 'plu',
    'koj' => 'kwv',
    'krm' => 'bmf',
    'ktr' => 'dtp',
    'kvs' => 'gdj',
    'kwq' => 'yam',
    'kxe' => 'tvd',
    'kxl' => 'kru',
    'kzj' => 'dtp',
    'kzt' => 'dtp',
    'lak' => 'ksp',
    'lii' => 'raq',
    'llo' => 'ngt',
    'lmm' => 'rmx',
    'meg' => 'cir',
    'mo'  => 'ro',
    'mst' => 'mry',
    'mwj' => 'vaj',
    'myd' => 'aog',
    'myt' => 'mry',
    'nad' => 'xny',
    'ncp' => 'kdz',
    'nns' => 'nbr',
    'nnx' => 'ngv',
    'nom' => 'cbr',
    'nts' => 'pij',
    'nxu' => 'bpp',
    'oun' => 'vaj',
    'pat' => 'kxr',
    'pcr' => 'adx',
    'pmc' => 'huw',
    'pmk' => 'crr',
    'pmu' => 'phr',
    'ppa' => 'bfy',
    'ppr' => 'lcq',
    'prp' => 'gu',
    'pry' => 'prt',
    'puz' => 'pub',
    'sca' => 'hle',
    'skk' => 'oyb',
    'smd' => 'kmb',
    'snb' => 'iba',
    'szd' => 'umi',
    'tdu' => 'dtp',
    'thc' => 'tpo',
    'thw' => 'ola',
    'thx' => 'oyb',
    'tie' => 'ras',
    'tkk' => 'twm',
    'tlw' => 'weo',
    'tmk' => 'tdg',
    'tmp' => 'tyj',
    'tne' => 'kak',
    'tnf' => 'prs',
    'tpw' => 'tpn',
    'tsf' => 'taj',
    'uok' => 'ema',
    'xba' => 'cax',
    'xia' => 'acn',
    'xkh' => 'waw',
    'xrq' => 'dmw',
    'xss' => 'zko',
    'ybd' => 'rki',
    'yma' => 'lrr',
    'ymt' => 'mtm',
    'yos' => 'zom',
    'yuu' => 'yug',
    'zir' => 'scv',
    'zkb' => 'kjh',

    # start of backmaps
    'aas' => 'aam',
    'acn' => 'xia',
    'adx' => 'pcr',
    'aeb' => 'ajt',
    'aog' => 'myd',
    'apc' => 'ajp',
    'bcg' => 'bgm',
    'bfy' => 'ppa',
    'bir' => 'bic',
    'bmf' => 'krm',
    'bpp' => 'nxu',
    'cax' => 'xba',
    'cbr' => 'nom',
    'cir' => 'meg',
    'cmr' => 'cka',
    'crr' => 'pmk',
    'dev' => 'gav',
    'dif' => 'dit',
    'dmw' => 'xrq',
    'drl' => 'bjd',
    'dtp' => 'ktr',
    'duz' => 'guv',
    'dz'  => 'adp',
    'ema' => 'uok',
    'gal' => 'ilw',
    'gdj' => 'kvs',
    'gu'  => 'prp',
    'gvr' => 'ggn',
    'he'  => 'iw',
    'hle' => 'sca',
    'huw' => 'pmc',
    'iba' => 'blg',
    'id'  => 'in',
    'jal' => 'hrr',
    'jv'  => 'jw',
    'kak' => 'tne',
    'kdz' => 'ncp',
    'khk' => 'drh',
    'kjh' => 'zkb',
    'kmb' => 'smd',
    'kml' => 'kgh',
    'kru' => 'kxl',
    'ksp' => 'lak',
    'ktz' => 'aue',
    'kwv' => 'koj',
    'kxr' => 'pat',
    'kzk' => 'drr',
    'lcq' => 'ppr',
    'lrr' => 'yma',
    'mom' => 'cjr',
    'mry' => 'mst',
    'mtm' => 'ymt',
    'nbr' => 'nns',
    'ngt' => 'llo',
    'ngv' => 'nnx',
    'nun' => 'ayx',
    'nyc' => 'gti',
    'ola' => 'thw',
    'opa' => 'ibi',
    'oyb' => 'jeg',
    'phr' => 'pmu',
    'pij' => 'coy',
    'plu' => 'kgm',
    'prs' => 'drw',
    'prt' => 'pry',
    'pub' => 'puz',
    'quh' => 'cqu',
    'raq' => 'lii',
    'ras' => 'tie',
    'rki' => 'ccq',
    'rmx' => 'lmm',
    'ro'  => 'mo',
    'scv' => 'zir',
    'snz' => 'asd',
    'taj' => 'tsf',
    'tdf' => 'kgc',
    'tdg' => 'tmk',
    'tpn' => 'tpw',
    'tpo' => 'thc',
    'tvd' => 'kxe',
    'twm' => 'tkk',
    'tyj' => 'tmp',
    'umi' => 'szd',
    'vaj' => 'gfx',
    'waw' => 'xkh',
    'weo' => 'tlw',
    'xch' => 'cmk',
    'xny' => 'nad',
    'yam' => 'kwq',
    'yi'  => 'ji',
    'yug' => 'yuu',
    'zko' => 'xss',
    'zom' => 'yos',
);

# Generated regions
my %regions = (
    'bu' => 'mm',
    'dd' => 'de',
    'fx' => 'fr',
    'tp' => 'tl',
    'yd' => 'ye',
    'zr' => 'cd',

    # start of backmaps
    'cd' => 'zr',
    'de' => 'dd',
    'fr' => 'fx',
    'mm' => 'bu',
    'tl' => 'tp',
    'ye' => 'yd',
);

# Generated full strings
my %fulls = (
    'ar_aao'                 => 'aao',
    'ar_abh'                 => 'abh',
    'ar_abv'                 => 'abv',
    'ar_acm'                 => 'acm',
    'ar_acq'                 => 'acq',
    'ar_acw'                 => 'acw',
    'ar_acx'                 => 'acx',
    'ar_acy'                 => 'acy',
    'ar_adf'                 => 'adf',
    'ar_aeb'                 => 'aeb',
    'ar_aec'                 => 'aec',
    'ar_afb'                 => 'afb',
    'ar_ajp'                 => 'ajp',
    'ar_apc'                 => 'apc',
    'ar_apd'                 => 'apd',
    'ar_arb'                 => 'arb',
    'ar_arq'                 => 'arq',
    'ar_ars'                 => 'ars',
    'ar_ary'                 => 'ary',
    'ar_arz'                 => 'arz',
    'ar_auz'                 => 'auz',
    'ar_avl'                 => 'avl',
    'ar_ayh'                 => 'ayh',
    'ar_ayl'                 => 'ayl',
    'ar_ayn'                 => 'ayn',
    'ar_ayp'                 => 'ayp',
    'ar_bbz'                 => 'bbz',
    'ar_pga'                 => 'pga',
    'ar_shu'                 => 'shu',
    'ar_ssh'                 => 'ssh',
    'art_lojban'             => 'jbo',
    'en_gb_oed'              => 'en_gb_oxendict',
    'i_ami'                  => 'ami',
    'i_bnn'                  => 'bnn',
    'i_hak'                  => 'hak',
    'i_klingon'              => 'tlh',
    'i_lux'                  => 'lb',
    'i_navajo'               => 'nv',
    'i_pwn'                  => 'pwn',
    'i_tao'                  => 'tao',
    'i_tay'                  => 'tay',
    'i_tsu'                  => 'tsu',
    'ja_latn_hepburn_heploc' => 'ja_latn_alalc97',
    'kok_gom'                => 'gom',
    'kok_knn'                => 'knn',
    'lv_ltg'                 => 'ltg',
    'lv_lvs'                 => 'lvs',
    'ms_bjn'                 => 'bjn',
    'ms_btj'                 => 'btj',
    'ms_bve'                 => 'bve',
    'ms_bvu'                 => 'bvu',
    'ms_coa'                 => 'coa',
    'ms_dup'                 => 'dup',
    'ms_hji'                 => 'hji',
    'ms_jak'                 => 'jak',
    'ms_jax'                 => 'jax',
    'ms_kvb'                 => 'kvb',
    'ms_kvr'                 => 'kvr',
    'ms_kxd'                 => 'kxd',
    'ms_lce'                 => 'lce',
    'ms_lcf'                 => 'lcf',
    'ms_liw'                 => 'liw',
    'ms_max'                 => 'max',
    'ms_meo'                 => 'meo',
    'ms_mfa'                 => 'mfa',
    'ms_mfb'                 => 'mfb',
    'ms_min'                 => 'min',
    'ms_mqg'                 => 'mqg',
    'ms_msi'                 => 'msi',
    'ms_mui'                 => 'mui',
    'ms_orn'                 => 'orn',
    'ms_ors'                 => 'ors',
    'ms_pel'                 => 'pel',
    'ms_pse'                 => 'pse',
    'ms_tmw'                 => 'tmw',
    'ms_urk'                 => 'urk',
    'ms_vkk'                 => 'vkk',
    'ms_vkt'                 => 'vkt',
    'ms_xmm'                 => 'xmm',
    'ms_zlm'                 => 'zlm',
    'ms_zmi'                 => 'zmi',
    'ms_zsm'                 => 'zsm',
    'no_bok'                 => 'nb',
    'no_nyn'                 => 'nn',
    'sgn_ads'                => 'ads',
    'sgn_aed'                => 'aed',
    'sgn_aen'                => 'aen',
    'sgn_afg'                => 'afg',
    'sgn_ajs'                => 'ajs',
    'sgn_ase'                => 'ase',
    'sgn_asf'                => 'asf',
    'sgn_asp'                => 'asp',
    'sgn_asq'                => 'asq',
    'sgn_asw'                => 'asw',
    'sgn_be_fr'              => 'sfb',
    'sgn_be_nl'              => 'vgt',
    'sgn_bfi'                => 'bfi',
    'sgn_bfk'                => 'bfk',
    'sgn_bog'                => 'bog',
    'sgn_bqn'                => 'bqn',
    'sgn_bqy'                => 'bqy',
    'sgn_br'                 => 'bzs',
    'sgn_bvl'                => 'bvl',
    'sgn_bzs'                => 'bzs',
    'sgn_cds'                => 'cds',
    'sgn_ch_de'              => 'sgg',
    'sgn_co'                 => 'csn',
    'sgn_csc'                => 'csc',
    'sgn_csd'                => 'csd',
    'sgn_cse'                => 'cse',
    'sgn_csf'                => 'csf',
    'sgn_csg'                => 'csg',
    'sgn_csl'                => 'csl',
    'sgn_csn'                => 'csn',
    'sgn_csq'                => 'csq',
    'sgn_csr'                => 'csr',
    'sgn_csx'                => 'csx',
    'sgn_de'                 => 'gsg',
    'sgn_dk'                 => 'dsl',
    'sgn_doq'                => 'doq',
    'sgn_dse'                => 'dse',
    'sgn_dsl'                => 'dsl',
    'sgn_dsz'                => 'dsz',
    'sgn_ecs'                => 'ecs',
    'sgn_ehs'                => 'ehs',
    'sgn_es'                 => 'ssp',
    'sgn_esl'                => 'esl',
    'sgn_esn'                => 'esn',
    'sgn_eso'                => 'eso',
    'sgn_eth'                => 'eth',
    'sgn_fcs'                => 'fcs',
    'sgn_fr'                 => 'fsl',
    'sgn_fse'                => 'fse',
    'sgn_fsl'                => 'fsl',
    'sgn_fss'                => 'fss',
    'sgn_gb'                 => 'bfi',
    'sgn_gds'                => 'gds',
    'sgn_gr'                 => 'gss',
    'sgn_gse'                => 'gse',
    'sgn_gsg'                => 'gsg',
    'sgn_gsm'                => 'gsm',
    'sgn_gss'                => 'gss',
    'sgn_gus'                => 'gus',
    'sgn_hab'                => 'hab',
    'sgn_haf'                => 'haf',
    'sgn_hds'                => 'hds',
    'sgn_hks'                => 'hks',
    'sgn_hos'                => 'hos',
    'sgn_hps'                => 'hps',
    'sgn_hsh'                => 'hsh',
    'sgn_hsl'                => 'hsl',
    'sgn_icl'                => 'icl',
    'sgn_ie'                 => 'isg',
    'sgn_iks'                => 'iks',
    'sgn_ils'                => 'ils',
    'sgn_inl'                => 'inl',
    'sgn_ins'                => 'ins',
    'sgn_ise'                => 'ise',
    'sgn_isg'                => 'isg',
    'sgn_isr'                => 'isr',
    'sgn_it'                 => 'ise',
    'sgn_jcs'                => 'jcs',
    'sgn_jhs'                => 'jhs',
    'sgn_jks'                => 'jks',
    'sgn_jls'                => 'jls',
    'sgn_jos'                => 'jos',
    'sgn_jp'                 => 'jsl',
    'sgn_jsl'                => 'jsl',
    'sgn_jus'                => 'jus',
    'sgn_kgi'                => 'kgi',
    'sgn_kvk'                => 'kvk',
    'sgn_lbs'                => 'lbs',
    'sgn_lgs'                => 'lgs',
    'sgn_lls'                => 'lls',
    'sgn_lsb'                => 'lsb',
    'sgn_lsc'                => 'lsc',
    'sgn_lsg'                => 'lsg',
    'sgn_lsl'                => 'lsl',
    'sgn_lsn'                => 'lsn',
    'sgn_lso'                => 'lso',
    'sgn_lsp'                => 'lsp',
    'sgn_lst'                => 'lst',
    'sgn_lsv'                => 'lsv',
    'sgn_lsw'                => 'lsw',
    'sgn_lsy'                => 'lsy',
    'sgn_lws'                => 'lws',
    'sgn_mdl'                => 'mdl',
    'sgn_mfs'                => 'mfs',
    'sgn_mre'                => 'mre',
    'sgn_msd'                => 'msd',
    'sgn_msr'                => 'msr',
    'sgn_mx'                 => 'mfs',
    'sgn_mzc'                => 'mzc',
    'sgn_mzg'                => 'mzg',
    'sgn_mzy'                => 'mzy',
    'sgn_nbs'                => 'nbs',
    'sgn_ncs'                => 'ncs',
    'sgn_ni'                 => 'ncs',
    'sgn_nl'                 => 'dse',
    'sgn_no'                 => 'nsl',
    'sgn_nsi'                => 'nsi',
    'sgn_nsl'                => 'nsl',
    'sgn_nsp'                => 'nsp',
    'sgn_nsr'                => 'nsr',
    'sgn_nzs'                => 'nzs',
    'sgn_okl'                => 'okl',
    'sgn_pgz'                => 'pgz',
    'sgn_pks'                => 'pks',
    'sgn_prl'                => 'prl',
    'sgn_prz'                => 'prz',
    'sgn_psc'                => 'psc',
    'sgn_psd'                => 'psd',
    'sgn_psg'                => 'psg',
    'sgn_psl'                => 'psl',
    'sgn_pso'                => 'pso',
    'sgn_psp'                => 'psp',
    'sgn_psr'                => 'psr',
    'sgn_pt'                 => 'psr',
    'sgn_pys'                => 'pys',
    'sgn_rib'                => 'rib',
    'sgn_rms'                => 'rms',
    'sgn_rnb'                => 'rnb',
    'sgn_rsi'                => 'rsi',
    'sgn_rsl'                => 'rsl',
    'sgn_rsm'                => 'rsm',
    'sgn_rsn'                => 'rsn',
    'sgn_sdl'                => 'sdl',
    'sgn_se'                 => 'swl',
    'sgn_sfb'                => 'sfb',
    'sgn_sfs'                => 'sfs',
    'sgn_sgg'                => 'sgg',
    'sgn_sgx'                => 'sgx',
    'sgn_slf'                => 'slf',
    'sgn_sls'                => 'sls',
    'sgn_sqk'                => 'sqk',
    'sgn_sqs'                => 'sqs',
    'sgn_sqx'                => 'sqx',
    'sgn_ssp'                => 'ssp',
    'sgn_ssr'                => 'ssr',
    'sgn_svk'                => 'svk',
    'sgn_swl'                => 'swl',
    'sgn_syy'                => 'syy',
    'sgn_szs'                => 'szs',
    'sgn_tse'                => 'tse',
    'sgn_tsm'                => 'tsm',
    'sgn_tsq'                => 'tsq',
    'sgn_tss'                => 'tss',
    'sgn_tsy'                => 'tsy',
    'sgn_tza'                => 'tza',
    'sgn_ugn'                => 'ugn',
    'sgn_ugy'                => 'ugy',
    'sgn_ukl'                => 'ukl',
    'sgn_uks'                => 'uks',
    'sgn_us'                 => 'ase',
    'sgn_vgt'                => 'vgt',
    'sgn_vsi'                => 'vsi',
    'sgn_vsl'                => 'vsl',
    'sgn_vsv'                => 'vsv',
    'sgn_wbs'                => 'wbs',
    'sgn_xki'                => 'xki',
    'sgn_xml'                => 'xml',
    'sgn_xms'                => 'xms',
    'sgn_yds'                => 'yds',
    'sgn_ygs'                => 'ygs',
    'sgn_yhs'                => 'yhs',
    'sgn_ysl'                => 'ysl',
    'sgn_ysm'                => 'ysm',
    'sgn_za'                 => 'sfs',
    'sgn_zib'                => 'zib',
    'sgn_zsl'                => 'zsl',
    'sw_swc'                 => 'swc',
    'sw_swh'                 => 'swh',
    'uz_uzn'                 => 'uzn',
    'uz_uzs'                 => 'uzs',
    'zh_cdo'                 => 'cdo',
    'zh_cjy'                 => 'cjy',
    'zh_cmn'                 => 'cmn',
    'zh_cmn_hans'            => 'cmn_hans',
    'zh_cmn_hant'            => 'cmn_hant',
    'zh_cnp'                 => 'cnp',
    'zh_cpx'                 => 'cpx',
    'zh_csp'                 => 'csp',
    'zh_czh'                 => 'czh',
    'zh_czo'                 => 'czo',
    'zh_gan'                 => 'gan',
    'zh_guoyu'               => 'cmn',
    'zh_hak'                 => 'hak',
    'zh_hakka'               => 'hak',
    'zh_hsn'                 => 'hsn',
    'zh_lzh'                 => 'lzh',
    'zh_min_nan'             => 'nan',
    'zh_mnp'                 => 'mnp',
    'zh_nan'                 => 'nan',
    'zh_wuu'                 => 'wuu',
    'zh_xiang'               => 'hsn',
    'zh_yue'                 => 'yue',

    # start of backmaps
    'aao'             => 'ar_aao',
    'abh'             => 'ar_abh',
    'abv'             => 'ar_abv',
    'acm'             => 'ar_acm',
    'acq'             => 'ar_acq',
    'acw'             => 'ar_acw',
    'acx'             => 'ar_acx',
    'acy'             => 'ar_acy',
    'adf'             => 'ar_adf',
    'ads'             => 'sgn_ads',
    'aeb'             => 'ar_aeb',
    'aec'             => 'ar_aec',
    'aed'             => 'sgn_aed',
    'aen'             => 'sgn_aen',
    'afb'             => 'ar_afb',
    'afg'             => 'sgn_afg',
    'ajp'             => 'ar_ajp',
    'ajs'             => 'sgn_ajs',
    'ami'             => 'i_ami',
    'apc'             => 'ar_apc',
    'apd'             => 'ar_apd',
    'arb'             => 'ar_arb',
    'arq'             => 'ar_arq',
    'ars'             => 'ar_ars',
    'ary'             => 'ar_ary',
    'arz'             => 'ar_arz',
    'ase'             => 'sgn_ase',
    'asf'             => 'sgn_asf',
    'asp'             => 'sgn_asp',
    'asq'             => 'sgn_asq',
    'asw'             => 'sgn_asw',
    'auz'             => 'ar_auz',
    'avl'             => 'ar_avl',
    'ayh'             => 'ar_ayh',
    'ayl'             => 'ar_ayl',
    'ayn'             => 'ar_ayn',
    'ayp'             => 'ar_ayp',
    'bbz'             => 'ar_bbz',
    'bfi'             => 'sgn_bfi',
    'bfk'             => 'sgn_bfk',
    'bjn'             => 'ms_bjn',
    'bnn'             => 'i_bnn',
    'bog'             => 'sgn_bog',
    'bqn'             => 'sgn_bqn',
    'bqy'             => 'sgn_bqy',
    'btj'             => 'ms_btj',
    'bve'             => 'ms_bve',
    'bvl'             => 'sgn_bvl',
    'bvu'             => 'ms_bvu',
    'bzs'             => 'sgn_br',
    'cdo'             => 'zh_cdo',
    'cds'             => 'sgn_cds',
    'cjy'             => 'zh_cjy',
    'cmn'             => 'zh_cmn',
    'cmn_hans'        => 'zh_cmn_hans',
    'cmn_hant'        => 'zh_cmn_hant',
    'cnp'             => 'zh_cnp',
    'coa'             => 'ms_coa',
    'cpx'             => 'zh_cpx',
    'csc'             => 'sgn_csc',
    'csd'             => 'sgn_csd',
    'cse'             => 'sgn_cse',
    'csf'             => 'sgn_csf',
    'csg'             => 'sgn_csg',
    'csl'             => 'sgn_csl',
    'csn'             => 'sgn_co',
    'csp'             => 'zh_csp',
    'csq'             => 'sgn_csq',
    'csr'             => 'sgn_csr',
    'csx'             => 'sgn_csx',
    'czh'             => 'zh_czh',
    'czo'             => 'zh_czo',
    'doq'             => 'sgn_doq',
    'dse'             => 'sgn_dse',
    'dsl'             => 'sgn_dk',
    'dsz'             => 'sgn_dsz',
    'dup'             => 'ms_dup',
    'ecs'             => 'sgn_ecs',
    'ehs'             => 'sgn_ehs',
    'en_gb_oxendict'  => 'en_gb_oed',
    'esl'             => 'sgn_esl',
    'esn'             => 'sgn_esn',
    'eso'             => 'sgn_eso',
    'eth'             => 'sgn_eth',
    'fcs'             => 'sgn_fcs',
    'fse'             => 'sgn_fse',
    'fsl'             => 'sgn_fr',
    'fss'             => 'sgn_fss',
    'gan'             => 'zh_gan',
    'gds'             => 'sgn_gds',
    'gom'             => 'kok_gom',
    'gse'             => 'sgn_gse',
    'gsg'             => 'sgn_de',
    'gsm'             => 'sgn_gsm',
    'gss'             => 'sgn_gr',
    'gus'             => 'sgn_gus',
    'hab'             => 'sgn_hab',
    'haf'             => 'sgn_haf',
    'hak'             => 'i_hak',
    'hds'             => 'sgn_hds',
    'hji'             => 'ms_hji',
    'hks'             => 'sgn_hks',
    'hos'             => 'sgn_hos',
    'hps'             => 'sgn_hps',
    'hsh'             => 'sgn_hsh',
    'hsl'             => 'sgn_hsl',
    'hsn'             => 'zh_hsn',
    'icl'             => 'sgn_icl',
    'iks'             => 'sgn_iks',
    'ils'             => 'sgn_ils',
    'inl'             => 'sgn_inl',
    'ins'             => 'sgn_ins',
    'ise'             => 'sgn_ise',
    'isg'             => 'sgn_ie',
    'isr'             => 'sgn_isr',
    'ja_latn_alalc97' => 'ja_latn_hepburn_heploc',
    'jak'             => 'ms_jak',
    'jax'             => 'ms_jax',
    'jbo'             => 'art_lojban',
    'jcs'             => 'sgn_jcs',
    'jhs'             => 'sgn_jhs',
    'jks'             => 'sgn_jks',
    'jls'             => 'sgn_jls',
    'jos'             => 'sgn_jos',
    'jsl'             => 'sgn_jp',
    'jus'             => 'sgn_jus',
    'kgi'             => 'sgn_kgi',
    'knn'             => 'kok_knn',
    'kvb'             => 'ms_kvb',
    'kvk'             => 'sgn_kvk',
    'kvr'             => 'ms_kvr',
    'kxd'             => 'ms_kxd',
    'lb'              => 'i_lux',
    'lbs'             => 'sgn_lbs',
    'lce'             => 'ms_lce',
    'lcf'             => 'ms_lcf',
    'lgs'             => 'sgn_lgs',
    'liw'             => 'ms_liw',
    'lls'             => 'sgn_lls',
    'lsb'             => 'sgn_lsb',
    'lsc'             => 'sgn_lsc',
    'lsg'             => 'sgn_lsg',
    'lsl'             => 'sgn_lsl',
    'lsn'             => 'sgn_lsn',
    'lso'             => 'sgn_lso',
    'lsp'             => 'sgn_lsp',
    'lst'             => 'sgn_lst',
    'lsv'             => 'sgn_lsv',
    'lsw'             => 'sgn_lsw',
    'lsy'             => 'sgn_lsy',
    'ltg'             => 'lv_ltg',
    'lvs'             => 'lv_lvs',
    'lws'             => 'sgn_lws',
    'lzh'             => 'zh_lzh',
    'max'             => 'ms_max',
    'mdl'             => 'sgn_mdl',
    'meo'             => 'ms_meo',
    'mfa'             => 'ms_mfa',
    'mfb'             => 'ms_mfb',
    'mfs'             => 'sgn_mfs',
    'min'             => 'ms_min',
    'mnp'             => 'zh_mnp',
    'mqg'             => 'ms_mqg',
    'mre'             => 'sgn_mre',
    'msd'             => 'sgn_msd',
    'msi'             => 'ms_msi',
    'msr'             => 'sgn_msr',
    'mui'             => 'ms_mui',
    'mzc'             => 'sgn_mzc',
    'mzg'             => 'sgn_mzg',
    'mzy'             => 'sgn_mzy',
    'nan'             => 'zh_min_nan',
    'nb'              => 'no_bok',
    'nbs'             => 'sgn_nbs',
    'ncs'             => 'sgn_ncs',
    'nn'              => 'no_nyn',
    'nsi'             => 'sgn_nsi',
    'nsl'             => 'sgn_no',
    'nsp'             => 'sgn_nsp',
    'nsr'             => 'sgn_nsr',
    'nv'              => 'i_navajo',
    'nzs'             => 'sgn_nzs',
    'okl'             => 'sgn_okl',
    'orn'             => 'ms_orn',
    'ors'             => 'ms_ors',
    'pel'             => 'ms_pel',
    'pga'             => 'ar_pga',
    'pgz'             => 'sgn_pgz',
    'pks'             => 'sgn_pks',
    'prl'             => 'sgn_prl',
    'prz'             => 'sgn_prz',
    'psc'             => 'sgn_psc',
    'psd'             => 'sgn_psd',
    'pse'             => 'ms_pse',
    'psg'             => 'sgn_psg',
    'psl'             => 'sgn_psl',
    'pso'             => 'sgn_pso',
    'psp'             => 'sgn_psp',
    'psr'             => 'sgn_psr',
    'pwn'             => 'i_pwn',
    'pys'             => 'sgn_pys',
    'rib'             => 'sgn_rib',
    'rms'             => 'sgn_rms',
    'rnb'             => 'sgn_rnb',
    'rsi'             => 'sgn_rsi',
    'rsl'             => 'sgn_rsl',
    'rsm'             => 'sgn_rsm',
    'rsn'             => 'sgn_rsn',
    'sdl'             => 'sgn_sdl',
    'sfb'             => 'sgn_be_fr',
    'sfs'             => 'sgn_sfs',
    'sgg'             => 'sgn_ch_de',
    'sgx'             => 'sgn_sgx',
    'shu'             => 'ar_shu',
    'slf'             => 'sgn_slf',
    'sls'             => 'sgn_sls',
    'sqk'             => 'sgn_sqk',
    'sqs'             => 'sgn_sqs',
    'sqx'             => 'sgn_sqx',
    'ssh'             => 'ar_ssh',
    'ssp'             => 'sgn_es',
    'ssr'             => 'sgn_ssr',
    'svk'             => 'sgn_svk',
    'swc'             => 'sw_swc',
    'swh'             => 'sw_swh',
    'swl'             => 'sgn_se',
    'syy'             => 'sgn_syy',
    'szs'             => 'sgn_szs',
    'tao'             => 'i_tao',
    'tay'             => 'i_tay',
    'tlh'             => 'i_klingon',
    'tmw'             => 'ms_tmw',
    'tse'             => 'sgn_tse',
    'tsm'             => 'sgn_tsm',
    'tsq'             => 'sgn_tsq',
    'tss'             => 'sgn_tss',
    'tsu'             => 'i_tsu',
    'tsy'             => 'sgn_tsy',
    'tza'             => 'sgn_tza',
    'ugn'             => 'sgn_ugn',
    'ugy'             => 'sgn_ugy',
    'ukl'             => 'sgn_ukl',
    'uks'             => 'sgn_uks',
    'urk'             => 'ms_urk',
    'uzn'             => 'uz_uzn',
    'uzs'             => 'uz_uzs',
    'vgt'             => 'sgn_be_nl',
    'vkk'             => 'ms_vkk',
    'vkt'             => 'ms_vkt',
    'vsi'             => 'sgn_vsi',
    'vsl'             => 'sgn_vsl',
    'vsv'             => 'sgn_vsv',
    'wbs'             => 'sgn_wbs',
    'wuu'             => 'zh_wuu',
    'xki'             => 'sgn_xki',
    'xml'             => 'sgn_xml',
    'xmm'             => 'ms_xmm',
    'xms'             => 'sgn_xms',
    'yds'             => 'sgn_yds',
    'ygs'             => 'sgn_ygs',
    'yhs'             => 'sgn_yhs',
    'ysl'             => 'sgn_ysl',
    'ysm'             => 'sgn_ysm',
    'yue'             => 'zh_yue',
    'zib'             => 'sgn_zib',
    'zlm'             => 'ms_zlm',
    'zmi'             => 'ms_zmi',
    'zsl'             => 'sgn_zsl',
    'zsm'             => 'ms_zsm',
);

sub new ( $class, %settings ) {
    if (   !blessed( $settings{'cache'} )
        || !$settings{'cache'}->isa('Locale::MaybeMaketext::Cache') ) {
        croak('Invalid cache');
    }
    return bless { 'cache' => $settings{'cache'}->get_namespaced('Alternatives') }, $class;
}

sub _get_cache ( $self, $cache_key ) {
    return wantarray ? $self->{'cache'}->get_cache($cache_key) : $self->{'cache'}->get_cache($cache_key);
}

sub _set_cache ( $self, $cache_key, @data ) {
    return $self->{'cache'}->set_cache( $cache_key, @data );
}

sub _join_parts ( $self, %myparts ) {
    my @wanted_fields;
    for (@field_parts) {
        if ( defined( $myparts{$_} ) ) { push @wanted_fields, $myparts{$_}; }
    }
    return join( '_', @wanted_fields );
}

sub _copy_but_change ( $self, $item, $new, %parts ) {
    my %output;
    for (@field_parts) {
        if ( defined( $parts{$_} ) ) {
            if ( $_ eq $item ) {
                $output{$_} = $new;
            }
            else {
                $output{$_} = $parts{$_};
            }
        }
    }
    return \%output;
}

sub find_alternatives ( $self, %parts ) {
    my ( @output_array, %output_strings );
    my $original_as_string = $self->_join_parts(%parts);
    if ( $self->_get_cache( 'find_alternatives' . $original_as_string ) ) {
        my @cache = $self->_get_cache( 'find_alternatives' . $original_as_string );
        return @cache;
    }

    # see what needs changing
    if ( defined( $parts{'language'} ) ) {
        if ( $languages{ $parts{'language'} } ) {
            push @output_array, $self->_copy_but_change( 'language', $languages{ $parts{'language'} }, %parts );
        }
        if ( defined( $parts{'region'} ) && $regions{ $parts{'region'} } ) {

            # add original
            push @output_array, $self->_copy_but_change( 'region', $regions{ $parts{'region'} }, %parts );

            # change any already stored.
            # use a temporary array as we are going to be looping over the original.
            my @new_regions;
            for my $cur (@output_array) {
                push @new_regions, $self->_copy_but_change( 'region', $regions{ $parts{'region'} }, %{$cur} );

            }
            @output_array = ( @output_array, @new_regions );
        }
    }

    # make all into strings
    my $joined;
    $output_strings{$original_as_string} = 1;
    for (@output_array) {
        $joined = $self->_join_parts( %{$_} );
        if ( !$output_strings{$joined} ) { $output_strings{$joined} = 1; }
    }
    my @keys = keys(%output_strings);

    # check for full length replacements for all strings
  LANGLOOP: for my $current_language (@keys) {
        for my $entry ( keys(%fulls) ) {
            my $entry_length = length($entry);

            # are we a full match?
            if ( $current_language eq $entry ) {
                if ( !$output_strings{ $fulls{$entry} } ) {
                    $output_strings{ $fulls{$entry} } = 1;
                }
                next LANGLOOP;
            }

            elsif ( substr( $current_language, 0, $entry_length + 1 ) eq $entry . '_' ) {

                # or just up to a marker?
                my $out     = $fulls{$entry};
                my $changed = $out . substr( $current_language, $entry_length );
                if ( !$output_strings{$changed} ) { $output_strings{$changed} = 1; }
                next LANGLOOP;
            }
        }
    }    # end LANGLOOP
    @keys = keys(%output_strings);
    $self->_set_cache( 'find_alternatives' . $original_as_string, @keys );
    return @keys;
}

1;
