extends RefCounted
## Shared Mario Kart 64 style look for the menu and the race HUD: a rounded bold font, a
## gold / cream / navy palette, drop shadows instead of thick black outlines and navy panels
## with a gold rim. Only the big "sign" texts (logo, countdown, banners) keep a coloured rim.

# MK64 palette: gold highlights, cream body text, navy panels with a gold rim, a red logo
const GOLD := Color(1.0, 0.82, 0.22)
const GOLD_DIM := Color(0.95, 0.78, 0.35, 0.85)
const CREAM := Color(0.98, 0.97, 0.92)
const GREY := Color(0.72, 0.76, 0.86)
const SKY_BLUE := Color(0.55, 0.9, 1.0)
const LOGO_RED := Color(0.9, 0.14, 0.1)
const LOGO_RIM := Color(1.0, 0.86, 0.3)
const SIGN_RIM := Color(0.55, 0.08, 0.05)
const PANEL_FILL := Color(0.05, 0.07, 0.2, 0.84)
const PANEL_RIM := Color(1.0, 0.8, 0.25, 0.95)
const SHADOW := Color(0, 0, 0, 0.55)
## Rounded fonts in MK64's spirit; Godot falls back to its default font when none is installed.
const FONT_NAMES := ["Arial Rounded MT Bold", "Avenir Next", "Verdana"]

static func make_font() -> Font:
	var f := SystemFont.new()
	f.font_names = FONT_NAMES
	f.font_weight = 700
	f.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
	return f

## Drop-shadow offset for a given text size (2 px for small text, 3 px from 30 px up, 5 px for signs).
static func shadow_offset(font_size: int) -> int:
	if font_size >= 64:
		return 5
	return 3 if font_size >= 30 else 2

## Body text: coloured, drop shadow, no outline.
static func style_label(l: Label, font: Font, font_size: int, col: Color) -> void:
	l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_shadow_color", SHADOW)
	var off := shadow_offset(font_size)
	l.add_theme_constant_override("shadow_offset_x", off)
	l.add_theme_constant_override("shadow_offset_y", off)
	l.add_theme_constant_override("outline_size", 0)

## Sign text (countdown, FINISH!, YOU WIN!): gold with a dark red rim like the logo, over a shadow.
static func style_sign(l: Label, font: Font, font_size: int, col := GOLD, rim := SIGN_RIM) -> void:
	style_label(l, font, font_size, col)
	l.add_theme_color_override("font_outline_color", rim)
	l.add_theme_constant_override("outline_size", maxi(3, font_size / 16))

## Navy panel with a gold rim and a soft shadow (menu panels, results table).
static func panel_style(fill := PANEL_FILL, rim := PANEL_RIM, radius := 16) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = fill
	sb.border_color = rim
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(radius)
	sb.shadow_color = Color(0, 0, 0, 0.35)
	sb.shadow_size = 6
	sb.shadow_offset = Vector2(0, 3)
	return sb
