#!/usr/bin/env python3
# Generates assets/data/ethnic_festivals.json and religious_festivals.json (years always {}).

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def ef(
    eid,
    ename,
    sid,
    name,
    ct,
    cd,
    desc,
    customs,
    foods,
    hi,
    major,
    tags,
    ds,
    conf="high",
    note="",
    default_sub=False,
):
    return {
        "id": f"{eid}_{sid}",
        "name": name,
        "ethnic_id": eid,
        "ethnic_name": ename,
        "calendar_type": ct,
        "calendar_date": cd,
        "description": desc,
        "customs": customs,
        "foods": foods,
        "holiday_info": hi,
        "years": {},
        "is_major": major,
        "tags": tags,
        "date_strategy": ds,
        "confidence": conf,
        "note": note,
        "default_subscribed": default_sub,
    }


_DEFAULT_SUB = {
    "zang_losar",
    "dai_water_splashing",
    "miao_new_year",
    "miao_sisters",
    "yi_huoba",
    "menggu_white_month",
    "bai_march_street",
    "zhuang_sanyuesan",
    "hani_zhalet",
    "naxi_sanduo",
}


def wrap(desc):
    """Ensure ~100+ chars; caller passes full text."""
    return desc


def build_ethnic():
    out = []

    def add(eid, ename, rows):
        nonlocal out
        for r in rows:
            oid = f"{eid}_{r['sid']}"
            out.append(
                ef(
                    eid,
                    ename,
                    r["sid"],
                    r["name"],
                    r["ct"],
                    r["cd"],
                    wrap(r["desc"]),
                    r["cu"],
                    r["fd"],
                    r["hi"],
                    r["mj"],
                    r["tg"],
                    r["ds"],
                    r.get("cf", "high"),
                    r.get("nt", ""),
                    default_sub=(oid in _DEFAULT_SUB),
                )
            )

    # --- A 档 ---
    add(
        "zang",
        "藏族",
        [
            dict(sid="losar", name="藏历新年", ct="tibetan", cd="1-1", desc="藏族最隆重的年节，家家洒扫庭除、摆放切玛与青稞苗，除夕夜吃古突面疙瘩谈心祈福，初一抢新水、煨桑诵经；街巷寺院香火鼎盛，歌舞鍋庄彻夜不息，凝聚高原农牧社会对新春、人畜平安与人伦和睦的深切祈愿。", cu=["煨桑", "跳锅庄", "抢新水"], fd=["古突", "青稞酒"], hi="依规放假调休", mj=True, tg=["新年", "藏历"], ds="algorithm"),
            dict(sid="saga_dawa", name="萨噶达瓦节", ct="tibetan", cd="4-15", desc="藏传佛教纪念释迦牟尼诞生、成道与涅槃的殊胜日子，信众沿千佛崖与八廓街转经叩拜，寺院举行法会并素食放生；拉萨等地朝圣人潮如潮，被视为积德修善的紧要福田，体现信仰与高原日常生活的紧密结合。", cu=["转经", "放生", "布施"], fd=[], hi="", mj=True, tg=["佛教", "藏历"], ds="algorithm"),
            dict(sid="shoton", name="雪顿节", ct="tibetan", cd="6-30", desc="雪顿意为酸奶宴，历史上犒劳僧人下山并晒大佛；如今哲蚌寺巨幅唐卡铺展于半山，罗布林卡藏戏连台，各族民众逛林卡野餐，僧俗共庆夏末秋收在即，展现宗教仪轨与民间文娱相融的节日气象。", cu=["展佛", "藏戏", "过林卡"], fd=["酸奶"], hi="多地放假活动", mj=True, tg=["藏历"], ds="algorithm"),
            dict(sid="burning_lamp", name="燃灯节", ct="tibetan", cd="10-25", desc="为纪念格鲁派祖师宗喀巴圆寂，寺院与民居窗台屋顶点亮万千酥油灯彻夜不灭，象征智慧光明驱除无明；僧侣诵经供灯，信众绕行拜佛，冬夜里灯火连绵如星河，肃穆温馨并存。", cu=["供灯", "诵经"], fd=[], hi="", mj=False, tg=["藏传佛教"], ds="algorithm"),
            dict(sid="wongkor", name="望果节", ct="tibetan", cd="7-1", desc="农区巡游祈愿秋收的节日，村民举着幡旗绕田祝福禾穗饱满，赛马歌舞与敬酒欢聚相接；仪式兼具酬谢土地与凝聚村寨互助的传统功能，各地田间日程略有先后。", cu=["绕田", "赛马"], fd=["青稞酒"], hi="", mj=False, tg=["丰收"], ds="algorithm", cf="medium", nt="田间活动时间依各村安排而异。"),
        ],
    )
    add(
        "menggu",
        "蒙古族",
        [
            dict(sid="white_month", name="白节", ct="lunar", cd="1-1", desc="蒙古族新年庆贺，家家清扫毡房、敬献奶食与手把肉，晚辈向长辈屈膝敬酒拜年；祝酒歌与摔跤赛马交织，篝火通宵象征人畜两旺，禁忌恶语摔碗体现游牧社会对和睦繁衍的重视。", cu=["拜年", "祭火"], fd=["奶食", "手把肉"], hi="牧区集会休假", mj=True, tg=["新年"], ds="lunar_convert"),
            dict(sid="nadam", name="那达慕大会", ct="lunar", cd="7-1", desc="以摔跤、赛马、射箭三项竞技为核心，历史上源于出征检阅与部落联盟议事；如今夏秋草场搭起彩色毡帐，商贩集市与歌舞晚宴同台，胜者被授予骏马哈达，彰显草原勇毅尚武与集体荣誉。", cu=["摔跤", "赛马", "射箭"], fd=["奶制品"], hi="盛会期间轮休", mj=True, tg=["竞技"], ds="lunar_convert", cf="medium", nt="开幕日期各地浮动，属集会型节庆。"),
            dict(sid="mare_milk", name="马奶节", ct="unknown", cd="7-15", desc="夏秋牲畜膘肥时节牧民汇聚品尝发酵马奶，敬酒祈福牲畜无病；伴随短时赛马或长调民歌，规模因地而异，体现游牧生计与自然节律相契合的庆贺方式。", cu=["尝马奶"], fd=["马奶酒"], hi="", mj=False, tg=["游牧"], ds="unknown", cf="low", nt="命名与时间牧区间差异大。"),
            dict(sid="lamp_memorial", name="燃灯节", ct="tibetan", cd="10-25", desc="受藏传佛教影响，寺院与牧户点亮酥油灯纪念宗师圆寂；牧民彻夜诵经祈福走亲访友，冬季草原上灯火点点如同星河，与藏族燃灯节同源而在礼仪细节上带有草原聚落色彩。", cu=["点灯"], fd=[], hi="", mj=False, tg=["藏传佛教"], ds="algorithm"),
        ],
    )
    add(
        "weiwu",
        "维吾尔族",
        [
            dict(sid="gurban", name="古尔邦节", ct="islamic", cd="12-10", desc="穆斯林宰牲献祭纪念易卜拉欣顺从典范，聚礼后分肉济贫并走亲访友；南疆街巷飘散烤肉抓饭香气，长者为孩子讲述施舍故事，强调信仰仁爱与社会互助。", cu=["聚礼", "宰牲"], fd=["抓饭", "烤肉"], hi="依法放假", mj=True, tg=["伊斯兰教"], ds="algorithm"),
            dict(sid="rozah", name="肉孜节", ct="islamic", cd="10-1", desc="斋月圆满的开斋庆典，清晨沐浴盛装赴清真寺礼拜，施舍糕点糖果给孩子；家宴款待来客互致问候，象征忍耐之后的宽恕与团圆，街巷洋溢着喜庆祥和。", cu=["礼拜", "施舍"], fd=["馓子"], hi="依法放假", mj=True, tg=["开斋"], ds="algorithm"),
            dict(sid="nowruz", name="诺鲁孜节", ct="gregorian", cd="3-21", desc="春分前后庆贺新旧更替，家家户户熬制诺鲁孜饭撒麦粒祈福；广场萨玛舞与叼羊赛马热闹非凡，象征绿洲农耕对春雨与时序的礼赞，亦折射丝路文化交流。", cu=["诺鲁孜饭", "歌舞"], fd=["杂粮粥"], hi="", mj=True, tg=["迎春"], ds="fixed"),
        ],
    )
    add(
        "hui",
        "回族",
        [
            dict(sid="gurban", name="古尔邦节", ct="islamic", cd="12-10", desc="回族坊巷同日宰牲聚礼，阿訇讲经阐明仁爱施舍要义；家族分食牛羊肉探望孤寡，油香馓子馈赠邻里，礼仪兼具伊斯兰教戒律与中原人情社会的待客之道。", cu=["聚礼", "宰牲"], fd=["油香"], hi="依法放假", mj=True, tg=["伊斯兰教"], ds="algorithm"),
            dict(sid="eid_fitr", name="开斋节", ct="islamic", cd="10-1", desc="斋戒结束清晨盛大礼拜，孩童盛装领取施舍糖果；家家户户炸油香熬八宝粥，走亲访友互道吉祥，强调宽恕和解与社群凝聚力。", cu=["礼拜", "走亲"], fd=["油香"], hi="依法放假", mj=True, tg=["伊斯兰教"], ds="algorithm"),
            dict(sid="mawlid", name="圣纪节", ct="islamic", cd="3-12", desc="纪念先知诞辰，清真寺诵读圣训讲述圣人生平品德；信众熬粥施舍路人，部分地区悬挂灯饰，凸显慈善教育与社群记忆的传承。", cu=["诵经", "施舍"], fd=[], hi="", mj=False, tg=["伊斯兰教"], ds="algorithm", cf="medium", nt="各地历日与礼仪略有流派差异。"),
        ],
    )
    add(
        "yi",
        "彝族",
        [
            dict(sid="huoba", name="火把节", ct="yi", cd="6-24", desc="彝语称火把驱邪护稼，夜幕下山寨火把连成火龙，斗牛赛马与朵洛荷民歌彻夜不息；姑娘盛装抢银饰，长者念诵祭祖词，象征山地社会对丰收、尊严与族群凝聚的共同祈愿。", cu=["点火把", "斗牛"], fd=["坨坨肉"], hi="多地放假旅游旺季", mj=True, tg=["火把节"], ds="algorithm"),
            dict(sid="year_yi", name="彝族年", ct="yi", cd="10-1", desc="彝历十月为岁首，杀猪祭祖宴请亲友，长者口述谱牒传禁忌；青年左脚舞对歌择偶，村寨轮流坐庄叙事饮酒，体现山地计时体系与家族伦理秩序。", cu=["祭祖", "杀猪宴"], fd=["荞粑"], hi="", mj=True, tg=["彝历年"], ds="algorithm", cf="medium", nt="方言区岁首时段仍有差异。"),
            dict(sid="tiger_leap", name="跳虎节", ct="yi", cd="2-8", desc="滇南彝寨遗存虎图腾祭祀，彩绘面具舞者模仿猛虎撵邪护寨；仪式包含撵邪词与模拟狩猎，戏剧张力强烈但流传范围有限，折射山地狩猎文化与巫祭传统的叠合。", cu=["面具舞"], fd=[], hi="", mj=False, tg=["祭祀"], ds="unknown", cf="low", nt="仅存局部县域口述资料。"),
            dict(sid="flower_day", name="插花节", ct="yi", cd="3-8", desc="春暖花开男女头戴山花互赠示好，老人在花树下讲述始祖传说；宴席歌舞直至篝火熄灭，象征生命力与婚恋吉祥，承载山地花卉崇拜与社群联欢。", cu=["采花", "对歌"], fd=[], hi="", mj=False, tg=["迎春"], ds="unknown", cf="medium"),
        ],
    )
    add(
        "dai",
        "傣族",
        [
            dict(sid="water_splashing", name="泼水节", ct="dai", cd="6-1", desc="傣历新年盛事，清晨浴佛后以清水互泼祝福，龙舟竞渡与象脚鼓舞倾城；高升焰火祈求雨顺风调，南传佛教仪式与傣寨社群凝聚力相得益彰。", cu=["泼水", "龙舟"], fd=["泼水粑粑"], hi="法定假日区域休假", mj=True, tg=["傣历"], ds="lookup"),
            dict(sid="closing_door", name="关门节", ct="dai", cd="9-15", desc="安居开始前信众集中赕佛听经，暂缓婚庆大兴土木；僧侣严守寺内戒律，农家以糯米饭布施表达对雨季安居制度的敬重。", cu=["赕佛"], fd=[], hi="", mj=False, tg=["安居"], ds="lookup"),
            dict(sid="opening_door", name="开门节", ct="dai", cd="12-15", desc="安居期满村寨敲响象脚鼓解禁歌舞，佛塔点灯泼水嬉戏重演喜气；僧侣获准远行宣教，标志傣寨社会生活重回欢愉节律。", cu=["歌舞"], fd=[], hi="", mj=False, tg=["傣历"], ds="lookup"),
        ],
    )
    add(
        "miao",
        "苗族",
        [
            dict(sid="new_year", name="苗年", ct="lunar", cd="10-1", desc="秋收后岁首杀猪祭祖吹芦笙踩堂，牛角酒糯米饭待客；斗牛赛马选拔勇者，青年盛装走亲择偶，重申血缘村寨同盟与自然神灵庇护。", cu=["祭祖", "芦笙舞"], fd=["糯米酒"], hi="", mj=True, tg=["苗年"], ds="lunar_convert", cf="medium", nt="各地月份略有参差。"),
            dict(sid="sisters", name="姊妹节", ct="lunar", cd="3-15", desc="黔东南姑娘蒸煮五彩姊妹饭赠心仪后生，江边龙舟对歌择偶；母亲传授刺绣歌谣，节日兼具婚恋媒介与女性非遗展演窗口。", cu=["对歌"], fd=["姊妹饭"], hi="", mj=True, tg=["婚恋"], ds="lunar_convert"),
            dict(sid="april8", name="四月八", ct="lunar", cd="4-8", desc="纪念英雄或祭牛王庙会，糯米饭喂耕牛休犁一日；斗牛比武吹笙跳舞，部分地区穿插爬坡习俗，体现山地农耕尚武传统。", cu=["祭牛"], fd=["糯米饭"], hi="", mj=False, tg=["农耕"], ds="lunar_convert"),
            dict(sid="lusheng_hui", name="芦笙节", ct="lunar", cd="9-1", desc="百堂笙队竞技曲调舞步，胜者被视为村寨荣耀；姑娘百褶盛装围观抛绣球，跨省苗族联谊与非遗展演同场进行。", cu=["芦笙赛"], fd=[], hi="", mj=False, tg=["非遗"], ds="lunar_convert", cf="medium"),
        ],
    )
    add(
        "zhuang",
        "壮族",
        [
            dict(sid="sanyuesan", name="三月三歌圩", ct="lunar", cd="3-3", desc="传统歌圩倚歌择偶，长者传唱布洛陀史诗；五色糯米饭碰彩蛋象征繁衍，抢花炮与竹竿舞同样热烈，列入国家级非遗名录。", cu=["对歌", "抛绣球"], fd=["五色糯米饭"], hi="自治区放假", mj=True, tg=["歌圩"], ds="lunar_convert"),
            dict(sid="tuoluo", name="陀螺节", ct="lunar", cd="2-1", desc="桂西北孩童旋木陀螺比拼耐力技巧，胜者获彩绘陀螺；山歌擂台与百家宴并行，既是农耕间歇娱乐亦锻炼协作。", cu=["打陀螺"], fd=[], hi="", mj=False, tg=["民俗"], ds="lunar_convert", cf="medium"),
            dict(sid="tonggu", name="铜鼓节", ct="lunar", cd="7-1", desc="敲响祖传铜鼓召集祭祖议事，舞蹈模仿耕作狩猎；米酒宴客强化骆越后裔文化认同，广西多地轮流主办联谊。", cu=["敲铜鼓"], fd=["米酒"], hi="", mj=False, tg=["铜鼓"], ds="lunar_convert", cf="medium"),
        ],
    )
    add(
        "man",
        "满族",
        [
            dict(sid="banjin", name="颁金节", ct="lunar", cd="10-13", desc="纪念皇太极定族名满洲，同胞着旗袍马褂祭祖诵读家谱；歌舞滑冰与传统体育同台，强调历史认同与民族团结叙事。", cu=["祭祖"], fd=["萨其马"], hi="", mj=True, tg=["满族"], ds="lunar_convert"),
            dict(sid="chongwang", name="虫王节", ct="lunar", cd="6-6", desc="祈愿驱除蝗灾保护庄稼，蒸饽饽祭虫王庙暂缓喷洒；萨满说唱讲述驱虫神话，反映东北亚农耕对自然灾害的经验回应。", cu=["祭虫王"], fd=["饽饽"], hi="", mj=False, tg=["农耕"], ds="lunar_convert"),
            dict(sid="shangyuan", name="上元节", ct="lunar", cd="1-15", desc="满族灯会融入冰灯与火锅宴，姑娘踩高跷走百病；与汉族元宵同源而在食材娱乐上保留旗俗讲究。", cu=["灯会"], fd=[], hi="", mj=False, tg=["元宵"], ds="lunar_convert", cf="medium", nt="与汉族元宵节深度融合。"),
        ],
    )
    add(
        "chaoxian",
        "朝鲜族",
        [
            dict(sid="wonwoo", name="上元节", ct="lunar", cd="1-15", desc="正月十五吃五谷饭坚果防寒，踏桥踹福祈愿康健；农乐队巡演讲述农耕寓言，灯笼教育孩子敬老尚俭。", cu=["踏桥"], fd=["五谷饭"], hi="", mj=True, tg=["元宵"], ds="lunar_convert"),
            dict(sid="hanshi", name="寒食节", ct="lunar", cd="4-3", desc="艾草年糕祭祖扫墓，家族踏青放风筝；强调孝道顺序与生死观念，粳米粉团礼仪在城市朝鲜族社区延续。", cu=["扫墓"], fd=["艾草糕"], hi="", mj=False, tg=["祭祖"], ds="lunar_convert", cf="medium"),
            dict(sid="autumn_eve", name="秋夕节", ct="lunar", cd="8-15", desc="秋收祭祖打松饼馈赠邻里，摔跤跳板赛烘托团圆；全家返乡打磨秋千，象征感恩收成与家族纽带。", cu=["祭祖", "跳板"], fd=["松饼"], hi="区域休假", mj=True, tg=["中秋"], ds="lunar_convert"),
            dict(sid="huijia", name="回甲节", ct="unknown", cd="", desc="朝鲜族为长者庆贺六十花甲，子孙献寿宴歌舞跪拜感恩辛劳；红色礼服寿桃面食强调孝道伦理在跨国迁徙社区的延续。", cu=["寿宴"], fd=["寿面"], hi="", mj=False, tg=["寿庆"], ds="unknown", cf="low", nt="具体日以寿星生辰确定。"),
        ],
    )

    # --- B 档 ---
    add(
        "dong",
        "侗族",
        [
            dict(sid="new_year", name="侗年", ct="lunar", cd="10-1", desc="侗寨秋收后过年杀猪祭祖，鼓楼篝火琵琶歌彻夜；百家腌鱼侗酒待客，强化款的同盟与山林资源共享。", cu=["祭祖", "琵琶歌"], fd=["腌鱼"], hi="", mj=True, tg=["侗年"], ds="lunar_convert", cf="medium"),
            dict(sid="huapao", name="花炮节", ct="lunar", cd="3-3", desc="抢花炮象征村寨吉祥，勇敢青年冲入人群夺取铁环；芦笙踩堂与斗牛同时进行，体现侗族竞技精神与社群荣耀。", cu=["抢花炮"], fd=[], hi="", mj=False, tg=["竞技"], ds="lunar_convert"),
            dict(sid="sama", name="萨玛节", ct="lunar", cd="2-2", desc="祭祀侗族祖母神萨玛，黑伞队列静默巡游村寨祈求人畜平安；古老歌谣口述族群迁徙记忆，女性祭司主持礼仪。", cu=["祭祀"], fd=[], hi="", mj=False, tg=["信仰"], ds="lunar_convert", cf="medium"),
        ],
    )
    add(
        "yao",
        "瑶族",
        [
            dict(sid="panwang", name="盘王节", ct="lunar", cd="10-16", desc="纪念盘瓠先祖的长鼓舞盛会，师公吟诵经幡祭祖；赛陀螺舂糍粑长桌宴，跨省过山瑶同台重温迁徙史诗。", cu=["长鼓舞"], fd=["糍粑"], hi="", mj=True, tg=["祖先"], ds="lunar_convert", cf="medium"),
            dict(sid="danu", name="达努节", ct="lunar", cd="5-29", desc="布努瑶纪念创世女神密洛陀，射弩赛马酿酒比武；铜鼓舞与传说吟诵并举，强调山地耕作与女性创造力的尊崇。", cu=["铜鼓舞"], fd=["药酒"], hi="", mj=False, tg=["密洛陀"], ds="lunar_convert", cf="medium"),
            dict(sid="shewang", name="社王节", ct="lunar", cd="2-2", desc="春社祭土地祈愿庄稼无病，糯米饭与鸡血酒供奉社王；随后开山耕作禁忌解除，体现山林农耕与自然神灵契约。", cu=["祭社"], fd=[], hi="", mj=False, tg=["农耕"], ds="lunar_convert"),
        ],
    )
    add(
        "bai",
        "白族",
        [
            dict(sid="march_street", name="三月街", ct="lunar", cd="3-15", desc="大理千年庙会商贸与赛马并行，各族商人驮药材茶叶赶集；对歌射箭与白曲展演同台，象征茶马古道多元交汇。", cu=["赛马", "赶集"], fd=[], hi="", mj=True, tg=["集市"], ds="lunar_convert"),
            dict(sid="raosanling", name="绕三灵", ct="lunar", cd="4-23", desc="信众盛装巡游苍山洱海神灵居所，执柳祈福歌舞即兴；强调人与自然神圣契约，被誉为活的农耕图腾巡游。", cu=["巡游"], fd=[], hi="", mj=False, tg=["信仰"], ds="lunar_convert", cf="medium"),
            dict(sid="torch_bai", name="火把节", ct="lunar", cd="6-25", desc="白族山寨火把驱蝗祈愿丰收，扎火把赛马互泼米酒；虽与彝族火把同源却在祭祀辞与白曲唱腔上呈现洱海盆地特色。", cu=["火把"], fd=[], hi="", mj=False, tg=["火把"], ds="lunar_convert", cf="medium"),
            dict(sid="benzhu", name="本主节", ct="lunar", cd="4-1", desc="各村供奉守护神本主，迎神游船鞭炮宴席；洞经古乐与霸王鞭舞蹈穿插，体现村社自治与民间道教融合的信仰景观。", cu=["迎神"], fd=[], hi="", mj=False, tg=["本主"], ds="lunar_convert", cf="medium", nt="各村本主诞辰不同。"),
        ],
    )
    add(
        "tujia",
        "土家族",
        [
            dict(sid="ganian", name="赶年", ct="lunar", cd="12-29", desc="比汉族春节提前一天过年，传说源于出征辞岁；户户腊肉糍粑祭祀先祖跳摆手舞，凸显武陵山区军事记忆与家族守望。", cu=["摆手舞"], fd=["腊肉"], hi="", mj=True, tg=["新年"], ds="lunar_convert", cf="medium"),
            dict(sid="sheba", name="舍巴日", ct="lunar", cd="3-1", desc="大型摆手祭仪歌颂八部大神迁徙开荒，梯玛巫师吟唱古老歌谣；昼夜锣鼓不断，凝聚土家族口述历史与社群伦理。", cu=["摆手祭"], fd=[], hi="", mj=False, tg=["祭祀"], ds="lunar_convert", cf="medium"),
            dict(sid="june6", name="六月六", ct="lunar", cd="6-6", desc="晒衣物书籍防蛀祭祖晒龙袍传说并行；山歌盘唱与打溜子演出活跃村寨，象征梅雨过后的洁净与祈福。", cu=["晒衣"], fd=[], hi="", mj=False, tg=["消暑"], ds="lunar_convert"),
        ],
    )
    add(
        "hani",
        "哈尼族",
        [
            dict(sid="zhalet", name="扎勒特", ct="unknown", cd="10-1", desc="哈尼十月年长桌宴连村寨，簸箕盛鸡鸭谷物祭祖告知秋收喜讯；长辈吟唱迁徙史诗分配年轮耕作权，梯田文化与稻作伦理同日重申。", cu=["长桌宴"], fd=["染蛋"], hi="", mj=True, tg=["十月年"], ds="unknown", cf="medium", nt="哈尼历法与公历对照尚待统一算法。"),
            dict(sid="kuzazha", name="苦扎扎", ct="unknown", cd="6-1", desc="栽秧结束感恩夏日休息，打磨秋千立于村寨广场；男女对唱哈巴叙事插秧苦乐，祭祀田地神灵保佑梯田蓄水。", cu=["秋千"], fd=[], hi="", mj=False, tg=["农耕"], ds="unknown", cf="medium"),
            dict(sid="angmatu", name="昂玛突", ct="unknown", cd="2-1", desc="祭寨神确立村寨神圣边界，长老主持分配狩猎采集禁忌；仪式后全民清扫巷道修补沟渠，强化山林资源的社群共治。", cu=["祭寨神"], fd=[], hi="", mj=False, tg=["祭祀"], ds="unknown", cf="low"),
        ],
    )
    add(
        "kaz",
        "哈萨克族",
        [
            dict(sid="nowruz", name="纳吾鲁孜节", ct="gregorian", cd="3-21", desc="春分庆贺新年，熬制五谷粥抛洒祈福；阿肯弹唱冬不拉赛马叼羊，迁徙史诗在草原上口口相传。", cu=["叼羊"], fd=["纳吾粥"], hi="", mj=True, tg=["春分"], ds="fixed"),
            dict(sid="gurban", name="古尔邦节", ct="islamic", cd="12-10", desc="宰牲聚礼分食亲友，毡房飘香的手抓肉体现游牧穆斯林待客礼仪；少年赛马彰显勇毅品格。", cu=["聚礼"], fd=["手抓肉"], hi="依法放假", mj=True, tg=["伊斯兰教"], ds="algorithm"),
            dict(sid="rozi", name="肉孜节", ct="islamic", cd="10-1", desc="斋月结束开斋礼拜，奶茶油炸面食款待来客；草原牧民借机迁徙草场协调资源共享。", cu=["礼拜"], fd=["包尔萨克"], hi="依法放假", mj=True, tg=["开斋"], ds="algorithm"),
        ],
    )
    add(
        "li",
        "黎族",
        [
            dict(sid="march3", name="三月三", ct="lunar", cd="3-3", desc="海南黎寨对歌择偶跳竹竿舞，五色饭祭祖娱神；隆闺房习俗与传说爱情故事交织，列入非遗名录。", cu=["竹竿舞"], fd=["山栏酒"], hi="法定假日", mj=True, tg=["爱情"], ds="lunar_convert"),
            dict(sid="love", name="爱情节", ct="lunar", cd="3-3", desc="与三月三同源侧重婚恋叙事，姑娘赠送腰篓编织信物；傍晚篝火通宵民歌问答考验才情。", cu=["对歌"], fd=[], hi="", mj=False, tg=["婚恋"], ds="lunar_convert", cf="medium"),
            dict(sid="shanlan", name="山栏节", ct="unknown", cd="8-1", desc="庆贺山栏稻收割，酿酒杀猪款待帮工；长老讲述黎锦纹样禁忌，强化山地稻作互助伦理。", cu=["收割祭"], fd=["山栏酒"], hi="", mj=False, tg=["稻作"], ds="unknown", cf="low"),
        ],
    )
    add(
        "she",
        "畲族",
        [
            dict(sid="third_march", name="三月三", ct="lunar", cd="3-3", desc="畲族乌饭节蒸乌米饭祭祖，传说纪念英雄斗争；山歌盘唱讲述盘瓠传说，强化迁徙族群的身份认同。", cu=["祭祖"], fd=["乌米饭"], hi="", mj=True, tg=["祭祖"], ds="lunar_convert"),
            dict(sid="huiqin", name="会亲节", ct="lunar", cd="2-2", desc="出嫁女携儿女回娘家团聚，娘家备糍粑米酒宴请姻亲；修补亲属网络并传授育儿经验。", cu=["走亲"], fd=["糍粑"], hi="", mj=False, tg=["亲属"], ds="lunar_convert"),
            dict(sid="fenglong", name="封龙节", ct="lunar", cd="5-5", desc="立夏前后举行封龙仪式祈愿雨水调匀，师公吟咒巡田；插秧动员与社群互助公约同日宣布。", cu=["祭龙"], fd=[], hi="", mj=False, tg=["农耕"], ds="lunar_convert", cf="low"),
        ],
    )
    add(
        "buyi",
        "布依族",
        [
            dict(sid="june6", name="六月六", ct="lunar", cd="6-6", desc="晾晒衣物书籍祭祖祭田神，糯米粽子宴客；山歌对唱讲述稻作起源，象征梅雨结束洁净迎新。", cu=["祭田"], fd=["粽子"], hi="", mj=True, tg=["稻作"], ds="lunar_convert"),
            dict(sid="chabai", name="查白歌节", ct="lunar", cd="6-21", desc="黔西南布依青年山坡对歌择偶，传说源于忠贞爱情故事；木叶吹奏与糠包舞彰显山地浪漫。", cu=["对歌"], fd=[], hi="", mj=False, tg=["婚恋"], ds="lunar_convert"),
            dict(sid="thirdmar", name="三月三", ct="lunar", cd="3-3", desc="祭山扫墓蒸五色糯米饭，泼水嬉戏祈福风调雨顺；铜鼓敲击节奏贯穿祭仪与歌舞。", cu=["祭山"], fd=["五色饭"], hi="", mj=False, tg=["祭祖"], ds="lunar_convert"),
        ],
    )
    add(
        "naxi",
        "纳西族",
        [
            dict(sid="sanduo", name="三朵节", ct="lunar", cd="2-8", desc="祭祀战神三朵保护茶马商旅，玉龙雪山脚下赛马对歌；东巴诵经跳神面展现纳西族巫祭与商贸记忆。", cu=["赛马"], fd=[], hi="", mj=True, tg=["祭神"], ds="lunar_convert"),
            dict(sid="bangbang", name="棒棒会", ct="lunar", cd="1-15", desc="正月十五集市交易农具苗木种籽，纳西人家趁会修缮梯田工具；兼有占卜择偶与民歌交流的早春市集。", cu=["集会"], fd=[], hi="", mj=False, tg=["市集"], ds="lunar_convert"),
            dict(sid="qiyue", name="七月会", ct="lunar", cd="7-7", desc="山地物资交流赛马斗牛，姑娘穿戴七星披肩展示刺绣；夜间篝火打跳强化河谷社群联谊。", cu=["赛马"], fd=[], hi="", mj=False, tg=["集会"], ds="lunar_convert", cf="medium"),
        ],
    )

    # --- C 档（35 族，每族 1–2）---
    C = [
        ("gaoshan", "高山族", [
            dict(sid="harvest", name="丰收节", ct="unknown", cd="8-1", desc="台湾少数民族庆贺小米与芋头收成，头目主持感恩祭分享米酒；歌舞模拟狩猎捕鱼场景，强化部落联盟与资源共享。", cu=["感恩祭"], fd=["米酒"], hi="", mj=True, tg=["丰收"], ds="unknown", cf="low", nt="各族群祭仪名称时间不一。"),
            dict(sid="sowing", name="播种节", ct="unknown", cd="4-1", desc="春耕前占卜吉辰撒种祈福，妇女背着藤篓举行唤谷魂仪式；歌舞教导青年辨识节气与作物轮作。", cu=["播种祭"], fd=[], hi="", mj=False, tg=["农耕"], ds="unknown", cf="low"),
        ]),
        ("lahu", "拉祜族", [
            dict(sid="hulu", name="葫芦节", ct="unknown", cd="4-8", desc="传说中的葫芦孕育祖先，村寨摆葫芦图腾宴跳芦笙；巫师讲述迁徙史诗并分配山林采摘禁忌。", cu=["芦笙舞"], fd=[], hi="", mj=True, tg=["祖先"], ds="unknown", cf="medium"),
            dict(sid="kuota", name="扩塔节", ct="unknown", cd="1-1", desc="拉祜新年杀猪祭祖荡秋千，夜间火把巡游驱散疫病；青年男女互换烟草荷包订立口头婚约。", cu=["祭祖"], fd=[], hi="", mj=False, tg=["新年"], ds="unknown", cf="medium"),
        ]),
        ("shui", "水族", [
            dict(sid="duan", name="端节", ct="unknown", cd="9-1", desc="借端祭祖庆贺稻米鱼类丰收，赛马斗牛通宵饮酒；水书先生择吉日宣读迁徙戒律维持村寨秩序。", cu=["赛马"], fd=["鱼包韭菜"], hi="", mj=True, tg=["端节"], ds="lookup", cf="medium", nt="水历推算依赖端寨历法查表。"),
            dict(sid="mao", name="卯节", ct="unknown", cd="6-1", desc="青年卯坡对歌择偶，祭祖祈求梯田水产丰盈；仪式结束后方可开镰捕鱼，象征生态节律。", cu=["对歌"], fd=[], hi="", mj=False, tg=["婚恋"], ds="lookup", cf="low"),
        ]),
        ("dongx", "东乡族", [
            dict(sid="gurban", name="古尔邦节", ct="islamic", cd="12-10", desc="黄土高原穆斯林宰牲聚礼走亲，油香馓子馈赠邻里；阿訇宣讲仁爱故事强化社群互助。", cu=["聚礼"], fd=["油香"], hi="依法放假", mj=True, tg=["伊斯兰教"], ds="algorithm"),
            dict(sid="eid", name="开斋节", ct="islamic", cd="10-1", desc="斋月圆满礼拜施舍，农家蒸花卷宴客；山地梯田耕作节律短暂停歇以利走亲。", cu=["礼拜"], fd=[], hi="依法放假", mj=False, tg=["开斋"], ds="algorithm"),
        ]),
        ("jingp", "景颇族", [
            dict(sid="munao", name="目瑙纵歌节", ct="unknown", cd="1-15", desc="万人踩着同一个锣鼓点进入迷宫舞步，祭祀天神太阳象征族群团结；犀鸟图腾木雕高举巡游。", cu=["集体舞"], fd=[], hi="", mj=True, tg=["祭典"], ds="unknown", cf="medium", nt="举办年份轮值村寨而定。"),
            dict(sid="newrice", name="新米节", ct="unknown", cd="10-1", desc="尝新米饭祭祖告知秋收喜讯，长者讲述刀耕火种记忆；青年斗牛射箭选拔勇者护卫村寨。", cu=["尝新"], fd=[], hi="", mj=False, tg=["丰收"], ds="unknown", cf="low"),
        ]),
        ("keq", "柯尔克孜族", [
            dict(sid="nowruz", name="诺鲁孜节", ct="gregorian", cd="3-21", desc="帕米尔高原春分祈丰年，刁羊赛马与库姆孜弹唱同台；家家户户泼清水迎春除尘。", cu=["刁羊"], fd=["麦子粥"], hi="", mj=True, tg=["春分"], ds="fixed"),
            dict(sid="gurban", name="古尔邦节", ct="islamic", cd="12-10", desc="毡房宰牲聚礼后骑马访友，奶茶酥油款待远方来客；史诗吟唱延续游牧迁徙记忆。", cu=["聚礼"], fd=["奶茶"], hi="依法放假", mj=False, tg=["伊斯兰教"], ds="algorithm"),
        ]),
        ("tuzu", "土族", [
            dict(sid="nadun", name="纳顿节", ct="unknown", cd="7-1", desc="河湟谷地庄稼成熟时轮流上演跳於菟面具戏酬谢神灵；长达两个月的村庄祭仪揭示农耕军事屯垦叠合的历史。", cu=["面具戏"], fd=[], hi="", mj=True, tg=["农耕"], ds="lookup", cf="medium"),
            dict(sid="huaer", name="花儿会", ct="unknown", cd="6-6", desc="山地情歌擂台吸引跨省歌手，绣荷包交换象征情意；花儿曲调承载西北民族交融记忆。", cu=["花儿"], fd=[], hi="", mj=False, tg=["民歌"], ds="lookup", cf="medium"),
            dict(sid="leitai", name="擂台会", ct="unknown", cd="5-1", desc="传统的比武与商贸结合的庙会，青年摔跤射箭争夺荣誉；商贩借机交流畜种农具。", cu=["摔跤"], fd=[], hi="", mj=False, tg=["竞技"], ds="unknown", cf="low"),
        ]),
        ("daw", "达斡尔族", [
            dict(sid="anie", name="阿涅", ct="lunar", cd="1-1", desc="达斡尔新年包饺子祭祖敬火，冰雪赛马射箭考验耐寒品格；长辈讲述契丹后裔迁徙黑龙江流域史诗。", cu=["敬火"], fd=["饺子"], hi="", mj=True, tg=["新年"], ds="lunar_convert"),
            dict(sid="kumle", name="库木勒节", ct="unknown", cd="5-1", desc="采集柳蒿芽共享野蔬宴感恩自然馈赠；歌舞讲述渔猎转型农耕的经验互助。", cu=["采野菜"], fd=[], hi="", mj=False, tg=["迎春"], ds="unknown", cf="low"),
        ]),
        ("mul", "仫佬族", [
            dict(sid="yifan", name="依饭节", ct="unknown", cd="11-1", desc="三至五年一度的感恩还愿大典，师公戴面具跳神宴请祖宗；族人集资修缮宗族祠堂重申互助公约。", cu=["跳神"], fd=[], hi="", mj=True, tg=["祭祖"], ds="lookup", cf="medium", nt="具体周期依宗族占卜。"),
            dict(sid="paopo", name="走坡节", ct="lunar", cd="8-15", desc="青年山坡对歌择偶抛绣球，糯米糍粑象征同心；月下篝火延续至天明。", cu=["对歌"], fd=["糍粑"], hi="", mj=False, tg=["婚恋"], ds="lunar_convert"),
        ]),
        ("qiang", "羌族", [
            dict(sid="rmai", name="羌历新年", ct="unknown", cd="10-1", desc="日麦节杀猪敬白石神祈愿人畜平安，莎朗集体歌舞环绕火塘；释比吟唱创世史诗分配来年耕作禁忌。", cu=["祭白石"], fd=["咂酒"], hi="", mj=True, tg=["新年"], ds="unknown", cf="medium"),
            dict(sid="mount", name="祭山会", ct="unknown", cd="5-1", desc="高山村寨祭祀山神禁止砍伐狩猎数日；长老颁布封山育林乡约维护生态。", cu=["祭山"], fd=[], hi="", mj=False, tg=["信仰"], ds="unknown", cf="low"),
        ]),
        ("blang", "布朗族", [
            dict(sid="hounan", name="厚南节", ct="unknown", cd="4-1", desc="布朗新年泼水祝福清扫村寨，长者背诵迁徙史诗分配茶园采摘权；青年敲鼓绕寨驱邪。", cu=["泼水"], fd=["糯米"], hi="", mj=True, tg=["新年"], ds="unknown", cf="medium"),
            dict(sid="shankang", name="山康节", ct="unknown", cd="2-1", desc="祭祀部落祖先与茶祖，仪式后开行茶市互换普洱茶苗；歌舞模拟采茶揉捻工序。", cu=["祭茶祖"], fd=[], hi="", mj=False, tg=["茶"], ds="unknown", cf="low"),
        ]),
        ("sala", "撒拉族", [
            dict(sid="gurban", name="古尔邦节", ct="islamic", cd="12-10", desc="黄河谷地穆斯林宰牲聚礼分肉济贫，油搅团慰问老人；庭院栽种花草象征洁净信仰。", cu=["聚礼"], fd=["油搅团"], hi="依法放假", mj=True, tg=["伊斯兰教"], ds="algorithm"),
            dict(sid="eid", name="开斋节", ct="islamic", cd="10-1", desc="开斋礼拜施舍糕点孩童，家族团聚讲述迁徙中亚东渐故事；麦田收割互助公约同日重申。", cu=["礼拜"], fd=[], hi="依法放假", mj=False, tg=["开斋"], ds="algorithm"),
            dict(sid="mawlid", name="圣纪节", ct="islamic", cd="3-12", desc="清真寺熬煮粥饭施舍路人讲述圣人生平；绣花花帽展示撒拉族非遗。", cu=["诵经"], fd=[], hi="", mj=False, tg=["圣纪"], ds="algorithm", cf="medium"),
        ]),
        ("mnan", "毛南族", [
            dict(sid="fenlong", name="分龙节", ct="lunar", cd="5-20", desc="祈雨仪式分割稻田水源使用权，师公吟咒舞蹈模拟行云布雨；五色糯米饭供奉龙王。", cu=["祈雨"], fd=["五色饭"], hi="", mj=True, tg=["农耕"], ds="lunar_convert", cf="medium"),
            dict(sid="pumpkin", name="南瓜节", ct="lunar", cd="9-9", desc="感恩山地南瓜丰收制作南瓜宴款待帮工；山歌讲述迁徙落户毛南山乡的艰辛。", cu=["宴客"], fd=["南瓜"], hi="", mj=False, tg=["丰收"], ds="lunar_convert"),
        ]),
        ("gela", "仡佬族", [
            dict(sid="year", name="仡佬年", ct="lunar", cd="10-1", desc="敬雀节与新年合一，蒸糍粑喂鸟感恩啄虫护稼；祭田仪式分配来年稻种。", cu=["喂鸟"], fd=["糍粑"], hi="", mj=True, tg=["新年"], ds="lunar_convert", cf="medium"),
            dict(sid="chixin", name="吃新节", ct="unknown", cd="7-1", desc="尝新米祭祖告知秋收起始，长老诵读祭谷魂辞；禁忌解除后方可开仓。", cu=["尝新"], fd=[], hi="", mj=False, tg=["稻作"], ds="unknown", cf="low"),
            dict(sid="mountgod", name="祭山节", ct="unknown", cd="3-1", desc="仡佬山寨祭山封刀三日禁止砍伐；芦笙引导队伍巡游界定村寨神圣边界。", cu=["祭山"], fd=[], hi="", mj=False, tg=["信仰"], ds="unknown", cf="low"),
        ]),
        ("xibo", "锡伯族", [
            dict(sid="west_move", name="西迁节", ct="lunar", cd="4-18", desc="纪念乾隆年间锡伯军民万里戍边伊犁，庙会射箭比武重演行军阵列；家族供奉家谱讲述屯垦戍边史诗。", cu=["射箭"], fd=["发面饼"], hi="", mj=True, tg=["纪念"], ds="lunar_convert"),
            dict(sid="spring_day", name="春节", ct="lunar", cd="1-1", desc="抹黑祈福驱邪与萨满鼓舞并行，冻饺子炖鱼象征耐寒团聚；儿童蹬冰车延续渔猎记忆。", cu=["祭祖"], fd=["饺子"], hi="", mj=False, tg=["新年"], ds="lunar_convert"),
        ]),
        ("ach", "阿昌族", [
            dict(sid="aluwo", name="阿露窝罗节", ct="unknown", cd="3-1", desc="蹬窝罗螺旋舞步祭祀创世祖先遮帕麻与遮米麻；青龙白象道具巡游讲述天地开辟神话。", cu=["蹬窝罗"], fd=[], hi="", mj=True, tg=["创世"], ds="unknown", cf="medium"),
            dict(sid="huijie", name="会街节", ct="unknown", cd="9-1", desc="宗教信仰与商贸结合的集会，青龙白象舞沿街巡游并施舍米花；青年借机挑选银饰工匠拜师。", cu=["巡游"], fd=[], hi="", mj=False, tg=["集会"], ds="unknown", cf="low"),
        ]),
        ("pumi", "普米族", [
            dict(sid="wuxi", name="吾昔节", ct="unknown", cd="7-1", desc="普米新年杀猪祭祖跳锅庄，韩规巫师主持敬锅庄女神仪式；荞麦粑粑与苏里玛酒象征山地耐寒生计。", cu=["锅庄"], fd=["粑粑"], hi="", mj=True, tg=["新年"], ds="unknown", cf="medium"),
            dict(sid="zhuanshan", name="转山节", ct="unknown", cd="7-15", desc="环绕神山诵经撒五谷祈福，禁止砍伐狩猎七日；青年赛马选拔护卫神山志愿者。", cu=["转山"], fd=[], hi="", mj=False, tg=["信仰"], ds="unknown", cf="low"),
        ]),
        ("taj", "塔吉克族", [
            dict(sid="nowruz_tjk", name="肖公巴哈尔节", ct="gregorian", cd="3-21", desc="帕米尔迎春清扫房屋泼清水，刁羊赛马与鹰笛共鸣；长辈为孩子佩戴野花祈福茁壮成长。", cu=["刁羊"], fd=["麦子面"], hi="", mj=True, tg=["春节"], ds="fixed"),
            dict(sid="gurban", name="古尔邦节", ct="islamic", cd="12-10", desc="高原穆斯林宰牲聚礼后骑马互访，奶茶砖宴象征游牧社群资源共享。", cu=["聚礼"], fd=["奶茶"], hi="依法放假", mj=False, tg=["伊斯兰教"], ds="algorithm"),
        ]),
        ("nu", "怒族", [
            dict(sid="fairy", name="仙女节", ct="unknown", cd="3-15", desc="怒江峡谷采集杜鹃鲜花祭祀仙女岩洞，歌舞通宵祈求村寨免受泥石流之苦；妇女主导仪式凸显性别互助。", cu=["献花"], fd=[], hi="", mj=True, tg=["信仰"], ds="unknown", cf="medium"),
            dict(sid="forest", name="祭山林节", ct="unknown", cd="2-1", desc="封山育林祭祀禁止砍伐狩猎若干日；长老宣读资源分配公约调解林地纠纷。", cu=["祭林"], fd=[], hi="", mj=False, tg=["生态"], ds="unknown", cf="low"),
        ]),
        ("uzb", "乌孜别克族", [
            dict(sid="gurban", name="古尔邦节", ct="islamic", cd="12-10", desc="西域穆斯林宰牲宴客手抓饭飘香，十二木卡姆乐舞庭院展演；刺绣集市互换纹样技艺。", cu=["聚礼"], fd=["抓饭"], hi="依法放假", mj=True, tg=["伊斯兰教"], ds="algorithm"),
            dict(sid="eid", name="开斋节", ct="islamic", cd="10-1", desc="开斋布施甜食孩童，家族合唱民歌讲述丝路商旅记忆。", cu=["礼拜"], fd=["甜点"], hi="依法放假", mj=False, tg=["开斋"], ds="algorithm"),
            dict(sid="nowruz", name="诺鲁孜节", ct="gregorian", cd="3-21", desc="春分煮粥祈福歌舞，庭院泼水除尘象征涤荡晦气。", cu=["歌舞"], fd=["粥"], hi="", mj=False, tg=["迎春"], ds="fixed"),
        ]),
        ("elu", "俄罗斯族", [
            dict(sid="easter", name="复活节", ct="gregorian", cd="4-1", desc="东正教复活节彩绘复活蛋象征基督复活，教堂钟声后分享库里奇面包；家庭聚会讲述哈尔滨侨民社区的节庆记忆。", cu=["画彩蛋"], fd=["库里奇"], hi="", mj=True, tg=["东正教"], ds="fixed", cf="medium", nt="教会礼仪年日期因年与教派而异，待算法填充。"),
            dict(sid="christmas", name="圣诞节", ct="gregorian", cd="1-7", desc="东正教圣诞节礼拜唱诗分享蜜粥，雪地马车巡游重现侨居东北时期的节庆景观。", cu=["礼拜"], fd=["蜜粥"], hi="", mj=False, tg=["东正教"], ds="fixed", cf="medium", nt="各地教会礼仪日程不一，占位日期待核对。"),
        ]),
        ("ewk", "鄂温克族", [
            dict(sid="sebin", name="瑟宾节", ct="unknown", cd="6-18", desc="鄂温克猎人欢聚驯鹿营地摔跤射箭，萨满鼓声祈祷山林猎物丰盈；非遗传承人讲述使鹿部落迁徙故事。", cu=["驯鹿巡游"], fd=[], hi="", mj=True, tg=["游牧"], ds="unknown", cf="medium"),
            dict(sid="mikulu", name="米阔鲁节", ct="unknown", cd="5-1", desc="春季接羔繁育节庆，牧民给羔羊剪耳标记分配草场；宴饮表彰接羔能手。", cu=["剪耳标记"], fd=["奶制品"], hi="", mj=False, tg=["畜牧"], ds="unknown", cf="low"),
        ]),
        ("dea", "德昂族", [
            dict(sid="water", name="泼水节", ct="dai", cd="4-1", desc="德昂山寨浴佛泼水祝福，青年敲响象脚鼓巡游；糯米饭包烤肉体现跨境佛教节庆与山地农耕融合。", cu=["泼水"], fd=["糯米饭"], hi="", mj=True, tg=["节庆"], ds="lookup", cf="medium"),
            dict(sid="flower_water", name="浇花节", ct="unknown", cd="3-1", desc="青年男女相互浇花表达爱慕，佛寺诵经祈愿茶树丰收；仪式后采摘春茶祭谷魂。", cu=["浇花"], fd=[], hi="", mj=False, tg=["婚恋"], ds="unknown", cf="low"),
            dict(sid="open_gate", name="开门节", ct="dai", cd="12-1", desc="安居结束解禁歌舞宴饮，佛塔点灯洒水重演泼水喜气；村寨长老分配来年甘蔗种植地块。", cu=["点灯"], fd=[], hi="", mj=False, tg=["佛教"], ds="lookup", cf="low"),
        ]),
        ("bao", "保安族", [
            dict(sid="gurban", name="古尔邦节", ct="islamic", cd="12-10", desc="黄土高原穆斯林宰牲聚礼分肉济贫，保安腰刀技艺展示与宴席并行体现信仰与工匠精神。", cu=["聚礼"], fd=["油香"], hi="依法放假", mj=True, tg=["伊斯兰教"], ds="algorithm"),
            dict(sid="eid", name="开斋节", ct="islamic", cd="10-1", desc="开斋施舍油炸面食孩童，家族讲述黄河沿岸戍边屯垦故事。", cu=["礼拜"], fd=[], hi="依法放假", mj=False, tg=["开斋"], ds="algorithm"),
            dict(sid="mawlid", name="圣纪节", ct="islamic", cd="3-12", desc="清真寺熬粥讲述圣人生平，刺绣礼拜毯竞赛展现妇女才艺。", cu=["诵经"], fd=[], hi="", mj=False, tg=["圣纪"], ds="algorithm"),
        ]),
        ("yug", "裕固族", [
            dict(sid="horse_mane", name="剪马鬃节", ct="unknown", cd="5-1", desc="初夏给骏马剪鬃洗浴祈福水草丰美，骑手赛马叼羊展示驯牧技艺；帐篷宴饮传唱史诗。", cu=["剪鬃"], fd=["奶茶"], hi="", mj=True, tg=["畜牧"], ds="unknown", cf="low"),
            dict(sid="ovoo", name="鄂博节", ct="unknown", cd="6-1", desc="祭祀敖包堆砌石块祈福人畜平安，萨满诵经撒五谷；赛马摔跤选拔部落勇士。", cu=["祭敖包"], fd=[], hi="", mj=False, tg=["信仰"], ds="unknown", cf="medium"),
            dict(sid="fire_offer", name="祭火节", ct="unknown", cd="12-1", desc="冬季祭火塘讲述迁徙河西走廊记忆，羊拐游戏凝聚家族男性同盟。", cu=["祭火"], fd=[], hi="", mj=False, tg=["祭祖"], ds="unknown", cf="low"),
        ]),
        ("jingr", "京族", [
            dict(sid="ha", name="哈节", ct="unknown", cd="8-10", desc="京族祭海神唱哈长达数日，独弦琴伴奏叙事诗讲述海上谋生风险；渔民献捕获宴客共享渔汛红利。", cu=["唱哈"], fd=["鱼宴"], hi="", mj=True, tg=["海洋"], ds="lookup", cf="medium", nt="各村哈节日期轮流。"),
            dict(sid="changha", name="唱哈节", ct="unknown", cd="8-15", desc="与哈节同源侧重民歌擂台，姑娘头戴斗笠与渔夫对唱海盐之恋；仪式后修补渔网协作捕鱼。", cu=["对唱"], fd=[], hi="", mj=False, tg=["民歌"], ds="lookup", cf="low"),
        ]),
        ("tata", "塔塔尔族", [
            dict(sid="gurban", name="古尔邦节", ct="islamic", cd="12-10", desc="塔塔尔穆斯林宰牲宴客古拜底埃糕点飘香；冬不拉弹唱讲述中亚商旅定居伊犁河谷记忆。", cu=["聚礼"], fd=["糕点"], hi="依法放假", mj=True, tg=["伊斯兰教"], ds="algorithm"),
            dict(sid="eid", name="开斋节", ct="islamic", cd="10-1", desc="开斋施舍果酱糖果孩童，庭院栽种花卉象征信仰纯洁。", cu=["礼拜"], fd=[], hi="依法放假", mj=False, tg=["开斋"], ds="algorithm"),
            dict(sid="saban", name="撒班节", ct="unknown", cd="5-1", desc="春耕结束犁铧宴犒劳耕牛与农人，歌舞模拟犁地播种动作；集市交换良种牲畜。", cu=["犁铧宴"], fd=[], hi="", mj=False, tg=["农耕"], ds="unknown", cf="low"),
        ]),
        ("dulo", "独龙族", [
            dict(sid="kachewa", name="卡雀哇节", ct="unknown", cd="1-1", desc="独龙江峡谷新年剽牛祭天祈福人畜无病，长者分发猎物重申血缘互助；牛皮鼓声彻夜不息。", cu=["剽牛祭"], fd=[], hi="", mj=True, tg=["新年"], ds="unknown", cf="low"),
            dict(sid="sky_offer", name="剽牛祭天", ct="unknown", cd="12-1", desc="大型祭祖仪式杀牛分肉给每户，巫师吟唱创世史诗界定狩猎禁区。", cu=["剽牛"], fd=[], hi="", mj=False, tg=["祭祀"], ds="unknown", cf="low"),
        ]),
        ("elc", "鄂伦春族", [
            dict(sid="bonfire", name="篝火节", ct="unknown", cd="6-18", desc="森林猎民围着篝火跳兽皮舞讲述熊图腾禁忌；赛马射箭选拔新一代猎手首领。", cu=["篝火舞"], fd=[], hi="", mj=True, tg=["狩猎"], ds="unknown", cf="medium"),
            dict(sid="spring_year", name="春节", ct="lunar", cd="1-1", desc="贴桦树皮剪纸祭祖分享兽肉饺子，滑雪橇比赛模拟冬季狩猎追击。", cu=["祭祖"], fd=[], hi="", mj=False, tg=["新年"], ds="lunar_convert"),
        ]),
        ("hez", "赫哲族", [
            dict(sid="wurig", name="乌日贡节", ct="unknown", cd="7-1", desc="乌苏里江流域民族文艺体育盛会，鱼皮画鱼皮衣展演讲述渔猎技艺；鹿棋摔跤选拔村寨代表。", cu=["鱼皮工艺"], fd=["鱼肉"], hi="", mj=True, tg=["非遗"], ds="unknown", cf="medium"),
            dict(sid="river_lamp", name="河灯节", ct="unknown", cd="7-15", desc="放河灯超度溺水亡灵并祈求江水平静渔汛安稳；萨满鼓声引导船队巡游。", cu=["放河灯"], fd=[], hi="", mj=False, tg=["祭祀"], ds="unknown", cf="low"),
        ]),
        ("menb", "门巴族", [
            dict(sid="new_year", name="门巴新年", ct="unknown", cd="1-1", desc="藏南门巴村寨杀猪酿酒跳锅庄迎新岁，祭祀山神保佑古道商旅平安；传说融合吐蕃与门巴口传史诗。", cu=["锅庄"], fd=["青稞酒"], hi="", mj=True, tg=["新年"], ds="unknown", cf="medium"),
            dict(sid="wongkor", name="望果节", ct="tibetan", cd="7-1", desc="门巴农耕区绕田祈福模仿藏族望果仪式并加入门巴情歌；仪式后分配秋收互助劳力。", cu=["绕田"], fd=[], hi="", mj=False, tg=["丰收"], ds="algorithm", cf="medium", nt="与藏族望果同源而异俗。"),
        ]),
        ("luob", "珞巴族", [
            dict(sid="xudulong", name="旭独龙节", ct="unknown", cd="2-1", desc="珞巴新年剽牛共享猎物祭祖，巫师念诵始祖迁徙史诗并颁布狩猎禁忌；藤编器具交换巩固部落联盟。", cu=["剽牛"], fd=[], hi="", mj=True, tg=["新年"], ds="unknown", cf="low"),
            dict(sid="dongen", name="洞更谷乳木节", ct="unknown", cd="8-1", desc="秋收感恩祭祀洞神庇佑谷物无鼠患；青年射箭比赛选拔护卫山林边界勇士。", cu=["祭洞神"], fd=[], hi="", mj=False, tg=["农耕"], ds="unknown", cf="low"),
        ]),
        ("jino", "基诺族", [
            dict(sid="techmark", name="特懋克节", ct="unknown", cd="2-6", desc="基诺新年打铁祭鼓祈谷魂归来，长老敲响牛皮大鼓带领全村跳卓舞；竹笋宴象征热带雨林生计。", cu=["祭鼓"], fd=["竹笋"], hi="", mj=True, tg=["新年"], ds="unknown", cf="medium"),
            dict(sid="new_rice_jino", name="新米节", ct="unknown", cd="9-1", desc="尝新米杀猪祭祖告知秋收喜讯，青年交替敲击竹筒传递喜讯至邻寨。", cu=["尝新"], fd=[], hi="", mj=False, tg=["丰收"], ds="unknown", cf="low"),
        ]),
        ("lisu", "傈僳族", [
            dict(sid="kuoshi", name="阔时节", ct="unknown", cd="12-1", desc="傈僳新年跳嘎洒搓澡迎新岁，弩弓射靶比赛选拔猎手；同心酒仪式重申村寨联盟。", cu=["搓澡舞"], fd=["杵酒"], hi="", mj=True, tg=["新年"], ds="unknown", cf="medium"),
            dict(sid="knife_ladder", name="刀杆节", ct="unknown", cd="2-8", desc="勇士赤脚踏刀刃爬上高架祈福战胜灾祸；喃咪巫师吟诵史诗安抚亡灵。", cu=["上刀杆"], fd=[], hi="", mj=False, tg=["祭祀"], ds="unknown", cf="medium"),
            dict(sid="hot_spring", name="澡塘会", ct="unknown", cd="2-1", desc="怒江峡谷温泉集聚洗衣歌舞择偶，货物集市互换药材山货。", cu=["沐浴"], fd=[], hi="", mj=False, tg=["社交"], ds="unknown", cf="low"),
        ]),
        ("wa", "佤族", [
            dict(sid="new_rice_wa", name="新米节", ct="unknown", cd="10-1", desc="全寨品尝新米剽牛告知谷魂归来，木鼓敲击节奏贯穿祭祀与歌舞；禁忌解除后方可开仓。", cu=["敲木鼓"], fd=["鸡肉烂饭"], hi="", mj=True, tg=["稻作"], ds="unknown", cf="medium"),
            dict(sid="wood_drum", name="木鼓节", ct="unknown", cd="5-1", desc="拉木鼓进山祭祀神明保佑村寨平安，男女裸体彩绘跳舞驱邪；被视为佤族最具标志性的信仰盛典。", cu=["拉木鼓"], fd=[], hi="", mj=False, tg=["祭祀"], ds="unknown", cf="low"),
            dict(sid="monihei", name="摸你黑狂欢节", ct="unknown", cd="5-1", desc="涂泥嬉戏象征洗去晦气祝福彼此健康，篝火狂欢延续至天明展现边疆族群生命力。", cu=["涂泥"], fd=[], hi="", mj=False, tg=["狂欢"], ds="unknown", cf="medium"),
        ]),
    ]

    for eid, ename, rows in C:
        add(eid, ename, rows)

    # Header / meta
    doc = {
        "version": "2026.2",
        "last_updated": "2026-05-04",
        "source_note": "数据来源于公开资料整理；years 待批量填充；含 date_strategy、confidence、note 元数据。",
        "festivals": out,
    }
    return doc


def build_religious():
    fs = []

    def RF(rid, rtype, sid, name, ct, cd, desc, cu, fd, hi, mj, tg, ds, conf="high", note="", default_sub=False):
        fs.append(
            {
                "id": f"{rid}_{sid}",
                "name": name,
                "religion_id": rid,
                "religious_type": rtype,
                "calendar_type": ct,
                "calendar_date": cd,
                "description": desc,
                "customs": cu,
                "foods": fd,
                "holiday_info": hi,
                "years": {},
                "is_major": mj,
                "tags": tg,
                "date_strategy": ds,
                "confidence": conf,
                "note": note,
                "default_subscribed": default_sub,
            }
        )

    # Buddhism
    RF(
        "buddhism",
        "佛教",
        "buddha_birth",
        "佛诞节",
        "lunar",
        "4-8",
        "纪念释迦牟尼诞辰，寺院举行浴佛法会并以香水灌沐太子像；信众放生素食诵经，象征觉悟甘露洗涤无明，汉地俗称浴佛节并与花卉巡游相结合。",
        ["浴佛", "放生"],
        [],
        "",
        True,
        ["佛教"],
        "lunar_convert",
    )
    RF(
        "buddhism",
        "佛教",
        "laba",
        "腊八节",
        "lunar",
        "12-8",
        "寺院熬制腊八粥施舍信众纪念释迦牟尼成道前夕苦行；民间亦以杂粮粥祭祖御寒，强调施舍忍辱与精进修行的精神内涵。",
        ["施粥"],
        ["腊八粥"],
        "",
        False,
        ["佛教"],
        "lunar_convert",
    )
    RF(
        "buddhism",
        "佛教",
        "ulan",
        "盂兰盆节",
        "lunar",
        "7-15",
        "佛教盂兰盆法会超度六道父母，寺院举行焰口施食强调孝道与报恩；信众放生点灯寄托对亡亲的思念，体现大乘慈悲思想。",
        ["诵经", "施食"],
        [],
        "",
        True,
        ["佛教", "孝道"],
        "lunar_convert",
    )
    RF(
        "buddhism",
        "佛教",
        "nirvana",
        "涅槃节",
        "lunar",
        "2-15",
        "纪念佛陀入涅槃，僧侣诵经阐扬无常教法；信众点灯供花忏悔业障，反思生死觉悟之道，寺院气氛庄严肃穆。",
        ["诵经", "供灯"],
        [],
        "",
        False,
        ["佛教"],
        "lunar_convert",
        conf="medium",
        note="汉传与南传纪念日期传说有异。",
    )
    RF(
        "buddhism",
        "佛教",
        "enlightenment",
        "成道节",
        "lunar",
        "12-8",
        "亦称腊八成道纪念，强调释迦牟尼睹明星悟道；寺院通宵禅修讲经，提醒信众在日常中观照自心。",
        ["禅修", "讲经"],
        [],
        "",
        False,
        ["佛教"],
        "lunar_convert",
        conf="medium",
        note="与腊八民俗并行，寺院侧重不同。",
    )
    RF(
        "buddhism",
        "佛教",
        "guanyin",
        "观音诞",
        "lunar",
        "2-19",
        "观世音菩萨诞辰纪念日，信众赴寺敬香祈福海事平安家庭和睦；放生施舍强调慈悲救度的信仰实践。",
        ["进香", "放生"],
        [],
        "",
        False,
        ["佛教"],
        "lunar_convert",
    )

    # Islam
    RF(
        "islam",
        "伊斯兰教",
        "eid_fitr",
        "开斋节",
        "islamic",
        "10-1",
        "斋月结束清晨盛大聚礼，施舍济贫分享甜点；穆斯林更衣访友互致问候，象征忍耐之后的宽恕与社群团结。",
        ["聚礼", "施舍"],
        [],
        "依法放假",
        True,
        ["伊斯兰教"],
        "algorithm",
    )
    RF(
        "islam",
        "伊斯兰教",
        "eid_adha",
        "古尔邦节",
        "islamic",
        "12-10",
        "宰牲纪念易卜拉欣顺从故事，聚礼后分肉慰问孤寡；强调敬畏顺从与慷慨分享的信仰核心价值观。",
        ["宰牲", "聚礼"],
        [],
        "依法放假",
        True,
        ["伊斯兰教"],
        "algorithm",
    )
    RF(
        "islam",
        "伊斯兰教",
        "mawlid",
        "圣纪节",
        "islamic",
        "3-12",
        "诵读赞圣诗文讲述先知生平德行；清真寺施舍粥饭弘扬仁爱宽容精神，社群齐聚缅怀伊斯兰兴起历程。",
        ["诵经", "施舍"],
        [],
        "",
        True,
        ["伊斯兰教"],
        "algorithm",
        conf="medium",
    )
    RF(
        "islam",
        "伊斯兰教",
        "ashura",
        "阿舒拉日",
        "islamic",
        "1-10",
        "什叶派纪念侯赛因殉难逊尼派亦斋戒反省；施舍粥饭救济贫民体现坚忍与互助，清真寺讲述正义牺牲叙事。",
        ["斋戒", "施舍"],
        [],
        "",
        False,
        ["伊斯兰教"],
        "algorithm",
        conf="medium",
        note="教法学派对斋戒义务认定不同。",
    )
    RF(
        "islam",
        "伊斯兰教",
        "qadr",
        "盖德尔夜",
        "islamic",
        "9-27",
        "斋月後十日寻觅高贵之夜彻夜诵经施舍；《古兰经》初次降示的象征时刻，穆斯林加倍祈祷忏悔寻求赦宥。",
        ["诵经", "施舍"],
        [],
        "",
        False,
        ["伊斯兰教"],
        "algorithm",
        conf="medium",
        note="具体夜晚依学派在斋月末旬浮动。",
    )

    # Taoism
    RF(
        "taoism",
        "道教",
        "sanqing",
        "三清节",
        "unknown",
        "",
        "崇尚玉清上清太清三清尊神圣诞，宫观举行朝科法会诵经礼忏；信众供奉清香花灯祈求消灾解厄，体现道教神学体系的至高崇拜格局。",
        ["法会"],
        [],
        "",
        True,
        ["道教"],
        "unknown",
        conf="low",
        note="三清圣诞日在不同道派典籍中记载不一。",
    )
    RF(
        "taoism",
        "道教",
        "shangyuan",
        "上元节",
        "lunar",
        "1-15",
        "天官赐福之日，道观设坛祈福消灾并施舍汤圆；灯会与民俗元宵交融强调天人感应与孝道和睦。",
        ["祈福"],
        [],
        "",
        True,
        ["道教"],
        "lunar_convert",
    )
    RF(
        "taoism",
        "道教",
        "zhongyuan",
        "中元节",
        "lunar",
        "7-15",
        "地官赦罪超度水陆法会普度鬼魂；信众放生烧钱袱表达对先祖与无主孤魂的仁慈关怀。",
        ["超度"],
        [],
        "",
        True,
        ["道教"],
        "lunar_convert",
    )
    RF(
        "taoism",
        "道教",
        "xiayuan",
        "下元节",
        "lunar",
        "10-15",
        "水官解厄祈福江河安澜农田润泽；宫观诵经施舍粥米象征洗涤罪业迎接寒冬。",
        ["祈福"],
        [],
        "",
        False,
        ["道教"],
        "lunar_convert",
    )
    RF(
        "taoism",
        "道教",
        "yuhuang",
        "玉皇圣诞",
        "lunar",
        "9-9",
        "庆贺玉皇大帝诞辰，宫观举行玉皇大表科仪赦罪消灾；信众斋戒朝拜祈求国泰民安风调雨顺。",
        ["斋醮"],
        [],
        "",
        False,
        ["道教"],
        "lunar_convert",
        conf="medium",
    )

    # Christianity
    RF(
        "christianity",
        "基督教",
        "christmas",
        "圣诞节",
        "gregorian",
        "12-25",
        "纪念耶稣基督降生，教堂举行子夜弥撒或礼拜朗诵福音；家庭互赠礼物分享爱宴象征上帝对人的普世恩典。",
        ["礼拜"],
        [],
        "",
        True,
        ["基督教"],
        "fixed",
    )
    RF(
        "christianity",
        "基督教",
        "easter",
        "复活节",
        "computus",
        "",
        "纪念耶稣死里复活的核心教义，教堂烛光礼拜与哈利路亚颂歌交错；彩蛋象征新生盼望，信徒彼此祝贺复活喜讯。",
        ["礼拜"],
        [],
        "",
        True,
        ["基督教"],
        "fixed",
        conf="medium",
        note="日期按复活节算法浮动，待批量填充。",
    )
    RF(
        "christianity",
        "基督教",
        "good_friday",
        "受难节",
        "computus",
        "",
        "纪念耶稣受难钉十字架，教堂诵读受难剧默想救恩；信徒禁食祷告反省自我与宽恕他人。",
        ["礼拜", "禁食"],
        [],
        "",
        False,
        ["基督教"],
        "fixed",
        conf="medium",
        note="与复活节周相连具体日期待算法填充。",
    )
    RF(
        "christianity",
        "基督教",
        "thanksgiving_x",
        "感恩节",
        "unknown",
        "",
        "教会层面感恩礼拜歌颂上帝供应与保守，不同于世俗购物狂欢；信徒奉献物资救助弱势群体体现感恩行动。",
        ["感恩礼拜", "奉献"],
        [],
        "",
        False,
        ["基督教"],
        "unknown",
        conf="low",
        note="教会历感恩主日与美洲世俗感恩节不同步。",
    )
    RF(
        "christianity",
        "基督教",
        "epiphany",
        "主显节",
        "unknown",
        "",
        "纪念东方博士朝拜圣婴与耶稣受洗显现神性；部分地区行了祝福圣水与烛光游行强调启示光照万国。",
        ["礼拜"],
        [],
        "",
        False,
        ["基督教"],
        "unknown",
        conf="medium",
        note="东正教与西方教会日期不一。",
    )

    # Hindu (legacy compatibility)
    RF(
        "hinduism",
        "印度教",
        "diwali",
        "排灯节",
        "hindu",
        "",
        "光明战胜黑暗的象征节日，点灯祈福洁净家园互赠甜食；寺庙诵读史诗段落家族团聚分享救赎叙事。",
        ["点灯"],
        [],
        "",
        True,
        ["印度教"],
        "unknown",
        conf="medium",
    )
    RF(
        "hinduism",
        "印度教",
        "holi",
        "洒红节",
        "hindu",
        "",
        "春日色彩的欢庆节日，抛洒植物粉末化解隔阂重建社群和睦；歌舞巡游讲述黑天神传说彰显爱与宽恕。",
        ["洒彩"],
        [],
        "",
        False,
        ["印度教"],
        "unknown",
        conf="medium",
    )

    return {
        "version": "2026.2",
        "last_updated": "2026-05-04",
        "source_note": "years 待批量填充；含佛教、伊斯兰教、道教、基督教及保留印度教条目。",
        "festivals": fs,
    }


def main():
    eth_path = ROOT / "assets/data/ethnic_festivals.json"
    rel_path = ROOT / "assets/data/religious_festivals.json"
    eth_doc = build_ethnic()
    rel_doc = build_religious()
    eth_path.write_text(json.dumps(eth_doc, ensure_ascii=False, indent=2), encoding="utf-8")
    rel_path.write_text(json.dumps(rel_doc, ensure_ascii=False, indent=2), encoding="utf-8")
    print("Wrote", eth_path, "festivals:", len(eth_doc["festivals"]))
    print("Wrote", rel_path, "festivals:", len(rel_doc["festivals"]))


if __name__ == "__main__":
    main()
