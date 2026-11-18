CREATE OR REPLACE PROCEDURE register_response(
    p_applicant_id  INTEGER,
    p_vacancy_id    INTEGER,
    p_resume_id     INTEGER,
    OUT o_response_id BIGINT
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_vacancy_version_id BIGINT;
    v_resume_version_id  BIGINT;
    v_vac_status         VARCHAR(50);
    v_resume_applicant   INTEGER;
    v_resume_status      VARCHAR(50);
    v_exists             INTEGER;
BEGIN
    -- 1) Проверка вакансии и её статуса
    SELECT publish_status INTO v_vac_status
    FROM vacancy WHERE vacancy_id = p_vacancy_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Вакансия % не найдена', p_vacancy_id;
    END IF;

    IF v_vac_status <> 'активна' THEN
        RAISE EXCEPTION 'Вакансия % не активна (статус: %)', p_vacancy_id, v_vac_status;
    END IF;

    -- 2) Проверка резюме и принадлежности соискателю
    SELECT applicant_id, status INTO v_resume_applicant, v_resume_status
    FROM resume WHERE resume_id = p_resume_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Резюме % не найдено', p_resume_id;
    END IF;

    IF v_resume_applicant <> p_applicant_id THEN
        RAISE EXCEPTION 'Резюме % не принадлежит соискателю %', p_resume_id, p_applicant_id;
    END IF;

    IF v_resume_status <> 'опубликовано' THEN
        RAISE EXCEPTION 'Резюме % не опубликовано (статус: %)', p_resume_id, v_resume_status;
    END IF;

    -- 3) Текущие версии
    SELECT vacancy_version_id INTO v_vacancy_version_id
    FROM vacancy_version
    WHERE vacancy_id = p_vacancy_id AND status = 'текущая'
    ORDER BY version_number DESC
    LIMIT 1;

    IF v_vacancy_version_id IS NULL THEN
        RAISE EXCEPTION 'У вакансии % нет действующей версии', p_vacancy_id;
    END IF;

    SELECT resume_version_id INTO v_resume_version_id
    FROM resume_version
    WHERE resume_id = p_resume_id AND status = 'текущая'
    ORDER BY version_number DESC
    LIMIT 1;

    IF v_resume_version_id IS NULL THEN
        RAISE EXCEPTION 'У резюме % нет действующей версии', p_resume_id;
    END IF;

    -- 4) Проверка дубликата активного отклика
    SELECT COUNT(*) INTO v_exists
    FROM response
    WHERE applicant_id = p_applicant_id
      AND vacancy_version_id = v_vacancy_version_id
      AND status = 'активен';

    IF v_exists > 0 THEN
        RAISE EXCEPTION
          'Активный отклик соискателя % на вакансию % уже существует',
          p_applicant_id, p_vacancy_id;
    END IF;

    -- 5) Создание отклика
    INSERT INTO response
        (applicant_id, resume_version_id, vacancy_version_id,
         created_at, current_stage, status)
    VALUES
        (p_applicant_id, v_resume_version_id, v_vacancy_version_id,
         NOW(), 'получен', 'активен')
    RETURNING response_id INTO o_response_id;

    -- 6) Первоначальный этап рассмотрения
    INSERT INTO response_stage
        (response_id, recruiter_id, stage_type, date_from, result)
    VALUES
        (o_response_id, NULL, 'получен', NOW(), 'Отклик зарегистрирован');
END;
$$;