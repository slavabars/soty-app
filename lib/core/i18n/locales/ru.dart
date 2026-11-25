part of '../soty_l10n.dart';

const Map<String, String> _ru = {
  'File': 'Файл',
  'Attach': 'Прикрепить',
  'Take photo': 'Сделать фото',
  'Record video': 'Записать видео',
  'Recording… {time}': 'Запись… {time}',
  'Save file': 'Сохранить файл',
  'File saved to {path}': 'Файл сохранён в {path}',
  'Failed to save file': 'Не удалось сохранить файл',
  'File is too large (max {mb} MB)': 'Файл слишком большой (макс. {mb} МБ)',
  'The sender is offline. The file will download when they return.':
      'Отправитель не в сети. Файл загрузится, когда он вернётся.',
  'Waiting for a group member to share this file':
      'Ожидание участника группы, у которого уже есть файл',
  'Video saved to {path}': 'Видео сохранено в {path}',
  'Failed to save video': 'Не удалось сохранить видео',
  'Save video': 'Сохранить видео',
  'Receiving': 'Получение',
  'Transfer cancelled': 'Передача отменена',
  'Cancel transfer': 'Отменить передачу',
  'Video is too large (max {mb} MB)': 'Видео слишком большое (макс. {mb} МБ)',
  'Unsupported video format': 'Неподдерживаемый формат видео',
  'Video unavailable': 'Видео недоступно',
  'Video': 'Видео',
  'Send': 'Отправить',
  'You are no longer a member of this group.':
      'Вы больше не участник этой группы.',
  'You': 'Вы',
  'Group info': 'Информация о группе',
  'Members': 'Участники',
  'Admin': 'Админ',
  'Member': 'Участник',
  'Add member': 'Добавить участника',
  'Remove member': 'Удалить участника',
  'Make admin': 'Сделать админом',
  'Remove admin': 'Снять админа',
  'Only admins can change this group.':
      'Менять группу могут только админы.',
  '{actor} added {name}': '{actor} добавил(а) {name}',
  '{actor} removed {name}': '{actor} удалил(а) {name}',
  '{actor} made {name} an admin': '{actor} сделал(а) {name} админом',
  '{actor} removed admin rights from {name}':
      '{actor} снял(а) права админа с {name}',
  'Could not update the group.': 'Не удалось обновить группу.',
  'Not sent ({n})': 'Не отправлено ({n})',
  'No connection — Soty will retry when the peer is reachable.':
      'Нет связи — Soty повторит отправку, когда получатель станет доступен.',
  'Search': 'Поиск',
  'Search messages': 'Поиск сообщений',
  'Search in this chat': 'Поиск в этом чате',
  'No messages found': 'Сообщения не найдены',
  'Type to search your messages.':
      'Начните вводить текст для поиска.',
  'All': 'Все',
  'Photos': 'Фото',
  'Voice': 'Голосовые',
  'Unread': 'Непрочитанные',
  'The new version is signed with a different key. Save a backup, '
  'uninstall Soty, then install the new release by hand and restore '
  'the backup.':
      'Новая версия подписана другим ключом. Сделайте '
      'резервную копию, удалите Soty, '
      'установите новый выпуск вручную и восстановите копию.',
  'Backup': 'Резервная копия',
  'Export backup': 'Экспорт резервной копии',
  'Encrypted file with your identity, contacts and messages.':
      'Зашифрованный файл с вашей личностью, контактами и сообщениями.',
  'Restore backup': 'Восстановление из копии',
  'Replace the identity, contacts and messages on '
  'this device from a backup file.':
      'Заменить личность, контакты и сообщения на этом устройстве '
      'из файла копии.',
  'Backup password': 'Пароль копии',
  'Password must be at least {n} characters':
      'Пароль должен быть не короче {n} символов',
  'Backup created: {path}': 'Копия создана: {path}',
  'Backup restored': 'Копия восстановлена',
  'Wrong password or damaged backup file':
      'Неверный пароль или повреждённый файл копии',
  'Restore this backup?': 'Восстановить эту копию?',
  'This replaces your identity, contacts and messages and restarts Soty.':
      'Это заменит вашу личность, контакты и сообщения и перезапустит Soty.',
  'Restore': 'Восстановить',
  'Picking a file is not supported on this platform':
      'Выбор файла не поддерживается на этой платформе',
  'Backup failed': 'Не удалось создать копию',
  'Export': 'Экспорт',
  'Copy code': 'Копировать код',
  'Could not verify this contact':
      'Не удалось отметить контакт проверенным',
  'Safety number': 'Код безопасности',
  'Compare this code with {name} in person or over a trusted channel.':
      'Сравните этот код с {name} при встрече или по доверенному каналу.',
  'Not verified': 'Не проверено',
  'Verified': 'Проверено',
  'Security code changed': 'Код безопасности изменился',
  '{name} presented a new key. Compare the new code before trusting this '
      'chat.':
      '{name} предъявил новый ключ. Сравните новый код, прежде чем доверять '
      'этому чату.',
  'Mark as verified': 'Отметить как проверенный',
  'Scan their code': 'Сканировать код',
  'Safety codes match': 'Коды безопасности совпадают',
  'Safety codes do not match': 'Коды безопасности не совпадают',
  'Safety code unavailable': 'Код безопасности недоступен',
  'This contact has not published an Ed25519 key yet.':
      'Этот контакт ещё не опубликовал ключ Ed25519.',
  'Failed to save photo': 'Не удалось сохранить фото',
  'Photo saved to {path}': 'Фото сохранено в {path}',
  'Messaging with no server and no account. Pick a display name — it is '
      'signed into the invite other Soty users import to reach you.':
      'Без сервера и без аккаунта. Выберите отображаемое имя — оно '
      'подписывается в приглашение, которое другие пользователи Soty '
      'импортируют, чтобы написать вам.',
  'Display name': 'Отображаемое имя',
  'Roll another name': 'Предложить другое имя',
  'Continue': 'Продолжить',
  'You can change your name later in the identity screen.':
      'Имя можно изменить позже на экране личности.',
  'Cancel': 'Отмена',
  'Save': 'Сохранить',
  'Invite copied to clipboard': 'Приглашение скопировано в буфер обмена',
  'Import invite': 'Импортировать приглашение',
  'Paste the invite JSON here': 'Вставьте сюда приглашение JSON',
  'Import': 'Импорт',
  'Peer imported': 'Пир импортирован',
  'Invite rejected': 'Приглашение отклонено',
  'Import contact': 'Импортировать контакт',
  'Paste invite JSON': 'Вставить JSON-приглашение',
  'Enter manually': 'Ввести вручную',
  'Unknown contact — import it first to reply.':
      'Неизвестный контакт — сначала импортируйте его, '
      'чтобы ответить.',
  'Add peer': 'Добавить пира',
  'Peer X25519 public key (hex)':
      'Открытый X25519-ключ пира (hex)',
  'Peer X25519 public key (hex) *':
      'Открытый X25519-ключ пира (hex) *',
  'Name (optional)': 'Имя (необязательно)',
  'libp2p peer id (optional)': 'libp2p peer id (необязательно)',
  'Multiaddr (optional, e.g. /ip4/…/tcp/4001)':
      'Multiaddr (необязательно, напр. /ip4/…/tcp/4001)',
  'Multiaddr (optional)': 'Multiaddr (необязательно)',
  'Public key must be 64 hex characters':
      'Открытый ключ должен содержать 64 hex-символа',
  'Add': 'Добавить',
  'Identity': 'Личность',
  'Unnamed': 'Без имени',
  'Ed25519 (identity / signing)': 'Ed25519 (личность / подпись)',
  'X25519 (address peers send to)': 'X25519 (адрес для сообщений)',
  'Copy invite': 'Скопировать приглашение',
  'Signed identity claim — paste it to import your key.':
      'Подписанное заявление личности — вставьте, чтобы импортировать ваш '
      'ключ.',
  'Paste a friend’s signed invite to add them.':
      'Вставьте подписанное приглашение друга, чтобы добавить его.',
  'Add a peer': 'Добавить пира',
  'Paste their X25519 key (+ optional libp2p address) to start a '
      'conversation.':
      'Вставьте их X25519-ключ (+ необязательный libp2p-адрес), чтобы начать '
      'переписку.',
  'Pruning': 'Очистка истории',
  'Retention & integrity roots.': 'Хранение и корни целостности.',
  'Public key copied': 'Открытый ключ скопирован',
  'Pruning integrity roots': 'Корни целостности очистки',
  'No batches pruned yet.': 'Пока ничего не очищено.',
  'Cutoff {ts}': 'Граница {ts}',
  'count: {n}\n{root}': 'количество: {n}\n{root}',
  'count: {n}\n{root}|one': 'количество: {n}\n{root}',
  'count: {n}\n{root}|few': 'количество: {n}\n{root}',
  'count: {n}\n{root}|many': 'количество: {n}\n{root}',
  'count: {n}\n{root}|other': 'количество: {n}\n{root}',
  'New chat': 'Новый чат',
  'Start': 'Начать',
  'Invalid public key': 'Недействительный открытый ключ',
  'Chats': 'Чаты',
  'No conversations yet.\nAdd a peer to start.':
      'Пока нет диалогов.\nДобавьте пира, чтобы начать.',
  'online': 'на связи',
  'offline': 'не в сети',
  'last seen just now': 'был(а) только что',
  'last seen {n} min ago': 'был(а) {n} мин назад',
  'last seen {n} min ago|one': 'был(а) {n} минуту назад',
  'last seen {n} min ago|few': 'был(а) {n} минуты назад',
  'last seen {n} min ago|many': 'был(а) {n} минут назад',
  'last seen {n} h ago': 'был(а) {n} ч назад',
  'last seen {n} h ago|one': 'был(а) {n} час назад',
  'last seen {n} h ago|few': 'был(а) {n} часа назад',
  'last seen {n} h ago|many': 'был(а) {n} часов назад',
  'last seen {n} d ago': 'был(а) {n} дн назад',
  'last seen {n} d ago|one': 'был(а) {n} день назад',
  'last seen {n} d ago|few': 'был(а) {n} дня назад',
  'last seen {n} d ago|many': 'был(а) {n} дней назад',
  'No messages yet.': 'Сообщений пока нет.',
  'Text message': 'Текстовое сообщение',
  'Message exceeds the 4 KB limit': 'Сообщение превышает лимит 4 КБ',
  'Message could not be sent': 'Сообщение не удалось отправить',
  'Reply': 'Ответить',
  'Forward': 'Переслать',
  'Copy': 'Копировать',
  'Share': 'Поделиться',
  'Copied': 'Скопировано',
  'Forward to': 'Переслать в',
  'Group': 'Группа',
  'No conversations yet.': 'Нет бесед',
  'Recent': 'Недавние',
  'Emoji': 'Эмодзи',
  'No recent emoji': 'Нет недавних эмодзи',
  'Smileys & emotion': 'Смайлики и эмоции',
  'People & gestures': 'Люди и жесты',
  'Animals & nature': 'Животные и природа',
  'Food & drink': 'Еда и напитки',
  'Travel & places': 'Путешествия и места',
  'Activities': 'Занятия',
  'Objects': 'Предметы',
  'Symbols': 'Символы',
  'Peers': 'Пиры',
  'Rename chat': 'Переименовать чат',
  'Rename contact': 'Переименовать контакт',
  'No contacts yet.\nImport an invite to start.':
      'Пока нет контактов.\nИмпортируйте инвайт, чтобы начать.',
  'Chat name': 'Имя чата',
  'Name updated': 'Имя обновлено',
  'Unlock Soty': 'Разблокировать Soty',
  'Soty is locked': 'Soty заблокирован',
  'Enter your password to continue.': 'Введите пароль, чтобы продолжить.',
  'Password': 'Пароль',
  'Incorrect password': 'Неверный пароль',
  'Unlock with fingerprint': 'Разблокировать отпечатком пальца',
  'Unlock': 'Разблокировать',
  'Invite link copied to clipboard':
      'Ссылка на приглашение скопирована',
  'My QR code': 'Мой QR-код',
  'Copy invite link': 'Скопировать ссылку-приглашение',
  'No identity yet.': 'Личности ещё нет.',
  'Others add you by scanning this code from Settings → Scan QR code.':
      'Другие добавят вас, отсканировав этот код из Настройки → '
      'Сканировать QR-код.',
  'Copy invite text': 'Скопировать текст приглашения',
  'Retry': 'Повторить',
  'Scan QR code': 'Сканировать QR-код',
  'Point the camera at a Soty contact QR code.':
      'Наведите камеру на QR-код контакта Soty.',
  'Camera unavailable. Allow camera permission and retry.':
      'Камера недоступна. Разрешите доступ и повторите попытку.',
  'Contact added from QR code': 'Контакт добавлен из QR-кода',
  'Invalid host link': 'Неверная ссылка на хост',
  'Relay host added': 'Ретрансляционный хост добавлен',
  'Relay host list is full (max {max})':
      'Список ретрансляционных хостов переполнен (макс. {max})',
  'Add relay host': 'Добавить ретрансляционный хост',
  'Disable app lock': 'Отключить блокировку приложения',
  'Enter your current password.': 'Введите текущий пароль.',
  'Current password': 'Текущий пароль',
  'Confirm your current password.': 'Подтвердите текущий пароль.',
  'Biometrics are not available on this device':
      'Биометрия недоступна на этом устройстве',
  'Enable fingerprint unlock': 'Включить разблокировку отпечатком',
  'Enter your password to confirm.': 'Введите пароль для подтверждения.',
  'Set app lock password': 'Задайте пароль блокировки',
  'Enable lock': 'Включить блокировку',
  'Confirm': 'Подтвердить',
  'Settings': 'Настройки',
  'Contact': 'Контакты',
  'Show this code so others can add you.':
      'Покажите этот код, чтобы другие могли вас добавить.',
  'Add a contact by scanning their code.':
      'Добавьте контакт, отсканировав его код.',
  'Paste the invite instead of a QR.': 'Вставьте приглашение вместо QR.',
  'A soty:// link that opens Soty to add you.':
      'Ссылка soty://, которая открывает Soty для добавления вас.',
  'Security': 'Безопасность',
  'App lock': 'Блокировка приложения',
  'Require a password to open Soty.': 'Требовать пароль для открытия Soty.',
  'Change password': 'Сменить пароль',
  'Fingerprint unlock': 'Разблокировка отпечатком',
  'Unlock with biometrics instead of typing the password.':
      'Разблокировка по биометрии вместо ввода пароля.',
  'Network': 'Сеть',
'Peers in network': 'Пиров в сети',
'{n} registered · {online} online':
    '{n} зарегистрировано · {online} онлайн',
'Active connections': 'Активные соединения',
  appLockResetNotice:
      'Блокировка сброшена: сохранённый пароль повреждён. '
      'Задайте его заново в настройках.',
'{n} visible · {connected} connected':
    '{n} видимых · подключено {connected}',
'{n} of {max} direct peers in exchange':
    '{n} из {max} прямых пиров в обмене',
'About': 'О приложении',
'Version': 'Версия',
'Source and releases': 'Исходный код и релизы',
'Link copied to clipboard':
    'Ссылка скопирована в буфер обмена',
  'Active peers limit': 'Лимит активных пиров',
  'Keep at most {n} direct peers connected.':
      'Держите не более {n} прямых соединений с пирами.',
  'Keep at most {n} direct peers connected.|one':
      'Держите не более {n} прямого соединения с пиром.',
  'Keep at most {n} direct peers connected.|few':
      'Держите не более {n} прямых соединений с пирами.',
  'Keep at most {n} direct peers connected.|many':
      'Держите не более {n} прямых соединений с пирами.',
  'Keep at most {n} direct peers connected.|other':
      'Держите не более {n} прямых соединений с пирами.',
  'Relay hosts': 'Ретрансляционные хосты',
  'Connected': 'Подключено',
  'Offline': 'Не в сети',
  'Remove host': 'Удалить хост',
  'Paste a ws:// URL or a soty:// host link.':
      'Вставьте ws:// URL или ссылку soty:// на хост.',
  'Tracker discovery': 'Обнаружение через трекеры',
  'Peers found via trackers: {n}.': 'Пиры, найденные через трекеры: {n}.',
  'Peers found via trackers: {n}.|one':
      'Пир, найденный через трекеры: {n}.',
  'Peers found via trackers: {n}.|few':
      'Пира, найденных через трекеры: {n}.',
  'Peers found via trackers: {n}.|many':
      'Пиров, найденных через трекеры: {n}.',
  'Peers found via trackers: {n}.|other':
      'Пиров, найденных через трекеры: {n}.',
  'How many direct peers the device keeps available at once. Raise it for '
      'dense meshes; lower it to save battery and traffic.':
      'Сколько прямых пиров устройство держит одновременно. Увеличьте для '
      'плотных сетей; уменьшите для экономии батареи и трафика.',
  'Apply': 'Применить',
  'Use {min}–{max} characters': 'Используйте от {min} до {max} символов',
  'Passwords do not match': 'Пароли не совпадают',
  'Repeat password': 'Повторите пароль',
  'A relay host stores only encrypted envelopes. Anyone running one can see '
      'who talks to whom, so use hosts you trust.':
      'Ретрансляционный хост хранит только зашифрованные конверты. Любой '
      'оператор видит, кто с кем общается, поэтому используйте доверенные '
      'хосты.',
  'Host': 'Хост',
  'ws://host:port/ws or soty://host?addr=…':
      'ws://host:port/ws или soty://host?addr=…',
  'Appearance': 'Оформление',
  'Language': 'Язык',
  'Theme': 'Тема',
  'System': 'Системная',
  'Light': 'Светлая',
  'Dark': 'Тёмная',
  'Failed to start Soty:\n{error}': 'Не удалось запустить Soty:\n{error}',
  'Invalid relay host link': 'Неверная ссылка на хост',
  'Relay host list is full': 'Список ретрансляционных хостов переполнен',
  'Invalid invite link': 'Неверная ссылка на приглашение',
  'Insecure or expired invite': 'Ненадёжное или устаревшее приглашение',
  'Messages': 'Сообщения',
  'Encrypted message': 'Зашифрованное сообщение',
  'Send with Enter': 'Отправлять по Enter',
  'Press Enter to send; turn it off to add a new line.':
      'Нажмите Enter, чтобы отправить; выключите, чтобы перенести строку.',
  'Storage': 'Хранилище',
  'Keep messages': 'Хранить сообщения',
  'Save sent messages': 'Сохранять исходящие сообщения',
  'Relay failover': 'Переключение ретрансляторов',
  'Only configured relays': 'Только прописанные ретрансляторы',
  'Automatic fallback': 'Автоматическая замена',
  'Never use relays learned from trackers.':
      'Не использовать релеи, узнанные из трекеров.',
  'Use relays learned from hosts when the configured ones '
      'are unreachable.':
      'Использовать релеи с хостов, если прописанные недоступны.',
  'Keep my sent messages on this device so they stay readable after '
      'restart': 'Хранить мои сообщения на этом устройстве, чтобы они '
          'оставались читаемыми после перезапуска',
  'How long your own conversations stay on this device. Envelopes you only '
      'relay for others are always pruned after 30 days (capped at 10 GB).':
      'Как долго ваши переписки хранятся на устройстве. Конверты, которые вы '
      'только ретранслируете для других, всегда удаляются через 30 дней '
      '(до 10 ГБ).',
  '{n} days': '{n} дн.',
  '{n} days|one': '{n} день',
  '{n} days|few': '{n} дня',
  '{n} days|many': '{n} дней',
  '{n} days|other': '{n} дней',
  'Forever': 'Всегда',
  'New group': 'Новая группа',
  'Group name': 'Название группы',
  'Members: {n}': 'Участников: {n}',
  'Members: {n}|one': 'Участник: {n}',
  'Members: {n}|few': 'Участника: {n}',
  'Members: {n}|many': 'Участников: {n}',
  'Members: {n}|other': 'Участников: {n}',
  'Create': 'Создать',
  'Add peers first.': 'Сначала добавьте контакты.',
  'Notifications': 'Уведомления',
  'Message notifications': 'Уведомления о сообщениях',
  'Enabled on this device': 'Включены на этом устройстве',
  'Blocked by the system': 'Заблокированы системой',
  'Not available: {reason}': 'Недоступно: {reason}',
  'Not supported on this platform': 'Не поддерживается на этой платформе',
  'Checking notification support…': 'Проверяем поддержку уведомлений…',
  'Open system notification settings':
      'Открыть системные настройки уведомлений',
  'Send test notification': 'Отправить тестовое уведомление',
  'Test notification sent': 'Тестовое уведомление отправлено',
  'Notifications are blocked by the system':
      'Уведомления заблокированы системой',
  'Test notification failed: {reason}':
      'Не удалось отправить тестовое уведомление: {reason}',
  'Test notification': 'Тестовое уведомление',
  'Open': 'Открыть',
  'Mesh (BLE/Wi-Fi Direct)': 'Меш (BLE/Wi-Fi Direct)',
  '{n} nodes in range': '{n} узлов в зоне действия',
  'Off': 'Выкл.',
  'Permission required': 'Требуется разрешение',
  'Unavailable': 'Недоступно',
  'Background': 'Фоновая работа',
  'Work in background': 'Работать в фоне',
  'Keep mesh and relays alive while the app is not in the chat':
      'Держать меш и релеи активными, когда вы не в чате',
  'Battery optimization': 'Оптимизация батареи',
  'No restrictions': 'Без ограничений',
  'Restricted by the system': 'Ограничена системой',
  'Checking…': 'Проверка…',

  'Read receipts': 'Уведомления о прочтении',
  'Send read receipts so others know when you have read their messages.':
      'Отправлять собеседникам, когда вы прочитали их сообщения.',
  'Sending': 'Отправка',
  'Sent': 'Отправлено',
  'Delivered': 'Доставлено',
  'Read': 'Прочитано',
  'Update available': 'Доступно обновление',
  'Version {v} is available': 'Доступна версия {v}',
  'Download': 'Скачать',
  'Install': 'Установить',
  'Hide': 'Скрыть',
  'Remind later': 'Напомнить позже',
  'Allow Soty to install apps, then tap Install again.':
      'Разрешите Soty устанавливать приложения, затем нажмите «Установить» ещё '
      'раз.',
  'Download failed': 'Не удалось скачать',
  'The downloaded file failed its checksum check':
      'Загруженный файл не прошёл проверку контрольной суммы',
  'Check for updates': 'Проверить обновления',
  'Could not check for updates': 'Не удалось проверить обновления',
  'You have the latest version': 'У вас последняя версия',
  'Current version: {v}': 'Текущая версия: {v}',
  'Release notes': 'Что нового',
  'Close': 'Закрыть',
  'Voice message': 'Голосовое сообщение',
  'Photo': 'Фото',
  'Recording… {s} s left': 'Запись… осталось {s} с',
  'Photo is too large (max {kb} KB)':
      'Фото слишком большое (максимум {kb} КБ)',
  'Voice message is too short': 'Голосовое сообщение слишком короткое',
  'Voice message is too large': 'Голосовое сообщение слишком большое',
  'Microphone permission is required': 'Нужен доступ к микрофону',
  'Recording failed': 'Не удалось записать',
  'Voice message failed': 'Не удалось воспроизвести голосовое сообщение',
  'Photo unavailable': 'Фото недоступно',
  'Unsupported photo format': 'Неподдерживаемый формат фото',
  'Play voice message': 'Воспроизвести голосовое сообщение',
  'Stop': 'Остановить',
  'Not delivered yet ({n})':
      'Пока не доставлено ({n})',
  'Message not delivered yet — Soty will retry when the peer is '
  'reachable.':
      'Сообщение пока не доставлено — Soty повторит попытку, когда '
      'получатель станет доступен.',
  'Report abuse': 'Пожаловаться',
  'Opens the report form on soty.su in a browser':
      'Откроет форму жалобы на soty.su в браузере',
  'Link copied': 'Ссылка скопирована',
  'Block contact': 'Заблокировать контакт',
  'Messages from this contact are ignored and never decrypted.':
      'Сообщения от этого контакта игнорируются и не расшифровываются.',
  'You blocked this contact. Unblock it in the safety screen.':
      'Контакт заблокирован. Разблокируйте его на экране кода безопасности.',
  'Privacy policy': 'Политика конфиденциальности',
  'Terms of use': 'Условия использования',
  'Keys cannot be read': 'Ключи не читаются',
  'This usually happens when app data was restored from a '
      'system backup: the backup holds the encrypted keys, but '
      'the device key that decrypts them stayed on the old '
      'phone. Messages cannot be decrypted without it.':
      'Обычно так бывает, когда данные приложения восстановили '
      'из системной резервной копии: в копии лежат '
      'зашифрованные ключи, а ключ устройства, который их '
      'расшифровывает, остался на старом телефоне. Без него '
      'сообщения не расшифровать.',
  'Start over': 'Начать заново',
  'Try again': 'Повторить',
  'Delete local data': 'Удалить локальные данные',
  'Start over deletes the local database and media on this '
      'device. If you have a Soty backup file, restore it in '
      'Settings after the app starts.':
      '«Начать заново» удалит локальную базу и медиафайлы на '
      'этом устройстве. Если у вас есть файл резервной копии '
      'Soty, восстановите его в Настройках после запуска '
      'приложения.',
};
