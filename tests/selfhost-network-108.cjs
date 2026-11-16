// Issue #108 — bằng chứng Network/console của trình duyệt thật trên bản self-host localhost.
// Chạy: MINDSPRINT_BROWSER_URL=http://127.0.0.1:8080 node tests/selfhost-network-108.cjs [tệp-bằng-chứng.txt]
// Ghi: mọi request khi mở trang, đăng nhập và sau khi tải lại (origin, mã, loại, có qua Service Worker không), lỗi console,
// và mã/kiểu phản hồi của tệp tĩnh + route API không tồn tại. Tài khoản thử sinh ngẫu nhiên, mật khẩu không ghi ra file.
const assert = require('node:assert/strict');
const crypto = require('node:crypto');
const fs = require('node:fs');
const path = require('node:path');
const { execSync } = require('node:child_process');
const { launchBrowser } = require('./playwright-launch.cjs');
const { chromium } = require(path.join(__dirname, '../backend/MindSprint.Api/bin/Release/net8.0/.playwright/package'));

const base = process.env.MINDSPRINT_BROWSER_URL || 'http://127.0.0.1:8080';
const origin = new URL(base).origin;
const out = process.argv[2];
// Host ngoài được phép: phông chữ/biểu tượng của giao diện và đăng nhập Google. Không request nghiệp vụ nào được đi ra ngoài.
const allowedExternal = ['fonts.googleapis.com', 'fonts.gstatic.com', 'cdnjs.cloudflare.com', 'accounts.google.com'];
const forbidden = /onrender\.com|vercel\.app|:(5000|5100|5144|7014)\b/;

function sha() {
    try {
        const head = execSync('git rev-parse --short HEAD', { cwd: __dirname }).toString().trim();
        const dirty = execSync('git status --porcelain', { cwd: __dirname }).toString().trim() ? ' (+ thay đổi chưa commit)' : '';
        return head + dirty;
    } catch { return 'không rõ'; }
}

(async () => {
    const browser = await launchBrowser(chromium);
    const context = await browser.newContext();           // để Service Worker chạy như người dùng thật
    const email = `issue108-${crypto.randomBytes(6).toString('hex')}@example.com`;
    const password = crypto.randomBytes(12).toString('hex');
    const lines = [], phases = {};
    let phase = 'mở trang';
    const log = s => { lines.push(s); console.log(s); };
    try {
        assert.equal((await context.request.post(base + '/api/auth/register', { data: { email, password, displayName: 'Issue 108 check' } })).status(), 200);
        const page = await context.newPage();
        // Trình duyệt còn nhớ API của bản demo cũ: bản self-host vẫn phải gọi API cùng origin.
        await page.addInitScript(() => localStorage.setItem('api-base', 'http://localhost:5000'));
        const consoleErrors = [];
        page.on('console', m => { if (m.type() === 'error') consoleErrors.push(`[${phase}] ${m.text().slice(0, 160)}`); });
        page.on('pageerror', e => consoleErrors.push(`[${phase}] pageerror: ${e.message.slice(0, 160)}`));
        page.on('response', r => {
            const u = new URL(r.url());
            if (u.protocol === 'data:') return;
            (phases[phase] ??= []).push({ host: u.origin, path: u.pathname, status: r.status(), type: r.request().resourceType(),
                sw: r.fromServiceWorker(), ct: (r.headers()['content-type'] || '').split(';')[0] });
        });
        await page.goto(base, { waitUntil: 'networkidle' });
        phase = 'đăng nhập';
        await page.locator('#sidebar-auth [data-act=login]').click();
        await page.locator('#auth-email').fill(email);
        await page.locator('#auth-pass').fill(password);
        await page.locator('#auth-submit-btn').click();
        await page.locator('.auth-overlay').waitFor({ state: 'detached' });
        await page.waitForLoadState('networkidle');
        phase = 'sau tải lại';
        await page.reload({ waitUntil: 'networkidle' });
        assert.equal(await page.locator('#sidebar-user-name').innerText(), 'Issue 108 check', 'Phiên đăng nhập phải còn sau tải lại');

        log(`# Issue #108 — Network/console trên ${origin}`);
        log(`Thời điểm: ${new Date().toISOString()} · Mã nguồn: ${sha()} · Trình duyệt: ${browser.version()} (headless)`);
        log(`Môi trường: web self-host (Production, Hosting__ServeFrontend=true, runtime-config sameOrigin) + SQL Server DB thử riêng; localStorage api-base cũ = http://localhost:5000`);
        let failures = 0;
        const fail = msg => { failures++; log(`FAIL: ${msg}`); };
        for (const [name, rs] of Object.entries(phases)) {
            const own = rs.filter(r => r.host === origin), ext = rs.filter(r => r.host !== origin);
            const api = own.filter(r => r.path.startsWith('/api/'));
            const byType = t => own.filter(r => r.type === t);
            log(`\n## ${name}: ${rs.length} response (${own.length} cùng origin, ${ext.length} ngoài)`);
            log(`- API: ${api.length} lời gọi, mã ${[...new Set(api.map(r => r.status))].join('/') || '-'} — ${[...new Set(api.map(r => r.path))].join(', ')}`);
            for (const t of ['document', 'script', 'stylesheet', 'font', 'image']) {
                const list = byType(t);
                log(`- ${t}: ${list.length} tệp, mã ${[...new Set(list.map(r => r.status))].join('/') || '-'}${list.some(r => r.sw) ? `, ${list.filter(r => r.sw).length} qua Service Worker` : ''}`);
                list.filter(r => r.status >= 400).forEach(r => fail(`${name}: ${t} ${r.path} trả ${r.status}`));
            }
            const fonts = rs.filter(r => r.type === 'font');
            log(`- phông chữ (mọi origin): ${fonts.length} tệp, mã ${[...new Set(fonts.map(r => r.status))].join('/') || '-'}`);
            fonts.filter(r => r.status >= 400).forEach(r => fail(`${name}: phông ${r.host}${r.path} trả ${r.status}`));
            const bad = rs.filter(r => r.status >= 400);
            log(`- response lỗi (>= 400): ${bad.map(r => `${r.status} ${r.host === origin ? '' : r.host}${r.path} [${r.type}]`).join(', ') || 'không có'}`);
            log(`- ngoài origin: ${[...new Set(ext.map(r => new URL(r.host).host))].join(', ') || 'không có'}`);
            ext.filter(r => !allowedExternal.includes(new URL(r.host).host)).forEach(r => fail(`${name}: request ra ngoài ${r.host}${r.path}`));
            rs.filter(r => forbidden.test(r.host)).forEach(r => fail(`${name}: request tới máy chủ cũ/cổng Development ${r.host}${r.path}`));
            if (!own.some(r => r.type === 'stylesheet') && name !== 'đăng nhập') fail(`${name}: không thấy CSS nào tải`);
        }
        log(`\n## Console\n- lỗi console/pageerror: ${consoleErrors.length}${consoleErrors.map(e => '\n  - ' + e).join('')}`);
        consoleErrors.forEach(e => fail(`console: ${e}`));

        log('\n## Đường dẫn không tồn tại (không được trả HTML trang chủ)');
        for (const [p, method] of [['/khong-ton-tai.js', 'GET'], ['/assets/khong-co.png', 'GET'], ['/api/khong-ton-tai', 'GET'], ['/api/khong-ton-tai', 'POST']]) {
            const r = await context.request.fetch(base + p, { method });
            const ct = (r.headers()['content-type'] || '').split(';')[0], body = (await r.text()).slice(0, 90);
            log(`- ${method} ${p} → ${r.status()} ${ct || '(không có nội dung)'} ${body ? '· ' + body : ''}`);
            if (r.status() !== 404) fail(`${p} phải trả 404`);
            if (/<html/i.test(body)) fail(`${p} trả HTML`);
            if (p.startsWith('/api/') && ct !== 'application/json') fail(`${p} phải trả JSON`);
        }
        log(`\nKết quả: ${failures ? `FAIL (${failures})` : 'PASS'} · tài khoản thử: 1 (email issue108-…@example.com, mật khẩu ngẫu nhiên không ghi lại)`);
        if (out) fs.writeFileSync(out, lines.join('\n') + '\n');
        process.exitCode = failures ? 1 : 0;
    } finally {
        await context.close();
        await browser.close();
    }
})().catch(e => { console.error(e); process.exitCode = 1; });
