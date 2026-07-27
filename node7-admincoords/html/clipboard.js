'use strict';

const resourceName = typeof GetParentResourceName === 'function'
    ? GetParentResourceName()
    : 'node7-admincoords';

async function report(requestId, success) {
    try {
        await fetch(`https://${resourceName}/clipboardResult`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json; charset=UTF-8' },
            body: JSON.stringify({ requestId, success })
        });
    } catch (_) {
        // The Lua side also prints every value to F8 as a recovery path.
    }
}

function legacyCopy(text) {
    const textarea = document.createElement('textarea');
    textarea.value = text;
    textarea.setAttribute('readonly', '');
    textarea.style.position = 'fixed';
    textarea.style.left = '-10000px';
    textarea.style.top = '-10000px';
    textarea.style.opacity = '0';
    document.body.appendChild(textarea);
    textarea.focus({ preventScroll: true });
    textarea.select();
    textarea.setSelectionRange(0, textarea.value.length);

    let success = false;
    try {
        success = document.execCommand('copy') === true;
    } catch (_) {
        success = false;
    }

    textarea.remove();
    return success;
}

window.addEventListener('message', async (event) => {
    const data = event.data || {};
    if (data.action !== 'copyText') return;

    const requestId = String(data.requestId || '');
    const text = String(data.text ?? '');
    let success = false;

    if (navigator.clipboard && typeof navigator.clipboard.writeText === 'function') {
        try {
            await navigator.clipboard.writeText(text);
            success = true;
        } catch (_) {
            success = false;
        }
    }

    if (!success) {
        success = legacyCopy(text);
    }

    await report(requestId, success);
});
