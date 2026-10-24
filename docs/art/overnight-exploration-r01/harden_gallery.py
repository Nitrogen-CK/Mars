"""Keep offline gallery viewing usable when browser storage is unavailable."""
from pathlib import Path

path = Path(__file__).resolve().parent/'library.py'
text = path.read_text(encoding='utf-8')
text = text.replace("const stars=new Set(JSON.parse(localStorage.getItem(key)||'[]'));", "function readStars(){try{const value=JSON.parse(localStorage.getItem(key)||'[]');return Array.isArray(value)?value:[]}catch{return []}}function saveStars(){try{localStorage.setItem(key,JSON.stringify([...stars]))}catch{}}const stars=new Set(readStars());")
text = text.replace("localStorage.setItem(key,JSON.stringify([...stars]));draw()", "saveStars();draw()")
text = text.replace("${chosen.map(d=>`<div><h2>", "${chosen.length?chosen.map(d=>`<div><h2>")
text = text.replace("${d.image}\"></div>`).join('')}</div>`", "${d.image}\"></div>`).join(''):'<p>Star a few images to compare them here.</p>'}</div>`")
path.write_text(text, encoding='utf-8')
print('Offline storage fallback and empty-shortlist guidance added.')
