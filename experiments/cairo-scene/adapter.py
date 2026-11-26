"""Bounded replay of the exporter's Scene operations on either Cairo surface."""

import io
from enum import Enum
from math import pi

import cairocffi as cairo
from PIL import Image


class Op(Enum):
    RECT = "rect"
    CLIP = "clip"
    UNCLIP = "unclip"
    TRANSFORM = "transform"
    RESET = "reset"
    LAYER = "layer"
    END_LAYER = "endlayer"
    LINE = "line"
    PATH = "path"
    GRADIENT = "gradient"
    TEXT = "text"
    BITMAP = "bitmap"
    MISSING = "missing-resource"


def rounded_rect(ctx, x, y, w, h, r):
    if not r:
        ctx.rectangle(x, y, w, h)
        return
    for cx, cy, angle in [
        (x + w - r, y + r, -pi / 2),
        (x + w - r, y + h - r, 0),
        (x + r, y + h - r, pi / 2),
        (x + r, y + r, pi),
    ]:
        ctx.arc(cx, cy, r, angle, angle + pi / 2)
    ctx.close_path()


def draw(surface, header, lines):
    ctx = cairo.Context(surface)
    ctx.set_source_rgba(*header[2:])
    ctx.paint()
    layers = [1.0]
    missing = []
    for line in lines:
        opacity, name, *args = line.split()
        op = Op(name)
        alpha = layers[-1] * float(opacity)

        def numbers(start, end):
            return [float(v) for v in args[start:end]]

        def source(offset):
            r, g, b, a = numbers(offset, offset + 4)
            ctx.set_source_rgba(r, g, b, a * alpha)

        if op is Op.RECT:
            rounded_rect(ctx, *numbers(0, 5))
            source(5)
            ctx.fill()
        elif op is Op.CLIP:
            ctx.save()
            ctx.rectangle(*numbers(0, 4))
            ctx.clip()
        elif op is Op.UNCLIP:
            matrix = ctx.get_matrix()
            ctx.restore()
            ctx.set_matrix(matrix)
        elif op is Op.TRANSFORM:
            ctx.transform(cairo.Matrix(*numbers(0, 6)))
        elif op is Op.RESET:
            ctx.identity_matrix()
        elif op is Op.LAYER:
            layers.append(layers[-1] * float(args[0]))
        elif op is Op.END_LAYER:
            layers.pop()
        elif op is Op.LINE:
            ctx.move_to(*numbers(0, 2))
            ctx.line_to(*numbers(2, 4))
            ctx.set_line_width(float(args[4]))
            source(5)
            ctx.stroke()
        elif op is Op.PATH:
            # The bounded typed-path cell uses only M, L and Z.
            tokens = iter(args[9:])
            for verb in tokens:
                if verb == "Z":
                    ctx.close_path()
                else:
                    method = {"M": ctx.move_to, "L": ctx.line_to}[verb]
                    method(float(next(tokens)), float(next(tokens)))
            source(0)
            ctx.set_fill_rule(cairo.FILL_RULE_EVEN_ODD)
            ctx.fill_preserve()
            source(4)
            if float(args[8]) > 0:
                ctx.set_line_width(float(args[8]))
                ctx.stroke()
            ctx.new_path()
        elif op is Op.GRADIENT:
            grad = cairo.LinearGradient(*numbers(4, 8))
            for stop, offset in enumerate([8, 12]):
                r, g, b, a = numbers(offset, offset + 4)
                grad.add_color_stop_rgba(stop, r, g, b, a * alpha)
            ctx.set_source(grad)
            ctx.rectangle(*numbers(0, 4))
            ctx.fill()
        elif op is Op.TEXT:
            x, y, _, h = numbers(0, 4)
            ctx.move_to(x, y + h)
            ctx.set_font_size(16)
            source(4)
            ctx.show_text(line.split(maxsplit=10)[10])
        elif op is Op.BITMAP:
            x, y, w, h = numbers(0, 4)
            size = int(args[4]), int(args[5])
            image = Image.frombytes("RGBA", size, bytes(map(int, args[6:])))
            data = io.BytesIO()
            image.save(data, format="PNG")
            data.seek(0)
            bitmap = cairo.ImageSurface.create_from_png(data)
            ctx.save()
            ctx.translate(x, y)
            ctx.scale(w / size[0], h / size[1])
            ctx.set_source_surface(bitmap)
            ctx.get_source().set_filter(cairo.FILTER_NEAREST)
            ctx.paint_with_alpha(alpha)
            ctx.restore()
        elif op is Op.MISSING:
            missing.append(int(args[4]))
    return missing
