import psycopg2
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

# ================= КОЛИЧЕСТВО ДАННЫХ =================
NUM_COMPANIES = 50
NUM_DEPARTMENTS = 400
NUM_RECRUITERS = 4000
NUM_VACANCIES = 5000
NUM_SKILLS = 100
NUM_APPLICANTS = 7000
NUM_RESPONSES = 20000

# Диапазон количества версий
MIN_VERSIONS = 1
MAX_VERSIONS = 6


def get_id(cur, query, params):
    """Выполняет INSERT и возвращает сгенерированный ID"""
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

        # ================= 2. ПОДРАЗДЕЛЕНИЯ =================
        print(f"🏢 Создаем {NUM_DEPARTMENTS} подразделений...")
        department_ids = []

        for _ in range(NUM_DEPARTMENTS):
            # 30% шанс, что подразделение будет вложенным
            parent = random.choice(department_ids) if department_ids and random.random() < 0.3 else None

            did = get_id(cur, """
                INSERT INTO department (company_id, name, parent_id, head_full_name, status)
                VALUES (%s, %s, %s, %s, %s) RETURNING department_id
            """, (
                random.choice(company_ids),
                fake.bs(),
                parent,
                fake.name(),
                random.choice(['активно', 'не активно'])
            ))
            department_ids.append(did)

        # ================= 3. РЕКРУТЕРЫ =================
        print(f" 👥 Создаем {NUM_RECRUITERS} рекрутеров...")
        recruiter_ids = []

        for _ in range(NUM_RECRUITERS):
            rid = get_id(cur, """
                INSERT INTO recruiter (full_name, contacts, department_id, status)
                VALUES (%s, %s, %s, %s) RETURNING recruiter_id
            """, (
                fake.name(),
                f"{fake.phone_number()}, {fake.email()}",
                random.choice(department_ids),
                random.choice(['активен', 'не активен'])
            ))
            recruiter_ids.append(rid)

        # ================= 4. ПОЛНОМОЧИЯ РЕКРУТЕРОВ =================
        print("🔐 Создаем полномочия рекрутеров...")
        for rid in recruiter_ids:
            num_authorities = random.randint(1, 3)
            for _ in range(num_authorities):
                date_from = fake.date_object()
                date_to = date_from + timedelta(days=random.randint(30, 365))

                get_id(cur, """
                    INSERT INTO recruiter_authority (recruiter_id, object, role, date_from, date_to, status)
                    VALUES (%s, %s, %s, %s, %s, %s) RETURNING authority_id
                """, (
                    rid,
                    fake.word(),
                    fake.job(),
                    date_from,
                    date_to,
                    random.choice(['действует', 'истекло', 'отозвано'])
                ))

        # ================= 5. ТАРИФЫ =================
        print("💳 Создаем тарифы для компаний...")
        for company_id in company_ids:
            num_tariffs = random.randint(1, 4)
            for _ in range(num_tariffs):
                date_from = fake.date_object()

                get_id(cur, """
                    INSERT INTO employer_tariff (company_id, name, rate, unit, date_from, date_to, status)
                    VALUES (%s, %s, %s, %s, %s, %s, %s) RETURNING tariff_id
                """, (
                    company_id,
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

        for _ in range(NUM_VACANCIES):
            vid = get_id(cur, """
                INSERT INTO vacancy (position_name, company_id, department_id, conditions, publish_status)
                VALUES (%s, %s, %s, %s, %s) RETURNING vacancy_id
            """, (
                fake.job(),
                random.choice(company_ids),
                random.choice(department_ids),
                fake.text(max_nb_chars=150),
                random.choice(['активна', 'закрыта'])
            ))

            # Случайное количество версий для каждой вакансии
            num_versions = random.randint(MIN_VERSIONS, MAX_VERSIONS)

            for version_num in range(1, num_versions + 1):
                status = 'текущая' if version_num == num_versions else 'устаревшая'

                vvid = get_id(cur, """
                    INSERT INTO vacancy_version (vacancy_id, version_number, changed_by, change_reason, status)
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

                # Добавляем случайное количество требований навыков
                num_skills = random.randint(2, min(6, len(skill_ids)))
                required_skills = random.sample(skill_ids, k=num_skills)

                for sid in required_skills:
                    cur.execute("""
                        INSERT INTO vacancy_skill_requirement (vacancy_version_id, skill_id, required_level, is_mandatory, comment)
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
        resume_version_ids = []

        for aid in applicant_ids:
            # Каждый соискатель имеет 1-3 резюме
            num_resumes = random.randint(1, 3)

            for _ in range(num_resumes):
                rid = get_id(cur, """
                    INSERT INTO resume (applicant_id, name, desired_position, status)
                    VALUES (%s, %s, %s, %s) RETURNING resume_id
                """, (
                    aid,
                    f"Резюме {fake.word()}",
                    fake.job(),
                    random.choice(['опубликовано', 'скрыто'])
                ))

                # Случайное количество версий для каждого резюме
                num_versions = random.randint(MIN_VERSIONS, MAX_VERSIONS)

                for version_num in range(1, num_versions + 1):
                    status = 'текущая' if version_num == num_versions else 'устаревшая'

                    rvid = get_id(cur, """
                        INSERT INTO resume_version (resume_id, version_number, changed_by, change_reason, status)
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

                    # Добавляем случайное количество навыков
                    num_skills = random.randint(3, min(8, len(skill_ids)))
                    resume_skills = random.sample(skill_ids, k=num_skills)

                    for sid in resume_skills:
                        cur.execute("""
                            INSERT INTO resume_skill (resume_version_id, skill_id, level, experience, comment)
                            VALUES (%s, %s, %s, %s, %s)
                        """, (
                            rvid,
                            sid,
                            random.randint(1, 5),
                            random.randint(0, 15),
                            fake.text(max_nb_chars=50) if random.random() < 0.5 else None
                        ))

                    resume_version_ids.append((rvid, aid))

        # ================= 10. ОТКЛИКИ =================
        print(f"📨 Создаем {NUM_RESPONSES} откликов...")
        response_ids = []
        STAGES = ['получен', 'просмотрен', 'приглашен', 'интервью',
                  'тестовое задание', 'отказ', 'предложение']

        # Генерируем даты откликов за последний год
        base_date = datetime.now() - timedelta(days=365)

        for _ in range(NUM_RESPONSES):
            rvid, aid = random.choice(resume_version_ids)
            vvid = random.choice(vacancy_version_ids)
            current_stage = random.choice(STAGES)
            status = 'завершён' if current_stage in ['отказ', 'предложение'] else 'активен'

            # Случайная дата отклика за последний год
            created_at = base_date + timedelta(
                days=random.randint(0, 365),
                hours=random.randint(0, 23),
                minutes=random.randint(0, 59)
            )

            resp_id = get_id(cur, """
                INSERT INTO response (applicant_id, resume_version_id, vacancy_version_id,
                                     current_stage, status, created_at)
                VALUES (%s, %s, %s, %s, %s, %s) RETURNING response_id
            """, (aid, rvid, vvid, current_stage, status, created_at))
            response_ids.append((resp_id, aid, current_stage))

        # ================= 11. ЭТАПЫ ОТКЛИКОВ =================
        print("📊 Создаем этапы откликов...")
        for resp_id, aid, current_stage in response_ids:
            # Получаем дату создания отклика
            cur.execute("SELECT created_at FROM response WHERE response_id = %s", (resp_id,))
            response_created_at = cur.fetchone()[0]

            # Создаем 1-5 этапов для каждого отклика
            num_stages = random.randint(1, 9)
            stage_date = response_created_at

            for _ in range(num_stages):
                stage_type = random.choice(STAGES)
                date_from = stage_date + timedelta(hours=random.randint(1, 48))
                date_to = date_from + timedelta(hours=random.randint(1, 168)) if random.random() < 0.7 else None

                cur.execute("""
                            INSERT INTO response_stage (response_id, recruiter_id, stage_type, date_from, date_to, result)
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
        print("🎤 Создаем интервью...")
        interview_ids = []

        # Создаем интервью для 40% откликов
        for resp_id, aid, current_stage in response_ids:
            if random.random() < 0.4:
                start_time = fake.date_time_between(start_date='-1M', end_date='+1M')
                end_time = start_time + timedelta(hours=random.randint(1, 3))

                iid = get_id(cur, """
                    INSERT INTO interview (response_id, applicant_id, start_at, end_at, format, result, status)
                    VALUES (%s, %s, %s, %s, %s, %s, %s) RETURNING interview_id
                """, (
                    resp_id,
                    aid,
                    start_time,
                    end_time,
                    random.choice(['Онлайн', 'Офлайн', 'Телефон']),
                    fake.text(max_nb_chars=100) if random.random() < 0.7 else None,
                    random.choice(['запланировано', 'завершено', 'отменено'])
                ))

                # Добавляем 1-4 участников
                num_participants = random.randint(1, min(4, len(recruiter_ids)))
                participants = random.sample(recruiter_ids, k=num_participants)

                for rec_id in participants:
                    cur.execute("""
                        INSERT INTO interview_participant (interview_id, recruiter_id)
                        VALUES (%s, %s)
                    """, (iid, rec_id))

                interview_ids.append(iid)

        # ================= 13. ПРЕДЛОЖЕНИЯ О РАБОТЕ =================
        print("💼 Создаем предложения о работе...")
        for resp_id, aid, current_stage in response_ids:
            # Создаем предложение для 20% откликов
            if random.random() < 0.2:
                offer_date = fake.date_object()

                get_id(cur, """
                    INSERT INTO job_offer (response_id, offer_date, position, conditions, response_deadline, status)
                    VALUES (%s, %s, %s, %s, %s, %s) RETURNING offer_id
                """, (
                    resp_id,
                    offer_date,
                    fake.job(),
                    fake.text(max_nb_chars=150),
                    offer_date + timedelta(days=random.randint(3, 14)),
                    random.choice(['отправлено', 'принято', 'отклонено', 'истекло', 'отозвано', 'устаревшее'])
                ))

        conn.commit()
        print("\n✅ База данных успешно заполнена!")
        print(f"📊 Статистика:")
        print(f"   • Компаний: {len(company_ids)}")
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
    except Exception as e:
        print(f"\n❌ Произошла ошибка: {e}")
        import traceback

        traceback.print_exc()