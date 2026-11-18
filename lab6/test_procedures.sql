-- Процедура 1 с получением id:
DO $$
DECLARE r BIGINT;
BEGIN
    CALL register_response(1, 10, 5, 3, r);
    RAISE NOTICE 'Создан отклик %', r;
END $$;

-- Процедура 2
CALL advance_response_stage(1, 'просмотрен', 3, NOW() + INTERVAL '2 days');