-- Функция для версии вакансии
CREATE OR REPLACE FUNCTION trg_protect_vacany_version()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_cnt INTEGER;
    v_id BIGINT := COALESCE(NEW.vacancy_version_id, OLD.vacancy_version_id);
BEGIN
    SELECT COUNT(*) INTO v_cnt
    FROM response
    WHERE vacancy_version_id = v_id;

    IF v_cnt > 0 THEN
        RAISE EXCEPTION
            'Нельзя % версию вакансии % : на неё ссылается % отклик(ов)',
            CASE TG_OP WHEN 'DELETE' THEN 'удалить' ELSE 'изменить' END,
            v_id, v_cnt
            USING ERRCODE = 'restrict_violation';
    end if;
    RETURN COALESCE(NEW, OLD);
END;
$$

CREATE TRIGGER trg_vacancy_version_protect
    BEFORE UPDATE OR DELETE ON vacancy_version
    FOR EACH ROW EXECUTE FUNCTION trg_protect_vacany_version();

-- Функция для версии резюме
CREATE OR REPLACE FUNCTION trg_protect_resume_version()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_cnt INTEGER;
    v_id  BIGINT := COALESCE(NEW.resume_version_id, OLD.resume_version_id);
BEGIN
    SELECT COUNT(*) INTO v_cnt
    FROM response
    WHERE resume_version_id = v_id;

    IF v_cnt > 0 THEN
        RAISE EXCEPTION
            'Нельзя % версию резюме % : на неё ссылается % отклик(ов)',
            CASE TG_OP WHEN 'DELETE' THEN 'удалить' ELSE 'изменить' END,
            v_id, v_cnt
            USING ERRCODE = 'restrict_violation';
    END IF;

    RETURN COALESCE(NEW, OLD);
END;
$$;

CREATE TRIGGER trg_resume_version_protection
    BEFORE UPDATE OR DELETE ON resume_version
    FOR EACH ROW EXECUTE FUNCTION trg_protect_resume_version();