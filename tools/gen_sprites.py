#!/usr/bin/env python3
"""Genera el arte placeholder en pixel art de Pythoria.

Uso:  python3 tools/gen_sprites.py
Salida: assets/sprites/<id>.png (fondo transparente).

Cada sprite se dibuja a baja resolución y se escala x2 con vecino más cercano.
Los colores salen de la paleta fija de docs/DISENO.md (más los colores de mundo
para la naturaleza). Se puede reemplazar cualquier PNG por arte final con el
mismo nombre sin tocar código.
"""
from pathlib import Path

from PIL import Image, ImageDraw

OUT = Path(__file__).resolve().parent.parent / "assets" / "sprites"
SCALE = 2


def hx(h: str, a: int = 255) -> tuple:
    h = h.lstrip("#")
    return (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16), a)


def shade(c: tuple, f: float) -> tuple:
    """f < 1 oscurece, f > 1 aclara (hacia blanco)."""
    if f <= 1:
        return tuple(int(v * f) for v in c[:3]) + (c[3],)
    return tuple(int(v + (255 - v) * (f - 1)) for v in c[:3]) + (c[3],)


# Paleta fija
NOCHE = hx("1E1B3A")
VIOLETA = hx("6C4AB6")
LAVANDA = hx("A98BE8")
DORADO = hx("F2B84B")
TURQUESA = hx("3FD1C0")
ROJO = hx("E5484D")
PERGAMINO = hx("F4E9D2")
TINTA = hx("2B2440")
# Colores de mundo (naturaleza y detalles)
VERDE = hx("4E7D4B")
NARANJA = hx("B5702A")
AZUL = hx("3F6FB5")
MARRON = hx("7A4A3A")
GRIS = hx("5A6270")
CELESTE = shade(AZUL, 1.45)
PIEL = shade(PERGAMINO, 0.97)
T = (0, 0, 0, 0)


def canvas(w: int, h: int | None = None) -> tuple[Image.Image, ImageDraw.ImageDraw]:
    img = Image.new("RGBA", (w, h or w), T)
    return img, ImageDraw.Draw(img)


def px(d: ImageDraw.ImageDraw, pts, color) -> None:
    for p in pts:
        d.point(p, fill=color)


def outline(img: Image.Image, color=TINTA) -> Image.Image:
    """Contorno oscuro de 1 px alrededor de lo opaco."""
    w, h = img.size
    src = img.load()
    out = img.copy()
    dst = out.load()
    for y in range(h):
        for x in range(w):
            if src[x, y][3] != 0:
                continue
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                nx, ny = x + dx, y + dy
                if 0 <= nx < w and 0 <= ny < h and src[nx, ny][3] > 0 and src[nx, ny][:3] != color[:3]:
                    dst[x, y] = color
                    break
    return out


def save(img: Image.Image, name: str, line: bool = True) -> None:
    if line:
        img = outline(img)
    img = img.resize((img.width * SCALE, img.height * SCALE), Image.NEAREST)
    img.save(OUT / f"{name}.png")
    print(f"  {name}.png  {img.width}x{img.height}")


def star(d, cx: int, cy: int, color, r: int = 2) -> None:
    """Estrellita en cruz con centro."""
    px(d, [(cx, cy)], color)
    for i in range(1, r + 1):
        px(d, [(cx + i, cy), (cx - i, cy), (cx, cy + i), (cx, cy - i)], color)


# --- Personajes ---------------------------------------------------------------

def wizard_hat(d, color, band, x0: int = 6, tip: int = 1) -> None:
    d.polygon([(12, tip), (x0, 9), (24 - x0, 9)], fill=color)
    px(d, [(13, tip + 1), (14, tip + 2)], shade(color, 1.25))
    d.rectangle([x0 + 1, 7, 23 - x0 - 1, 8], fill=band)
    d.rectangle([3, 9, 20, 10], fill=shade(color, 0.75))


def player() -> Image.Image:
    img, d = canvas(24)
    # capa
    d.polygon([(7, 13), (16, 13), (19, 21), (4, 21)], fill=VIOLETA)
    d.polygon([(10, 14), (13, 14), (14, 21), (9, 21)], fill=shade(VIOLETA, 0.7))
    # cara
    d.ellipse([7, 8, 16, 15], fill=PIEL)
    px(d, [(9, 12), (14, 12)], TINTA)
    px(d, [(8, 13), (15, 13)], shade(ROJO, 1.5))
    # sombrero con banda dorada
    wizard_hat(d, VIOLETA, DORADO)
    # grimorio turquesa con estrella
    d.rectangle([16, 15, 20, 19], fill=TURQUESA)
    d.line([(16, 15), (16, 19)], fill=shade(TURQUESA, 0.6))
    px(d, [(18, 17)], DORADO)
    # pies
    d.rectangle([7, 21, 9, 22], fill=TINTA)
    d.rectangle([14, 21, 16, 22], fill=TINTA)
    return img


def ada() -> Image.Image:
    img, d = canvas(24)
    # bastón con luz
    d.line([(20, 6), (20, 22)], fill=MARRON)
    d.ellipse([18, 2, 22, 6], fill=LAVANDA)
    px(d, [(20, 4)], PERGAMINO)
    # capa celeste con estrellas
    d.polygon([(7, 12), (16, 12), (19, 22), (4, 22)], fill=CELESTE)
    px(d, [(7, 18), (12, 20), (15, 16), (9, 15)], PERGAMINO)
    d.polygon([(10, 13), (13, 13), (14, 22), (9, 22)], fill=shade(CELESTE, 0.75))
    # pelo canoso (lavanda) y rodete
    d.ellipse([6, 3, 17, 13], fill=shade(LAVANDA, 1.35))
    d.ellipse([9, 1, 14, 5], fill=shade(LAVANDA, 1.35))
    # cara
    d.ellipse([8, 6, 15, 13], fill=PIEL)
    # anteojos
    d.rectangle([8, 8, 10, 10], outline=TINTA)
    d.rectangle([13, 8, 15, 10], outline=TINTA)
    px(d, [(11, 9), (12, 9)], TINTA)
    px(d, [(9, 9), (14, 9)], AZUL)
    px(d, [(11, 12)], shade(ROJO, 1.5))
    return img


def owl() -> Image.Image:
    img, d = canvas(24)
    # cuerpo
    d.ellipse([4, 5, 19, 22], fill=VIOLETA)
    d.ellipse([7, 12, 16, 21], fill=LAVANDA)
    for y in (14, 17):
        px(d, [(9, y), (11, y + 1), (13, y), (15, y + 1)], shade(LAVANDA, 0.8))
    # orejas
    d.polygon([(5, 7), (6, 2), (9, 6)], fill=VIOLETA)
    d.polygon([(18, 7), (17, 2), (14, 6)], fill=VIOLETA)
    # ojos grandes
    d.ellipse([5, 6, 11, 12], fill=PERGAMINO)
    d.ellipse([12, 6, 18, 12], fill=PERGAMINO)
    d.rectangle([7, 8, 9, 10], fill=TINTA)
    d.rectangle([14, 8, 16, 10], fill=TINTA)
    px(d, [(7, 8), (14, 8)], PERGAMINO)
    # pico
    d.polygon([(11, 11), (13, 11), (12, 14)], fill=NARANJA)
    # patitas
    px(d, [(9, 22), (10, 22), (13, 22), (14, 22)], NARANJA)
    return img


def byte_cat() -> Image.Image:
    img, d = canvas(24)
    # cuerpo enroscado durmiendo
    d.ellipse([2, 10, 21, 22], fill=NARANJA)
    d.ellipse([5, 13, 15, 21], fill=shade(NARANJA, 1.3))
    for x in (8, 12, 16):
        d.line([(x, 11), (x + 1, 14)], fill=shade(NARANJA, 0.7))
    # cola
    d.arc([12, 14, 23, 23], 270, 90, fill=NARANJA, width=2)
    # cabeza
    d.ellipse([2, 8, 11, 16], fill=NARANJA)
    d.polygon([(3, 10), (3, 5), (6, 8)], fill=NARANJA)
    d.polygon([(10, 10), (10, 5), (7, 8)], fill=NARANJA)
    px(d, [(4, 7), (9, 7)], shade(ROJO, 1.5))
    # ojos cerrados
    px(d, [(4, 12), (5, 13), (8, 13), (9, 12)], TINTA)
    px(d, [(6, 14), (7, 14)], shade(ROJO, 1.4))
    # sombrerito violeta
    d.polygon([(7, 0), (4, 6), (11, 6)], fill=VIOLETA)
    d.rectangle([3, 5, 12, 6], fill=shade(VIOLETA, 0.75))
    # zzz
    px(d, [(16, 2), (17, 2), (18, 2), (17, 3), (16, 4), (17, 4), (18, 4)], LAVANDA)
    return img


def gremlin() -> Image.Image:
    img, d = canvas(24)
    # orejas puntiagudas
    d.polygon([(1, 6), (7, 8), (6, 12)], fill=ROJO)
    d.polygon([(22, 6), (16, 8), (17, 12)], fill=ROJO)
    # cuerpo y cabeza
    d.ellipse([5, 4, 18, 16], fill=ROJO)
    d.ellipse([6, 13, 17, 22], fill=shade(ROJO, 0.8))
    # cuernitos
    px(d, [(8, 3), (8, 2), (15, 3), (15, 2)], shade(ROJO, 0.6))
    # ojos furiosos
    d.rectangle([7, 8, 10, 10], fill=PERGAMINO)
    d.rectangle([13, 8, 16, 10], fill=PERGAMINO)
    px(d, [(9, 9), (14, 9)], TINTA)
    d.line([(7, 7), (10, 8)], fill=TINTA)
    d.line([(16, 7), (13, 8)], fill=TINTA)
    # boca con dientes
    d.rectangle([8, 12, 15, 14], fill=TINTA)
    px(d, [(9, 12), (11, 12), (13, 12), (10, 14), (12, 14), (14, 14)], PERGAMINO)
    # paréntesis robados
    d.arc([0, 14, 6, 23], 100, 260, fill=PERGAMINO, width=1)
    d.arc([17, 14, 23, 23], 280, 80, fill=PERGAMINO, width=1)
    # patas
    d.rectangle([7, 21, 9, 22], fill=shade(ROJO, 0.6))
    d.rectangle([14, 21, 16, 22], fill=shade(ROJO, 0.6))
    return img


def fantasma() -> Image.Image:
    img, d = canvas(24)
    body = shade(LAVANDA, 1.6)
    d.ellipse([4, 2, 19, 16], fill=body)
    d.rectangle([4, 9, 19, 19], fill=body)
    # borde ondulado
    for i, x in enumerate(range(4, 20, 3)):
        d.polygon([(x, 19), (x + 3, 19), (x + 1, 22 if i % 2 == 0 else 21)], fill=body)
    # ojos rojos de criatura del Caos
    d.ellipse([7, 7, 10, 11], fill=ROJO)
    d.ellipse([13, 7, 16, 11], fill=ROJO)
    px(d, [(8, 8), (14, 8)], PERGAMINO)
    # boca "?"
    d.ellipse([10, 13, 13, 16], fill=TINTA)
    # etiqueta de nombre vacía
    d.rectangle([14, 16, 21, 19], fill=PERGAMINO)
    px(d, [(16, 17), (17, 17), (18, 17), (19, 17)], GRIS)
    return img


def quimera() -> Image.Image:
    img, d = canvas(24)
    # cuerpo
    d.ellipse([3, 10, 20, 20], fill=ROJO)
    # patas
    for x in (5, 9, 14, 18):
        d.rectangle([x - 1, 18, x, 22], fill=shade(ROJO, 0.7))
    # cola de serpiente
    d.line([(20, 14), (22, 10), (21, 7)], fill=shade(ROJO, 0.6), width=1)
    # cabeza de león (melena)
    d.ellipse([0, 3, 11, 13], fill=NARANJA)
    d.ellipse([2, 5, 9, 12], fill=ROJO)
    px(d, [(4, 7), (7, 7)], PERGAMINO)
    px(d, [(5, 10), (6, 10)], TINTA)
    # cabeza de cabra con cuernos
    d.ellipse([12, 4, 20, 11], fill=shade(ROJO, 0.85))
    d.arc([12, 0, 18, 6], 180, 360, fill=PERGAMINO)
    d.arc([15, 0, 21, 6], 180, 360, fill=PERGAMINO)
    px(d, [(14, 7), (18, 7)], PERGAMINO)
    px(d, [(16, 10)], TINTA)
    # rayo: tipos que chocan
    px(d, [(11, 14), (12, 15), (11, 16), (12, 17)], DORADO)
    return img


def ouroboros() -> Image.Image:
    img, d = canvas(24)
    body = shade(ROJO, 0.85)
    d.ellipse([2, 2, 21, 21], outline=body, width=4)
    # escamas
    for p in [(12, 3), (19, 9), (19, 15), (12, 20), (4, 15), (4, 9)]:
        px(d, [p], shade(ROJO, 1.3))
    # cabeza mordiendo la cola (arriba a la izquierda)
    d.ellipse([3, 2, 10, 8], fill=ROJO)
    px(d, [(5, 4)], PERGAMINO)
    px(d, [(9, 6), (10, 7)], PERGAMINO)
    # cola entrando en la boca
    d.polygon([(10, 5), (13, 3), (13, 6)], fill=shade(ROJO, 0.6))
    # flechas de bucle
    d.arc([8, 8, 15, 15], 30, 330, fill=LAVANDA)
    px(d, [(15, 10), (14, 9), (16, 9)], LAVANDA)
    return img


# --- Objetos ------------------------------------------------------------------

def jar() -> Image.Image:
    img, d = canvas(24)
    glass = shade(LAVANDA, 1.25)
    d.rectangle([9, 1, 14, 4], fill=MARRON)
    d.rectangle([8, 4, 15, 6], fill=shade(LAVANDA, 0.9))
    d.ellipse([3, 6, 20, 22], fill=glass)
    d.rectangle([3, 13, 20, 18], fill=glass)
    # brillo
    d.line([(6, 10), (6, 16)], fill=PERGAMINO)
    px(d, [(7, 9)], PERGAMINO)
    # runa
    px(d, [(12, 11), (11, 12), (13, 12), (12, 13), (12, 14), (12, 15)], VIOLETA)
    return img


def cauldron() -> Image.Image:
    img, d = canvas(24)
    pot = shade(TINTA, 1.25)
    # burbujas turquesa
    d.ellipse([7, 2, 10, 5], fill=TURQUESA)
    d.ellipse([13, 0, 15, 2], fill=shade(TURQUESA, 1.3))
    d.ellipse([11, 4, 14, 7], fill=TURQUESA)
    # olla
    d.ellipse([2, 8, 21, 22], fill=pot)
    d.rectangle([1, 7, 22, 9], fill=shade(pot, 1.3))
    d.ellipse([4, 7, 19, 10], fill=TURQUESA)
    # brillo y patas
    d.arc([5, 11, 13, 19], 150, 220, fill=shade(pot, 1.6))
    d.rectangle([5, 21, 6, 23], fill=pot)
    d.rectangle([17, 21, 18, 23], fill=pot)
    return img


def grimoire() -> Image.Image:
    img, d = canvas(24)
    d.rectangle([4, 4, 20, 21], fill=shade(PERGAMINO, 0.9))
    d.rectangle([3, 3, 19, 20], fill=TURQUESA)
    d.rectangle([3, 3, 5, 20], fill=shade(TURQUESA, 0.65))
    d.rectangle([7, 6, 17, 17], outline=shade(TURQUESA, 0.75))
    star(d, 12, 11, DORADO, 2)
    px(d, [(11, 10), (13, 10), (11, 12), (13, 12)], shade(DORADO, 1.3))
    return img


def teacup() -> Image.Image:
    img, d = canvas(24)
    # vapor
    d.line([(9, 1), (8, 3), (9, 5), (8, 7)], fill=LAVANDA)
    d.line([(14, 2), (13, 4), (14, 6)], fill=LAVANDA)
    # taza
    d.rectangle([4, 9, 17, 17], fill=PERGAMINO)
    d.ellipse([4, 14, 17, 21], fill=PERGAMINO)
    d.rectangle([4, 9, 17, 10], fill=shade(NARANJA, 0.8))
    d.rectangle([4, 13, 17, 14], fill=VIOLETA)
    d.arc([15, 10, 21, 17], 270, 90, fill=PERGAMINO, width=2)
    # plato
    d.ellipse([1, 19, 21, 22], fill=shade(PERGAMINO, 0.85))
    return img


def candle_books(lit: bool) -> Image.Image:
    img, d = canvas(24)
    # pila de libros
    d.rectangle([2, 18, 21, 22], fill=VIOLETA)
    d.line([(3, 20), (20, 20)], fill=shade(VIOLETA, 1.4))
    d.rectangle([4, 14, 19, 17], fill=AZUL)
    d.line([(5, 15), (18, 15)], fill=shade(AZUL, 1.4))
    d.rectangle([3, 11, 17, 13], fill=VERDE)
    # vela
    d.rectangle([9, 7, 12, 10], fill=PERGAMINO)
    px(d, [(9, 8), (9, 9)], shade(PERGAMINO, 0.8))
    px(d, [(10, 6), (11, 6)], TINTA)
    if lit:
        d.polygon([(10, 0), (8, 4), (10, 6), (12, 4)], fill=NARANJA)
        d.polygon([(10, 2), (9, 4), (10, 5), (11, 4)], fill=PERGAMINO)
    return img


def star_icon() -> Image.Image:
    img, d = canvas(16)
    d.polygon([(8, 0), (10, 5), (15, 6), (11, 9), (12, 15), (8, 12), (4, 15), (5, 9), (1, 6), (6, 5)], fill=DORADO)
    px(d, [(7, 4), (7, 5), (6, 6)], shade(DORADO, 1.4))
    return img


# --- Casitas ------------------------------------------------------------------

def house(state: str) -> Image.Image:
    img, d = canvas(24)
    locked = state == "locked"
    wall = shade(PERGAMINO, 0.7) if locked else PERGAMINO
    roof = GRIS if locked else VIOLETA
    # chimenea
    d.rectangle([16, 3, 18, 8], fill=shade(MARRON, 0.9))
    # techo
    d.polygon([(12, 2), (1, 11), (23, 11)], fill=roof)
    d.line([(2, 11), (22, 11)], fill=shade(roof, 0.7))
    px(d, [(12, 4), (11, 5), (13, 5)], shade(roof, 1.3))
    # paredes
    d.rectangle([3, 11, 20, 22], fill=wall)
    d.line([(3, 22), (20, 22)], fill=shade(wall, 0.75))
    # ventana
    win = shade(GRIS, 0.8) if locked else shade(PERGAMINO, 1.2)
    d.rectangle([14, 13, 18, 16], fill=win)
    if not locked:
        px(d, [(15, 14), (16, 14)], PERGAMINO)
        d.line([(16, 13), (16, 16)], fill=MARRON)
    # puerta
    if locked:
        d.rectangle([6, 15, 10, 22], fill=MARRON)
        d.rectangle([6, 14, 10, 15], fill=shade(MARRON, 0.8))
        # candado
        d.arc([6, 13, 10, 18], 180, 360, fill=GRIS)
        d.rectangle([5, 16, 11, 20], fill=shade(GRIS, 1.4))
        px(d, [(8, 17), (8, 18)], TINTA)
    else:
        d.rectangle([6, 15, 10, 22], fill=shade(PERGAMINO, 1.0))
        d.rectangle([7, 16, 9, 22], fill=LAVANDA if state == "open" else TURQUESA)
        px(d, [(8, 17)], PERGAMINO)
        # luz que sale de la puerta
        if state == "open":
            px(d, [(5, 21), (11, 21), (4, 22), (12, 22)], LAVANDA)
    if state == "done":
        d.polygon([(19, 0), (20, 2), (23, 2), (21, 4), (22, 7), (19, 5), (16, 7), (17, 4), (15, 2), (18, 2)], fill=DORADO)
    return img


# --- Tiles y mapa -------------------------------------------------------------

def _noise(seed: int, n: int, size: int) -> list[tuple[int, int]]:
    pts, s = [], seed
    for _ in range(n):
        s = (s * 1103515245 + 12345) & 0x7FFFFFFF
        x = s % size
        s = (s * 1103515245 + 12345) & 0x7FFFFFFF
        pts.append((x, s % size))
    return pts


def tile_grass() -> Image.Image:
    img, d = canvas(16)
    d.rectangle([0, 0, 15, 15], fill=VERDE)
    for x, y in _noise(7, 10, 16):
        px(d, [(x, y), (x, max(0, y - 1))], shade(VERDE, 1.25))
    for x, y in _noise(31, 6, 16):
        px(d, [(x, y)], shade(VERDE, 0.8))
    return img


def tile_path() -> Image.Image:
    img, d = canvas(16)
    sand = shade(PERGAMINO, 0.82)
    d.rectangle([0, 0, 15, 15], fill=sand)
    for x, y in _noise(11, 8, 16):
        px(d, [(x, y)], shade(sand, 0.85))
    for x, y in _noise(5, 3, 15):
        px(d, [(x, y), (x + 1, y)], shade(MARRON, 1.4))
    return img


def tile_water() -> Image.Image:
    img, d = canvas(16)
    d.rectangle([0, 0, 15, 15], fill=AZUL)
    for (x, y) in [(2, 3), (9, 7), (4, 12), (12, 13)]:
        d.line([(x, y), (x + 2, y)], fill=shade(LAVANDA, 1.2))
        px(d, [(x + 3, y + 1)], shade(AZUL, 1.3))
    return img


def tree() -> Image.Image:
    img, d = canvas(16)
    d.rectangle([7, 11, 9, 15], fill=MARRON)
    d.ellipse([1, 1, 14, 13], fill=shade(VERDE, 0.8))
    d.ellipse([3, 2, 11, 9], fill=VERDE)
    px(d, [(5, 4), (6, 3), (8, 4)], shade(VERDE, 1.3))
    return img


def map_node(state: str) -> Image.Image:
    img, d = canvas(24)
    if state == "locked":
        d.ellipse([2, 2, 21, 21], fill=GRIS)
        d.ellipse([5, 5, 18, 18], fill=shade(GRIS, 0.8))
        d.arc([8, 5, 15, 13], 180, 360, fill=shade(PERGAMINO, 0.8), width=1)
        d.rectangle([7, 10, 16, 17], fill=shade(PERGAMINO, 0.8))
        px(d, [(11, 12), (12, 12), (11, 13), (12, 13), (11, 14)], TINTA)
    elif state == "done":
        d.ellipse([2, 2, 21, 21], fill=DORADO)
        d.ellipse([5, 5, 18, 18], fill=shade(DORADO, 0.85))
        d.polygon([(12, 6), (13, 10), (17, 10), (14, 13), (15, 17), (12, 15), (9, 17), (10, 13), (7, 10), (11, 10)], fill=PERGAMINO)
    else:
        d.ellipse([2, 2, 21, 21], fill=VIOLETA)
        d.ellipse([5, 5, 18, 18], fill=LAVANDA)
        d.ellipse([8, 8, 15, 15], fill=PERGAMINO)
        px(d, [(7, 7), (8, 6)], shade(LAVANDA, 1.3))
    return img


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    print(f"Generando sprites en {OUT}")
    sprites = {
        "player": player(),
        "ada": ada(),
        "owl": owl(),
        "byte_cat": byte_cat(),
        "gremlin_sintaxis": gremlin(),
        "fantasma_sin_nombre": fantasma(),
        "quimera_tipos": quimera(),
        "ouroboros": ouroboros(),
        "jar": jar(),
        "cauldron": cauldron(),
        "grimoire": grimoire(),
        "teacup": teacup(),
        "candle_books": candle_books(False),
        "candle_books_lit": candle_books(True),
        "star": star_icon(),
        "house_locked": house("locked"),
        "house_open": house("open"),
        "house_done": house("done"),
        "tree": tree(),
        "map_node": map_node("current"),
        "map_node_done": map_node("done"),
        "map_node_locked": map_node("locked"),
    }
    for name, img in sprites.items():
        save(img, name)
    for name, img in {"tile_grass": tile_grass(), "tile_path": tile_path(), "tile_water": tile_water()}.items():
        save(img, name, line=False)


if __name__ == "__main__":
    main()
