// Issue #110 — nâng cấp hai bản build liên tiếp trên cùng origin, không kẹt cache cũ, và cách reset cache giữ phiên đăng nhập.
// Chạy: MINDSPRINT_BROWSER_URL=http://127.0.0.1:8080 SWITCH_BUILD_CMD="<lệnh đổi sang bản B>" \
//       BUILD_A="<SHA/image bản A>" BUILD_B="<SHA/image bản B>" node tests/selfhost-cache-110.cjs [tệp-bằng-chứng.txt]
// Bản A phải đang chạy khi bắt đầu. Với Docker: SWITCH_BUILD_CMD="docker compose -f compose.selfhost.yaml up -d --build web".
// Không có SWITCH_BUILD_CMD thì script dừng chờ: tự triển khai bản B rồi nhấn Enter.
const assert = require('node:assert/strict');
const crypto = require('node:crypto');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const readline = require('node:readline/promises');
const { execSync } = require('node:child_process');
const { chromium } = require(path.join(__dirname, '../backend/MindSprint.Api/bin/Release/net8.0/.playwright/package'));

const base = process.env.MINDSPRINT_BROWSER_URL || 'http://127.0.0.1:8080';
const origin = new URL(base).origin;
const out = process.argv[2];
const sleep = ms => new Promise(r => setTimeout(r, ms));

(async () => {
    // Hồ sơ trình duyệt riêng, giữ qua các lần tải lại như người dùng thật (Service Worker, Cache Storage, localStorage).
    const profile = fs.mkdtempSync(path.join(os.tmpdir(), 'issue110-'));
    const context = await chromium.launchPersistentContext(profile, {
        headless: true, ...(process.env.TUTOR_BROWSER ? { executablePath: process.env.TUTOR_BROWSER } : {})
    });
    const email = `issue110-${crypto.randomBytes(6).toString('hex')}@example.com`;
    const password = crypto.randomBytes(12).toString('hex');
    const lines = [];
    const log = s => { lines.push(s); console.log(s); };
    let failures = 0;
    const check = (ok, msg) => { if (!ok) { failures++; log(`FAIL: ${msg}`); } };
    try {
        assert.equal((await context.request.post(base + '/api/auth/register', { data: { email, password, displayName: 'Issue 110 check' } })).status(), 200);
        const page = context.pages()[0] || await context.newPage();
        let apiOrigins = new Set(), assetSources = [];
        page.on('response', r => {
            const u = new URL(r.url());
            if (u.pathname.startsWith('/api/')) apiOrigins.add(u.origin);
            if (u.origin === origin && /\.(js|css)$/.test(u.pathname)) assetSources.push(`${u.pathname.slice(1)}${u.search}${r.fromServiceWorker() ? ' (SW)' : ''}`);
        });
        const snapshot = async label => {
            apiOrigins = new Set(); assetSources = [];
            await page.reload({ waitUntil: 'networkidle' });
            await page.evaluate(() => navigator.serviceWorker.ready);
            const s = await page.evaluate(async () => ({
                caches: (await caches.keys()).sort(),
                controller: navigator.serviceWorker.controller?.scriptURL || null,
                script: [...document.scripts].map(x => x.getAttribute('src') || '').find(x => x.startsWith('script.js')),
                runtime: JSON.stringify(window.MINDSPRINT_CONFIG || null),
                storage: Object.keys(localStorage).sort(),
                user: document.querySelector('#sidebar-user-name')?.innerText || null
            }));
            log(`\n## ${label}`);
            log(`- trang dùng: ${s.script} · Cache Storage: ${s.caches.join(', ') || '(trống)'} · SW điều khiển trang: ${s.controller ? 'có' : 'chưa'}`);
            log(`- runtime-config: ${s.runtime}`);
            log(`- API gọi tới: ${[...apiOrigins].join(', ') || '(không có)'} · JS/CSS: ${assetSources.filter(x => /script\.js|sw\.js|runtime-config|api\.js|style\.css/.test(x)).join(', ')}`);
            log(`- localStorage (chỉ tên khóa): ${s.storage.join(', ')} · người dùng: ${s.user ?? '(chưa đăng nhập)'}`);
            check([...apiOrigins].every(o => o === origin), `${label}: API phải cùng origin`);
            return s;
        };

        log(`# Issue #110 — nâng cấp cache trên ${origin}`);
        log(`Thời điểm: ${new Date().toISOString()} · Trình duyệt: ${context.browser()?.version() ?? 'Chrome'} (headless, hồ sơ riêng)`);
        log(`Bản A: ${process.env.BUILD_A || 'không ghi'} · Bản B: ${process.env.BUILD_B || 'không ghi'}`);
        await page.goto(base, { waitUntil: 'networkidle' });
        await page.locator('#sidebar-auth [data-act=login]').click();
        await page.locator('#auth-email').fill(email);
        await page.locator('#auth-pass').fill(password);
        await page.locator('#auth-submit-btn').click();
        await page.locator('.auth-overlay').waitFor({ state: 'detached' });
        // Dữ liệu cần giữ do người dùng tạo (giả lập một cài đặt riêng ngoài phiên đăng nhập).
        await page.evaluate(() => localStorage.setItem('issue110-keep', 'giữ-nguyên'));
        const a = await snapshot('Bản A — sau đăng nhập và tải lại');
        check(a.user === 'Issue 110 check', 'Bản A: phải đang đăng nhập');

        if (process.env.SWITCH_BUILD_CMD) execSync(process.env.SWITCH_BUILD_CMD, { stdio: 'inherit', shell: true });
        else { const rl = readline.createInterface({ input: process.stdin, output: process.stdout }); await rl.question('Triển khai bản B rồi nhấn Enter… '); rl.close(); }
        await sleep(1000);

        const b1 = await snapshot('Bản B — lần tải lại đầu tiên sau khi triển khai');
        // Service Worker mới được cài ngầm sau lần tải đầu (skipWaiting + clients.claim) rồi xóa cache cũ: đo thời gian tới khi xong.
        const started = Date.now();
        let swapped = false;
        while (!swapped && Date.now() - started < 30000) {
            await sleep(500);
            swapped = await page.evaluate(old => caches.keys().then(k => k.length > 0 && !k.some(c => old.includes(c))), a.caches);
        }
        log(`\n- Service Worker mới thay bản cũ sau ${((Date.now() - started) / 1000).toFixed(1)} giây kể từ lần tải lại đầu${swapped ? '' : ' (QUÁ 30 GIÂY)'}`);
        check(swapped, 'Bản B: Service Worker mới phải thay bản cũ trong 30 giây');
        const b2 = await snapshot('Bản B — lần tải lại thứ hai');
        check(b1.script !== a.script, 'Bản B: trang phải dùng script mới ngay lần tải lại đầu (HTML/JS lấy mạng trước)');
        check(b2.caches.length === 1 && !a.caches.some(c => b2.caches.includes(c)), 'Bản B: chỉ còn cache của bản mới, cache bản A đã xóa');
        check(b2.user === 'Issue 110 check', 'Bản B: phiên đăng nhập phải còn');
        check(JSON.stringify(a.storage) === JSON.stringify(b2.storage), 'Bản B: các khóa localStorage phải giữ nguyên');

        log('\n## Reset cache: mở /?reset-cache=1');
        // Đặt một mục đánh dấu vào cache hiện tại: sau reset mục này phải mất (chứng minh cache đã bị xóa, không chỉ trùng tên).
        await page.evaluate(async () => (await caches.open((await caches.keys())[0])).put('/__issue110-marker', new Response('cu')));
        await page.goto(base + '/?reset-cache=1');
        await page.waitForURL(u => !u.search.includes('reset-cache'), { timeout: 20000 });
        await page.waitForLoadState('networkidle');
        const afterReset = await page.evaluate(async () => ({ caches: await caches.keys(), regs: (await navigator.serviceWorker.getRegistrations()).length,
            marker: !!(await caches.match('/__issue110-marker')) }));
        log(`- ngay sau reset: Cache Storage ${afterReset.caches.length ? afterReset.caches.join(', ') : '(đã xóa, đang tạo lại)'} · Service Worker đăng ký lại: ${afterReset.regs} · mục đánh dấu còn: ${afterReset.marker ? 'CÒN' : 'đã mất (cache cũ đã xóa)'}`);
        check(!afterReset.marker, 'Reset: cache cũ phải bị xóa');
        const r = await snapshot('Sau reset — tải lại');
        check(r.user === 'Issue 110 check', 'Sau reset: không được đăng xuất');
        check(JSON.stringify(a.storage) === JSON.stringify(r.storage), 'Sau reset: localStorage phải giữ nguyên (gồm issue110-keep)');
        check(await page.evaluate(() => localStorage.getItem('issue110-keep')) === 'giữ-nguyên', 'Sau reset: giá trị người dùng phải còn');

        log(`\nKết quả: ${failures ? `FAIL (${failures})` : 'PASS'} · tài khoản thử: 1 (email issue110-…@example.com, mật khẩu ngẫu nhiên không ghi lại)`);
        if (out) fs.writeFileSync(out, lines.join('\n') + '\n');
        process.exitCode = failures ? 1 : 0;
    } finally {
        await context.close();
        fs.rmSync(profile, { recursive: true, force: true });
    }
})().catch(e => { console.error(e); process.exitCode = 1; });
