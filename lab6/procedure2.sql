CREATE OR REPLACE PROCEDURE advance_response_stage(
    p_response_id   INTEGER,
    p_new_stage     VARCHAR(100),
    p_recruiter_id  INTEGER,
    p_deadline      TIMESTAMP
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_current_stage VARCHAR(100);
    v_status        VARCHAR(50);
    v_vacancy_id    INTEGER;
    v_allowed       INTEGER;
    v_authority_ok  INTEGER;
    v_open_stage    BIGINT;
BEGIN
    -- 1) Проверка отклика
    SELECT current_stage, status INTO v_current_stage, v_status
    FROM response WHERE response_id = p_response_id
    FOR UPDATE;  -- блокировка на время транзакции

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Отклик % не найден', p_response_id;
    END IF;

    IF v_status <> 'активен' THEN
        RAISE EXCEPTION 'Отклик % завершён, перевод невозможен', p_response_id;
    END IF;

    IF v_current_stage = p_new_stage THEN
        RAISE EXCEPTION 'Отклик % уже находится на этапе «%»', p_response_id, p_new_stage;
    END IF;

    -- 2) Допустимость перехода
    SELECT COUNT(*) INTO v_allowed
    FROM stage_transition
    WHERE from_stage = v_current_stage AND to_stage = p_new_stage;

    IF v_allowed = 0 THEN
        RAISE EXCEPTION 'Недопустимый переход этапа: % -> %', v_current_stage, p_new_stage;
    END IF;

    -- 3) Полномочия рекрутера на момент операции
    --    Получаем компанию/подразделение вакансии, к которой относится отклик
    SELECT v.company_id INTO v_vacancy_id
    FROM response r
    JOIN vacancy_version vv ON vv.vacancy_version_id = r.vacancy_version_id
    JOIN vacancy v           ON v.vacancy_id = vv.vacancy_id
    WHERE r.response_id = p_response_id;

    --    Проверяем наличие действующего полномочия у рекрутера
    --    (объект = 'вакансия:<id>' или 'компания:<id>' — упрощённо: любое действующее)
    SELECT COUNT(*) INTO v_authority_ok
    FROM recruiter_authority ra
    WHERE ra.recruiter_id = p_recruiter_id
      AND ra.status = 'действует'
      AND CURRENT_DATE BETWEEN ra.date_from AND COALESCE(ra.date_to, CURRENT_DATE)
      AND (
           ra.object = 'компания:' || v_vacancy_id
        OR ra.object = 'вакансия:'  || v_vacancy_id
      );

    IF v_authority_ok = 0 THEN
        RAISE EXCEPTION
          'У рекрутера % нет действующих полномочий для работы с вакансией компании %',
          p_recruiter_id, v_vacancy_id;
    END IF;

    -- 4) Закрываем предыдущий открытый этап (date_to IS NULL)
    UPDATE response_stage
       SET date_to = NOW(),
           result  = COALESCE(result, '') || ' [закрыт автоматически при переходе]'
     WHERE response_id = p_response_id
       AND date_to IS NULL;

    -- 5) Создаём новую запись истории
    INSERT INTO response_stage
        (response_id, recruiter_id, stage_type, date_from, date_to, result)
    VALUES
        (p_response_id, p_recruiter_id, p_new_stage, NOW(), p_deadline, NULL);

    -- 6) Обновляем текущее состояние отклика
    UPDATE response
       SET current_stage = p_new_stage,
           status = CASE WHEN p_new_stage IN ('отказ','предложение')
                         THEN 'завершён' ELSE status END
     WHERE response_id = p_response_id;

    -- Всё в одной транзакции процедуры — атомарно
END;
$$;