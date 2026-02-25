-- ================================================================
-- SLIDING PUZZLE -- Пятнашки
-- Лабораторная работа Карпенко Д.С., Яфаров Р.И., КА-22-05
-- Шаг 4 Пакет SLIDING_PUZZLE_UTILS
-- Внутренние процедуры и функции (недоступны игроку напрямую)
-- ================================================================


-- ================================================================
-- СПЕЦИФИКАЦИЯ
-- ================================================================

CREATE OR REPLACE PACKAGE SLIDING_PUZZLE_UTILS AS

    -- Получить ID текущего пользователя по логину БД
    FUNCTION GET_ACTIVE_USER RETURN NUMBER;

    -- Получить ID активной сессии текущего пользователя
    FUNCTION GET_ACTIVE_SESSION_ID RETURN NUMBER;

    -- Получить ID активной попытки по сессии
    FUNCTION GET_ACTIVE_ATTEMPT_ID(P_SESSION_ID IN NUMBER) RETURN NUMBER;

    -- Зарегистрировать пользователя если не существует, вернуть ID
    FUNCTION GET_OR_CREATE_USER RETURN NUMBER;

    -- Создать игровую сессию, вернуть ID сессии
    FUNCTION START_GAME(P_PUZZLE_ID IN NUMBER) RETURN NUMBER;

    -- Сгенерировать поле NxN из решённого состояния случайными ходами
    -- Возвращает начальное состояние в виде строки 1,2,3,4,5,6,7,8,0
    FUNCTION GENERATE_PUZZLE(
        P_GRID_SIZE IN NUMBER,
        P_SHUFFLE_MOVES IN NUMBER,
        P_SEED IN VARCHAR2
    ) RETURN VARCHAR2;

    -- Проверить победу текущее состояние == целевое
    FUNCTION CHECK_WIN(P_ATTEMPT_ID IN NUMBER) RETURN NUMBER;

    -- Рассчитать метрики misplaced tiles и manhattan distance
    PROCEDURE CALCULATE_METRICS(
        P_STATE IN VARCHAR2,
        P_TARGET IN VARCHAR2,
        P_GRID_SIZE IN NUMBER,
        P_MISPLACED OUT NUMBER,
        P_MANHATTAN OUT NUMBER,
        P_CORRECT OUT NUMBER
    );

    -- Нарисовать игровое поле в консоли
    PROCEDURE DRAW_BOARD(P_ATTEMPT_ID IN NUMBER);

    -- Завершить игровую сессию с указанным статусом
    PROCEDURE END_GAME(P_SESSION_ID IN NUMBER, P_STATUS_NAME IN VARCHAR2);

    -- Проверить активность игрока (автозавершение по таймауту)
    PROCEDURE CHECK_USER_ACTIVE_GAME;

    -- Установить пазл дня (вызывается планировщиком)
    PROCEDURE SET_DAILY_PUZZLE;

    -- Записать лог
    PROCEDURE SAVE_LOG(
        P_SESSION_ID IN NUMBER,
        P_LOG_TYPE IN VARCHAR2,
        P_PROCEDURE_NAME IN VARCHAR2,
        P_MESSAGE IN VARCHAR2
    );

END SLIDING_PUZZLE_UTILS;
/


-- ================================================================
-- ТЕЛО ПАКЕТА
-- ================================================================

CREATE OR REPLACE PACKAGE BODY SLIDING_PUZZLE_UTILS AS

    -- ============================================================
    -- GET_ACTIVE_USER
    -- Определяет ID текущего пользователя через имя сессии БД.
    -- Если пользователь не найден — возвращает NULL.
    -- ============================================================
    FUNCTION GET_ACTIVE_USER RETURN NUMBER IS
        V_USER_ID NUMBER;
        V_DB_NAME VARCHAR2(128);
    BEGIN
        V_DB_NAME := SYS_CONTEXT('USERENV', 'SESSION_USER');
        SELECT ID INTO V_USER_ID
        FROM USERS
        WHERE DB_USERNAME = V_DB_NAME;
        RETURN V_USER_ID;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RETURN NULL;
    END GET_ACTIVE_USER;


    -- ============================================================
    -- GET_ACTIVE_SESSION_ID
    -- Возвращает ID активной сессии текущего пользователя.
    -- Активная = статус 'active' и последняя активность < 1 часа.
    -- Если нет активной сессии — возвращает NULL.
    -- ============================================================
    FUNCTION GET_ACTIVE_SESSION_ID RETURN NUMBER IS
        V_SESSION_ID NUMBER;
        V_USER_ID NUMBER;
    BEGIN
        V_USER_ID := GET_ACTIVE_USER;
        IF V_USER_ID IS NULL THEN
            RETURN NULL;
        END IF;
        SELECT GS.ID INTO V_SESSION_ID
        FROM GAME_SESSIONS GS
        JOIN GAME_STATUSES GST ON GS.STATUS_ID = GST.ID
        WHERE GS.USER_ID = V_USER_ID
        AND GST.NAME = 'active'
        AND GS.LAST_ACTIVITY_AT > SYSTIMESTAMP - INTERVAL '1' HOUR
        AND ROWNUM = 1;
        RETURN V_SESSION_ID;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RETURN NULL;
    END GET_ACTIVE_SESSION_ID;


    -- ============================================================
    -- GET_ACTIVE_ATTEMPT_ID
    -- Возвращает ID активной попытки для переданной сессии.
    -- ============================================================
    FUNCTION GET_ACTIVE_ATTEMPT_ID(P_SESSION_ID IN NUMBER) RETURN NUMBER IS
        V_ATTEMPT_ID NUMBER;
    BEGIN
        SELECT GA.ID INTO V_ATTEMPT_ID
        FROM GAME_ATTEMPTS GA
        JOIN GAME_STATUSES GS ON GA.STATUS_ID = GS.ID
        WHERE GA.SESSION_ID = P_SESSION_ID
        AND GS.NAME = 'active'
        AND ROWNUM = 1;
        RETURN V_ATTEMPT_ID;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RETURN NULL;
    END GET_ACTIVE_ATTEMPT_ID;


    -- ============================================================
    -- GET_OR_CREATE_USER
    -- Ищет пользователя по имени сессии БД.
    -- Если не найден — создаёт новую запись и возвращает ID.
    -- ============================================================
    FUNCTION GET_OR_CREATE_USER RETURN NUMBER IS
        V_USER_ID NUMBER;
        V_DB_NAME VARCHAR2(128);
    BEGIN
        V_DB_NAME := SYS_CONTEXT('USERENV', 'SESSION_USER');
        BEGIN
            SELECT ID INTO V_USER_ID
            FROM USERS
            WHERE DB_USERNAME = V_DB_NAME;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                INSERT INTO USERS (ID, DB_USERNAME, USERNAME, GAMES_COUNT, CREATED_AT)
                VALUES (SEQ_USERS.NEXTVAL, V_DB_NAME, V_DB_NAME, 0, SYSTIMESTAMP)
                RETURNING ID INTO V_USER_ID;
        END;
        RETURN V_USER_ID;
    END GET_OR_CREATE_USER;


    -- ============================================================
    -- START_GAME
    -- Создаёт новую игровую сессию и попытку для указанного пазла.
    -- Проверяет отсутствие уже активной сессии у пользователя.
    -- Возвращает ID созданной сессии.
    -- ============================================================
    FUNCTION START_GAME(P_PUZZLE_ID IN NUMBER) RETURN NUMBER IS
        V_USER_ID NUMBER;
        V_SESSION_ID NUMBER;
        V_ATTEMPT_ID NUMBER;
        V_ACTIVE_SESSION NUMBER;
        V_STATUS_ACTIVE NUMBER;
        V_GRID_SIZE NUMBER;
        V_DIFF_MOVES NUMBER;
        V_SEED VARCHAR2(100);
        V_INITIAL_STATE VARCHAR2(4000);
        V_TARGET_STATE VARCHAR2(4000);
        V_TIME_LIMIT INTERVAL DAY(0) TO SECOND(0);
        V_MISPLACED NUMBER;
        V_MANHATTAN NUMBER;
        V_CORRECT NUMBER;
        V_TOKEN VARCHAR2(255);
    BEGIN
        -- Получить или создать пользователя
        V_USER_ID := GET_OR_CREATE_USER;

        -- Проверить наличие активной сессии
        V_ACTIVE_SESSION := GET_ACTIVE_SESSION_ID;
        IF V_ACTIVE_SESSION IS NOT NULL THEN
            DBMS_OUTPUT.PUT_LINE('=================================================');
            DBMS_OUTPUT.PUT_LINE('ВНИМАНИЕ: у вас уже есть активная игра (ID=' || V_ACTIVE_SESSION || ').');
            DBMS_OUTPUT.PUT_LINE('Завершите её перед началом новой:');
            DBMS_OUTPUT.PUT_LINE('  EXEC SLIDING_PUZZLE.GAME_OVER;');
            DBMS_OUTPUT.PUT_LINE('=================================================');
            RETURN NULL;
        END IF;

        -- Получить данные пазла
        SELECT
            PS.GRID_SIZE,
            DL.SHUFFLE_MOVES,
            PZ.SEED,
            PZ.INITIAL_STATE,
            PZ.TARGET_STATE,
            PS.DEFAULT_TIME_LIMIT
        INTO V_GRID_SIZE, V_DIFF_MOVES, V_SEED, V_INITIAL_STATE, V_TARGET_STATE, V_TIME_LIMIT
        FROM PUZZLES PZ
        JOIN PUZZLE_SIZES PS ON PZ.PUZZLE_SIZE_ID = PS.ID
        JOIN DIFFICULTY_LEVELS DL ON PZ.DIFFICULTY_ID = DL.ID
        WHERE PZ.ID = P_PUZZLE_ID;

        -- Получить ID статуса 'active'
        SELECT ID INTO V_STATUS_ACTIVE FROM GAME_STATUSES WHERE NAME = 'active';

        -- Сгенерировать уникальный токен сессии
        V_TOKEN := V_USER_ID || '_' || P_PUZZLE_ID || '_' || TO_CHAR(SYSDATE, 'YYYYMMDDHH24MISS');

        -- Создать сессию
        INSERT INTO GAME_SESSIONS (
            ID, USER_ID, PUZZLE_ID, STATUS_ID,
            SESSION_TOKEN, STEPS_COUNT, LAST_ACTIVITY_AT, START_TIME
        ) VALUES (
            SEQ_GAME_SESSIONS.NEXTVAL, V_USER_ID, P_PUZZLE_ID, V_STATUS_ACTIVE,
            V_TOKEN, 0, SYSTIMESTAMP, SYSDATE
        ) RETURNING ID INTO V_SESSION_ID;

        -- Рассчитать начальные метрики
        CALCULATE_METRICS(V_INITIAL_STATE, V_TARGET_STATE, V_GRID_SIZE,
                          V_MISPLACED, V_MANHATTAN, V_CORRECT);

        -- Создать попытку
        INSERT INTO GAME_ATTEMPTS (
            ID, SESSION_ID, USER_ID, PUZZLE_ID,
            GAME_MODE, CURRENT_STATE,
            INITIAL_MISPLACED_TILES, INITIAL_MANHATTAN_DISTANCE,
            CURRENT_MISPLACED_TILES, CURRENT_MANHATTAN_DISTANCE,
            UNDO_POINTER, STATUS_ID, TIME_LIMIT, STARTED_AT
        ) VALUES (
            SEQ_GAME_ATTEMPTS.NEXTVAL, V_SESSION_ID, V_USER_ID, P_PUZZLE_ID,
            'numbers', V_INITIAL_STATE,
            V_MISPLACED, V_MANHATTAN,
            V_MISPLACED, V_MANHATTAN,
            0, V_STATUS_ACTIVE, V_TIME_LIMIT, SYSTIMESTAMP
        ) RETURNING ID INTO V_ATTEMPT_ID;

        -- Сохранить начальное состояние в историю ходов (шаг 0)
        INSERT INTO GAME_STEPS (
            ID, SESSION_ID, ATTEMPT_ID, ACTION_ID,
            STATE_AFTER, IS_ACTUAL, IS_IMPORT, IS_MARK,
            STEP_INDEX, STEP_TIME
        ) VALUES (
            SEQ_GAME_STEPS.NEXTVAL, V_SESSION_ID, V_ATTEMPT_ID,
            (SELECT ID FROM ACTION_TYPES WHERE NAME = 'move'),
            V_INITIAL_STATE, 1, 0, 0, 0, SYSDATE
        );

        -- Обновить счётчик игр и дату первой игры у пользователя
        UPDATE USERS
        SET GAMES_COUNT = GAMES_COUNT + 1,
            FIRST_GAME_DATE = NVL(FIRST_GAME_DATE, SYSDATE)
        WHERE ID = V_USER_ID;

        -- Записать лог
        SAVE_LOG(V_SESSION_ID, 'INFO', 'START_GAME',
                 'Игра начата. Пазл ID=' || P_PUZZLE_ID || ', размер=' || V_GRID_SIZE || 'x' || V_GRID_SIZE);

        COMMIT;

        -- Нарисовать поле
        DRAW_BOARD(V_ATTEMPT_ID);

        RETURN V_SESSION_ID;

    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            DBMS_OUTPUT.PUT_LINE('ОШИБКА: пазл с ID=' || P_PUZZLE_ID || ' не найден.');
            SAVE_LOG(NULL, 'ERROR', 'START_GAME', 'Пазл не найден. ID=' || P_PUZZLE_ID);
            RETURN NULL;
        WHEN OTHERS THEN
            ROLLBACK;
            DBMS_OUTPUT.PUT_LINE('ОШИБКА при запуске игры: ' || SQLERRM);
            SAVE_LOG(NULL, 'ERROR', 'START_GAME', SQLERRM);
            RETURN NULL;
    END START_GAME;


    -- ============================================================
    -- GENERATE_PUZZLE
    -- Генерирует перемешанное поле NxN начиная из решённого
    -- состояния путём P_SHUFFLE_MOVES случайных легальных ходов.
    -- Состояние хранится как строка через запятую
    --   1,2,3,4,5,6,7,8,0  (0 = пустая клетка)
    -- Гарантирует разрешимость, так как перемешивание идёт
    -- только через легальные ходы из решённого состояния.
    -- ============================================================
    FUNCTION GENERATE_PUZZLE(
        P_GRID_SIZE IN NUMBER,
        P_SHUFFLE_MOVES IN NUMBER,
        P_SEED IN VARCHAR2
    ) RETURN VARCHAR2 IS
        TYPE T_BOARD IS TABLE OF NUMBER INDEX BY PLS_INTEGER;
        V_BOARD T_BOARD;
        V_TOTAL NUMBER;
        V_EMPTY_POS NUMBER;
        V_PREV_DIR NUMBER := -1;
        V_DIR NUMBER;
        V_NEW_POS NUMBER;
        V_TEMP NUMBER;
        V_RESULT VARCHAR2(4000) := '';
        V_SEED_NUM NUMBER;
        V_RND NUMBER;
    BEGIN
        V_TOTAL := P_GRID_SIZE * P_GRID_SIZE;

        -- Заполнить решённое состояние 1,2,3,...,N*N-1,0
        FOR I IN 1..V_TOTAL LOOP
            IF I = V_TOTAL THEN
                V_BOARD(I) := 0;
            ELSE
                V_BOARD(I) := I;
            END IF;
        END LOOP;
        V_EMPTY_POS := V_TOTAL;

        -- Инициализировать генератор по seed
        V_SEED_NUM := 0;
        FOR I IN 1..LENGTH(P_SEED) LOOP
            V_SEED_NUM := V_SEED_NUM + ASCII(SUBSTR(P_SEED, I, 1));
        END LOOP;
        DBMS_RANDOM.SEED(V_SEED_NUM);

        -- Перемешать P_SHUFFLE_MOVES легальными ходами
        FOR STEP IN 1..P_SHUFFLE_MOVES LOOP
            -- Найти возможные направления (0=вверх,1=вниз,2=влево,3=вправо)
            -- и исключить обратное к предыдущему ходу
            DECLARE
                TYPE T_DIRS IS TABLE OF NUMBER INDEX BY PLS_INTEGER;
                V_DIRS T_DIRS;
                V_CNT NUMBER := 0;
                V_ROW NUMBER;
                V_COL NUMBER;
            BEGIN
                V_ROW := CEIL(V_EMPTY_POS / P_GRID_SIZE);
                V_COL := MOD(V_EMPTY_POS - 1, P_GRID_SIZE) + 1;

                -- Вверх: пустая не в первой строке, не обратно к вниз(1)
                IF V_ROW > 1 AND V_PREV_DIR != 1 THEN
                    V_CNT := V_CNT + 1;
                    V_DIRS(V_CNT) := 0;
                END IF;
                -- Вниз: пустая не в последней строке, не обратно к вверх(0)
                IF V_ROW < P_GRID_SIZE AND V_PREV_DIR != 0 THEN
                    V_CNT := V_CNT + 1;
                    V_DIRS(V_CNT) := 1;
                END IF;
                -- Влево: пустая не в первом столбце, не обратно к вправо(3)
                IF V_COL > 1 AND V_PREV_DIR != 3 THEN
                    V_CNT := V_CNT + 1;
                    V_DIRS(V_CNT) := 2;
                END IF;
                -- Вправо: пустая не в последнем столбце, не обратно к влево(2)
                IF V_COL < P_GRID_SIZE AND V_PREV_DIR != 2 THEN
                    V_CNT := V_CNT + 1;
                    V_DIRS(V_CNT) := 3;
                END IF;

                -- Выбрать случайное направление
                V_RND := TRUNC(DBMS_RANDOM.VALUE(1, V_CNT + 1));
                V_DIR := V_DIRS(V_RND);
                V_PREV_DIR := V_DIR;

                -- Вычислить позицию плитки которую двигаем
                IF V_DIR = 0 THEN
                    V_NEW_POS := V_EMPTY_POS - P_GRID_SIZE;
                ELSIF V_DIR = 1 THEN
                    V_NEW_POS := V_EMPTY_POS + P_GRID_SIZE;
                ELSIF V_DIR = 2 THEN
                    V_NEW_POS := V_EMPTY_POS - 1;
                ELSE
                    V_NEW_POS := V_EMPTY_POS + 1;
                END IF;

                -- Поменять местами пустую и плитку
                V_TEMP := V_BOARD(V_NEW_POS);
                V_BOARD(V_NEW_POS) := 0;
                V_BOARD(V_EMPTY_POS) := V_TEMP;
                V_EMPTY_POS := V_NEW_POS;
            END;
        END LOOP;

        -- Собрать результат в строку через запятую
        FOR I IN 1..V_TOTAL LOOP
            IF I = 1 THEN
                V_RESULT := TO_CHAR(V_BOARD(I));
            ELSE
                V_RESULT := V_RESULT || ',' || TO_CHAR(V_BOARD(I));
            END IF;
        END LOOP;

        RETURN V_RESULT;
    END GENERATE_PUZZLE;


    -- ============================================================
    -- CHECK_WIN
    -- Сравнивает текущее состояние попытки с целевым.
    -- Возвращает 1 если совпадают, 0 если нет.
    -- ============================================================
    FUNCTION CHECK_WIN(P_ATTEMPT_ID IN NUMBER) RETURN NUMBER IS
        V_CURRENT VARCHAR2(4000);
        V_TARGET VARCHAR2(4000);
    BEGIN
        SELECT GA.CURRENT_STATE, PZ.TARGET_STATE
        INTO V_CURRENT, V_TARGET
        FROM GAME_ATTEMPTS GA
        JOIN PUZZLES PZ ON GA.PUZZLE_ID = PZ.ID
        WHERE GA.ID = P_ATTEMPT_ID;

        IF V_CURRENT = V_TARGET THEN
            RETURN 1;
        ELSE
            RETURN 0;
        END IF;
    END CHECK_WIN;


    -- ============================================================
    -- CALCULATE_METRICS
    -- Рассчитывает для текущего состояния
    --   P_MISPLACED  — кол-во плиток не на своём месте
    --   P_MANHATTAN  — сумма манхэттенских расстояний до цели
    --   P_CORRECT    — кол-во плиток на своём месте
    -- Состояния передаются строкой 1,2,3,4,5,6,7,8,0.
    -- ============================================================
    PROCEDURE CALCULATE_METRICS(
        P_STATE IN VARCHAR2,
        P_TARGET IN VARCHAR2,
        P_GRID_SIZE IN NUMBER,
        P_MISPLACED OUT NUMBER,
        P_MANHATTAN OUT NUMBER,
        P_CORRECT OUT NUMBER
    ) IS
        TYPE T_ARR IS TABLE OF NUMBER INDEX BY PLS_INTEGER;
        V_CUR T_ARR;
        V_TGT T_ARR;
        V_TOTAL NUMBER;
        V_STR VARCHAR2(4000);
        V_POS NUMBER;
        V_IDX NUMBER;
        V_CUR_ROW NUMBER;
        V_CUR_COL NUMBER;
        V_TGT_ROW NUMBER;
        V_TGT_COL NUMBER;
        V_VAL NUMBER;
    BEGIN
        V_TOTAL := P_GRID_SIZE * P_GRID_SIZE;
        P_MISPLACED := 0;
        P_MANHATTAN := 0;
        P_CORRECT := 0;

        -- Разобрать текущее состояние
        V_STR := P_STATE || ',';
        V_IDX := 1;
        LOOP
            V_POS := INSTR(V_STR, ',');
            EXIT WHEN V_POS = 0;
            V_CUR(V_IDX) := TO_NUMBER(SUBSTR(V_STR, 1, V_POS - 1));
            V_STR := SUBSTR(V_STR, V_POS + 1);
            V_IDX := V_IDX + 1;
        END LOOP;

        -- Разобрать целевое состояние
        V_STR := P_TARGET || ',';
        V_IDX := 1;
        LOOP
            V_POS := INSTR(V_STR, ',');
            EXIT WHEN V_POS = 0;
            V_TGT(V_IDX) := TO_NUMBER(SUBSTR(V_STR, 1, V_POS - 1));
            V_STR := SUBSTR(V_STR, V_POS + 1);
            V_IDX := V_IDX + 1;
        END LOOP;

        -- Подсчитать метрики для каждой плитки (кроме пустой)
        FOR I IN 1..V_TOTAL LOOP
            V_VAL := V_CUR(I);
            IF V_VAL != 0 THEN
                -- Найти позицию этой плитки в целевом состоянии
                FOR J IN 1..V_TOTAL LOOP
                    IF V_TGT(J) = V_VAL THEN
                        V_CUR_ROW := CEIL(I / P_GRID_SIZE);
                        V_CUR_COL := MOD(I - 1, P_GRID_SIZE) + 1;
                        V_TGT_ROW := CEIL(J / P_GRID_SIZE);
                        V_TGT_COL := MOD(J - 1, P_GRID_SIZE) + 1;

                        P_MANHATTAN := P_MANHATTAN
                            + ABS(V_CUR_ROW - V_TGT_ROW)
                            + ABS(V_CUR_COL - V_TGT_COL);

                        IF I = J THEN
                            P_CORRECT := P_CORRECT + 1;
                        ELSE
                            P_MISPLACED := P_MISPLACED + 1;
                        END IF;
                        EXIT;
                    END IF;
                END LOOP;
            END IF;
        END LOOP;
    END CALCULATE_METRICS;


    -- ============================================================
    -- DRAW_BOARD
    -- Выводит текущее состояние игрового поля в консоль.
    -- Формат (пример 3x3):
    --   +---+---+---+
    --   | 1 | 2 | 3 |
    --   +---+---+---+
    --   | 4 |   | 5 |
    --   +---+---+---+
    --   | 6 | 7 | 8 |
    --   +---+---+---+
    --   Ходов: 5    Не на месте: 3    Манхэттен: 7    Прогресс: 50%
    -- ============================================================
    PROCEDURE DRAW_BOARD(P_ATTEMPT_ID IN NUMBER) IS
        V_STATE VARCHAR2(4000);
        V_TARGET VARCHAR2(4000);
        V_GRID_SIZE NUMBER;
        V_MOVES NUMBER;
        V_MISPLACED NUMBER;
        V_MANHATTAN NUMBER;
        V_CORRECT NUMBER;
        V_TOTAL NUMBER;
        V_STR VARCHAR2(4000);
        V_POS NUMBER;
        V_IDX NUMBER := 1;
        TYPE T_ARR IS TABLE OF NUMBER INDEX BY PLS_INTEGER;
        V_BOARD T_ARR;
        V_SEP VARCHAR2(200);
        V_LINE VARCHAR2(200);
        V_VAL NUMBER;
        V_CELL VARCHAR2(5);
        V_TIME_ELAPSED INTERVAL DAY TO SECOND;
        V_PROGRESS NUMBER;
        V_INIT_MANHATTAN NUMBER;
    BEGIN
        -- Получить данные попытки
        SELECT
            GA.CURRENT_STATE,
            PZ.TARGET_STATE,
            PS.GRID_SIZE,
            GA.UNDO_POINTER,
            GA.CURRENT_MISPLACED_TILES,
            GA.CURRENT_MANHATTAN_DISTANCE,
            GA.INITIAL_MANHATTAN_DISTANCE,
            (SYSTIMESTAMP - GA.STARTED_AT) DAY TO SECOND
        INTO V_STATE, V_TARGET, V_GRID_SIZE, V_MOVES,
             V_MISPLACED, V_MANHATTAN, V_INIT_MANHATTAN, V_TIME_ELAPSED
        FROM GAME_ATTEMPTS GA
        JOIN PUZZLES PZ ON GA.PUZZLE_ID = PZ.ID
        JOIN PUZZLE_SIZES PS ON PZ.PUZZLE_SIZE_ID = PS.ID
        WHERE GA.ID = P_ATTEMPT_ID;

        -- Рассчитать правильных плиток
        CALCULATE_METRICS(V_STATE, V_TARGET, V_GRID_SIZE,
                          V_MISPLACED, V_MANHATTAN, V_CORRECT);

        -- Прогресс %
        IF V_INIT_MANHATTAN > 0 THEN
            V_PROGRESS := ROUND((V_INIT_MANHATTAN - V_MANHATTAN) / V_INIT_MANHATTAN * 100);
        ELSE
            V_PROGRESS := 100;
        END IF;

        -- Разобрать состояние в массив
        V_STR := V_STATE || ',';
        V_IDX := 1;
        LOOP
            V_POS := INSTR(V_STR, ',');
            EXIT WHEN V_POS = 0;
            V_BOARD(V_IDX) := TO_NUMBER(SUBSTR(V_STR, 1, V_POS - 1));
            V_STR := SUBSTR(V_STR, V_POS + 1);
            V_IDX := V_IDX + 1;
        END LOOP;

        V_TOTAL := V_GRID_SIZE * V_GRID_SIZE;

        -- Построить разделитель строк +---+---+---+
        V_SEP := '+';
        FOR C IN 1..V_GRID_SIZE LOOP
            V_SEP := V_SEP || '---+';
        END LOOP;

        DBMS_OUTPUT.PUT_LINE('');
        DBMS_OUTPUT.PUT_LINE(V_SEP);

        -- Вывести строки поля
        FOR R IN 1..V_GRID_SIZE LOOP
            V_LINE := '|';
            FOR C IN 1..V_GRID_SIZE LOOP
                V_VAL := V_BOARD((R - 1) * V_GRID_SIZE + C);
                IF V_VAL = 0 THEN
                    V_CELL := '   ';
                ELSIF V_VAL < 10 THEN
                    V_CELL := ' ' || TO_CHAR(V_VAL) || ' ';
                ELSE
                    V_CELL := TO_CHAR(V_VAL) || ' ';
                END IF;
                V_LINE := V_LINE || V_CELL || '|';
            END LOOP;
            DBMS_OUTPUT.PUT_LINE(V_LINE);
            DBMS_OUTPUT.PUT_LINE(V_SEP);
        END LOOP;

        -- Статистика под полем
        DBMS_OUTPUT.PUT_LINE('');
        DBMS_OUTPUT.PUT_LINE(
            'Ходов: ' || V_MOVES ||
            '    Не на месте: ' || V_MISPLACED ||
            '    Манхэттен: ' || V_MANHATTAN ||
            '    Прогресс: ' || V_PROGRESS || '%'
        );
        DBMS_OUTPUT.PUT_LINE('');

    EXCEPTION
        WHEN OTHERS THEN
            DBMS_OUTPUT.PUT_LINE('ОШИБКА при отрисовке поля: ' || SQLERRM);
    END DRAW_BOARD;


    -- ============================================================
    -- END_GAME
    -- Завершает игровую сессию обновляет статус и время окончания.
    -- P_STATUS_NAME: 'solved', 'abandoned', 'timeout', 'exported'
    -- ============================================================
    PROCEDURE END_GAME(P_SESSION_ID IN NUMBER, P_STATUS_NAME IN VARCHAR2) IS
        V_STATUS_ID NUMBER;
        V_ATTEMPT_ID NUMBER;
    BEGIN
        SELECT ID INTO V_STATUS_ID FROM GAME_STATUSES WHERE NAME = P_STATUS_NAME;

        -- Завершить активную попытку
        V_ATTEMPT_ID := GET_ACTIVE_ATTEMPT_ID(P_SESSION_ID);
        IF V_ATTEMPT_ID IS NOT NULL THEN
            UPDATE GAME_ATTEMPTS
            SET STATUS_ID = V_STATUS_ID,
                FINISHED_AT = SYSTIMESTAMP
            WHERE ID = V_ATTEMPT_ID;
        END IF;

        -- Завершить сессию
        UPDATE GAME_SESSIONS
        SET STATUS_ID = V_STATUS_ID,
            END_TIME = SYSDATE
        WHERE ID = P_SESSION_ID;

        SAVE_LOG(P_SESSION_ID, 'INFO', 'END_GAME',
                 'Игра завершена со статусом ' || P_STATUS_NAME);
        COMMIT;
    EXCEPTION
        WHEN OTHERS THEN
            ROLLBACK;
            SAVE_LOG(P_SESSION_ID, 'ERROR', 'END_GAME', SQLERRM);
    END END_GAME;


    -- ============================================================
    -- CHECK_USER_ACTIVE_GAME
    -- Проверяет время последней активности текущего пользователя.
    -- Если прошло более 15 минут — завершает сессию с timeout.
    -- ============================================================
    PROCEDURE CHECK_USER_ACTIVE_GAME IS
        V_SESSION_ID NUMBER;
        V_LAST_ACTIVITY TIMESTAMP WITH TIME ZONE;
    BEGIN
        V_SESSION_ID := GET_ACTIVE_SESSION_ID;
        IF V_SESSION_ID IS NULL THEN
            RETURN;
        END IF;

        SELECT LAST_ACTIVITY_AT INTO V_LAST_ACTIVITY
        FROM GAME_SESSIONS
        WHERE ID = V_SESSION_ID;

        IF SYSTIMESTAMP - V_LAST_ACTIVITY > INTERVAL '15' MINUTE THEN
            DBMS_OUTPUT.PUT_LINE('Время хода истекло. Игра завершена автоматически.');
            END_GAME(V_SESSION_ID, 'timeout');
        END IF;
    EXCEPTION
        WHEN OTHERS THEN
            SAVE_LOG(V_SESSION_ID, 'ERROR', 'CHECK_USER_ACTIVE_GAME', SQLERRM);
    END CHECK_USER_ACTIVE_GAME;


    -- ============================================================
    -- SET_DAILY_PUZZLE
    -- Сбрасывает флаг IS_DAILY у всех пазлов и устанавливает
    -- его случайному пазлу на текущую дату.
    -- Вызывается планировщиком ежедневно в 00:00.
    -- ============================================================
    PROCEDURE SET_DAILY_PUZZLE IS
        V_PUZZLE_ID NUMBER;
    BEGIN
        -- Снять флаг у всех
        UPDATE PUZZLES SET IS_DAILY = 0;

        -- Выбрать случайный пазл и установить флаг
        SELECT ID INTO V_PUZZLE_ID
        FROM (
            SELECT ID FROM PUZZLES
            ORDER BY DBMS_RANDOM.VALUE
        )
        WHERE ROWNUM = 1;

        UPDATE PUZZLES SET IS_DAILY = 1 WHERE ID = V_PUZZLE_ID;

        SAVE_LOG(NULL, 'INFO', 'SET_DAILY_PUZZLE',
                 'Пазл дня установлен. ID=' || V_PUZZLE_ID);
        COMMIT;
    EXCEPTION
        WHEN OTHERS THEN
            ROLLBACK;
            SAVE_LOG(NULL, 'ERROR', 'SET_DAILY_PUZZLE', SQLERRM);
    END SET_DAILY_PUZZLE;


    -- ============================================================
    -- SAVE_LOG
    -- Записывает событие в таблицу LOGS.
    -- Использует автономную транзакцию чтобы лог сохранялся
    -- даже при откате основной транзакции.
    -- ============================================================
    PROCEDURE SAVE_LOG(
        P_SESSION_ID IN NUMBER,
        P_LOG_TYPE IN VARCHAR2,
        P_PROCEDURE_NAME IN VARCHAR2,
        P_MESSAGE IN VARCHAR2
    ) IS
        PRAGMA AUTONOMOUS_TRANSACTION;
    BEGIN
        INSERT INTO LOGS (ID, LOG_DATE, SESSION_ID, LOG_TYPE, PROCEDURE_NAME, MESSAGE)
        VALUES (SEQ_LOGS.NEXTVAL, SYSDATE, P_SESSION_ID, P_LOG_TYPE, P_PROCEDURE_NAME, P_MESSAGE);
        COMMIT;
    EXCEPTION
        WHEN OTHERS THEN
            NULL; -- лог не должен ронять основную логику
    END SAVE_LOG;

END SLIDING_PUZZLE_UTILS;
/