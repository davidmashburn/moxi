#!/usr/bin/env python3
"""Protocol boundary tests plus real fallback, no mocked solver."""
import json
import unittest
from interactive import InlineFDG, Kind, VERSION, validate_graph, workload_256

class ProtocolChecks(unittest.TestCase):
    def setUp(self):
        self.widget = InlineFDG(slot='check')
        self.sent = []
        self.widget.send = self.sent.append
        self.seq = 0
    def tearDown(self):
        self.widget.close()
    def message(self, kind=Kind.PING, **changes):
        self.seq += 1
        return dict(v=VERSION, session=self.widget.session, generation=self.widget.generation,
                    view='00000000-0000-0000-0000-000000000001', seq=self.seq, kind=kind, **changes)
    def receive(self, message):
        self.widget._receive(self.widget, message, [])
    def test_roundtrip_and_bounds(self):
        self.receive(self.message(Kind.HELLO))
        self.assertEqual(self.sent[-1]['kind'], Kind.ACK)
        self.assertIsInstance(Kind(self.sent[-1]['kind']), Kind)
        state=dict(selected=0, paused=True, panX=0, panY=0, zoom=1, releases=1, dragging=False)
        self.receive(self.message(Kind.STATE, state=state))
        self.assertEqual(self.widget.snapshot, state)
        for field, value in [('v', 2), ('session','old'), ('generation',0), ('seq',0), ('kind','unknown'), ('state','x'*5000)]:
            message=self.message(Kind.STATE,state=state)
            message[field]=value
            count=len(self.sent)
            self.receive(message)
            self.assertEqual(len(self.sent),count)
        self.assertEqual(self.widget.rejected,6)
        for field,value in [('selected',77),('zoom',float('nan')),('releases',-1),('paused',1),('dragging','false')]:
            self.receive(self.message(Kind.STATE,state={**state,field:value}))
        self.assertEqual(self.widget.rejected,11)
    def test_replacement_isolation_failure(self):
        self.receive(self.message(Kind.HELLO))
        other=InlineFDG(slot='other', graph=workload_256())
        replacement=InlineFDG(slot='check')
        try:
            self.receive(self.message())
            self.assertEqual(self.widget.rejected,1)
            self.assertNotEqual(other.session,replacement.session)
            self.assertEqual(replacement.generation,self.widget.generation+1)
            replacement.send=self.sent.append
            msg=dict(v=1,session=replacement.session,generation=replacement.generation,view='00000000-0000-0000-0000-000000000002',seq=1,kind=Kind.HELLO)
            replacement.set_backend_available(False)
            replacement._receive(replacement,msg,[])
            self.assertEqual(self.sent[-1]['kind'],Kind.ERROR)
            replacement.set_backend_available(True)
            replacement._receive(replacement,{**msg,'seq':2},[])
            self.assertEqual(self.sent[-1]['kind'],Kind.ACK)
        finally:
            other.close();replacement.close()
    def test_real_fallback_and_graph_capacity(self):
        self.assertIn('<svg',self.widget.fallback)
        self.assertIn('node-0',self.widget.fallback)
        for graph in [dict(groups=[],links=[]),dict(groups=[0]*257,links=[]),dict(groups=[True],links=[]),dict(groups=[0],links=[[0,1,1]])]:
            with self.assertRaises(ValueError):validate_graph(graph)
        self.assertEqual(len(validate_graph(workload_256())['links']),1024)

if __name__=='__main__':unittest.main()
