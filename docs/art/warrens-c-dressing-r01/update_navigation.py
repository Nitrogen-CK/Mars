"""Surface the production kit from the concept library already open in the user's browser."""
from pathlib import Path
ROOT=Path(__file__).resolve().parent
old=ROOT.parent/'overnight-exploration-r01/PREVIEW.html'
text=old.read_text(encoding='utf-8')
marker='<nav id="tabs">'
link='<p class="source"><a href="../warrens-c-dressing-r01/sections/chain-crossing-sluice/PREVIEW.html"><b>NEW: Chain Crossing &amp; Sluice — all local model sheets and Blender briefs</b></a><br><a href="../warrens-c-dressing-r01/PREVIEW.html">Full Variant C dressing pack</a></p>'
if 'warrens-c-dressing-r01/sections/chain-crossing-sluice/PREVIEW.html' not in text:
    assert marker in text
    old.write_text(text.replace(marker,link+marker,1),encoding='utf-8')
print('Concept-library links point directly to the section and full-level kits.')
