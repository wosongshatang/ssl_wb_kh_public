extends GutTest
## 美术明度一致性测试（阶段 8）
##
## ## 守的是什么
## 「背景太亮、角色看不清」是**肉眼能感觉到、但每次都要重新吵一遍**的问题。
## 说清了就是一句可测的话：
##
## > **背景的平均亮度必须低于角色的平均亮度**，否则前景会"沉"进背景里。
##
## ## 为什么分「硬上限」和「理想区」两档（照搬技能的设计）
## 单一区间会让"可接受但非最优"的图把门禁刷成噪音。
## **门禁一旦误报，人就会干脆关掉它——比没有门禁更糟（D17）。**
## 所以：真正破坏基调的必拦（❌ 失败），拿捏性的判断只提示（⚠️ 打印）。
##
## ## 为什么有「已登记的折中」
## 有些图的美术价值值得换一点明度偏差（沙地 + 落日天然高亮）。
## 这类**必须显式登记**，否则视为未达标——**默认不允许静默例外**。
##
## ## 度量方式
## Rec.709 加权（0.2126/0.7152/0.0722）。人眼对绿最敏感、对蓝最不敏感，
## 等权平均会把深蓝背景算亮、暖色角色算暗，判定就会偏。

# ── 硬上限（突破即失败）——与技能 §2.2 表一致 ──────────────
const ENV_HARD_MIN: float = 30.0
const ENV_HARD_MAX: float = 55.0
const CHAR_HARD_MIN: float = 36.0
const CHAR_HARD_MAX: float = 75.0

# ── 理想区（未达只打印，不判失败）────────────────────────
const ENV_IDEAL_MIN: float = 35.0
const ENV_IDEAL_MAX: float = 48.0
const CHAR_IDEAL_MIN: float = 42.0
const CHAR_IDEAL_MAX: float = 70.0

## 已登记的折中：落在理想区外、硬上限内，**用户已确认保留**。
## 新增折中必须先登记在这里，否则测试会当成未达标。
const REGISTERED_COMPROMISES: Dictionary = {
	"warrior_act1": "沙地 + 落日天空天然高亮；压到理想区需累计系数 0.58（低于 0.70 舒适线），经确认保留",
}

## 透明像素不算数——否则透明区会被当成纯黑拉低均值（技能 §2.1）
const ALPHA_GATE: int = 200
## 抽样步长。取 4 已足够稳定，且比全图快两个数量级
const SAMPLE_STEP: int = 4

const CHARACTERS: Array[StringName] = [&"warrior", &"mage", &"hunter"]
const BACKGROUNDS: Array[Array] = [
	[&"warrior", 1], [&"mage", 2], [&"hunter", 3],
]


func before_all() -> void:
	ContentRegistry.load_all()


# ── 测量 ────────────────────────────────────────────────────

## Rec.709 加权平均亮度（0~255）。返回 -1 表示读不出来。
func _mean_luma(path: String) -> float:
	var tex: Texture2D = load(path) as Texture2D
	if tex == null:
		return -1.0
	var img: Image = tex.get_image()
	if img == null:
		return -1.0
	if img.get_format() != Image.FORMAT_RGBA8:
		img.convert(Image.FORMAT_RGBA8)

	var w: int = img.get_width()
	var h: int = img.get_height()
	if w <= 0 or h <= 0:
		return -1.0
	var data: PackedByteArray = img.get_data()

	var total: float = 0.0
	var count: int = 0
	var y: int = 0
	while y < h:
		var x: int = 0
		while x < w:
			var o: int = (y * w + x) * 4
			if data[o + 3] >= ALPHA_GATE:
				total += 0.2126 * float(data[o]) \
					+ 0.7152 * float(data[o + 1]) \
					+ 0.0722 * float(data[o + 2])
				count += 1
			x += SAMPLE_STEP
		y += SAMPLE_STEP
	if count <= 0:
		return -1.0
	return total / float(count)


func _character_luma(character: StringName) -> float:
	return _mean_luma("res://assets/portraits/%s.png" % character)


func _background_luma(entry: Array) -> float:
	return _mean_luma(ContentRegistry.battle_background_path(entry[0], entry[1]))


func _background_key(entry: Array) -> String:
	return "%s_act%d" % [entry[0], entry[1]]


# ── 硬性规则（❌ 突破即失败）────────────────────────────────

func test_characters_are_measurable_and_within_hard_limits() -> void:
	for character: StringName in CHARACTERS:
		var l: float = _character_luma(character)
		assert_gt(l, 0.0, "%s 立绘读不出亮度" % character)
		assert_between(l, CHAR_HARD_MIN, CHAR_HARD_MAX,
			"%s 立绘亮度 %.1f 超出硬上限 %.0f~%.0f" % [character, l, CHAR_HARD_MIN, CHAR_HARD_MAX])


func test_backgrounds_are_within_hard_limits() -> void:
	for entry: Array in BACKGROUNDS:
		var l: float = _background_luma(entry)
		assert_gt(l, 0.0, "%s 背景读不出亮度" % _background_key(entry))
		assert_between(l, ENV_HARD_MIN, ENV_HARD_MAX,
			"%s 背景亮度 %.1f 超出硬上限 %.0f~%.0f"
			% [_background_key(entry), l, ENV_HARD_MIN, ENV_HARD_MAX])


func test_backgrounds_are_darker_than_characters() -> void:
	## ⚠️ **核心硬规则**：背景不得亮于角色，否则角色会沉进背景。
	##
	## 已登记的折中**豁免此条**（用户确认过），其余一律不能破。
	var char_mean: float = 0.0
	for character: StringName in CHARACTERS:
		char_mean += _character_luma(character)
	char_mean /= float(CHARACTERS.size())
	assert_gt(char_mean, 0.0, "角色均值读不出来")

	for entry: Array in BACKGROUNDS:
		var key: String = _background_key(entry)
		if REGISTERED_COMPROMISES.has(key):
			continue
		var l: float = _background_luma(entry)
		assert_lt(l, char_mean,
			"%s 背景亮度 %.1f 不低于角色均值 %.1f —— 角色会看不清"
			% [key, l, char_mean])


func test_registered_compromises_are_documented() -> void:
	## 折中必须**写明原因**。空字符串等于"随便豁免"，那就失去意义了。
	for key: String in REGISTERED_COMPROMISES.keys():
		var reason: String = str(REGISTERED_COMPROMISES[key])
		assert_gt(reason.length(), 10, "%s 的折中原因写得太短，等于没写" % key)
		# 折中的图必须真的存在，否则是过期登记
		var found: bool = false
		for entry: Array in BACKGROUNDS:
			if _background_key(entry) == key:
				found = true
		assert_true(found, "%s 已不在背景清单里，折中登记过期了" % key)


func test_registered_compromise_still_respects_hard_limits() -> void:
	## 折中只是"允许偏离理想区"，**不是"可以无限亮"**。
	## 这条防止有人把折中当成万能免死金牌。
	for entry: Array in BACKGROUNDS:
		var key: String = _background_key(entry)
		if not REGISTERED_COMPROMISES.has(key):
			continue
		var l: float = _background_luma(entry)
		assert_lt(l, ENV_HARD_MAX,
			"%s 是折中项，但仍不能突破硬上限 %.0f（当前 %.1f）" % [key, ENV_HARD_MAX, l])


# ── 理想区（⚠️ 只提示，不判失败）──────────────────────────

func test_ideal_range_deviations_are_reported() -> void:
	## 这条**永远通过**——它只负责把"离理想区还有多远"打到日志里。
	## 故意不判失败：门禁误报比没有门禁更糟（D17）。
	##
	## 断言只用来说明"理想区本身是良构的"，不是判图。
	assert_lt(ENV_IDEAL_MIN, ENV_IDEAL_MAX, "环境理想区上下界写反了")
	assert_lt(CHAR_IDEAL_MIN, CHAR_IDEAL_MAX, "角色理想区上下界写反了")

	for entry: Array in BACKGROUNDS:
		var key: String = _background_key(entry)
		var l: float = _background_luma(entry)
		if l < ENV_IDEAL_MIN or l > ENV_IDEAL_MAX:
			var note: String = "已登记折中" if REGISTERED_COMPROMISES.has(key) else "未登记"
			gut.p("⚠️  %s 背景亮度 %.1f 在理想区 %.0f~%.0f 之外（%s）"
				% [key, l, ENV_IDEAL_MIN, ENV_IDEAL_MAX, note])


func test_non_compromised_backgrounds_share_one_tone() -> void:
	## 「统一视觉基调」的量化定义：**非折中项之间**不能差太多。
	## 折中项本来就是离群点，把它算进来会让这条失去意义。
	var lumas: Array[float] = []
	for entry: Array in BACKGROUNDS:
		if REGISTERED_COMPROMISES.has(_background_key(entry)):
			continue
		lumas.append(_background_luma(entry))

	assert_gt(lumas.size(), 1, "非折中背景少于两张，这条测不出东西")
	var lo: float = lumas[0]
	var hi: float = lumas[0]
	for l: float in lumas:
		lo = minf(lo, l)
		hi = maxf(hi, l)
	assert_gt(lo, 0.0, "有背景读不出亮度")
	var spread: float = (hi - lo) / lo
	assert_lt(spread, 0.20,
		"非折中背景亮度差 %.0f%%（%.1f ~ %.1f），超过 20%% —— 基调不统一"
		% [spread * 100.0, lo, hi])
