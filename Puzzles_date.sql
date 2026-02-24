-- ================================================================
-- SLIDING PUZZLE -- тестовые пазлы для каталога
-- ================================================================
-- Формат состояния: JSON-массив массивов
-- 0 = пустая клетка
-- Целевое состояние 3x3: [[1,2,3],[4,5,6],[7,8,0]]
-- Целевое состояние 4x4: [[1,2,3,4],[5,6,7,8],[9,10,11,12],[13,14,15,0]]
-- ================================================================

SELECT * FROM users;

SELECT * FROM game_sessions;
-- ================================================================
-- 3x3, Easy (PUZZLE_SIZE_ID=1, DIFFICULTY_ID=1)
-- ================================================================

INSERT INTO PUZZLES (ID, PUZZLE_SIZE_ID, DIFFICULTY_ID, SEED, IS_DAILY, INITIAL_STATE, TARGET_STATE, CREATED_AT)
VALUES (
    SEQ_PUZZLES.NEXTVAL, 1, 1, 'easy-3x3-001', 0,
    '[[1,2,3],[4,0,6],[7,5,8]]',
    '[[1,2,3],[4,5,6],[7,8,0]]',
    SYSTIMESTAMP
);

INSERT INTO PUZZLES (ID, PUZZLE_SIZE_ID, DIFFICULTY_ID, SEED, IS_DAILY, INITIAL_STATE, TARGET_STATE, CREATED_AT)
VALUES (
    SEQ_PUZZLES.NEXTVAL, 1, 1, 'easy-3x3-002', 0,
    '[[1,2,3],[4,5,0],[7,8,6]]',
    '[[1,2,3],[4,5,6],[7,8,0]]',
    SYSTIMESTAMP
);

INSERT INTO PUZZLES (ID, PUZZLE_SIZE_ID, DIFFICULTY_ID, SEED, IS_DAILY, INITIAL_STATE, TARGET_STATE, CREATED_AT)
VALUES (
    SEQ_PUZZLES.NEXTVAL, 1, 1, 'easy-3x3-003', 1,
    '[[1,2,3],[0,4,6],[7,5,8]]',
    '[[1,2,3],[4,5,6],[7,8,0]]',
    SYSTIMESTAMP
);


-- ================================================================
-- 3x3, Medium (PUZZLE_SIZE_ID=1, DIFFICULTY_ID=2)
-- ================================================================

INSERT INTO PUZZLES (ID, PUZZLE_SIZE_ID, DIFFICULTY_ID, SEED, IS_DAILY, INITIAL_STATE, TARGET_STATE, CREATED_AT)
VALUES (
    SEQ_PUZZLES.NEXTVAL, 1, 2, 'medium-3x3-001', 0,
    '[[4,1,3],[7,2,6],[5,8,0]]',
    '[[1,2,3],[4,5,6],[7,8,0]]',
    SYSTIMESTAMP
);

INSERT INTO PUZZLES (ID, PUZZLE_SIZE_ID, DIFFICULTY_ID, SEED, IS_DAILY, INITIAL_STATE, TARGET_STATE, CREATED_AT)
VALUES (
    SEQ_PUZZLES.NEXTVAL, 1, 2, 'medium-3x3-002', 0,
    '[[2,8,3],[1,6,4],[7,0,5]]',
    '[[1,2,3],[4,5,6],[7,8,0]]',
    SYSTIMESTAMP
);


-- ================================================================
-- 3x3, Hard (PUZZLE_SIZE_ID=1, DIFFICULTY_ID=3)
-- ================================================================

INSERT INTO PUZZLES (ID, PUZZLE_SIZE_ID, DIFFICULTY_ID, SEED, IS_DAILY, INITIAL_STATE, TARGET_STATE, CREATED_AT)
VALUES (
    SEQ_PUZZLES.NEXTVAL, 1, 3, 'hard-3x3-001', 0,
    '[[8,6,7],[2,5,4],[3,0,1]]',
    '[[1,2,3],[4,5,6],[7,8,0]]',
    SYSTIMESTAMP
);

INSERT INTO PUZZLES (ID, PUZZLE_SIZE_ID, DIFFICULTY_ID, SEED, IS_DAILY, INITIAL_STATE, TARGET_STATE, CREATED_AT)
VALUES (
    SEQ_PUZZLES.NEXTVAL, 1, 3, 'hard-3x3-002', 0,
    '[[6,4,7],[8,5,0],[3,2,1]]',
    '[[1,2,3],[4,5,6],[7,8,0]]',
    SYSTIMESTAMP
);


-- ================================================================
-- 4x4, Easy (PUZZLE_SIZE_ID=2, DIFFICULTY_ID=1)
-- ================================================================

INSERT INTO PUZZLES (ID, PUZZLE_SIZE_ID, DIFFICULTY_ID, SEED, IS_DAILY, INITIAL_STATE, TARGET_STATE, CREATED_AT)
VALUES (
    SEQ_PUZZLES.NEXTVAL, 2, 1, 'easy-4x4-001', 0,
    '[[1,2,3,4],[5,6,7,8],[9,10,11,12],[13,14,0,15]]',
    '[[1,2,3,4],[5,6,7,8],[9,10,11,12],[13,14,15,0]]',
    SYSTIMESTAMP
);

INSERT INTO PUZZLES (ID, PUZZLE_SIZE_ID, DIFFICULTY_ID, SEED, IS_DAILY, INITIAL_STATE, TARGET_STATE, CREATED_AT)
VALUES (
    SEQ_PUZZLES.NEXTVAL, 2, 1, 'easy-4x4-002', 0,
    '[[1,2,3,4],[5,6,7,8],[9,10,11,0],[13,14,15,12]]',
    '[[1,2,3,4],[5,6,7,8],[9,10,11,12],[13,14,15,0]]',
    SYSTIMESTAMP
);


-- ================================================================
-- 4x4, Medium (PUZZLE_SIZE_ID=2, DIFFICULTY_ID=2)
-- ================================================================

INSERT INTO PUZZLES (ID, PUZZLE_SIZE_ID, DIFFICULTY_ID, SEED, IS_DAILY, INITIAL_STATE, TARGET_STATE, CREATED_AT)
VALUES (
    SEQ_PUZZLES.NEXTVAL, 2, 2, 'medium-4x4-001', 0,
    '[[1,2,3,4],[5,6,0,8],[9,10,7,12],[13,14,11,15]]',
    '[[1,2,3,4],[5,6,7,8],[9,10,11,12],[13,14,15,0]]',
    SYSTIMESTAMP
);


COMMIT;

-- Проверка
SELECT P.ID, P.SEED, PS.GRID_SIZE, DL.NAME AS DIFFICULTY, P.IS_DAILY
FROM PUZZLES P
JOIN PUZZLE_SIZES PS ON P.PUZZLE_SIZE_ID = PS.ID
JOIN DIFFICULTY_LEVELS DL ON P.DIFFICULTY_ID = DL.ID
ORDER BY DL.ID, PS.GRID_SIZE;