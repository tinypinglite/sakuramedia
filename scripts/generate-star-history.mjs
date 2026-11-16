#!/usr/bin/env node
// 拉取当前仓库的 stargazers 时间序列，渲染成 light/dark 两份静态 SVG。
// 由 .github/workflows/docs.yml 在 VitePress build 之前调用，产物落到
// wiki/public/star-history-{light,dark}.svg，跟 wiki 一起发布到 GitHub Pages。
// 不入库（见 .gitignore），也不会污染主分支。
//
// 环境变量：
//   GH_TOKEN  必填。workflow 里传 secrets.GH_PAT；本地跑传自己的 PAT。
//   REPO      必填。格式 owner/name，workflow 里传 github.repository。
//   OUT_DIR   可选。默认 wiki/public。

import { writeFileSync, mkdirSync } from 'node:fs';
import { join } from 'node:path';

const TOKEN = process.env.GH_TOKEN;
const REPO = process.env.REPO;
const OUT_DIR = process.env.OUT_DIR || 'wiki/public';

if (!TOKEN || !REPO || !REPO.includes('/')) {
  console.error('GH_TOKEN 和 REPO (owner/name) 是必填');
  process.exit(1);
}
const [owner, name] = REPO.split('/');

async function fetchStars() {
  const dates = [];
  let cursor = null;
  const query = `
    query($owner:String!,$name:String!,$cursor:String){
      repository(owner:$owner,name:$name){
        stargazers(first:100,after:$cursor,orderBy:{field:STARRED_AT,direction:ASC}){
          pageInfo{hasNextPage endCursor}
          edges{starredAt}
        }
      }
    }`;
  while (true) {
    const res = await fetch('https://api.github.com/graphql', {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${TOKEN}`,
        'Content-Type': 'application/json',
        'User-Agent': 'sakuramedia-star-history-generator',
      },
      body: JSON.stringify({ query, variables: { owner, name, cursor } }),
    });
    if (!res.ok) {
      throw new Error(`GraphQL HTTP ${res.status}: ${await res.text()}`);
    }
    const json = await res.json();
    if (json.errors) {
      throw new Error(`GraphQL errors: ${JSON.stringify(json.errors)}`);
    }
    const sg = json.data.repository.stargazers;
    for (const e of sg.edges) dates.push(new Date(e.starredAt).getTime());
    if (!sg.pageInfo.hasNextPage) break;
    cursor = sg.pageInfo.endCursor;
  }
  return dates;
}

function buildSeries(times) {
  const points = times.map((t, i) => ({ t, y: i + 1 }));
  if (points.length <= 500) return points;
  const step = Math.ceil(points.length / 500);
  const sampled = points.filter((_, i) => i % step === 0);
  const last = points[points.length - 1];
  if (sampled[sampled.length - 1] !== last) sampled.push(last);
  return sampled;
}

const PALETTE = {
  light: {
    axis: '#57606a',
    text: '#1f2328',
    grid: '#d0d7de',
    line: '#0969da',
    fill: 'rgba(9,105,218,0.15)',
  },
  dark: {
    axis: '#8b949e',
    text: '#e6edf3',
    grid: '#30363d',
    line: '#58a6ff',
    fill: 'rgba(88,166,255,0.20)',
  },
};

function fmtDate(t) {
  const d = new Date(t);
  const y = d.getUTCFullYear();
  const m = String(d.getUTCMonth() + 1).padStart(2, '0');
  const day = String(d.getUTCDate()).padStart(2, '0');
  return `${y}-${m}-${day}`;
}

function renderSvg(points, theme) {
  const W = 800;
  const H = 400;
  const PAD = { top: 40, right: 30, bottom: 50, left: 60 };
  const innerW = W - PAD.left - PAD.right;
  const innerH = H - PAD.top - PAD.bottom;
  const c = PALETTE[theme];
  const title = `${owner}/${name} · Star History`;

  if (points.length === 0) {
    return `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 ${W} ${H}" font-family="system-ui,-apple-system,'Helvetica Neue',Arial,sans-serif"><text x="${W / 2}" y="${H / 2}" text-anchor="middle" font-size="18" fill="${c.text}">No stars yet</text></svg>`;
  }

  const tMin = points[0].t;
  const tMax = points[points.length - 1].t;
  const yMax = points[points.length - 1].y;
  const tSpan = Math.max(1, tMax - tMin);
  const x = (t) => PAD.left + ((t - tMin) / tSpan) * innerW;
  const y = (v) => PAD.top + innerH - (v / yMax) * innerH;

  const pathD = points
    .map((p, i) => `${i === 0 ? 'M' : 'L'} ${x(p.t).toFixed(1)} ${y(p.y).toFixed(1)}`)
    .join(' ');
  const baseY = (PAD.top + innerH).toFixed(1);
  const areaD = `${pathD} L ${x(tMax).toFixed(1)} ${baseY} L ${x(tMin).toFixed(1)} ${baseY} Z`;

  const yTicks = [];
  for (let i = 0; i <= 4; i++) {
    const v = Math.round((yMax / 4) * i);
    yTicks.push({ v, y: y(v) });
  }
  const xTicks = [
    { t: tMin, label: fmtDate(tMin) },
    { t: tMin + tSpan / 2, label: fmtDate(tMin + tSpan / 2) },
    { t: tMax, label: fmtDate(tMax) },
  ];

  const gridLines = yTicks
    .map(
      (t) =>
        `<line x1="${PAD.left}" x2="${W - PAD.right}" y1="${t.y.toFixed(1)}" y2="${t.y.toFixed(1)}" stroke="${c.grid}" stroke-width="1"/>`,
    )
    .join('');
  const yLabels = yTicks
    .map(
      (t) =>
        `<text x="${PAD.left - 8}" y="${(t.y + 4).toFixed(1)}" text-anchor="end" font-size="11" fill="${c.text}">${t.v}</text>`,
    )
    .join('');
  const xLabels = xTicks
    .map(
      (t) =>
        `<text x="${x(t.t).toFixed(1)}" y="${H - PAD.bottom + 20}" text-anchor="middle" font-size="11" fill="${c.text}">${t.label}</text>`,
    )
    .join('');

  return `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 ${W} ${H}" font-family="system-ui,-apple-system,'Helvetica Neue',Arial,sans-serif">
  <text x="${W / 2}" y="24" text-anchor="middle" font-size="16" font-weight="600" fill="${c.text}">${title}</text>
  ${gridLines}
  ${yLabels}
  ${xLabels}
  <line x1="${PAD.left}" y1="${PAD.top}" x2="${PAD.left}" y2="${H - PAD.bottom}" stroke="${c.axis}" stroke-width="1"/>
  <line x1="${PAD.left}" y1="${H - PAD.bottom}" x2="${W - PAD.right}" y2="${H - PAD.bottom}" stroke="${c.axis}" stroke-width="1"/>
  <path d="${areaD}" fill="${c.fill}"/>
  <path d="${pathD}" fill="none" stroke="${c.line}" stroke-width="2" stroke-linejoin="round" stroke-linecap="round"/>
  <text x="${W - PAD.right}" y="${H - 10}" text-anchor="end" font-size="10" fill="${c.text}" opacity="0.6">Updated ${fmtDate(Date.now())} · ${yMax} stars</text>
</svg>
`;
}

async function main() {
  console.log(`Fetching stargazers for ${REPO}...`);
  const times = await fetchStars();
  console.log(`Total stars: ${times.length}`);
  const points = buildSeries(times);
  mkdirSync(OUT_DIR, { recursive: true });
  writeFileSync(join(OUT_DIR, 'star-history-light.svg'), renderSvg(points, 'light'));
  writeFileSync(join(OUT_DIR, 'star-history-dark.svg'), renderSvg(points, 'dark'));
  console.log(`Wrote star-history-{light,dark}.svg to ${OUT_DIR} (${points.length} points)`);
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
