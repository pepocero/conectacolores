"""Genera iconos Android de Conecta Colores.

icon_main_192 y el icono de Play (512) usan EXACTAMENTE el mismo diseño
(solo cambia el tamaño). Cuadrado completo: el sistema / Play aplican la máscara.
"""
from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageDraw

OUT = Path(__file__).resolve().parent

BG_ADAPT = (26, 58, 166, 255)  # #1A3AA6 — azul menú
CYAN = (0, 212, 255, 255)
ORANGE = (255, 140, 66, 255)
GREEN = (74, 222, 128, 255)
PINK = (255, 107, 157, 255)
PURPLE = (167, 139, 250, 255)


def compose_motif(
	size: int,
	*,
	with_bg: bool = False,
	pad_ratio: float = 0.16,
	mono: bool = False,
) -> Image.Image:
	img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
	draw = ImageDraw.Draw(img)

	if with_bg:
		draw.rectangle([0, 0, size - 1, size - 1], fill=BG_ADAPT)

	margin = int(size * pad_ratio)
	box = size - 2 * margin
	s = box / 128.0
	ox = oy = float(margin)

	def P(x: float, y: float) -> tuple[float, float]:
		return ox + x * s, oy + y * s

	def R(v: float) -> int:
		return max(2, int(v * s))

	line_w = max(3, int(10 * s))
	lines = Image.new("RGBA", (size, size), (0, 0, 0, 0))
	ld = ImageDraw.Draw(lines)

	def line(p0, p1, color, alpha: int = 140) -> None:
		col = (255, 255, 255, min(255, alpha + 60)) if mono else (color[0], color[1], color[2], alpha)
		ld.line([p0, p1], fill=col, width=line_w)

	p34, p94, p34b, p64 = P(34, 34), P(94, 34), P(34, 94), P(64, 64)
	line(p34, p94, CYAN, 140)
	line(p34b, P(64, 94), GREEN, 140)
	line(P(64, 94), p64, GREEN, 140)
	line(p94, P(94, 64), ORANGE, 90)
	img = Image.alpha_composite(img, lines)
	draw = ImageDraw.Draw(img)

	for (cx, cy), r, col in [
		(p34, R(14), CYAN),
		(p94, R(14), ORANGE),
		(p34b, R(14), GREEN),
		(P(94, 94), R(14), PINK),
		(p64, R(12), PURPLE),
	]:
		if mono:
			draw.ellipse([cx - r, cy - r, cx + r, cy + r], fill=(255, 255, 255, 255))
			hr = max(2, int(r * 0.28))
			draw.ellipse(
				[cx - r * 0.35 - hr / 2, cy - r * 0.4 - hr / 2, cx - r * 0.35 + hr / 2, cy - r * 0.4 + hr / 2],
				fill=(255, 255, 255, 90),
			)
		else:
			draw.ellipse([cx - r + 1, cy - r + 2, cx + r + 1, cy + r + 2], fill=(0, 0, 0, 50))
			draw.ellipse([cx - r, cy - r, cx + r, cy + r], fill=col)
			hr = max(2, int(r * 0.32))
			hx, hy = cx - int(r * 0.28), cy - int(r * 0.32)
			hl = Image.new("RGBA", (size, size), (0, 0, 0, 0))
			ImageDraw.Draw(hl).ellipse([hx - hr, hy - hr, hx + hr, hy + hr], fill=(255, 255, 255, 170))
			img = Image.alpha_composite(img, hl)
			draw = ImageDraw.Draw(img)
	return img


def make_brand_icon(size: int) -> Image.Image:
	"""Diseño único de marca: fondo azul + burbujas. Mismo para 192 y 512."""
	bg = Image.new("RGBA", (size, size), BG_ADAPT)
	glow = Image.new("RGBA", (size, size), (0, 0, 0, 0))
	gd = ImageDraw.Draw(glow)
	cx = cy = size // 2
	for i in range(20, 0, -1):
		r = int(size * (0.16 + i * 0.028))
		gd.ellipse([cx - r, int(cy * 0.9) - r, cx + r, int(cy * 0.9) + r], fill=(80, 140, 255, 8))
	bg = Image.alpha_composite(bg, glow)

	# Burbujas decorativas en esquinas (proporcionales)
	for fx, fy, fr, col, a in [
		(0.14, 0.16, 0.062, CYAN, 45),
		(0.84, 0.18, 0.074, PINK, 40),
		(0.12, 0.82, 0.086, GREEN, 38),
		(0.88, 0.84, 0.078, ORANGE, 40),
	]:
		layer = Image.new("RGBA", (size, size), (0, 0, 0, 0))
		r = int(size * fr)
		x, y = int(size * fx), int(size * fy)
		ImageDraw.Draw(layer).ellipse([x - r, y - r, x + r, y + r], fill=(col[0], col[1], col[2], a))
		bg = Image.alpha_composite(bg, layer)

	fg = compose_motif(size, with_bg=False, pad_ratio=0.16, mono=False)
	return Image.alpha_composite(bg, fg)


def make_background(size: int = 432) -> Image.Image:
	bg = Image.new("RGBA", (size, size), BG_ADAPT)
	glow = Image.new("RGBA", (size, size), (0, 0, 0, 0))
	gd = ImageDraw.Draw(glow)
	cx = cy = size // 2
	for i in range(20, 0, -1):
		r = int(size * (0.16 + i * 0.028))
		gd.ellipse([cx - r, int(cy * 0.9) - r, cx + r, int(cy * 0.9) + r], fill=(80, 140, 255, 8))
	bg = Image.alpha_composite(bg, glow)
	for fx, fy, fr, col, a in [
		(0.14, 0.16, 0.062, CYAN, 50),
		(0.84, 0.18, 0.074, PINK, 45),
		(0.12, 0.82, 0.086, GREEN, 40),
		(0.88, 0.84, 0.078, ORANGE, 45),
		(0.50, 0.92, 0.050, PURPLE, 35),
	]:
		layer = Image.new("RGBA", (size, size), (0, 0, 0, 0))
		r = int(size * fr)
		x, y = int(size * fx), int(size * fy)
		ImageDraw.Draw(layer).ellipse([x - r, y - r, x + r, y + r], fill=(col[0], col[1], col[2], a))
		bg = Image.alpha_composite(bg, layer)
	return bg


def main() -> None:
	# Mismo diseño exacto (escalado)
	brand_512 = make_brand_icon(512)
	brand_192 = brand_512.resize((192, 192), Image.Resampling.LANCZOS)

	main_path = OUT / "icon_main_192.png"
	brand_192.save(main_path, "PNG")
	print(f"{main_path.name}: {brand_192.size}")

	# Adaptive layers (mismas proporciones)
	bg = make_background(432)
	bg_path = OUT / "icon_adaptive_background_432.png"
	bg.save(bg_path, "PNG")

	fg = compose_motif(432, with_bg=False, pad_ratio=0.18, mono=False)
	fg_path = OUT / "icon_adaptive_foreground_432.png"
	fg.save(fg_path, "PNG")

	mono = compose_motif(432, with_bg=False, pad_ratio=0.18, mono=True)
	mono_path = OUT / "icon_adaptive_monochrome_432.png"
	mono.save(mono_path, "PNG")

	# Copia 512 para sincronizar con la ficha de Play
	play_dir = Path(r"G:\Apps Android\Conecta Colores\Ficha Google Play\01_icono")
	if play_dir.is_dir():
		play_path = play_dir / "icon_play_512.png"
		brand_512.save(play_path, "PNG")
		print(f"sincronizado Play: {play_path}")

	ref_dir = Path(r"G:\Apps Android\Conecta Colores\Ficha Google Play\05_referencia_app")
	if ref_dir.is_dir():
		brand_192.save(ref_dir / "icon_main_192.png", "PNG")
		brand_192.save(ref_dir / "icon_main_192_app.png", "PNG")
		fg.save(ref_dir / "icon_adaptive_foreground_432.png", "PNG")
		bg.save(ref_dir / "icon_adaptive_background_432.png", "PNG")
		mono.save(ref_dir / "icon_adaptive_monochrome_432.png", "PNG")
		# Ya no hace falta la variante redondeada distinta
		old = ref_dir / "icon_app_style_512_rounded_NO_SUBIR.png"
		if old.exists():
			old.unlink()

	for p in (main_path, fg_path, bg_path, mono_path):
		im = Image.open(p)
		print(f"{p.name}: {im.size[0]}x{im.size[1]} {im.mode}")


if __name__ == "__main__":
	main()
