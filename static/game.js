// ================================================================
// ПЯТНАШКИ — game.js
// Логика кликов по плиткам и AJAX-запросы к серверу
// ================================================================

let lastMoveTime = Date.now();
let redoAvailable = false;

// ================================================================
// ТАЙМЕР — интеграция с HTML
// ================================================================

let timerInterval = null;
let timerSeconds = 0;
let timerRunning = true;
let timeLimitSeconds = 0;

// Инициализация таймера
function initGameTimer() {
    // Получаем лимит времени из глобальной переменной (установлена в HTML)
    if (typeof TIME_LIMIT_SECONDS !== 'undefined') {
        timeLimitSeconds = TIME_LIMIT_SECONDS;
    }
    
    // Пытаемся восстановить время из sessionStorage
    if (typeof SESSION_ID !== 'undefined') {
        const savedTime = sessionStorage.getItem('puzzle_timer_' + SESSION_ID);
        if (savedTime) {
            timerSeconds = parseInt(savedTime);
        }
    }
    
    updateTimerDisplay();
    
    // Запускаем таймер
    startTimer();
}

// Запуск таймера
function startTimer() {
    if (timerInterval) clearInterval(timerInterval);
    
    timerInterval = setInterval(() => {
        if (timerRunning) {
            timerSeconds++;
            
            // Проверка на превышение лимита времени
            if (timeLimitSeconds > 0 && timerSeconds >= timeLimitSeconds) {
                timerSeconds = timeLimitSeconds;
                updateTimerDisplay();
                stopTimer();
                checkTimeOut();
            } else {
                updateTimerDisplay();
            }
            
            // Сохраняем в sessionStorage
            if (typeof SESSION_ID !== 'undefined') {
                sessionStorage.setItem('puzzle_timer_' + SESSION_ID, timerSeconds.toString());
            }
        }
    }, 1000);
}

// Остановка таймера
function stopTimer() {
    timerRunning = false;
    if (timerInterval) {
        clearInterval(timerInterval);
        timerInterval = null;
    }
}

// Возобновление таймера
function resumeTimer() {
    timerRunning = true;
    if (!timerInterval) {
        startTimer();
    }
}

// Сброс таймера
function resetTimer() {
    timerSeconds = 0;
    timerRunning = true;
    updateTimerDisplay();
    if (typeof SESSION_ID !== 'undefined') {
        sessionStorage.removeItem('puzzle_timer_' + SESSION_ID);
    }
    if (!timerInterval) {
        startTimer();
    }
}

// Обновление отображения таймера
function updateTimerDisplay() {
    const timerEl = document.getElementById('game-timer');
    if (timerEl) {
        const minutes = Math.floor(timerSeconds / 60);
        const seconds = timerSeconds % 60;
        timerEl.textContent = `${minutes.toString().padStart(2, '0')}:${seconds.toString().padStart(2, '0')}`;
        
        // Добавляем класс предупреждения если осталось мало времени
        if (timeLimitSeconds > 0) {
            const remaining = timeLimitSeconds - timerSeconds;
            if (remaining < 60) { // Меньше минуты
                timerEl.classList.add('warning');
            } else {
                timerEl.classList.remove('warning');
            }
        }
    }
}

// Проверка на превышение времени
async function checkTimeOut() {
    try {
        const res = await fetch('/game/check-timeout', { 
            method: 'POST',
            headers: { 'Content-Type': 'application/json' }
        });
        
        const data = await res.json();
        
        if (data.timeout) {
            showTimeoutModal();
        }
    } catch (e) {
        console.error('Ошибка проверки времени:', e);
    }
}

// Показ модального окна при превышении времени
function showTimeoutModal() {
    stopTimer();
    
    const modal = document.getElementById('timeout-modal');
    const stepsEl = document.getElementById('timeout-steps');
    const stepsCount = document.getElementById('steps-count');
    
    if (stepsEl && stepsCount) {
        stepsEl.textContent = stepsCount.textContent;
    }
    
    if (modal) {
        modal.style.display = 'flex';
        
        // Удаляем сохранённые данные таймера
        if (typeof SESSION_ID !== 'undefined') {
            sessionStorage.removeItem('puzzle_timer_' + SESSION_ID);
        }
    }
}

// ================================================================
// ОСНОВНАЯ ЛОГИКА ИГРЫ
// ================================================================

function showMessage(text, type = '') {
    const el = document.getElementById('message');
    if (!el) return;
    
    el.textContent = text;
    el.className = 'game-message ' + type;
    el.style.display = 'block';
    setTimeout(() => { 
        if (el) el.style.display = 'none'; 
    }, 2000);
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
    if (data.board) {
        updateMiniMap(data.board);
    }
}

function updateMiniMap(board) {
    const miniBoard = document.querySelector('.mini-board');
    if (!miniBoard || !board) return;
    
    const tiles = miniBoard.querySelectorAll('.mini-tile');
    const flatBoard = board.flat();
    
    tiles.forEach((tile, index) => {
        if (index < flatBoard.length) {
            const value = flatBoard[index];
            if (value === 0) {
                tile.classList.add('mini-empty');
                tile.textContent = '';
            } else {
                tile.classList.remove('mini-empty');
                tile.textContent = value;
            }
            tile.dataset.value = value;
        }
    });
}

function renderBoard(board) {
    const boardEl = document.getElementById('board');
    if (!boardEl) return;
    
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
    // Останавливаем таймер
    stopTimer();
    
    const modal = document.getElementById('win-modal');
    const finalSteps = document.getElementById('final-steps');
    const finalTime = document.getElementById('final-time');
    
    if (finalSteps) finalSteps.textContent = steps;
    
    // Показываем итоговое время
    const minutes = Math.floor(timerSeconds / 60);
    const seconds = timerSeconds % 60;
    if (finalTime) finalTime.textContent = `${minutes.toString().padStart(2, '0')}:${seconds.toString().padStart(2, '0')}`;
    
    // Удаляем сохранённые данные таймера
    if (typeof SESSION_ID !== 'undefined') {
        sessionStorage.removeItem('puzzle_timer_' + SESSION_ID);
    }
    
    if (modal) modal.style.display = 'flex';
}

function showHintModal(hintData) {
    const modal = document.getElementById('hint-modal');
    const content = document.getElementById('hint-content');
    
    if (content && hintData) {
        content.innerHTML = `
            <div class="hint-stat">📊 Не на месте: <strong>${hintData.misplaced || 0}</strong></div>
            <div class="hint-stat">📏 Манхэттен: <strong>${hintData.manhattan || 0}</strong></div>
            <div class="hint-stat">✅ На месте: <strong>${hintData.correct || 0}</strong></div>
            <div class="hint-stat">📈 Прогресс: <strong>${hintData.progress || 0}%</strong></div>
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
    
    // Убеждаемся что таймер работает
    if (!timerRunning && timerInterval) {
        resumeTimer();
    }
    
    try {
        const res = await fetch('/game/move', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ tile: parseInt(tile) })
        });

        const data = await res.json();

        if (data.error) {
            showMessage(data.error, 'error');
            
            // Если время вышло, показываем модальное окно
            if (data.error === 'Время вышло') {
                showTimeoutModal();
            }
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
        console.error('Ошибка при ходе:', e);
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
        console.error('Ошибка при отмене:', e);
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
        console.error('Ошибка при возврате:', e);
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
        console.error('Ошибка получения подсказки:', e);
        showMessage('Ошибка получения подсказки', 'error');
    }
}

// ================================================================
// ОБРАБОТЧИКИ СОБЫТИЙ
// ================================================================

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
        case 'escape': // Закрытие модальных окон
            document.querySelectorAll('.modal').forEach(modal => {
                modal.style.display = 'none';
            });
            break;
    }
});

// Инициализация при загрузке страницы
document.addEventListener('DOMContentLoaded', () => {
    const btnUndo = document.getElementById('btn-undo');
    const btnRedo = document.getElementById('btn-redo');
    const btnHint = document.getElementById('btn-hint');
    
    if (btnUndo) btnUndo.addEventListener('click', undoMove);
    if (btnRedo) btnRedo.addEventListener('click', redoMove);
    if (btnHint) btnHint.addEventListener('click', getHint);
    
    // Инициализируем таймер
    initGameTimer();
    
    // Закрытие модальных окон по клику вне
    document.querySelectorAll('.modal').forEach(modal => {
        modal.addEventListener('click', (e) => {
            if (e.target === modal) {
                modal.style.display = 'none';
                
                // Если это модальное окно победы, перенаправляем на главную через 2 секунды
                if (modal.id === 'win-modal') {
                    setTimeout(() => {
                        window.location.href = '/';
                    }, 2000);
                }
            }
        });
    });
    
    // Сохраняем время перед уходом со страницы
    window.addEventListener('beforeunload', () => {
        if (timerRunning && typeof SESSION_ID !== 'undefined') {
            sessionStorage.setItem('puzzle_timer_' + SESSION_ID, timerSeconds.toString());
        }
    });
});