import concurrent.futures
import json
import threading
import time
import unittest
from array import array
from functools import partial
from http.server import ThreadingHTTPServer
from pathlib import Path
from urllib.request import Request, urlopen
from urllib.error import HTTPError
from server import Data, Handler, Kind, GRID, reduce, wire_bytes
from probe import SpatialPoints, generate_points, SOURCE_SEED

class Contracts(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.data=Data()
        cls.server=ThreadingHTTPServer(('127.0.0.1',0),partial(Handler,directory=str(Path(__file__).resolve().parents[2])))
        cls.server.data=cls.data
        cls.thread=threading.Thread(target=cls.server.serve_forever,daemon=True);cls.thread.start()
        cls.url=f'http://127.0.0.1:{cls.server.server_port}'
    @classmethod
    def tearDownClass(cls):
        cls.server.shutdown();cls.server.server_close();cls.thread.join()
    def request(self,**kw):
        return dict(session='fixture',query='q1',revision=self.data.revision,generation=1,kind=Kind.GRID.value,viewport=[0,0,1,1],width=GRID,height=GRID,cap=32,delay=0)|kw
    def post(self,path,payload):
        with urlopen(Request(self.url+path,json.dumps(payload).encode(),{'Content-Type':'application/json'}),timeout=6) as response:
            body=response.read();self.assertLessEqual(len(body),65536);return json.loads(body)
    def test_advertised_entry_url(self):
        with urlopen(self.url+'/?route=full') as response:
            self.assertEqual(response.url,self.url+'/experiments/server-backed-views/?route=full')
            self.assertIn(b'./demo.mjs',response.read())
        with urlopen(self.url+'/experiments/server-backed-views/demo.mjs') as response:
            self.assertEqual(response.status,200)

    def test_full_and_binary(self):
        q=self.request();result=self.post('/api/query',q)
        self.assertEqual(sum(result['counts']),1000000)
        self.assertNotIn('records',result)
        with urlopen(self.url+'/api/source') as response:binary=response.read()
        self.assertEqual(len(binary),20000000);self.assertEqual(binary,self.data.binary)
        self.assertEqual(self.data.revision,'cbc893afb24c38048ff9e30813c114c47ee1052bd18aa8963008ff93a04c991f')
    def test_boundaries_details(self):
        points=SpatialPoints(array('d',[0,.5,.999,1,.5]),array('d',[0,.5,.999,.5,1]),array('I',[1,2,3,4,5]))
        q=self.request();result=reduce(points,q,threading.Event())
        self.assertEqual(result['total'],3);self.assertEqual(result['counts'][0],1);self.assertEqual(result['counts'][16*GRID+16],1)
        q=self.request(kind=Kind.DETAILS.value,cap=2)
        result=reduce(points,q,threading.Event());self.assertEqual([r['id'] for r in result['records']],[1,2]);self.assertTrue(result['truncated'])
        result=self.post('/api/query',self.request(kind=Kind.DETAILS.value));self.assertEqual(len(result['records']),32);self.assertEqual(result['total'],1000000)
    def test_cancel_pending_delay_and_capacity(self):
        q=self.request(query='delayed',delay=3000)
        with concurrent.futures.ThreadPoolExecutor() as pool:
            future=pool.submit(self.post,'/api/query',q)
            deadline=time.monotonic()+3
            while 'fixture' not in self.data.jobs and time.monotonic()<deadline:time.sleep(.005)
            self.assertIn('fixture',self.data.jobs)
            with self.assertRaises(HTTPError):self.post('/api/query',self.request(query='overlap'))
            start=time.monotonic();self.post('/api/cancel',{'session':'fixture','query':'delayed'})
            self.assertTrue(future.result()['cancelled']);self.assertLess(time.monotonic()-start,1)
        self.assertEqual(len(self.data.jobs),0)
    def test_cancel_before_start(self):
        self.post('/api/cancel',{'session':'fixture','query':'before'})
        self.assertTrue(self.post('/api/query',self.request(query='before'))['cancelled'])
    def test_reduce_cancellation(self):
        token=threading.Event();token.set()
        from server import Cancelled
        with self.assertRaises(Cancelled):reduce(self.data.points,self.request(),token)
    def test_validation(self):
        for change in [dict(revision='old'),dict(width=4096),dict(cap=33,kind=Kind.DETAILS.value),dict(delay=-1),dict(viewport=[0,0,float('nan'),1]),dict(generation=True),dict(kind='other')]:
            with self.assertRaises(HTTPError):self.post('/api/query',self.request(**change))
        with self.assertRaises(HTTPError):urlopen(Request(self.url+'/api/meta',headers={'Origin':'https://example.org'}))
        for route in ['/pixi.toml','/experiments/server-backed-views/%2e%2e/%2e%2e/pixi.toml','/experiments/server-backed-views/server.py']:
            with self.assertRaises(HTTPError):urlopen(self.url+route)
    def test_delay_is_real(self):
        start=time.monotonic();self.post('/api/query',self.request(delay=150));self.assertGreaterEqual(time.monotonic()-start,.15)
    def test_two_sessions(self):
        with concurrent.futures.ThreadPoolExecutor() as pool:
            fs=[pool.submit(self.post,'/api/query',self.request(session=s,query=s,delay=150)) for s in ['a','b']]
            for f in fs:self.assertEqual(f.result()['total'],1000000)
        self.assertGreaterEqual(self.data.max_active,2)

    def test_cancel_during_reduction(self):
        q=self.request(query='scan',delay=0)
        with concurrent.futures.ThreadPoolExecutor() as pool:
            future=pool.submit(self.post,'/api/query',q)
            deadline=time.monotonic()+3
            while 'fixture' not in self.data.jobs and time.monotonic()<deadline:time.sleep(.001)
            time.sleep(.02)
            self.post('/api/cancel',{'session':'fixture','query':'scan'})
            self.assertTrue(future.result()['cancelled'])

    def test_real_server_restart_changed_revision(self):
        def launch(port,data):
            server=ThreadingHTTPServer(('127.0.0.1',port),partial(Handler,directory=str(Path(__file__).resolve().parents[2])))
            server.data=data
            thread=threading.Thread(target=server.serve_forever,daemon=True);thread.start()
            return server,thread
        first=Data(generate_points(8));server,thread=launch(0,first);port=server.server_port
        def query(q):
            with urlopen(Request(f'http://127.0.0.1:{port}/api/query',json.dumps(q).encode(),{'Content-Type':'application/json'})) as response:return json.load(response)
        old=self.request(revision=first.revision)
        self.assertEqual(query(old)['total'],8)
        server.shutdown();server.server_close();thread.join()
        second=Data(generate_points(8,SOURCE_SEED+1));server,thread=launch(port,second)
        try:
            self.assertNotEqual(first.revision,second.revision)
            with self.assertRaises(HTTPError):query(old)
            self.assertEqual(query(self.request(session='new',revision=second.revision))['total'],8)
        finally:
            server.shutdown();server.server_close();thread.join()

if __name__=='__main__':unittest.main(verbosity=2)
