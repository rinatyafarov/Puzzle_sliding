INSERT INTO GAME_STATUSES (ID, NAME) VALUES (SEQ_GAME_STATUSES.NEXTVAL, 'active');
INSERT INTO GAME_STATUSES (ID, NAME) VALUES (SEQ_GAME_STATUSES.NEXTVAL, 'solved');
INSERT INTO GAME_STATUSES (ID, NAME) VALUES (SEQ_GAME_STATUSES.NEXTVAL, 'abandoned');
INSERT INTO GAME_STATUSES (ID, NAME) VALUES (SEQ_GAME_STATUSES.NEXTVAL, 'timeout');
INSERT INTO GAME_STATUSES (ID, NAME) VALUES (SEQ_GAME_STATUSES.NEXTVAL, 'exported');


-- ================================================================
-- 2. ACTION_TYPES
-- ================================================================

INSERT INTO ACTION_TYPES (ID, NAME) VALUES (SEQ_ACTION_TYPES.NEXTVAL, 'move');
INSERT INTO ACTION_TYPES (ID, NAME) VALUES (SEQ_ACTION_TYPES.NEXTVAL, 'undo');
INSERT INTO ACTION_TYPES (ID, NAME) VALUES (SEQ_ACTION_TYPES.NEXTVAL, 'redo');
INSERT INTO ACTION_TYPES (ID, NAME) VALUES (SEQ_ACTION_TYPES.NEXTVAL, 'restart');
INSERT INTO ACTION_TYPES (ID, NAME) VALUES (SEQ_ACTION_TYPES.NEXTVAL, 'hint');
INSERT INTO ACTION_TYPES (ID, NAME) VALUES (SEQ_ACTION_TYPES.NEXTVAL, 'import');


-- ================================================================
-- 3. DIFFICULTY_LEVELS
-- ================================================================

INSERT INTO DIFFICULTY_LEVELS (ID, NAME, SHUFFLE_MOVES) VALUES (SEQ_DIFF_LEVELS.NEXTVAL, 'Easy', 50);
INSERT INTO DIFFICULTY_LEVELS (ID, NAME, SHUFFLE_MOVES) VALUES (SEQ_DIFF_LEVELS.NEXTVAL, 'Medium', 200);
INSERT INTO DIFFICULTY_LEVELS (ID, NAME, SHUFFLE_MOVES) VALUES (SEQ_DIFF_LEVELS.NEXTVAL, 'Hard', 1000);


-- ================================================================
-- 4. PUZZLE_SIZES
--    Лимит времени: ceil(10 * (N / 4)) минут
--    N=3 ->  8 мин
--    N=4 -> 10 мин
--    N=5 -> 13 мин
--    N=6 -> 15 мин
--    N=7 -> 18 мин
-- ================================================================

INSERT INTO PUZZLE_SIZES (ID, GRID_SIZE, DEFAULT_TIME_LIMIT) VALUES (SEQ_PUZZLE_SIZES.NEXTVAL, 3, INTERVAL '8' MINUTE);
INSERT INTO PUZZLE_SIZES (ID, GRID_SIZE, DEFAULT_TIME_LIMIT) VALUES (SEQ_PUZZLE_SIZES.NEXTVAL, 4, INTERVAL '10' MINUTE);
INSERT INTO PUZZLE_SIZES (ID, GRID_SIZE, DEFAULT_TIME_LIMIT) VALUES (SEQ_PUZZLE_SIZES.NEXTVAL, 5, INTERVAL '13' MINUTE);
INSERT INTO PUZZLE_SIZES (ID, GRID_SIZE, DEFAULT_TIME_LIMIT) VALUES (SEQ_PUZZLE_SIZES.NEXTVAL, 6, INTERVAL '15' MINUTE);
INSERT INTO PUZZLE_SIZES (ID, GRID_SIZE, DEFAULT_TIME_LIMIT) VALUES (SEQ_PUZZLE_SIZES.NEXTVAL, 7, INTERVAL '18' MINUTE);



-- Добавим несколько пазлов разных размеров
-- Easy 5x5
INSERT INTO PUZZLES (ID, PUZZLE_SIZE_ID, DIFFICULTY_ID, SEED, IS_DAILY, INITIAL_STATE, TARGET_STATE, CREATED_AT)
VALUES (SEQ_PUZZLES.NEXTVAL, 
        (SELECT ID FROM PUZZLE_SIZES WHERE GRID_SIZE=5), 
        (SELECT ID FROM DIFFICULTY_LEVELS WHERE NAME='Easy'), 
        'easy_5x5_1', 0,
        '[1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,0]',
        '[1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,0]',
        SYSTIMESTAMP);

-- Medium 5x5
INSERT INTO PUZZLES (ID, PUZZLE_SIZE_ID, DIFFICULTY_ID, SEED, IS_DAILY, INITIAL_STATE, TARGET_STATE, CREATED_AT)
VALUES (SEQ_PUZZLES.NEXTVAL, 
        (SELECT ID FROM PUZZLE_SIZES WHERE GRID_SIZE=5), 
        (SELECT ID FROM DIFFICULTY_LEVELS WHERE NAME='Medium'), 
        'medium_5x5_1', 0,
        '[1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,0,19,21,22,23,24,20]',
        '[1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,0]',
        SYSTIMESTAMP);

-- Easy 6x6
INSERT INTO PUZZLES (ID, PUZZLE_SIZE_ID, DIFFICULTY_ID, SEED, IS_DAILY, INITIAL_STATE, TARGET_STATE, CREATED_AT)
VALUES (SEQ_PUZZLES.NEXTVAL, 
        (SELECT ID FROM PUZZLE_SIZES WHERE GRID_SIZE=6), 
        (SELECT ID FROM DIFFICULTY_LEVELS WHERE NAME='Easy'), 
        'easy_6x6_1', 0,
        '[1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26,27,28,29,30,31,32,33,34,35,0]',
        '[1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26,27,28,29,30,31,32,33,34,35,0]',
        SYSTIMESTAMP);

COMMIT;

CREATE OR REPLACE PROCEDURE GENERATE_PUZZLES_VARIOUS_SIZES AS
    V_SEED VARCHAR2(100);
    V_INITIAL CLOB;
    V_TARGET CLOB;
    V_SIZE_ID NUMBER;
    V_DIFF_ID NUMBER;
    V_GRID_SIZE NUMBER;
BEGIN
    -- Генерируем пазлы для разных размеров
    FOR size_rec IN (SELECT ID, GRID_SIZE FROM PUZZLE_SIZES WHERE GRID_SIZE IN (5, 6)) LOOP
        FOR diff_rec IN (SELECT ID FROM DIFFICULTY_LEVELS) LOOP
            FOR i IN 1..3 LOOP -- по 3 пазла каждого размера и сложности
                V_GRID_SIZE := size_rec.GRID_SIZE;
                V_SEED := 'generated_' || size_rec.GRID_SIZE || 'x' || size_rec.GRID_SIZE || '_' || i || '_' || TO_CHAR(SYSTIMESTAMP, 'YYYYMMDDHH24MISS');
                
                -- Генерируем начальное состояние
                V_INITIAL := SLIDING_PUZZLE_UTILS.GENERATE_PUZZLE(
                    V_GRID_SIZE,
                    CASE diff_rec.ID 
                        WHEN 1 THEN 50   -- Easy
                        WHEN 2 THEN 200  -- Medium
                        WHEN 3 THEN 500  -- Hard для больших размеров уменьшим
                    END,
                    V_SEED
                );
                
                -- Целевое состояние (решенное)
                DECLARE
                    V_TEMP CLOB := '[';
                BEGIN
                    FOR j IN 1..(V_GRID_SIZE*V_GRID_SIZE-1) LOOP
                        IF j > 1 THEN
                            V_TEMP := V_TEMP || ',';
                        END IF;
                        V_TEMP := V_TEMP || j;
                    END LOOP;
                    V_TEMP := V_TEMP || ',0]';
                    V_TARGET := V_TEMP;
                END;
                
                -- Вставляем пазл
                INSERT INTO PUZZLES (
                    ID, PUZZLE_SIZE_ID, DIFFICULTY_ID, SEED, 
                    IS_DAILY, INITIAL_STATE, TARGET_STATE, CREATED_AT
                ) VALUES (
                    SEQ_PUZZLES.NEXTVAL, 
                    size_rec.ID,
                    diff_rec.ID,
                    V_SEED,
                    0,
                    V_INITIAL,
                    V_TARGET,
                    SYSTIMESTAMP
                );
            END LOOP;
        END LOOP;
    END LOOP;
    
    COMMIT;
    DBMS_OUTPUT.PUT_LINE('Пазлы различных размеров успешно сгенерированы');
END GENERATE_PUZZLES_VARIOUS_SIZES;
/

-- Вызвать процедуру для генерации
EXEC GENERATE_PUZZLES_VARIOUS_SIZES;


SELECT * FROM PUZZLE_SIZES ORDER BY GRID_SIZE;

SELECT P.ID, PS.GRID_SIZE, DL.NAME AS DIFFICULTY, P.SEED
FROM PUZZLES P
JOIN PUZZLE_SIZES PS ON P.PUZZLE_SIZE_ID = PS.ID
JOIN DIFFICULTY_LEVELS DL ON P.DIFFICULTY_ID = DL.ID
WHERE PS.GRID_SIZE IN (5, 6)
ORDER BY PS.GRID_SIZE, DL.ID;