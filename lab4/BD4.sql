-- E1. Компания
CREATE TABLE company (
    company_id      BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    name            VARCHAR(255)    NOT NULL,
    requisites      VARCHAR(255)    NOT NULL UNIQUE,
    contacts        TEXT            NOT NULL,
    status          VARCHAR(50)     NOT NULL,

    CONSTRAINT chk_company_status CHECK (status IN ('активна', 'не активна'))
);

-- E2. Подразделение
CREATE TABLE department (
    department_id   BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    company_id      INTEGER         NOT NULL,
    name            VARCHAR(255)    NOT NULL,
    parent_id       INTEGER,
    head_full_name  VARCHAR(255)    NOT NULL,
    status          VARCHAR(50)     NOT NULL,

    CONSTRAINT fk_department_company
        FOREIGN KEY (company_id) REFERENCES company (company_id),
    CONSTRAINT fk_department_parent
        FOREIGN KEY (parent_id) REFERENCES department (department_id),
    CONSTRAINT chk_department_status CHECK (status IN ('активно', 'не активно'))
);

-- E3. Рекрутер
CREATE TABLE recruiter (
    recruiter_id    BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    full_name       VARCHAR(255)    NOT NULL,
    contacts        TEXT            NOT NULL,
    department_id   INTEGER         NOT NULL,
    status          VARCHAR(50)     NOT NULL,

    CONSTRAINT fk_recruiter_department
        FOREIGN KEY (department_id) REFERENCES department (department_id),
    CONSTRAINT chk_recruiter_status CHECK (status IN ('активен', 'не активен'))
);

-- E4. Полномочие рекрутера
CREATE TABLE recruiter_authority (
    authority_id    BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    recruiter_id    INTEGER         NOT NULL,
    object          VARCHAR(255)    NOT NULL,
    role            VARCHAR(100)    NOT NULL,
    date_from       DATE            NOT NULL DEFAULT CURRENT_DATE,
    date_to         DATE            DEFAULT (CURRENT_DATE + 30),
    status          VARCHAR(50)     NOT NULL,

    CONSTRAINT fk_authority_recruiter
        FOREIGN KEY (recruiter_id) REFERENCES recruiter (recruiter_id),
    CONSTRAINT chk_recruiter_authority_status
        CHECK (status IN ('действует', 'истекло', 'отозвано'))
);

-- E5. Вакансия
CREATE TABLE vacancy (
    vacancy_id      BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    position_name   VARCHAR(255)    NOT NULL,
    company_id      INTEGER         NOT NULL,
    department_id   INTEGER,
    conditions      TEXT            NOT NULL,
    publish_status  VARCHAR(50)     NOT NULL,

    CONSTRAINT fk_vacancy_company
        FOREIGN KEY (company_id) REFERENCES company (company_id),
    CONSTRAINT fk_vacancy_department
        FOREIGN KEY (department_id) REFERENCES department (department_id),
    CONSTRAINT chk_vacancy_status CHECK (publish_status IN ('активна', 'закрыта'))
);

-- E6. Версия вакансии
CREATE TABLE vacancy_version (
    vacancy_version_id  BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    vacancy_id          INTEGER     NOT NULL,                               
    version_number      INTEGER     NOT NULL,                            
    created_at          TIMESTAMP   NOT NULL DEFAULT NOW(),
    changed_by          VARCHAR(255) NOT NULL,
    change_reason       TEXT,
    status              VARCHAR(50) NOT NULL,

    CONSTRAINT uq_vacancy_version UNIQUE (vacancy_id, version_number),   
    CONSTRAINT fk_vacancy_version_vacancy
        FOREIGN KEY (vacancy_id) REFERENCES vacancy (vacancy_id)
        ON DELETE RESTRICT,
    CONSTRAINT chk_vacancy_version_status
        CHECK (status IN ('текущая', 'устаревшая'))
);

-- E7. Навык
CREATE TABLE skill (
    skill_id        BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    name            VARCHAR(255)    NOT NULL,
    category        VARCHAR(100)    NOT NULL,
    description     TEXT
);

-- E8. Требование навыка
CREATE TABLE vacancy_skill_requirement (
    vacancy_version_id  BIGINT      NOT NULL,     
    skill_id            BIGINT      NOT NULL,
    required_level      INTEGER     NOT NULL,
    is_mandatory        BOOLEAN     NOT NULL,
    comment             TEXT,

    PRIMARY KEY (vacancy_version_id, skill_id),
    CONSTRAINT fk_vsr_vacancy_version
        FOREIGN KEY (vacancy_version_id) REFERENCES vacancy_version (vacancy_version_id)
        ON DELETE CASCADE,
    CONSTRAINT fk_vsr_skill
        FOREIGN KEY (skill_id) REFERENCES skill (skill_id)
);

-- E9. Соискатель
CREATE TABLE applicant (
    applicant_id    BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    full_name       VARCHAR(255)    NOT NULL,
    contacts        TEXT            NOT NULL,
    registered_at   TIMESTAMP       NOT NULL DEFAULT NOW(),
    status          VARCHAR(50)     NOT NULL,

    CONSTRAINT chk_applicant_status CHECK (status IN ('активен', 'неактивен'))
);

-- E10. Резюме
CREATE TABLE resume (
    resume_id       BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    applicant_id    INTEGER         NOT NULL,
    name            VARCHAR(255)    NOT NULL,
    desired_position VARCHAR(255)   NOT NULL,
    created_at      TIMESTAMP       NOT NULL DEFAULT NOW(),
    status          VARCHAR(50)     NOT NULL,

    CONSTRAINT fk_resume_applicant
        FOREIGN KEY (applicant_id) REFERENCES applicant (applicant_id),
    CONSTRAINT chk_resume_status CHECK (status IN ('опубликовано', 'скрыто'))
);

-- E11. Версия резюме
CREATE TABLE resume_version (
    resume_version_id   BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,   -- суррогатный PK
    resume_id           INTEGER     NOT NULL,                               -- FK на резюме
    version_number      INTEGER     NOT NULL,                               -- номер версии внутри резюме
    created_at          TIMESTAMP   NOT NULL DEFAULT NOW(),
    changed_by          VARCHAR(255) NOT NULL,
    change_reason       TEXT,
    status              VARCHAR(50) NOT NULL,

    CONSTRAINT uq_resume_version UNIQUE (resume_id, version_number),        -- бизнес-ключ
    CONSTRAINT fk_resume_version_resume
        FOREIGN KEY (resume_id) REFERENCES resume (resume_id)
        ON DELETE CASCADE,
    CONSTRAINT chk_resume_version_status
        CHECK (status IN ('текущая', 'устаревшая'))
);

-- E12. Навык резюме
CREATE TABLE resume_skill (
    resume_version_id  BIGINT      NOT NULL,   
    skill_id           BIGINT      NOT NULL,
    level              INTEGER     NOT NULL,
    experience         INTEGER     NOT NULL,
    comment            TEXT,

    PRIMARY KEY (resume_version_id, skill_id),
    CONSTRAINT fk_resume_skill_version
        FOREIGN KEY (resume_version_id) REFERENCES resume_version (resume_version_id)
        ON DELETE CASCADE,
    CONSTRAINT fk_resume_skill_skill
        FOREIGN KEY (skill_id) REFERENCES skill (skill_id)
);

-- E13. Отклик
CREATE TABLE response (
    response_id         BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    applicant_id        INTEGER      NOT NULL,
    resume_version_id   BIGINT       NOT NULL,     
    vacancy_version_id  BIGINT       NOT NULL,     
    created_at          TIMESTAMP    NOT NULL DEFAULT NOW(),
    current_stage       VARCHAR(100) NOT NULL,
    status              VARCHAR(50)  NOT NULL,

    CONSTRAINT fk_response_applicant
        FOREIGN KEY (applicant_id) REFERENCES applicant (applicant_id),
    CONSTRAINT fk_response_resume_version
        FOREIGN KEY (resume_version_id) REFERENCES resume_version (resume_version_id),
    CONSTRAINT fk_response_vacancy_version
        FOREIGN KEY (vacancy_version_id) REFERENCES vacancy_version (vacancy_version_id),
    CONSTRAINT chk_response_status
        CHECK (status IN ('активен', 'завершён')),
    CONSTRAINT chk_response_current_stage
        CHECK (current_stage IN ('получен', 'просмотрен', 'приглашен',
                                 'интервью', 'тестовое задание',
                                 'отказ', 'предложение'))
);

-- E14. Этап отклика
CREATE TABLE response_stage (
    stage_id        BIGINT GENERATED ALWAYS AS IDENTITY,  
    response_id     INTEGER         NOT NULL,             
    recruiter_id    INTEGER         NOT NULL,              
    stage_type      VARCHAR(100)    NOT NULL,              
    date_from       TIMESTAMP       NOT NULL DEFAULT NOW(),
    date_to         TIMESTAMP,                             
    result          TEXT,                                  

    PRIMARY KEY (stage_id, response_id),
    CONSTRAINT fk_response_stage_response
        FOREIGN KEY (response_id) REFERENCES response (response_id)
        ON DELETE CASCADE,
    CONSTRAINT fk_response_stage_recruiter
        FOREIGN KEY (recruiter_id) REFERENCES recruiter (recruiter_id)
);

-- E15. Интервью
CREATE TABLE interview (
    interview_id    BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    response_id     INTEGER         NOT NULL,
    applicant_id    INTEGER         NOT NULL,
    start_at        TIMESTAMP       NOT NULL DEFAULT NOW(),
    end_at          TIMESTAMP       NOT NULL DEFAULT (NOW() + INTERVAL '2 hours'),
    format          VARCHAR(50)     NOT NULL,
    result          TEXT,
    status          VARCHAR(50)     NOT NULL,

    CONSTRAINT fk_interview_response
        FOREIGN KEY (response_id) REFERENCES response (response_id),
    CONSTRAINT fk_interview_applicant
        FOREIGN KEY (applicant_id) REFERENCES applicant (applicant_id)
);

-- E16. Предложение о работе
CREATE TABLE job_offer (
    offer_id            BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    response_id         INTEGER         NOT NULL,
    offer_date          DATE            NOT NULL DEFAULT CURRENT_DATE,
    position            VARCHAR(255)    NOT NULL,
    conditions          TEXT            NOT NULL,
    response_deadline   DATE            NOT NULL DEFAULT (CURRENT_DATE + 7),
    status              VARCHAR(50)     NOT NULL,

    CONSTRAINT fk_job_offer_response
        FOREIGN KEY (response_id) REFERENCES response (response_id)
);

-- E17. Тариф работодателя
CREATE TABLE employer_tariff (
    tariff_id       BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    company_id      INTEGER         NOT NULL,
    name            VARCHAR(255)    NOT NULL,
    rate            NUMERIC(12,2)   NOT NULL,
    unit            VARCHAR(50)     NOT NULL,
    date_from       DATE            NOT NULL DEFAULT CURRENT_DATE,
    date_to         DATE            NOT NULL DEFAULT (CURRENT_DATE + 30),
    status          VARCHAR(50)     NOT NULL,

    CONSTRAINT fk_tariff_company
        FOREIGN KEY (company_id) REFERENCES company (company_id)
);

-- E18. Участник интервью
CREATE TABLE interview_participant (
    interview_id    INTEGER         NOT NULL,
    recruiter_id    INTEGER         NOT NULL,

    PRIMARY KEY (interview_id, recruiter_id),
    CONSTRAINT fk_ip_interview
        FOREIGN KEY (interview_id) REFERENCES interview (interview_id),
    CONSTRAINT fk_ip_recruiter
        FOREIGN KEY (recruiter_id) REFERENCES recruiter (recruiter_id)
);