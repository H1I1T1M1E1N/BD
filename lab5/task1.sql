WITH VacancyResponses AS (
    -- Связываем вакансии, все их версии (включая устаревшие/архивные) и отклики
    SELECT
        v.vacancy_id,                    -- Идентификатор вакансии
        v.position_name,                 -- Название должности
        c.name AS company_name,          -- Название компании
        r.response_id,                   -- Идентификатор отклика
        r.applicant_id,                  -- Идентификатор соискателя
        r.created_at AS response_created_at -- Дата и время получения отклика
    FROM vacancy v
    JOIN vacancy_version vv ON v.vacancy_id = vv.vacancy_id          -- Все версии вакансии (включая архивные)
    JOIN response r ON vv.vacancy_version_id = r.vacancy_version_id  -- Отклики на конкретную версию
    JOIN company c ON v.company_id = c.company_id                    -- Компания-работодатель
),
ResponseStages AS (
    -- Анализируем историю этапов для каждого отклика
    SELECT
        vr.vacancy_id,                   -- Идентификатор вакансии
        vr.response_id,                  -- Идентификатор отклика
        BOOL_OR(rs.stage_type = 'просмотрен') AS reached_view,       -- Достигнут ли этап "просмотрен"
        BOOL_OR(rs.stage_type = 'интервью') AS reached_interview,    -- Достигнут ли этап "интервью"
        BOOL_OR(rs.stage_type = 'предложение') AS reached_offer,     -- Достигнут ли этап "предложение"
        BOOL_OR(rs.stage_type = 'отказ') AS is_rejected,             -- Был ли отказ
        MIN(rs.date_from) FILTER (WHERE rs.stage_type = 'просмотрен') AS first_view_at -- Время первого просмотра
    FROM VacancyResponses vr
    LEFT JOIN response_stage rs ON vr.response_id = rs.response_id
    GROUP BY vr.vacancy_id, vr.response_id
),
VacancyMetrics AS (
    -- Считаем итоговые метрики по вакансиям
    SELECT
        vr.vacancy_id,                                                    -- Идентификатор вакансии
        COUNT(DISTINCT vr.response_id) AS total_responses,                -- Общее количество откликов
        COUNT(DISTINCT vr.applicant_id) AS unique_candidates,             -- Количество уникальных соискателей
        COUNT(DISTINCT vr.response_id) FILTER (WHERE rs.reached_view) AS reached_view,           -- Достигли просмотра
        COUNT(DISTINCT vr.response_id) FILTER (WHERE rs.reached_interview) AS reached_interview, -- Достигли интервью
        COUNT(DISTINCT vr.response_id) FILTER (WHERE rs.reached_offer) AS reached_offer,         -- Достигли предложения
        COUNT(DISTINCT vr.response_id) FILTER (WHERE rs.is_rejected) AS total_rejections,        -- Количество отказов
        COUNT(DISTINCT i.interview_id) AS total_interviews,               -- Количество проведённых интервью
        COUNT(DISTINCT jo.offer_id) FILTER (WHERE jo.status = 'принято') AS accepted_offers,     -- Принятые предложения
        AVG(rs.first_view_at - vr.response_created_at) FILTER (WHERE rs.first_view_at IS NOT NULL) AS avg_time_to_view -- Среднее время до первого просмотра
    FROM VacancyResponses vr
    LEFT JOIN ResponseStages rs ON vr.vacancy_id = rs.vacancy_id AND vr.response_id = rs.response_id
    LEFT JOIN interview i ON vr.response_id = i.response_id
    LEFT JOIN job_offer jo ON vr.response_id = jo.response_id
    GROUP BY vr.vacancy_id
)
SELECT
    vm.vacancy_id,                                                        -- Идентификатор вакансии
    v.position_name,                                                      -- Название должности
    vm.total_responses,                                                   -- Общее количество откликов
    vm.unique_candidates,                                                 -- Количество уникальных кандидатов
    -- Конверсия из отклика в просмотр (в процентах); NULL при отсутствии данных
    ROUND(vm.reached_view::NUMERIC / NULLIF(vm.total_responses, 0) * 100, 2) AS conv_response_to_view,
    -- Конверсия из просмотра в интервью
    ROUND(vm.reached_interview::NUMERIC / NULLIF(vm.reached_view, 0) * 100, 2) AS conv_view_to_interview,
    -- Конверсия из интервью в предложение
    ROUND(vm.reached_offer::NUMERIC / NULLIF(vm.reached_interview, 0) * 100, 2) AS conv_interview_to_offer,
    -- Конверсия из предложения в принятие
    ROUND(vm.accepted_offers::NUMERIC / NULLIF(vm.reached_offer, 0) * 100, 2) AS conv_offer_to_accept,
    -- Общая конверсия из отклика в принятое предложение
    ROUND(vm.accepted_offers::NUMERIC / NULLIF(vm.total_responses, 0) * 100, 2) AS overall_conv,
    vm.avg_time_to_view,                                                  -- Среднее время от отклика до первого просмотра
    vm.total_rejections,                                                  -- Количество отказов
    -- Процент отказов от общего количества откликов
    ROUND(vm.total_rejections::NUMERIC / NULLIF(vm.total_responses, 0) * 100, 2) AS rejection_rate
FROM VacancyMetrics vm
JOIN vacancy v ON vm.vacancy_id = v.vacancy_id
WHERE vm.total_responses >= 10 AND vm.total_interviews >= 3
ORDER BY overall_conv DESC NULLS LAST, vm.total_responses DESC;