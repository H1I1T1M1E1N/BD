-- Переговорная комната
CREATE TABLE meeting_room (
    room_id     BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    name        VARCHAR(255) NOT NULL,
    company_id  INTEGER NOT NULL,
    CONSTRAINT fk_room_company FOREIGN KEY (company_id)
        REFERENCES company (company_id) ON DELETE RESTRICT
);

-- Добавление связи переговорной с интервью
ALTER TABLE interview
    ADD COLUMN room_id BIGINT,
    ADD CONSTRAINT fk_interview_room
        FOREIGN KEY (room_id) REFERENCES meeting_room (room_id)
        ON DELETE SET NULL;

-- Допустимые переходы между этапами отклика
CREATE TABLE stage_transition (
    from_stage  VARCHAR(100) NOT NULL,
    to_stage    VARCHAR(100) NOT NULL,
    PRIMARY KEY (from_stage, to_stage)
);

INSERT INTO stage_transition (from_stage, to_stage) VALUES
 ('получен','просмотрен'),
 ('просмотрен','приглашен'),
 ('просмотрен','отказ'),
 ('приглашен','интервью'),
 ('приглашен','отказ'),
 ('интервью','тестовое задание'),
 ('интервью','отказ'),
 ('тестовое задание','предложение'),
 ('тестовое задание','отказ'),
 ('предложение','отказ');