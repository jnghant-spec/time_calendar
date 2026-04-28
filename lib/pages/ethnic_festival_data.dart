// 民族节日：56 个民族 + 各民族的硬编码节日种子（后续可换 API）
// 与 [FestivalSettingsPage] 解耦，仅作为数据表。

/// ( id, 名称, 是否默认选中 )
const kEthnicGroupRows = <(String, String, bool)>[
  ('zang', '藏族', true),
  ('dai', '傣族', true),
  ('miao', '苗族', true),
  ('yi', '彝族', true),
  ('menggu', '蒙古族', true),
  ('bai', '白族', true),
  ('zhuang', '壮族', true),
  ('chaoxian', '朝鲜族', true),
  ('hani', '哈尼族', true),
  ('naxi', '纳西族', true),
  ('weiwu', '维吾尔族', false),
  ('tujia', '土家族', false),
  ('buyi', '布依族', false),
  ('yao', '瑶族', false),
  ('dong', '侗族', false),
  ('hui', '回族', false),
  ('man', '满族', false),
  ('li', '黎族', false),
  ('lisu', '傈僳族', false),
  ('she', '畲族', false),
  ('gaoshan', '高山族', false),
  ('lahu', '拉祜族', false),
  ('shui', '水族', false),
  ('dongx', '东乡族', false),
  ('jingp', '景颇族', false),
  ('keq', '柯尔克孜族', false),
  ('daw', '达斡尔族', false),
  ('mul', '仫佬族', false),
  ('qiang', '羌族', false),
  ('blang', '布朗族', false),
  ('sala', '撒拉族', false),
  ('mnan', '毛南族', false),
  ('gela', '仡佬族', false),
  ('xibo', '锡伯族', false),
  ('ach', '阿昌族', false),
  ('pumi', '普米族', false),
  ('taj', '塔吉克族', false),
  ('nu', '怒族', false),
  ('uzb', '乌孜别克族', false),
  ('elu', '俄罗斯族', false),
  ('ewk', '鄂温克族', false),
  ('dea', '德昂族', false),
  ('bao', '保安族', false),
  ('yug', '裕固族', false),
  ('jingr', '京族', false),
  ('tata', '塔塔尔族', false),
  ('dulo', '独龙族', false),
  ('elc', '鄂伦春族', false),
  ('hez', '赫哲族', false),
  ('menb', '门巴族', false),
  ('luob', '珞巴族', false),
  ('jino', '基诺族', false),
  ('tuzu', '土族', false),
  ('wa', '佤族', false),
  ('kaz', '哈萨克族', false),
  ('han', '汉族', false),
];

/// ( 节日名, 民族历标签全文, 公历, 默认订阅 )
const kEthnicFestivalsByGroup = <String, List<(String, String, String, bool)>>{
  'zang': [
    ('藏历新年', '藏历 木羊年一月初一', '2027年2月19日', true),
    ('雪顿节', '藏历 六月三十', '2027年8月', false),
    ('萨噶达瓦节', '藏历 四月十五', '2027年6月', false),
    ('望果节', '藏历 七至八月间', '2027年8月', false),
  ],
  'dai': [
    ('泼水节', '傣历 六月', '2027年4月13日', true),
    ('关门节', '傣历 九月十五', '2027年7月', false),
    ('开门节', '傣历 十二月十五', '2027年10月', false),
  ],
  'miao': [
    ('苗年', '苗历 十月', '2027年11月', true),
    ('姊妹节', '苗历 三月十五', '2027年3月', true),
  ],
  'yi': [
    ('火把节', '彝历 六月二十四', '2027年7月', true),
    ('彝族年', '彝历 十月', '2027年11月', false),
  ],
  'menggu': [
    ('那达慕', '蒙历 七至八月', '2027年7月', true),
    ('白月节', '蒙历 正月', '2027年2月', false),
  ],
  'bai': [
    ('三月街', '农历 三月十五', '2027年4月', true),
  ],
  'zhuang': [
    ('三月三', '农历 三月初三', '2027年4月', true),
  ],
  'chaoxian': [
    ('回甲节', '', '因人而异', false),
  ],
  'hani': [
    ('嘎汤帕节', '哈尼历 十月', '2027年1月', true),
  ],
  'naxi': [
    ('三朵节', '农历 二月初八', '2027年3月', true),
  ],
};
