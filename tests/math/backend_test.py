"""Actual persistent selected-subtree transport, lifecycle and failure checks."""
import os
import sys
import time
import unittest
from moxi_math.backend import Source, Notation as N, Computation, State, project, text
from moxi_math_probe.model import BoundaryError, Kind, Operation, integer, symbol, node as semantic_node

def token(s, identity=1): return Source(N.TOKEN,s,'',(),identity)
def node(k,*children,identity=10,text='',extra=''): return Source(k,text,extra,children,identity)
def polynomial():
    return node(N.SCRIPTS,node(N.GROUP,node(N.ROW,token('x'),token('+'),token('1')),text='(',extra=')'),node(N.HOLE),token('3'),node(N.HOLE),node(N.HOLE),identity=43)
def wait(c,revision):
    until=time.monotonic()+8
    while not c.tick(revision):
        if time.monotonic()>until: raise AssertionError('worker deadline')
        time.sleep(.005)

class BackendTests(unittest.TestCase):
    def setUp(self): self.c=Computation()
    def tearDown(self): self.c.close()
    def test_persistent_expand_differentiate(self):
        self.assertTrue(self.c.submit(polynomial(),[],Operation.EXPAND,7))
        wait(self.c,7)
        self.assertEqual(self.c.state,State.READY,self.c.message)
        self.assertEqual(self.c.target,43)
        self.assertIn('scripts(x, ?, 3',self.c.result)
        process=self.c.controller.process
        self.assertTrue(self.c.eligible(7)); self.assertFalse(self.c.eligible(8))
        self.assertTrue(self.c.submit(polynomial(),[],Operation.DIFFERENTIATE,8))
        wait(self.c,8)
        self.assertEqual(self.c.state,State.READY,self.c.message)
        self.assertIs(self.c.controller.process,process)
        self.assertEqual(len(self.c.controller.startups),1)
    def test_stale_and_close(self):
        self.assertTrue(self.c.submit(polynomial(),[],Operation.EXPAND,7))
        wait(self.c,8)
        self.assertEqual(self.c.state,State.STALE)
        self.assertTrue(self.c.result); self.assertFalse(self.c.eligible(8))
        process=self.c.controller.process
        self.c.close()
        self.assertIsNotNone(process.poll())
        self.assertFalse(self.c.submit(polynomial(),[],Operation.EXPAND,8))
    def test_exact_evaluation_and_substitution(self):
        self.assertTrue(self.c.submit(node(N.FRACTION,token('2'),token('4')),[],Operation.EVALUATE,1))
        wait(self.c,1)
        self.assertEqual(self.c.result,'frac(1, 2)')
        self.assertTrue(self.c.submit(polynomial(),[],Operation.SUBSTITUTE,2,token('2')))
        wait(self.c,2)
        self.assertEqual(self.c.result,'27')
        self.assertTrue(self.c.eligible(2))
        self.assertFalse(self.c.submit(polynomial(),[],Operation.SUBSTITUTE,3,node(N.HOLE)))
        self.assertEqual(self.c.state,State.UNSUPPORTED)
    def test_ancestor_binders_and_incomplete(self):
        for kind in (N.SUM,N.INTEGRAL):
            self.assertFalse(self.c.submit(polynomial(),[kind],Operation.EXPAND,1))
            self.assertEqual(self.c.state,State.UNSUPPORTED)
            self.assertIsNone(self.c.controller.process)
        for selected in (node(N.HOLE),node(N.ERROR,text='frac(x,'),node(N.ROW,token('x'),token('y')),node(N.SCRIPTS,token('x'),token('i'),token('2'),node(N.HOLE),node(N.HOLE))):
            self.assertFalse(self.c.submit(selected,[],Operation.EXPAND,1))
    def test_cancel_restart(self):
        self.assertTrue(self.c.submit(polynomial(),[],Operation.EXPAND,1))
        self.c.cancel()
        self.assertEqual(self.c.state,State.CANCELLED)
        self.assertFalse(self.c.eligible(1))
        self.assertTrue(self.c.submit(polynomial(),[],Operation.EXPAND,2))
        wait(self.c,2)
        self.assertEqual(self.c.state,State.READY,self.c.message)
    def test_unsupported_supersedes_pending(self):
        self.c.controller.command=[sys.executable,'-c','import time; time.sleep(2)']
        self.assertTrue(self.c.submit(polynomial(),[],Operation.EXPAND,1))
        generation=self.c.generation
        self.assertFalse(self.c.submit(node(N.HOLE),[],Operation.EXPAND,1))
        self.assertGreater(self.c.generation,generation)
        self.assertFalse(self.c.tick(1))
        self.assertEqual(self.c.state,State.UNSUPPORTED)
        self.assertFalse(self.c.eligible(1))
    def test_edit_after_ready_marks_stale_without_reimport(self):
        self.assertTrue(self.c.submit(polynomial(),[],Operation.EXPAND,1))
        wait(self.c,1)
        result=self.c.result
        self.assertTrue(self.c.new_result)
        self.assertTrue(self.c.tick(2))
        self.assertEqual(self.c.state,State.STALE)
        self.assertFalse(self.c.new_result)
        self.assertEqual(self.c.result,result)
        self.assertFalse(self.c.eligible(2))
    def test_result_grouping(self):
        addition=semantic_node(Kind.ADD,symbol('x'),integer(1))
        self.assertEqual(text(semantic_node(Kind.MUL,integer(2),addition)), 'row(2, *, group("(", ")", row(x, +, 1)))')
        self.assertEqual(text(semantic_node(Kind.POW,addition,integer(2))), 'scripts(group("(", ")", row(x, +, 1)), ?, 2, ?, ?)')
    def test_missing_backend(self):
        self.c.close(); self.c=Computation('/no/such/moxi-math-python')
        self.assertTrue(self.c.submit(polynomial(),[],Operation.EXPAND,1))
        wait(self.c,1)
        self.assertEqual(self.c.state,State.ERROR)
        self.assertFalse(self.c.eligible(1))
    def test_deadline_and_corrupt_backend(self):
        self.c.controller.command=[sys.executable,'-c','import time; time.sleep(2)']
        self.c.controller.timeout=.05
        self.assertTrue(self.c.submit(polynomial(),[],Operation.EXPAND,1))
        wait(self.c,1)
        self.assertEqual(self.c.state,State.ERROR)
        self.assertFalse(self.c.eligible(1))
        self.c.controller.command=[sys.executable,'-c','import sys; sys.stdout.buffer.write(b"nope"); sys.stdout.flush()']
        self.assertTrue(self.c.submit(polynomial(),[],Operation.EXPAND,2))
        wait(self.c,2)
        self.assertEqual(self.c.state,State.ERROR)

if __name__=='__main__': unittest.main()
