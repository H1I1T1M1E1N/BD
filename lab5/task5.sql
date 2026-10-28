WITH RecruiterResponses AS (
    -- Уникальные пары рекрутер–отклик (один отклик учитывается один раз)
    SELECT DISTINCT recruiter_id, response_id
    FROM response_stage
),
ResponseStageFlags AS (
    SELECT
        rs.response_id,                                                   -- Идентификатор отклика
        BOOL_OR(rs.stage_type IN ('приглашен', 'интервью')) AS reached_interview, -- Дошёл до интервью
        BOOL_OR(rs.stage_type = 'предложение') AS reached_offer           -- Дошёл до предложения
    FROM response_stage rs
    GROUP BY rs.response_id
),
ResponseFirstView AS (
    -- Время от получения отклика до первого просмотра (в секундах)
    SELECT
        rs.response_id,                                                   -- Идентификатор отклика
        EXTRACT(EPOCH FROM (MIN(rs.date_from) - r.created_at)) AS first_view_delay -- Задержка до первого просмотра
    FROM response_stage rs
    JOIN response r ON rs.response_id = r.response_id
    WHERE rs.stage_type = 'просмотрен'
    GROUP BY rs.response_id, r.created_at
),
RecruiterResponseMetrics AS (
    -- Показатели рекрутера по откликам
    SELECT
        rr.recruiter_id,                                                  -- Идентификатор рекрутера
        COUNT(DISTINCT rr.response_id) AS processed_responses,            -- Уникальные обработанные отклики
        COUNT(DISTINCT rr.response_id) FILTER (WHERE rs.stage_type = 'просмотрен') AS viewed_responses, -- Просмотренные
        COUNT(DISTINCT rr.response_id) FILTER (WHERE rs.stage_type = 'отказ') AS rejected_responses,    -- Отказы
        COUNT(rs.stage_id) FILTER (WHERE rs.date_to < CURRENT_TIMESTAMP AND rs.date_to IS NOT NULL) AS overdue_stages, -- Просроченные этапы
        COUNT(rs.stage_id) AS total_stages,                               -- Всего этапов
        AVG(rfv.first_view_delay) AS avg_time_to_view,                    -- Среднее время до первого просмотра
        COUNT(DISTINCT rr.response_id) FILTER (WHERE rsf.reached_interview) AS reached_interview, -- Дошли до интервью
        COUNT(DISTINCT rr.response_id) FILTER (WHERE rsf.reached_offer) AS reached_offer          -- Дошли до предложения
    FROM RecruiterResponses rr
    LEFT JOIN response_stage rs ON rr.response_id = rs.response_id AND rr.recruiter_id = rs.recruiter_id
    LEFT JOIN ResponseStageFlags rsf ON rr.response_id = rsf.response_id
    LEFT JOIN ResponseFirstView rfv ON rr.response_id = rfv.response_id
    GROUP BY rr.recruiter_id
),
RecruiterInterviewMetrics AS (
    -- Показатели рекрутера по интервью (повторные интервью — отдельные события)
    SELECT
        ip.recruiter_id,
        COUNT(DISTINCT i.interview_id) AS conducted_interviews,
        COUNT(DISTINCT i.interview_id) FILTER (WHERE i.status = 'отменено') AS cancelled_interviews,
        COUNT(DISTINCT i.interview_id) FILTER (WHERE i.result = 'положительный') AS positive_interviews,
        AVG(EXTRACT(EPOCH FROM (i.end_at - i.start_at))) AS avg_interview_duration
    FROM interview_participant ip
    JOIN interview i ON ip.interview_id = i.interview_id
    GROUP BY ip.recruiter_id
),
RecruiterOfferMetrics AS (
    -- Показатели рекрутера по предложениям
    SELECT
        rr.recruiter_id,                                                  -- Идентификатор рекрутера
        COUNT(DISTINCT jo.offer_id) AS sent_offers,                       -- Отправленные предложения
        COUNT(DISTINCT jo.offer_id) FILTER (WHERE jo.status = 'принято') AS accepted_offers,  -- Принятые
        COUNT(DISTINCT jo.offer_id) FILTER (WHERE jo.status = 'отклонено') AS rejected_offers, -- Отклонённые
        AVG(EXTRACT(EPOCH FROM (jo.offer_date::TIMESTAMP - r.created_at))) AS avg_time_to_offer -- Среднее время от отклика до предложения
    FROM RecruiterResponses rr
    JOIN response r ON rr.response_id = r.response_id
    LEFT JOIN job_offer jo ON rr.response_id = jo.response_id
    GROUP BY rr.recruiter_id
),
FinalMetrics AS (
    -- Сводные показатели рекрутера с конверсиями
    SELECT
        rrm.recruiter_id,                                                 -- Идентификатор рекрутера
        rec.full_name,                                                    -- ФИО рекрутера
        d.department_id,                                                  -- Идентификатор подразделения
        d.name AS department_name,                                        -- Название подразделения
        c.company_id,                                                     -- Идентификатор компании
        c.name AS company_name,                                           -- Название компании
        rrm.processed_responses,                                          -- Обработанные отклики
        rrm.viewed_responses,                                             -- Просмотренные отклики
        rrm.rejected_responses,                                           -- Отказы
        ROUND(rrm.avg_time_to_view / 3600, 2) AS avg_hours_to_view,       -- Среднее время до просмотра (часы)
        rrm.overdue_stages,                                               -- Просроченные этапы
        rrm.total_stages,                                                 -- Всего этапов
        COALESCE(rim.conducted_interviews, 0) AS conducted_interviews,    -- Проведённые интервью
        COALESCE(rim.cancelled_interviews, 0) AS cancelled_interviews,    -- Отменённые интервью
        COALESCE(rim.positive_interviews, 0) AS positive_interviews,      -- Положительные интервью
        ROUND(rim.avg_interview_duration / 3600, 2) AS avg_interview_hours, -- Средняя продолжительность (часы)
        COALESCE(rom.sent_offers, 0) AS sent_offers,                      -- Отправленные предложения
        COALESCE(rom.accepted_offers, 0) AS accepted_offers,              -- Принятые предложения
        COALESCE(rom.rejected_offers, 0) AS rejected_offers,              -- Отклонённые предложения
        ROUND(rom.avg_time_to_offer / 3600, 2) AS avg_hours_to_offer,     -- Среднее время до предложения (часы)
        rrm.reached_interview,                                            -- Дошли до интервью
        rrm.reached_offer,                                                -- Дошли до предложения
        -- Конверсия из обработанных откликов в интервью
        ROUND(rrm.reached_interview::NUMERIC / NULLIF(rrm.processed_responses, 0) * 100, 2) AS interview_conversion,
        -- Конверсия из интервью в предложение
        ROUND(rrm.reached_offer::NUMERIC / NULLIF(rrm.reached_interview, 0) * 100, 2) AS offer_conversion,
        -- Процент принятия предложений (от окончательно решённых)
        ROUND(rom.accepted_offers::NUMERIC / NULLIF(rom.accepted_offers + rom.rejected_offers, 0) * 100, 2) AS acceptance_rate,
        -- Доля просроченных этапов
        ROUND(rrm.overdue_stages::NUMERIC / NULLIF(rrm.total_stages, 0) * 100, 2) AS overdue_rate
    FROM RecruiterResponseMetrics rrm
    JOIN recruiter rec ON rrm.recruiter_id = rec.recruiter_id
    JOIN department d ON rec.department_id = d.department_id
    JOIN company c ON d.company_id = c.company_id
    LEFT JOIN RecruiterInterviewMetrics rim ON rrm.recruiter_id = rim.recruiter_id
    LEFT JOIN RecruiterOfferMetrics rom ON rrm.recruiter_id = rom.recruiter_id
)
SELECT
    company_name,                                                         -- Компания
    department_name,                                                      -- Подразделение
    full_name AS recruiter,                                               -- Рекрутер
    processed_responses,                                                  -- Обработанные отклики
    viewed_responses,                                                     -- Просмотренные отклики
    rejected_responses,                                                   -- Отказы
    avg_hours_to_view,                                                    -- Среднее время до просмотра (часы)
    overdue_stages,                                                       -- Просроченные этапы
    conducted_interviews,                                                 -- Проведённые интервью
    cancelled_interviews,                                                 -- Отменённые интервью
    positive_interviews,                                                  -- Положительные интервью
    avg_interview_hours,                                                  -- Средняя продолжительность интервью (часы)
    sent_offers,                                                          -- Отправленные предложения
    accepted_offers,                                                      -- Принятые предложения
    rejected_offers,                                                      -- Отклонённые предложения
    avg_hours_to_offer,                                                   -- Среднее время до предложения (часы)
    interview_conversion,                                                 -- Конверсия в интервью
    offer_conversion,                                                     -- Конверсия в предложение
    acceptance_rate,                                                      -- Процент принятия предложений
    overdue_rate,                                                         -- Доля просроченных этапов
    -- Непрерывный рейтинг внутри компании
    DENSE_RANK() OVER (
        PARTITION BY company_id
        ORDER BY accepted_offers DESC,
                 offer_conversion DESC,
                 overdue_rate ASC,
                 avg_hours_to_view ASC,
                 processed_responses DESC
    ) AS company_rank,
    -- Общий рейтинг по всем рекрутерам сервиса
    DENSE_RANK() OVER (
        ORDER BY accepted_offers DESC,
                 acceptance_rate DESC,
                 conducted_interviews DESC,
                 avg_hours_to_view ASC,
                 overdue_stages ASC
    ) AS overall_rank
FROM FinalMetrics
ORDER BY overall_rank;