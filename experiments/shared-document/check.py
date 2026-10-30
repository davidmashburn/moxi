"""Matched checks and compiled extension trials; no new UI runtime.

Materialized inputs/diffs are kept in the reported temporary directory. The shared
common scenario bodies come from the original gate, with only ownership-access
syntax adapted. The distinct copy semantics are tested separately.
"""
from datetime import datetime, timezone
import difflib
import hashlib
import json
from pathlib import Path
import re
import subprocess
import tempfile

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
BASE = ROOT / 'experiments/composition-gate'


def capture(command):
    return subprocess.check_output(command, cwd=ROOT, text=True).strip()


def shared_scenarios(source):
    source = source[:source.index('\ndef copy_isolation():')]
    source = source.replace('action(self.workspace.editors[index], self.workspace.document, text)',
                            'action(self.workspace.editors[index], text)')
    source = source.replace('editor_view(ui, editor, self.workspace.document)',
                            'editor_view(ui, editor)')
    source = re.sub(r'len\(([^\n()]+\.document)\.history\)', r'\1.history_count()', source)
    source = re.sub(r'(\.document\.(?:name|revision|commits))\b', r'\1()', source)
    return source + '\n\ndef main():\n    drafts_and_history()\n    owner_policy()\n    identity_and_composition()\n'


def extend_editor(source, shared):
    source = source.replace('    var note: String', '    var reviewer: String\n    var note: String')
    source = source.replace('        self.note = ""', '        self.reviewer = ""\n        self.note = ""')
    source = source.replace('    def set_note(', '    def set_reviewer(mut self, text: String):\n        self.reviewer = text\n\n    def set_note(')
    bridge = '' if shared else '''def write_reviewer(mut editor: Editor, mut document: Document, text: String):
    editor.set_reviewer(text)


'''
    method = 'Editor.set_reviewer' if shared else 'write_reviewer'
    bridge += f'''def reviewer_changed[R: EditorRoute](mut root: R, key: Int, text: String):
    root.route_editor(key, {method}, text)


'''
    source = source.replace('def editor_view[', bridge + 'def editor_view[')
    return source.replace('    ui.end_scope()', '    ui.text_input_for("Reviewer", editor.reviewer, reviewer_changed[R], editor.key)\n    ui.end_scope()')


EXTENSION_CHECK = '''

def extensions():
    var app = App(HandlerHost(Application()), Rect(0, 0, 640, 2400))
    replace(app, "/k8:editor-1/p9", "first reviewer")
    test_check(app.component.root.shell.workspace.editors[0].reviewer == "first reviewer")
    test_check(app.component.root.shell.workspace.editors[1].reviewer == "")
    click(app, "/p4")
    replace(app, "/k8:editor-3/p9", "third reviewer")
    test_check(app.component.root.shell.workspace.editors[2].reviewer == "third reviewer")
    test_check(app.component.root.shell.workspace.editors[0].reviewer == "first reviewer")
    replace(app, "/k8:editor-3/p2", "Ada3")
    click(app, "/k8:editor-3/p5")
    test_check(app.component.root.shell.workspace.editors[2].error == "Digits are not allowed")
    test_check(DOCUMENT_NAME == "Ada")
    replace(app, "/k8:editor-1/p2", "Lin2")
    click(app, "/k8:editor-1/p5")
    test_check(app.component.root.shell.workspace.editors[0].error == "Digits are not allowed")
    test_check(DOCUMENT_COMMITS == 0)
    replace(app, "/k8:editor-3/p2", "Grace")
    click(app, "/k8:editor-3/p5")
    test_check(DOCUMENT_NAME == "Grace")
    test_check(DOCUMENT_COMMITS == 1)
    test_check(app.component.root.shell.workspace.editors[2].reviewer == "third reviewer")
    click(app, "/p1")
    test_check(DOCUMENT_NAME == "Ada")
    test_check(app.component.root.shell.workspace.editors[0].reviewer == "first reviewer")
    print("PASS extension: independent reviewer field, third editor, centralized digit policy, unchanged undo/local state")
'''


def counts(paths):
    result = {}
    for path in paths:
        lines = path.read_text().splitlines()
        result[path.name] = {'physical_lines': len(lines),
            'nonblank_noncomment_lines': sum(bool(s.strip()) and not s.lstrip().startswith(('#', '"""')) for s in lines),
            'function_definitions': sum(bool(re.match(r'\s*def ', s)) for s in lines)}
    return result


def main():
    work = Path(tempfile.mkdtemp(prefix='moxi-shared-document-'))
    report = {'timestamp': datetime.now(timezone.utc).isoformat(),
              'baseline': capture(['git','rev-parse','HEAD']),
              'branch': capture(['git','branch','--show-current']),
              'compiler': capture(['pixi','run','--locked','mojo','--version']),
              'scope': 'Matched real App synthetic events, compiled local-field/policy extension, handle semantics. No native, performance, async, multi-window or usability testing.',
              'checks': [], 'source_cost': {}, 'extension_diffs': {},
              'common_runtime_cost': counts([ROOT/'experiments/handler-api/runtime.mojo']),
              'alternate_root_cost': {}}
    original = (BASE/'check.mojo').read_text()
    jobs = []
    for shared in (False, True):
        name = 'shared' if shared else 'current'
        folder = work/name
        folder.mkdir()
        source_folder = HERE if shared else BASE
        for filename in ('application.mojo','editor.mojo'):
            (folder/filename).write_text((source_folder/filename).read_text())
        (folder/'document.mojo').write_text((BASE/'document.mojo').read_text())
        if shared:
            (folder/'document_handle.mojo').write_text((HERE/'document_handle.mojo').read_text())
        scenario = shared_scenarios(original) if shared else original
        (folder/'check.mojo').write_text(scenario)
        alternate = scenario[scenario.index('struct FlatApplication'):scenario.index('def drafts_and_history')].splitlines()
        report['alternate_root_cost'][name] = sum(bool(line.strip()) and not line.lstrip().startswith(('///', '"""', '#')) for line in alternate)
        report['source_cost'][name] = counts([folder/f for f in ('document.mojo','editor.mojo','application.mojo')] + ([folder/'document_handle.mojo'] if shared else []))
        jobs.append((name+'-behavior', folder, folder/'check.mojo'))
        semantics = HERE/('semantics.mojo' if shared else 'current_semantics.mojo')
        (folder/'semantics.mojo').write_text(semantics.read_text())
        jobs.append((name+'-semantics', folder, folder/'semantics.mojo'))
        extended = work/(name+'-extended')
        extended.mkdir()
        diffs = []
        for path in folder.glob('*.mojo'):
            if path.name in ('check.mojo','semantics.mojo'):
                continue
            before = path.read_text()
            after = before
            if path.name == 'editor.mojo':
                after = extend_editor(before, shared)
            if path.name == 'document.mojo':
                after = before.replace('        if normalized == self.name:',
                    '        for digit in "0123456789":\n            if String(digit) in normalized:\n                return "Digits are not allowed"\n        if normalized == self.name:')
            (extended/path.name).write_text(after)
            diffs.extend(difflib.unified_diff(before.splitlines(True), after.splitlines(True), fromfile=name+'/'+path.name, tofile=name+'-extended/'+path.name))
        diff = ''.join(diffs)
        (work/(name+'-extension.diff')).write_text(diff)
        report['extension_diffs'][name] = diff
        report['source_cost'][name+'-extended'] = counts(list(extended.glob('*.mojo')))
        check = EXTENSION_CHECK.replace('DOCUMENT_NAME', 'app.component.root.shell.workspace.document.name'+('()' if shared else '')).replace('DOCUMENT_COMMITS','app.component.root.shell.workspace.document.commits'+('()' if shared else ''))
        # Preserve the entire common suite and run the added behavior after it.
        scenario = scenario.replace('\ndef main():',check+'\n\ndef main():') + '    extensions()\n'
        (extended/'check.mojo').write_text(scenario)
        jobs.append((name+'-extensions', extended, extended/'check.mojo'))
    paths = [ROOT/'pixi.lock', HERE/'check.py']
    for folder in (HERE, BASE, ROOT/'experiments/handler-api', ROOT/'src'):
        paths.extend(folder.rglob('*.mojo'))
    report['sources'] = {str(p.relative_to(ROOT)): hashlib.sha256(p.read_bytes()).hexdigest() for p in sorted(set(paths))}
    report['materialized_sources'] = {str(p.relative_to(work)): hashlib.sha256(p.read_bytes()).hexdigest() for p in sorted(work.rglob('*.mojo'))}
    for label, folder, script in jobs:
        command = ['pixi','run','--locked','mojo','run','-I','src','-I','experiments/handler-api','-I',str(folder),str(script)]
        log_path = work/(label+'.log')
        with log_path.open('w') as log:
            result = subprocess.run(command,cwd=ROOT,stdout=log,stderr=subprocess.STDOUT)
        output = log_path.read_text()
        # Paths in compiler diagnostics are local run details, not published provenance.
        report['checks'].append({'name':label,'command':[x.replace(str(work),'<work>') for x in command], 'exit_code':result.returncode,'output':output.replace(str(work),'<work>')})
    (HERE/'results.json').write_text(json.dumps(report,indent=2)+'\n')
    print('Materialized source, diffs and full logs:',work)
    for check in report['checks']:
        print(check['name'], 'PASS' if check['exit_code']==0 else 'FAIL')
        print('\n'.join(check['output'].splitlines()[:12]))
    raise SystemExit(any(c['exit_code'] != 0 for c in report['checks']))


if __name__ == '__main__':
    main()
