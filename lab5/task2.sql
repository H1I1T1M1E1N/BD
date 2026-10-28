WITH StageStats AS (
    SELECT
        r.response_id,                                                    -- Идентификатор отклика
        r.vacancy_version_id,                                             -- Идентификатор версии вакансии
        r.applicant_id,                                                   -- Идентификатор соискателя
        r.current_stage,                                                  -- Текущий этап отклика
        r.created_at,                                                     -- Дата получения отклика
        COUNT(rs.stage_id) AS total_stages,                               -- Количество зарегистрированных этапов
        MIN(rs.date_from) AS first_transition,                            -- Время первого перехода
        MAX(COALESCE(rs.date_to, rs.date_from)) AS last_transition,       -- Время последнего перехода
        -- Просроченные этапы: срок истёк, но результат не зафиксирован
        COUNT(rs.stage_id) FILTER (WHERE rs.date_to < CURRENT_TIMESTAMP AND rs.date_to IS NOT NULL AND rs.result IS NULL) AS overdue_count,
        -- Этапы без ответственного рекрутера
        COUNT(rs.stage_id) FILTER (WHERE rs.recruiter_id IS NULL) AS no_recruiter_count,
        -- Некорректный интервал: завершение раньше начала
        COUNT(rs.stage_id) FILTER (WHERE rs.date_to < rs.date_from) AS invalid_interval_count
    FROM response r
    JOIN response_stage rs ON r.response_id = rs.response_id
    GROUP BY r.response_id, r.vacancy_version_id, r.applicant_id, r.current_stage, r.created_at
),
ActiveStages AS (
    -- Анализ незавершенных этапов
    SELECT
        response_id,
        COUNT(*) AS active_count,
        MAX(recruiter_id) FILTER (WHERE date_to IS NULL) AS active_recruiter_id
    FROM response_stage
    WHERE date_to IS NULL
    GROUP BY response_id
)
SELECT
    ss.response_id,                                                       -- Идентификатор отклика
    vv.vacancy_id,                                                        -- Идентификатор вакансии
    ss.applicant_id,                                                      -- Идентификатор кандидата
    ss.current_stage,                                                     -- Текущий этап
    -- Ответственный рекрутер: активный этап, иначе последний известный
    COALESCE(act.active_recruiter_id, (SELECT MAX(recruiter_id) FROM response_stage WHERE response_id = ss.response_id)) AS responsible_recruiter,
    -- Общее количество нарушений (просрочки + без рекрутера + некорректный интервал + несколько активных)
    (ss.overdue_count + ss.no_recruiter_count + ss.invalid_interval_count + CASE WHEN act.active_count > 1 THEN 1 ELSE 0 END) AS total_violations,
    CASE
        WHEN ss.overdue_count > 0 THEN 'превышен срок обработки'
        WHEN ss.no_recruiter_count > 0 OR (act.active_count > 0 AND act.active_recruiter_id IS NULL) THEN 'не назначен ответственный'
        WHEN act.active_count > 1 THEN 'несколько активных этапов'
        WHEN ss.invalid_interval_count > 0 THEN 'некорректный временной интервал'
        ELSE 'прочая проблема'
    END AS main_problem_type
FROM StageStats ss
JOIN vacancy_version vv ON ss.vacancy_version_id = vv.vacancy_version_id
LEFT JOIN ActiveStages act ON ss.response_id = act.response_id
WHERE (ss.overdue_count + ss.no_recruiter_count + ss.invalid_interval_count + CASE WHEN act.active_count > 1 THEN 1 ELSE 0 END) > 0
ORDER BY total_violations DESC, ss.created_at ASC;