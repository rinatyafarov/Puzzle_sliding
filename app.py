from flask import Flask, render_template, request, redirect, url_for, session, jsonify
import db
import json

app = Flask(__name__)
app.secret_key = "sliding_puzzle_secret_key"


# ================================================================
# ВСПОМОГАТЕЛЬНЫЕ ФУНКЦИИ
# ================================================================

def get_current_user_id():
    return session.get("user_id")


def get_active_session_id():
    """Возвращает ID активной игровой сессии из Flask-сессии."""
    return session.get("game_session_id")


def get_active_attempt(session_id):
    """Возвращает активную попытку по session_id."""
    return db.fetch_one(
        """SELECT GA.ID, GA.CURRENT_STATE, GA.UNDO_POINTER,
                  GA.CURRENT_MISPLACED_TILES, GA.CURRENT_MANHATTAN_DISTANCE,
                  GA.INITIAL_MANHATTAN_DISTANCE,
                  PS.GRID_SIZE, DL.NAME AS DIFFICULTY,
                  PZ.TARGET_STATE, PZ.ID AS PUZZLE_ID
           FROM GAME_ATTEMPTS GA
           JOIN GAME_STATUSES GST ON GA.STATUS_ID = GST.ID
           JOIN PUZZLES PZ ON GA.PUZZLE_ID = PZ.ID
           JOIN PUZZLE_SIZES PS ON PZ.PUZZLE_SIZE_ID = PS.ID
           JOIN DIFFICULTY_LEVELS DL ON PZ.DIFFICULTY_ID = DL.ID
           WHERE GA.SESSION_ID = :1 AND GST.NAME = 'active' AND ROWNUM = 1""",
        [session_id]
    )


def read_clob(value):
    """Читает CLOB или строку и возвращает str."""
    if value is None:
        return ""
    # oracledb возвращает CLOB как объект с методом read()
    if hasattr(value, "read"):
        return value.read()
    return str(value)


def parse_board(state_str, grid_size):
    """Преобразует состояние в двумерный список и flat-список."""
    s = read_clob(state_str)
    s = s.strip()

    if not s:
        return [], []

    try:
        data = json.loads(s)
    except json.JSONDecodeError:
        # Если не JSON, пробуем CSV
        return parse_board_csv(s, grid_size)

    # Проверяем формат данных
    if data and len(data) > 0 and isinstance(data[0], list):
        # Это двумерный массив
        flat = []
        for row in data:
            flat.extend(row)
        # Проверяем, что размер соответствует grid_size
        expected_length = grid_size * grid_size
        if len(flat) != expected_length:
            print(f"Warning: Board size mismatch. Expected {expected_length}, got {len(flat)}")
            # Пытаемся обрезать или дополнить
            if len(flat) > expected_length:
                flat = flat[:expected_length]
            elif len(flat) < expected_length:
                flat.extend([0] * (expected_length - len(flat)))
        return data, flat
    else:
        # Это плоский список
        flat = data
        expected_length = grid_size * grid_size
        if len(flat) != expected_length:
            print(f"Warning: Board size mismatch. Expected {expected_length}, got {len(flat)}")
            if len(flat) > expected_length:
                flat = flat[:expected_length]
            elif len(flat) < expected_length:
                flat.extend([0] * (expected_length - len(flat)))

        board = []
        for r in range(grid_size):
            start_idx = r * grid_size
            end_idx = (r + 1) * grid_size
            if end_idx <= len(flat):
                board.append(flat[start_idx:end_idx])
            else:
                board.append([])
        return board, flat


def parse_board_csv(csv_str, grid_size):
    """Парсит CSV-строку в доску и flat-список."""
    try:
        flat = [int(x.strip()) for x in csv_str.split(",")]
    except ValueError:
        return [], []
    
    board = []
    for r in range(grid_size):
        start_idx = r * grid_size
        end_idx = (r + 1) * grid_size
        if end_idx <= len(flat):
            board.append(flat[start_idx:end_idx])
        else:
            board.append([])
    return board, flat


def flat_to_json(flat):
    """Преобразует плоский список в JSON-строку."""
    return json.dumps(flat)


def compute_metrics(flat, target_flat, grid_size):
    """Считает misplaced и manhattan distance."""
    misplaced = 0
    manhattan = 0
    correct = 0
    n = grid_size
    
    # Убеждаемся, что target_flat - плоский список
    if target_flat and len(target_flat) > 0 and isinstance(target_flat[0], list):
        # Преобразуем двумерный в плоский
        new_target = []
        for row in target_flat:
            new_target.extend(row)
        target_flat = new_target
    
    # Создаем словарь позиций для быстрого поиска
    target_positions = {}
    for idx, val in enumerate(target_flat):
        if val != 0:  # Не учитываем пустую клетку
            target_positions[val] = idx
    
    for i, val in enumerate(flat):
        if val == 0:
            continue
            
        if val in target_positions:
            target_pos = target_positions[val]
            
            if i == target_pos:
                correct += 1
            else:
                misplaced += 1
                
            cur_row, cur_col = divmod(i, n)
            tgt_row, tgt_col = divmod(target_pos, n)
            manhattan += abs(cur_row - tgt_row) + abs(cur_col - tgt_col)
        else:
            # Если значение не найдено в target_flat, считаем его неправильным
            misplaced += 1
            # Добавляем максимальное расстояние
            manhattan += 2 * n
    
    return misplaced, manhattan, correct


def progress_pct(init_manhattan, cur_manhattan):
    if init_manhattan == 0:
        return 100
    return round((init_manhattan - cur_manhattan) / init_manhattan * 100, 1)


# ================================================================
# АВТОРИЗАЦИЯ
# ================================================================

@app.route("/login", methods=["GET", "POST"])
def login():
    error = None
    if request.method == "POST":
        username = request.form.get("username", "").strip()
        if not username:
            error = "Введите имя пользователя."
        else:
            user = db.fetch_one(
                "SELECT ID, USERNAME FROM USERS WHERE USERNAME = :1",
                [username]
            )
            if not user:
                db.execute_query(
                    "INSERT INTO USERS (ID, DB_USERNAME, USERNAME, GAMES_COUNT, CREATED_AT) "
                    "VALUES (SEQ_USERS.NEXTVAL, :1, :2, 0, SYSTIMESTAMP)",
                    [username, username]
                )
                user = db.fetch_one(
                    "SELECT ID, USERNAME FROM USERS WHERE USERNAME = :1",
                    [username]
                )
            session["user_id"] = user["id"]
            session["username"] = user["username"]
            # Восстановить активную сессию если есть
            active = db.fetch_one(
                "SELECT GS.ID FROM GAME_SESSIONS GS "
                "JOIN GAME_STATUSES GST ON GS.STATUS_ID = GST.ID "
                "WHERE GS.USER_ID = :1 AND GST.NAME = 'active' AND ROWNUM = 1",
                [user["id"]]
            )
            if active:
                session["game_session_id"] = active["id"]
            return redirect(url_for("index"))
    return render_template("login.html", error=error)


@app.route("/logout")
def logout():
    session.clear()
    return redirect(url_for("login"))


# ================================================================
# ГЛАВНАЯ
# ================================================================

@app.route("/")
def index():
    if not get_current_user_id():
        return redirect(url_for("login"))

    puzzles = db.fetch_all(
        """SELECT P.ID, P.SEED, PS.GRID_SIZE, DL.NAME AS DIFFICULTY,
                  DL.SHUFFLE_MOVES,
                  P.IS_DAILY,
                  COUNT(DISTINCT GS.ID) AS TIMES_PLAYED,
                  SUM(CASE WHEN GST.NAME='solved' THEN 1 ELSE 0 END) AS TIMES_SOLVED
           FROM PUZZLES P
           JOIN PUZZLE_SIZES PS ON P.PUZZLE_SIZE_ID = PS.ID
           JOIN DIFFICULTY_LEVELS DL ON P.DIFFICULTY_ID = DL.ID
           LEFT JOIN GAME_SESSIONS GS ON P.ID = GS.PUZZLE_ID
           LEFT JOIN GAME_STATUSES GST ON GS.STATUS_ID = GST.ID
           GROUP BY P.ID, P.SEED, PS.GRID_SIZE, DL.NAME, DL.SHUFFLE_MOVES, P.IS_DAILY, DL.ID
           ORDER BY DL.ID, PS.GRID_SIZE"""
    )

    daily = db.fetch_one(
        """SELECT P.ID AS PUZZLE_ID, P.SEED, PS.GRID_SIZE, DL.NAME AS DIFFICULTY
           FROM PUZZLES P
           JOIN PUZZLE_SIZES PS ON P.PUZZLE_SIZE_ID = PS.ID
           JOIN DIFFICULTY_LEVELS DL ON P.DIFFICULTY_ID = DL.ID
           WHERE P.IS_DAILY = 1 AND ROWNUM = 1"""
    )

    active_game = None
    gsid = get_active_session_id()
    if gsid:
        active_game = get_active_attempt(gsid)

    return render_template(
        "index.html",
        puzzles=puzzles,
        daily=daily,
        active_game=active_game,
        username=session.get("username")
    )


# ================================================================
# ИГРА -- ЗАПУСК
# ================================================================

@app.route("/game/start/<int:puzzle_id>")
def start_game(puzzle_id):
    if not get_current_user_id():
        return redirect(url_for("login"))

    # Не запускать если уже есть активная
    gsid = get_active_session_id()
    if gsid and get_active_attempt(gsid):
        return redirect(url_for("game"))

    user_id = get_current_user_id()

    # Получить данные пазла
    puzzle = db.fetch_one(
        """SELECT PZ.ID, PS.GRID_SIZE, DL.SHUFFLE_MOVES,
                  PZ.INITIAL_STATE, PZ.TARGET_STATE, PS.DEFAULT_TIME_LIMIT
           FROM PUZZLES PZ
           JOIN PUZZLE_SIZES PS ON PZ.PUZZLE_SIZE_ID = PS.ID
           JOIN DIFFICULTY_LEVELS DL ON PZ.DIFFICULTY_ID = DL.ID
           WHERE PZ.ID = :1""",
        [puzzle_id]
    )
    if not puzzle:
        return redirect(url_for("index"))

    grid_size = puzzle["grid_size"]
    
    # Читаем JSON-строки из CLOB
    init_json = read_clob(puzzle["initial_state"])
    tgt_json = read_clob(puzzle["target_state"])
    
    # Преобразуем JSON в списки для вычислений
    try:
        init_data = json.loads(init_json)
        tgt_data = json.loads(tgt_json)
    except json.JSONDecodeError:
        return redirect(url_for("index"))
    
    # Преобразуем в плоские списки для вычислений
    if init_data and len(init_data) > 0 and isinstance(init_data[0], list):
        init_flat = []
        for row in init_data:
            init_flat.extend(row)
    else:
        init_flat = init_data
        
    if tgt_data and len(tgt_data) > 0 and isinstance(tgt_data[0], list):
        tgt_flat = []
        for row in tgt_data:
            tgt_flat.extend(row)
    else:
        tgt_flat = tgt_data
    
    # Вычисляем метрики
    misplaced, manhattan, correct = compute_metrics(init_flat, tgt_flat, grid_size)

    # Получить ID статуса active
    status_active_row = db.fetch_one("SELECT ID FROM GAME_STATUSES WHERE NAME='active'")
    if not status_active_row:
        db.execute_query("INSERT INTO GAME_STATUSES (ID, NAME) VALUES (SEQ_GAME_STATUSES.NEXTVAL, 'active')")
        status_active_row = db.fetch_one("SELECT ID FROM GAME_STATUSES WHERE NAME='active'")
    status_active = status_active_row["id"]
    
    action_move_row = db.fetch_one("SELECT ID FROM ACTION_TYPES WHERE NAME='move'")
    if not action_move_row:
        db.execute_query("INSERT INTO ACTION_TYPES (ID, NAME) VALUES (SEQ_ACTION_TYPES.NEXTVAL, 'move')")
        action_move_row = db.fetch_one("SELECT ID FROM ACTION_TYPES WHERE NAME='move'")
    action_move = action_move_row["id"]

    # Создать сессию
    timestamp_row = db.fetch_one("SELECT TO_CHAR(SYSDATE, 'YYYYMMDDHH24MISS') AS T FROM DUAL")
    token = f"{user_id}_{puzzle_id}_{timestamp_row['t']}"
    
    db.execute_query(
        """INSERT INTO GAME_SESSIONS
               (ID, USER_ID, PUZZLE_ID, STATUS_ID, SESSION_TOKEN,
                STEPS_COUNT, LAST_ACTIVITY_AT, START_TIME)
           VALUES (SEQ_GAME_SESSIONS.NEXTVAL, :1, :2, :3, :4,
                   0, SYSTIMESTAMP, SYSDATE)""",
        [user_id, puzzle_id, status_active, token]
    )
    
    gs = db.fetch_one("SELECT ID FROM GAME_SESSIONS WHERE SESSION_TOKEN=:1", [token])
    if not gs:
        gs = db.fetch_one(
            "SELECT ID FROM GAME_SESSIONS WHERE USER_ID = :1 AND SESSION_TOKEN LIKE :2 ORDER BY ID DESC",
            [user_id, f"{user_id}_{puzzle_id}%"]
        )
    gs_id = gs["id"]

    # Создать попытку
    db.execute_query(
        """INSERT INTO GAME_ATTEMPTS
               (ID, SESSION_ID, USER_ID, PUZZLE_ID, GAME_MODE, CURRENT_STATE,
                INITIAL_MISPLACED_TILES, INITIAL_MANHATTAN_DISTANCE,
                CURRENT_MISPLACED_TILES, CURRENT_MANHATTAN_DISTANCE,
                UNDO_POINTER, STATUS_ID, STARTED_AT)
           VALUES (SEQ_GAME_ATTEMPTS.NEXTVAL, :1, :2, :3, 'numbers', :4,
                   :5, :6, :7, :8, 0, :9, SYSTIMESTAMP)""",
        [gs_id, user_id, puzzle_id, init_json,
         misplaced, manhattan, misplaced, manhattan, status_active]
    )
    
    ga = db.fetch_one("SELECT ID FROM GAME_ATTEMPTS WHERE SESSION_ID=:1 AND ROWNUM=1", [gs_id])
    if not ga:
        ga = db.fetch_one(
            "SELECT ID FROM GAME_ATTEMPTS WHERE SESSION_ID = :1 ORDER BY ID DESC",
            [gs_id]
        )
    ga_id = ga["id"]

    # Записать шаг 0 (начальное состояние)
    db.execute_query(
        """INSERT INTO GAME_STEPS
               (ID, SESSION_ID, ATTEMPT_ID, ACTION_ID, STATE_AFTER,
                IS_ACTUAL, IS_IMPORT, IS_MARK, STEP_INDEX, STEP_TIME)
           VALUES (SEQ_GAME_STEPS.NEXTVAL, :1, :2, :3, :4,
                   1, 0, 0, 0, SYSDATE)""",
        [gs_id, ga_id, action_move, init_json]
    )

    # Обновить счётчик игр пользователя
    db.execute_query(
        "UPDATE USERS SET GAMES_COUNT = GAMES_COUNT + 1, "
        "FIRST_GAME_DATE = NVL(FIRST_GAME_DATE, SYSDATE) WHERE ID = :1",
        [user_id]
    )

    session["game_session_id"] = gs_id
    return redirect(url_for("game"))


# ================================================================
# ИГРА -- СТРАНИЦА
# ================================================================

@app.route("/game")
def game():
    if not get_current_user_id():
        return redirect(url_for("login"))

    gsid = get_active_session_id()
    if not gsid:
        return redirect(url_for("index"))

    attempt = get_active_attempt(gsid)
    if not attempt:
        session.pop("game_session_id", None)
        return redirect(url_for("index"))

    grid_size = attempt["grid_size"]
    board, flat = parse_board(read_clob(attempt["current_state"]), grid_size)
    _, tgt_flat = parse_board(read_clob(attempt["target_state"]), grid_size)
    misplaced, manhattan, _ = compute_metrics(flat, tgt_flat, grid_size)
    pct = progress_pct(attempt["initial_manhattan_distance"], manhattan)

    active = {
        "session_id": gsid,
        "grid_size": grid_size,
        "difficulty": attempt["difficulty"],
        "current_step": attempt["undo_pointer"],
        "misplaced_tiles": misplaced,
        "manhattan_distance": manhattan,
        "progress_pct": pct,
        "initial_manhattan": attempt["initial_manhattan_distance"],
    }

    return render_template(
        "game.html",
        active=active,
        board=board,
        username=session.get("username")
    )


# ================================================================
# ИГРА -- ХОД
# ================================================================

@app.route("/game/move", methods=["POST"])
def make_move():
    if not get_current_user_id():
        return jsonify({"error": "Не авторизован"}), 401

    tile = request.json.get("tile")
    if tile is None:
        return jsonify({"error": "Не указана плитка"}), 400

    gsid = get_active_session_id()
    if not gsid:
        return jsonify({"error": "Нет активной игровой сессии"}), 400
        
    attempt = get_active_attempt(gsid)
    if not attempt:
        return jsonify({"error": "Нет активной попытки"}), 400

    grid_size = attempt["grid_size"]
    
    # Читаем текущее состояние как JSON
    current_state_json = read_clob(attempt["current_state"])
    target_state_json = read_clob(attempt["target_state"])
    
    board, flat = parse_board(current_state_json, grid_size)
    _, tgt_flat = parse_board(target_state_json, grid_size)

    # Найти позиции плитки и пустой клетки
    try:
        tile_value = int(tile)
        tile_pos = flat.index(tile_value)
        empty_pos = flat.index(0)
    except ValueError:
        return jsonify({"error": f"Плитка {tile} не найдена"}), 400

    # Проверить легальность хода
    diff = tile_pos - empty_pos
    if diff not in (1, -1, grid_size, -grid_size):
        return jsonify({"error": "Недопустимый ход"}), 400
    if diff in (1, -1):
        if tile_pos // grid_size != empty_pos // grid_size:
            return jsonify({"error": "Недопустимый ход"}), 400

    # Выполнить ход
    flat[empty_pos], flat[tile_pos] = flat[tile_pos], flat[empty_pos]
    
    # Сохраняем состояние как JSON
    new_state_json = json.dumps(flat)

    # Вычисляем метрики
    misplaced, manhattan, _ = compute_metrics(flat, tgt_flat, grid_size)
    next_idx = attempt["undo_pointer"] + 1
    
    # Получаем ID действия 'move' с проверкой
    action_move_row = db.fetch_one("SELECT ID FROM ACTION_TYPES WHERE NAME='move'")
    if not action_move_row:
        db.execute_query("INSERT INTO ACTION_TYPES (ID, NAME) VALUES (SEQ_ACTION_TYPES.NEXTVAL, 'move')")
        action_move_row = db.fetch_one("SELECT ID FROM ACTION_TYPES WHERE NAME='move'")
    action_move = action_move_row["id"]

    # Инвалидировать redo-ветку
    db.execute_query(
        "UPDATE GAME_STEPS SET IS_ACTUAL=0 WHERE ATTEMPT_ID=:1 AND STEP_INDEX > :2",
        [attempt["id"], attempt["undo_pointer"]]
    )

    # Записать шаг
    db.execute_query(
        """INSERT INTO GAME_STEPS
               (ID, SESSION_ID, ATTEMPT_ID, ACTION_ID, TILE_VALUE,
                STATE_AFTER, IS_ACTUAL, IS_IMPORT, IS_MARK, STEP_INDEX, STEP_TIME)
           VALUES (SEQ_GAME_STEPS.NEXTVAL, :1, :2, :3, :4,
                   :5, 1, 0, 0, :6, SYSDATE)""",
        [gsid, attempt["id"], action_move, tile_value, new_state_json, next_idx]
    )

    # Обновить попытку
    db.execute_query(
        """UPDATE GAME_ATTEMPTS
           SET CURRENT_STATE=:1, CURRENT_MISPLACED_TILES=:2,
               CURRENT_MANHATTAN_DISTANCE=:3, UNDO_POINTER=:4
           WHERE ID=:5""",
        [new_state_json, misplaced, manhattan, next_idx, attempt["id"]]
    )

    # Обновить сессию
    db.execute_query(
        "UPDATE GAME_SESSIONS SET STEPS_COUNT=STEPS_COUNT+1, LAST_ACTIVITY_AT=SYSTIMESTAMP WHERE ID=:1",
        [gsid]
    )

    # Перестраиваем доску для ответа
    board = [flat[r * grid_size:(r + 1) * grid_size] for r in range(grid_size)]
    pct = progress_pct(attempt["initial_manhattan_distance"], manhattan)

    # Проверить победу
    if flat == tgt_flat:
        status_solved_row = db.fetch_one("SELECT ID FROM GAME_STATUSES WHERE NAME='solved'")
        if not status_solved_row:
            db.execute_query("INSERT INTO GAME_STATUSES (ID, NAME) VALUES (SEQ_GAME_STATUSES.NEXTVAL, 'solved')")
            status_solved_row = db.fetch_one("SELECT ID FROM GAME_STATUSES WHERE NAME='solved'")
        status_solved = status_solved_row["id"]
        
        db.execute_query(
            "UPDATE GAME_ATTEMPTS SET STATUS_ID=:1, FINISHED_AT=SYSTIMESTAMP WHERE ID=:2",
            [status_solved, attempt["id"]]
        )
        db.execute_query(
            "UPDATE GAME_SESSIONS SET STATUS_ID=:1, END_TIME=SYSDATE WHERE ID=:2",
            [status_solved, gsid]
        )
        session.pop("game_session_id", None)
        return jsonify({
            "status": "solved", 
            "board": board, 
            "steps": next_idx, 
            "progress": 100,
            "misplaced": 0,
            "manhattan": 0
        })

    return jsonify({
        "status": "ok",
        "board": board,
        "steps": next_idx,
        "misplaced": misplaced,
        "manhattan": manhattan,
        "progress": pct
    })


# ================================================================
# ИГРА -- UNDO
# ================================================================

@app.route("/game/undo", methods=["POST"])
def undo_move():
    if not get_current_user_id():
        return jsonify({"error": "Не авторизован"}), 401

    gsid = get_active_session_id()
    if not gsid:
        return jsonify({"error": "Нет активной игровой сессии"}), 400
        
    attempt = get_active_attempt(gsid)
    if not attempt or attempt["undo_pointer"] <= 0:
        return jsonify({"error": "Нет ходов для отмены"}), 400

    grid_size = attempt["grid_size"]
    
    # Получаем целевое состояние
    target_state_json = read_clob(attempt["target_state"])
    _, tgt_flat = parse_board(target_state_json, grid_size)
    
    prev_idx = attempt["undo_pointer"] - 1

    prev_step = db.fetch_one(
        "SELECT STATE_AFTER FROM GAME_STEPS WHERE ATTEMPT_ID=:1 AND STEP_INDEX=:2",
        [attempt["id"], prev_idx]
    )
    if not prev_step:
        return jsonify({"error": "Нет предыдущего шага"}), 400

    # Читаем предыдущее состояние как JSON
    prev_state_json = read_clob(prev_step["state_after"])
    _, flat = parse_board(prev_state_json, grid_size)
    
    misplaced, manhattan, _ = compute_metrics(flat, tgt_flat, grid_size)

    db.execute_query(
        """UPDATE GAME_ATTEMPTS
           SET CURRENT_STATE=:1, CURRENT_MISPLACED_TILES=:2,
               CURRENT_MANHATTAN_DISTANCE=:3, UNDO_POINTER=:4
           WHERE ID=:5""",
        [prev_state_json, misplaced, manhattan, prev_idx, attempt["id"]]
    )

    board = [flat[r * grid_size:(r + 1) * grid_size] for r in range(grid_size)]
    pct = progress_pct(attempt["initial_manhattan_distance"], manhattan)

    return jsonify({
        "status": "ok", 
        "board": board, 
        "steps": prev_idx, 
        "progress": pct,
        "misplaced": misplaced,
        "manhattan": manhattan
    })


# ================================================================
# ИГРА -- REDO
# ================================================================

@app.route("/game/redo", methods=["POST"])
def redo_move():
    if not get_current_user_id():
        return jsonify({"error": "Не авторизован"}), 401

    gsid = get_active_session_id()
    if not gsid:
        return jsonify({"error": "Нет активной игровой сессии"}), 400
        
    attempt = get_active_attempt(gsid)
    if not attempt:
        return jsonify({"error": "Нет активной попытки"}), 400

    grid_size = attempt["grid_size"]
    
    # Получаем целевое состояние
    target_state_json = read_clob(attempt["target_state"])
    _, tgt_flat = parse_board(target_state_json, grid_size)
    
    next_idx = attempt["undo_pointer"] + 1

    next_step = db.fetch_one(
        """SELECT GS.STATE_AFTER FROM GAME_STEPS GS
           JOIN ACTION_TYPES AT ON GS.ACTION_ID = AT.ID
           WHERE GS.ATTEMPT_ID=:1 AND GS.STEP_INDEX=:2 AND AT.NAME='move'""",
        [attempt["id"], next_idx]
    )
    if not next_step:
        return jsonify({"error": "Нет отменённых ходов"}), 400

    # Читаем следующее состояние как JSON
    next_state_json = read_clob(next_step["state_after"])
    _, flat = parse_board(next_state_json, grid_size)
    
    misplaced, manhattan, _ = compute_metrics(flat, tgt_flat, grid_size)

    db.execute_query(
        """UPDATE GAME_ATTEMPTS
           SET CURRENT_STATE=:1, CURRENT_MISPLACED_TILES=:2,
               CURRENT_MANHATTAN_DISTANCE=:3, UNDO_POINTER=:4
           WHERE ID=:5""",
        [next_state_json, misplaced, manhattan, next_idx, attempt["id"]]
    )

    board = [flat[r * grid_size:(r + 1) * grid_size] for r in range(grid_size)]
    pct = progress_pct(attempt["initial_manhattan_distance"], manhattan)

    return jsonify({
        "status": "ok", 
        "board": board, 
        "steps": next_idx, 
        "progress": pct,
        "misplaced": misplaced,
        "manhattan": manhattan
    })


# ================================================================
# ИГРА -- ЗАВЕРШИТЬ
# ================================================================

@app.route("/game/over", methods=["POST"])
def game_over():
    if not get_current_user_id():
        return redirect(url_for("login"))

    gsid = get_active_session_id()
    if gsid:
        status_abandoned_row = db.fetch_one("SELECT ID FROM GAME_STATUSES WHERE NAME='abandoned'")
        if not status_abandoned_row:
            db.execute_query("INSERT INTO GAME_STATUSES (ID, NAME) VALUES (SEQ_GAME_STATUSES.NEXTVAL, 'abandoned')")
            status_abandoned_row = db.fetch_one("SELECT ID FROM GAME_STATUSES WHERE NAME='abandoned'")
        status_abandoned = status_abandoned_row["id"]
        
        db.execute_query(
            "UPDATE GAME_ATTEMPTS SET STATUS_ID=:1, FINISHED_AT=SYSTIMESTAMP WHERE SESSION_ID=:2",
            [status_abandoned, gsid]
        )
        db.execute_query(
            "UPDATE GAME_SESSIONS SET STATUS_ID=:1, END_TIME=SYSDATE WHERE ID=:2",
            [status_abandoned, gsid]
        )
        session.pop("game_session_id", None)

    return redirect(url_for("index"))


# ================================================================
# ТАБЛИЦА ЛИДЕРОВ
# ================================================================

@app.route("/leaderboard")
def leaderboard():
    if not get_current_user_id():
        return redirect(url_for("login"))

    players = db.fetch_all(
        """SELECT U.ID, U.USERNAME,
                  COUNT(DISTINCT GS.ID) AS TOTAL_GAMES,
                  SUM(CASE WHEN GST.NAME='solved' THEN 1 ELSE 0 END) AS SOLVED_GAMES,
                  ROUND(SUM(CASE WHEN GST.NAME='solved' THEN 1 ELSE 0 END) /
                        NULLIF(COUNT(DISTINCT GS.ID),0)*100, 1) AS SUCCESS_RATE,
                  ROUND(AVG(CASE WHEN GST.NAME='solved'
                            THEN (GS.END_TIME - GS.START_TIME)*24*60 END), 1) AS AVG_TIME_MINUTES,
                  MIN(CASE WHEN GST.NAME='solved' THEN GS.STEPS_COUNT END) AS BEST_STEPS
           FROM USERS U
           LEFT JOIN GAME_SESSIONS GS ON U.ID = GS.USER_ID
           LEFT JOIN GAME_STATUSES GST ON GS.STATUS_ID = GST.ID
           GROUP BY U.ID, U.USERNAME
           ORDER BY SOLVED_GAMES DESC NULLS LAST, AVG_TIME_MINUTES NULLS LAST"""
    )
    return render_template("leaderboard.html", players=players, username=session.get("username"))


# ================================================================
# ИСТОРИЯ
# ================================================================

@app.route("/history")
def history():
    if not get_current_user_id():
        return redirect(url_for("login"))

    user_id = get_current_user_id()
    games = db.fetch_all(
        """SELECT GS.ID AS SESSION_ID, GS.START_TIME, GS.END_TIME,
                  GST.NAME AS STATUS, GS.STEPS_COUNT,
                  PS.GRID_SIZE, DL.NAME AS DIFFICULTY,
                  ROUND((GS.END_TIME - GS.START_TIME)*24*60, 1) AS TIME_MINUTES
           FROM GAME_SESSIONS GS
           JOIN GAME_STATUSES GST ON GS.STATUS_ID = GST.ID
           JOIN PUZZLES PZ ON GS.PUZZLE_ID = PZ.ID
           JOIN PUZZLE_SIZES PS ON PZ.PUZZLE_SIZE_ID = PS.ID
           JOIN DIFFICULTY_LEVELS DL ON PZ.DIFFICULTY_ID = DL.ID
           WHERE GS.USER_ID = :1 AND GST.NAME != 'active'
           ORDER BY GS.START_TIME DESC""",
        [user_id]
    )
    return render_template("history.html", games=games, username=session.get("username"))


# ================================================================
# ЗАПУСК
# ================================================================

if __name__ == "__main__":
    app.run(debug=True, port=5000)