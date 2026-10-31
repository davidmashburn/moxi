"""Compile practical source edits, behavioral checks, and whole-candidate timing."""
from datetime import datetime, timezone
import difflib
import hashlib
import json
from pathlib import Path
import platform
import statistics
import sys
import subprocess
import tempfile

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def code_lines(text):
    # Docstrings are excluded with comments and blank lines; no token estimates.
    inside = False
    count = 0
    for line in text.splitlines():
        s = line.strip()
        if '"""' in s:
            if s.count('"""') % 2:
                inside = not inside
            continue
        if s and not s.startswith('#') and not inside:
            count += 1
    return count


def main():
    logs = Path(tempfile.mkdtemp(prefix='moxi-simple-composition-'))
    dirs = [HERE, ROOT/'experiments/typed-boundaries', ROOT/'experiments/state-access',
            ROOT/'experiments/method-binding', ROOT/'experiments/selective-updates']
    checks = []
    def run(name, source, extra=None, build=False):
        cmd = ['pixi','run','--locked','mojo', 'build' if build else 'run']
        if build: cmd += ['-O3']
        for directory in ([extra] if extra else []) + [ROOT/'src'] + dirs:
            cmd += ['-I', str(directory)]
        cmd += [str(source)]
        if build: cmd += ['-o', str(logs/'timing')]
        with (logs/(name+'.log')).open('w') as output:
            result = subprocess.run(cmd, cwd=ROOT, stdout=output, stderr=subprocess.STDOUT, timeout=240)
        text = (logs/(name+'.log')).read_text()
        assert result.returncode == 0, name+'\n'+text[-4000:]
        checks.append(dict(name=name, command=cmd, output=text))
        return text
    run('differential-and-identity', HERE/'probe.mojo')
    original = {
        'screen.mojo': (HERE/'screen.mojo').read_text(),
        'editor.mojo': (dirs[2]/'editor.mojo').read_text(),
        'domain.mojo': (dirs[2]/'domain.mojo').read_text(),
        'workbench.mojo': (dirs[1]/'workbench.mojo').read_text(),
    }
    common = '''from screen import Workbench
from runtime import HandlerHost, require
from moxi import App, Rect, Event, TextInputEvent, ActionEvent

def target(app: App[HandlerHost[Workbench]], key: Int, position: Int) -> Int:
    var path = "/k" + String(String(key).byte_length()) + ":" + String(key) + "/p" + String(position)
    for item in app.component.ui.controls:
        if item.active and item.path == path:
            return item.id
    require(False, "extension target")
    return -1

def action(id: Int) -> Event:
    var event = Event(ActionEvent(id))
    event.set_target(id)
    return event

def main():
    var app = App(HandlerHost(Workbench()), Rect(0, 0, 800, 5000))
'''
    extensions = []
    def extension(name, sources, body):
        folder = logs/name
        folder.mkdir()
        diffs = {}
        for file, before in original.items():
            after = sources.get(file, before)
            (folder/file).write_text(after)
            if before != after:
                diff = ''.join(difflib.unified_diff(before.splitlines(True), after.splitlines(True), fromfile=file, tofile=file))
                diffs[file] = dict(added_code_lines=code_lines(after)-code_lines(before), diff=diff)
        probe = folder/'extension.mojo'
        probe.write_text(common+body+f'    print("PASS {name}")\n')
        run(name, probe, folder)
        extensions.append(dict(name=name, files=diffs, probe=probe.read_text()))
    editor = original['editor.mojo'].replace('    var note: String', '    var note: String\n    var reviewer: String').replace('        self.note = ""', '        self.note = ""\n        self.reviewer = ""')
    editor = editor.replace('    def apply(', '    def set_reviewer(mut self, value: String):\n        self.reviewer = value\n\n    def apply(')
    editor += '        ui.text_input("Reviewer", self.reviewer, Self.set_reviewer)\n'
    extension('add-field', {'editor.mojo':editor}, '''    var event = Event(TextInputEvent("Reviewer"))
    event.set_target(target(app, 2, 9))
    require(app.update(event), "reviewer edit")
    require(app.component.root.left.reviewer == "Reviewer", "local reviewer field")
    require(app.component.root.right.reviewer == "", "private reviewer field")
''')
    screen = original['screen.mojo'].replace('struct Workbench(Screen):', 'comptime EXTRA = 8\n\nstruct Workbench(Screen):').replace('    var left: Editor','    var extra: Editor\n    var left: Editor').replace('        self.left = Editor(self.services)', '        self.extra = Editor(self.services)\n        self.left = Editor(self.services)')
    screen = screen.replace('    def render(self,', '    def route_extra(mut self, key: Int, action: Action[Editor, Services]):\n        if key == EXTRA:\n            action(self.extra, self.services)\n\n    def render(self,')
    screen += '        ui.child(self.extra, self.services, Self.route_extra, key=EXTRA)\n'
    extension('add-child', {'screen.mojo':screen}, '''    var event = Event(TextInputEvent("Extra", 0, 1000000))
    event.set_target(target(app, 8, 2))
    require(app.update(event), "extra draft")
    require(app.component.root.left.draft == "Ada", "existing child unchanged")
    require(app.update(action(target(app, 8, 5))), "extra apply")
    require(app.component.root.services.document.name == "Extra", "new child uses shared services")
''')
    domain = original['domain.mojo'].replace('    var unrelated: Int', '    var unrelated: Int\n    var show_revision: Bool').replace('        self.unrelated = 0', '        self.unrelated = 0\n        self.show_revision = False')
    panels = original['workbench.mojo'].replace('    def set_explanation(', '    def toggle_revision(mut self, mut settings: Settings):\n        settings.show_revision = not settings.show_revision\n    def set_explanation(').replace('        ui.text_input("Policy note", self.explanation, Self.set_explanation)', '        ui.text_input("Policy note", self.explanation, Self.set_explanation)\n        ui.button("Show revision", Self.toggle_revision)')
    editor = original['editor.mojo']+'        if services.settings.show_revision:\n            ui.label("Editor revision: " + String(services.document.revision))\n'
    extension('add-shared-setting', {'domain.mojo':domain, 'workbench.mojo':panels, 'editor.mojo':editor}, '''    require(app.update(action(target(app, 4, 6))), "setting toggle")
    require(app.component.root.services.settings.show_revision, "shared setting changed")
    var labels = 0
    for i in range(app.view.child_count()):
        if app.view.child(i).text == "Editor revision: 0":
            labels += 1
    require(labels == 3, "all three editor consumers refresh")
''')
    run('timing-build', HERE/'timing.mojo', build=True)
    paths=[ROOT/'pixi.lock', ROOT/'pixi.toml', *ROOT.glob('src/**/*.mojo')]
    for folder in dirs: paths+=list(folder.glob('*.mojo'))
    paths += list(HERE.glob('*.py'))
    counts={str(p.relative_to(ROOT)):code_lines(p.read_text()) for p in [dirs[1]/'workbench.mojo', dirs[1]/'host.mojo', dirs[1]/'boundary.mojo', HERE/'screen.mojo', dirs[3]/'runtime.mojo', dirs[3]/'bindings.mojo', dirs[2]/'editor.mojo']}
    counts['baseline_root_only'] = code_lines(original['workbench.mojo'][original['workbench.mojo'].index('struct Workbench('):])
    host = (dirs[1]/'host.mojo').read_text()
    counts['baseline_host_without_counter_methods'] = code_lines(host[:host.index('    def reset_counts')])
    report=dict(timestamp=datetime.now(timezone.utc).isoformat(), compiler=subprocess.check_output(['pixi','run','--locked','mojo','--version'],cwd=ROOT,text=True).strip(), machine=platform.platform(),logs=str(logs),checks=checks,extensions=extensions,counts=counts,
                source_hashes={str(p.relative_to(ROOT)):sha(p) for p in sorted(set(paths))},
                protocol='O3; eight heterogeneous panes; two warmups/five samples; rotating three-mode order; real App update + paint; setup/checks/destruction excluded. Topology differs: simple is flat, typed hosts have component surfaces. Whole-candidate comparison, not isolated cache attribution. Unisolated machine.',
                binary_sha256=sha(logs/"timing"))
    (logs/'prepared.json').write_text(json.dumps(report,indent=2)+'\n')
    if '--prepare' in sys.argv:
        print('PREPARED', logs/'prepared.json')
    else:
        measure(report)


def measure(report):
    logs = Path(report['logs'])
    for name, digest in report['source_hashes'].items():
        assert sha(ROOT/name) == digest, name
    assert sha(logs/'timing') == report['binary_sha256']
    output = subprocess.check_output([str(logs/'timing')], cwd=ROOT, text=True, timeout=180)
    (logs/'timing.log').write_text(output)
    rows=[]
    for line in output.splitlines():
        if not line.startswith('TIMING '): continue
        _, history, shared, sample, *times = line.split()
        row = dict(history=int(history), shared=shared=='True', sample=int(sample))
        for i, mode in enumerate(('simple','cached','forced')):
            row[mode+'_update_ns'], row[mode+'_paint_ns'] = map(int,times[2*i:2*i+2])
            row[mode+'_frame_ns'] = row[mode+'_update_ns']+row[mode+'_paint_ns']
        rows.append(row)
    assert len(rows)==20 and 'PASS 60 candidate frames' in output
    summaries=[]
    for history in (0,10000):
        for shared in (False,True):
            subset=[r for r in rows if r['history']==history and r['shared']==shared]
            summaries.append(dict(history=history,shared=shared,stats={key:dict(median=statistics.median(r[key] for r in subset), min=min(r[key] for r in subset), max=max(r[key] for r in subset)) for key in rows[0] if key.endswith('_ns')}))
    report.update(raw_stdout=output, samples=rows, summaries=summaries,
                  measurement_timestamp=datetime.now(timezone.utc).isoformat())
    (HERE/'results.json').write_text(json.dumps(report,indent=2)+'\n')
    print('PASS',len(report['checks']),'compiled programs; three source-edit tasks; 60 candidate frames; logs:',logs)

if __name__=='__main__':
    if len(sys.argv) == 3 and sys.argv[1] == '--measure':
        measure(json.loads(Path(sys.argv[2]).read_text()))
    else:
        main()
