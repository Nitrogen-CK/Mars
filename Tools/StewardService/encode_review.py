"""Encode the actual captured viewport frames; no generated/interpolated frames."""
import json
import subprocess
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parents[1] / 'Saved/StewardServiceDeps'))
import imageio_ffmpeg

report = json.loads((HERE / 'Output/Runtime/capture_report.json').read_text())
assert report['status'] == 'complete' and report['capture_validity']['captured_ok']
frames = Path(report['output_dir'])
assert len(list(frames.glob('frame_*.png'))) == report['frame_count']
fps = report['frame_count'] / report['elapsed_seconds']
start = max(0, report['stages']['after_n_ticks']['fired_at_seconds'] - .3)
output = HERE / 'Output/Steward_Service_Editor_Demo.mp4'
functional = json.loads((HERE / 'Output/Runtime/review.json').read_text())
assert functional['status'] == 'passed', 'Cannot encode a failed or incomplete functional review as delivery'
duration = min(report['elapsed_seconds'] - start, functional.get('wall_seconds', 27) + 1)
exe = imageio_ffmpeg.get_ffmpeg_exe()
subprocess.run([exe, '-hide_banner', '-loglevel', 'error', '-y', '-framerate', str(fps),
                '-i', str(frames / 'frame_%03d.png'), '-ss', str(start), '-t', str(duration),
                '-vf', 'scale=1280:-2', '-c:v', 'libx264', '-crf', '20', '-pix_fmt', 'yuv420p',
                '-movflags', '+faststart', str(output)], check=True)
probe = subprocess.run([exe, '-hide_banner', '-i', str(output), '-f', 'null', '-'],
                       capture_output=True, text=True, check=True)
(HERE / 'Output/Runtime/video_validation.txt').write_text(probe.stderr)
assert output.stat().st_size > 10000
print(output, output.stat().st_size, 'bytes; decoded every frame successfully')
