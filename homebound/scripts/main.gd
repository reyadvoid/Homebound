extends Node2D

var center = Vector2(300, 300)
var player_radius = 80.0
var player_angle = 0.0
var angular_speed = 2.6
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
	{ "name": "The Dark Ages", "ring_type": "in", "rings_to_pass": 4, "color": Color(0.05, 0.05, 0.08) },
	{ "name": "First Starlight", "ring_type": "in", "rings_to_pass": 3, "color": Color(0.6, 0.8, 1.0) },
]
var stage_index = 0
var passes_this_stage = 0

func _process(delta):
	if not running:
		return
	if Input.is_action_pressed("rotate_left"):
		player_angle -= angular_speed * delta
	if Input.is_action_pressed("rotate_right"):
		player_angle += angular_speed * delta

	spawn_timer += delta
	if spawn_timer >= spawn_interval:
		spawn_timer = 0.0
		rings.append({ "radius": 250.0, "gap_start": randf() * TAU, "resolved": false })

	for i in range(rings.size() - 1, -1, -1):
		var ring = rings[i]
		ring.radius -= ring_speed * delta
		if not ring.resolved and ring.radius <= player_radius + 6 and ring.radius >= player_radius - 6:
			ring.resolved = true
			var a = fposmod(player_angle, TAU)
			var gs = fposmod(ring.gap_start, TAU)
			var ge = fposmod(ring.gap_start + gap_width, TAU)
			var in_gap = (a >= gs and a <= ge) if gs < ge else (a >= gs or a <= ge)
			if in_gap:
				on_ring_passed()
			else:
				running = false
				print("Missed it — press Play again to retry")
			break
		if ring.radius <= 0:
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
		print("Reached the end of the first 5 stages!")
		running = false
		return
	modulate = stages[stage_index].color
	print("Now entering: " + stages[stage_index].name)

func _draw():
	draw_circle(center, 20, Color.WHITE)
	for ring in rings:
		draw_arc(center, ring.radius, ring.gap_start + gap_width, ring.gap_start + TAU, 64, Color.ORANGE, 4.0)
	var player_pos = center + Vector2(cos(player_angle), sin(player_angle)) * player_radius
	draw_circle(player_pos, 6, Color.CYAN)
