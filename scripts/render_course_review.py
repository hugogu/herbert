#!/usr/bin/env python3
"""Render an offline before/after board review from real catalog data, not app screenshots."""
import argparse
import html
import json
from pathlib import Path
import subprocess

from advanced_course import LESSONS as ADVANCED_LESSONS
from generate_original_problems import LESSONS

ROOT = Path(__file__).resolve().parents[1]
CATALOG = 'Sources/HerbertCore/Resources/original-problems.json'


def board_svg(rows):
    parts = ['<svg viewBox="0 0 520 520" role="img" aria-label="25 × 25 棋盘">',
             '<rect width="520" height="520" rx="18" fill="#f5f5ed"/>']
    for y, row in enumerate(rows):
        for x, cell in enumerate(row):
            cx, cy = 20+x*20, 20+y*20
            if cell == 'x':
                parts.append(f'<rect x="{cx-10}" y="{cy-10}" width="20" height="20" fill="#435e5e"/>')
            elif cell == 'o':
                parts.append(f'<circle cx="{cx}" cy="{cy}" r="6.5" fill="#efaa3e"/>')
                parts.append(f'<circle cx="{cx}" cy="{cy}" r="2" fill="#f5f5ed"/>')
            elif cell == '*':
                parts.append(f'<circle cx="{cx}" cy="{cy}" r="6" fill="none" stroke="#9b7369" stroke-width="2"/>')
                parts.append(f'<circle cx="{cx}" cy="{cy}" r="2" fill="#9b7369"/>')
            elif cell == 'u':
                parts.append(f'<path d="M{cx},{cy-8} l-7,13 h14 z" fill="#147c66"/>')
            else:
                parts.append(f'<circle cx="{cx}" cy="{cy}" r="1.1" fill="#bdc9c5"/>')
    return ''.join(parts) + '</svg>'


def render(current, previous):
    old = {p['lesson']['order']: p for p in previous}
    data = []
    for problem in current[9:]:
        order = problem['lesson']['order']
        before = old[order]
        title, goal, _ = (LESSONS + ADVANCED_LESSONS)[order-1]
        counts = lambda p: {symbol: sum(row.count(symbol) for row in p['rows']) for symbol in 'xo*'}
        data.append(dict(order=order, name=title[1], goal=goal[1], limit=problem['byteLimit'],
                         after=board_svg(problem['rows']), before=board_svg(before['rows']),
                         counts=counts(problem), oldCounts=counts(before)))
    payload = json.dumps(data, ensure_ascii=False).replace('<', '\u003c')
    cards = ''.join(f'<button class="thumb" data-index="{i}">{p["after"]}'
                    f'<span>L{p["order"]:02} · {html.escape(p["name"])}</span></button>' for i, p in enumerate(data))
    return '''<!doctype html><html lang="zh-CN"><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>Herbert · 关卡改版审阅</title>
<style>
*{box-sizing:border-box}body{margin:0;background:#f5f5ed;color:#183034;font:16px/1.6 system-ui,sans-serif}
main{max-width:1250px;margin:auto;padding:32px 24px}h1{font-size:clamp(25px,4vw,40px);margin:0}
h2{margin:0}p{margin:8px 0 20px;color:#617773}.bar{display:flex;gap:12px;align-items:center;flex-wrap:wrap}
button,select{font:inherit;color:#147c66;border:1px solid #d4ded7;border-radius:10px;background:white;padding:9px 16px;cursor:pointer}
select{flex:1;min-width:240px}.comparison{display:grid;grid-template-columns:1fr 1fr;gap:20px;margin-top:20px}
.panel{background:white;border:1px solid #dce3db;border-radius:20px;padding:20px}svg{display:block;width:100%;height:auto}
.caption{display:flex;justify-content:space-between;gap:12px;margin-bottom:12px;color:#617773;font-size:14px}
.gallery{display:grid;grid-template-columns:repeat(auto-fit,minmax(200px,1fr));gap:16px;margin-top:24px}
.thumb{padding:12px;text-align:left}.thumb span{display:block;margin-top:8px;font-weight:600;color:#183034}
.legend{display:flex;gap:20px;flex-wrap:wrap;margin:16px 0;font-size:14px;color:#617773}
.dot{width:12px;height:12px;display:inline-block;margin-right:6px;vertical-align:middle;border-radius:50%;background:#efaa3e}
.wall{background:#435e5e;border-radius:1px}.trap{background:none;border:2px solid #9b7369}
.notice{font-size:13px;color:#617773;border-top:1px solid #dce3db;margin-top:32px;padding-top:16px}
@media(max-width:650px){main{padding:20px 14px}.comparison{grid-template-columns:1fr}.panel{padding:12px}}
</style><main><h1>Herbert · 开放几何关卡</h1>
<p>L11–L22 重构形态；L23–L30 保留目标与起点，调整局部墙和陷阱。点击缩略图查看改版前后。</p>
<div class="bar"><button id="prev" aria-label="上一关">←</button><select id="select" aria-label="选择关卡"></select><button id="next" aria-label="下一关">→</button></div>
<div class="legend"><span><i class="dot"></i>目标</span><span><i class="dot wall"></i>墙：挡住移动</span><span><i class="dot trap"></i>陷阱：可进入，但会熄灭已亮目标</span></div>
<h2 id="name"></h2><p id="goal"></p><div class="comparison">
<section class="panel"><div class="caption"><b>改版前 · v0.3.8</b><span id="oldStats"></span></div><div id="before"></div></section>
<section class="panel"><div class="caption"><b>本次改版</b><span id="stats"></span></div><div id="after"></div></section></div>
<div class="gallery">''' + cards + '''</div>
<p class="notice">这是按实际关卡数据绘制的棋盘审阅图，并非 App 截图。参考答案仅存于测试目录；此页面不含答案。README 截图未更新。</p>
</main><script>const data=''' + payload + ''';
const select=document.getElementById('select');
for(const [i,p] of data.entries()){const o=document.createElement('option');o.value=i;o.textContent=`L${String(p.order).padStart(2,'0')} · ${p.name}`;select.appendChild(o)}
function show(i){i=(i+data.length)%data.length;select.value=i;const p=data[i];
document.getElementById('name').textContent=`L${String(p.order).padStart(2,'0')} · ${p.name}`;
document.getElementById('goal').textContent=p.goal+`（${p.limit} bytes）`;
for(const key of ['before','after'])document.getElementById(key).innerHTML=p[key];
document.getElementById('oldStats').textContent=`墙 ${p.oldCounts.x} · 陷阱 ${p.oldCounts['*']} · 目标 ${p.oldCounts.o}`;
document.getElementById('stats').textContent=`墙 ${p.counts.x} · 陷阱 ${p.counts['*']} · 目标 ${p.counts.o}`;}
select.onchange=()=>show(+select.value);document.getElementById('prev').onclick=()=>show(+select.value-1);
document.getElementById('next').onclick=()=>show(+select.value+1);
for(const b of document.querySelectorAll('.thumb'))b.onclick=()=>{show(+b.dataset.index);window.scrollTo({top:0,behavior:'smooth'})};show(1);
</script></html>'''


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--baseline', default='v0.3.8')
    parser.add_argument('--output', type=Path, default=Path('outputs/course-review/index.html'))
    args = parser.parse_args()
    current = json.loads((ROOT / CATALOG).read_text())
    previous = json.loads(subprocess.check_output(['git', 'show', f'{args.baseline}:{CATALOG}'], cwd=ROOT))
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(render(current, previous))
    print(f'Wrote {args.output}: L10–L30, offline before/after review, no answers or app screenshots.')


if __name__ == '__main__':
    main()
