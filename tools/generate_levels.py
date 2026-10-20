#!/usr/bin/env python3
"""
Genera data/levels.json con dificultad progresiva.

Cada nivel es una rejilla de letras. Cada letra debe formar un poliominó-serpiente
(exactamente 2 celdas con un solo vecino del mismo color). Eso garantiza solución.
"""

from __future__ import annotations

import json
import random
from collections import defaultdict, deque
from pathlib import Path

COLOR_MAP = {
	"C": "cyan",
	"O": "orange",
	"G": "green",
	"P": "pink",
	"Y": "yellow",
	"V": "violet",
}
DIRS = [(1, 0), (-1, 0), (0, 1), (0, -1)]


def parse_grid(text: str) -> list[str]:
	rows = [ln.rstrip() for ln in text.strip("\n").splitlines() if ln.strip() != ""]
	width = len(rows[0])
	for r in rows:
		assert len(r) == width, f"filas irregulares: {r!r}"
	return rows


def neighbors(pos: tuple[int, int], cells: set[tuple[int, int]]) -> list[tuple[int, int]]:
	x, y = pos
	return [(x + dx, y + dy) for dx, dy in DIRS if (x + dx, y + dy) in cells]


def trace_path(cells: list[tuple[int, int]], letter: str, level_id: int) -> list[list[int]]:
	cell_set = set(cells)
	assert len(cell_set) == len(cells), (level_id, letter, "duplicadas")
	degrees = {c: len(neighbors(c, cell_set)) for c in cell_set}
	ends = [c for c, d in degrees.items() if d == 1]
	assert len(ends) == 2, (level_id, letter, f"extremos={len(ends)}", degrees)

	seen: set[tuple[int, int]] = set()
	q = deque([ends[0]])
	seen.add(ends[0])
	while q:
		cur = q.popleft()
		for n in neighbors(cur, cell_set):
			if n not in seen:
				seen.add(n)
				q.append(n)
	assert seen == cell_set, (level_id, letter, "no conexa")

	path = [ends[0]]
	prev = None
	while path[-1] != ends[1]:
		cur = path[-1]
		opts = [n for n in neighbors(cur, cell_set) if n != prev]
		assert len(opts) == 1, (level_id, letter, f"bifurcación {cur}", opts)
		prev = cur
		path.append(opts[0])
	assert len(path) == len(cell_set), (level_id, letter, "path incompleto")
	return [[x, y] for x, y in path]


def level_from_grid(level_id: int, name: str, grid_text: str) -> dict:
	grid = parse_grid(grid_text)
	size = len(grid)
	assert all(len(r) == size for r in grid), (level_id, "no cuadrada")

	grouped: dict[str, list[tuple[int, int]]] = defaultdict(list)
	for y, row in enumerate(grid):
		for x, ch in enumerate(row):
			if ch == ".":
				continue
			assert ch in COLOR_MAP, (level_id, f"letra inválida {ch}")
			grouped[ch].append((x, y))

	paths: dict[str, list[list[int]]] = {}
	dots: list[dict] = []
	for letter, cells in grouped.items():
		color = COLOR_MAP[letter]
		path = trace_path(cells, letter, level_id)
		paths[color] = path
		dots.append({"color": color, "x": path[0][0], "y": path[0][1]})
		dots.append({"color": color, "x": path[-1][0], "y": path[-1][1]})

	return {
		"id": level_id,
		"name": name,
		"size": size,
		"dots": dots,
		"solution": paths,
		"par": sum(len(p) - 1 for p in paths.values()),
	}


def all_levels() -> list[tuple[int, str, str]]:
	"""Grids: filas de arriba a abajo. Cada color = serpiente (2 extremos)."""
	return [
		# ========== 1–2 Tutorial (trivial) ==========
		(1, "Primeros pasos", """
CCCCC
.....
.....
.....
OOOOO
"""),
		(2, "Columnas", """
C...O
C...O
C...O
C...O
C...O
"""),
		# ========== 3–5  5×5: giros y rodeos ==========
		(3, "Giro sencillo", """
CCCCC
G...C
G...C
G...C
GOOOO
"""),
		(4, "Rodeo", """
CCOOO
C.G.O
C.G.O
C.G.O
CCGGG
"""),
		(5, "Doblez", """
CCCCC
O...Y
O.G.Y
O.G.Y
O.GGY
"""),
		# ========== 6–10  6×6 ==========
		(6, "Marco", """
CCCCCC
O....C
O.GGGC
O.G..C
O.GGGC
OOOOOO
"""),
		(7, "Serpiente", """
CYYYYO
C...GO
CPPPGO
C...GO
CGGGGO
CCCCCO
"""),
		(8, "Puente", """
CCCCCC
Y....C
Y.OO.C
Y.O..C
Y.OOOC
YYYYYC
"""),
		(9, "Espiral", """
CCCCCC
OOOOOC
GPPPPC
G...YC
GYYYYC
GGGGGC
"""),
		(10, "Nudo", """
CGGGGO
C...GO
CPPPGO
C...YO
CYYYYO
CCCCCO
"""),
		# ========== 11–20  7×7 ==========
		(11, "Ampliar", """
CCCCCCC
O.....C
O.GGGGC
O.G...C
O.G.YYC
O.GGGYC
OOOOOYC
"""),
		(12, "Cajas", """
CCCCYYY
O...Y.Y
O.GGY.Y
O.G.Y.Y
O.GPPP P
O.G...P
OOOOVVV
""".replace(" ", "")),
		(13, "Río", """
CCCCCCC
GPPPPPC
G....PC
G.YYY.C
G.Y...C
G.YYYYC
GGGOOOO
"""),
		(14, "Trenes", """
CCCCCCC
O.....C
O.YYY.C
O.Y.Y.C
O.Y.Y.C
O.Y.Y.C
OOOOGGC
"""),
		(15, "Laberinto", """
CGGGGGG
C.....G
C.OOOOG
C.O..OG
C.OY.OG
C.OYYOG
CCCOOOG
"""),
		(16, "Dobles", """
CCCGGGG
C.....G
C.PPPPG
C.....G
C.YYYYG
C.....O
CCCOOOO
"""),
		(17, "Enredo", """
CYYYYYY
C.....Y
CPPPPPY
C....PY
CGGGGGY
C....GG
CCCCCCG
"""),
		(18, "Sifón", """
OOOOOOO
OCCCCCO
OC...CO
OCGGGCO
OC...CO
OCPPPCO
OYYYYYO
"""),
		(19, "Corredor", """
CCCCCCC
Y.....C
Y.OOOOC
Y.O..OC
Y.OGGOC
Y.O..OC
Y.O..OC
"""),
		(20, "Desafío 7", """
CCCCCCC
Y....GC
Y.OOOGC
Y.O.PGC
Y.OPPGC
Y.O..GC
YYOOOOO
"""),
		# ========== 21–30  8×8 ==========
		(21, "Ocho suave", """
CCCCCCCC
O......C
O.GGGGGC
O.G....C
O.G.YYYC
O.G...YC
O.GGGGYC
OOOOOOYC
"""),
		(22, "Franjas vivas", """
CCCCYYYY
C......Y
C.OOOO.Y
C.O..O.Y
C.OGGO.Y
C.O..O.Y
C.O..O.Y
CCCCPPPP
"""),
		(23, "Laberinto 8", """
CCCCCCCO
Y.....CO
Y.GGG.CO
Y.G.G.CO
Y.G.GGCO
Y.G...CO
Y.GGGGCO
YYYYYYYO
"""),
		(24, "Hexa", """
CCCCCCCO
GPPPPPPO
G......O
G.YYYY.O
G.Y..Y.O
G.YVVY.O
G.Y..Y.O
GGGGGGGO
"""),
		(25, "Torre", """
CGOPYV..
CGOPYV..
CGOPYV..
CGOPYVVV
CGOP....
CGOPPPPP
CGOOOOOO
CCCCCCCC
"""),
		(26, "Profundo", """
CCCCCCCC
Y......C
Y.OOOO.C
Y.O..O.C
Y.OGGO.C
Y.O..O.C
Y.O..O.C
YYYYPPPP
"""),
		(27, "Maestro", """
CCCCCCCO
G.....CO
G.YYYYCO
G.Y..YCO
G.YVVYCO
G.Y..YCO
G.Y..YCO
GGGGGGGO
"""),
		(28, "Abismo", """
CCCCCCCO
Y.....CO
Y.VVVVCO
Y.V..VCO
Y.VGGVCO
Y.V..VCO
Y.V..VCO
YYYYPPPO
"""),
		(29, "Virtuoso", """
CGGGGGGO
C.....GO
C.YYYYGO
C.Y..YGO
C.YVVYGO
C.Y..YGO
C.Y..YGO
CCCCCCCO
"""),
		(30, "Gran final", """
CCCCCCCO
Y.....CO
Y.GGGGCO
Y.G..GCO
Y.GPPGCO
Y.G..GCO
Y.G..GCO
YYYYYYYO
"""),
	]


def _in_bounds(x: int, y: int, size: int) -> bool:
	return 0 <= x < size and 0 <= y < size


def _grid_neighbors(x: int, y: int, size: int) -> list[tuple[int, int]]:
	return [(x + dx, y + dy) for dx, dy in DIRS if _in_bounds(x + dx, y + dy, size)]


def _snake_extend_ok(
	path: list[tuple[int, int]], nxt: tuple[int, int], size: int
) -> bool:
	"""Solo el extremo puede tocar la nueva celda → el poliominó sigue siendo serpiente."""
	path_set = set(path)
	tip = path[-1]
	for nb in _grid_neighbors(nxt[0], nxt[1], size):
		if nb in path_set and nb != tip:
			return False
	return True


def _grow_snake(
	size: int,
	free: set[tuple[int, int]],
	target_len: int,
	rng: random.Random,
	start: tuple[int, int] | None = None,
) -> list[tuple[int, int]] | None:
	if start is None:
		candidates = list(free)
		rng.shuffle(candidates)
	else:
		candidates = [start] if start in free else []

	best: list[tuple[int, int]] = []
	for s in candidates[:12]:
		path = [s]
		while len(path) < target_len:
			opts = [
				n
				for n in _grid_neighbors(path[-1][0], path[-1][1], size)
				if n in free and n not in path and _snake_extend_ok(path, n, size)
			]
			if not opts:
				break
			# Preferir celdas con menos salidas (corredores estrechos / giros forzados).
			opts.sort(
				key=lambda p: (
					sum(1 for n in _grid_neighbors(p[0], p[1], size) if n in free and n not in path),
					rng.random(),
				)
			)
			path.append(opts[0])
		if len(path) > len(best):
			best = path
		if len(best) >= target_len:
			break
	if len(best) < 2:
		return None
	return best


def _build_hard_grid(size: int, num_colors: int, seed: int, min_cover: float) -> str | None:
	rng = random.Random(seed)
	letters = list(COLOR_MAP.keys())[:num_colors]
	rng.shuffle(letters)
	free = {(x, y) for x in range(size) for y in range(size)}
	assignment: dict[tuple[int, int], str] = {}
	total = size * size

	for i, letter in enumerate(letters):
		remaining_colors = num_colors - i
		# Cobertura alta: serpientes largas que se enredan.
		ideal = max(3, int(len(free) / remaining_colors))
		jitter = rng.randint(-1, 2)
		target = max(3, min(len(free) - 2 * max(0, remaining_colors - 1), ideal + jitter))
		path = _grow_snake(size, free, target, rng)
		if path is None:
			return None
		for cell in path:
			assignment[cell] = letter
			free.remove(cell)

	cover = (total - len(free)) / total
	if cover < min_cover:
		return None

	rows = []
	for y in range(size):
		rows.append("".join(assignment.get((x, y), ".") for x in range(size)))
	return "\n".join(rows)


HARD_NAMES = [
	"Presión",
	"Falso atajo",
	"Corredor fino",
	"Nido duro",
	"Cruce ciego",
	"Laberinto duro",
	"Cajas tensas",
	"Sifón profundo",
	"Doble U",
	"Enredo mayor",
	"Río estrecho",
	"Torre tensa",
	"Virtuoso",
	"Abismo",
	"Desafío alto",
	"Ocho cerrado",
	"Anillo partido",
	"Laberinto máximo",
	"Hexa tenso",
	"Profundo+",
	"Maestro+",
	"Abismo+",
	"Virtuoso+",
	"Gran final+",
	"Serpiente larga",
	"Doble nido",
	"Pasillos",
	"Laberinto final",
	"Nudo extremo",
	"Último reto",
]


def hard_levels() -> list[tuple[int, str, str]]:
	"""Modo difícil: serpientes largas autoevitantes que se cruzan visualmente."""
	defs: list[tuple[int, str, str]] = []

	for level_id in range(1, 31):
		name = HARD_NAMES[level_id - 1]
		if level_id <= 5:
			size, num_colors, min_cover = 6, 4, 0.72
		elif level_id <= 12:
			size, num_colors, min_cover = 7, 5, 0.75
		elif level_id <= 20:
			size, num_colors, min_cover = 8, 5, 0.78
		else:
			size, num_colors, min_cover = 8, 6, 0.80

		grid = None
		for attempt in range(80):
			seed = level_id * 10_000 + attempt * 97 + 42
			candidate = _build_hard_grid(size, num_colors, seed, min_cover)
			if candidate is None:
				continue
			try:
				level_from_grid(level_id, name, candidate)
			except AssertionError:
				continue
			grid = candidate
			break

		if grid is None:
			# Relajar cobertura si hace falta, nunca la validez.
			for attempt in range(120):
				seed = level_id * 50_000 + attempt * 31 + 7
				candidate = _build_hard_grid(size, num_colors, seed, min_cover=0.55)
				if candidate is None:
					continue
				try:
					level_from_grid(level_id, name, candidate)
				except AssertionError:
					continue
				grid = candidate
				break

		assert grid is not None, f"No se pudo generar hard #{level_id}"
		defs.append((level_id, name, grid))

	return defs


def _compile_pack(defs: list[tuple[int, str, str]], pack_name: str) -> list[dict]:
	ids = [i for i, _, _ in defs]
	assert ids == list(range(1, 31)), (pack_name, ids)
	levels: list[dict] = []
	for level_id, name, grid in defs:
		try:
			levels.append(level_from_grid(level_id, name, grid))
		except AssertionError as exc:
			raise AssertionError(f"[{pack_name}] Nivel {level_id} ({name}) inválido: {exc}") from exc
	return [
		{
			"id": lv["id"],
			"name": lv["name"],
			"size": lv["size"],
			"dots": lv["dots"],
			"solution": lv["solution"],
			"par": lv["par"],
		}
		for lv in levels
	]


def main() -> None:
	easy = _compile_pack(all_levels(), "easy")
	hard = _compile_pack(hard_levels(), "hard")

	out = Path(__file__).resolve().parents[1] / "data" / "levels.json"
	payload = {"easy": easy, "hard": hard}
	out.write_text(json.dumps(payload, indent="\t", ensure_ascii=False) + "\n", encoding="utf-8")
	print(f"OK: easy={len(easy)} hard={len(hard)} → {out}")
	print("--- FÁCIL ---")
	for lv in easy:
		print(f"  #{lv['id']:02d} {lv['name']:<16} {lv['size']}×{lv['size']}  pairs={len(lv['solution'])}  par={lv['par']}")
	print("--- DIFÍCIL ---")
	for lv in hard:
		print(f"  #{lv['id']:02d} {lv['name']:<16} {lv['size']}\u00d7{lv['size']}  pairs={len(lv['solution'])}  par={lv['par']}")


if __name__ == "__main__":
	main()
