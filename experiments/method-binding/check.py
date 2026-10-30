"""Matched integration, extension and callback-lifetime checks with provenance."""
from datetime import datetime, timezone
import difflib
import hashlib
import importlib.util
import json
from pathlib import Path
import subprocess
import tempfile

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
BASE = ROOT / 'experiments/composition-gate'
OLD = ROOT / 'experiments/handler-api'


def capture(command):
    return subprocess.check_output(command, cwd=ROOT, text=True).strip()


def adapt_common(source):
    source = source.replace('from editor import EditorAction, EditorRoute, editor_view',
                            'from editor import Editor\nfrom document import Document\nfrom bindings import Action')
    source = source.replace('FlatApplication(Screen, EditorRoute)', 'FlatApplication(Screen)')
    source = source.replace('action: EditorAction, text: String', 'action: Action[Editor, Document]')
    source = source.replace('self.workspace.document, text)', 'self.workspace.document)')
    source = source.replace('editor_view(ui, editor, self.workspace.document)',
                            'ui.child(editor, self.workspace.document, Self.route_editor, key=editor.key)')
    for key in (1, 2, 3):
        source = source.replace(f'/k8:editor-{key}', f'/k1:{key}')
    return source


def count(path):
    lines = path.read_text().splitlines()
    return {'physical_lines': len(lines), 'nonblank_noncomment_lines':
            sum(bool(s.strip()) and not s.lstrip().startswith(('#', '"""')) for s in lines)}


def main():
    work = Path(tempfile.mkdtemp(prefix='moxi-method-binding-'))
    report = {'timestamp': datetime.now(timezone.utc).isoformat(),
              'baseline': capture(['git', 'rev-parse', 'HEAD']),
              'branch': capture(['git', 'branch', '--show-current']),
              'compiler': capture(['pixi', 'run', '--locked', 'mojo', '--version']),
              'scope': 'Synthetic events through real App, matched composition assertions, nested context routing, descriptor lifetime, local-field/policy extension and render mutation rejection. No native or usability test; no performance benchmark.',
              'checks': []}
    common = adapt_common((BASE/'check.mojo').read_text())
    assert common == (HERE/'check.mojo').read_text(), 'Common assertions drifted'
    normal = work/'normal'
    normal.mkdir()
    for name in ('runtime.mojo', 'bindings.mojo', 'editor.mojo', 'application.mojo',
                 'check.mojo', 'nested.mojo', 'lifetime.mojo'):
        (normal/name).write_text((HERE/name).read_text())
    (normal/'document.mojo').write_text((BASE/'document.mojo').read_text())
    # Root-level control behavior is unchanged; retain exactly the old assertions.
    controls = (OLD/'check.mojo').read_text().replace(
        'from examples import Counters, GreetingForm, TwoForms, Rows, Row',
        'from control_examples import Counters, GreetingForm')
    controls = controls[:controls.index('    var nested = App')]
    (normal/'controls.mojo').write_text(controls)
    examples = (OLD/'examples.mojo').read_text()
    (normal/'control_examples.mojo').write_text(examples[:examples.index('struct TwoForms')])
    spec = importlib.util.spec_from_file_location('shared_check', ROOT/'experiments/shared-document/check.py')
    shared = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(shared)
    extended = work/'extended'
    extended.mkdir()
    diffs = []
    for path in normal.glob('*.mojo'):
        before = path.read_text()
        after = before
        if path.name == 'editor.mojo':
            after = after.replace('    var note: String', '    var reviewer: String\n    var note: String')
            after = after.replace('        self.note = ""', '        self.reviewer = ""\n        self.note = ""')
            after = after.replace('    def set_note(', '    def set_reviewer(mut self, text: String):\n        self.reviewer = text\n\n    def set_note(')
            after += '        ui.text_input("Reviewer", self.reviewer, Self.set_reviewer)\n'
        if path.name == 'document.mojo':
            after = before.replace('        if normalized == self.name:',
                '        for digit in "0123456789":\n            if String(digit) in normalized:\n                return "Digits are not allowed"\n        if normalized == self.name:')
        if path.name == 'check.mojo':
            extension = shared.EXTENSION_CHECK.replace('DOCUMENT_NAME', 'app.component.root.shell.workspace.document.name').replace('DOCUMENT_COMMITS', 'app.component.root.shell.workspace.document.commits')
            for key in (1, 2, 3):
                extension = extension.replace(f'/k8:editor-{key}', f'/k1:{key}')
            after = before.replace('\ndef main():', extension+'\n\ndef main():') + '    extensions()\n'
        (extended/path.name).write_text(after)
        if path.name in ('editor.mojo', 'document.mojo', 'application.mojo'):
            diffs.extend(difflib.unified_diff(before.splitlines(True), after.splitlines(True), fromfile='normal/'+path.name, tofile='extended/'+path.name))
    instrumented = work/'instrumented'
    instrumented.mkdir()
    for path in normal.glob('*.mojo'):
        source = path.read_text()
        if path.name == 'bindings.mojo':
            source = source.replace('        self.drop = _destroy[T]', '        self.drop = _destroy[T]\n        print(1)')
            source = source.replace('        self.drop(self.raw)', '        self.drop(self.raw)\n        print(-1)')
        (instrumented/path.name).write_text(source)
    (instrumented/'allocations.mojo').write_text('from runtime import HandlerHost\nfrom application import Application\ndef main():\n    var host = HandlerHost(Application())\n    host.refresh()\n    _ = host\n')
    report['extension_diff'] = ''.join(diffs)
    (work/'extension.diff').write_text(report['extension_diff'])
    report['authoring_cost'] = {
        'previous': {name: count(BASE/name) for name in ('document.mojo','editor.mojo','application.mojo')},
        'direct': {name: count(normal/name) for name in ('document.mojo','editor.mojo','application.mojo')},
        'extended': {name: count(extended/name) for name in ('document.mojo','editor.mojo','application.mojo')}}
    report['runtime_cost'] = {'previous': count(OLD/'runtime.mojo'),
                            'direct': {name: count(HERE/name) for name in ('runtime.mojo','bindings.mojo')}}
    paths = [ROOT/'pixi.lock', HERE/'check.py', ROOT/'experiments/shared-document/check.py']
    for folder in (HERE, BASE, OLD, ROOT/'src'):
        paths.extend(folder.rglob('*.mojo'))
    report['sources'] = {str(p.relative_to(ROOT)): hashlib.sha256(p.read_bytes()).hexdigest() for p in sorted(set(paths))}
    report['materialized_sources'] = {str(p.relative_to(work)): hashlib.sha256(p.read_bytes()).hexdigest() for p in sorted(work.rglob('*.mojo'))}
    jobs = [('baseline', BASE/'check.mojo', [OLD,BASE], False)]
    jobs += [(name, normal/(name+'.mojo'), [normal], False) for name in ('check','controls','nested','lifetime')]
    jobs += [('extension', extended/'check.mojo', [extended], False),
             ('allocations', instrumented/'allocations.mojo', [instrumented], False),
             ('render-mutation', HERE/'diagnostics/render_mutation.mojo', [normal], True)]
    for name, script, includes, reject in jobs:
        command = ['pixi','run','--locked','mojo','run','-I','src']
        for folder in includes:
            command += ['-I',str(folder)]
        command += [str(script)]
        with (work/(name+'.log')).open('w') as log:
            result = subprocess.run(command,cwd=ROOT,stdout=log,stderr=subprocess.STDOUT)
        output = (work/(name+'.log')).read_text()
        passed = (result.returncode != 0 and 'invalid use of mutating method' in output and 'crash backtrace' not in output) if reject else result.returncode == 0
        if name == 'allocations' and result.returncode == 0:
            live = peak = created = destroyed = 0
            for line in output.splitlines():
                delta = int(line)
                assert delta in (-1, 1)
                live += delta
                peak = max(peak, live)
                created += delta == 1
                destroyed += delta == -1
                assert live >= 0
            passed = live == 0 and created == destroyed == 40
            report['descriptor_lifetimes'] = {'renders':2,'created':created,'destroyed':destroyed,
                'peak_live':peak,'live_after_host_drop':live,
                'allocation_sites_per_descriptor':2,
                'note':'Instrumented Storage constructor/destructor calls; two allocation sites are payload alloc and ArcPointer. This is not allocator profiling or a timing benchmark.'}
            output = f'{created} descriptors created and destroyed over two renders; peak {peak}; final live {live}\n'
        report['checks'].append({'name':name,'expected_compile_rejection':reject,
            'passed':passed,'exit_code':result.returncode,
            'command':[x.replace(str(work),'<work>').replace(str(ROOT),'<repo>') for x in command],
            'output':output.replace(str(work),'<work>').replace(str(ROOT),'<repo>')})
    (HERE/'results.json').write_text(json.dumps(report,indent=2)+'\n')
    print('Materialized sources, extension diff and full logs:',work)
    for check in report['checks']:
        print(check['name'], 'PASS' if check['passed'] else 'FAIL')
        print('\n'.join(check['output'].splitlines()[:4]))
    raise SystemExit(any(not c['passed'] for c in report['checks']))


if __name__ == '__main__':
    main()
