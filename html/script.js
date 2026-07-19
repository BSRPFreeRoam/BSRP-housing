(() => {
    const res = typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'bsrp-housing';
    const app = document.getElementById('app');
    let current = null;

    const $ = (s) => document.querySelector(s);
    const money = (n) => '$' + (Number(n) || 0).toLocaleString('en-US');

    function post(name, data = {}) {
        return fetch(`https://${res}/${name}`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json; charset=UTF-8' },
            body: JSON.stringify(data),
        }).then((r) => r.json()).catch(() => ({}));
    }

    function renderActions(d) {
        const box = $('#actions');
        box.innerHTML = '';
        const add = (label, cls, action) => {
            const b = document.createElement('button');
            b.type = 'button';
            b.className = 'btn ' + (cls || '');
            b.textContent = label;
            b.addEventListener('click', action);
            box.appendChild(b);
        };

        if (!d.owned) {
            add('BUY HOUSE', 'primary', () => post('buy', { name: d.name }));
        } else if (d.isMine) {
            add('ENTER', 'primary', () => post('enter', { name: d.name }));
            add(d.locked ? 'UNLOCK DOOR' : 'LOCK DOOR', 'ghost', () => post('lock', { name: d.name }));
            add('SELL HOUSE', 'danger', () => post('sell', { name: d.name }));
        } else if (d.hasAccess || !d.locked) {
            add('ENTER', 'primary', () => post('enter', { name: d.name }));
        } else {
            add('LOCKED', 'ghost', () => {});
        }

        if (d.inside && d.isMine) {
            add('OPEN STASH', 'primary', () => post('stash', { name: d.name }));
            add('LEAVE HOUSE', 'danger', () => post('leave', {}));
        }
    }

    window.addEventListener('message', (e) => {
        const { action, data } = e.data || {};
        if (action === 'open') {
            current = data;
            app.classList.remove('hidden');
            $('#title').textContent = (data.label || 'HOUSE').toUpperCase();
            $('#subtitle').textContent = `TIER ${data.tier || '?'} // ${data.name || ''}`;
            $('#price').textContent = money(data.price);
            $('#tier').textContent = String(data.tier || 1);
            $('#status').textContent = data.owned ? (data.isMine ? 'OWNED BY YOU' : 'OWNED') : 'FOR SALE';
            $('#lock').textContent = data.owned ? (data.locked ? 'LOCKED' : 'UNLOCKED') : '—';
            renderActions(data);
        } else if (action === 'close') {
            app.classList.add('hidden');
            current = null;
        }
    });

    $('#btnClose').addEventListener('click', () => post('close'));
    document.addEventListener('keydown', (e) => {
        if (e.key === 'Escape' && !app.classList.contains('hidden')) post('close');
    });
})();
