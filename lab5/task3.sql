WITH MonthlyActivity AS (
    -- Базовая активность по месяцам
    SELECT
        r.applicant_id,                                                   -- Идентификатор соискателя
        DATE_TRUNC('month', r.created_at)::DATE AS resp_month,            -- Месяц отклика (начало месяца)
        COUNT(r.response_id) AS responses,                                -- Количество отправленных откликов
        COUNT(DISTINCT vv.vacancy_id) AS unique_vacancies,                -- Количество уникальных вакансий
        COUNT(DISTINCT i.interview_id) AS interviews,                     -- Количество приглашений на интервью
        COUNT(DISTINCT jo.offer_id) AS offers,                            -- Количество полученных предложений
        COUNT(DISTINCT rs.stage_id) FILTER (WHERE rs.stage_type = 'отказ') AS rejections -- Количество отказов
    FROM response r
    JOIN vacancy_version vv ON r.vacancy_version_id = vv.vacancy_version_id
    LEFT JOIN interview i ON r.response_id = i.response_id
    LEFT JOIN job_offer jo ON r.response_id = jo.response_id
    LEFT JOIN response_stage rs ON r.response_id = rs.response_id AND rs.stage_type = 'отказ'
    GROUP BY r.applicant_id, DATE_TRUNC('month', r.created_at)
),
MinMaxMonths AS (
    -- Первый и последний месяц активности соискателя
    SELECT applicant_id, MIN(resp_month) AS min_month, MAX(resp_month) AS max_month
    FROM MonthlyActivity GROUP BY applicant_id
),
Calendar AS (
    -- Генерируем непрерывный ряд месяцев для заполнения пропусков
    SELECT applicant_id, generate_series(min_month, max_month, '1 month')::DATE AS month_date
    FROM MinMaxMonths
),
FullActivity AS (
    SELECT
        c.applicant_id,                                                   -- Идентификатор соискателя
        c.month_date,                                                     -- Месяц
        COALESCE(ma.unique_vacancies, 0) AS unique_vacancies,             -- Уникальные вакансии (0 при пропуске)
        COALESCE(ma.interviews, 0) AS interviews,                         -- Интервью (0 при пропуске)
        COALESCE(ma.offers, 0) AS offers,                                 -- Предложения (0 при пропуске)
        COALESCE(ma.rejections, 0) AS rejections,                         -- Отказы (0 при пропуске)
        COALESCE(ma.responses, 0) AS responses                            -- Отклики (0 при пропуске)
    FROM Calendar c
    LEFT JOIN MonthlyActivity ma ON c.applicant_id = ma.applicant_id AND c.month_date = ma.resp_month
)
SELECT
    applicant_id,                                                         -- Идентификатор соискателя
    month_date,                                                           -- Месяц
    responses,                                                            -- Количество откликов
    unique_vacancies,                                                     -- Количество уникальных вакансий
    interviews,                                                           -- Количество интервью
    offers,                                                               -- Количество предложений
    rejections,                                                           -- Количество отказов
    LAG(responses, 1) OVER w AS prev_month_responses,                     -- Отклики за предыдущий месяц
    LAG(responses, 2) OVER w AS two_months_ago_responses,                 -- Отклики два месяца назад
    responses - LAG(responses, 1) OVER w AS change_vs_prev,               -- Изменение относительно предыдущего месяца
    ROUND(AVG(responses) OVER (ORDER BY month_date ROWS BETWEEN 3 PRECEDING AND 1 PRECEDING), 2) AS avg_3_prev, -- Среднее за 3 предыдущих месяца (без текущего)
    ROUND(AVG(responses) OVER (ORDER BY month_date ROWS BETWEEN 3 PRECEDING AND CURRENT ROW), 2) AS avg_curr_3_prev, -- Среднее за текущий и 3 предыдущих
    MAX(interviews) OVER (ORDER BY month_date ROWS BETWEEN 3 PRECEDING AND CURRENT ROW) AS max_interviews_4_months, -- Максимум интервью за 4 месяца
    SUM(responses) OVER (ORDER BY month_date ROWS UNBOUNDED PRECEDING) AS cum_responses,   -- Накопительно откликов
    SUM(offers) OVER (ORDER BY month_date ROWS UNBOUNDED PRECEDING) AS cum_offers,         -- Накопительно предложений
    ROUND(responses - AVG(responses) OVER (ORDER BY month_date ROWS BETWEEN 3 PRECEDING AND 1 PRECEDING), 2) AS deviation, -- Отклонение от среднего за 3 предыдущих
    CASE
        WHEN LAG(responses) OVER w IS NULL THEN 'начальный период'
        WHEN LAG(responses) OVER w > 0 AND responses >= LAG(responses) OVER w * 1.5 THEN 'резкий рост активности'
        WHEN LAG(responses) OVER w > 0 AND responses <= LAG(responses) OVER w * 0.5 THEN 'резкое снижение активности'
        WHEN responses > 0 AND offers > 0.2 * responses THEN 'высокая результативность'
        ELSE 'стабильная активность'
    END AS activity_category
FROM FullActivity
WINDOW w AS (PARTITION BY applicant_id ORDER BY month_date)
ORDER BY applicant_id, month_date;