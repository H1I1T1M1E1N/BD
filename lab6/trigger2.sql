CREATE OR REPLACE FUNCTION trg_check_interview_overlap()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_conflict_id BIGINT;
    v_kind        TEXT;
BEGIN
    -- Отменённое интервью не проверяем
    IF NEW.status = 'отменено' THEN
        RETURN NEW;
    END IF;

    -- 1) Конфликт по переговорной
    IF NEW.room_id IS NOT NULL THEN
        SELECT i.interview_id INTO v_conflict_id
        FROM interview i
        WHERE i.interview_id <> NEW.interview_id
          AND i.status <> 'отменено'
          AND i.room_id = NEW.room_id
          AND tstzrange(i.start_at, i.end_at, '[)')
              && tstzrange(NEW.start_at, NEW.end_at, '[)')
        LIMIT 1;

        IF v_conflict_id IS NOT NULL THEN
            RAISE EXCEPTION
              'Конфликт расписания: переговорная занята в интервью №% (пересечение по времени)',
              v_conflict_id
              USING ERRCODE = 'exclusion_violation';
        END IF;
    END IF;

    -- 2) Конфликт по соискателю (кандидат не может быть на двух интервью одновременно)
    SELECT i.interview_id INTO v_conflict_id
    FROM interview i
    WHERE i.interview_id <> NEW.interview_id
      AND i.status <> 'отменено'
      AND i.applicant_id = NEW.applicant_id
      AND tstzrange(i.start_at, i.end_at, '[)')
          && tstzrange(NEW.start_at, NEW.end_at, '[)')
    LIMIT 1;

    IF v_conflict_id IS NOT NULL THEN
        RAISE EXCEPTION
          'Конфликт расписания: соискатель уже приглашён на интервью №% (пересечение по времени)',
          v_conflict_id
          USING ERRCODE = 'exclusion_violation';
    END IF;

    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_interview_overlap
BEFORE INSERT OR UPDATE OF start_at, end_at, room_id, status ON interview
FOR EACH ROW EXECUTE FUNCTION trg_check_interview_overlap();

-- Отдельно триггер для пересечения интервью у рекрутеров
CREATE OR REPLACE FUNCTION trg_check_participant_overlap()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_conflict_id BIGINT;
BEGIN
    SELECT i2.interview_id INTO v_conflict_id
    FROM interview i1
    JOIN interview i2
      ON i2.interview_id <> i1.interview_id
     AND i2.status <> 'отменено'
     AND tstzrange(i2.start_at, i2.end_at, '[)')
         && tstzrange(i1.start_at, i1.end_at, '[)')
    JOIN interview_participant ip2
      ON ip2.interview_id = i2.interview_id
     AND ip2.recruiter_id = NEW.recruiter_id
    WHERE i1.interview_id = NEW.interview_id
      AND i1.status <> 'отменено'
    LIMIT 1;

    IF v_conflict_id IS NOT NULL THEN
        RAISE EXCEPTION
          'Конфликт расписания: рекрутер уже занят в интервью №% (пересечение по времени)',
          v_conflict_id
          USING ERRCODE = 'exclusion_violation';
    END IF;

    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_participant_overlap
AFTER INSERT OR UPDATE ON interview_participant
FOR EACH ROW EXECUTE FUNCTION trg_check_participant_overlap();