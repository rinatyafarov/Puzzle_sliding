// ================================================================
// ПЯТНАШКИ — game.js
// Логика кликов по плиткам и AJAX-запросы к серверу
// ================================================================

let lastMoveTime = Date.now();
let redoAvailable = false;

function showMessage(text, type = '') {
    const el = document.getElementById('message');
    el.textContent = text;
    el.className = 'game-message ' + type;
    el.style.display = 'block';
    setTimeout(() => { el.style.display = 'none'; }, 2000);
}

function updateStats(data) {
    const steps = document.getElementById('steps-count');
    const misplaced = document.getElementById('misplaced-count');
    const manhattan = document.getElementById('manhattan-distance');
    const progress = document.getElementById('progress-pct');
    const bar = document.getElementById('progress-bar');
    const undoBtn = document.getElementById('btn-undo');
    const redoBtn = document.getElementById('btn-redo');

    if (steps) steps.textContent = data.steps ?? steps.textContent;
    if (misplaced) misplaced.textContent = data.misplaced ?? misplaced.textContent;
    if (manhattan) manhattan.textContent = data.manhattan ?? manhattan.textContent;
    if (progress) progress.textContent = (data.progress ?? '') + '%';
    if (bar) bar.style.width = (data.progress ?? 0) + '%';
    
    // Обновляем состояние кнопок
    if (undoBtn) {
        undoBtn.disabled = (data.steps === 0);
    }
    if (redoBtn) {
        redoBtn.disabled = !data.redoAvailable;
        redoAvailable = data.redoAvailable || false;
    }
    
    // Обновляем мини-карту если есть
    updateMiniMap(data.board);
}

function updateMiniMap(board) {
    const miniBoard = document.querySelector('.mini-board');
    if (!miniBoard || !board) return;
    
    const tiles = miniBoard.querySelectorAll('.mini-tile');
    const flatBoard = board.flat();
    
    tiles.forEach((tile, index) => {
        const value = flatBoard[index];
        if (value === 0) {
            tile.classList.add('mini-empty');
            tile.textContent = '';
        } else {
            tile.classList.remove('mini-empty');
            tile.textContent = value;
        }
        tile.dataset.value = value;
    });
}

function renderBoard(board) {
    const boardEl = document.getElementById('board');
    const gridSize = board.length;
    boardEl.innerHTML = '';
    boardEl.style.setProperty('--grid-size', gridSize);

    board.forEach((row, r) => {
        row.forEach((val, c) => {
            const tile = document.createElement('div');
            tile.className = 'tile' + (val === 0 ? ' tile-empty' : '');
            tile.dataset.value = val;
            tile.dataset.row = r;
            tile.dataset.col = c;
            
            const span = document.createElement('span');
            if (val === 0) {
                span.className = 'tile-empty-symbol';
                span.textContent = '◻';
            } else {
                span.className = 'tile-number';
                span.textContent = val;
                tile.onclick = () => moveTile(val);
            }
            
            tile.appendChild(span);
            boardEl.appendChild(tile);
        });
    });
    
    updateMiniMap(board);
}

function showWinModal(steps) {
    const modal = document.getElementById('win-modal');
    const finalSteps = document.getElementById('final-steps');
    const finalTime = document.getElementById('final-time');
    
    if (finalSteps) finalSteps.textContent = steps;
    
    // Рассчитываем время
    const endTime = new Date();
    const startTime = window.startTime || new Date();
    const diff = Math.floor((endTime - startTime) / 1000);
    const minutes = Math.floor(diff / 60);
    const seconds = diff % 60;
    if (finalTime) finalTime.textContent = `${minutes.toString().padStart(2, '0')}:${seconds.toString().padStart(2, '0')}`;
    
    if (modal) modal.style.display = 'flex';
}

function showHintModal(hintData) {
    const modal = document.getElementById('hint-modal');
    const content = document.getElementById('hint-content');
    
    if (content && hintData) {
        content.innerHTML = `
            <div class="hint-stat">📊 Не на месте: <strong>${hintData.misplaced}</strong></div>
            <div class="hint-stat">📏 Манхэттен: <strong>${hintData.manhattan}</strong></div>
            <div class="hint-stat">✅ На месте: <strong>${hintData.correct}</strong></div>
            <div class="hint-stat">📈 Прогресс: <strong>${hintData.progress}%</strong></div>
            <p class="hint-tip">💭 Попробуйте собрать углы и края в первую очередь</p>
        `;
    }
    
    if (modal) modal.style.display = 'flex';
}

async function moveTile(tile) {
    // Защита от двойного клика
    const now = Date.now();
    if (now - lastMoveTime < 200) return;
    lastMoveTime = now;
    
    try {
        const res = await fetch('/game/move', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ tile })
        });

        const data = await res.json();

        if (data.error) {
            showMessage(data.error, 'error');
            return;
        }

        if (data.status === 'solved') {
            if (data.board) renderBoard(data.board);
            updateStats({...data, redoAvailable: false});
            setTimeout(() => showWinModal(data.steps), 400);
            return;
        }

        if (data.board) renderBoard(data.board);
        updateStats({...data, redoAvailable: true});

    } catch (e) {
        showMessage('Ошибка соединения', 'error');
    }
}

async function undoMove() {
    try {
        const res = await fetch('/game/undo', { method: 'POST' });
        const data = await res.json();
        if (data.error) { 
            showMessage(data.error, 'error'); 
            return; 
        }
        if (data.board) renderBoard(data.board);
        updateStats({...data, redoAvailable: true});
        showMessage('Ход отменён');
    } catch (e) {
        showMessage('Ошибка соединения', 'error');
    }
}

async function redoMove() {
    try {
        const res = await fetch('/game/redo', { method: 'POST' });
        const data = await res.json();
        if (data.error) { 
            showMessage(data.error, 'error'); 
            return; 
        }
        if (data.board) renderBoard(data.board);
        updateStats({...data, redoAvailable: false});
        showMessage('Ход возвращён');
    } catch (e) {
        showMessage('Ошибка соединения', 'error');
    }
}

async function getHint() {
    try {
        const res = await fetch('/game/hint', { method: 'POST' });
        const data = await res.json();
        if (data.error) {
            showMessage(data.error, 'error');
            return;
        }
        showHintModal(data);
    } catch (e) {
        showMessage('Ошибка получения подсказки', 'error');
    }
}

// Обработка горячих клавиш
document.addEventListener('keydown', (e) => {
    // Игнорируем если ввод в поле
    if (e.target.tagName === 'INPUT' || e.target.tagName === 'TEXTAREA') return;
    
    const key = e.key.toLowerCase();
    
    // Цифры 1-9 для ходов
    if (key >= '1' && key <= '9') {
        const tile = parseInt(key);
        moveTile(tile);
        e.preventDefault();
    }
    
    // Горячие клавиши
    switch(key) {
        case 'z': // Undo
            if (e.ctrlKey || e.metaKey) {
                e.preventDefault();
                undoMove();
            }
            break;
        case 'y': // Redo
            if (e.ctrlKey || e.metaKey) {
                e.preventDefault();
                redoMove();
            }
            break;
        case 'h': // Hint
            e.preventDefault();
            getHint();
            break;
    }
});

// Назначить обработчики кнопок
document.addEventListener('DOMContentLoaded', () => {
    const btnUndo = document.getElementById('btn-undo');
    const btnRedo = document.getElementById('btn-redo');
    const btnHint = document.getElementById('btn-hint');
    
    if (btnUndo) btnUndo.addEventListener('click', undoMove);
    if (btnRedo) btnRedo.addEventListener('click', redoMove);
    if (btnHint) btnHint.addEventListener('click', getHint);
    
    // Сохраняем время начала для таймера
    window.startTime = new Date();
    
    // Закрытие модальных окон по клику вне
    document.querySelectorAll('.modal').forEach(modal => {
        modal.addEventListener('click', (e) => {
            if (e.target === modal) {
                modal.style.display = 'none';
            }
        });
    });
});