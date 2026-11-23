#!/usr/bin/env python3
"""Check real main..HEAD coverage: changed hits/branches retained, old same-file class excluded."""
import argparse
import json
import re
import subprocess
import xml.etree.ElementTree as ET
from pathlib import Path

p = argparse.ArgumentParser(description=__doc__)
p.add_argument('--xml', type=Path, required=True, help='Fresh complete Coverlet Cobertura input')
p.add_argument('--report', type=Path, required=True, help='CoverageX-generated Cobertura.xml')
p.add_argument('--scope-log', type=Path, required=True, help='CoverageX stderr with Information scope logs')
a = p.parse_args()
repo = Path(__file__).resolve().parent.parent
source_file = repo / 'src/SampleLibrary/Calculator.cs'
source = source_file.read_text().splitlines()
subprocess.run(['git', 'merge-base', '--is-ancestor', 'main', 'HEAD'], cwd=repo, check=True)
diff = subprocess.check_output(['git', 'diff', '--unified=0', 'main...HEAD', '--', 'src/SampleLibrary/Calculator.cs'], cwd=repo, text=True)
added = set()
current = None
for row in diff.splitlines():
    if row.startswith('@@'):
        current = int(re.search(r'\+(\d+)', row)[1])
    elif current is not None and row.startswith('+') and not row.startswith('+++'):
        code = row[1:].strip()
        if code and code not in ('{', '}', '};') and not code.startswith('//'):
            added.add(current)
        current += 1
    elif current is not None and row.startswith(' '):
        current += 1
assert added, 'No committed incremental fixture; commit this branch before reporting'
markers = {name: next(i for i, text in enumerate(source, 1) if 'fixture: ' + name in text)
           for name in ('condition', 'missed', 'covered', 'unused')}
assert set(markers.values()) <= added
scope_objects = []
text = a.scope_log.read_text()
for match in re.finditer(r'\{', text):
    try:
        value, _ = json.JSONDecoder().raw_decode(text[match.start():])
    except ValueError:
        continue
    if isinstance(value, dict) and value.get('RelativePath') == 'src/SampleLibrary/Calculator.cs':
        scope_objects.append(value)
assert len(scope_objects) == 1, 'Need one actual Calculator.cs scope record at Information log level'
assert set(scope_objects[0]['ChangedLines']) == added, 'Actual Git-derived scope differs from expected meaningful changes'
raw = ET.parse(a.xml).getroot()
report = ET.parse(a.report).getroot()

def classes(root):
    return root.findall('./packages/package/classes/class')

def named(root, name):
    matches = [c for c in classes(root) if c.get('name') == name]
    assert len(matches) == 1, (name, [c.get('name') for c in classes(root)])
    return matches[0]

def lines(c):
    result = {}
    for line in c.findall('./lines/line'):
        number = int(line.get('number'))
        assert number not in result, 'This fixture expects unique producer line records'
        result[number] = line
    return result

def fraction(line):
    value = line.get('condition-coverage', '')
    is_branch = line.get('branch', 'false').lower() == 'true'
    if not value:
        assert not is_branch, 'Branch line has no coverage fraction'
        return None
    match = re.fullmatch(r'(\d+(?:\.\d+)?)%\s*\((\d+)/(\d+)\)', value)
    assert is_branch and match, 'Malformed branch metadata'
    percent, covered, total = float(match[1]), int(match[2]), int(match[3])
    assert 0 <= covered <= total and total > 0
    assert abs(percent - 100 * covered / total) <= 0.01, 'Branch percentage contradicts its fraction'
    return covered, total

old_class = named(raw, 'SampleLibrary.Calculator')
assert any(int(l.get('hits')) > 0 for l in old_class.findall('./lines/line')), 'Baseline unchanged code must actually run'
assert not any(c.get('name') == 'SampleLibrary.Calculator' for c in classes(report)), 'Unchanged same-file class leaked into report'
raw_lines = lines(named(raw, 'SampleLibrary.IncrementalShipping'))
reported = lines(named(report, 'SampleLibrary.IncrementalShipping'))
expected = set(raw_lines) & added
assert set(reported) == expected, {'expected': sorted(expected), 'actual': sorted(reported)}
for number in expected:
    assert int(reported[number].get('hits')) == int(raw_lines[number].get('hits')), number
    assert fraction(reported[number]) == fraction(raw_lines[number]), number
for name in ('condition', 'covered'):
    assert int(reported[markers[name]].get('hits')) > 0, name
for name in ('missed', 'unused'):
    assert int(reported[markers[name]].get('hits')) == 0, name
assert fraction(reported[markers['condition']]) == (1, 2), 'Only the standard branch should have run'
comment_line = next(i for i, text in enumerate(source, 1) if 'Fixture: comment-only' in text)
assert comment_line not in scope_objects[0]['ChangedLines']
assert all(comment_line != int(line.get('number')) for c in classes(report) for line in c.findall('./lines/line'))
assert int(report.get('lines-valid')) == len(expected)
assert int(report.get('lines-covered')) == sum(int(line.get('hits')) > 0 for line in reported.values())
branch_counts = [fraction(line) for line in reported.values() if fraction(line) is not None]
covered_branches = sum(pair[0] for pair in branch_counts)
total_branches = sum(pair[1] for pair in branch_counts)
assert int(report.get('branches-covered')) == covered_branches
assert int(report.get('branches-valid')) == total_branches
assert abs(float(report.get('branch-rate')) - covered_branches / total_branches) <= 0.0001
assert abs(float(report.get('line-rate')) - sum(int(line.get('hits')) > 0 for line in reported.values()) / len(expected)) <= 0.0001
print(json.dumps({'sourceCommit': subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=repo, text=True).strip(),
    'targetCommit': subprocess.check_output(['git', 'rev-parse', 'main'], cwd=repo, text=True).strip(),
    'changedExecutableLines': sorted(expected), 'markers': markers,
    'coveredLines': sum(int(line.get('hits')) > 0 for line in reported.values()),
    'missedLines': sum(int(line.get('hits')) == 0 for line in reported.values()),
    'conditionCoverage': '1/2', 'unchangedSameFileClassExcluded': True, 'selectedLineHitsAndBranchCountsPreserved': True, 'actualGitScopeChecked': True, 'rootBranchTotalsChecked': True, 'conditionIdentityChecked': False}, indent=2))
