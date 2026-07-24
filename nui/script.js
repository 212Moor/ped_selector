let allPeds = [];
let selectedPed = null;

window.addEventListener('message', (event) => {
    const data = event.data;

    if (data.action === 'open') {
        document.body.style.display = 'flex';
        allPeds = [];
        updateList('');
    } 
    else if (data.action === 'addPeds') {
        allPeds.push(...data.peds);
        updateList(document.getElementById('search').value);
    }
    else if (data.action === 'close') {
        document.body.style.display = 'none';
    }
});

function updateList(filter) {
    const list = document.getElementById('list');
    list.innerHTML = '';

    allPeds
        .filter(p => p.toLowerCase().includes(filter.toLowerCase()))
        .slice(0, 300)
        .forEach(p => {
            const div = document.createElement('div');
            div.classList.add('item');
            div.textContent = p;
            div.onclick = () => {
                selectedPed = p;
                previewPed(p);
            };
            list.appendChild(div);
        });
}

function previewPed(ped) {
    fetch(`https://${GetParentResourceName()}/previewPed`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ ped })
    });
}

document.getElementById('apply').addEventListener('click', () => {
    if (!selectedPed) return;
    fetch(`https://${GetParentResourceName()}/selectPed`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ ped: selectedPed })
    });
});

document.getElementById('search').addEventListener('input', (e) => {
    updateList(e.target.value);
});

document.getElementById('close').addEventListener('click', () => {
    fetch(`https://${GetParentResourceName()}/closeMenu`, { method: 'POST' });
});
