"""Check collection ownership and mode boundaries with finite fake tools."""

import json
import os
import subprocess
import tempfile
import unittest
from pathlib import Path


TOOLS = '''#!/usr/bin/env python3
import json, os, signal, sys, time
from pathlib import Path
name=Path(sys.argv[0]).name
args=sys.argv[1:]
root=Path(os.environ['FAKE_STATE'])
with (root/'calls').open('a') as f: f.write(json.dumps([name,*args])+'\\n')
if name=='lsof': raise SystemExit(0 if os.environ.get('PORT_BUSY') else 1)
if name=='curl': print('{"id":1}'); raise SystemExit(0)
if name=='dotnet': raise SystemExit(0)
if name=='dotnet-coverage':
    operation=args[0]
    if operation=='collect':
        deadline=time.monotonic()+10
        while not (root/'stop').exists() and time.monotonic()<deadline: time.sleep(.01)
        Path(args[args.index('-o')+1]).write_text('<coverage />')
        if os.environ.get('COLLECT_FAIL'): raise SystemExit(7)
        os.kill(os.getpid(), signal.SIGKILL)
    elif operation=='shutdown':
        (root/'stop').touch()
        raise SystemExit(1 if os.environ.get('SHUTDOWN_FAIL') else 0)
    elif operation in ('snapshot','merge'):
        if operation=='merge' and os.environ.get('EXPORT_FAIL'): raise SystemExit(1)
        Path(args[args.index('-o')+1]).write_text('native' if operation=='snapshot' else '<coverage />')
'''


class CollectionTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.bin = self.root / "bin"
        self.bin.mkdir()
        for name in ("dotnet", "dotnet-coverage", "curl", "lsof"):
            tool = self.bin / name
            tool.write_text(TOOLS)
            tool.chmod(0o755)

    def run_collection(self, mode="snapshot", **extra):
        env = os.environ.copy()
        env.update(PATH=str(self.bin) + os.pathsep + env["PATH"], FAKE_STATE=str(self.root),
                   OUTPUT_DIR=str(self.root / "output"), COLLECTION_MODE=mode, BASE_URL="http://localhost:20000",
                   SESSION_ID="owned-test-session", **extra)
        run = subprocess.run(["bash", str(Path(__file__).with_name("sampleapi-generate-xml.sh"))],
                             env=env, capture_output=True, text=True, timeout=20)
        calls = [json.loads(line) for line in (self.root / "calls").read_text().splitlines()]
        return run, calls

    def test_snapshot_retains_requests_and_shuts_down_once(self):
        run, calls = self.run_collection()
        self.assertEqual(run.returncode, 0, run.stderr)
        coverage = [args[1] for args in calls if args[0] == "dotnet-coverage"]
        self.assertEqual(coverage, ["collect", "snapshot", "merge", "shutdown"])
        self.assertEqual(sum(call[0] == "curl" for call in calls), 8)
        xml = Path((self.root / "output/latest-xml-path").read_text().strip())
        self.assertEqual(xml.read_text(), "<coverage />")

    def test_final_omits_snapshot_and_merge(self):
        run, calls = self.run_collection("final")
        self.assertEqual(run.returncode, 0, run.stderr)
        self.assertEqual([args[1] for args in calls if args[0] == "dotnet-coverage"], ["collect", "shutdown"])
        self.assertTrue((self.root / "output/latest-xml-path").read_text().strip().endswith("sampleapi-final.xml"))

    def test_conflicting_port_never_starts_or_stops_a_session(self):
        run, calls = self.run_collection(PORT_BUSY="1")
        self.assertNotEqual(run.returncode, 0)
        self.assertFalse(any(call[0] == "dotnet-coverage" for call in calls))
        self.assertFalse((self.root / "output").exists())

    def test_export_failure_cleans_owned_session_without_publishing_path(self):
        run, calls = self.run_collection(EXPORT_FAIL="1")
        self.assertNotEqual(run.returncode, 0)
        self.assertEqual(sum(call[:2] == ["dotnet-coverage", "shutdown"] for call in calls), 1)
        self.assertFalse((self.root / "output/latest-xml-path").exists())

    def test_unexpected_collector_exit_is_not_accepted(self):
        run, calls = self.run_collection(COLLECT_FAIL="1")
        self.assertEqual(run.returncode, 7)
        self.assertEqual(sum(call[:2] == ["dotnet-coverage", "shutdown"] for call in calls), 1)
        self.assertFalse((self.root / "output/latest-xml-path").exists())


if __name__ == "__main__":
    unittest.main()
