import importlib.util
from pathlib import Path
import unittest
spec = importlib.util.spec_from_file_location('reorder', Path(__file__).parents[1] / 'reorder_workspaces.py')
r = importlib.util.module_from_spec(spec); spec.loader.exec_module(r)
class ReorderTests(unittest.TestCase):
    def test_insert_and_shift(self):
        self.assertEqual(r.permutation([1,2,3,4], [2,3,1,4]), {2:1,3:2,1:3})
    def test_repeated_reorder_roundtrip(self):
        state = {1:'a',2:'b',3:'c'}
        def change(a,b):
            self.assertNotIn(b,state); state[b]=state.pop(a)
        r.transact(r.permutation([1,2,3],[2,3,1]),[{'id':i} for i in state],change,lambda moves:None)
        self.assertEqual(state,{1:'b',2:'c',3:'a'})
        r.transact(r.permutation([1,2,3],[3,1,2]),[{'id':i} for i in state],change,lambda moves:None)
        self.assertEqual(state,{1:'a',2:'b',3:'c'})
    def test_journal_keeps_no_window_titles(self):
        workspace = {'id': 2, 'name': '2', 'monitor': 'DP-1', 'monitorID': 0, 'windows': 3, 'lastwindow': '0xabc', 'lastwindowtitle': 'Bank - password'}
        self.assertEqual(r.journal_snapshot([workspace]), [{'id': 2, 'name': '2', 'monitor': 'DP-1', 'monitorID': 0, 'windows': 3}])
    def test_reject_duplicates(self):
        with self.assertRaises(ValueError): r.permutation([1,2], [1,1])
    def test_layouts_preserved_and_empty_slots(self):
        state = {1:'code', 3:'browser'}
        def change(a,b):
            self.assertNotIn(b,state);state[b]=state.pop(a)
        r.transact({1:3,2:1,3:2}, [{'id':i} for i in state], change, lambda moves:None)
        self.assertEqual(state,{3:'code',2:'browser'})
    def test_failure_rolls_back(self):
        state={1:'a',2:'b'}; calls=0
        def change(a,b):
            nonlocal calls
            calls+=1
            if calls==3: raise RuntimeError('test failure')
            self.assertNotIn(b,state);state[b]=state.pop(a)
        with self.assertRaises(RuntimeError):r.transact({1:2,2:1},[{'id':1},{'id':2}],change,lambda moves:None)
        self.assertEqual(state,{1:'a',2:'b'})
if __name__=='__main__':unittest.main()
