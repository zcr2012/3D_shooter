extends RefCounted
## Small generated sprites for combat feedback (no external image assets, built once
## at startup, all under 64x64 pixels). Used by the world effects, the FPS weapon and the HUD.

static func soft_disc(size: int) -> ImageTexture:
	## Radial falloff sprite for puffs and sparks (generated once, no external asset).
	var image := Image.create_empty(size, size, false, Image.FORMAT_RGBA8)
	var half := size * 0.5
	for y in size:
		for x in size:
			var r := Vector2(x + 0.5 - half, y + 0.5 - half).length() / half
			var alpha := clampf(1.0 - r, 0.0, 1.0)
			alpha = alpha * alpha * (3.0 - 2.0 * alpha)
			image.set_pixel(x, y, Color(1, 1, 1, alpha))
	return ImageTexture.create_from_image(image)

static func star_texture(size: int) -> ImageTexture:
	## Muzzle flash sprite: hot white core with irregular petals, alpha fades to zero.
	var image := Image.create_empty(size, size, false, Image.FORMAT_RGBA8)
	var half := size * 0.5
	for y in size:
		for x in size:
			var offset := Vector2(x + 0.5 - half, y + 0.5 - half)
			var angle := offset.angle()
			var edge := 0.3 + 0.4 * pow(absf(sin(3.0 * angle + 0.4)), 3.0) + 0.3 * pow(absf(cos(5.0 * angle + 1.3)), 6.0)
			var r := offset.length() / half
			var alpha := clampf((edge - r) / maxf(0.45 * edge, 0.02), 0.0, 1.0)
			var heat := clampf(1.0 - r * 2.2, 0.0, 1.0)
			image.set_pixel(x, y, Color(1.0, lerpf(0.72, 1.0, heat), lerpf(0.35, 0.95, heat), alpha))
	return ImageTexture.create_from_image(image)

static func blob(size: int, seed_value: int, core: float, irregularity: float, softness: float) -> ImageTexture:
	## Irregular splat/hole: a radial mask whose edge radius wobbles with a few harmonics.
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var phases: Array[float] = []
	var weights: Array[float] = []
	for k in 5:
		phases.append(rng.randf_range(0.0, TAU))
		weights.append(rng.randf_range(0.3, 1.0))
	var image := Image.create_empty(size, size, false, Image.FORMAT_RGBA8)
	var half := size * 0.5
	for y in size:
		for x in size:
			var offset := Vector2(x + 0.5 - half, y + 0.5 - half)
			var angle := offset.angle()
			var edge := core
			for k in 5:
				edge += irregularity * 0.3 * weights[k] * sin(float(k + 2) * angle + phases[k])
			var r := offset.length() / half
			var alpha := clampf((edge - r) / maxf(softness * edge, 0.02), 0.0, 1.0)
			var speckle := 0.85 + 0.15 * rng.randf()
			image.set_pixel(x, y, Color(speckle, speckle, speckle, alpha))
	return ImageTexture.create_from_image(image)

static func vignette(width: int, height: int, tint: Color) -> GradientTexture2D:
	## Elliptical screen-edge tint: clear centre, opaque corners; drawn stretched over the HUD.
	var gradient := Gradient.new()
	gradient.set_color(0, Color(tint, 0.0))
	gradient.set_color(1, Color(tint, 1.0))
	gradient.add_point(0.45, Color(tint, 0.0))
	gradient.add_point(0.8, Color(tint, 0.55))
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.width = width
	texture.height = height
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(0.5, 0.0)
	return texture
