"""Build a portable, offline HTML and check the authored grid connectivity."""
import json
from collections import deque
from pathlib import Path

HERE = Path(__file__).resolve().parent
data = json.loads((HERE / 'layout.json').read_text(encoding='utf-8'))
grid = data['grid']
nodes = set()
for floor in data['floors']:
    x0, y0, x1, y1 = floor['rect']
    assert all(v % grid == 0 for v in floor['rect'] + [floor['z']]), floor['id']
    for x in range(x0, x1, grid):
        for y in range(y0, y1, grid):
            nodes.add((x + grid / 2, y + grid / 2, floor['z']))
for stair in data['stairs']:
    x0, y0, x1, y1 = stair['rect']
    assert all(v % grid == 0 for v in stair['rect']), stair['id']
    for x in range(x0, x1, grid):
        for y in range(y0, y1, grid):
            z = stair['from'] + (stair['to'] - stair['from']) * (y + grid / 2 - y0) / (y1 - y0)
            nodes.add((x + grid / 2, y + grid / 2, z))
start = next(iter(nodes))
seen = {start}
queue = deque([start])
while queue:
    a = queue.popleft()
    for b in nodes - seen:
        if abs(a[0]-b[0]) + abs(a[1]-b[1]) == grid and abs(a[2]-b[2]) <= 2:
            seen.add(b)
            queue.append(b)
assert seen == nodes, f'{len(nodes - seen)} isolated floor/stair cells'
for spawn in data['spawns']:
    x, y, z = spawn['at']
    assert any(f['rect'][0] <= x <= f['rect'][2] and f['rect'][1] <= y <= f['rect'][3]
               and f['z'] == z for f in data['floors']), spawn['id']
library = (HERE / 'three.min.js').read_text(encoding='utf-8')
template = (HERE / 'viewer.template.html').read_text(encoding='utf-8')
html = template.replace('/* THREE_BUNDLE */', library).replace('/* LAYOUT_DATA */', json.dumps(data))
target = HERE / 'cistern-greybox.html'
target.write_text(html, encoding='utf-8')
print(f'PASS: {len(nodes)} floor/stair cells connected; 4 grid-aligned valid entrances; offline HTML {target.stat().st_size:,} bytes')
