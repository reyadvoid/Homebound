extends Node2D

var center = Vector2(300, 300)
var player_radius = 80.0
var player_angle = 0.0
var angular_speed = 2.6
var player_pos = Vector2.ZERO
var facing_dir = 1.0
var ring_speed = 60.0
var gap_width = 0.6
var running = true
var game_started = false
var rings = []
var spawn_timer = 0.0
var spawn_interval = 1.3
var trail_points = []
var trail_max_length = 28

var ending_phase = ""
var ending_timer = 0.0
var burst_start_pos = Vector2.ZERO
var burst_stretch = 0.0
var flash_alpha = 0.0

var earth_rotation = 0.0
var earth_rotation_speed = 0.5
var earth_continents = [
	{ "angle": 0.0, "y": -20, "size": 16 },
	{ "angle": 1.4, "y": 10, "size": 12 },
	{ "angle": 2.8, "y": -5, "size": 14 },
	{ "angle": 4.2, "y": 20, "size": 10 },
	{ "angle": 5.5, "y": 0, "size": 13 },
]

var stages = [
	{ "name": "Big Bang", "ring_type": "out", "rings_to_pass": 3, "color": Color(1, 1, 1) },
	{ "name": "Primordial Plasma", "ring_type": "in", "rings_to_pass": 4, "color": Color(0.9, 0.3, 0.1) },
	{ "name": "Recombination", "ring_type": "in", "rings_to_pass": 3, "color": Color(0.9, 0.8, 0.4) },
	{ "name": "The Dark Ages", "ring_type": "in", "rings_to_pass": 4, "color": Color(1, 1, 1), "low_visibility": true },
	{ "name": "First Starlight", "ring_type": "in", "rings_to_pass": 3, "color": Color(0.6, 0.8, 1.0) },
	{ "name": "Protogalaxy", "ring_type": "in", "rings_to_pass": 3, "color": Color(0.3, 0.6, 0.65) },
	{ "name": "Nebula", "ring_type": "in", "rings_to_pass": 3, "color": Color(0.75, 0.5, 0.8) },
	{ "name": "Star Cluster", "ring_type": "in", "rings_to_pass": 4, "color": Color(0.8, 0.9, 1.0) },
	{ "name": "Supernova", "ring_type": "out", "rings_to_pass": 3, "color": Color(1.0, 0.5, 0.15) },
	{ "name": "Neutron Star", "ring_type": "in", "rings_to_pass": 5, "color": Color(0.7, 0.85, 1.0) },
	{ "name": "Pulsar", "ring_type": "in", "rings_to_pass": 4, "color": Color(0.6, 0.75, 1.0) },
	{ "name": "Black Hole", "ring_type": "in", "rings_to_pass": 6, "color": Color(0.03, 0.03, 0.05) },
	{ "name": "Quasar", "ring_type": "in", "rings_to_pass": 5, "color": Color(1.0, 0.95, 0.6) },
	{ "name": "Galactic Core", "ring_type": "in", "rings_to_pass": 4, "color": Color(0.85, 0.7, 0.35) },
	{ "name": "Wormhole", "ring_type": "in", "rings_to_pass": 4, "color": Color(0.35, 0.55, 0.7), "two_path": true },
	{ "name": "White Hole", "ring_type": "out", "rings_to_pass": 3, "color": Color(1, 1, 1) },
	{ "name": "Molecular Cloud", "ring_type": "in", "rings_to_pass": 3, "color": Color(0.5, 0.55, 0.65) },
	{ "name": "Oort Cloud", "ring_type": "in", "rings_to_pass": 3, "color": Color(0.7, 0.8, 0.9) },
	{ "name": "Asteroid Belt", "ring_type": "in", "rings_to_pass": 4, "color": Color(0.55, 0.45, 0.35) },
	{ "name": "Earth", "ring_type": "none", "rings_to_pass": 0, "color": Color(0.25, 0.6, 0.5) },
]
var stage_index = 0
var passes_this_stage = 0

func in_gap_range(angle: float, gs_raw: float, gw: float) -> bool:
	var a = fposmod(angle, TAU)
	var gs = fposmod(gs_raw, TAU)
	var ge = fposmod(gs_raw + gw, TAU)
	return (a >= gs and a <= ge) if gs < ge else (a >= gs or a <= ge)

func _process(delta):
	if not game_started:
		earth_rotation += earth_rotation_speed * delta
		if Input.is_action_just_pressed("rotate_left") or Input.is_action_just_pressed("rotate_right"):
			game_started = true
		queue_redraw()
		return
	if ending_phase != "":
		update_ending(delta)
		queue_redraw()
		return
	if not running:
		if Input.is_action_just_pressed("ui_accept"):
			restart_game()
		queue_redraw()
		return
	if Input.is_action_pressed("rotate_left"):
		player_angle -= angular_speed * delta
		facing_dir = -1.0
	if Input.is_action_pressed("rotate_right"):
		player_angle += angular_speed * delta
		facing_dir = 1.0

	player_pos = center + Vector2(cos(player_angle), sin(player_angle)) * player_radius
	trail_points.append(player_pos)
	if trail_points.size() > trail_max_length:
		trail_points.remove_at(0)

	spawn_timer += delta
	if spawn_timer >= spawn_interval:
		spawn_timer = 0.0
		var s = stages[stage_index]
		var start_radius = 10.0 if s.ring_type == "out" else 250.0
		var new_ring = { "radius": start_radius, "gap_start": randf() * TAU, "resolved": false, "ring_type": s.ring_type }
		if s.get("two_path", false):
			new_ring["gap_start_2"] = new_ring.gap_start + PI + (randf() - 0.5) * 1.0
		rings.append(new_ring)

	for i in range(rings.size() - 1, -1, -1):
		var ring = rings[i]
		if ring.ring_type == "out":
			ring.radius += ring_speed * delta
		else:
			ring.radius -= ring_speed * delta
		if not ring.resolved and ring.radius <= player_radius + 6 and ring.radius >= player_radius - 6:
			ring.resolved = true
			var passed = in_gap_range(player_angle, ring.gap_start, gap_width)
			if ring.has("gap_start_2"):
				passed = passed or in_gap_range(player_angle, ring.gap_start_2, gap_width)
			if passed:
				on_ring_passed()
			else:
				$SfxFail.play()
				running = false
				print("Missed it — press Enter to retry")
			break
		if ring.radius <= 0 or ring.radius > 300:
			rings.remove_at(i)
	queue_redraw()

func on_ring_passed():
	passes_this_stage += 1
	if passes_this_stage >= stages[stage_index].rings_to_pass:
		advance_stage()

func advance_stage():
	stage_index += 1
	passes_this_stage = 0
	rings.clear()
	if stage_index >= stages.size():
		print("Reached the end of all stages!")
		running = false
		return
	var s = stages[stage_index]
	modulate = s.color
	if s.ring_type == "none":
		start_ending()
		return
	print("Now entering: " + s.name)

func start_ending():
	running = false
	modulate = Color(1, 1, 1)
	ending_phase = "burst"
	ending_timer = 0.0
	burst_start_pos = player_pos
	print("Approaching Earth...")

func update_ending(delta):
	ending_timer += delta
	if ending_phase == "burst":
		var t = clamp(ending_timer / 0.9, 0.0, 1.0)
		var eased = t * t
		var dir = Vector2(cos(player_angle), sin(player_angle))
		player_pos = burst_start_pos + dir * eased * 900.0
		burst_stretch = eased * 1.6
		if ending_timer >= 0.9:
			ending_phase = "flash"
			ending_timer = 0.0
	elif ending_phase == "flash":
		var t = clamp(ending_timer / 0.35, 0.0, 1.0)
		flash_alpha = min(1.0, t / 0.5)
		if ending_timer >= 0.35:
			ending_phase = "reveal"
			ending_timer = 0.0
	elif ending_phase == "reveal":
		var t = clamp(ending_timer / 1.0, 0.0, 1.0)
		flash_alpha = 1.0 - t
		if ending_timer >= 1.0:
			ending_phase = ""
			flash_alpha = 0.0
			enter_earth()

func enter_earth():
	running = false
	print("Welcome home.")

func restart_game():
	stage_index = 0
	passes_this_stage = 0
	rings.clear()
	trail_points.clear()
	player_angle = 0.0
	facing_dir = 1.0
	spawn_timer = 0.0
	ending_phase = ""
	flash_alpha = 0.0
	burst_stretch = 0.0
	modulate = stages[0].color
	running = true
	print("Restarting the run.")

func draw_ring(ring):
	var s = stages[stage_index]
	var low_vis = s.get("low_visibility", false)
	var wall_color = Color(0.15, 0.15, 0.18) if low_vis else Color.ORANGE
	if ring.has("gap_start_2"):
		var g1 = fposmod(ring.gap_start, TAU)
		var g2 = fposmod(ring.gap_start_2, TAU)
		if g2 < g1:
			var tmp = g1
			g1 = g2
			g2 = tmp
		draw_arc(center, ring.radius, g1 + gap_width, g2, 48, wall_color, 4.0)
		draw_arc(center, ring.radius, g2 + gap_width, g1 + TAU, 48, wall_color, 4.0)
	else:
		draw_arc(center, ring.radius, ring.gap_start + gap_width, ring.gap_start + TAU, 64, wall_color, 4.0)
	if low_vis:
		var edge1 = center + Vector2(cos(ring.gap_start), sin(ring.gap_start)) * ring.radius
		var edge2 = center + Vector2(cos(ring.gap_start + gap_width), sin(ring.gap_start + gap_width)) * ring.radius
		draw_circle(edge1, 5, Color(1, 0.95, 0.6))
		draw_circle(edge2, 5, Color(1, 0.95, 0.6))

func draw_trail():
	var n = trail_points.size()
	if n < 2:
		return
	for i in range(n - 1):
		var t = float(i) / float(n)
		var alpha = t * 0.75
		var width = 1.5 + t * 4.5
		draw_line(trail_points[i], trail_points[i + 1], Color(0.4, 0.9, 1.0, alpha), width)

func draw_ship():
	var facing = player_angle + facing_dir * PI / 2.0
	draw_set_transform(player_pos, facing, Vector2.ONE)
	var pts = PackedVector2Array([
		Vector2(12, 0),
		Vector2(-8, -6),
		Vector2(-4, 0),
		Vector2(-8, 6)
	])
	draw_colored_polygon(pts, Color.CYAN)
	draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)

func draw_burst_frame():
	draw_line(burst_start_pos, player_pos, Color(0.6, 0.9, 1.0, 0.6), 3.0)
	draw_set_transform(player_pos, player_angle, Vector2(1.0 + burst_stretch, 1.0))
	var pts = PackedVector2Array([
		Vector2(12, 0),
		Vector2(-8, -6),
		Vector2(-4, 0),
		Vector2(-8, 6)
	])
	draw_colored_polygon(pts, Color(1, 1, 1))
	draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)

func draw_earth_scene(show_lander: bool):
	draw_circle(center, 40, Color(0.2, 0.45, 0.75))
	draw_circle(center + Vector2(-14, -10), 12, Color(0.3, 0.6, 0.35))
	draw_circle(center + Vector2(12, 14), 9, Color(0.3, 0.6, 0.35))
	if show_lander:
		var lander_pos = center + Vector2(22, -8)
		draw_set_transform(lander_pos, -PI / 2.0, Vector2(0.6, 0.6))
		var pts = PackedVector2Array([Vector2(12, 0), Vector2(-8, -6), Vector2(-4, 0), Vector2(-8, 6)])
		draw_colored_polygon(pts, Color.CYAN)
		draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
		var flag_base = lander_pos + Vector2(14, 4)
		draw_line(flag_base, flag_base + Vector2(0, -14), Color(0.85, 0.85, 0.85), 2.0)
		var flag_pts = PackedVector2Array([flag_base + Vector2(0, -14), flag_base + Vector2(10, -11), flag_base + Vector2(0, -8)])
		draw_colored_polygon(flag_pts, Color(0.9, 0.2, 0.2))
	draw_string(ThemeDB.fallback_font, Vector2(center.x - 20, center.y + 70), "home.", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color.WHITE)
	if show_lander:
		draw_string(ThemeDB.fallback_font, Vector2(center.x - 105, center.y + 100), "Press Enter to fly again.", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.75, 0.8, 0.85))

func draw_menu_earth():
	var e_center = Vector2(780, 320)
	var e_radius = 90.0
	draw_circle(e_center, e_radius, Color(0.15, 0.35, 0.65))
	for c in earth_continents:
		var a = c.angle + earth_rotation
		var depth = cos(a)
		if depth < -0.15:
			continue
		var x = e_center.x + sin(a) * e_radius * 0.9
		var y = e_center.y + c.y
		var alpha = clamp((depth + 0.15) / 1.15, 0.0, 1.0)
		var size = c.size * (0.6 + 0.4 * depth)
		draw_circle(Vector2(x, y), size, Color(0.25, 0.55, 0.3, alpha))

func _draw():
	if not game_started:
		draw_menu_earth()
		draw_string(ThemeDB.fallback_font, Vector2(center.x - 110, center.y - 60), "HOMEBOUND", HORIZONTAL_ALIGNMENT_LEFT, -1, 32, Color.WHITE)
		draw_string(ThemeDB.fallback_font, Vector2(center.x - 140, center.y - 20), "Born in the Big Bang. Searching for Earth.", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.8, 0.8, 0.85))
		draw_string(ThemeDB.fallback_font, Vector2(center.x - 140, center.y + 30), "Hold A/D or Left/Right to rotate.", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.7, 0.7, 0.75))
		draw_string(ThemeDB.fallback_font, Vector2(center.x - 140, center.y + 55), "Line up with the gap as each ring closes in.", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.7, 0.7, 0.75))
		draw_string(ThemeDB.fallback_font, Vector2(center.x - 140, center.y + 90), "18 of these locations are real. 2 are still just theory.", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.55, 0.6, 0.65))
		draw_string(ThemeDB.fallback_font, Vector2(center.x - 140, center.y + 120), "Press left or right to begin.", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(1, 0.9, 0.5))
		return
	if ending_phase == "burst":
		draw_burst_frame()
		return
	if ending_phase == "flash" or ending_phase == "reveal":
		draw_earth_scene(true)
		draw_rect(Rect2(-1000, -1000, 4000, 4000), Color(1, 1, 1, flash_alpha), true)
		return
	var s = stages[stage_index]
	if s.ring_type == "none":
		draw_earth_scene(true)
		return
	draw_circle(center, 20, Color.WHITE)
	for ring in rings:
		draw_ring(ring)
	draw_trail()
	draw_ship()
	if not running:
		draw_string(ThemeDB.fallback_font, Vector2(center.x - 60, center.y - 120), "Missed it.", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color.WHITE)
		draw_string(ThemeDB.fallback_font, Vector2(center.x - 105, center.y - 95), "Press Enter to try again.", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(1, 0.9, 0.5))
