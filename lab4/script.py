import psycopg2
from psycopg2 import errors
from faker import Faker
import random
from datetime import datetime, timedelta
import uuid

# ================= НАСТРОЙКИ =================
DB_CONFIG = {
    "dbname": "gg.ai",
    "user": "postgres",
    "password": "QAZxdrf567890",
    "host": "localhost",
    "port": "5432"
}

fake = Faker('ru_RU')
random.seed(42)  # воспроизводимость

# ================= КОЛИЧЕСТВО ДАННЫХ =================
NUM_COMPANIES = 50
NUM_DEPARTMENTS = 400
NUM_RECRUITERS = 4000
NUM_VACANCIES = 5000
NUM_SKILLS = 100
NUM_APPLICANTS = 7000
NUM_RESPONSES = 20000

MIN_VERSIONS = 1
MAX_VERSIONS = 6

# Этапы и допустимые переходы (должны совпадать с stage_transition)
STAGES = ['получен', 'просмотрен', 'приглашен', 'интервью',
          'тестовое задание', 'отказ', 'предложение']

TRANSITIONS = {
    'получен': ['просмотрен'],
    'просмотрен': ['приглашен', 'отказ'],
    'приглашен': ['интервью', 'отказ'],
    'интервью': ['тестовое задание', 'отказ'],
    'тестовое задание': ['предложение', 'отказ'],
    'предложение': ['отказ'],
}

INTERVIEW_STATUSES = ['запланировано', 'завершено', 'отменено']


def get_id(cur, query, params):
    cur.execute(query, params)
    return cur.fetchone()[0]


def seed_database():
    conn = psycopg2.connect(**DB_CONFIG)

    with conn, conn.cursor() as cur:
        print("🚀 Начинаем заполнение базы данных...")

        # ================= 1. КОМПАНИИ =================
        print(f"📦 Создаем {NUM_COMPANIES} компаний...")
        company_ids = []
        for _ in range(NUM_COMPANIES):
            cid = get_id(cur, """
                INSERT INTO company (name, requisites, contacts, status)
                VALUES (%s, %s, %s, %s) RETURNING company_id
            """, (
                fake.company(),
                str(uuid.uuid4()),
                f"{fake.address()}, тел: {fake.phone_number()}, email: {fake.email()}",
                random.choice(['активна', 'не активна'])
            ))
            company_ids.append(cid)

        # ================= 1a. ПЕРЕГОВОРНЫЕ =================
        print("🚪 Создаем переговорные...")
        company_rooms = {cid: [] for cid in company_ids}
        for cid in company_ids:
            for n in range(random.randint(2, 6)):
                rid = get_id(cur, """
                    INSERT INTO meeting_room (name, company_id)
                    VALUES (%s, %s) RETURNING room_id
                """, (f"Переговорная {n + 1}", cid))
                company_rooms[cid].append(rid)

        # ================= 2. ПОДРАЗДЕЛЕНИЯ =================
        print(f"🏢 Создаем {NUM_DEPARTMENTS} подразделений...")
        department_ids = []
        department_company = {}  # department_id -> company_id (нужно для вакансий/рекрутеров)

        for _ in range(NUM_DEPARTMENTS):
            parent = random.choice(department_ids) if department_ids and random.random() < 0.3 else None
            cid = random.choice(company_ids)

            did = get_id(cur, """
                INSERT INTO department (company_id, name, parent_id, head_full_name, status)
                VALUES (%s, %s, %s, %s, %s) RETURNING department_id
            """, (
                cid,
                fake.bs(),
                parent,
                fake.name(),
                random.choice(['активно', 'не активно'])
            ))
            department_ids.append(did)
            department_company[did] = cid

        # ================= 3. РЕКРУТЕРЫ =================
        print(f"👥 Создаем {NUM_RECRUITERS} рекрутеров...")
        recruiter_ids = []
        recruiter_company = {}  # recruiter_id -> company_id

        for _ in range(NUM_RECRUITERS):
            did = random.choice(department_ids)
            rid = get_id(cur, """
                INSERT INTO recruiter (full_name, contacts, department_id, status)
                VALUES (%s, %s, %s, %s) RETURNING recruiter_id
            """, (
                fake.name(),
                f"{fake.phone_number()}, {fake.email()}",
                did,
                random.choice(['активен', 'не активен'])
            ))
            recruiter_ids.append(rid)
            recruiter_company[rid] = department_company[did]

        # ================= 4. ПОЛНОМОЧИЯ РЕКРУТЕРОВ =================
        # object = 'компания:<id>' или 'вакансия:<id>' — как ожидает процедура advance_response_stage
        print("🔐 Создаем полномочия рекрутеров...")
        today = datetime.now().date()
        for rid in recruiter_ids:
            cid = recruiter_company[rid]
            num_authorities = random.randint(1, 3)
            for _ in range(num_authorities):
                # 70% — действующие (вокруг сегодня), 30% — истёкшие/отозванные
                if random.random() < 0.7:
                    date_from = today - timedelta(days=random.randint(1, 90))
                    date_to = today + timedelta(days=random.randint(30, 365))
                    status = 'действует'
                else:
                    date_from = today - timedelta(days=random.randint(200, 700))
                    date_to = date_from + timedelta(days=random.randint(30, 180))
                    status = random.choice(['истекло', 'отозвано'])

                obj = (f"компания:{cid}" if random.random() < 0.5
                       else f"вакансия:{random.randint(1, 100000)}")

                get_id(cur, """
                    INSERT INTO recruiter_authority
                        (recruiter_id, object, role, date_from, date_to, status)
                    VALUES (%s, %s, %s, %s, %s, %s) RETURNING authority_id
                """, (rid, obj, fake.job(), date_from, date_to, status))

        # ================= 5. ТАРИФЫ =================
        print("💳 Создаем тарифы для компаний...")
        for cid in company_ids:
            for _ in range(random.randint(1, 4)):
                date_from = fake.date_object()
                get_id(cur, """
                    INSERT INTO employer_tariff
                        (company_id, name, rate, unit, date_from, date_to, status)
                    VALUES (%s, %s, %s, %s, %s, %s, %s) RETURNING tariff_id
                """, (
                    cid,
                    f"Тариф {fake.word()}",
                    round(random.uniform(1000, 100000), 2),
                    random.choice(["в месяц", "за вакансию", "за отклик"]),
                    date_from,
                    date_from + timedelta(days=random.randint(30, 365)),
                    random.choice(['активна', 'не активна'])
                ))

        # ================= 6. НАВЫКИ =================
        print(f"🎯 Создаем {NUM_SKILLS} навыков...")
        skill_ids = []
        for _ in range(NUM_SKILLS):
            sid = get_id(cur, """
                INSERT INTO skill (name, category, description)
                VALUES (%s, %s, %s) RETURNING skill_id
            """, (
                fake.word().capitalize(),
                random.choice(["Языки программирования", "Фреймворки", "Инструменты",
                               "Базы данных", "Методологии", "Soft Skills"]),
                fake.text(max_nb_chars=100)
            ))
            skill_ids.append(sid)

        # ================= 7. ВАКАНСИИ И ВЕРСИИ =================
        print(f"💼 Создаем {NUM_VACANCIES} вакансий...")
        vacancy_version_ids = []
        # Для каждого отклика нам нужно знать компанию вакансии (для переговорной)
        vacancy_version_company = {}  # vacancy_version_id -> company_id

        for _ in range(NUM_VACANCIES):
            cid = random.choice(company_ids)
            did = random.choice([d for d in department_ids if department_company[d] == cid]
                                or department_ids)

            vid = get_id(cur, """
                INSERT INTO vacancy
                    (position_name, company_id, department_id, conditions, publish_status)
                VALUES (%s, %s, %s, %s, %s) RETURNING vacancy_id
            """, (
                fake.job(),
                cid,
                did,
                fake.text(max_nb_chars=150),
                random.choice(['активна', 'закрыта'])
            ))

            num_versions = random.randint(MIN_VERSIONS, MAX_VERSIONS)
            for version_num in range(1, num_versions + 1):
                status = 'текущая' if version_num == num_versions else 'устаревшая'
                vvid = get_id(cur, """
                    INSERT INTO vacancy_version
                        (vacancy_id, version_number, changed_by, change_reason, status)
                    VALUES (%s, %s, %s, %s, %s) RETURNING vacancy_version_id
                """, (
                    vid,
                    version_num,
                    fake.name(),
                    random.choice([
                        "Первичное создание",
                        "Изменение зарплатной вилки",
                        "Добавление новых требований",
                        "Обновление описания вакансии",
                        "Изменение условий работы"
                    ]),
                    status
                ))
                vacancy_version_company[vvid] = cid

                for sid in random.sample(skill_ids, k=random.randint(2, 6)):
                    cur.execute("""
                        INSERT INTO vacancy_skill_requirement
                            (vacancy_version_id, skill_id, required_level, is_mandatory, comment)
                        VALUES (%s, %s, %s, %s, %s)
                    """, (
                        vvid,
                        sid,
                        random.randint(1, 5),
                        random.choice([True, False]),
                        fake.text(max_nb_chars=50) if random.random() < 0.5 else None
                    ))

                vacancy_version_ids.append(vvid)

        # ================= 8. СОИСКАТЕЛИ =================
        print(f"👤 Создаем {NUM_APPLICANTS} соискателей...")
        applicant_ids = []
        for _ in range(NUM_APPLICANTS):
            aid = get_id(cur, """
                INSERT INTO applicant (full_name, contacts, status)
                VALUES (%s, %s, %s) RETURNING applicant_id
            """, (
                fake.name(),
                f"{fake.phone_number()}, {fake.email()}",
                random.choice(['активен', 'неактивен'])
            ))
            applicant_ids.append(aid)

        # ================= 9. РЕЗЮМЕ И ВЕРСИИ =================
        print("📄 Создаем резюме для соискателей...")
        resume_version_ids = []  # (resume_version_id, applicant_id)
        applicant_resume_versions = {aid: [] for aid in applicant_ids}

        for aid in applicant_ids:
            for _ in range(random.randint(1, 3)):
                rid = get_id(cur, """
                    INSERT INTO resume (applicant_id, name, desired_position, status)
                    VALUES (%s, %s, %s, %s) RETURNING resume_id
                """, (
                    aid,
                    f"Резюме {fake.word()}",
                    fake.job(),
                    random.choice(['опубликовано', 'скрыто'])
                ))

                num_versions = random.randint(MIN_VERSIONS, MAX_VERSIONS)
                for version_num in range(1, num_versions + 1):
                    status = 'текущая' if version_num == num_versions else 'устаревшая'
                    rvid = get_id(cur, """
                        INSERT INTO resume_version
                            (resume_id, version_number, changed_by, change_reason, status)
                        VALUES (%s, %s, %s, %s, %s) RETURNING resume_version_id
                    """, (
                        rid,
                        version_num,
                        fake.name(),
                        random.choice([
                            "Первичное создание",
                            "Добавление нового опыта",
                            "Обновление навыков",
                            "Исправление ошибок",
                            "Изменение желаемой должности"
                        ]),
                        status
                    ))

                    for sid in random.sample(skill_ids, k=random.randint(3, 8)):
                        cur.execute("""
                            INSERT INTO resume_skill
                                (resume_version_id, skill_id, level, experience, comment)
                            VALUES (%s, %s, %s, %s, %s)
                        """, (
                            rvid,
                            sid,
                            random.randint(1, 5),
                            random.randint(0, 15),
                            fake.text(max_nb_chars=50) if random.random() < 0.5 else None
                        ))

                    resume_version_ids.append((rvid, aid))
                    applicant_resume_versions[aid].append(rvid)

        # ================= 10. ОТКЛИКИ =================
        print(f"📨 Создаем {NUM_RESPONSES} откликов...")
        response_ids = []  # (response_id, applicant_id, current_stage, vacancy_version_id)
        base_date = datetime.now() - timedelta(days=365)

        # Только текущие версии вакансий — на них можно откликаться
        cur.execute("SELECT vacancy_version_id FROM vacancy_version WHERE status = 'текущая'")
        current_vacancy_versions = [r[0] for r in cur.fetchall()]

        # Множество для контроля дубликатов (applicant_id, vacancy_version_id)
        seen_pairs = set()

        attempts = 0
        while len(response_ids) < NUM_RESPONSES and attempts < NUM_RESPONSES * 5:
            attempts += 1
            vvid = random.choice(current_vacancy_versions)
            rvid, aid = random.choice(resume_version_ids)

            if (aid, vvid) in seen_pairs:
                continue
            seen_pairs.add((aid, vvid))

            # Выбираем этап и строим цепочку от 'получен' до него
            final_stage = random.choice(STAGES)
            status = 'завершён' if final_stage in ('отказ', 'предложение') else 'активен'

            created_at = base_date + timedelta(
                days=random.randint(0, 365),
                hours=random.randint(0, 23),
                minutes=random.randint(0, 59)
            )

            resp_id = get_id(cur, """
                INSERT INTO response
                    (applicant_id, resume_version_id, vacancy_version_id,
                     current_stage, status, created_at)
                VALUES (%s, %s, %s, %s, %s, %s) RETURNING response_id
            """, (aid, rvid, vvid, final_stage, status, created_at))

            response_ids.append((resp_id, aid, final_stage, vvid))

        # ================= 11. ЭТАПЫ ОТКЛИКОВ =================
        # Строим цепочку этапов по TRANSITIONS, чтобы данные были согласованы
        print("📊 Создаем этапы откликов...")

        def build_stage_chain(final_stage):
            """Возвращает список этапов от 'получен' до final_stage по допустимым переходам."""
            if final_stage == 'получен':
                return ['получен']
            # BFS по TRANSITIONS от 'получен' до final_stage
            from collections import deque
            q = deque([('получен', ['получен'])])
            visited = {'получен'}
            while q:
                node, path = q.popleft()
                if node == final_stage:
                    return path
                for nxt in TRANSITIONS.get(node, []):
                    if nxt not in visited:
                        visited.add(nxt)
                        q.append((nxt, path + [nxt]))
            return ['получен']

        for resp_id, aid, final_stage, vvid in response_ids:
            cur.execute("SELECT created_at FROM response WHERE response_id = %s", (resp_id,))
            stage_date = cur.fetchone()[0]

            chain = build_stage_chain(final_stage)
            for i, stage_type in enumerate(chain):
                date_from = stage_date + timedelta(hours=random.randint(1, 48))
                # Последний этап оставляем открытым, если отклик активен
                is_last = (i == len(chain) - 1)
                if is_last and final_stage not in ('отказ', 'предложение'):
                    date_to = None
                else:
                    date_to = date_from + timedelta(hours=random.randint(1, 168))

                cur.execute("""
                    INSERT INTO response_stage
                        (response_id, recruiter_id, stage_type, date_from, date_to, result)
                    VALUES (%s, %s, %s, %s, %s, %s)
                """, (
                    resp_id,
                    random.choice(recruiter_ids),
                    stage_type,
                    date_from,
                    date_to,
                    fake.text(max_nb_chars=80) if random.random() < 0.6 else None
                ))

                if date_to:
                    stage_date = date_to

        # ================= 12. ИНТЕРВЬЮ =================
        # Учитываем триггеры пересечений: используем SAVEPOINT и пропускаем конфликты.
        print("🎤 Создаем интервью (с учётом триггеров пересечений)...")
        interview_ids = []
        skipped = 0

        for resp_id, aid, final_stage, vvid in response_ids:
            if random.random() >= 0.4:
                continue

            # Разносим интервью по времени, чтобы снизить число конфликтов
            start_time = fake.date_time_between(start_date='-1M', end_date='+1M')
            end_time = start_time + timedelta(hours=random.randint(1, 3))

            fmt = random.choice(['Онлайн', 'Офлайн', 'Телефон'])
            # Переговорная нужна только для офлайн-интервью
            room_id = None
            if fmt == 'Офлайн':
                cid = vacancy_version_company.get(vvid)
                if cid and company_rooms.get(cid):
                    room_id = random.choice(company_rooms[cid])

            status = random.choice(INTERVIEW_STATUSES)

            try:
                cur.execute("SAVEPOINT before_interview")

                iid = get_id(cur, """
                    INSERT INTO interview
                        (response_id, applicant_id, start_at, end_at,
                         format, result, status, room_id)
                    VALUES (%s, %s, %s, %s, %s, %s, %s, %s)
                    RETURNING interview_id
                """, (
                    resp_id,
                    aid,
                    start_time,
                    end_time,
                    fmt,
                    fake.text(max_nb_chars=100) if random.random() < 0.7 else None,
                    status,
                    room_id
                ))

                # Участники: 1-4 рекрутера из той же компании, что и вакансия
                cid = vacancy_version_company.get(vvid)
                candidates = [r for r in recruiter_ids if recruiter_company[r] == cid]
                if not candidates:
                    candidates = recruiter_ids
                participants = random.sample(candidates, k=min(random.randint(1, 4), len(candidates)))

                for rec_id in participants:
                    cur.execute("""
                        INSERT INTO interview_participant (interview_id, recruiter_id)
                        VALUES (%s, %s)
                    """, (iid, rec_id))

                cur.execute("RELEASE SAVEPOINT before_interview")
                interview_ids.append(iid)

            except errors.ExclusionViolation:
                # Конфликт расписания — откатываем только эту вставку
                cur.execute("ROLLBACK TO SAVEPOINT before_interview")
                skipped += 1
            except psycopg2.Error:
                cur.execute("ROLLBACK TO SAVEPOINT before_interview")
                skipped += 1

        print(f"   ↳ создано интервью: {len(interview_ids)}, пропущено из-за конфликтов: {skipped}")

        # ================= 13. ПРЕДЛОЖЕНИЯ О РАБОТЕ =================
        print("💼 Создаем предложения о работе...")
        for resp_id, aid, final_stage, vvid in response_ids:
            if random.random() < 0.2:
                offer_date = fake.date_object()
                get_id(cur, """
                    INSERT INTO job_offer
                        (response_id, offer_date, position, conditions, response_deadline, status)
                    VALUES (%s, %s, %s, %s, %s, %s) RETURNING offer_id
                """, (
                    resp_id,
                    offer_date,
                    fake.job(),
                    fake.text(max_nb_chars=150),
                    offer_date + timedelta(days=random.randint(3, 14)),
                    random.choice(['отправлено', 'принято', 'отклонено',
                                   'истекло', 'отозвано', 'устаревшее'])
                ))

        conn.commit()
        print("\n✅ База данных успешно заполнена!")
        print(f"📊 Статистика:")
        print(f"   • Компаний: {len(company_ids)}")
        print(f"   • Переговорных: {sum(len(v) for v in company_rooms.values())}")
        print(f"   • Подразделений: {len(department_ids)}")
        print(f"   • Рекрутеров: {len(recruiter_ids)}")
        print(f"   • Навыков: {len(skill_ids)}")
        print(f"   • Вакансий: {NUM_VACANCIES}")
        print(f"   • Версий вакансий: {len(vacancy_version_ids)}")
        print(f"   • Соискателей: {len(applicant_ids)}")
        print(f"   • Версий резюме: {len(resume_version_ids)}")
        print(f"   • Откликов: {len(response_ids)}")
        print(f"   • Интервью: {len(interview_ids)}")


if __name__ == "__main__":
    try:
        seed_database()
    except psycopg2.Error as e:
        print(f"\n❌ Ошибка базы данных: {e}")
        print(f"   SQLSTATE: {getattr(e, 'pgcode', None)}")
        print(f"   Детали: {getattr(e, 'pgerror', None)}")
    except Exception as e:
        print(f"\n❌ Произошла ошибка: {e}")
        import traceback
        traceback.print_exc()