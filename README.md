# Смены — календарь рабочих смен (SwiftUI, iOS 16+)

Небольшое нативное приложение для iPhone: циклический график смен, ручные правки,
заметки по дням и статистика часов. Всё хранится локально в JSON, никаких серверов
и аккаунтов.

## Что умеет

- **Цикл смен** любой длины: 2/2, 3/3, 4/2, 1/3, своя последовательность — просто
  список типов смен, который повторяется от даты-якоря.
- **Календарь на месяц**: цветные метки смен, отметка «сегодня», точки-индикаторы
  ручных правок и заметок, свайп-навигация по месяцам кнопками.
- **Ручная правка дня**: поставить другую смену, отметить выходной, вернуть «по циклу».
- **Заметки** к любому дню (подмена, переработка, отпросился).
- **Типы смен** редактируются: название, короткое обозначение, цвет, начало и конец.
  Ночные смены (конец раньше начала) считаются через полночь.
- **Статистика за месяц**: количество смен, суммарные часы, выходные, разбивка по типам.
- **Напоминания** о смене в выбранное время (локальные уведомления).
- Русский интерфейс, светлая и тёмная тема, только iPhone, только портрет.

## Как получить .ipa без Mac (GitHub Actions)

Сборка идёт на macOS-раннере GitHub, результат — **unsigned .ipa**, который
подписывается твоим сертификатом в eSign.

1. Создай репозиторий на github.com (можно приватный), без README.
2. На странице репозитория: **Add file → Upload files**, перетащи туда **всё
   содержимое папки `shift-calendar`** (включая папки `.github` и `ShiftCalendar`).
   Commit.
   - Если папка `.github` не загрузилась: **Add file → Create new file**, имя
     `.github/workflows/build-ipa.yml`, и вставь содержимое одноимённого файла
     из проекта.
3. Вкладка **Actions** → если GitHub спросит, нажми
   *«I understand my workflows, go ahead and enable them»*.
4. Слева выбери **Build unsigned IPA** → **Run workflow** → **Run workflow**
   (или просто дождись автозапуска после коммита).
5. Через ~3–5 минут открой завершённый запуск, внизу раздел **Artifacts** →
   скачай `ShiftCalendar-unsigned-ipa.zip`.
6. Распакуй архив — внутри `ShiftCalendar-unsigned.ipa`.

## Как подписать в eSign

1. Открой eSign → **Import** / «+» → выбери `ShiftCalendar-unsigned.ipa`.
2. Укажи свой `.p12` + пароль и `.mobileprovision` (или готовый сертификат из
   хранилища eSign).
3. **Sign** → **Install**.

Важно:

- Если сертификат выпущен под конкретный Bundle ID, поменяй его в `project.yml`:
  `PRODUCT_BUNDLE_IDENTIFIER: com.example.shiftcalendar` → свой, затем пересобери.
- Для development-сертификата UDID iPhone должен быть в профиле.
- Подпись с бесплатным Apple ID живёт 7 дней, с платным — год. Переподписать можно
  тем же файлом `.ipa`, пересобирать не нужно.

## Сборка на Mac (если появится)

```bash
brew install xcodegen
xcodegen generate
open ShiftCalendar.xcodeproj
```

Дальше обычный Run на устройство (нужен свой Team в Signing & Capabilities).

## Структура

```
project.yml                        описание проекта для XcodeGen
Info.plist                         генерируется XcodeGen (в git не хранится)
.github/workflows/build-ipa.yml    CI: сборка unsigned .ipa
tools/make_icon.ps1                генератор иконки 1024×1024
ShiftCalendar/
  App/ShiftCalendarApp.swift       точка входа + AppDelegate уведомлений
  Models/ShiftType.swift           тип смены (цвет, время, длительность)
  Models/ShiftPattern.swift        цикл и правка дня
  Models/ScheduleData.swift        состояние + расчёт смены на дату
  Store/ScheduleStore.swift        хранение в JSON, мутации, статистика
  Notifications/ReminderScheduler.swift
  Support/Cal.swift                календарная математика, форматирование
  Support/Color+Hex.swift          цвета, палитра
  Views/…                          экраны и ячейки
  Assets.xcassets                  иконка и акцентный цвет
```

## Где что менять

| Что | Где |
|---|---|
| Название приложения на экране | `project.yml` → `CFBundleDisplayName` |
| Bundle ID | `project.yml` → `PRODUCT_BUNDLE_IDENTIFIER` |
| Дефолтный график (2/2, дневная/ночная) | `ScheduleData.makeDefault()` |
| Палитра цветов для смен | `Support/Color+Hex.swift` → `Palette.hexes` |
| Горизонт напоминаний (30 дней) | `ReminderScheduler.schedule` |

## Ограничения текущей версии

- Нет синхронизации с iCloud и экспорта.
- Учёт переработок/ночных надбавок не ведётся — только часы.
- Виджетов и Apple Watch нет.
