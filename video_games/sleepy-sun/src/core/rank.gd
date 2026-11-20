class_name Rank
extends RefCounted
## The letter a run earns. D through SS, banded over the normalised 0-1000
## score that `MiniGameResult` already carries.
##
## It reads the normalised number rather than the raw score on purpose. Raw
## scores are per-game and unbounded -- Riverleap pays tens of thousands for a
## long run, a fixed-length game pays hundreds -- so a letter cut from them
## would grade the game rather than the player. `normalised` exists precisely
## to put every game on one scale, and until now nothing displayed it.
##
## `MiniGame.normalised_from_duration()` puts par at 500 and twice par at 750,
## so the bands below mean: a par run is a B, a good one an A, a strong one an
## S, and SS is for a run several times par. D is the floor, for a credit that
## barely started.

## Descending, so the first row a score clears is its band.
## [threshold, letter, colour]
const BANDS := [
	[900, "SS", Color(1.00, 0.84, 0.35)],   # gold
	[750, "S",  Color(1.00, 0.95, 0.72)],   # pale gold
	[600, "A",  Color(0.62, 1.00, 0.70)],   # green
	[450, "B",  Color(0.60, 0.86, 1.00)],   # blue
	[250, "C",  Color(0.82, 0.82, 0.92)],   # grey
	[0,   "D",  Color(0.72, 0.64, 0.68)],   # dull
]


## The letter for a normalised 0-1000 score.
static func letter(normalised: int) -> String:
	return String(_band(normalised)[1])


static func colour(normalised: int) -> Color:
	return _band(normalised)[2]


## True when this run's letter beats the best one seen before. Compared by
## BAND rather than by number, so "a new letter" means what the player thinks
## it means and two runs inside the same band do not both claim it.
static func is_new_letter(normalised: int, best_normalised: int) -> bool:
	return index(normalised) < index(best_normalised)


## Position in BANDS, 0 being the best. Exposed because comparing letters as
## strings would put "SS" next to "S" alphabetically and "A" above both.
static func index(normalised: int) -> int:
	for i in BANDS.size():
		if normalised >= int(BANDS[i][0]):
			return i
	return BANDS.size() - 1


static func _band(normalised: int) -> Array:
	return BANDS[index(normalised)]
