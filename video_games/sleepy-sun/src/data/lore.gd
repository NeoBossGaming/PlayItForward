class_name Lore
extends RefCounted
## The story of one credit, as data.
##
## Seventeen hand-built cutscene scenes would be unmaintainable and, worse,
## unreviewable -- nobody would ever look at all of them. So a cutscene here is
## a list of *shots*, and a shot is a sky, a caption, and some sprites told
## where to go. src/ui/cutscene.gd knows how to play one; this file is the only
## place the actual story lives, so rewriting the lore never means touching a
## scene.
##
## Every texture named here is already on disk. That is deliberate: the lore had
## to be able to ship without waiting on art, so the cutscenes are composed from
## the minigames' own sprites. Only four placeholders were added for it
## (village/sun_beaming, decor/ray, decor/hill, decor/note).
##
## The premise, in one line: **the sun slept through the dawn**. Each minigame
## gathers one thing that might wake it -- its `gift` in Game.MINIGAMES -- and
## the finale shows the player what they brought.

const ART := "res://assets/game/"

# --- skies -------------------------------------------------------------------
#
# Read top-of-screen first, bottom second. The sequence of a cutscene is usually
# the sequence of these: night, then blue hour, then something warm at the edge.

const NIGHT: Array[Color] = [Color(0.06, 0.07, 0.17), Color(0.13, 0.15, 0.28)]
const BLUE_HOUR: Array[Color] = [Color(0.10, 0.13, 0.29), Color(0.28, 0.28, 0.44)]
const PRE_DAWN: Array[Color] = [Color(0.17, 0.17, 0.36), Color(0.52, 0.36, 0.42)]
const DAWN: Array[Color] = [Color(0.28, 0.30, 0.52), Color(0.88, 0.56, 0.38)]
const MORNING: Array[Color] = [Color(0.40, 0.62, 0.87), Color(0.98, 0.79, 0.50)]
const GOLD: Array[Color] = [Color(0.52, 0.73, 0.94), Color(1.00, 0.88, 0.56)]
const DUSK: Array[Color] = [Color(0.21, 0.20, 0.40), Color(0.82, 0.47, 0.35)]
const HOLLOW: Array[Color] = [Color(0.08, 0.07, 0.13), Color(0.20, 0.15, 0.26)]
const DEEP: Array[Color] = [Color(0.05, 0.11, 0.22), Color(0.11, 0.26, 0.40)]

## Where the ground sits in a cutscene, so the eight of them agree with
## each other about where the horizon is.
const GROUND := 216.0
const HORIZON := 206.0


# --- public ------------------------------------------------------------------

## The beat that plays before the instruction card: why this game matters.
static func before(id: StringName) -> Array[Dictionary]:
	match id:
		&"wind_leaf": return _before_wind_leaf()
		&"tall_grass": return _before_tall_grass()
		&"cave": return _before_cave()
		&"harpoon": return _before_harpoon()
		&"acorn_storm": return _before_acorn_storm()
		&"firefly": return _before_firefly()
		&"temple_bell": return _before_temple_bell()
		&"crow_watch": return _before_crow_watch()
	return []


## The beat that plays after: what the player just did with it. `met_par` picks
## the confident telling over the gentle one -- never a failure, only a quieter
## success, because the cabinet has no fail state and never will.
static func after(id: StringName, met_par: bool) -> Array[Dictionary]:
	match id:
		&"wind_leaf": return _after_wind_leaf(met_par)
		&"tall_grass": return _after_tall_grass(met_par)
		&"cave": return _after_cave(met_par)
		&"harpoon": return _after_harpoon(met_par)
		&"acorn_storm": return _after_acorn_storm(met_par)
		&"firefly": return _after_firefly(met_par)
		&"temple_bell": return _after_temple_bell(met_par)
		&"crow_watch": return _after_crow_watch(met_par)
	return []


# --- ranking -----------------------------------------------------------------
#
# Tiers live here rather than on the results screen so the finale and the rank
# stamp can never disagree. A beaming sun over a WARM stamp would read as a bug
# to everybody who saw it, and it would be one.

const TIERS: Array[Array] = [
	[1.15, "RADIANT", Color(1.00, 0.87, 0.45)],
	[0.90, "BRIGHT", Color(0.95, 0.78, 0.42)],
	[0.65, "WARM", Color(0.78, 0.82, 0.60)],
	[0.00, "GENTLE", Color(0.70, 0.74, 0.85)],
]

## Index into TIERS for a score/par ratio. 0 is the best.
static func tier_for(ratio: float) -> int:
	for i in TIERS.size():
		if ratio >= float(TIERS[i][0]):
			return i
	return TIERS.size() - 1


static func tier_name(tier: int) -> String:
	return String(TIERS[clampi(tier, 0, TIERS.size() - 1)][1])


static func tier_color(tier: int) -> Color:
	return TIERS[clampi(tier, 0, TIERS.size() - 1)][2]


## The end of the credit. `gift_ids` are the games actually dealt, so the sun is
## thanked for what this run brought rather than for a generic three.
static func finale(tier: int, gift_ids: Array = []) -> Array[Dictionary]:
	var shots: Array[Dictionary] = []
	shots.append(_shot(1.7, PRE_DAWN, "You left it all at the edge of the world.", [
		_hill(238),
		_a(ART + "player/idle_up.png", Vector2(240, 190), {"scale": 1.5}),
		_a(ART + "decor/star.png", Vector2(90, 60), {"tint": Color(1, 1, 1, 0.7)}),
		_a(ART + "decor/star.png", Vector2(392, 78), {"tint": Color(1, 1, 1, 0.6)}),
		_a(ART + "decor/star.png", Vector2(300, 48), {"tint": Color(1, 1, 1, 0.5)}),
	]))
	shots.append(_gift_shot(gift_ids))

	match clampi(tier, 0, 3):
		0: shots.append_array(_finale_radiant())
		1, 2: shots.append_array(_finale_bright())
		_: shots.append_array(_finale_gentle())
	return shots


## Every texture path any cutscene can ask for. tests/smoke_test.gd loads all of
## them: a typo in a path here is invisible until that exact cutscene plays in
## front of somebody, which is the worst possible time to find it.
static func every_texture_path() -> PackedStringArray:
	var paths := PackedStringArray()
	var lists: Array[Array] = []
	var ids: Array[StringName] = []
	for entry in Game.MINIGAMES:
		ids.append(entry["id"])
		lists.append(before(entry["id"]))
		lists.append(after(entry["id"], true))
		lists.append(after(entry["id"], false))
	for tier in 4:
		lists.append(finale(tier, ids.slice(0, 3)))
	for shots in lists:
		for shot in shots:
			for actor in shot["actors"]:
				var tex: String = actor["tex"]
				if not paths.has(tex):
					paths.append(tex)
	return paths


# --- Riverleap: the river chimes ---------------------------------------------

static func _before_wind_leaf() -> Array[Dictionary]:
	return [
		_shot(1.7, BLUE_HOUR, "The wind died before the dawn did.", _water() + [
			_a(ART + "decor/reed.png", Vector2(44, 188), {"scale": 1.4}),
			_a(ART + "decor/reed.png", Vector2(436, 192), {"scale": 1.4, "delay": 0.1}),
			_a(ART + "wind_leaf/chime.png", Vector2(150, 96), {"scale": 2.5}),
			_a(ART + "wind_leaf/chime.png", Vector2(240, 84), {"scale": 2.5, "delay": 0.1}),
			_a(ART + "wind_leaf/chime.png", Vector2(330, 98), {"scale": 2.5, "delay": 0.2}),
		]),
		_shot(1.7, BLUE_HOUR, "The chimes it wakes to are on the far bank.", _water() + [
			_a(ART + "wind_leaf/leaf.png", Vector2(160, 222),
					{"scale": 1.4, "to": Vector2(178, 222)}),
			_a(ART + "wind_leaf/leaf.png", Vector2(250, 204),
					{"scale": 1.4, "to": Vector2(268, 204)}),
			_a(ART + "wind_leaf/leaf.png", Vector2(340, 216),
					{"scale": 1.4, "to": Vector2(358, 216)}),
			_a(ART + "player/idle_right.png", Vector2(60, 186), {"scale": 1.8}),
			_a(ART + "wind_leaf/chime.png", Vector2(424, 104), {"scale": 2.5}),
		]),
		_shot(1.6, PRE_DAWN, "So somebody crosses, and rings them by hand.", _water() + [
			_a(ART + "wind_leaf/leaf.png", Vector2(180, 216), {"scale": 1.4}),
			_a(ART + "wind_leaf/leaf.png", Vector2(310, 212), {"scale": 1.4}),
			_a(ART + "player/walk_right_1.png", Vector2(180, 176),
					{"scale": 1.8, "to": Vector2(310, 172), "spin": 0.5}),
			_a(ART + "wind_leaf/chime.png", Vector2(424, 104), {"scale": 2.5, "sway": 4.0}),
		], &"chime", 1.0),
	]


static func _after_wind_leaf(met_par: bool) -> Array[Dictionary]:
	if met_par:
		return [
			_shot(2.5, PRE_DAWN, "The river sings the whole length of the valley.", _water() + [
				_a(ART + "wind_leaf/chime.png", Vector2(240, 128),
						{"scale": 3.5, "sway": 7.0}),
				_note(150, 0.0), _note(200, 0.2), _note(280, 0.35),
				_note(330, 0.5), _note(240, 0.65),
			], &"chime", 1.2),
			_shot(2.5, DAWN, "Something up there rolls over and listens.", [
				_hill(238),
				_gift_rising(&"wind_leaf"),
				_a(ART + "village/sun_2.png", Vector2(306, 176),
						{"scale": 1.6, "to": Vector2(306, 162)}),
				_a(ART + "village/glow.png", Vector2(306, 168),
						{"scale": 2.4, "tint": Color(1, 0.9, 0.6, 0.5)}),
			]),
		]
	return [
		_shot(2.5, BLUE_HOUR, "A few notes made it across the water.", _water() + [
			_a(ART + "wind_leaf/chime.png", Vector2(240, 128), {"scale": 3.5, "sway": 3.0}),
			_note(210, 0.1), _note(275, 0.4),
		], &"chime", 0.9),
		_shot(2.5, PRE_DAWN, "Faint is still a sound. It carries.", [
			_hill(238),
			_gift_rising(&"wind_leaf"),
			_a(ART + "village/sun_2.png", Vector2(306, 182), {"scale": 1.4}),
			_note(240, 0.2),
		]),
	]


# --- Hush Meadow: a handful of yesterday -------------------------------------

static func _before_tall_grass() -> Array[Dictionary]:
	return [
		_shot(1.7, DUSK, "Sunpetals keep whatever light they are given.", [
			_band(ART + "tall_grass/grass_1.png", 226),
			_a(ART + "tall_grass/petal.png", Vector2(150, 190), {"scale": 1.6}),
			_a(ART + "tall_grass/petal.png", Vector2(250, 182), {"scale": 1.6, "delay": 0.15}),
			_a(ART + "tall_grass/petal.png", Vector2(340, 194), {"scale": 1.6, "delay": 0.3}),
			_a(ART + "village/glow.png", Vector2(250, 182),
					{"scale": 1.6, "tint": Color(1, 0.92, 0.62, 0.4)}),
		]),
		_shot(1.7, DUSK, "So you pick them as the last of the day goes.", [
			_band(ART + "tall_grass/grass_1.png", 226),
			_a(ART + "player/idle_right.png", Vector2(140, 184),
					{"scale": 1.5, "to": Vector2(190, 184)}),
			_a(ART + "tall_grass/petal.png", Vector2(300, 188),
					{"scale": 1.6, "delay": 0.2}),
			_a(ART + "decor/mist.png", Vector2(240, 206),
					{"scale": 5.0, "tint": Color(0.8, 0.8, 1, 0.35)}),
		]),
		_shot(1.6, BLUE_HOUR, "The meadow birds are still up. Stay in the grass.", [
			_band(ART + "tall_grass/grass_1.png", 226),
			_a(ART + "tall_grass/bird_0.png", Vector2(340, 150),
					{"scale": 1.4, "to": Vector2(300, 158)}),
			_a(ART + "tall_grass/bird_0.png", Vector2(96, 168),
					{"scale": 1.2, "to": Vector2(126, 164), "delay": 0.2}),
			_a(ART + "tall_grass/grass_2.png", Vector2(210, 196), {"scale": 1.4}),
		]),
	]


static func _after_tall_grass(met_par: bool) -> Array[Dictionary]:
	if met_par:
		return [
			_shot(2.5, BLUE_HOUR, "You carry back a whole handful of daylight.", [
				_band(ART + "tall_grass/grass_1.png", 226),
				_a(ART + "player/idle_down.png", Vector2(240, 176), {"scale": 2.0}),
				_a(ART + "village/glow.png", Vector2(240, 168),
						{"scale": 2.4, "tint": Color(1, 0.93, 0.65, 0.6)}),
				_a(ART + "tall_grass/petal.png", Vector2(212, 150),
						{"scale": 1.2, "to": Vector2(212, 132), "fade": "out"}),
				_a(ART + "tall_grass/petal.png", Vector2(268, 154),
						{"scale": 1.2, "to": Vector2(268, 134), "fade": "out", "delay": 0.3}),
			]),
			_shot(2.5, NIGHT, "Enough to remind it what light was for.", [
				_hill(238),
				_gift_rising(&"tall_grass"),
				_a(ART + "village/sun_2.png", Vector2(306, 186), {"scale": 1.5}),
				_a(ART + "village/glow.png", Vector2(306, 186),
						{"scale": 2.6, "tint": Color(1, 0.9, 0.62, 0.5)}),
			]),
		]
	return [
		_shot(2.5, BLUE_HOUR, "Not a full handful. Still warm, though.", [
			_band(ART + "tall_grass/grass_1.png", 226),
			_a(ART + "player/idle_down.png", Vector2(240, 176), {"scale": 2.0}),
			_a(ART + "village/glow.png", Vector2(240, 170),
					{"scale": 1.3, "tint": Color(1, 0.93, 0.65, 0.45)}),
		]),
		_shot(2.5, NIGHT, "The meadow will have more of it tomorrow.", [
			_hill(238),
			_gift_rising(&"tall_grass"),
			_a(ART + "village/sun_2.png", Vector2(306, 190), {"scale": 1.4}),
			_a(ART + "decor/star.png", Vector2(120, 70), {"tint": Color(1, 1, 1, 0.7)}),
			_a(ART + "decor/star.png", Vector2(370, 58), {"tint": Color(1, 1, 1, 0.6)}),
		]),
	]


# --- Echo Hollow: the sun's own name -----------------------------------------

## Walls above, floor below. Without them the lit stones hang in a void and the
## hollow reads as open sky, which is the opposite of what it is.
static func _hollow() -> Array:
	return [_band(ART + "cave/wall.png", 42), _band(ART + "cave/wall.png", 74),
			_band(ART + "cave/floor.png", 214), _band(ART + "cave/floor.png", 246)]


static func _before_cave() -> Array[Dictionary]:
	return [
		_shot(1.7, HOLLOW, "Nobody alive remembers what the sun is called.", _hollow() + [
			_a(ART + "cave/torch_1.png", Vector2(70, 150),
					{"scale": 1.6, "tint": Color(1, 0.8, 0.55, 0.9)}),
			_a(ART + "cave/torch_1.png", Vector2(410, 150),
					{"scale": 1.6, "tint": Color(1, 0.8, 0.55, 0.9), "delay": 0.15}),
			_a(ART + "player/idle_up.png", Vector2(240, 190), {"scale": 1.6}),
		]),
		_shot(1.7, HOLLOW, "The hollow does. One syllable to a stone.", _hollow() + [
			_a(ART + "cave/plate_on_red.png", Vector2(130, 172), {"scale": 1.2}),
			_a(ART + "cave/plate_on_yellow.png", Vector2(200, 158),
					{"scale": 1.2, "delay": 0.25}),
			_a(ART + "cave/plate_on_green.png", Vector2(280, 158),
					{"scale": 1.2, "delay": 0.5}),
			_a(ART + "cave/plate_on_blue.png", Vector2(350, 170),
					{"scale": 1.2, "delay": 0.75}),
			_a(ART + "decor/crystal.png", Vector2(60, 96),
					{"scale": 1.4, "tint": Color(0.7, 0.9, 1, 0.8)}),
			_a(ART + "decor/crystal.png", Vector2(420, 88),
					{"scale": 1.2, "tint": Color(0.7, 0.9, 1, 0.7)}),
		], &"confirm", 0.8),
		_shot(1.6, HOLLOW, "Say them back in order and it hears its name.", _hollow() + [
			_a(ART + "cave/plate_on_purple.png", Vector2(240, 178), {"scale": 1.4}),
			_a(ART + "village/glow.png", Vector2(240, 168),
					{"scale": 2.2, "tint": Color(0.8, 0.7, 1, 0.5)}),
			_a(ART + "player/idle_down.png", Vector2(240, 150),
					{"scale": 1.6, "to": Vector2(240, 158)}),
		]),
	]


static func _after_cave(met_par: bool) -> Array[Dictionary]:
	if met_par:
		return [
			_shot(2.5, HOLLOW, "The hollow says the name, all of it, at once.", _hollow() + [
				_a(ART + "cave/plate_on_red.png", Vector2(110, 178), {"scale": 1.2}),
				_a(ART + "cave/plate_on_yellow.png", Vector2(175, 176),
						{"scale": 1.2, "delay": 0.1}),
				_a(ART + "cave/plate_on_green.png", Vector2(240, 176),
						{"scale": 1.2, "delay": 0.2}),
				_a(ART + "cave/plate_on_blue.png", Vector2(305, 176),
						{"scale": 1.2, "delay": 0.3}),
				_a(ART + "cave/plate_on_purple.png", Vector2(370, 176),
						{"scale": 1.2, "delay": 0.4}),
				_a(ART + "village/glow.png", Vector2(240, 170),
						{"scale": 4.0, "tint": Color(0.85, 0.78, 1, 0.5)}),
			]),
			_shot(2.5, PRE_DAWN, "It goes up the shaft and out over the hill.", [
				_hill(238),
				_gift_rising(&"cave"),
				_a(ART + "village/sun_2.png", Vector2(306, 172),
						{"scale": 1.6, "to": Vector2(306, 164)}),
				_a(ART + "decor/sparkle.png", Vector2(190, 130),
						{"to": Vector2(190, 100), "fade": "out"}),
				_a(ART + "decor/sparkle.png", Vector2(292, 138),
						{"to": Vector2(292, 104), "fade": "out", "delay": 0.4}),
			]),
		]
	return [
		_shot(2.5, HOLLOW, "Half a name. Half is enough to turn a head.", _hollow() + [
			_a(ART + "cave/plate_on_red.png", Vector2(150, 178), {"scale": 1.2}),
			_a(ART + "cave/plate_on_yellow.png", Vector2(240, 176),
					{"scale": 1.2, "delay": 0.2}),
			_a(ART + "cave/plate_off.png", Vector2(330, 176), {"scale": 1.2}),
		]),
		_shot(2.5, BLUE_HOUR, "The rest of it is still down there. It waits.", [
			_hill(238),
			_gift_rising(&"cave"),
			_a(ART + "village/sun_2.png", Vector2(306, 182), {"scale": 1.4}),
		]),
	]


# --- Riverstrike: a clear river to look in -----------------------------------

static func _before_harpoon() -> Array[Dictionary]:
	return [
		_shot(1.7, NIGHT, "The sun cannot see how late it has slept.", _water() + [
			_a(ART + "decor/moon.png", Vector2(390, 74), {"scale": 1.6}),
			_a(ART + "decor/reed.png", Vector2(46, 182), {"scale": 1.4}),
			_a(ART + "decor/reed.png", Vector2(438, 188), {"scale": 1.4, "delay": 0.15}),
			_a(ART + "decor/lilypad.png", Vector2(300, 226), {"scale": 1.4}),
		]),
		_shot(1.7, DEEP, "The river would show it, if the river were clear.", _water() + [
			_a(ART + "harpoon/plastic.png", Vector2(150, 202), {"spin": 0.4}),
			_a(ART + "harpoon/plastic.png", Vector2(280, 228), {"spin": -0.3, "delay": 0.2}),
			_a(ART + "harpoon/plastic.png", Vector2(372, 196), {"spin": 0.5, "delay": 0.35}),
			_a(ART + "decor/lilypad.png", Vector2(70, 218), {"scale": 1.3}),
		]),
		_shot(1.6, DEEP, "Clear it out. The glassfish do the rest.", _water() + [
			_a(ART + "harpoon/launcher.png", Vector2(58, 206), {"scale": 2.6}),
			_a(ART + "harpoon/bolt.png", Vector2(110, 208),
					{"scale": 1.4, "rotation": PI / 2.0, "to": Vector2(300, 208)}),
			_a(ART + "harpoon/fish_1.png", Vector2(356, 214),
					{"scale": 1.4, "to": Vector2(322, 210)}),
		], &"cast", 1.0),
	]


static func _after_harpoon(met_par: bool) -> Array[Dictionary]:
	if met_par:
		return [
			_shot(2.5, DEEP, "Every bottle out. The water goes still and bright.",
					_water(ART + "shared/water_0.png") + [
				_a(ART + "shared/ripple.png", Vector2(200, 208), {"scale": 1.8}),
				_a(ART + "shared/ripple.png", Vector2(330, 228),
						{"scale": 1.4, "delay": 0.4}),
				_a(ART + "decor/sparkle.png", Vector2(150, 198), {"fade": "out"}),
				_a(ART + "decor/sparkle.png", Vector2(368, 206),
						{"fade": "out", "delay": 0.5}),
			]),
			_shot(2.5, DAWN, "The river throws the morning straight back at it.", [
				_hill(238),
				_gift_rising(&"harpoon"),
				_a(ART + "village/sun_2.png", Vector2(306, 152), {"scale": 1.6}),
				_a(ART + "village/glow.png", Vector2(306, 200),
						{"scale": 3.0, "tint": Color(1, 0.88, 0.6, 0.55)}),
			]),
		]
	return [
		_shot(2.5, DEEP, "Cloudy water, but it caught a little light.", _water() + [
			_a(ART + "harpoon/plastic.png", Vector2(346, 214), {"spin": 0.3}),
			_a(ART + "shared/ripple.png", Vector2(190, 206), {"scale": 1.5}),
			_a(ART + "decor/sparkle.png", Vector2(190, 200), {"fade": "out"}),
		]),
		_shot(2.5, BLUE_HOUR, "Enough of a mirror to be worth looking in.", [
			_hill(238),
			_gift_rising(&"harpoon"),
			_a(ART + "village/sun_2.png", Vector2(306, 180), {"scale": 1.4}),
		]),
	]


# --- Acorn Storm: breakfast --------------------------------------------------

static func _before_acorn_storm() -> Array[Dictionary]:
	return [
		_shot(1.7, NIGHT, "The old oak drops its whole year in the dark.", [
			_band(ART + "tall_grass/ground_0.png", 226),
			_a(ART + "village/tree.png", Vector2(240, 130), {"scale": 3.0}),
			_a(ART + "decor/squirrel.png", Vector2(288, 108), {"delay": 0.4}),
		]),
		_shot(1.7, NIGHT, "Most of what falls is acorns, and acorns hurt.", [
			_band(ART + "tall_grass/ground_0.png", 226),
			_a(ART + "acorn_storm/acorn.png", Vector2(140, 60),
					{"to": Vector2(140, 200), "spin": 3.0}),
			_a(ART + "acorn_storm/acorn.png", Vector2(268, 40),
					{"to": Vector2(268, 200), "spin": -2.4, "delay": 0.2}),
			_a(ART + "acorn_storm/acorn.png", Vector2(360, 70),
					{"to": Vector2(360, 200), "spin": 2.8, "delay": 0.4}),
			_a(ART + "player/idle_down.png", Vector2(200, 186), {"scale": 1.5}),
		]),
		_shot(1.6, BLUE_HOUR, "One in ten is sunfruit. That one is breakfast.", [
			_band(ART + "tall_grass/ground_0.png", 226),
			_a(ART + "acorn_storm/sunfruit.png", Vector2(240, 70),
					{"scale": 2.0, "to": Vector2(240, 176)}),
			_a(ART + "village/glow.png", Vector2(240, 140),
					{"scale": 1.6, "tint": Color(1, 0.8, 0.45, 0.55)}),
			_a(ART + "player/idle_up.png", Vector2(240, 200), {"scale": 1.5}),
		]),
	]


static func _after_acorn_storm(met_par: bool) -> Array[Dictionary]:
	if met_par:
		return [
			_shot(2.5, BLUE_HOUR, "Enough sunfruit to get anybody out of bed.", [
				_band(ART + "tall_grass/ground_0.png", 226),
				_a(ART + "acorn_storm/sunfruit.png", Vector2(200, 186), {"scale": 1.6}),
				_a(ART + "acorn_storm/sunfruit.png", Vector2(240, 178),
						{"scale": 1.6, "delay": 0.15}),
				_a(ART + "acorn_storm/sunfruit.png", Vector2(280, 186),
						{"scale": 1.6, "delay": 0.3}),
				_a(ART + "village/glow.png", Vector2(240, 182),
						{"scale": 2.4, "tint": Color(1, 0.82, 0.48, 0.5)}),
			]),
			_shot(2.5, DAWN, "You can smell it from the horizon.", [
				_hill(238),
				_gift_rising(&"acorn_storm"),
				_a(ART + "village/sun_2.png", Vector2(306, 168),
						{"scale": 1.6, "to": Vector2(306, 160)}),
			]),
		]
	return [
		_shot(2.5, NIGHT, "A small breakfast. It is the thought.", [
			_band(ART + "tall_grass/ground_0.png", 226),
			_a(ART + "acorn_storm/sunfruit.png", Vector2(240, 184), {"scale": 1.6}),
			_a(ART + "acorn_storm/acorn.png", Vector2(180, 196)),
			_a(ART + "acorn_storm/acorn.png", Vector2(310, 198), {"delay": 0.2}),
		]),
		_shot(2.5, BLUE_HOUR, "The oak has plenty left. So have you.", [
			_hill(238),
			_gift_rising(&"acorn_storm"),
			_a(ART + "village/sun_2.png", Vector2(306, 182), {"scale": 1.4}),
		]),
	]


# --- Firefly Lantern: a borrowed light ---------------------------------------

static func _before_firefly() -> Array[Dictionary]:
	return [
		_shot(1.7, NIGHT, "Your lantern is nearly out.", [
			_a(ART + "firefly/lantern.png", Vector2(240, 150), {"scale": 2.4}),
			_a(ART + "village/glow.png", Vector2(240, 148),
					{"scale": 1.4, "tint": Color(1, 0.85, 0.5, 0.35),
					"to_scale": 0.9, "fade": "out"}),
		]),
		_shot(1.7, NIGHT, "The fireflies will lend you theirs.", [
			_a(ART + "firefly/mote.png", Vector2(140, 130),
					{"tint": Color(0.9, 1, 0.55, 0.9), "to": Vector2(158, 118)}),
			_a(ART + "firefly/mote.png", Vector2(300, 160),
					{"tint": Color(0.9, 1, 0.55, 0.9), "to": Vector2(286, 146),
					"delay": 0.2}),
			_a(ART + "firefly/mote.png", Vector2(378, 108),
					{"tint": Color(0.9, 1, 0.55, 0.9), "to": Vector2(394, 122),
					"delay": 0.4}),
			_a(ART + "player/idle_right.png", Vector2(200, 190), {"scale": 1.5}),
		]),
		_shot(1.6, NIGHT, "The darker it gets, the more each one is giving.", [
			_a(ART + "firefly/lantern.png", Vector2(240, 158),
					{"scale": 2.4, "to": Vector2(240, 150)}),
			_a(ART + "village/glow.png", Vector2(240, 152),
					{"scale": 1.0, "to_scale": 2.6,
					"tint": Color(0.95, 1, 0.6, 0.55)}),
		]),
	]


static func _after_firefly(met_par: bool) -> Array[Dictionary]:
	if met_par:
		return [
			_shot(2.5, NIGHT, "A borrowed light, held up as high as you can.", [
				_a(ART + "player/idle_up.png", Vector2(240, 186), {"scale": 2.0}),
				_a(ART + "firefly/lantern.png", Vector2(240, 138),
						{"scale": 2.4, "to": Vector2(240, 126)}),
				_a(ART + "village/glow.png", Vector2(240, 132),
						{"scale": 3.2, "tint": Color(0.98, 1, 0.68, 0.6)}),
			]),
			_shot(2.5, PRE_DAWN, "From up there it must look like a small sun.", [
				_hill(238),
				_gift_rising(&"firefly"),
				_a(ART + "village/sun_2.png", Vector2(306, 170),
						{"scale": 1.6, "to": Vector2(306, 162)}),
				_a(ART + "decor/sparkle.png", Vector2(240, 200), {"fade": "out"}),
			]),
		]
	return [
		_shot(2.5, NIGHT, "A small light. Small lights still get seen.", [
			_a(ART + "player/idle_up.png", Vector2(240, 186), {"scale": 2.0}),
			_a(ART + "firefly/lantern.png", Vector2(240, 140), {"scale": 2.2}),
			_a(ART + "village/glow.png", Vector2(240, 138),
					{"scale": 1.5, "tint": Color(0.95, 1, 0.65, 0.4)}),
		]),
		_shot(2.5, BLUE_HOUR, "Hold it up anyway. That is the whole job.", [
			_hill(238),
			_gift_rising(&"firefly"),
			_a(ART + "village/sun_2.png", Vector2(306, 182), {"scale": 1.4}),
		]),
	]


# --- Temple Bell: the dawn bell ----------------------------------------------

static func _before_temple_bell() -> Array[Dictionary]:
	return [
		_shot(1.7, NIGHT, "Nobody rang the dawn bell.", [
			_a(ART + "temple_bell/bell.png", Vector2(240, 130),
					{"scale": 2.0, "tint": Color(0.7, 0.72, 0.82)}),
			_a(ART + "decor/lantern_hang.png", Vector2(120, 90), {"scale": 1.4}),
			_a(ART + "decor/lantern_hang.png", Vector2(360, 84),
					{"scale": 1.4, "delay": 0.2}),
		]),
		_shot(1.7, NIGHT, "That is very probably the whole problem.", [
			_a(ART + "temple_bell/bell.png", Vector2(240, 130),
					{"scale": 2.0, "tint": Color(0.7, 0.72, 0.82), "sway": 2.0}),
			_a(ART + "decor/petal.png", Vector2(160, 60),
					{"to": Vector2(146, 210), "spin": 1.6}),
			_a(ART + "decor/petal.png", Vector2(330, 40),
					{"to": Vector2(346, 210), "spin": -1.4, "delay": 0.3}),
		]),
		_shot(1.6, PRE_DAWN, "So ring it. Morning is not a request.", [
			_a(ART + "temple_bell/bell.png", Vector2(240, 126),
					{"scale": 2.2, "sway": 8.0}),
			_a(ART + "temple_bell/ring.png", Vector2(240, 130),
					{"scale": 1.0, "to_scale": 3.4, "fade": "out"}),
			_a(ART + "player/idle_up.png", Vector2(240, 202), {"scale": 1.5}),
		], &"door", 0.9),
	]


static func _after_temple_bell(met_par: bool) -> Array[Dictionary]:
	if met_par:
		return [
			_shot(2.5, PRE_DAWN, "The valley hears the morning start on time.", [
				_a(ART + "temple_bell/bell.png", Vector2(240, 126),
						{"scale": 2.2, "sway": 9.0}),
				_a(ART + "temple_bell/ring.png", Vector2(240, 130),
						{"scale": 0.8, "to_scale": 4.0, "fade": "out"}),
				_note(150, 0.1), _note(340, 0.3), _note(240, 0.5),
			], &"door", 1.0),
			_shot(2.5, DAWN, "Late, but on time. Both can be true.", [
				_hill(238),
				_gift_rising(&"temple_bell"),
				_a(ART + "village/sun_2.png", Vector2(306, 166),
						{"scale": 1.6, "to": Vector2(306, 156)}),
			]),
		]
	return [
		_shot(2.5, BLUE_HOUR, "Rung late, and a little crooked. Rung.", [
			_a(ART + "temple_bell/bell.png", Vector2(240, 128),
					{"scale": 2.0, "sway": 4.0}),
			_a(ART + "temple_bell/ring.png", Vector2(240, 132),
					{"scale": 0.8, "to_scale": 2.2, "fade": "out"}),
			_note(240, 0.3),
		], &"door", 0.8),
		_shot(2.5, PRE_DAWN, "A bell does not care how well it was struck.", [
			_hill(238),
			_gift_rising(&"temple_bell"),
			_a(ART + "village/sun_2.png", Vector2(306, 180), {"scale": 1.4}),
		]),
	]


# --- Crow Watch: the harvest offering ----------------------------------------

static func _before_crow_watch() -> Array[Dictionary]:
	return [
		_shot(1.7, BLUE_HOUR, "The rice was grown for the sun.", [
			_band(ART + "tall_grass/ground_1.png", 218),
			_band(ART + "tall_grass/ground_1.png", 250),
			_band(ART + "crow_watch/rice_0.png", 206),
			_band(ART + "crow_watch/rice_0.png", 238),
			_a(ART + "decor/scarecrow.png", Vector2(240, 158), {"scale": 2.4}),
			_a(ART + "decor/fence.png", Vector2(66, 192), {"scale": 1.4}),
			_a(ART + "decor/fence.png", Vector2(414, 192), {"scale": 1.4, "delay": 0.15}),
		]),
		_shot(1.7, BLUE_HOUR, "The crows would rather it were grown for them.", [
			_band(ART + "tall_grass/ground_1.png", 218),
			_band(ART + "tall_grass/ground_1.png", 250),
			_band(ART + "crow_watch/rice_0.png", 206),
			_band(ART + "crow_watch/rice_0.png", 238),
			_a(ART + "tall_grass/bird_0.png", Vector2(120, 80),
					{"scale": 1.4, "to": Vector2(160, 150)}),
			_a(ART + "tall_grass/bird_0.png", Vector2(340, 60),
					{"scale": 1.4, "to": Vector2(300, 148), "delay": 0.25}),
		]),
		_shot(1.6, PRE_DAWN, "Nothing is given if nothing is left.", [
			_band(ART + "tall_grass/ground_1.png", 218),
			_band(ART + "tall_grass/ground_1.png", 250),
			_band(ART + "crow_watch/rice_0.png", 206),
			_band(ART + "crow_watch/rice_0.png", 238),
			_a(ART + "player/idle_right.png", Vector2(150, 182),
					{"scale": 1.5, "to": Vector2(230, 182)}),
			_a(ART + "tall_grass/bird_0.png", Vector2(320, 150),
					{"scale": 1.4, "to": Vector2(360, 96), "fade": "out"}),
		]),
	]


static func _after_crow_watch(met_par: bool) -> Array[Dictionary]:
	if met_par:
		return [
			_shot(2.5, PRE_DAWN, "The offering goes out whole.", [
				_band(ART + "tall_grass/ground_1.png", 218),
				_band(ART + "tall_grass/ground_1.png", 250),
				_band(ART + "crow_watch/rice_0.png", 206),
				_band(ART + "crow_watch/rice_0.png", 238),
				_a(ART + "decor/scarecrow.png", Vector2(240, 156), {"scale": 2.4}),
				_a(ART + "village/glow.png", Vector2(240, 200),
						{"scale": 3.4, "tint": Color(1, 0.86, 0.55, 0.45)}),
			]),
			_shot(2.5, DAWN, "A field like that is worth waking up for.", [
				_hill(238),
				_gift_rising(&"crow_watch"),
				_a(ART + "village/sun_2.png", Vector2(306, 166),
						{"scale": 1.6, "to": Vector2(306, 158)}),
			]),
		]
	return [
		_shot(2.5, BLUE_HOUR, "What is left is still an offering.", [
			_band(ART + "tall_grass/ground_1.png", 218),
			_band(ART + "tall_grass/ground_1.png", 250),
			_band(ART + "crow_watch/rice_1.png", 206),
			_band(ART + "crow_watch/rice_1.png", 238),
			_a(ART + "decor/scarecrow.png", Vector2(240, 158), {"scale": 2.4}),
			_a(ART + "tall_grass/bird_0.png", Vector2(390, 120),
					{"scale": 1.2, "to": Vector2(420, 90), "fade": "out"}),
		]),
		_shot(2.5, PRE_DAWN, "It was never about the size of the bowl.", [
			_hill(238),
			_gift_rising(&"crow_watch"),
			_a(ART + "village/sun_2.png", Vector2(306, 182), {"scale": 1.4}),
		]),
	]


# --- the finale --------------------------------------------------------------

## The gifts float up, named. Built from the hand actually dealt, so the ending
## thanks the player for the run they played rather than for a generic three.
static func _gift_shot(gift_ids: Array) -> Dictionary:
	var actors: Array[Dictionary] = []
	var names := PackedStringArray()
	var count: int = maxi(gift_ids.size(), 1)
	var span := 96.0
	var x0 := 240.0 - span * (count - 1) / 2.0
	for i in gift_ids.size():
		var id: StringName = gift_ids[i]
		var entry := Game.definition(id)
		if entry.is_empty():
			continue
		names.append(String(entry.get("gift", entry.get("title", id))))
		actors.append(_a(ART + "ui/card_icon_%s.png" % id,
				Vector2(x0 + span * i, 200), {
					"scale": 2.0,
					"to": Vector2(x0 + span * i, 120),
					"tint": entry["color"],
					"delay": 0.2 * i,
					"fade": "in",
				}))
		actors.append(_a(ART + "decor/sparkle.png",
				Vector2(x0 + span * i, 190), {
					"to": Vector2(x0 + span * i, 110),
					"fade": "out",
					"delay": 0.2 * i + 0.15,
				}))
		actors.append(_a(ART + "village/glow.png",
				Vector2(x0 + span * i, 200), {
					"scale": 1.2,
					"to": Vector2(x0 + span * i, 120),
					"tint": Color(entry["color"].r, entry["color"].g,
							entry["color"].b, 0.45),
					"delay": 0.2 * i,
				}))
	var caption := " + ".join(names) if names.size() > 0 else "everything you had"
	return _shot(2.2, PRE_DAWN, caption, actors)


static func _finale_radiant() -> Array[Dictionary]:
	var rays: Array[Dictionary] = [
		_a(ART + "village/sun_beaming.png", Vector2(240, 150),
				{"scale": 2.0, "to": Vector2(240, 126)}),
	]
	for i in 12:
		var angle := TAU * i / 12.0
		var at := Vector2(240, 132) + Vector2(cos(angle), sin(angle)) * 46.0
		rays.append(_a(ART + "decor/ray.png", at, {
			"rotation": angle + PI / 2.0,
			"scale": 0.8,
			"to": Vector2(240, 132) + Vector2(cos(angle), sin(angle)) * 74.0,
			"tint": Color(1, 0.92, 0.62, 0.9),
			"delay": 0.04 * i,
		}))
	return [
		_shot(1.8, DAWN, "It came up grinning.", [
			_hill(238),
			_a(ART + "village/sun_beaming.png", Vector2(240, 210),
					{"scale": 2.0, "to": Vector2(240, 150)}),
			_a(ART + "village/glow.png", Vector2(240, 190),
					{"scale": 4.0, "tint": Color(1, 0.9, 0.6, 0.7)}),
		], &"complete", 1.25),
		_shot(2.0, GOLD, "The whole valley is warm before you can blink.", rays),
		_shot(2.6, GOLD, "Nobody is sleeping through a morning like that.", [
			_hill(238),
			_a(ART + "village/sun_beaming.png", Vector2(240, 110),
					{"scale": 2.4, "sway": 4.0}),
			_a(ART + "village/glow.png", Vector2(240, 112),
					{"scale": 6.0, "tint": Color(1, 0.92, 0.66, 0.6)}),
			_a(ART + "player/idle_up.png", Vector2(150, 202), {"scale": 1.6}),
		]),
	]


static func _finale_bright() -> Array[Dictionary]:
	return [
		_shot(1.8, DAWN, "It sat up. It had a look at what you brought.", [
			_hill(238),
			_a(ART + "village/sun_1.png", Vector2(240, 198),
					{"scale": 1.8, "to": Vector2(240, 168)}),
			_a(ART + "village/glow.png", Vector2(240, 186),
					{"scale": 3.2, "tint": Color(1, 0.88, 0.58, 0.6)}),
		], &"complete", 1.0),
		_shot(2.0, MORNING, "And decided that would do nicely.", [
			_hill(238),
			_a(ART + "village/sun_0.png", Vector2(240, 160),
					{"scale": 2.0, "to": Vector2(240, 134)}),
			_a(ART + "village/glow.png", Vector2(240, 142),
					{"scale": 4.4, "tint": Color(1, 0.9, 0.62, 0.55)}),
		]),
		_shot(2.6, MORNING, "It usually does. Thank you for the morning.", [
			_hill(238),
			_a(ART + "village/sun_0.png", Vector2(240, 128),
					{"scale": 2.0, "sway": 3.0}),
			_a(ART + "player/idle_up.png", Vector2(150, 202), {"scale": 1.6}),
			_a(ART + "decor/cloud.png", Vector2(90, 92),
					{"scale": 1.6, "to": Vector2(130, 92),
					"tint": Color(1, 0.95, 0.85, 0.5)}),
		]),
	]


static func _finale_gentle() -> Array[Dictionary]:
	return [
		_shot(1.8, PRE_DAWN, "It opened one eye.", [
			_hill(238),
			_a(ART + "village/sun_1.png", Vector2(240, 196),
					{"scale": 1.8, "to": Vector2(240, 182)}),
			_a(ART + "village/glow.png", Vector2(240, 196),
					{"scale": 2.6, "tint": Color(1, 0.84, 0.55, 0.45)}),
		], &"complete", 0.85),
		_shot(2.0, DAWN, "Morning, then. Slow, crooked, but morning.", [
			_hill(238),
			_a(ART + "village/sun_1.png", Vector2(240, 182),
					{"scale": 1.8, "to": Vector2(240, 164)}),
			_a(ART + "village/glow.png", Vector2(240, 178),
					{"scale": 3.4, "tint": Color(1, 0.86, 0.56, 0.5)}),
		]),
		_shot(2.6, DAWN, "Come back. Help it up the rest of the way.", [
			_hill(238),
			_a(ART + "village/sun_1.png", Vector2(240, 160),
					{"scale": 1.8, "sway": 3.0}),
			_a(ART + "player/idle_up.png", Vector2(150, 202), {"scale": 1.6}),
		]),
	]


# --- builders ----------------------------------------------------------------

## `sfx` names a cue in Audio for the moment the shot opens. Used sparingly:
## a sound on every shot would turn a quiet scene into a slot machine, so only
## the beats that are *about* a sound get one.
static func _shot(seconds: float, sky: Array, caption: String, actors: Array,
		sfx: StringName = &"", sfx_pitch: float = 1.0) -> Dictionary:
	var typed: Array[Dictionary] = []
	for actor in actors:
		typed.append(actor)
	return {"seconds": seconds, "sky": sky, "caption": caption, "actors": typed,
			"sfx": sfx, "sfx_pitch": sfx_pitch}


## One sprite. `extra` overrides any of the defaults cutscene.gd reads:
## to, scale, to_scale, tint, fade, sway, spin, rotation, delay, repeat, step.
static func _a(tex: String, at: Vector2, extra: Dictionary = {}) -> Dictionary:
	var actor := {"tex": tex, "at": at}
	actor.merge(extra, true)
	return actor


## A tile repeated across the screen: water, grass, rice. Starts left of the
## frame and runs past the right edge so the seam is never on screen.
static func _band(tex: String, y: float, extra: Dictionary = {}) -> Dictionary:
	var actor := _a(tex, Vector2(16, y), extra)
	actor["repeat"] = 16
	actor["step"] = Vector2(32, 0)
	return actor


## A body of water rather than a stripe: two rows, filling the bottom third, so
## anything placed between y=190 and y=240 is convincingly *in* it.
static func _water(tex: String = ART + "shared/water_1.png") -> Array:
	return [_band(tex, 206), _band(tex, 238)]


## The horizon. Two copies of a 256px silhouette cover 480 with room to spare.
static func _hill(y: float) -> Dictionary:
	var actor := _a(ART + "decor/hill.png", Vector2(128, y))
	actor["repeat"] = 2
	actor["step"] = Vector2(256, 0)
	return actor


## The gift arriving. Without it every game's closing shot is the same sun on
## the same hill; with it the shot says which game you just played.
static func _gift_rising(id: StringName) -> Dictionary:
	var colour: Color = Game.definition(id).get("color", Color.WHITE)
	return _a(ART + "ui/card_icon_%s.png" % id, Vector2(150, 224), {
		"scale": 1.6,
		"to": Vector2(150, 148),
		"fade": "out",
		"delay": 0.4,
		"tint": colour.lerp(Color.WHITE, 0.35),
	})


## A note rising and fading -- the only way to draw a sound.
static func _note(x: float, delay: float) -> Dictionary:
	return _a(ART + "decor/note.png", Vector2(x, 150), {
		"scale": 1.6,
		"to": Vector2(x + 12.0, 74.0),
		"fade": "out",
		"delay": delay,
		"tint": Color(1, 1, 1, 0.9),
	})
