-- ================================================================
-- SLIDING PUZZLE -- Пятнашки
-- Лабораторная работа: Карпенко Д.С., Яфаров Р.И., КА-22-05
-- Шаг 5: Пакет SLIDING_PUZZLE
-- Публичные процедуры -- доступны игроку напрямую
-- ================================================================

-- ================================================================
-- СПЕЦИФИКАЦИЯ
-- ================================================================

CREATE OR REPLACE PACKAGE SLIDING_PUZZLE AS

    -- Главное меню
    PROCEDURE START_MENU;

    -- Выбор типа запуска игры
    -- P_TYPE: 1 = из каталога, 2 = по сложности, 3 = игра дня, 4 = импорт
    PROCEDURE START_NEW_GAME(P_TYPE IN NUMBER);

    -- Начать игру по seed из каталога
    PROCEDURE SELECT_FROM_CATALOG(P_SEED IN VARCHAR2);

    -- Начать случайную игру по уровню сложности
    PROCEDURE SELECT_BY_DIFFICULTY(P_DIFFICULTY_ID IN NUMBER);

    -- Загрузить ранее экспортированное состояние
    PROCEDURE IMPORT_GAME(P_EXPORT_DATA IN VARCHAR2);

    -- Сделать ход: передвинуть плитку с указанным значением
    PROCEDURE SET_TILE(P_TILE IN NUMBER);

    -- Отменить последний ход
    PROCEDURE UNDO;

    -- Вернуть отменённый ход
    PROCEDURE REDO;

    -- Показать метрики-подсказки по текущему состоянию
    PROCEDURE GET_HINT;

    -- Досрочно завершить текущую игру
    PROCEDURE GAME_OVER;

    -- История игр текущего пользователя
    -- P_GAME_ID: если указан -- реплей конкретной игры, иначе список всех
    PROCEDURE GET_GAME_HISTORY(P_GAME_ID IN NUMBER DEFAULT NULL);

    -- Экспортировать текущее состояние в строку CSV
    PROCEDURE EXPORT_GAME;

    -- Правила игры
    PROCEDURE GET_GAME_RULES;
    
    -- ============================================================
    -- НОВЫЕ ФУНКЦИИ ДЛЯ PYTHON UI
    -- ============================================================
    
    -- Получить текущее состояние доски в виде строки "1,2,3,4,5,0,6,7,8"
    FUNCTION GET_BOARD_STATE RETURN VARCHAR2;
    
    -- Получить подсказку в формате JSON
    FUNCTION GET_HINT_JSON RETURN VARCHAR2;
    
    -- Получить метрики текущей игры (ходы, misplaced, манхэттен, размер, время)
    FUNCTION GET_CURRENT_METRICS RETURN SYS_REFCURSOR;
    
    -- Получить список доступных пазлов для выбора
    FUNCTION GET_AVAILABLE_PUZZLES(
        P_DIFFICULTY_ID IN NUMBER DEFAULT NULL,
        P_SIZE_ID IN NUMBER DEFAULT NULL
    ) RETURN SYS_REFCURSOR;
    
    -- Получить топ игроков
    FUNCTION GET_TOP_PLAYERS(P_LIMIT IN NUMBER DEFAULT 10) RETURN SYS_REFCURSOR;
    
    -- Получить историю игр текущего игрока
    FUNCTION GET_PLAYER_HISTORY(P_LIMIT IN NUMBER DEFAULT 20) RETURN SYS_REFCURSOR;
    
    -- Перезапустить текущую игру
    PROCEDURE RESTART_GAME;
    
    -- Показать топ игроков в консоли
    PROCEDURE SHOW_TOP_PLAYERS;

END SLIDING_PUZZLE;
/


-- ================================================================
-- ТЕЛО ПАКЕТА
-- ================================================================

CREATE OR REPLACE PACKAGE BODY SLIDING_PUZZLE AS

    -- ============================================================
    -- START_MENU
    -- Выводит главное меню с доступными командами.
    -- ============================================================
    PROCEDURE START_MENU IS
    BEGIN
        DBMS_OUTPUT.PUT_LINE('=================================================');
        DBMS_OUTPUT.PUT_LINE('        ПЯТНАШКИ -- Sliding Puzzle               ');
        DBMS_OUTPUT.PUT_LINE('=================================================');
        DBMS_OUTPUT.PUT_LINE('Выберите действие и вызовите нужную процедуру:');
        DBMS_OUTPUT.PUT_LINE('');
        DBMS_OUTPUT.PUT_LINE('1. Начать игру из каталога:');
        DBMS_OUTPUT.PUT_LINE('   EXEC SLIDING_PUZZLE.START_NEW_GAME(1);');
        DBMS_OUTPUT.PUT_LINE('');
        DBMS_OUTPUT.PUT_LINE('2. Начать игру по сложности:');
        DBMS_OUTPUT.PUT_LINE('   EXEC SLIDING_PUZZLE.START_NEW_GAME(2);');
        DBMS_OUTPUT.PUT_LINE('');
        DBMS_OUTPUT.PUT_LINE('3. Игра дня:');
        DBMS_OUTPUT.PUT_LINE('   EXEC SLIDING_PUZZLE.START_NEW_GAME(3);');
        DBMS_OUTPUT.PUT_LINE('');
        DBMS_OUTPUT.PUT_LINE('4. Импортировать сохранённую игру:');
        DBMS_OUTPUT.PUT_LINE('   EXEC SLIDING_PUZZLE.START_NEW_GAME(4);');
        DBMS_OUTPUT.PUT_LINE('');
        DBMS_OUTPUT.PUT_LINE('5. История игр:');
        DBMS_OUTPUT.PUT_LINE('   EXEC SLIDING_PUZZLE.GET_GAME_HISTORY;');
        DBMS_OUTPUT.PUT_LINE('');
        DBMS_OUTPUT.PUT_LINE('6. Правила игры:');
        DBMS_OUTPUT.PUT_LINE('   EXEC SLIDING_PUZZLE.GET_GAME_RULES;');
        DBMS_OUTPUT.PUT_LINE('');
        DBMS_OUTPUT.PUT_LINE('7. Топ игроков:');
        DBMS_OUTPUT.PUT_LINE('   EXEC SLIDING_PUZZLE.SHOW_TOP_PLAYERS;');
        DBMS_OUTPUT.PUT_LINE('=================================================');
    END START_MENU;


    -- ============================================================
    -- START_NEW_GAME
    -- Выводит подсказку по выбранному типу запуска.
    -- Для типа 3 (игра дня) сразу запускает игру.
    -- ============================================================
    PROCEDURE START_NEW_GAME(P_TYPE IN NUMBER) IS
        V_PUZZLE_ID NUMBER;
        V_SESSION_ID NUMBER;
    BEGIN
        IF P_TYPE = 1 THEN
            DBMS_OUTPUT.PUT_LINE('=================================================');
            DBMS_OUTPUT.PUT_LINE('Каталог доступных головоломок:');
            DBMS_OUTPUT.PUT_LINE('=================================================');
            FOR R IN (
                SELECT PZ.ID, PZ.SEED, DL.NAME AS DIFFICULTY, PS.GRID_SIZE
                FROM PUZZLES PZ
                JOIN DIFFICULTY_LEVELS DL ON PZ.DIFFICULTY_ID = DL.ID
                JOIN PUZZLE_SIZES PS ON PZ.PUZZLE_SIZE_ID = PS.ID
                ORDER BY DL.ID, PS.GRID_SIZE
            ) LOOP
                DBMS_OUTPUT.PUT_LINE(
                    'ID=' || R.ID ||
                    '  Seed=' || R.SEED ||
                    '  Сложность=' || R.DIFFICULTY ||
                    '  Размер=' || R.GRID_SIZE || 'x' || R.GRID_SIZE
                );
            END LOOP;
            DBMS_OUTPUT.PUT_LINE('');
            DBMS_OUTPUT.PUT_LINE('Для запуска вызовите:');
            DBMS_OUTPUT.PUT_LINE('  EXEC SLIDING_PUZZLE.SELECT_FROM_CATALOG(''<seed>'');');

        ELSIF P_TYPE = 2 THEN
            DBMS_OUTPUT.PUT_LINE('=================================================');
            DBMS_OUTPUT.PUT_LINE('Доступные уровни сложности:');
            DBMS_OUTPUT.PUT_LINE('=================================================');
            FOR R IN (
                SELECT ID, NAME, SHUFFLE_MOVES FROM DIFFICULTY_LEVELS ORDER BY ID
            ) LOOP
                DBMS_OUTPUT.PUT_LINE(
                    'ID=' || R.ID ||
                    '  ' || R.NAME ||
                    '  (' || R.SHUFFLE_MOVES || ' ходов перемешивания)'
                );
            END LOOP;
            DBMS_OUTPUT.PUT_LINE('');
            DBMS_OUTPUT.PUT_LINE('Для запуска вызовите:');
            DBMS_OUTPUT.PUT_LINE('  EXEC SLIDING_PUZZLE.SELECT_BY_DIFFICULTY(<ID сложности>);');

        ELSIF P_TYPE = 3 THEN
            BEGIN
                SELECT ID INTO V_PUZZLE_ID FROM PUZZLES WHERE IS_DAILY = 1;
            EXCEPTION
                WHEN NO_DATA_FOUND THEN
                    DBMS_OUTPUT.PUT_LINE('ОШИБКА: пазл дня ещё не установлен.');
                    RETURN;
            END;
            DBMS_OUTPUT.PUT_LINE('Запускаем игру дня...');
            V_SESSION_ID := SLIDING_PUZZLE_UTILS.START_GAME(V_PUZZLE_ID);

        ELSIF P_TYPE = 4 THEN
            DBMS_OUTPUT.PUT_LINE('=================================================');
            DBMS_OUTPUT.PUT_LINE('Импорт сохранённой игры.');
            DBMS_OUTPUT.PUT_LINE('Передайте строку экспорта в процедуру:');
            DBMS_OUTPUT.PUT_LINE('  EXEC SLIDING_PUZZLE.IMPORT_GAME(''<строка>'');');
            DBMS_OUTPUT.PUT_LINE('=================================================');

        ELSE
            DBMS_OUTPUT.PUT_LINE('ОШИБКА: неверный тип. Допустимые значения: 1, 2, 3, 4.');
        END IF;
    END START_NEW_GAME;


    -- ============================================================
    -- SELECT_FROM_CATALOG
    -- Запускает игру по seed из каталога.
    -- ============================================================
    PROCEDURE SELECT_FROM_CATALOG(P_SEED IN VARCHAR2) IS
        V_PUZZLE_ID NUMBER;
        V_SESSION_ID NUMBER;
    BEGIN
        BEGIN
            SELECT ID INTO V_PUZZLE_ID FROM PUZZLES WHERE SEED = P_SEED AND ROWNUM = 1;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                DBMS_OUTPUT.PUT_LINE('ОШИБКА: пазл с seed="' || P_SEED || '" не найден.');
                RETURN;
        END;
        V_SESSION_ID := SLIDING_PUZZLE_UTILS.START_GAME(V_PUZZLE_ID);
    END SELECT_FROM_CATALOG;


    -- ============================================================
    -- SELECT_BY_DIFFICULTY
    -- Выбирает случайный пазл по уровню сложности и запускает игру.
    -- ============================================================
    PROCEDURE SELECT_BY_DIFFICULTY(P_DIFFICULTY_ID IN NUMBER) IS
        V_PUZZLE_ID NUMBER;
        V_SESSION_ID NUMBER;
        V_DIFF_NAME VARCHAR2(20);
    BEGIN
        BEGIN
            SELECT NAME INTO V_DIFF_NAME
            FROM DIFFICULTY_LEVELS WHERE ID = P_DIFFICULTY_ID;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                DBMS_OUTPUT.PUT_LINE('ОШИБКА: уровень сложности ID=' || P_DIFFICULTY_ID || ' не найден.');
                DBMS_OUTPUT.PUT_LINE('Допустимые значения: 1=Easy, 2=Medium, 3=Hard.');
                RETURN;
        END;

        BEGIN
            SELECT ID INTO V_PUZZLE_ID
            FROM (
                SELECT ID FROM PUZZLES
                WHERE DIFFICULTY_ID = P_DIFFICULTY_ID
                ORDER BY DBMS_RANDOM.VALUE
            )
            WHERE ROWNUM = 1;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                DBMS_OUTPUT.PUT_LINE('ОШИБКА: нет пазлов с уровнем ' || V_DIFF_NAME || '.');
                RETURN;
        END;

        DBMS_OUTPUT.PUT_LINE('Выбран случайный пазл уровня ' || V_DIFF_NAME || '...');
        V_SESSION_ID := SLIDING_PUZZLE_UTILS.START_GAME(V_PUZZLE_ID);
    END SELECT_BY_DIFFICULTY;


    -- ============================================================
    -- IMPORT_GAME
    -- Загружает ранее экспортированное состояние.
    -- Формат строки: "<puzzle_id>;<val1,val2,...>"
    -- Пример: "5;1,2,3,4,5,0,6,7,8"
    -- ============================================================
    PROCEDURE IMPORT_GAME(P_EXPORT_DATA IN VARCHAR2) IS
        V_PUZZLE_ID NUMBER;
        V_STATE VARCHAR2(4000);
        V_SESSION_ID NUMBER;
        V_ATTEMPT_ID NUMBER;
        V_DELIM NUMBER;
        V_ACTION_IMPORT NUMBER;
        V_GRID_SIZE NUMBER;
        V_TARGET VARCHAR2(4000);
        V_MISPLACED NUMBER;
        V_MANHATTAN NUMBER;
        V_CORRECT NUMBER;
    BEGIN
        V_DELIM := INSTR(P_EXPORT_DATA, ';');
        IF V_DELIM = 0 THEN
            DBMS_OUTPUT.PUT_LINE('ОШИБКА: неверный формат. Ожидается: "<puzzle_id>;<состояние>"');
            RETURN;
        END IF;

        V_PUZZLE_ID := TO_NUMBER(SUBSTR(P_EXPORT_DATA, 1, V_DELIM - 1));
        V_STATE := SUBSTR(P_EXPORT_DATA, V_DELIM + 1);

        V_SESSION_ID := SLIDING_PUZZLE_UTILS.START_GAME(V_PUZZLE_ID);
        IF V_SESSION_ID IS NULL THEN
            RETURN;
        END IF;

        SELECT GA.ID, PS.GRID_SIZE, PZ.TARGET_STATE
        INTO V_ATTEMPT_ID, V_GRID_SIZE, V_TARGET
        FROM GAME_ATTEMPTS GA
        JOIN PUZZLES PZ ON GA.PUZZLE_ID = PZ.ID
        JOIN PUZZLE_SIZES PS ON PZ.PUZZLE_SIZE_ID = PS.ID
        WHERE GA.SESSION_ID = V_SESSION_ID AND ROWNUM = 1;

        SLIDING_PUZZLE_UTILS.CALCULATE_METRICS(
            V_STATE, V_TARGET, V_GRID_SIZE,
            V_MISPLACED, V_MANHATTAN, V_CORRECT
        );

        UPDATE GAME_ATTEMPTS
        SET CURRENT_STATE = V_STATE,
            CURRENT_MISPLACED_TILES = V_MISPLACED,
            CURRENT_MANHATTAN_DISTANCE = V_MANHATTAN
        WHERE ID = V_ATTEMPT_ID;

        SELECT ID INTO V_ACTION_IMPORT FROM ACTION_TYPES WHERE NAME = 'import';

        INSERT INTO GAME_STEPS (
            ID, SESSION_ID, ATTEMPT_ID, ACTION_ID,
            STATE_AFTER, IS_ACTUAL, IS_IMPORT, IS_MARK,
            STEP_INDEX, STEP_TIME
        ) VALUES (
            SEQ_GAME_STEPS.NEXTVAL, V_SESSION_ID, V_ATTEMPT_ID, V_ACTION_IMPORT,
            V_STATE, 1, 1, 0, 1, SYSDATE
        );

        UPDATE GAME_ATTEMPTS SET UNDO_POINTER = 1 WHERE ID = V_ATTEMPT_ID;

        SLIDING_PUZZLE_UTILS.SAVE_LOG(V_SESSION_ID, 'INFO', 'IMPORT_GAME',
            'Состояние импортировано. Пазл ID=' || V_PUZZLE_ID);
        COMMIT;

        DBMS_OUTPUT.PUT_LINE('Состояние успешно импортировано.');
        SLIDING_PUZZLE_UTILS.DRAW_BOARD(V_ATTEMPT_ID);
    EXCEPTION
        WHEN OTHERS THEN
            ROLLBACK;
            DBMS_OUTPUT.PUT_LINE('ОШИБКА при импорте: ' || SQLERRM);
            SLIDING_PUZZLE_UTILS.SAVE_LOG(NULL, 'ERROR', 'IMPORT_GAME', SQLERRM);
    END IMPORT_GAME;


    -- ============================================================
    -- SET_TILE
    -- Выполняет ход: сдвигает плитку P_TILE к пустой клетке.
    -- Проверяет легальность хода и после хода проверяет победу.
    -- ============================================================
    PROCEDURE SET_TILE(P_TILE IN NUMBER) IS
        V_SESSION_ID NUMBER;
        V_ATTEMPT_ID NUMBER;
        V_STATE VARCHAR2(4000);
        V_TARGET VARCHAR2(4000);
        V_GRID_SIZE NUMBER;
        V_TOTAL NUMBER;
        V_EMPTY_POS NUMBER;
        V_TILE_POS NUMBER;
        V_IDX NUMBER;
        V_STR VARCHAR2(4000);
        V_POS NUMBER;
        V_VAL NUMBER;
        V_NEW_STATE VARCHAR2(4000);
        TYPE T_ARR IS TABLE OF NUMBER INDEX BY PLS_INTEGER;
        V_BOARD T_ARR;
        V_DIFF NUMBER;
        V_MISPLACED NUMBER;
        V_MANHATTAN NUMBER;
        V_CORRECT NUMBER;
        V_NEXT_IDX NUMBER;
        V_ACTION_MOVE NUMBER;
        V_WIN NUMBER;
        V_STEP_INDEX NUMBER;
        V_TIME_LIMIT INTERVAL DAY TO SECOND;
        V_ELAPSED INTERVAL DAY TO SECOND;
    BEGIN
        SLIDING_PUZZLE_UTILS.CHECK_USER_ACTIVE_GAME;

        V_SESSION_ID := SLIDING_PUZZLE_UTILS.GET_ACTIVE_SESSION_ID;
        IF V_SESSION_ID IS NULL THEN
            DBMS_OUTPUT.PUT_LINE('Нет активной игры. Начните новую: EXEC SLIDING_PUZZLE.START_MENU;');
            RETURN;
        END IF;

        V_ATTEMPT_ID := SLIDING_PUZZLE_UTILS.GET_ACTIVE_ATTEMPT_ID(V_SESSION_ID);

        SELECT GA.CURRENT_STATE, PZ.TARGET_STATE, PS.GRID_SIZE,
               GA.UNDO_POINTER, GA.TIME_LIMIT,
               (SYSTIMESTAMP - GA.STARTED_AT) DAY TO SECOND
        INTO V_STATE, V_TARGET, V_GRID_SIZE,
             V_STEP_INDEX, V_TIME_LIMIT, V_ELAPSED
        FROM GAME_ATTEMPTS GA
        JOIN PUZZLES PZ ON GA.PUZZLE_ID = PZ.ID
        JOIN PUZZLE_SIZES PS ON PZ.PUZZLE_SIZE_ID = PS.ID
        WHERE GA.ID = V_ATTEMPT_ID;

        IF V_TIME_LIMIT IS NOT NULL AND V_ELAPSED > V_TIME_LIMIT THEN
            DBMS_OUTPUT.PUT_LINE('Время вышло! Игра завершена.');
            SLIDING_PUZZLE_UTILS.END_GAME(V_SESSION_ID, 'timeout');
            RETURN;
        END IF;

        V_TOTAL := V_GRID_SIZE * V_GRID_SIZE;

        -- Разобрать состояние в массив
        V_STR := V_STATE || ',';
        V_IDX := 1;
        LOOP
            V_POS := INSTR(V_STR, ',');
            EXIT WHEN V_POS = 0;
            V_VAL := TO_NUMBER(SUBSTR(V_STR, 1, V_POS - 1));
            V_BOARD(V_IDX) := V_VAL;
            IF V_VAL = 0 THEN 
                V_EMPTY_POS := V_IDX; 
            END IF;
            IF V_VAL = P_TILE THEN 
                V_TILE_POS := V_IDX; 
            END IF;
            V_STR := SUBSTR(V_STR, V_POS + 1);
            V_IDX := V_IDX + 1;
        END LOOP;

        IF V_TILE_POS IS NULL THEN
            DBMS_OUTPUT.PUT_LINE('ОШИБКА: плитка ' || P_TILE || ' не найдена на поле.');
            RETURN;
        END IF;

        -- Проверить что плитка соседняя с пустой клеткой
        V_DIFF := V_TILE_POS - V_EMPTY_POS;
        IF V_DIFF != 1 AND V_DIFF != -1
            AND V_DIFF != V_GRID_SIZE AND V_DIFF != -V_GRID_SIZE THEN
            DBMS_OUTPUT.PUT_LINE('Недопустимый ход: плитка ' || P_TILE || ' не соседняя с пустой клеткой.');
            RETURN;
        END IF;

        -- Доп. проверка: горизонтальный ход не через край строки
        IF V_DIFF = 1 OR V_DIFF = -1 THEN
            IF CEIL(V_TILE_POS / V_GRID_SIZE) != CEIL(V_EMPTY_POS / V_GRID_SIZE) THEN
                DBMS_OUTPUT.PUT_LINE('Недопустимый ход: плитка ' || P_TILE || ' на другой строке.');
                RETURN;
            END IF;
        END IF;

        -- Выполнить ход
        V_BOARD(V_EMPTY_POS) := P_TILE;
        V_BOARD(V_TILE_POS) := 0;

        -- Собрать новое состояние
        V_NEW_STATE := '';
        FOR I IN 1..V_TOTAL LOOP
            IF I = 1 THEN
                V_NEW_STATE := TO_CHAR(V_BOARD(I));
            ELSE
                V_NEW_STATE := V_NEW_STATE || ',' || TO_CHAR(V_BOARD(I));
            END IF;
        END LOOP;

        SLIDING_PUZZLE_UTILS.CALCULATE_METRICS(
            V_NEW_STATE, V_TARGET, V_GRID_SIZE,
            V_MISPLACED, V_MANHATTAN, V_CORRECT
        );

        V_NEXT_IDX := V_STEP_INDEX + 1;

        -- Инвалидировать redo-ветку
        UPDATE GAME_STEPS SET IS_ACTUAL = 0
        WHERE ATTEMPT_ID = V_ATTEMPT_ID AND STEP_INDEX > V_STEP_INDEX;

        SELECT ID INTO V_ACTION_MOVE FROM ACTION_TYPES WHERE NAME = 'move';

        INSERT INTO GAME_STEPS (
            ID, SESSION_ID, ATTEMPT_ID, ACTION_ID,
            TILE_VALUE, STATE_AFTER, IS_ACTUAL, IS_IMPORT, IS_MARK,
            STEP_INDEX, STEP_TIME
        ) VALUES (
            SEQ_GAME_STEPS.NEXTVAL, V_SESSION_ID, V_ATTEMPT_ID, V_ACTION_MOVE,
            P_TILE, V_NEW_STATE, 1, 0, 0,
            V_NEXT_IDX, SYSDATE
        );

        UPDATE GAME_ATTEMPTS
        SET CURRENT_STATE = V_NEW_STATE,
            CURRENT_MISPLACED_TILES = V_MISPLACED,
            CURRENT_MANHATTAN_DISTANCE = V_MANHATTAN,
            UNDO_POINTER = V_NEXT_IDX
        WHERE ID = V_ATTEMPT_ID;

        UPDATE GAME_SESSIONS
        SET STEPS_COUNT = STEPS_COUNT + 1,
            LAST_ACTIVITY_AT = SYSTIMESTAMP
        WHERE ID = V_SESSION_ID;

        COMMIT;

        SLIDING_PUZZLE_UTILS.DRAW_BOARD(V_ATTEMPT_ID);

        V_WIN := SLIDING_PUZZLE_UTILS.CHECK_WIN(V_ATTEMPT_ID);
        IF V_WIN = 1 THEN
            DBMS_OUTPUT.PUT_LINE('');
            DBMS_OUTPUT.PUT_LINE('=================================================');
            DBMS_OUTPUT.PUT_LINE('  ПОЗДРАВЛЯЕМ! Головоломка решена!');
            DBMS_OUTPUT.PUT_LINE('=================================================');
            SLIDING_PUZZLE_UTILS.END_GAME(V_SESSION_ID, 'solved');
        END IF;

    EXCEPTION
        WHEN OTHERS THEN
            ROLLBACK;
            DBMS_OUTPUT.PUT_LINE('ОШИБКА при выполнении хода: ' || SQLERRM);
            SLIDING_PUZZLE_UTILS.SAVE_LOG(V_SESSION_ID, 'ERROR', 'SET_TILE', SQLERRM);
    END SET_TILE;


    -- ============================================================
    -- UNDO
    -- Отменяет последний ход, двигая UNDO_POINTER на шаг назад.
    -- ============================================================
    PROCEDURE UNDO IS
        V_SESSION_ID NUMBER;
        V_ATTEMPT_ID NUMBER;
        V_POINTER NUMBER;
        V_PREV_STATE VARCHAR2(4000);
        V_TARGET VARCHAR2(4000);
        V_GRID_SIZE NUMBER;
        V_MISPLACED NUMBER;
        V_MANHATTAN NUMBER;
        V_CORRECT NUMBER;
        V_ACTION_UNDO NUMBER;
    BEGIN
        V_SESSION_ID := SLIDING_PUZZLE_UTILS.GET_ACTIVE_SESSION_ID;
        IF V_SESSION_ID IS NULL THEN
            DBMS_OUTPUT.PUT_LINE('Нет активной игры.');
            RETURN;
        END IF;

        V_ATTEMPT_ID := SLIDING_PUZZLE_UTILS.GET_ACTIVE_ATTEMPT_ID(V_SESSION_ID);

        SELECT GA.UNDO_POINTER, PZ.TARGET_STATE, PS.GRID_SIZE
        INTO V_POINTER, V_TARGET, V_GRID_SIZE
        FROM GAME_ATTEMPTS GA
        JOIN PUZZLES PZ ON GA.PUZZLE_ID = PZ.ID
        JOIN PUZZLE_SIZES PS ON PZ.PUZZLE_SIZE_ID = PS.ID
        WHERE GA.ID = V_ATTEMPT_ID;

        IF V_POINTER <= 0 THEN
            DBMS_OUTPUT.PUT_LINE('Нет ходов для отмены.');
            RETURN;
        END IF;

        SELECT STATE_AFTER INTO V_PREV_STATE
        FROM GAME_STEPS
        WHERE ATTEMPT_ID = V_ATTEMPT_ID AND STEP_INDEX = V_POINTER - 1;

        SLIDING_PUZZLE_UTILS.CALCULATE_METRICS(
            V_PREV_STATE, V_TARGET, V_GRID_SIZE,
            V_MISPLACED, V_MANHATTAN, V_CORRECT
        );

        SELECT ID INTO V_ACTION_UNDO FROM ACTION_TYPES WHERE NAME = 'undo';

        INSERT INTO GAME_STEPS (
            ID, SESSION_ID, ATTEMPT_ID, ACTION_ID,
            STATE_AFTER, IS_ACTUAL, IS_IMPORT, IS_MARK,
            STEP_INDEX, STEP_TIME
        ) VALUES (
            SEQ_GAME_STEPS.NEXTVAL, V_SESSION_ID, V_ATTEMPT_ID, V_ACTION_UNDO,
            V_PREV_STATE, 1, 0, 0, V_POINTER - 1, SYSDATE
        );

        UPDATE GAME_ATTEMPTS
        SET CURRENT_STATE = V_PREV_STATE,
            CURRENT_MISPLACED_TILES = V_MISPLACED,
            CURRENT_MANHATTAN_DISTANCE = V_MANHATTAN,
            UNDO_POINTER = V_POINTER - 1
        WHERE ID = V_ATTEMPT_ID;

        UPDATE GAME_SESSIONS SET LAST_ACTIVITY_AT = SYSTIMESTAMP WHERE ID = V_SESSION_ID;

        COMMIT;

        DBMS_OUTPUT.PUT_LINE('Ход отменён.');
        SLIDING_PUZZLE_UTILS.DRAW_BOARD(V_ATTEMPT_ID);

    EXCEPTION
        WHEN OTHERS THEN
            ROLLBACK;
            DBMS_OUTPUT.PUT_LINE('ОШИБКА при отмене хода: ' || SQLERRM);
            SLIDING_PUZZLE_UTILS.SAVE_LOG(V_SESSION_ID, 'ERROR', 'UNDO', SQLERRM);
    END UNDO;


    -- ============================================================
    -- REDO
    -- Возвращает последний отменённый ход.
    -- ============================================================
    PROCEDURE REDO IS
        V_SESSION_ID NUMBER;
        V_ATTEMPT_ID NUMBER;
        V_POINTER NUMBER;
        V_NEXT_STATE VARCHAR2(4000);
        V_TARGET VARCHAR2(4000);
        V_GRID_SIZE NUMBER;
        V_MISPLACED NUMBER;
        V_MANHATTAN NUMBER;
        V_CORRECT NUMBER;
        V_ACTION_REDO NUMBER;
        V_MAX_IDX NUMBER;
    BEGIN
        V_SESSION_ID := SLIDING_PUZZLE_UTILS.GET_ACTIVE_SESSION_ID;
        IF V_SESSION_ID IS NULL THEN
            DBMS_OUTPUT.PUT_LINE('Нет активной игры.');
            RETURN;
        END IF;

        V_ATTEMPT_ID := SLIDING_PUZZLE_UTILS.GET_ACTIVE_ATTEMPT_ID(V_SESSION_ID);

        SELECT GA.UNDO_POINTER, PZ.TARGET_STATE, PS.GRID_SIZE
        INTO V_POINTER, V_TARGET, V_GRID_SIZE
        FROM GAME_ATTEMPTS GA
        JOIN PUZZLES PZ ON GA.PUZZLE_ID = PZ.ID
        JOIN PUZZLE_SIZES PS ON PZ.PUZZLE_SIZE_ID = PS.ID
        WHERE GA.ID = V_ATTEMPT_ID;

        SELECT NVL(MAX(STEP_INDEX), -1) INTO V_MAX_IDX
        FROM GAME_STEPS GS
        JOIN ACTION_TYPES AT ON GS.ACTION_ID = AT.ID
        WHERE GS.ATTEMPT_ID = V_ATTEMPT_ID
        AND AT.NAME = 'move'
        AND GS.IS_IMPORT = 0;

        IF V_POINTER >= V_MAX_IDX THEN
            DBMS_OUTPUT.PUT_LINE('Нет отменённых ходов для возврата.');
            RETURN;
        END IF;

        SELECT STATE_AFTER INTO V_NEXT_STATE
        FROM GAME_STEPS GS
        JOIN ACTION_TYPES AT ON GS.ACTION_ID = AT.ID
        WHERE GS.ATTEMPT_ID = V_ATTEMPT_ID
        AND GS.STEP_INDEX = V_POINTER + 1
        AND AT.NAME = 'move';

        SLIDING_PUZZLE_UTILS.CALCULATE_METRICS(
            V_NEXT_STATE, V_TARGET, V_GRID_SIZE,
            V_MISPLACED, V_MANHATTAN, V_CORRECT
        );

        SELECT ID INTO V_ACTION_REDO FROM ACTION_TYPES WHERE NAME = 'redo';

        INSERT INTO GAME_STEPS (
            ID, SESSION_ID, ATTEMPT_ID, ACTION_ID,
            STATE_AFTER, IS_ACTUAL, IS_IMPORT, IS_MARK,
            STEP_INDEX, STEP_TIME
        ) VALUES (
            SEQ_GAME_STEPS.NEXTVAL, V_SESSION_ID, V_ATTEMPT_ID, V_ACTION_REDO,
            V_NEXT_STATE, 1, 0, 0, V_POINTER + 1, SYSDATE
        );

        UPDATE GAME_ATTEMPTS
        SET CURRENT_STATE = V_NEXT_STATE,
            CURRENT_MISPLACED_TILES = V_MISPLACED,
            CURRENT_MANHATTAN_DISTANCE = V_MANHATTAN,
            UNDO_POINTER = V_POINTER + 1
        WHERE ID = V_ATTEMPT_ID;

        UPDATE GAME_SESSIONS SET LAST_ACTIVITY_AT = SYSTIMESTAMP WHERE ID = V_SESSION_ID;

        COMMIT;

        DBMS_OUTPUT.PUT_LINE('Ход возвращён.');
        SLIDING_PUZZLE_UTILS.DRAW_BOARD(V_ATTEMPT_ID);

    EXCEPTION
        WHEN OTHERS THEN
            ROLLBACK;
            DBMS_OUTPUT.PUT_LINE('ОШИБКА при возврате хода: ' || SQLERRM);
            SLIDING_PUZZLE_UTILS.SAVE_LOG(V_SESSION_ID, 'ERROR', 'REDO', SQLERRM);
    END REDO;


    -- ============================================================
    -- GET_HINT
    -- Выводит метрики-подсказки без изменения состояния.
    -- ============================================================
    PROCEDURE GET_HINT IS
        V_SESSION_ID NUMBER;
        V_ATTEMPT_ID NUMBER;
        V_STATE VARCHAR2(4000);
        V_TARGET VARCHAR2(4000);
        V_GRID_SIZE NUMBER;
        V_INIT_MANHATTAN NUMBER;
        V_MISPLACED NUMBER;
        V_MANHATTAN NUMBER;
        V_CORRECT NUMBER;
        V_PROGRESS NUMBER;
        V_MOVES NUMBER;
    BEGIN
        V_SESSION_ID := SLIDING_PUZZLE_UTILS.GET_ACTIVE_SESSION_ID;
        IF V_SESSION_ID IS NULL THEN
            DBMS_OUTPUT.PUT_LINE('Нет активной игры.');
            RETURN;
        END IF;

        V_ATTEMPT_ID := SLIDING_PUZZLE_UTILS.GET_ACTIVE_ATTEMPT_ID(V_SESSION_ID);

        SELECT GA.CURRENT_STATE, PZ.TARGET_STATE, PS.GRID_SIZE,
               GA.INITIAL_MANHATTAN_DISTANCE, GA.UNDO_POINTER
        INTO V_STATE, V_TARGET, V_GRID_SIZE, V_INIT_MANHATTAN, V_MOVES
        FROM GAME_ATTEMPTS GA
        JOIN PUZZLES PZ ON GA.PUZZLE_ID = PZ.ID
        JOIN PUZZLE_SIZES PS ON PZ.PUZZLE_SIZE_ID = PS.ID
        WHERE GA.ID = V_ATTEMPT_ID;

        SLIDING_PUZZLE_UTILS.CALCULATE_METRICS(
            V_STATE, V_TARGET, V_GRID_SIZE,
            V_MISPLACED, V_MANHATTAN, V_CORRECT
        );

        IF V_INIT_MANHATTAN > 0 THEN
            V_PROGRESS := ROUND((V_INIT_MANHATTAN - V_MANHATTAN) / V_INIT_MANHATTAN * 100);
        ELSE
            V_PROGRESS := 100;
        END IF;

        DBMS_OUTPUT.PUT_LINE('=================================================');
        DBMS_OUTPUT.PUT_LINE('Подсказка:');
        DBMS_OUTPUT.PUT_LINE('  Ходов сделано     : ' || V_MOVES);
        DBMS_OUTPUT.PUT_LINE('  Плиток не на месте: ' || V_MISPLACED);
        DBMS_OUTPUT.PUT_LINE('  Манхэттен до цели : ' || V_MANHATTAN);
        DBMS_OUTPUT.PUT_LINE('  Плиток на месте   : ' || V_CORRECT);
        DBMS_OUTPUT.PUT_LINE('  Прогресс          : ' || V_PROGRESS || '%');
        DBMS_OUTPUT.PUT_LINE('=================================================');

    EXCEPTION
        WHEN OTHERS THEN
            DBMS_OUTPUT.PUT_LINE('ОШИБКА при получении подсказки: ' || SQLERRM);
    END GET_HINT;


    -- ============================================================
    -- GAME_OVER
    -- Досрочно завершает текущую игру со статусом 'abandoned'.
    -- ============================================================
    PROCEDURE GAME_OVER IS
        V_SESSION_ID NUMBER;
        V_ELAPSED INTERVAL DAY TO SECOND;
    BEGIN
        V_SESSION_ID := SLIDING_PUZZLE_UTILS.GET_ACTIVE_SESSION_ID;
        IF V_SESSION_ID IS NULL THEN
            DBMS_OUTPUT.PUT_LINE('Нет активной игры.');
            RETURN;
        END IF;

        SELECT (SYSTIMESTAMP - START_TIME) DAY TO SECOND
        INTO V_ELAPSED
        FROM GAME_SESSIONS WHERE ID = V_SESSION_ID;

        SLIDING_PUZZLE_UTILS.END_GAME(V_SESSION_ID, 'abandoned');

        DBMS_OUTPUT.PUT_LINE('Игра завершена досрочно.');
        DBMS_OUTPUT.PUT_LINE(
            'Время игры: ' ||
            EXTRACT(HOUR FROM V_ELAPSED) || 'ч ' ||
            EXTRACT(MINUTE FROM V_ELAPSED) || 'м ' ||
            TRUNC(EXTRACT(SECOND FROM V_ELAPSED)) || 'с'
        );
    END GAME_OVER;


    -- ============================================================
    -- GET_GAME_HISTORY
    -- Без параметра: список всех завершённых игр пользователя.
    -- С P_GAME_ID: пошаговый реплей конкретной игры.
    -- ============================================================
    PROCEDURE GET_GAME_HISTORY(P_GAME_ID IN NUMBER DEFAULT NULL) IS
        V_USER_ID NUMBER;
    BEGIN
        V_USER_ID := SLIDING_PUZZLE_UTILS.GET_ACTIVE_USER;
        IF V_USER_ID IS NULL THEN
            DBMS_OUTPUT.PUT_LINE('Пользователь не найден.');
            RETURN;
        END IF;

        IF P_GAME_ID IS NULL THEN
            DBMS_OUTPUT.PUT_LINE('=================================================');
            DBMS_OUTPUT.PUT_LINE('История игр:');
            DBMS_OUTPUT.PUT_LINE('=================================================');
            FOR R IN (
                SELECT GS.ID, GS.START_TIME, GS.END_TIME,
                       GST.NAME AS STATUS, GS.STEPS_COUNT,
                       PS.GRID_SIZE, DL.NAME AS DIFFICULTY
                FROM GAME_SESSIONS GS
                JOIN GAME_STATUSES GST ON GS.STATUS_ID = GST.ID
                JOIN PUZZLES PZ ON GS.PUZZLE_ID = PZ.ID
                JOIN PUZZLE_SIZES PS ON PZ.PUZZLE_SIZE_ID = PS.ID
                JOIN DIFFICULTY_LEVELS DL ON PZ.DIFFICULTY_ID = DL.ID
                WHERE GS.USER_ID = V_USER_ID
                AND GST.NAME != 'active'
                ORDER BY GS.START_TIME DESC
            ) LOOP
                DBMS_OUTPUT.PUT_LINE(
                    'ID=' || R.ID ||
                    '  ' || TO_CHAR(R.START_TIME, 'DD.MM.YYYY HH24:MI') ||
                    '  Статус=' || R.STATUS ||
                    '  Ходов=' || R.STEPS_COUNT ||
                    '  ' || R.GRID_SIZE || 'x' || R.GRID_SIZE ||
                    '  ' || R.DIFFICULTY
                );
            END LOOP;
            DBMS_OUTPUT.PUT_LINE('');
            DBMS_OUTPUT.PUT_LINE('Для реплея: EXEC SLIDING_PUZZLE.GET_GAME_HISTORY(<ID>);');
        ELSE
            DBMS_OUTPUT.PUT_LINE('=================================================');
            DBMS_OUTPUT.PUT_LINE('Реплей игры ID=' || P_GAME_ID || ':');
            DBMS_OUTPUT.PUT_LINE('=================================================');
            FOR R IN (
                SELECT GS.STEP_INDEX, AT.NAME AS ACTION,
                       GS.TILE_VALUE, GS.STEP_TIME, GS.IS_ACTUAL
                FROM GAME_STEPS GS
                JOIN ACTION_TYPES AT ON GS.ACTION_ID = AT.ID
                WHERE GS.SESSION_ID = P_GAME_ID
                AND GS.IS_IMPORT = 0
                ORDER BY GS.STEP_INDEX
            ) LOOP
                DBMS_OUTPUT.PUT_LINE(
                    'Шаг ' || R.STEP_INDEX ||
                    '  [' || R.ACTION || ']' ||
                    CASE WHEN R.TILE_VALUE IS NOT NULL
                         THEN '  Плитка=' || R.TILE_VALUE ELSE '' END ||
                    '  ' || TO_CHAR(R.STEP_TIME, 'HH24:MI:SS') ||
                    CASE WHEN R.IS_ACTUAL = 0 THEN ' (отменён)' ELSE '' END
                );
            END LOOP;
        END IF;
    END GET_GAME_HISTORY;


    -- ============================================================
    -- EXPORT_GAME
    -- Генерирует строку для сохранения текущего состояния.
    -- Формат: "<puzzle_id>;<состояние>"
    -- После экспорта игра завершается со статусом 'exported'.
    -- ============================================================
    PROCEDURE EXPORT_GAME IS
        V_SESSION_ID NUMBER;
        V_ATTEMPT_ID NUMBER;
        V_PUZZLE_ID NUMBER;
        V_STATE VARCHAR2(4000);
        V_EXPORT VARCHAR2(4000);
    BEGIN
        V_SESSION_ID := SLIDING_PUZZLE_UTILS.GET_ACTIVE_SESSION_ID;
        IF V_SESSION_ID IS NULL THEN
            DBMS_OUTPUT.PUT_LINE('Нет активной игры.');
            RETURN;
        END IF;

        V_ATTEMPT_ID := SLIDING_PUZZLE_UTILS.GET_ACTIVE_ATTEMPT_ID(V_SESSION_ID);

        SELECT PUZZLE_ID, CURRENT_STATE
        INTO V_PUZZLE_ID, V_STATE
        FROM GAME_ATTEMPTS WHERE ID = V_ATTEMPT_ID;

        V_EXPORT := V_PUZZLE_ID || ';' || V_STATE;

        SLIDING_PUZZLE_UTILS.END_GAME(V_SESSION_ID, 'exported');

        DBMS_OUTPUT.PUT_LINE('=================================================');
        DBMS_OUTPUT.PUT_LINE('Строка для импорта (скопируйте):');
        DBMS_OUTPUT.PUT_LINE(V_EXPORT);
        DBMS_OUTPUT.PUT_LINE('=================================================');
        DBMS_OUTPUT.PUT_LINE('Для продолжения вызовите:');
        DBMS_OUTPUT.PUT_LINE('  EXEC SLIDING_PUZZLE.IMPORT_GAME(''' || V_EXPORT || ''');');
    END EXPORT_GAME;


    -- ============================================================
    -- GET_GAME_RULES
    -- Выводит правила игры.
    -- Если есть активная игра -- показывает текущее поле.
    -- ============================================================
    PROCEDURE GET_GAME_RULES IS
        V_SESSION_ID NUMBER;
        V_ATTEMPT_ID NUMBER;
    BEGIN
        DBMS_OUTPUT.PUT_LINE('=================================================');
        DBMS_OUTPUT.PUT_LINE('ПРАВИЛА ИГРЫ "ПЯТНАШКИ"');
        DBMS_OUTPUT.PUT_LINE('=================================================');
        DBMS_OUTPUT.PUT_LINE('Цель: расставить плитки по порядку слева направо,');
        DBMS_OUTPUT.PUT_LINE('сверху вниз. Пустая клетка -- в правом нижнем углу.');
        DBMS_OUTPUT.PUT_LINE('');
        DBMS_OUTPUT.PUT_LINE('Ход: сдвинуть плитку, соседнюю с пустой клеткой.');
        DBMS_OUTPUT.PUT_LINE('');
        DBMS_OUTPUT.PUT_LINE('КОМАНДЫ:');
        DBMS_OUTPUT.PUT_LINE('  Сделать ход    : EXEC SLIDING_PUZZLE.SET_TILE(<номер плитки>);');
        DBMS_OUTPUT.PUT_LINE('  Отменить ход   : EXEC SLIDING_PUZZLE.UNDO;');
        DBMS_OUTPUT.PUT_LINE('  Вернуть ход    : EXEC SLIDING_PUZZLE.REDO;');
        DBMS_OUTPUT.PUT_LINE('  Подсказка      : EXEC SLIDING_PUZZLE.GET_HINT;');
        DBMS_OUTPUT.PUT_LINE('  Экспорт        : EXEC SLIDING_PUZZLE.EXPORT_GAME;');
        DBMS_OUTPUT.PUT_LINE('  Завершить игру : EXEC SLIDING_PUZZLE.GAME_OVER;');
        DBMS_OUTPUT.PUT_LINE('  История игр    : EXEC SLIDING_PUZZLE.GET_GAME_HISTORY;');
        DBMS_OUTPUT.PUT_LINE('  Перезапуск     : EXEC SLIDING_PUZZLE.RESTART_GAME;');
        DBMS_OUTPUT.PUT_LINE('  Топ игроков    : EXEC SLIDING_PUZZLE.SHOW_TOP_PLAYERS;');
        DBMS_OUTPUT.PUT_LINE('');
        DBMS_OUTPUT.PUT_LINE('УРОВНИ СЛОЖНОСТИ:');
        DBMS_OUTPUT.PUT_LINE('  Easy   -- 50 ходов перемешивания');
        DBMS_OUTPUT.PUT_LINE('  Medium -- 200 ходов перемешивания');
        DBMS_OUTPUT.PUT_LINE('  Hard   -- 1000 ходов перемешивания');
        DBMS_OUTPUT.PUT_LINE('=================================================');

        V_SESSION_ID := SLIDING_PUZZLE_UTILS.GET_ACTIVE_SESSION_ID;
        IF V_SESSION_ID IS NOT NULL THEN
            V_ATTEMPT_ID := SLIDING_PUZZLE_UTILS.GET_ACTIVE_ATTEMPT_ID(V_SESSION_ID);
            DBMS_OUTPUT.PUT_LINE('');
            DBMS_OUTPUT.PUT_LINE('Ваше текущее поле:');
            SLIDING_PUZZLE_UTILS.DRAW_BOARD(V_ATTEMPT_ID);
        END IF;
    END GET_GAME_RULES;
    
    
    -- ============================================================
    -- НОВЫЕ ФУНКЦИИ ДЛЯ PYTHON UI
    -- ============================================================
    
    FUNCTION GET_BOARD_STATE RETURN VARCHAR2 IS
        V_STATE VARCHAR2(4000);
        V_SESSION_ID NUMBER;
        V_ATTEMPT_ID NUMBER;
    BEGIN
        V_SESSION_ID := SLIDING_PUZZLE_UTILS.GET_ACTIVE_SESSION_ID;
        IF V_SESSION_ID IS NULL THEN
            RETURN NULL;
        END IF;
        
        V_ATTEMPT_ID := SLIDING_PUZZLE_UTILS.GET_ACTIVE_ATTEMPT_ID(V_SESSION_ID);
        IF V_ATTEMPT_ID IS NULL THEN
            RETURN NULL;
        END IF;
        
        SELECT CURRENT_STATE INTO V_STATE
        FROM GAME_ATTEMPTS
        WHERE ID = V_ATTEMPT_ID;
        
        RETURN V_STATE;
    EXCEPTION
        WHEN OTHERS THEN
            RETURN NULL;
    END GET_BOARD_STATE;
    
    
    FUNCTION GET_CURRENT_METRICS RETURN SYS_REFCURSOR IS
        V_CURSOR SYS_REFCURSOR;
        V_SESSION_ID NUMBER;
        V_ATTEMPT_ID NUMBER;
    BEGIN
        V_SESSION_ID := SLIDING_PUZZLE_UTILS.GET_ACTIVE_SESSION_ID;
        IF V_SESSION_ID IS NULL THEN
            RETURN NULL;
        END IF;
        
        V_ATTEMPT_ID := SLIDING_PUZZLE_UTILS.GET_ACTIVE_ATTEMPT_ID(V_SESSION_ID);
        IF V_ATTEMPT_ID IS NULL THEN
            RETURN NULL;
        END IF;
        
        OPEN V_CURSOR FOR
            SELECT 
                GA.UNDO_POINTER AS MOVES_COUNT,
                GA.CURRENT_MISPLACED_TILES,
                GA.CURRENT_MANHATTAN_DISTANCE,
                PS.GRID_SIZE,
                EXTRACT(HOUR FROM (SYSTIMESTAMP - GA.STARTED_AT)) * 60 +
                EXTRACT(MINUTE FROM (SYSTIMESTAMP - GA.STARTED_AT)) AS ELAPSED_MINUTES,
                EXTRACT(HOUR FROM GA.TIME_LIMIT) * 60 +
                EXTRACT(MINUTE FROM GA.TIME_LIMIT) AS TIME_LIMIT_MINUTES
            FROM GAME_ATTEMPTS GA
            JOIN PUZZLES PZ ON GA.PUZZLE_ID = PZ.ID
            JOIN PUZZLE_SIZES PS ON PZ.PUZZLE_SIZE_ID = PS.ID
            WHERE GA.ID = V_ATTEMPT_ID;
        
        RETURN V_CURSOR;
    EXCEPTION
        WHEN OTHERS THEN
            RETURN NULL;
    END GET_CURRENT_METRICS;
    
    
    FUNCTION GET_AVAILABLE_PUZZLES(
        P_DIFFICULTY_ID IN NUMBER DEFAULT NULL,
        P_SIZE_ID IN NUMBER DEFAULT NULL
    ) RETURN SYS_REFCURSOR IS
        V_CURSOR SYS_REFCURSOR;
    BEGIN
        OPEN V_CURSOR FOR
            SELECT 
                PZ.ID,
                PZ.SEED,
                DL.NAME AS DIFFICULTY,
                DL.SHUFFLE_MOVES,
                PS.GRID_SIZE,
                EXTRACT(HOUR FROM PS.DEFAULT_TIME_LIMIT) * 60 +
                EXTRACT(MINUTE FROM PS.DEFAULT_TIME_LIMIT) AS TIME_LIMIT_MINUTES,
                PZ.IS_DAILY
            FROM PUZZLES PZ
            JOIN DIFFICULTY_LEVELS DL ON PZ.DIFFICULTY_ID = DL.ID
            JOIN PUZZLE_SIZES PS ON PZ.PUZZLE_SIZE_ID = PS.ID
            WHERE (P_DIFFICULTY_ID IS NULL OR PZ.DIFFICULTY_ID = P_DIFFICULTY_ID)
              AND (P_SIZE_ID IS NULL OR PZ.PUZZLE_SIZE_ID = P_SIZE_ID)
            ORDER BY DL.ID, PS.GRID_SIZE;
        
        RETURN V_CURSOR;
    END GET_AVAILABLE_PUZZLES;
    
    
    FUNCTION GET_TOP_PLAYERS(
        P_LIMIT IN NUMBER DEFAULT 10
    ) RETURN SYS_REFCURSOR IS
        V_CURSOR SYS_REFCURSOR;
    BEGIN
        OPEN V_CURSOR FOR
            SELECT 
                USERNAME,
                TOTAL_GAMES,
                SOLVED_GAMES,
                SUCCESS_RATE,
                ROUND(AVG_TIME_MINUTES, 2) AS AVG_TIME_MINUTES,
                BEST_STEPS
            FROM V_TOP_PLAYERS
            WHERE TOTAL_GAMES > 0
            ORDER BY SUCCESS_RATE DESC, SOLVED_GAMES DESC
            AND ROWNUM <= P_LIMIT;
        
        RETURN V_CURSOR;
    END GET_TOP_PLAYERS;
    
    
    FUNCTION GET_PLAYER_HISTORY(
        P_LIMIT IN NUMBER DEFAULT 20
    ) RETURN SYS_REFCURSOR IS
        V_CURSOR SYS_REFCURSOR;
        V_USER_ID NUMBER;
    BEGIN
        V_USER_ID := SLIDING_PUZZLE_UTILS.GET_ACTIVE_USER;
        
        OPEN V_CURSOR FOR
            SELECT 
                GS.ID AS GAME_ID,
                TO_CHAR(GS.START_TIME, 'YYYY-MM-DD HH24:MI:SS') AS START_TIME,
                TO_CHAR(GS.END_TIME, 'YYYY-MM-DD HH24:MI:SS') AS END_TIME,
                GST.NAME AS STATUS,
                GS.STEPS_COUNT,
                PS.GRID_SIZE,
                DL.NAME AS DIFFICULTY,
                EXTRACT(HOUR FROM (GS.END_TIME - GS.START_TIME)) * 60 +
                EXTRACT(MINUTE FROM (GS.END_TIME - GS.START_TIME)) AS DURATION_MINUTES
            FROM GAME_SESSIONS GS
            JOIN GAME_STATUSES GST ON GS.STATUS_ID = GST.ID
            JOIN PUZZLES PZ ON GS.PUZZLE_ID = PZ.ID
            JOIN PUZZLE_SIZES PS ON PZ.PUZZLE_SIZE_ID = PS.ID
            JOIN DIFFICULTY_LEVELS DL ON PZ.DIFFICULTY_ID = DL.ID
            WHERE GS.USER_ID = V_USER_ID
            AND GST.NAME != 'active'
            ORDER BY GS.START_TIME DESC
            AND ROWNUM <= P_LIMIT;
        
        RETURN V_CURSOR;
    EXCEPTION
        WHEN OTHERS THEN
            RETURN NULL;
    END GET_PLAYER_HISTORY;
    
    
    FUNCTION GET_HINT_JSON RETURN VARCHAR2 IS
        V_SESSION_ID NUMBER;
        V_ATTEMPT_ID NUMBER;
        V_STATE VARCHAR2(4000);
        V_TARGET VARCHAR2(4000);
        V_GRID_SIZE NUMBER;
        V_INIT_MANHATTAN NUMBER;
        V_MISPLACED NUMBER;
        V_MANHATTAN NUMBER;
        V_CORRECT NUMBER;
        V_PROGRESS NUMBER;
        V_MOVES NUMBER;
        V_JSON VARCHAR2(4000);
    BEGIN
        V_SESSION_ID := SLIDING_PUZZLE_UTILS.GET_ACTIVE_SESSION_ID;
        IF V_SESSION_ID IS NULL THEN
            RETURN '{"error": "No active game"}';
        END IF;

        V_ATTEMPT_ID := SLIDING_PUZZLE_UTILS.GET_ACTIVE_ATTEMPT_ID(V_SESSION_ID);
        IF V_ATTEMPT_ID IS NULL THEN
            RETURN '{"error": "No active attempt"}';
        END IF;

        BEGIN
            SELECT GA.CURRENT_STATE, PZ.TARGET_STATE, PS.GRID_SIZE,
                   GA.INITIAL_MANHATTAN_DISTANCE, GA.UNDO_POINTER
            INTO V_STATE, V_TARGET, V_GRID_SIZE, V_INIT_MANHATTAN, V_MOVES
            FROM GAME_ATTEMPTS GA
            JOIN PUZZLES PZ ON GA.PUZZLE_ID = PZ.ID
            JOIN PUZZLE_SIZES PS ON PZ.PUZZLE_SIZE_ID = PS.ID
            WHERE GA.ID = V_ATTEMPT_ID;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                RETURN '{"error": "Game data not found"}';
        END;

        SLIDING_PUZZLE_UTILS.CALCULATE_METRICS(
            V_STATE, V_TARGET, V_GRID_SIZE,
            V_MISPLACED, V_MANHATTAN, V_CORRECT
        );

        IF V_INIT_MANHATTAN > 0 THEN
            V_PROGRESS := ROUND((V_INIT_MANHATTAN - V_MANHATTAN) / V_INIT_MANHATTAN * 100);
        ELSE
            V_PROGRESS := 100;
        END IF;
        
        V_JSON := '{' ||
            '"moves": ' || V_MOVES || ',' ||
            '"misplaced": ' || V_MISPLACED || ',' ||
            '"manhattan": ' || V_MANHATTAN || ',' ||
            '"correct": ' || V_CORRECT || ',' ||
            '"progress": ' || V_PROGRESS ||
            '}';
        
        RETURN V_JSON;
    EXCEPTION
        WHEN OTHERS THEN
            RETURN '{"error": "' || REPLACE(SQLERRM, '"', '\"') || '"}';
    END GET_HINT_JSON;
    
    
    PROCEDURE RESTART_GAME IS
        V_SESSION_ID NUMBER;
        V_PUZZLE_ID NUMBER;
        V_NEW_SESSION_ID NUMBER;
    BEGIN
        V_SESSION_ID := SLIDING_PUZZLE_UTILS.GET_ACTIVE_SESSION_ID;
        IF V_SESSION_ID IS NULL THEN
            DBMS_OUTPUT.PUT_LINE('Нет активной игры.');
            RETURN;
        END IF;
        
        SELECT PUZZLE_ID INTO V_PUZZLE_ID
        FROM GAME_SESSIONS 
        WHERE ID = V_SESSION_ID;
        
        SLIDING_PUZZLE_UTILS.END_GAME(V_SESSION_ID, 'abandoned');
        V_NEW_SESSION_ID := SLIDING_PUZZLE_UTILS.START_GAME(V_PUZZLE_ID);
        
        IF V_NEW_SESSION_ID IS NOT NULL THEN
            DBMS_OUTPUT.PUT_LINE('Игра успешно перезапущена.');
        END IF;
    EXCEPTION
        WHEN OTHERS THEN
            DBMS_OUTPUT.PUT_LINE('Ошибка при перезапуске: ' || SQLERRM);
            SLIDING_PUZZLE_UTILS.SAVE_LOG(NULL, 'ERROR', 'RESTART_GAME', SQLERRM);
    END RESTART_GAME;
    
    
    PROCEDURE SHOW_TOP_PLAYERS IS
        V_CURSOR SYS_REFCURSOR;
        V_USERNAME VARCHAR2(50);
        V_TOTAL_GAMES NUMBER;
        V_SOLVED_GAMES NUMBER;
        V_SUCCESS_RATE NUMBER;
        V_AVG_TIME NUMBER;
        V_BEST_STEPS NUMBER;
    BEGIN
        V_CURSOR := GET_TOP_PLAYERS(10);
        
        DBMS_OUTPUT.PUT_LINE('=================================================');
        DBMS_OUTPUT.PUT_LINE('ТОП-10 ИГРОКОВ');
        DBMS_OUTPUT.PUT_LINE('=================================================');
        DBMS_OUTPUT.PUT_LINE(
            RPAD('Игрок', 20) || ' ' ||
            RPAD('Успех %', 8) || ' ' ||
            RPAD('Решено', 8) || ' ' ||
            RPAD('Лучше ходов', 12)
        );
        DBMS_OUTPUT.PUT_LINE('-------------------------------------------------');
        
        LOOP
            FETCH V_CURSOR INTO V_USERNAME, V_TOTAL_GAMES, V_SOLVED_GAMES, 
                                V_SUCCESS_RATE, V_AVG_TIME, V_BEST_STEPS;
            EXIT WHEN V_CURSOR%NOTFOUND;
            
            DBMS_OUTPUT.PUT_LINE(
                RPAD(V_USERNAME, 20) || ' ' ||
                LPAD(TO_CHAR(ROUND(V_SUCCESS_RATE, 2), '999.99'), 8) || ' ' ||
                LPAD(NVL(TO_CHAR(V_SOLVED_GAMES), '0'), 8) || ' ' ||
                LPAD(NVL(TO_CHAR(V_BEST_STEPS), '-'), 12)
            );
        END LOOP;
        CLOSE V_CURSOR;
    END SHOW_TOP_PLAYERS;

END SLIDING_PUZZLE;
/