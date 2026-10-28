-- E1. Компания
CREATE TABLE company (
    company_id      BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY, -- Идентификатор компании
    name            VARCHAR(255)    NOT NULL,                        -- Наименование компании
    requisites      VARCHAR(255)    NOT NULL UNIQUE,                 -- Реквизиты компании
    contacts        TEXT            NOT NULL,                        -- Контактные данные
    status          VARCHAR(50)     NOT NULL,                        -- Статус компании

    CONSTRAINT chk_company_status CHECK (status IN ('активна', 'не активна')) -- Проверка допустимых статусов
);

-- E2. Подразделение
CREATE TABLE department (
    department_id   BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY, -- Идентификатор подразделения
    company_id      INTEGER         NOT NULL,                        -- Идентификатор компании
    name            VARCHAR(255)    NOT NULL,                        -- Название подразделения
    parent_id       INTEGER,                                         -- Идентификатор родительского подразделения
    head_full_name  VARCHAR(255)    NOT NULL,                        -- ФИО руководителя подразделения
    status          VARCHAR(50)     NOT NULL,                        -- Статус подразделения

    CONSTRAINT fk_department_company
        FOREIGN KEY (company_id) REFERENCES company (company_id)
		ON DELETE RESTRICT,                                          -- Запрет удаления компании при наличии подразделений
    CONSTRAINT fk_department_parent
        FOREIGN KEY (parent_id) REFERENCES department (department_id)
		ON DELETE SET NULL,                                          -- При удалении родителя parent_id обнуляется
    CONSTRAINT chk_department_status CHECK (status IN ('активно', 'не активно')) -- Проверка допустимых статусов
);

-- E3. Рекрутер
CREATE TABLE recruiter (
    recruiter_id    BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY, -- Идентификатор рекрутера
    full_name       VARCHAR(255)    NOT NULL,                        -- ФИО рекрутера
    contacts        TEXT            NOT NULL,                        -- Контактные данные
    department_id   INTEGER         NOT NULL,                        -- Идентификатор подразделения
    status          VARCHAR(50)     NOT NULL,                        -- Статус рекрутера

    CONSTRAINT fk_recruiter_department
        FOREIGN KEY (department_id) REFERENCES department (department_id)
		ON DELETE RESTRICT,                                          -- Запрет удаления подразделения при наличии рекрутеров
    CONSTRAINT chk_recruiter_status CHECK (status IN ('активен', 'не активен')) -- Проверка допустимых статусов
);

-- E4. Полномочие рекрутера
CREATE TABLE recruiter_authority (
    authority_id    BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY, -- Идентификатор полномочия
    recruiter_id    INTEGER         NOT NULL,                        -- Идентификатор рекрутера
    object          VARCHAR(255)    NOT NULL,                        -- Объект, на который распространяется полномочие
    role            VARCHAR(100)    NOT NULL,                        -- Роль или набор прав
    date_from       DATE            NOT NULL DEFAULT CURRENT_DATE,   -- Дата начала действия полномочия
    date_to         DATE            DEFAULT (CURRENT_DATE + 30),     -- Дата окончания действия полномочия
    status          VARCHAR(50)     NOT NULL,                        -- Статус полномочия

    CONSTRAINT fk_authority_recruiter
        FOREIGN KEY (recruiter_id) REFERENCES recruiter (recruiter_id)
		ON DELETE RESTRICT,                                          -- Запрет удаления рекрутера при наличии полномочий
    CONSTRAINT chk_recruiter_authority_status
        CHECK (status IN ('действует', 'истекло', 'отозвано'))       -- Проверка допустимых статусов
);

-- E5. Вакансия
CREATE TABLE vacancy (
    vacancy_id      BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY, -- Идентификатор вакансии
    position_name   VARCHAR(255)    NOT NULL,                        -- Название должности
    company_id      INTEGER         NOT NULL,                        -- Идентификатор компании
    department_id   INTEGER,                                         -- Идентификатор подразделения
    conditions      TEXT            NOT NULL,                        -- Условия работы
    publish_status  VARCHAR(50)     NOT NULL,                        -- Статус публикации

    CONSTRAINT fk_vacancy_company
        FOREIGN KEY (company_id) REFERENCES company (company_id)
		ON DELETE RESTRICT,                                          -- Запрет удаления компании при наличии вакансий
    CONSTRAINT fk_vacancy_department
        FOREIGN KEY (department_id) REFERENCES department (department_id)
		ON DELETE SET NULL,                                          -- При удалении подразделения department_id обнуляется
    CONSTRAINT chk_vacancy_status CHECK (publish_status IN ('активна', 'закрыта')) -- Проверка допустимых статусов
);

-- E6. Версия вакансии
CREATE TABLE vacancy_version (
    vacancy_version_id  BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY, -- Идентификатор версии вакансии
    vacancy_id          INTEGER     NOT NULL,                             -- Идентификатор вакансии
    version_number      INTEGER     NOT NULL,                             -- Номер версии
    created_at          TIMESTAMP   NOT NULL DEFAULT NOW(),               -- Дата и время создания версии
    changed_by          VARCHAR(255) NOT NULL,                            -- Автор изменения
    change_reason       TEXT,                                             -- Основание изменения
    status              VARCHAR(50) NOT NULL,                             -- Статус версии

    CONSTRAINT uq_vacancy_version UNIQUE (vacancy_id, version_number),    -- Уникальность номера версии в рамках вакансии
    CONSTRAINT fk_vacancy_version_vacancy
        FOREIGN KEY (vacancy_id) REFERENCES vacancy (vacancy_id)
        ON DELETE RESTRICT,                                               -- Запрет удаления вакансии при наличии версий
    CONSTRAINT chk_vacancy_version_status
        CHECK (status IN ('текущая', 'устаревшая'))                       -- Проверка допустимых статусов
);

-- E7. Навык
CREATE TABLE skill (
    skill_id        BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY, -- Идентификатор навыка
    name            VARCHAR(255)    NOT NULL,                        -- Название навыка
    category        VARCHAR(100)    NOT NULL,                        -- Категория навыка
    description     TEXT                                             -- Описание навыка
);

-- E8. Требование навыка
CREATE TABLE vacancy_skill_requirement (
    vacancy_version_id  BIGINT      NOT NULL,      -- Идентификатор версии вакансии
    skill_id            BIGINT      NOT NULL,      -- Идентификатор навыка
    required_level      INTEGER     NOT NULL,      -- Требуемый уровень владения навыком
    is_mandatory        BOOLEAN     NOT NULL,      -- Обязательность навыка
    comment             TEXT,                      -- Комментарий

    PRIMARY KEY (vacancy_version_id, skill_id),    -- Составной первичный ключ
    CONSTRAINT fk_vsr_vacancy_version
        FOREIGN KEY (vacancy_version_id) REFERENCES vacancy_version (vacancy_version_id)
        ON DELETE CASCADE,                         -- При удалении версии вакансии требования удаляются
    CONSTRAINT fk_vsr_skill
        FOREIGN KEY (skill_id) REFERENCES skill (skill_id)
		ON DELETE RESTRICT                         -- Запрет удаления навыка при наличии требований
);

-- E9. Соискатель
CREATE TABLE applicant (
    applicant_id    BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY, -- Идентификатор соискателя
    full_name       VARCHAR(255)    NOT NULL,                        -- ФИО соискателя
    contacts        TEXT            NOT NULL,                        -- Контактные данные
    registered_at   TIMESTAMP       NOT NULL DEFAULT NOW(),          -- Дата и время регистрации
    status          VARCHAR(50)     NOT NULL,                        -- Статус соискателя

    CONSTRAINT chk_applicant_status CHECK (status IN ('активен', 'неактивен')) -- Проверка допустимых статусов
);

-- E10. Резюме
CREATE TABLE resume (
    resume_id       BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY, -- Идентификатор резюме
    applicant_id    INTEGER         NOT NULL,                        -- Идентификатор соискателя
    name            VARCHAR(255)    NOT NULL,                        -- Название резюме
    desired_position VARCHAR(255)   NOT NULL,                        -- Желаемая должность
    created_at      TIMESTAMP       NOT NULL DEFAULT NOW(),          -- Дата и время создания
    status          VARCHAR(50)     NOT NULL,                        -- Статус резюме

    CONSTRAINT fk_resume_applicant
        FOREIGN KEY (applicant_id) REFERENCES applicant (applicant_id)
		ON DELETE RESTRICT,                                          -- Запрет удаления соискателя при наличии резюме
    CONSTRAINT chk_resume_status CHECK (status IN ('опубликовано', 'скрыто')) -- Проверка допустимых статусов
);

-- E11. Версия резюме
CREATE TABLE resume_version (
    resume_version_id   BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY, -- Идентификатор версии резюме
    resume_id           INTEGER     NOT NULL,                            -- Идентификатор резюме
    version_number      INTEGER     NOT NULL,                            -- Номер версии
    created_at          TIMESTAMP   NOT NULL DEFAULT NOW(),              -- Дата и время создания версии
    changed_by          VARCHAR(255) NOT NULL,                           -- Автор изменения
    change_reason       TEXT,                                            -- Основание изменения
    status              VARCHAR(50) NOT NULL,                            -- Статус версии

    CONSTRAINT uq_resume_version UNIQUE (resume_id, version_number),     -- Уникальность номера версии в рамках резюме
    CONSTRAINT fk_resume_version_resume
        FOREIGN KEY (resume_id) REFERENCES resume (resume_id)
        ON DELETE RESTRICT,                                              -- Запрет удаления резюме при наличии версий
    CONSTRAINT chk_resume_version_status
        CHECK (status IN ('текущая', 'устаревшая'))                      -- Проверка допустимых статусов
);

-- E12. Навык резюме
CREATE TABLE resume_skill (
    resume_version_id  BIGINT      NOT NULL,   -- Идентификатор версии резюме
    skill_id           BIGINT      NOT NULL,   -- Идентификатор навыка
    level              INTEGER     NOT NULL,   -- Уровень владения навыком
    experience         INTEGER     NOT NULL,   -- Опыт использования (в годах/месяцах)
    comment            TEXT,                   -- Комментарий

    PRIMARY KEY (resume_version_id, skill_id), -- Составной первичный ключ
    CONSTRAINT fk_resume_skill_version
        FOREIGN KEY (resume_version_id) REFERENCES resume_version (resume_version_id)
        ON DELETE CASCADE,                     -- При удалении версии резюме навыки удаляются
    CONSTRAINT fk_resume_skill_skill
        FOREIGN KEY (skill_id) REFERENCES skill (skill_id)
		ON DELETE RESTRICT                     -- Запрет удаления навыка при наличии записей
);

-- E13. Отклик
CREATE TABLE response (
    response_id         BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY, -- Идентификатор отклика
    applicant_id        INTEGER      NOT NULL,                           -- Идентификатор соискателя
    resume_version_id   BIGINT       NOT NULL,                           -- Идентификатор версии резюме
    vacancy_version_id  BIGINT       NOT NULL,                           -- Идентификатор версии вакансии
    created_at          TIMESTAMP    NOT NULL DEFAULT NOW(),             -- Дата и время создания отклика
    current_stage       VARCHAR(100) NOT NULL,                           -- Текущий этап отклика
    status              VARCHAR(50)  NOT NULL,                           -- Статус отклика

    CONSTRAINT fk_response_applicant
        FOREIGN KEY (applicant_id) REFERENCES applicant (applicant_id)
		ON DELETE RESTRICT,                                              -- Запрет удаления соискателя при наличии откликов
    CONSTRAINT fk_response_resume_version
        FOREIGN KEY (resume_version_id) REFERENCES resume_version (resume_version_id)
		ON DELETE RESTRICT,                                              -- Запрет удаления версии резюме при наличии откликов
    CONSTRAINT fk_response_vacancy_version
        FOREIGN KEY (vacancy_version_id) REFERENCES vacancy_version (vacancy_version_id)
		ON DELETE RESTRICT,                                              -- Запрет удаления версии вакансии при наличии откликов
    CONSTRAINT chk_response_status
        CHECK (status IN ('активен', 'завершён')),                       -- Проверка допустимых статусов
    CONSTRAINT chk_response_current_stage
        CHECK (current_stage IN ('получен', 'просмотрен', 'приглашен',   -- Проверка допустимых этапов
                                 'интервью', 'тестовое задание',
                                 'отказ', 'предложение'))
);

-- E14. Этап отклика
CREATE TABLE response_stage (
    stage_id        BIGINT GENERATED ALWAYS AS IDENTITY,  -- Идентификатор этапа
    response_id     INTEGER         NOT NULL,             -- Идентификатор отклика
    recruiter_id    INTEGER         NOT NULL,             -- Идентификатор ответственного рекрутера
    stage_type      VARCHAR(100)    NOT NULL,             -- Тип этапа
    date_from       TIMESTAMP       NOT NULL DEFAULT NOW(), -- Дата и время начала этапа
    date_to         TIMESTAMP,                            -- Дата и время завершения этапа
    result          TEXT,                                 -- Результат этапа

    PRIMARY KEY (stage_id, response_id),                  -- Составной первичный ключ
    CONSTRAINT fk_response_stage_response
        FOREIGN KEY (response_id) REFERENCES response (response_id)
        ON DELETE RESTRICT,                               -- Запрет удаления отклика при наличии этапов
    CONSTRAINT fk_response_stage_recruiter
        FOREIGN KEY (recruiter_id) REFERENCES recruiter (recruiter_id)
		ON DELETE RESTRICT                                -- Запрет удаления рекрутера при наличии этапов
);

-- E15. Интервью
CREATE TABLE interview (
    interview_id    BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY, -- Идентификатор интервью
    response_id     INTEGER         NOT NULL,                        -- Идентификатор отклика
    applicant_id    INTEGER         NOT NULL,                        -- Идентификатор соискателя
    start_at        TIMESTAMP       NOT NULL DEFAULT NOW(),          -- Дата и время начала интервью
    end_at          TIMESTAMP       NOT NULL DEFAULT (NOW() + INTERVAL '2 hours'), -- Дата и время окончания интервью
    format          VARCHAR(50)     NOT NULL,                        -- Формат интервью
    result          TEXT,                                            -- Результат интервью
    status          VARCHAR(50)     NOT NULL,                        -- Статус интервью

    CONSTRAINT fk_interview_response
        FOREIGN KEY (response_id) REFERENCES response (response_id)
		ON DELETE RESTRICT,                                          -- Запрет удаления отклика при наличии интервью
    CONSTRAINT fk_interview_applicant
        FOREIGN KEY (applicant_id) REFERENCES applicant (applicant_id)
		ON DELETE RESTRICT                                           -- Запрет удаления соискателя при наличии интервью
);

-- E16. Предложение о работе
CREATE TABLE job_offer (
    offer_id            BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY, -- Идентификатор предложения
    response_id         INTEGER         NOT NULL,                        -- Идентификатор отклика
    offer_date          DATE            NOT NULL DEFAULT CURRENT_DATE,   -- Дата предложения
    position            VARCHAR(255)    NOT NULL,                        -- Должность
    conditions          TEXT            NOT NULL,                        -- Условия предложения
    response_deadline   DATE            NOT NULL DEFAULT (CURRENT_DATE + 7), -- Срок ответа на предложение
    status              VARCHAR(50)     NOT NULL,                        -- Статус предложения

    CONSTRAINT fk_job_offer_response
        FOREIGN KEY (response_id) REFERENCES response (response_id)
		ON DELETE RESTRICT,                                              -- Запрет удаления отклика при наличии предложения
	CONSTRAINT chk_job_offer_status
        CHECK (status IN ('отправлено', 'принято', 'отклонено', 'истекло', 'отозвано', 'устаревшее')) -- Проверка допустимых статусов
);

-- E17. Тариф работодателя
CREATE TABLE employer_tariff (
    tariff_id       BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY, -- Идентификатор тарифа
    company_id      INTEGER         NOT NULL,                        -- Идентификатор компании
    name            VARCHAR(255)    NOT NULL,                        -- Название тарифа
    rate            NUMERIC(12,2)   NOT NULL,                        -- Ставка
    unit            VARCHAR(50)     NOT NULL,                        -- Единица расчёта
    date_from       DATE            NOT NULL DEFAULT CURRENT_DATE,   -- Дата начала действия тарифа
    date_to         DATE            NOT NULL DEFAULT (CURRENT_DATE + 30), -- Дата окончания действия тарифа
    status          VARCHAR(50)     NOT NULL,                        -- Статус тарифа

    CONSTRAINT fk_tariff_company
        FOREIGN KEY (company_id) REFERENCES company (company_id)
		ON DELETE RESTRICT                                           -- Запрет удаления компании при наличии тарифов
);

-- E18. Участник интервью
CREATE TABLE interview_participant (
    interview_id    INTEGER         NOT NULL, -- Идентификатор интервью
    recruiter_id    INTEGER         NOT NULL, -- Идентификатор рекрутера-участника

    PRIMARY KEY (interview_id, recruiter_id), -- Составной первичный ключ
    CONSTRAINT fk_ip_interview
        FOREIGN KEY (interview_id) REFERENCES interview (interview_id)
		ON DELETE CASCADE,                    -- При удалении интервью участники удаляются
    CONSTRAINT fk_ip_recruiter
        FOREIGN KEY (recruiter_id) REFERENCES recruiter (recruiter_id)
		ON DELETE RESTRICT                    -- Запрет удаления рекрутера при наличии участия в интервью
);