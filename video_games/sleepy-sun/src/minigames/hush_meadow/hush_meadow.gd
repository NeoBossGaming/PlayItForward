extends MiniGame
## Hush Meadow -- forage a meadow that is sliding out from under you.
##
## Endless. The run ends when the nerve meter fills.
##
## Two decisions make this game what it is, and everything else follows from
## them.
##
## **The meadow scrolls.** Grass drifts down the screen and off the bottom, so
## the patch you are standing in has a few seconds left in it. Cover is a
## route, not a den. It is also what keeps this game from being Acorn Storm
## with different sprites -- that one is a bounded field you move around
## inside, and so was the parked version of this one.
##
## **Nerve rises always, and only pickups bring it down.** Standing in grass
## nearly freezes the rise; it never lowers it. So hiding buys time and never
## progress, and a player who only hides loses slowly rather than living
## forever -- which is the hole every "cover restores you" stealth design has
## and the reason this one does not work that way.
##
## Those two combine into one loop:
##
##     run to a patch -> hidden, the rise freezes -> dew reveals BECAUSE you
##     are inside -> collect it, nerve drops -> the patch is already sliding
##     off -> cross open ground to the next one, exposed, with a cone sweeping
##     toward you.
##
## Dew appearing only inside cover was in the parked version as a flavour
## bonus, flagged in its header as the important one. Hanging survival on it
## is what makes it true: the cautious route and the greedy route are the same
## route, and there is no safe corner to sit in.
##
## Structurally this is Acorn Storm's loop -- a meter that runs out on its own
## and a pickup that is the only thing holding it back -- which is the part of
## that game that works. What is new is that the pickup is somewhere you have
## to go rather than something that comes to you.

const Z_PLAYER := 10
const Z_PROPS := 6
## Patches sit above the player so blades draw over her: standing in grass has
## to LOOK like standing in grass. Relative z accumulates up the parent chain,
## so the containers below carry none of their own -- see hush_test.gd, which
## resolves this by walking the chain rather than reading these constants back.
const Z_PATCH := 14

## Where the player may walk. Tighter than the viewport so nothing important
## happens against an edge.
const FIELD := Rect2(26, 46, 428, 196)
## Patches are built above this and freed below it.
const SPAWN_ABOVE := 30.0
const DESPAWN_BELOW := 56.0

## --- the curve ---------------------------------------------------------------
## Nothing moves until the meadow is up to speed; see launch_factor().
const LAUNCH_SECONDS := 2.2
const GENTLE_SECONDS := 45.0
const GENTLE_CEILING := 0.28
const STEEP_TAU := 80.0

## Pixels per second the meadow slides. Well under the walk speed at both ends:
## the player must always be able to outrun the ground, or cover stops being
## something they can choose and starts being something that happens to them.
const SCROLL := Vector2(18.0, 52.0)
## The shade layer drifts at a different fraction AND is a different tile size
## (240 against 176), so the two periods never line up. Different size alone
## only makes the grid bigger. hush_test.gd asserts these stay unequal, because
## setting them equal brings the grid straight back and nothing else would
## catch it.
const SHADE_RATE := 0.62

const WALK := 70.0
const SPRINT := 1.75
## A slow human. Subtracted from every reachability answer the director gives.
const REACTION := 0.30

## --- cover -------------------------------------------------------------------
## How far apart, up the meadow, the stands of grass grow. This is where the
## late game comes from: not a meaner bar, but a meadow with less in it and
## further between -- about four patches on the field early and under two
## late.
##
## Density in SPACE, not a count of live patches, and that distinction cost a
## round. Holding a count plants each new patch above the last, so the queue
## stretches hundreds of pixels off the top of the screen and most of the
## quota is somewhere nobody can see: a "target" of seven measured as 2.2
## patches actually on the field, and lowering it to three changed almost
## nothing. A scrolling world is spaced, not counted -- the river works the
## same way.
const PATCH_GAP := Vector2(52.0, 128.0)
## Patches already grown when the game starts, so the first thing a player
## sees is a meadow rather than an empty field filling up.
const SEED_PATCHES := 5
## Candidate placements tried before a patch is planted at the best of them.
const PATCH_ATTEMPTS := 10
## The director will not leave the player with fewer than this many usable
## patches. "Usable" is the whole guarantee: reachable at WALKING pace, still
## on the field when you arrive, and not currently under a bird's eye.
const COVER_FLOOR := 2
## Between rescue plantings, so the floor cannot turn into a hedge springing up
## under the player every frame.
const RESCUE_WAIT := 1.6

## --- birds -------------------------------------------------------------------
## Tried at 7 to steepen the late game and put back to 5. More eyes does make
## the run shorter, but it shortens the FORAGING run and lengthens the hiding
## one -- crossing open ground is what birds punish, so loading them up pays
## the cautious player and undoes the thing this design is for. The late game
## comes from the meadow thinning out instead.
const BIRDS := Vector2(1.0, 5.0)
const BIRD_SPEED := Vector2(23.0, 44.0)
const SPRINT_NOISE_RADIUS := 72.0
## After being spotted, nothing can see you. Long enough to get off the spot.
const MERCY_SECONDS := 1.1
const STUN_SECONDS := 0.45

## --- the nerve meter ---------------------------------------------------------
## Per second, by state. These three numbers are the game's difficulty.
## Deliberately NOT the thing that gets much worse. Difficulty here is more
## birds, faster patrols and cover that is further away -- all of which the
## player can see and play against. A bar that simply drains faster is
## difficulty you cannot do anything about, and this game already ends on one.
## The low end buys the gentle opening: at 0.030 a player who never touched the
## controls was done in 30 seconds, against 70-94 for the other two games, and
## a cabinet that takes a credit and gives half a minute is the thing this
## project keeps saying it will not ship.
##
## Note what the two ends do to the value of cover. Early, hiding is worth
## about 1.4x standing in the open; late it is worth 4.4x. Cover mattering
## MORE as the meadow runs out of it is the shape this game wants, and it
## falls out of these two numbers rather than needing a rule of its own.
const NERVE_OPEN := Vector2(0.022, 0.070)
const NERVE_SEEN := 0.42
## Not zero, and not nearly zero either. At 0.004 a bot that simply rode one
## patch down, crossed to the next and never went looking for anything lasted
## 145 seconds -- a safe corner, which is the hole this whole design exists to
## avoid. At 0.016 perfect hiding is worth about a minute, which is a delay.
const NERVE_HIDDEN := 0.016
## Raised with DEW_CHANCE falling, so the meadow's total supply per second is
## roughly unchanged -- what moved is that it now arrives in fewer, bigger
## pieces that have to be gone to.
const DEW_CALM := 0.42
## Petals lie in the OPEN, so this is the whole risk-for-reward line: the
## calmest way to play pays the least. Raised once, deliberately, because it
## is the one number that rewards foraging without also rewarding hiding --
## a player sitting in grass never walks over a petal.
const PETAL_CALM := 0.09
## The worst thing that can happen, and still not instant death: about six of
## these fills the meter on its own. At 0.22 it was four, which on a game
## whose whole verb is crossing open ground punished the player for playing
## it -- the bots were losing more to being seen than to the meadow.
const SPOTTED_NERVE := 0.18

## --- pickups -----------------------------------------------------------------
## Of patches that carry one, and deliberately NOT most of them. At 0.85 every
## patch was worth entering, so the nearest patch was always the right patch
## and there was no foraging decision to make. Just over half, with the rest
## bare, is what turns "which cover" into a choice -- and the choice only
## exists because a patch holding dew shimmers; see MeadowPatch.mark_dew().
const DEW_CHANCE := 0.55
const PETALS := Vector2(4.0, 6.0)
const PICKUP_RADIUS := 15.0
const GOLD_RADIUS := 20.0
## How close a bird's eye was when a pickup was taken.
const NERVE_CLOSE := 30.0
const NERVE_NEAR := 60.0

## --- scoring -----------------------------------------------------------------
const SCORE_SPOTTED := -100
const SCORE_PER_SECOND := Vector2(5.0, 22.0)
## A good run. Endless, so this is a DURATION -- see normalised_score().
##
## **Any change to how long a run lasts has to move this too**, or the letter
## on the results card silently regrades everybody: at par 75 a strong 90s run
## in the last game came out a C, which reads as the rank being broken rather
## than as the game being hard. Set from the measured table rather than
## guessed -- competent bots land either side of two minutes, so a two-minute
## run is a B and four minutes is an S.
const PAR_SECONDS := 120.0

const BIRD_SCENE := preload("res://src/minigames/hush_meadow/bird.tscn")
const PICKUP_SCENE := preload("res://src/minigames/hush_meadow/pickup.tscn")

@onready var _player: TopDownPlayer = $Player
@onready var _hud: HUD = $HUD
@onready var _camera: GameCamera = $Camera
@onready var _ground: ScrollingTexture = $World/Ground
@onready var _shade: ScrollingTexture = $World/Shade
@onready var _patches_root: Node2D = $Patches
@onready var _props_root: Node2D = $Props
@onready var _pickups_root: Node2D = $Pickups
@onready var _birds_root: Node2D = $Birds

var _rng := RandomNumberGenerator.new()

var _intensity: float = 0.0
var _nerve: float = 0.0
var _survived: float = 0.0
var _survival_score: float = 0.0
var _stun: float = 0.0
var _mercy: float = 0.0
var _ending: bool = false

var _patches: Array[MeadowPatch] = []
var _birds: Array[PatrolBird] = []
var _blockers: Array[Rect2] = []

var _concealed: bool = false
var _watched: bool = false

var _score: int = 0
var _dew: int = 0
var _petals: int = 0
var _spotted: int = 0
var _best_nerve: int = 1
## Counted rather than asserted away: if the director ever cannot find a
## placement that keeps the cover floor, the suite wants to know how often.
var _crowded_placements: int = 0
var _rescue_wait: float = 0.0
## Seconds of play at which this run's prize appears, or -1 for a run without
## one. See src/core/golden.gd.
var _golden_at: float = -1.0
var _goldens: int = 0
var _gold_live: MeadowPickup = null


func _ready() -> void:
	_rng.randomize()
	# Below centre, so there is more meadow ahead of her than behind -- and
	# high enough to clear the intro card's caption line, which at FIELD.end.y
	# - 40 ran straight through her. That exact complaint was filed against
	# the last game's card and it is the same 200px row of text.
	_player.position = Vector2(FIELD.get_center().x,
			FIELD.position.y + FIELD.size.y * 0.60)
	_player.speed = WALK
	_player.sprint_multiplier = SPRINT
	_player.can_sprint = true
	_player.z_index = Z_PLAYER
	_player.stamina_changed.connect(_hud.set_stamina)
	# stamina_changed only fires when the meter moves, so the bar would be
	# invisible until the first sprint without this.
	_hud.set_stamina(1.0, false)
	_player.freeze()

	_hud.reset_score(0)
	_hud.hide_lives()
	_seed_meadow()
	_refresh_bar()

	# No shell in front of it for now, so the game starts itself -- but only
	# when it really is the scene being played. The soak suite instances it as
	# a child and drives begin() itself, and must not get a card or a scene
	# reload out of the bargain.
	if get_tree().current_scene == self:
		finished.connect(_on_run_finished)
		await get_tree().process_frame
		var card := HushCard.new()
		add_child(card)
		await card.play()
		begin()


func control_hint() -> String:
	return "STICK  move      BUTTON  sprint"


func begin() -> void:
	super.begin()
	_player.unfreeze()
	_hud.toast("KEEP LOW", Color(0.72, 1.0, 0.78), 1.2)
	_golden_at = Golden.roll()


func _process(delta: float) -> void:
	super._process(delta)
	if not running:
		return

	_advance(delta)
	_scroll_world(delta)
	_tick_stun(delta)
	_player.position = _player.position.clamp(FIELD.position, FIELD.end)
	_update_concealment()
	_update_birds(delta)
	if _ending:
		return
	_tick_patches(delta)
	_tick_pickups()
	_tick_golden()
	_tick_nerve(delta)
	_refresh_bar()


func _advance(delta: float) -> void:
	_intensity = intensity_at(play_time())
	_camera.set_intensity(_intensity)
	if not sequence_started():
		return
	_survived += delta
	_survival_score += lerpf(SCORE_PER_SECOND.x, SCORE_PER_SECOND.y, _intensity) * delta
	_hud.set_timer(_survived)
	_hud.set_score(_current_score())


## --- the world moves ---------------------------------------------------------

## Vertical spacing between stands of grass at the current pressure.
func patch_gap() -> float:
	return lerpf(PATCH_GAP.x, PATCH_GAP.y, _intensity)


func scroll_speed() -> float:
	return lerpf(SCROLL.x, SCROLL.y, _intensity) * launch_factor()


## Everything that is part of the meadow travels together. The player does not:
## she is the one thing standing still while the ground leaves.
func _scroll_world(delta: float) -> void:
	var speed := scroll_speed()
	# Driven through `scroll` rather than add_offset() so ScrollingTexture wraps
	# the offset for us; nudging it by hand grows the region rect without bound
	# over a long run.
	_ground.scroll.y = speed
	_shade.scroll.y = speed * SHADE_RATE

	var step := Vector2(0.0, speed * delta)
	if step.y <= 0.0:
		return
	for patch in _patches:
		patch.position += step
	for child in _props_root.get_children():
		(child as Node2D).position += step
	for i in _blockers.size():
		_blockers[i].position += step
	for child in _pickups_root.get_children():
		(child as Node2D).position += step
	for bird in _birds:
		bird.drift(step)


## --- cover -------------------------------------------------------------------

func _update_concealment() -> void:
	var hidden := patch_at(_player.position) != null
	if hidden != _concealed:
		_concealed = hidden
		_player.set_concealed(hidden)
	# Grass is safety, and safety is slow. Crossing open ground is the risk,
	# and it is also the only way to travel at any speed.
	_player.speed = WALK * (0.72 if hidden else 1.0)


func patch_at(point: Vector2) -> MeadowPatch:
	for patch in _patches:
		if patch.hides(point):
			return patch
	return null


## Seconds for the player to walk from `from` onto a patch that is itself
## sliding down the screen at `speed`. Solved as an interception rather than a
## straight distance, because the patch is moving TOWARD a player below it and
## away from one above it, and treating it as stationary is wrong in both
## directions. INF if she cannot catch it at all.
static func intercept_time(from: Vector2, target: Vector2, speed: float,
		walk: float) -> float:
	var d := target - from
	if walk <= 0.0:
		return INF
	var a := speed * speed - walk * walk
	var b := 2.0 * d.y * speed
	var c := d.dot(d)
	if absf(a) < 0.0001:
		if absf(b) < 0.0001:
			return 0.0 if c <= 0.0001 else INF
		var linear := -c / b
		return linear if linear >= 0.0 else INF
	var disc := b * b - 4.0 * a * c
	if disc < 0.0:
		return INF
	var root := sqrt(disc)
	# Both roots spelled out rather than looped over a literal: a bare [a, b]
	# is an untyped Array and everything built from it stops type-inferring,
	# which takes the whole script down at parse time.
	var first := (-b + root) / (2.0 * a)
	var second := (-b - root) / (2.0 * a)
	var best := INF
	if first >= 0.0:
		best = first
	if second >= 0.0 and second < best:
		best = second
	return best


## Can the player get into this patch, in time, without walking under an eye.
## The guarantee the director keeps, in one function so there is exactly one
## definition of it in the game.
func patch_is_usable(patch: MeadowPatch, from: Vector2, speed: float) -> bool:
	var reach := intercept_time(from, patch.position, speed, WALK)
	if not is_finite(reach):
		return false
	if reach + REACTION > patch.life_left(speed, FIELD.end.y):
		return false
	for bird in _birds:
		if bird.sees_point(patch.position):
			return false
	return true


func usable_patches(from: Vector2) -> int:
	var speed := scroll_speed()
	var count := 0
	for patch in _patches:
		if patch_is_usable(patch, from, speed):
			count += 1
	return count


func _tick_patches(delta: float) -> void:
	_rescue_wait = maxf(_rescue_wait - delta, 0.0)
	for i in range(_patches.size() - 1, -1, -1):
		if _patches[i].position.y > FIELD.end.y + DESPAWN_BELOW:
			_patches[i].queue_free()
			_patches.remove_at(i)

	# Grow another whenever the highest one has come far enough down.
	var gap := patch_gap()
	var highest := INF
	for patch in _patches:
		highest = minf(highest, patch.position.y)
	if not is_finite(highest) or highest > FIELD.position.y - SPAWN_ABOVE:
		_plant_patch(false)

	# And then the floor, checked every frame rather than only while topping
	# up -- which is the version that shipped first and does not work. Late on
	# the meadow holds three patches, so the quota is MET while all three can
	# be behind her, under an eye, or about to go over the edge: the count is
	# fine and there is still nowhere to go. Measured at a 2.03s dead end.
	if _rescue_wait <= 0.0 and usable_patches(_player.position) < COVER_FLOOR:
		_plant_patch(true)
		_rescue_wait = RESCUE_WAIT


## The director's one real decision. A patch always goes in -- the meadow
## cannot simply stop growing grass -- but WHERE is chosen rather than thrown
## down and hoped over, which is how both other games keep their own version of
## "never corner the player".
func _plant_patch(rescue: bool) -> void:
	# Above whatever is already highest, so patches cannot stack on each other.
	var highest := FIELD.position.y - SPAWN_ABOVE
	for patch in _patches:
		highest = minf(highest, patch.position.y)
	var y := minf(highest, FIELD.position.y - SPAWN_ABOVE) \
			- patch_gap() * _rng.randf_range(0.82, 1.18)
	if rescue:
		# Just over the top edge rather than above everything else, or the
		# rescue is itself half a meadow away and arrives too late to be one.
		y = FIELD.position.y - SPAWN_ABOVE * 0.5
	var speed := scroll_speed()
	var inset := MeadowPatch.PATCH_HALF.x + 6.0
	var low := FIELD.position.x + inset
	var high := FIELD.end.x - inset
	var x := 0.0

	if rescue or usable_patches(_player.position) < COVER_FLOOR:
		# Nothing on the field is gettable, so this one goes straight above her
		# and comes down onto her -- the one placement that cannot fail.
		#
		# Counted rather than asserted away: a flood of these would mean the
		# meadow has grown too sparse to play and the floor is propping the
		# game up rather than protecting the player, which passes a cornering
		# check while breaking the game.
		_crowded_placements += 1
		x = clampf(_player.position.x, low, high)
	else:
		var best := -INF
		for attempt in PATCH_ATTEMPTS:
			var candidate := _rng.randf_range(low, high)
			var probe := MeadowPatch.new()
			probe.position = Vector2(candidate, y)
			var score := 10.0 if patch_is_usable(probe, _player.position, speed) else 0.0
			# Then spread: prefer the placement furthest from the nearest
			# existing patch, so cover is distributed across the meadow instead
			# of clustering into one corner and leaving the rest bare.
			var nearest := INF
			for other in _patches:
				nearest = minf(nearest, probe.position.distance_to(other.position))
			probe.free()
			if is_finite(nearest):
				score += minf(nearest, 160.0) / 160.0
			if score > best:
				best = score
				x = candidate

	var patch := MeadowPatch.build(_rng, Vector2(x, y))
	patch.z_index = Z_PATCH
	_patches_root.add_child(patch)
	_patches.append(patch)

	if _rng.randf() < DEW_CHANCE:
		_tuck(patch, MeadowPickup.Kind.DEW)
		patch.mark_dew()


## --- pickups -----------------------------------------------------------------

## Dew is parented to the patch holding it, so it scrolls with the grass
## without pickup.gd needing to know the meadow moves.
func _tuck(patch: MeadowPatch, kind: MeadowPickup.Kind) -> MeadowPickup:
	var pickup: MeadowPickup = PICKUP_SCENE.instantiate()
	pickup.kind = kind
	pickup.patch = patch
	# Anywhere in the patch, not near its middle. Tucked within 12px of centre
	# it sat inside the pickup radius of a player simply standing there, so
	# every dew collected itself and hiding paid as well as foraging. Spread
	# across the patch it has to be walked to -- and one near the edge has to
	# be walked to from the open.
	var reach := MeadowPatch.PATCH_HALF - Vector2(8.0, 8.0)
	pickup.position = Vector2(
		_rng.randf_range(-reach.x, reach.x), _rng.randf_range(-reach.y, reach.y))
	patch.add_child(pickup)
	return pickup


func _tick_pickups() -> void:
	for patch in _patches:
		# Asked of each patch rather than compared against the one patch_at()
		# happens to return. Patches overlap, and patch_at() answers with the
		# first match -- so a dew in the second one stayed invisible while the
		# player stood squarely inside it, which is the single rule this game
		# is built on failing silently wherever two stands of grass touch.
		var inside := patch.hides(_player.position)
		for child in patch.get_children():
			var dew := child as MeadowPickup
			if dew == null:
				continue
			if not dew.revealed:
				# The rule the whole game hangs on: it is not there until you
				# are. Cover is somewhere to GO.
				if inside:
					dew.reveal()
				continue
			var radius := GOLD_RADIUS if dew.kind == MeadowPickup.Kind.GOLD \
					else PICKUP_RADIUS
			if dew.global_position.distance_to(_player.position) < radius:
				_collect(dew)

	for child in _pickups_root.get_children():
		var petal := child as MeadowPickup
		if petal == null:
			continue
		if petal.position.y > FIELD.end.y + DESPAWN_BELOW:
			petal.queue_free()
			continue
		if petal.position.distance_to(_player.position) < PICKUP_RADIUS:
			_collect(petal)

	var want := int(round(lerpf(PETALS.x, PETALS.y, _intensity)))
	while _pickups_root.get_child_count() < want:
		_scatter_petal()


func _scatter_petal() -> void:
	var petal: MeadowPickup = PICKUP_SCENE.instantiate()
	petal.kind = MeadowPickup.Kind.PETAL
	petal.position = Vector2(
		_rng.randf_range(FIELD.position.x + 14.0, FIELD.end.x - 14.0),
		_rng.randf_range(FIELD.position.y - SPAWN_ABOVE, FIELD.position.y + 30.0))
	_pickups_root.add_child(petal)


func _collect(pickup: MeadowPickup) -> void:
	var at := pickup.global_position
	if pickup.patch != null and is_instance_valid(pickup.patch):
		pickup.patch.clear_mark()
	if pickup.kind == MeadowPickup.Kind.GOLD:
		_goldens += 1
		_gold_live = null
		Golden.celebrate(self, at, _camera)
		pickup.queue_free()
		return

	var nerve := _nerve_multiplier(at)
	_best_nerve = maxi(_best_nerve, nerve)
	var gained := pickup.value() * nerve
	_score += gained

	if pickup.kind == MeadowPickup.Kind.DEW:
		_dew += 1
		_nerve = maxf(_nerve - DEW_CALM, 0.0)
	else:
		_petals += 1
		_nerve = maxf(_nerve - PETAL_CALM, 0.0)

	Audio.sfx(&"pickup", 1.0 + 0.12 * nerve)
	pop(at, gained, nerve, "NERVE" if nerve > 1 else pickup.label())
	_hud.set_multiplier(nerve)
	_hud.set_score(_current_score())
	pickup.queue_free()


## How close the nearest bird's eye was when it was taken. The greed line: the
## calmest place to forage pays the least.
func _nerve_multiplier(at: Vector2) -> int:
	var closest := INF
	for bird in _birds:
		closest = minf(closest, bird.global_position.distance_to(at))
	if closest <= PatrolBird.VISION_RANGE + NERVE_CLOSE:
		return 3
	if closest <= PatrolBird.VISION_RANGE + NERVE_NEAR:
		return 2
	return 1


## --- the rare golden ---------------------------------------------------------

## A gift, not a dexterity test. It goes into the patch with the most life left
## that she can already reach, and the patch is marked so she knows WHICH one
## -- "something bright appeared and I could not get to it" is a worse
## non-event than never seeing one.
func _tick_golden() -> void:
	if _golden_at < 0.0 or play_time() < _golden_at or _gold_live != null:
		return
	_golden_at = -1.0
	var speed := scroll_speed()
	var best: MeadowPatch = null
	var best_life := -INF
	for patch in _patches:
		if not patch_is_usable(patch, _player.position, speed):
			continue
		var life := patch.life_left(speed, FIELD.end.y)
		if life > best_life:
			best_life = life
			best = patch
	if best == null:
		return
	_gold_live = _tuck(best, MeadowPickup.Kind.GOLD)
	best.mark_prize()
	Audio.sfx(&"chime", 0.8)
	_hud.toast("SOMETHING GLEAMS", Color(1.0, 0.88, 0.5), 1.3)


## --- birds -------------------------------------------------------------------

func _update_birds(delta: float) -> void:
	_mercy = maxf(_mercy - delta, 0.0)

	for i in range(_birds.size() - 1, -1, -1):
		if _birds[i].global_position.y > FIELD.end.y + DESPAWN_BELOW + 20.0:
			_birds[i].queue_free()
			_birds.remove_at(i)

	var want := int(round(lerpf(BIRDS.x, BIRDS.y, _intensity)))
	while _birds.size() < want:
		_launch_bird()

	# Computed from the same callable the birds themselves read, so what the
	# cone shows and what the meter does can never drift apart.
	_watched = false
	for bird in _birds:
		if _visible_from(bird.global_position, bird.facing):
			_watched = true
			break

	if _player.sprinting:
		for bird in _birds:
			if bird.global_position.distance_to(_player.position) < SPRINT_NOISE_RADIUS:
				bird.investigate(_player.position)


func _launch_bird() -> void:
	var bird: PatrolBird = BIRD_SCENE.instantiate()
	var y := FIELD.position.y - _rng.randf_range(16.0, 70.0)
	# Crossing patrols, so a bird sweeps the lane the player has to walk
	# through rather than guarding one spot. The lane is the threat.
	var left := FIELD.position.x + _rng.randf_range(10.0, 60.0)
	var right := FIELD.end.x - _rng.randf_range(10.0, 60.0)
	if _rng.randf() < 0.5:
		bird.waypoints = PackedVector2Array([Vector2(left, y), Vector2(right, y)])
	else:
		bird.waypoints = PackedVector2Array([Vector2(right, y), Vector2(left, y)])
	bird.speed = lerpf(BIRD_SPEED.x, BIRD_SPEED.y, _intensity) \
			* _rng.randf_range(0.85, 1.15)
	bird.can_see = _visible_from
	bird.spotted_player.connect(_on_bird_spotted.bind(bird))
	_birds_root.add_child(bird)
	_birds.append(bird)


## Given to every bird as its `can_see`, so there is one definition of "visible"
## in the game and the drawn cone cannot disagree with what the bird knows.
func _visible_from(from: Vector2, facing: Vector2) -> bool:
	if _concealed or _mercy > 0.0 or not running or _ending:
		return false
	var to_player := _player.position - from
	var distance := to_player.length()
	if distance > PatrolBird.VISION_RANGE or distance < 0.01:
		return false
	if absf(facing.angle_to(to_player)) > PatrolBird.VISION_HALF_ANGLE:
		return false
	return not _line_blocked(from, _player.position)


## Sampled line of sight against rocks and hedges. Cheaper than raycasts and
## precise enough at this scale, which keeps the Pi budget free.
func _line_blocked(from: Vector2, to: Vector2) -> bool:
	const SAMPLES := 8
	for i in range(1, SAMPLES):
		var point := from.lerp(to, float(i) / SAMPLES)
		for blocker in _blockers:
			if blocker.has_point(point):
				return true
	return false


## Being seen costs a lot and ends nothing. The run ends when the meter fills,
## so one mistake is expensive and three in a row are fatal -- which is the
## shape a cabinet wants, rather than a stranger losing to a bird they never
## saw thirty seconds in.
func _on_bird_spotted(bird: PatrolBird) -> void:
	if _mercy > 0.0 or not running or _ending:
		bird.reset()
		return
	_spotted += 1
	_mercy = MERCY_SECONDS
	_stun = STUN_SECONDS
	_nerve = minf(_nerve + SPOTTED_NERVE, 1.0)
	_score += SCORE_SPOTTED
	Audio.sfx(&"spotted")
	Juice.flash(self, Color(1, 0.35, 0.3, 0.4))
	_camera.kick(0.8)
	pop_on_player(SCORE_SPOTTED, "SPOTTED")
	_hud.set_score(_current_score())
	_player.freeze()

	var swoop := create_tween()
	swoop.tween_property(bird, "global_position", _player.position, 0.26) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	swoop.tween_callback(bird.reset)


func _tick_stun(delta: float) -> void:
	if _stun <= 0.0:
		return
	_stun = maxf(_stun - delta, 0.0)
	if _stun <= 0.0 and running and not _ending:
		_player.unfreeze()


## --- the nerve meter ---------------------------------------------------------

func _tick_nerve(delta: float) -> void:
	if not sequence_started():
		return
	var rise := 0.0
	if _watched:
		rise = NERVE_SEEN
	elif _concealed:
		rise = NERVE_HIDDEN
	else:
		rise = lerpf(NERVE_OPEN.x, NERVE_OPEN.y, _intensity)
	_nerve = clampf(_nerve + rise * delta, 0.0, 1.0)
	if _nerve >= 1.0:
		_flush()


## Fed 1 - nerve, so a draining bar means trouble in every game on the cabinet.
## A bar that fills to mean "worse" would be the one meter here that runs the
## other way, and nobody reads the icon in a panic.
func _refresh_bar() -> void:
	var calm := 1.0 - _nerve
	var tint := Color(0.55, 0.88, 0.62)
	if _nerve > 0.5:
		tint = Color(0.95, 0.78, 0.38).lerp(Color(1.0, 0.42, 0.38),
				clampf((_nerve - 0.5) / 0.4, 0.0, 1.0))
	_hud.set_meter(calm, &"nerve", tint)
	# Felt at the edge of vision rather than read as a sentence -- nobody reads
	# a sentence while panicking.
	_hud.set_alarm(1.0 if _nerve > 0.78 else 0.0)


func _current_score() -> int:
	return maxi(_score + int(_survival_score), 0)


## --- the curve and the launch ------------------------------------------------

static func intensity_at(seconds: float) -> float:
	return MiniGame.curve(seconds, GENTLE_SECONDS, GENTLE_CEILING, STEEP_TAU)


## 0 at the gun, 1 once the meadow is sliding at its opening pace.
func launch_factor() -> float:
	return smoothstep(0.0, LAUNCH_SECONDS, elapsed)


## Seconds of actual play. The meadow is still getting going before this, so
## the difficulty curve measures from the moment the game really starts --
## otherwise the gentle opening is two seconds short.
func play_time() -> float:
	return maxf(elapsed - LAUNCH_SECONDS, 0.0)


func sequence_started() -> bool:
	return elapsed >= LAUNCH_SECONDS


## --- the end -----------------------------------------------------------------

func _flush() -> void:
	if _ending:
		return
	_ending = true
	_nerve = 1.0
	_refresh_bar()
	_hud.set_multiplier(1)
	_hud.toast("THE FLOCK TAKES THE MEADOW", Color(1, 0.55, 0.45), 1.6)
	Audio.sfx(&"complete", 0.6)
	_camera.kick(1.0)
	_player.freeze()
	for bird in _birds:
		bird.investigate(_player.position)
	await Wait.on(self, 1.3)
	if is_finished():
		return
	var total := _current_score()
	_hud.set_score(total)
	finish(total, {
		"goldens": _goldens,
		"dew": _dew,
		"petals": _petals,
		"spotted": _spotted,
		"nerve": _best_nerve,
		"survived": int(_survived),
		"crowded": _crowded_placements,
	})


## Endless, so the comparable number is how long you kept your nerve, not the
## points -- two endless games compared on points compare their scoring rates
## rather than their players.
func normalised_score(_raw: int) -> int:
	return normalised_from_duration(_survived, PAR_SECONDS)


## --- the meadow at the gun ---------------------------------------------------

## Enough cover already on screen that the first thing a player sees is a
## meadow rather than an empty field filling up.
func _seed_meadow() -> void:
	for i in SEED_PATCHES:
		var inset := MeadowPatch.PATCH_HALF.x + 6.0
		var patch := MeadowPatch.build(_rng, Vector2(
			_rng.randf_range(FIELD.position.x + inset, FIELD.end.x - inset),
			_rng.randf_range(FIELD.position.y, FIELD.end.y - 20.0)))
		patch.z_index = Z_PATCH
		_patches_root.add_child(patch)
		_patches.append(patch)
		if _rng.randf() < DEW_CHANCE:
			_tuck(patch, MeadowPickup.Kind.DEW)
			patch.mark_dew()

	for i in 3:
		var prop := Sprite2D.new()
		prop.texture = load("res://assets/game/hush_meadow/%s.png"
				% ("hedge" if _rng.randf() < 0.5 else "rock"))
		prop.position = Vector2(
			_rng.randf_range(FIELD.position.x + 30.0, FIELD.end.x - 30.0),
			_rng.randf_range(FIELD.position.y, FIELD.end.y))
		prop.z_index = Z_PROPS
		_props_root.add_child(prop)
		_blockers.append(Rect2(prop.position - Vector2(13, 10), Vector2(26, 20)))

	for i in int(PETALS.x):
		_scatter_petal()


## Stands in for the shell while it is parked: results, then straight back in.
func _on_run_finished(result: MiniGameResult) -> void:
	var best := Save.best(id)
	var best_rank := Save.best_normalised(id)
	Save.submit(id, result.score, result.normalised,
			int(result.stats.get("goldens", 0)))
	var card := RunCard.new()
	add_child(card)
	var shown_at := Time.get_ticks_msec()
	card.replay.connect(func() -> void:
		StartCard.note_idle(Time.get_ticks_msec() - shown_at)
		get_tree().reload_current_scene())
	var held := int(result.stats.get("survived", 0))
	card.show_run("HUSH MEADOW", result.score, [
		["kept nerve", "%d:%02d" % [held / 60, held % 60]],
		["dew", "%d" % int(result.stats.get("dew", 0))],
		["best nerve", "x%d" % maxi(int(result.stats.get("nerve", 0)), 1)],
		["spotted", "%d" % int(result.stats.get("spotted", 0))],
	] + _golden_row(result), best, result.normalised, best_rank)


## Only shown when there is one: a row reading "golden 0" on every ordinary run
## would turn the rare thing into a thing you are missing.
func _golden_row(result: MiniGameResult) -> Array:
	var count := int(result.stats.get("goldens", 0))
	if count <= 0:
		return []
	return [["golden dew", "%d" % count]]
