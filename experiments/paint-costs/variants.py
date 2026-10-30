"""Create temporary runtime variants; never modify production source."""
from enum import Enum
import re


class Variant(str, Enum):
    BASELINE = "baseline"
    COMMANDS = "commands"
    FACTS = "facts"
    COMBINED = "combined"


def replace_once(source, before, after):
    assert source.count(before) == 1, before[:100]
    return source.replace(before, after)


def transform(source, variant):
    if variant is Variant.BASELINE:
        return source
    start = source.index("    def paint(mut self) -> PaintCommands:")
    end = source.index("    def accessibility(self)", start)
    paint = source[start:end]
    setup = ""
    if variant in (Variant.COMMANDS, Variant.COMBINED):
        setup += '''        var prior = Dict[Tuple[Int, Int], Int]()
        for i in range(len(self.previous_commands)):
            ref c = self.previous_commands[i]
            var key = (c.kind, c.id)
            if key not in prior:
                prior[key] = i
'''
        paint, n = re.subn(r"self.previous_command_index\((\w+)\)",
                           r"prior.get((\1.kind, \1.id), -1)", paint)
        assert n == 4
        paint, n = re.subn(r"self.command_changed\((\w+)\)",
                           r"_indexed_changed(prior, self.previous_commands, \1)", paint)
        assert n == 6
        before = '''        for previous_index in range(len(self.previous_commands)):
            var previous = self.previous_commands[previous_index]
            var found = False
            for current_index in range(commands.count()):
                var current = commands.command(current_index)
                if (
                    current.kind == previous.kind
                    and current.id == previous.id
                ):
                    found = True
                    break
            if not found:
                commands.mark_removed(previous.bounds)
'''
        after = '''        var current_ids = Dict[Tuple[Int, Int], Bool]()
        for i in range(commands.count()):
            var current = commands.command(i)
            current_ids[(current.kind, current.id)] = True
        for previous_index in range(len(self.previous_commands)):
            var previous = self.previous_commands[previous_index]
            if (previous.kind, previous.id) not in current_ids:
                commands.mark_removed(previous.bounds)
'''
        paint = replace_once(paint, before, after)
    if variant in (Variant.FACTS, Variant.COMBINED):
        setup += '''        var root_scrollable = self._root_is_scrollable()
        var parents = Dict[Int, Int]()
        var scrollable = Dict[Int, Bool]()
        for i in range(self.widget_count()):
            var w = self.widget(i)
            if w.id not in parents:
                parents[w.id] = i
            scrollable[w.id] = self._container_is_scrollable(w)
'''
        assert paint.count("self._root_is_scrollable()") == 4
        paint = paint.replace("self._root_is_scrollable()", "root_scrollable")
        paint, n = re.subn(r"self._container_is_scrollable\((\w+)\)",
                           r"scrollable.get(\1.id, False)", paint)
        assert n == 4
        # Preserve each ancestor walk and clipping order; replace its linear
        # search with the first active widget bearing that ID.
        pattern = r"(?m)^( +)for parent_index in range\(self.widget_count\(\)\):\n\1    var parent = self.widget\(parent_index\)\n\1    if parent.id == parent_id:\n((?:\1        .*\n)+)"
        def parent_lookup(match):
            indent, body = match.groups()
            assert body.endswith(indent + "        break\n")
            body = body[:-(len(indent) + len("        break\n"))]
            body = "\n".join(line[4:] for line in body.split("\n") if line) + "\n"
            return (indent + "var parent_index = parents.get(parent_id, -1)\n"
                    + indent + "if parent_index != -1:\n"
                    + indent + "    var parent = self.widget(parent_index)\n" + body)
        paint, n = re.subn(pattern, parent_lookup, paint)
        assert n == 2
    paint = replace_once(paint, "        var commands = PaintCommands()", setup + "        var commands = PaintCommands()")
    source = source[:start] + paint + source[end:]
    source = replace_once(source, "from std.collections import List", "from std.collections import List, Dict")
    if variant in (Variant.COMMANDS, Variant.COMBINED):
        helper = '''def _indexed_changed(prior: Dict[Tuple[Int, Int], Int], previous: List[PaintCommand], command: PaintCommand) -> Bool:
    var index = prior.get((command.kind, command.id), -1)
    return index == -1 or not previous[index].equivalent(command)


'''
        source = replace_once(source, "struct ColumnRuntime:", helper + "struct ColumnRuntime:")
    return source
