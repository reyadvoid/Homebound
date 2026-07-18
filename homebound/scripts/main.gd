extends Node2D

@onready var trail = $Trail

var center = Vector2(300, 300)
var player_radius = 80.0
var player_angle = 0.0
var angular_speed = 2.6
var player_pos = Vector2.ZERO
var ring_speed = 60.0
var gap_width = 0.6
var running = true
var rings = []
var spawn_timer = 0.0
var spawn_interval = 1.3

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
	if not running:
		trail.emitting = false
		return
	if Input.is_action_pressed("rotate_left"):
		player_angle -= angular_speed * delta
	if Input.is_action_pressed("rotate_right"):
		player_angle += angular_speed * delta

	player_pos = center + Vector2(cos(player_angle), sin(player_angle)) * player_radius
	trail.position = player_pos
	trail.emitting = true

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
				running = false
				print("Missed it — press Play again to retry")
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
		print("Welcome home. You reached Earth.")
		running = false
		return
	print("Now entering: " + s.name)

func draw_ring(ring):
	var s = stages[stage_index]
	var low_vis = s.get("low_visibility", false)
	var wall_color = Color(0.15, 0.15, 0.18) if low_vis else Color.ORANGE
	if ring.has("gap_start_2"):
		var gaps = [ring.gap_start, ring.gap_start_2]
		gaps.sort()
		var g1 = fposmod(gaps[0], TAU)
		var g2 = fposmod(gaps[1], TAU)
		draw_arc(center, ring.radius, g1 + gap_width, g2, 48, wall_color, 4.0)
		draw_arc(center, ring.radius, g2 + gap_width, g1 + TAU, 48, wall_color, 4.0)
	else:
		draw_arc(center, ring.radius, ring.gap_start + gap_width, ring.gap_start + TAU, 64, wall_color, 4.0)
	if low_vis:
		var edge1 = center + Vector2(cos(ring.gap_start), sin(ring.gap_start)) * ring.radius
		var edge2 = center + Vector2(cos(ring.gap_start + gap_width), sin(ring.gap_start + gap_width)) * ring.radius
		draw_circle(edge1, 5, Color(1, 0.95, 0.6))
		draw_circle(edge2, 5, Color(1, 0.95, 0.6))

func _draw():
	draw_circle(center, 20, Color.WHITE)
	for ring in rings:
		draw_ring(ring)
	draw_circle(player_pos, 6, Color.CYAN)
