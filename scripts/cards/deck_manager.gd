class_name DeckManager
extends RefCounted
## 牌堆管理（阶段 1 薄切片版）
##
## 抽牌堆 / 手牌 / 弃牌堆 + 洗牌。
## 阶段 1 的验收硬指标之一：**抽牌堆空时正确从弃牌堆重洗**。
##
## 洗牌用注入的 RandomNumberGenerator（Fisher-Yates），保证测试可复现——
## 用全局 randi() 会让"洗牌后顺序"无法断言。

signal card_drawn(card: CardData)
signal hand_changed(hand: Array[CardData])
signal reshuffled

var draw_pile: Array[CardData] = []
var hand: Array[CardData] = []
var discard_pile: Array[CardData] = []
## 消耗区：被消耗的牌本局不再回牌堆（阶段 5 法师线才真正使用）
var exhaust_pile: Array[CardData] = []

var _rng: RandomNumberGenerator


func _init(rng: RandomNumberGenerator = null) -> void:
	_rng = rng if rng != null else RandomNumberGenerator.new()


## 用初始牌组开新局（会复制一份，不污染调用方的数组）
func setup(starting_deck: Array[CardData]) -> void:
	draw_pile = starting_deck.duplicate()
	hand.clear()
	discard_pile.clear()
	exhaust_pile.clear()
	_shuffle(draw_pile)


## 抽 count 张。抽牌堆空则重洗弃牌堆；弃牌堆也空则提前停止。
func draw(count: int) -> Array[CardData]:
	var drawn: Array[CardData] = []
	for _i: int in count:
		if draw_pile.is_empty() and not _reshuffle_discard_into_draw():
			break
		var card: CardData = draw_pile.pop_back()
		hand.append(card)
		drawn.append(card)
		card_drawn.emit(card)
	hand_changed.emit(hand)
	return drawn


## 从手牌取出一张（离手但不入弃牌堆）——出牌结算期间使用
func take_from_hand(card: CardData) -> bool:
	if not hand.has(card):
		return false
	hand.erase(card)
	hand_changed.emit(hand)
	return true


func add_to_discard(card: CardData) -> void:
	discard_pile.append(card)


func add_to_exhaust(card: CardData) -> void:
	exhaust_pile.append(card)


## 把手牌中的一张牌移入消耗区（本局不再回牌堆）。
## 阶段 5 法师线的「禁忌知识」「死灵师」依赖这个入口。
## ⚠️ 消耗区**不参与重洗**——这是它存在的全部意义。
func exhaust(card: CardData) -> bool:
	if not take_from_hand(card):
		return false
	exhaust_pile.append(card)
	return true


## 整张手牌进弃牌堆（回合结束）
func discard_hand() -> int:
	var count: int = hand.size()
	if count == 0:
		return 0
	discard_pile.append_array(hand)
	hand.clear()
	hand_changed.emit(hand)
	return count


func _reshuffle_discard_into_draw() -> bool:
	if discard_pile.is_empty():
		return false
	draw_pile.append_array(discard_pile)
	discard_pile.clear()
	_shuffle(draw_pile)
	reshuffled.emit()
	return true


## Fisher-Yates，就地打乱
func _shuffle(arr: Array[CardData]) -> void:
	for i: int in range(arr.size() - 1, 0, -1):
		var j: int = _rng.randi_range(0, i)
		var tmp: CardData = arr[i]
		arr[i] = arr[j]
		arr[j] = tmp
