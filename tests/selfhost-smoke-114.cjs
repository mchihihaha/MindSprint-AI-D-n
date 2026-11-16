// Issue #114 — smoke toàn luồng trên trình duyệt thật của máy chủ (bản self-host localhost), không gọi AI.
// Chạy: MINDSPRINT_BROWSER_URL=http://127.0.0.1:8080 node tests/selfhost-smoke-114.cjs [tệp-bằng-chứng.txt]
// Live: đăng ký/đăng nhập, sổ tay + nguồn văn bản, thẻ, Kanban qua API/DB thật; tải lại rồi đối chiếu dữ liệu.
// Mock (chặn request trong trình duyệt): API lỗi 500 phải hiện thông báo lỗi, không báo lưu thành công giả.
const crypto = require('node:crypto');
const fs = require('node:fs');
const path = require('node:path');
const { execSync } = require('node:child_process');
const { launchBrowser } = require('./playwright-launch.cjs');
const { chromium } = require(path.join(__dirname, '../backend/MindSprint.Api/bin/Release/net8.0/.playwright/package'));

const base = process.env.MINDSPRINT_BROWSER_URL || 'http://127.0.0.1:8080';
const out = process.argv[2];
const tag = crypto.randomBytes(4).toString('hex');
const isApi = (r, p, method = 'POST') => new URL(r.url()).pathname.replace(/\/\d+(?=\/|$)/g, '/{id}') === p && r.request().method() === method;

(async () => {
    const browser = await launchBrowser(chromium);
    const context = await browser.newContext({ serviceWorkers: 'block' });
    const page = await context.newPage();
    const lines = [], results = [];
    const log = s => { lines.push(s); console.log(s); };
    const step = async (name, kind, fn) => {
        try { const note = await fn(); results.push([name, kind, 'Pass', note || '']); }
        catch (e) { results.push([name, kind, 'Fail', e.message.split('\n')[0].slice(0, 160)]); }
    };
    const expectOk = async (promise, label) => { const r = await promise; if (r.status() >= 300) throw new Error(`${label} trả ${r.status()}`); return r; };
    const email = `smoke114-${tag}@example.com`, password = crypto.randomBytes(12).toString('hex');
    const names = { notebook: `Sổ tay smoke ${tag}`, source: `Nguồn smoke ${tag}`, card: `Thẻ smoke ${tag}`, task: `Việc smoke ${tag}`, badTask: `Việc lỗi ${tag}` };
    let token, notebookId;
    const api = async p => (await context.request.get(base + p, { headers: { Authorization: `Bearer ${token}` } })).json();
    try {
        await step('Đăng ký tài khoản mới', 'live', async () => {
            const r = await context.request.post(base + '/api/auth/register', { data: { email, password, displayName: `Smoke ${tag}` } });
            if (r.status() !== 200) throw new Error(`register trả ${r.status()}`);
        });
        await step('Đăng nhập trên giao diện', 'live', async () => {
            await page.goto(base, { waitUntil: 'networkidle' });
            await page.locator('#sidebar-auth [data-act=login]').click();
            await page.locator('#auth-email').fill(email);
            await page.locator('#auth-pass').fill(password);
            await expectOk(Promise.all([page.waitForResponse(r => isApi(r, '/api/auth/login')), page.locator('#auth-submit-btn').click()]).then(x => x[0]), 'login');
            await page.locator('.auth-overlay').waitFor({ state: 'detached' });
            token = await page.evaluate(() => localStorage.getItem('ms-token'));
            if (!token) throw new Error('không có phiên đăng nhập');
        });
        await step('Tạo sổ tay mới', 'live', async () => {
            await page.locator('.sidebar [data-tab=notebook]').click();
            await page.locator('[data-act=nb-new]').click();
            await page.locator('#app-dialog-input').fill(names.notebook);
            const r = await expectOk(Promise.all([page.waitForResponse(r => isApi(r, '/api/notebooks')), page.locator('#app-dialog-submit').click()]).then(x => x[0]), 'tạo sổ tay');
            notebookId = (await r.json()).id;
        });
        await step('Thêm nguồn văn bản vào sổ tay', 'live', async () => {
            await page.locator('#nb-source-add').click();
            await page.locator('#nb-method-text').click();
            await page.locator('#nb-txt-title').fill(names.source);
            await page.locator('#nb-txt-body').fill('Ti thể là bào quan tạo năng lượng cho tế bào. Lục lạp là nơi diễn ra quang hợp ở thực vật. Ribôxôm tổng hợp prôtêin.');
            await expectOk(Promise.all([page.waitForResponse(r => isApi(r, '/api/notebooks/{id}/sources/text')), page.locator('[data-act=add-text]').click()]).then(x => x[0]), 'thêm nguồn');
            await page.locator('#nb-source-list').getByText(names.source).first().waitFor({ timeout: 10000 });
        });
        // Bước nào lỗi giữa chừng cũng không để hộp thoại mở che các bước sau.
        await page.evaluate(() => document.querySelectorAll('dialog[open]').forEach(d => d.close())).catch(() => { });
        await step('Tạo thẻ ghi nhớ', 'live', async () => {
            await page.locator('.sidebar [data-tab=flashcards]').click();
            await page.locator('#open-add-modal').click();
            await page.locator('#new-question').fill(names.card);
            await page.locator('#new-answer').fill('Đáp án smoke');
            await expectOk(Promise.all([page.waitForResponse(r => isApi(r, '/api/flashcards')), page.locator('#add-card-form [type=submit]').click()]).then(x => x[0]), 'tạo thẻ');
        });
        await step('Tạo công việc Kanban', 'live', async () => {
            await page.locator('.sidebar [data-tab=kanban]').click();
            await page.locator('#btn-new-task').click();
            await page.locator('#task-title').fill(names.task);
            await expectOk(Promise.all([page.waitForResponse(r => isApi(r, '/api/tasks')), page.locator('#task-modal-submit').click()]).then(x => x[0]), 'tạo việc');
        });
        await step('Tải lại: dữ liệu còn trên máy chủ và trên giao diện', 'live', async () => {
            await page.reload({ waitUntil: 'networkidle' });
            const cards = await api('/api/flashcards'), tasks = await api('/api/tasks'), nbs = await api('/api/notebooks');
            const sources = notebookId ? await api(`/api/notebooks/${notebookId}/sources`) : [];
            const has = (list, text) => JSON.stringify(list).includes(text);
            const missing = [['thẻ', cards, names.card], ['việc', tasks, names.task], ['sổ tay', nbs, names.notebook], ['nguồn', sources, names.source]]
                .filter(([, list, text]) => !has(list, text)).map(([n]) => n);
            if (missing.length) throw new Error(`mất sau tải lại: ${missing.join(', ')}`);
            await page.locator('.sidebar [data-tab=kanban]').click();
            await page.getByText(names.task).first().waitFor({ timeout: 10000 });
            return 'API + DB còn đủ 4 mục; giao diện Kanban hiện việc vừa tạo';
        });
        await step('API lỗi khi tạo việc: báo lỗi, không báo thành công giả', 'mock', async () => {
            await page.route('**/api/tasks', route => route.request().method() === 'POST'
                ? route.fulfill({ status: 500, contentType: 'application/json', body: JSON.stringify({ message: 'Máy chủ chưa xử lý được yêu cầu. Hãy thử lại sau.', code: 'server_error' }) })
                : route.continue());
            await page.locator('#btn-new-task').click();
            await page.locator('#task-title').fill(names.badTask);
            await page.locator('#task-modal-submit').click();
            await page.locator('#task-form-error').waitFor({ state: 'visible', timeout: 5000 });
            const msg = (await page.locator('#task-form-error').innerText()).trim();
            if (!msg) throw new Error('không có thông báo lỗi');
            await page.unroute('**/api/tasks');
            await page.reload({ waitUntil: 'networkidle' });
            if (JSON.stringify(await api('/api/tasks')).includes(names.badTask)) throw new Error('việc lỗi lại có trên máy chủ');
            return `hiện: "${msg.slice(0, 80)}"; sau tải lại không có việc lỗi`;
        });
        await step('API lỗi khi tạo thẻ: không báo đã lưu lên máy chủ', 'mock', async () => {
            const toasts = [];
            await page.route('**/api/flashcards', route => route.request().method() === 'POST'
                ? route.fulfill({ status: 503, contentType: 'application/json', body: '{"message":"Dịch vụ tạm gián đoạn.","code":"server_error"}' }) : route.continue());
            await page.locator('.sidebar [data-tab=flashcards]').click();
            await page.locator('#open-add-modal').click();
            await page.locator('#new-question').fill(`Thẻ lỗi ${tag}`);
            await page.locator('#new-answer').fill('x');
            await page.locator('#add-card-form [type=submit]').click();
            await page.waitForTimeout(1500);
            // Chỉ giữ thông báo nói về kết quả lưu (bỏ chữ hướng dẫn cố định của trang cũng nằm trong role=status).
            for (const t of await page.locator('.toast, .notification-toast, [role=alert], [role=status], #app-dialog-message').allInnerTexts())
                if (/lỗi|chưa lưu|không lưu|thất bại|đã lưu|thành công|đồng bộ/i.test(t)) toasts.push(t.trim().slice(0, 100));
            await page.unroute('**/api/flashcards');
            const onServer = JSON.stringify(await api('/api/flashcards')).includes(`Thẻ lỗi ${tag}`);
            if (onServer) throw new Error('thẻ lỗi lại có trên máy chủ');
            const claimsSaved = toasts.some(t => /đã lưu|thành công/i.test(t) && !/chưa|lỗi|không/i.test(t));
            if (claimsSaved) throw new Error(`giao diện báo thành công: ${toasts.join(' | ')}`);
            return `máy chủ không có thẻ lỗi; thông báo trên trang: ${toasts.join(' | ') || '(không có — thẻ chỉ ở máy, chưa đồng bộ)'}`;
        });
        results.push(['Gọi AI (Gemini)', 'tùy chọn', 'Không chạy', 'smoke không cần key/quota; AI kiểm riêng khi có key']);

        let sha = 'không rõ';
        try { sha = execSync('git rev-parse --short HEAD', { cwd: __dirname }).toString().trim() + (execSync('git status --porcelain', { cwd: __dirname }).toString().trim() ? ' (+ thay đổi chưa commit)' : ''); } catch { }
        log(`# Issue #114 — smoke toàn luồng trên ${base}`);
        log(`Thời điểm: ${new Date().toISOString()} · Mã nguồn: ${sha} · Trình duyệt: ${browser.version()} (headless) · tài khoản thử: smoke114-${tag}@example.com (mật khẩu ngẫu nhiên không ghi lại)`);
        log('\n| Bước | Loại | Kết quả | Ghi chú |\n|---|---|---|---|');
        results.forEach(([n, k, r, note]) => log(`| ${n} | ${k} | ${r} | ${note.replace(/\|/g, '/')} |`));
        const failed = results.filter(r => r[2] === 'Fail').length;
        log(`\nKết quả: ${failed ? `FAIL (${failed})` : 'PASS'}`);
        if (out) fs.writeFileSync(out, lines.join('\n') + '\n');
        process.exitCode = failed ? 1 : 0;
    } finally {
        await context.close();
        await browser.close();
    }
})().catch(e => { console.error(e); process.exitCode = 1; });
