# Выпуск игры «BATTLE BUT WITH ADMIN PANEL»

Все картинки лежат в папке `release/`:

| Файл | Куда загружать |
|---|---|
| `GameIcon.png` (512×512) | Иконка игры |
| `Thumbnail_1_Title.png`, `Thumbnail_2_AdminPanel.png` (1920×1080) | Обложки (Thumbnails) игры |
| `GamePass_VIP.png`, `GamePass_ADMIN.png` (512×512) | Картинки геймпассов VIP и ADMIN. Roblox показывает их кругом, картинки уже нарисованы под круг |
| `Ticket_x1.png` … `Ticket_x20.png` (512×512) | Картинки донатов-тикетов (Developer Products) |

## 1. Опубликовать место

1. Откройте `BattleAdminPanel_v6.rbxlx` в Roblox Studio.
2. Выберите **File → Publish to Roblox As…**, создайте новый опыт и назовите его `BATTLE BUT WITH ADMIN PANEL`.
3. Дождитесь сообщения, что публикация прошла.

## 2. Настроить игру (Creator Dashboard → ваша игра)

- **Basic Info.** Загрузите иконку `GameIcon.png` и обе обложки. Жанр — Strategy или Fighting, устройства — все.
- **Описание** (можно вставить как есть):

  > Build your army, fight other players… and every 2 minutes someone gets the ADMIN PANEL! Type ANY command: "meteor on the enemy base", "heal my army", "summon 3 giants"… Then the roulette decides: EXECUTE it, or EVERYONE ADDS to it!
  > Строй армию, сражайся — и каждые 2 минуты кто-то получает АДМИН-ПАНЕЛЬ! Пиши любую команду, а рулетка решит: выполнить её или все допишут своё!

- **Places → Configure → Max Players:** поставьте `18` (3 комнаты по 6 игроков).
- **Security:** включите **Enable Studio Access to API Services**. Без этого в Studio не сохраняются покупки и тикеты. В опубликованной игре сохранение работает и так.
- **Maturity & Compliance:** заполните анкету. В игре есть пользовательский текст, но он проходит фильтр Roblox (TextService).

## 3. Музыка заставки

Аудио `132472169476353` должно быть доступно этой игре. Проверьте это в Creator Dashboard → **Development Items → Audio → ваш трек → Permissions**: там должен быть ваш опыт (или трек должен быть публичным).

Если игра принадлежит группе, а трек загружен с личного аккаунта, добавьте в Permissions ID этой игры. Иначе заставка пойдёт без звука: анимация всё равно работает, просто тихо.

## 4. Геймпассы (Monetization → Passes)

Создайте 2 пасса:

| Название | Картинка | Цена (рекомендую) | Описание |
|---|---|---|---|
| VIP | `GamePass_VIP.png` | 299 R$ | Always gets the FIRST admin panel of the round, +1 ticket every round, [VIP] tag |
| ADMIN | `GamePass_ADMIN.png` | 999 R$ | +10 tickets every round, +20% chance to get the admin panel, [ADMIN] tag |

После создания откройте пасс, включите **Sale → On Sale**, поставьте цену и скопируйте его **ID** (число из ссылки или со страницы пасса).

## 5. Тикеты (Monetization → Developer Products)

Создайте 5 продуктов:

| Название | Картинка | Цена (рекомендую) |
|---|---|---|
| 1 Ticket | `Ticket_x1.png` | 25 R$ |
| 3 Tickets | `Ticket_x3.png` | 69 R$ |
| 7 Tickets | `Ticket_x7.png` | 149 R$ |
| 10 Tickets | `Ticket_x10.png` | 199 R$ |
| 20 Tickets | `Ticket_x20.png` | 349 R$ |

Скопируйте **ID** каждого продукта.

## 6. Вставить ID в игру

1. В Studio откройте **ReplicatedStorage → ArmyRoundShared → DonationCatalog**.
2. Замените `id=0` на ваши числа:

   ```lua
   {key='VIP',kind='Pass',id=123456789, ...
   {key='Admin',kind='Pass',id=123456790, ...
   {key='Ticket1',kind='Product',id=1234567, ...
   {key='Ticket3',kind='Product',id=1234568, ...
   {key='Ticket7',kind='Product',id=1234569, ...
   {key='Ticket10',kind='Product',id=1234570, ...
   {key='Ticket20',kind='Product',id=1234571, ...
   ```

   `price` можно не трогать. Магазин сам подтягивает настоящую цену из Roblox.
3. Снова выполните **File → Publish to Roblox**.

Пока ID равен `0`, в опубликованной игре товар показан как `SOON`, а в Studio — `TEST` (бесплатная тестовая выдача).

## 7. Проверка перед открытием

- **Покупки в Studio** (Play): с настоящими ID Roblox показывает тестовое окно покупки, Robux не списываются. Проверьте:
  - VIP и ADMIN дают теги и тикеты в раунде;
  - тикеты прибавляются в кошельке магазина.
- **Телефоны:** Test → Device (эмулятор телефона). Проверьте заставку, магазин и зум двумя пальцами в раунде.
- **Несколько игроков:** Test → Clients and Servers → 2–3 игрока. Проверьте:
  - комнаты 0/6;
  - админ-панель: ник цветом и текст команды, рулетка;
  - «все дописывают».
- **Открытие для всех:** Creator Dashboard → игра → **Make Public**.

## Как устроены донаты в коде (для справки)

- `DonationCatalog`: список товаров и правила (VIP +1 тикет, ADMIN +10 тикетов и +20% шанс).
- `DonationServer`:
  - проверяет владение пассами;
  - принимает покупки продуктов через `ProcessReceipt`, каждый чек учитывается один раз;
  - хранит тикеты в DataStore `BattleAdminVault_v2`.
- `Perks`: выдаёт перки и тикеты раунду.
- Магазин открывается кнопкой с короной справа на экране (в лобби).
