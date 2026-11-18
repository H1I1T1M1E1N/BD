-- Триггер 1: должен упасть, если есть отклик на версию
UPDATE vacancy_version SET change_reason = 'test'
WHERE vacancy_version_id = (SELECT vacancy_version_id FROM response LIMIT 1);
-- ERROR: Нельзя изменить версию вакансии А: на неё ссылается N отклик(ов)

-- Триггер 2: пересечение по переговорной
INSERT INTO interview (response_id, applicant_id, start_at, end_at, format, status, room_id)
VALUES (1, 1, NOW(), NOW() + INTERVAL '1 hour', 'офлайн', 'запланировано', 1);
-- Повторная вставка в тот же интервал в ту же комнату -> ERROR с номером конфликтующего интервью