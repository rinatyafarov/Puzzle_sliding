-- ================================================================
-- SLIDING PUZZLE — тестовые пазлы для каталога
-- Hard теперь доступен для всех размеров поля (3×3 … 6×6)
-- Начальные состояния хранятся решёнными — перемешивание
-- выполняется в Python при каждом запуске игры.
-- ================================================================

-- ================================================================
-- 3×3  Easy  (PUZZLE_SIZE_ID=1, DIFFICULTY_ID=1)
-- ================================================================
INSERT INTO PUZZLES (ID, PUZZLE_SIZE_ID, DIFFICULTY_ID, SEED, IS_DAILY, INITIAL_STATE, TARGET_STATE, CREATED_AT)
VALUES (SEQ_PUZZLES.NEXTVAL, 1, 1, 'easy-3x3-001', 0,
        '[1,2,3,4,5,6,7,8,0]', '[1,2,3,4,5,6,7,8,0]', SYSTIMESTAMP);

INSERT INTO PUZZLES (ID, PUZZLE_SIZE_ID, DIFFICULTY_ID, SEED, IS_DAILY, INITIAL_STATE, TARGET_STATE, CREATED_AT)
VALUES (SEQ_PUZZLES.NEXTVAL, 1, 1, 'easy-3x3-002', 0,
        '[1,2,3,4,5,6,7,8,0]', '[1,2,3,4,5,6,7,8,0]', SYSTIMESTAMP);

INSERT INTO PUZZLES (ID, PUZZLE_SIZE_ID, DIFFICULTY_ID, SEED, IS_DAILY, INITIAL_STATE, TARGET_STATE, CREATED_AT)
VALUES (SEQ_PUZZLES.NEXTVAL, 1, 1, 'easy-3x3-daily', 1,
        '[1,2,3,4,5,6,7,8,0]', '[1,2,3,4,5,6,7,8,0]', SYSTIMESTAMP);

-- ================================================================
-- 3×3  Medium  (PUZZLE_SIZE_ID=1, DIFFICULTY_ID=2)
-- ================================================================
INSERT INTO PUZZLES (ID, PUZZLE_SIZE_ID, DIFFICULTY_ID, SEED, IS_DAILY, INITIAL_STATE, TARGET_STATE, CREATED_AT)
VALUES (SEQ_PUZZLES.NEXTVAL, 1, 2, 'medium-3x3-001', 0,
        '[1,2,3,4,5,6,7,8,0]', '[1,2,3,4,5,6,7,8,0]', SYSTIMESTAMP);

INSERT INTO PUZZLES (ID, PUZZLE_SIZE_ID, DIFFICULTY_ID, SEED, IS_DAILY, INITIAL_STATE, TARGET_STATE, CREATED_AT)
VALUES (SEQ_PUZZLES.NEXTVAL, 1, 2, 'medium-3x3-002', 0,
        '[1,2,3,4,5,6,7,8,0]', '[1,2,3,4,5,6,7,8,0]', SYSTIMESTAMP);

-- ================================================================
-- 3×3  Hard  (PUZZLE_SIZE_ID=1, DIFFICULTY_ID=3)
-- ================================================================
INSERT INTO PUZZLES (ID, PUZZLE_SIZE_ID, DIFFICULTY_ID, SEED, IS_DAILY, INITIAL_STATE, TARGET_STATE, CREATED_AT)
VALUES (SEQ_PUZZLES.NEXTVAL, 1, 3, 'hard-3x3-001', 0,
        '[1,2,3,4,5,6,7,8,0]', '[1,2,3,4,5,6,7,8,0]', SYSTIMESTAMP);

INSERT INTO PUZZLES (ID, PUZZLE_SIZE_ID, DIFFICULTY_ID, SEED, IS_DAILY, INITIAL_STATE, TARGET_STATE, CREATED_AT)
VALUES (SEQ_PUZZLES.NEXTVAL, 1, 3, 'hard-3x3-002', 0,
        '[1,2,3,4,5,6,7,8,0]', '[1,2,3,4,5,6,7,8,0]', SYSTIMESTAMP);

-- ================================================================
-- 4×4  Easy  (PUZZLE_SIZE_ID=2, DIFFICULTY_ID=1)
-- ================================================================
INSERT INTO PUZZLES (ID, PUZZLE_SIZE_ID, DIFFICULTY_ID, SEED, IS_DAILY, INITIAL_STATE, TARGET_STATE, CREATED_AT)
VALUES (SEQ_PUZZLES.NEXTVAL, 2, 1, 'easy-4x4-001', 0,
        '[1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,0]',
        '[1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,0]', SYSTIMESTAMP);

INSERT INTO PUZZLES (ID, PUZZLE_SIZE_ID, DIFFICULTY_ID, SEED, IS_DAILY, INITIAL_STATE, TARGET_STATE, CREATED_AT)
VALUES (SEQ_PUZZLES.NEXTVAL, 2, 1, 'easy-4x4-002', 0,
        '[1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,0]',
        '[1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,0]', SYSTIMESTAMP);

-- ================================================================
-- 4×4  Medium  (PUZZLE_SIZE_ID=2, DIFFICULTY_ID=2)
-- ================================================================
INSERT INTO PUZZLES (ID, PUZZLE_SIZE_ID, DIFFICULTY_ID, SEED, IS_DAILY, INITIAL_STATE, TARGET_STATE, CREATED_AT)
VALUES (SEQ_PUZZLES.NEXTVAL, 2, 2, 'medium-4x4-001', 0,
        '[1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,0]',
        '[1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,0]', SYSTIMESTAMP);

INSERT INTO PUZZLES (ID, PUZZLE_SIZE_ID, DIFFICULTY_ID, SEED, IS_DAILY, INITIAL_STATE, TARGET_STATE, CREATED_AT)
VALUES (SEQ_PUZZLES.NEXTVAL, 2, 2, 'medium-4x4-002', 0,
        '[1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,0]',
        '[1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,0]', SYSTIMESTAMP);

-- ================================================================
-- 4×4  Hard  (PUZZLE_SIZE_ID=2, DIFFICULTY_ID=3)  ← НОВОЕ
-- ================================================================
INSERT INTO PUZZLES (ID, PUZZLE_SIZE_ID, DIFFICULTY_ID, SEED, IS_DAILY, INITIAL_STATE, TARGET_STATE, CREATED_AT)
VALUES (SEQ_PUZZLES.NEXTVAL, 2, 3, 'hard-4x4-001', 0,
        '[1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,0]',
        '[1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,0]', SYSTIMESTAMP);

INSERT INTO PUZZLES (ID, PUZZLE_SIZE_ID, DIFFICULTY_ID, SEED, IS_DAILY, INITIAL_STATE, TARGET_STATE, CREATED_AT)
VALUES (SEQ_PUZZLES.NEXTVAL, 2, 3, 'hard-4x4-002', 0,
        '[1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,0]',
        '[1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,0]', SYSTIMESTAMP);

-- ================================================================
-- 5×5  Easy  (PUZZLE_SIZE_ID=3, DIFFICULTY_ID=1)
-- ================================================================
INSERT INTO PUZZLES (ID, PUZZLE_SIZE_ID, DIFFICULTY_ID, SEED, IS_DAILY, INITIAL_STATE, TARGET_STATE, CREATED_AT)
VALUES (SEQ_PUZZLES.NEXTVAL, 3, 1, 'easy-5x5-001', 0,
        '[1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,0]',
        '[1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,0]', SYSTIMESTAMP);

-- ================================================================
-- 5×5  Medium  (PUZZLE_SIZE_ID=3, DIFFICULTY_ID=2)
-- ================================================================
INSERT INTO PUZZLES (ID, PUZZLE_SIZE_ID, DIFFICULTY_ID, SEED, IS_DAILY, INITIAL_STATE, TARGET_STATE, CREATED_AT)
VALUES (SEQ_PUZZLES.NEXTVAL, 3, 2, 'medium-5x5-001', 0,
        '[1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,0]',
        '[1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,0]', SYSTIMESTAMP);

-- ================================================================
-- 5×5  Hard  (PUZZLE_SIZE_ID=3, DIFFICULTY_ID=3)  ← НОВОЕ
-- ================================================================
INSERT INTO PUZZLES (ID, PUZZLE_SIZE_ID, DIFFICULTY_ID, SEED, IS_DAILY, INITIAL_STATE, TARGET_STATE, CREATED_AT)
VALUES (SEQ_PUZZLES.NEXTVAL, 3, 3, 'hard-5x5-001', 0,
        '[1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,0]',
        '[1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,0]', SYSTIMESTAMP);

INSERT INTO PUZZLES (ID, PUZZLE_SIZE_ID, DIFFICULTY_ID, SEED, IS_DAILY, INITIAL_STATE, TARGET_STATE, CREATED_AT)
VALUES (SEQ_PUZZLES.NEXTVAL, 3, 3, 'hard-5x5-002', 0,
        '[1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,0]',
        '[1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,0]', SYSTIMESTAMP);

-- ================================================================
-- 6×6  Easy  (PUZZLE_SIZE_ID=4, DIFFICULTY_ID=1)
-- ================================================================
INSERT INTO PUZZLES (ID, PUZZLE_SIZE_ID, DIFFICULTY_ID, SEED, IS_DAILY, INITIAL_STATE, TARGET_STATE, CREATED_AT)
VALUES (SEQ_PUZZLES.NEXTVAL, 4, 1, 'easy-6x6-001', 0,
        '[1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26,27,28,29,30,31,32,33,34,35,0]',
        '[1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26,27,28,29,30,31,32,33,34,35,0]',
        SYSTIMESTAMP);

-- ================================================================
-- 6×6  Medium  (PUZZLE_SIZE_ID=4, DIFFICULTY_ID=2)
-- ================================================================
INSERT INTO PUZZLES (ID, PUZZLE_SIZE_ID, DIFFICULTY_ID, SEED, IS_DAILY, INITIAL_STATE, TARGET_STATE, CREATED_AT)
VALUES (SEQ_PUZZLES.NEXTVAL, 4, 2, 'medium-6x6-001', 0,
        '[1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26,27,28,29,30,31,32,33,34,35,0]',
        '[1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26,27,28,29,30,31,32,33,34,35,0]',
        SYSTIMESTAMP);

-- ================================================================
-- 6×6  Hard  (PUZZLE_SIZE_ID=4, DIFFICULTY_ID=3)  ← НОВОЕ
-- ================================================================
INSERT INTO PUZZLES (ID, PUZZLE_SIZE_ID, DIFFICULTY_ID, SEED, IS_DAILY, INITIAL_STATE, TARGET_STATE, CREATED_AT)
VALUES (SEQ_PUZZLES.NEXTVAL, 4, 3, 'hard-6x6-001', 0,
        '[1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26,27,28,29,30,31,32,33,34,35,0]',
        '[1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26,27,28,29,30,31,32,33,34,35,0]',
        SYSTIMESTAMP);

INSERT INTO PUZZLES (ID, PUZZLE_SIZE_ID, DIFFICULTY_ID, SEED, IS_DAILY, INITIAL_STATE, TARGET_STATE, CREATED_AT)
VALUES (SEQ_PUZZLES.NEXTVAL, 4, 3, 'hard-6x6-002', 0,
        '[1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26,27,28,29,30,31,32,33,34,35,0]',
        '[1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26,27,28,29,30,31,32,33,34,35,0]',
        SYSTIMESTAMP);

COMMIT;

-- ================================================================
-- Проверка
-- ================================================================
SELECT P.ID, PS.GRID_SIZE, DL.NAME AS DIFFICULTY, P.SEED, P.IS_DAILY
FROM PUZZLES P
JOIN PUZZLE_SIZES PS ON P.PUZZLE_SIZE_ID = PS.ID
JOIN DIFFICULTY_LEVELS DL ON P.DIFFICULTY_ID = DL.ID
ORDER BY PS.GRID_SIZE, DL.ID, P.SEED;