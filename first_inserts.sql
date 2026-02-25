-- ================================================================
-- ОБНОВЛЕННЫЙ ФАЙЛ first_inserts.sql (без удаления записей)
-- ================================================================

-- ================================================================
-- 1. GAME_STATUSES (проверяем и добавляем если нет)
-- ================================================================

MERGE INTO GAME_STATUSES USING DUAL ON (NAME = 'active')
WHEN NOT MATCHED THEN INSERT (ID, NAME) VALUES (SEQ_GAME_STATUSES.NEXTVAL, 'active');

MERGE INTO GAME_STATUSES USING DUAL ON (NAME = 'solved')
WHEN NOT MATCHED THEN INSERT (ID, NAME) VALUES (SEQ_GAME_STATUSES.NEXTVAL, 'solved');

MERGE INTO GAME_STATUSES USING DUAL ON (NAME = 'abandoned')
WHEN NOT MATCHED THEN INSERT (ID, NAME) VALUES (SEQ_GAME_STATUSES.NEXTVAL, 'abandoned');

MERGE INTO GAME_STATUSES USING DUAL ON (NAME = 'timeout')
WHEN NOT MATCHED THEN INSERT (ID, NAME) VALUES (SEQ_GAME_STATUSES.NEXTVAL, 'timeout');

MERGE INTO GAME_STATUSES USING DUAL ON (NAME = 'exported')
WHEN NOT MATCHED THEN INSERT (ID, NAME) VALUES (SEQ_GAME_STATUSES.NEXTVAL, 'exported');

-- ================================================================
-- 2. ACTION_TYPES (проверяем и добавляем если нет)
-- ================================================================

MERGE INTO ACTION_TYPES USING DUAL ON (NAME = 'move')
WHEN NOT MATCHED THEN INSERT (ID, NAME) VALUES (SEQ_ACTION_TYPES.NEXTVAL, 'move');

MERGE INTO ACTION_TYPES USING DUAL ON (NAME = 'undo')
WHEN NOT MATCHED THEN INSERT (ID, NAME) VALUES (SEQ_ACTION_TYPES.NEXTVAL, 'undo');

MERGE INTO ACTION_TYPES USING DUAL ON (NAME = 'redo')
WHEN NOT MATCHED THEN INSERT (ID, NAME) VALUES (SEQ_ACTION_TYPES.NEXTVAL, 'redo');

MERGE INTO ACTION_TYPES USING DUAL ON (NAME = 'restart')
WHEN NOT MATCHED THEN INSERT (ID, NAME) VALUES (SEQ_ACTION_TYPES.NEXTVAL, 'restart');

MERGE INTO ACTION_TYPES USING DUAL ON (NAME = 'hint')
WHEN NOT MATCHED THEN INSERT (ID, NAME) VALUES (SEQ_ACTION_TYPES.NEXTVAL, 'hint');

MERGE INTO ACTION_TYPES USING DUAL ON (NAME = 'import')
WHEN NOT MATCHED THEN INSERT (ID, NAME) VALUES (SEQ_ACTION_TYPES.NEXTVAL, 'import');

-- ================================================================
-- 3. DIFFICULTY_LEVELS (ОБНОВЛЯЕМ количество перемешиваний)
-- ================================================================

-- Обновляем существующие записи, не удаляя их
UPDATE DIFFICULTY_LEVELS SET SHUFFLE_MOVES = 10 WHERE NAME = 'Easy';
UPDATE DIFFICULTY_LEVELS SET SHUFFLE_MOVES = 20 WHERE NAME = 'Medium';
UPDATE DIFFICULTY_LEVELS SET SHUFFLE_MOVES = 30 WHERE NAME = 'Hard';

-- Если каких-то записей нет, добавляем
MERGE INTO DIFFICULTY_LEVELS USING DUAL ON (NAME = 'Easy')
WHEN NOT MATCHED THEN INSERT (ID, NAME, SHUFFLE_MOVES) VALUES (SEQ_DIFF_LEVELS.NEXTVAL, 'Easy', 10);

MERGE INTO DIFFICULTY_LEVELS USING DUAL ON (NAME = 'Medium')
WHEN NOT MATCHED THEN INSERT (ID, NAME, SHUFFLE_MOVES) VALUES (SEQ_DIFF_LEVELS.NEXTVAL, 'Medium', 20);

MERGE INTO DIFFICULTY_LEVELS USING DUAL ON (NAME = 'Hard')
WHEN NOT MATCHED THEN INSERT (ID, NAME, SHUFFLE_MOVES) VALUES (SEQ_DIFF_LEVELS.NEXTVAL, 'Hard', 30);

-- ================================================================
-- 4. PUZZLE_SIZES (ДОБАВЛЯЕМ недостающие размеры)
-- ================================================================

-- Добавляем размеры, если их нет
MERGE INTO PUZZLE_SIZES USING DUAL ON (GRID_SIZE = 3)
WHEN NOT MATCHED THEN INSERT (ID, GRID_SIZE, DEFAULT_TIME_LIMIT) VALUES (SEQ_PUZZLE_SIZES.NEXTVAL, 3, INTERVAL '8' MINUTE);

MERGE INTO PUZZLE_SIZES USING DUAL ON (GRID_SIZE = 4)
WHEN NOT MATCHED THEN INSERT (ID, GRID_SIZE, DEFAULT_TIME_LIMIT) VALUES (SEQ_PUZZLE_SIZES.NEXTVAL, 4, INTERVAL '10' MINUTE);






CREATE OR REPLACE PROCEDURE GENERATE_PUZZLES_VARIOUS_SIZES AS
    V_SEED VARCHAR2(100);
    V_INITIAL CLOB;
    V_TARGET CLOB;
    V_SIZE_ID NUMBER;
    V_DIFF_ID NUMBER;
    V_GRID_SIZE NUMBER;
BEGIN
    FOR size_rec IN (SELECT ID, GRID_SIZE FROM PUZZLE_SIZES WHERE GRID_SIZE IN (5, 6)) LOOP
        FOR diff_rec IN (SELECT ID FROM DIFFICULTY_LEVELS) LOOP
            FOR i IN 1..3 LOOP
                V_GRID_SIZE := size_rec.GRID_SIZE;
                V_SEED := 'generated_' || size_rec.GRID_SIZE || 'x' || size_rec.GRID_SIZE || '_' || i || '_' || TO_CHAR(SYSTIMESTAMP, 'YYYYMMDDHH24MISS');
                
                V_INITIAL := SLIDING_PUZZLE_UTILS.GENERATE_PUZZLE(
                    V_GRID_SIZE,
                    CASE diff_rec.ID 
                        WHEN (SELECT ID FROM DIFFICULTY_LEVELS WHERE NAME='Easy') THEN 10
                        WHEN (SELECT ID FROM DIFFICULTY_LEVELS WHERE NAME='Medium') THEN 20
                        WHEN (SELECT ID FROM DIFFICULTY_LEVELS WHERE NAME='Hard') THEN 30
                    END,
                    V_SEED
                );
                
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
END;
/

-- Запустить генерацию
EXEC GENERATE_PUZZLES_VARIOUS_SIZES;

MERGE INTO PUZZLE_SIZES USING DUAL ON (GRID_SIZE = 5)
WHEN NOT MATCHED THEN INSERT (ID, GRID_SIZE, DEFAULT_TIME_LIMIT) VALUES (SEQ_PUZZLE_SIZES.NEXTVAL, 5, INTERVAL '13' MINUTE);

MERGE INTO PUZZLE_SIZES USING DUAL ON (GRID_SIZE = 6)
WHEN NOT MATCHED THEN INSERT (ID, GRID_SIZE, DEFAULT_TIME_LIMIT) VALUES (SEQ_PUZZLE_SIZES.NEXTVAL, 6, INTERVAL '15' MINUTE);

MERGE INTO PUZZLE_SIZES USING DUAL ON (GRID_SIZE = 7)
WHEN NOT MATCHED THEN INSERT (ID, GRID_SIZE, DEFAULT_TIME_LIMIT) VALUES (SEQ_PUZZLE_SIZES.NEXTVAL, 7, INTERVAL '18' MINUTE);

COMMIT;

-- Проверка
SELECT 'DIFFICULTY_LEVELS' AS TABLE_NAME, ID, NAME, SHUFFLE_MOVES FROM DIFFICULTY_LEVELS ORDER BY ID;
SELECT 'PUZZLE_SIZES' AS TABLE_NAME, ID, GRID_SIZE, DEFAULT_TIME_LIMIT FROM PUZZLE_SIZES ORDER BY GRID_SIZE;