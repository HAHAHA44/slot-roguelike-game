# 运行界面统一皮肤（深色「命理转盘」主题）：
# - 代码构 Theme + StyleBoxFlat，RunScreen._ready() 里赋到根节点，子控件自动继承。
#   （「内容进 .tres」是针对玩法内容；界面皮肤用代码构是可接受的，方便统一调色。）
# - 配色沿用转盘既有语义：金 = 本命年、青 = 当年奖励格。
# - 只定义通用控件（Label / Button / PanelContainer / ItemList）的默认样式；
#   ZodiacRing 自绘不受影响。
class_name UiTheme
extends RefCounted

const BG_DEEP := Color("0e0e17")
const BG_PANEL := Color("1b1b2a")
const BG_PANEL_ALT := Color("14141f")
const BORDER := Color("2e2e44")
const GOLD := Color("e6c84d")
const TEAL := Color("4cd98c")
const TEXT := Color("ededf2")
const TEXT_DIM := Color("9a9ab0")
const BTN := Color("26263a")
const BTN_HOVER := Color("32324c")
const BTN_PRESSED := Color("1e1e30")
const DANGER := Color("e8776a")

static func build() -> Theme:
	var theme := Theme.new()
	theme.default_font_size = 16

	theme.set_color("font_color", "Label", TEXT)

	var panel_sb := _panel_style(BG_PANEL, BORDER, 12)
	theme.set_stylebox("panel", "PanelContainer", panel_sb)
	theme.set_stylebox("panel", "Panel", panel_sb)

	theme.set_stylebox("normal", "Button", _button_style(BTN, BORDER))
	theme.set_stylebox("hover", "Button", _button_style(BTN_HOVER, GOLD.darkened(0.25)))
	theme.set_stylebox("pressed", "Button", _button_style(BTN_PRESSED, BORDER))
	theme.set_stylebox("disabled", "Button", _button_style(BG_PANEL_ALT, BORDER))
	theme.set_stylebox("focus", "Button", _flat(Color(0, 0, 0, 0), 10))
	theme.set_color("font_color", "Button", TEXT)
	theme.set_color("font_hover_color", "Button", GOLD)
	theme.set_color("font_pressed_color", "Button", TEXT_DIM)
	theme.set_color("font_disabled_color", "Button", TEXT_DIM.darkened(0.25))

	theme.set_stylebox("panel", "ItemList", _panel_style(BG_PANEL_ALT, BORDER, 10))
	theme.set_color("font_color", "ItemList", TEXT_DIM)
	theme.set_color("font_selected_color", "ItemList", GOLD)
	theme.set_stylebox("selected", "ItemList", _flat(GOLD.darkened(0.62), 6))
	theme.set_stylebox("selected_focus", "ItemList", _flat(GOLD.darkened(0.58), 6))
	theme.set_color("guide_color", "ItemList", Color(BORDER.r, BORDER.g, BORDER.b, 0.5))

	return theme

# 生成一张从上到下微渐变的背景纹理（深靛蓝 → 更暗），铺满界面。
static func background_gradient() -> GradientTexture2D:
	var gradient := Gradient.new()
	gradient.set_color(0, Color("161628"))
	gradient.set_color(1, BG_DEEP)
	var tex := GradientTexture2D.new()
	tex.gradient = gradient
	tex.fill = GradientTexture2D.FILL_LINEAR
	tex.fill_from = Vector2(0.0, 0.0)
	tex.fill_to = Vector2(0.0, 1.0)
	tex.width = 8
	tex.height = 256
	return tex

static func _panel_style(bg: Color, border: Color, radius: int) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(radius)
	sb.set_border_width_all(1)
	sb.border_color = border
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 12
	sb.content_margin_bottom = 12
	return sb

static func _button_style(bg: Color, border: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(10)
	sb.set_border_width_all(1)
	sb.border_color = border
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	return sb

static func _flat(bg: Color, radius: int) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(radius)
	return sb
