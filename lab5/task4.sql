WITH VersionBaseMetrics AS (
    -- Базовые метрики по каждой версии
    SELECT
        v.vacancy_id,                                                     -- Идентификатор вакансии
        v.company_id,                                                     -- Идентификатор компании
        vv.vacancy_version_id,                                            -- Идентификатор версии вакансии
        vv.version_number,                                                -- Номер версии
        COUNT(vsr.skill_id) FILTER (WHERE vsr.is_mandatory) AS mandatory_count,   -- Количество обязательных навыков
        COUNT(vsr.skill_id) FILTER (WHERE NOT vsr.is_mandatory) AS optional_count, -- Количество необязательных навыков
        ROUND(AVG(vsr.required_level), 2) AS avg_level,                   -- Средний требуемый уровень
        COUNT(r.response_id) AS responses_count                           -- Количество полученных откликов
    FROM vacancy v
    JOIN vacancy_version vv ON v.vacancy_id = vv.vacancy_id
    LEFT JOIN vacancy_skill_requirement vsr ON vv.vacancy_version_id = vsr.vacancy_version_id
    LEFT JOIN response r ON vv.vacancy_version_id = r.vacancy_version_id
    GROUP BY v.vacancy_id, v.company_id, vv.vacancy_version_id, vv.version_number
),
SkillComparison AS (
    -- Сравнение наборов навыков между текущей и предыдущей версией (FULL OUTER JOIN)
    SELECT
        COALESCE(c.vacancy_id, p.vacancy_id) AS vacancy_id,               -- Идентификатор вакансии
        c.vacancy_version_id,                                             -- Идентификатор текущей версии
        c.version_number,                                                 -- Номер текущей версии
        COUNT(c.skill_id) FILTER (WHERE p.skill_id IS NULL) AS new_skills,                -- Новые навыки
        COUNT(p.skill_id) FILTER (WHERE c.skill_id IS NULL) AS removed_skills,            -- Удалённые навыки
        COUNT(c.skill_id) FILTER (WHERE p.skill_id IS NOT NULL AND c.required_level > p.required_level) AS increased_level, -- Повышенный уровень
        COUNT(c.skill_id) FILTER (WHERE p.skill_id IS NULL AND c.is_mandatory) AS new_mandatory,      -- Новые обязательные
        COUNT(p.skill_id) FILTER (WHERE c.skill_id IS NULL AND p.is_mandatory) AS removed_mandatory   -- Удалённые обязательные
    FROM (
        SELECT v.vacancy_id, vv.vacancy_version_id, vv.version_number, vsr.skill_id, vsr.required_level, vsr.is_mandatory
        FROM vacancy v JOIN vacancy_version vv ON v.vacancy_id = vv.vacancy_id
        LEFT JOIN vacancy_skill_requirement vsr ON vv.vacancy_version_id = vsr.vacancy_version_id
    ) c
    FULL OUTER JOIN (
        SELECT v.vacancy_id, vv.vacancy_version_id, vv.version_number, vsr.skill_id, vsr.required_level, vsr.is_mandatory
        FROM vacancy v JOIN vacancy_version vv ON v.vacancy_id = vv.vacancy_id
        LEFT JOIN vacancy_skill_requirement vsr ON vv.vacancy_version_id = vsr.vacancy_version_id
    ) p ON c.vacancy_id = p.vacancy_id AND c.version_number = p.version_number + 1 AND c.skill_id = p.skill_id
    GROUP BY COALESCE(c.vacancy_id, p.vacancy_id), c.vacancy_version_id, c.version_number
)
SELECT
    c.name AS company_name,                                               -- Название компании
    v.position_name,                                                      -- Название должности
    vb.version_number,                                                    -- Номер версии
    vb.mandatory_count,                                                   -- Обязательных навыков в версии
    vb.optional_count,                                                    -- Необязательных навыков в версии
    vb.avg_level,                                                         -- Средний уровень
    vb.responses_count,                                                   -- Откликов на версию
    LAG(vb.mandatory_count) OVER w AS prev_mandatory,                     -- Обязательных навыков в предыдущей версии
    sc.new_skills,                                                        -- Новых навыков
    sc.removed_skills,                                                    -- Удалённых навыков
    sc.increased_level,                                                   -- Навыков с повышенным уровнем
    vb.mandatory_count - LAG(vb.mandatory_count) OVER w AS change_mandatory, -- Изменение количества обязательных
    vb.responses_count - LAG(vb.responses_count) OVER w AS change_responses, -- Изменение количества откликов
    ROUND(AVG(vb.responses_count) OVER (ORDER BY vb.version_number ROWS BETWEEN 2 PRECEDING AND CURRENT ROW), 2) AS avg_3_versions_responses, -- Среднее откликов по текущей и двум предыдущим
    SUM(vb.responses_count) OVER (ORDER BY vb.version_number ROWS UNBOUNDED PRECEDING) AS cum_responses, -- Накопительно откликов по версиям
    CASE
        WHEN LAG(vb.mandatory_count) OVER w IS NULL THEN 'первая версия'
        WHEN sc.new_mandatory >= 3 THEN 'ужесточение требований'
        WHEN sc.removed_mandatory >= 3 THEN 'смягчение требований'
        WHEN LAG(vb.responses_count) OVER w > 0 AND vb.responses_count <= LAG(vb.responses_count) OVER w * 0.7 THEN 'снижение интереса'
        WHEN LAG(vb.responses_count) OVER w > 0 AND vb.responses_count >= LAG(vb.responses_count) OVER w * 1.3 THEN 'рост интереса'
        ELSE 'незначительные изменения'
    END AS requirement_change_category
FROM VersionBaseMetrics vb
JOIN vacancy v ON vb.vacancy_id = v.vacancy_id
JOIN company c ON v.company_id = c.company_id
LEFT JOIN SkillComparison sc ON vb.vacancy_version_id = sc.vacancy_version_id
WINDOW w AS (PARTITION BY vb.vacancy_id ORDER BY vb.version_number)
ORDER BY c.name, v.position_name, vb.version_number;