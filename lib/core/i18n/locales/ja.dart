part of '../soty_l10n.dart';

/// Japanese translations.
const Map<String, String> _ja = {
  'File': 'ファイル',
  'Attach': '添付',
  'Take photo': '写真を撮る',
  'Record video': '動画を録画',
  'Recording… {time}': '録音中… {time}',
  'Save file': 'ファイルを保存',
  'File saved to {path}': 'ファイルを保存しました: {path}',
  'Failed to save file': 'ファイルを保存できませんでした',
  'File is too large (max {mb} MB)': 'ファイルが大きすぎます（最大 {mb} MB）',
  'The sender is offline. The file will download when they return.':
      '送信者がオフラインです。戻り次第ダウンロードされます。',
  'Waiting for a group member to share this file':
      'このファイルを持つグループメンバーの共有を待っています',
  'Video saved to {path}': '動画を保存しました: {path}',
  'Failed to save video': '動画を保存できませんでした',
  'Save video': '動画を保存',
  'Receiving': '受信中',
  'Transfer cancelled': '転送をキャンセルしました',
  'Cancel transfer': '転送をキャンセル',
  'Video is too large (max {mb} MB)': '動画が大きすぎます（最大 {mb} MB）',
  'Unsupported video format': '未対応の動画形式です',
  'Video unavailable': '動画を利用できません',
  'Video': '動画',
  'Send': '送信',
  'You are no longer a member of this group.':
      'あなたはもうこのグループのメンバーではありません。',
  'You': 'あなた',
  'Group info': 'グループ情報',
  'Members': 'メンバー',
  'Admin': '管理者',
  'Member': 'メンバー',
  'Add member': 'メンバーを追加',
  'Remove member': 'メンバーを削除',
  'Make admin': '管理者にする',
  'Remove admin': '管理者を解除',
  'Only admins can change this group.':
      'このグループを変更できるのは管理者だけです。',
  '{actor} added {name}': '{actor} が {name} を追加しました',
  '{actor} removed {name}': '{actor} が {name} を削除しました',
  '{actor} made {name} an admin': '{actor} が {name} を管理者にしました',
  '{actor} removed admin rights from {name}':
      '{actor} が {name} の管理者権限を解除しました',
  'Could not update the group.': 'グループを更新できませんでした。',
  'Not sent ({n})': '未送信（{n}）',
  'No connection — Soty will retry when the peer is reachable.':
      '接続がありません。相手に届くようになると Soty が再試行します。',
  'Search': '検索',
  'Search messages': 'メッセージを検索',
  'Search in this chat': 'このチャット内を検索',
  'No messages found': 'メッセージが見つかりません',
  'Type to search your messages.': '入力してメッセージを検索します。',
  'All': 'すべて',
  'Photos': '写真',
  'Voice': '音声',
  'Unread': '未読',
  'The new version is signed with a different key. Save a backup, '
  'uninstall Soty, then install the new release by hand and restore '
  'the backup.':
      '新しいバージョンは別の鍵で署名されています。バックアップを保存し、'
      'Soty をアンインストールしてから、新しいリリースを手動でインストールし、'
      'バックアップを復元してください。',
  'Backup': 'バックアップ',
  'Export backup': 'バックアップを書き出す',
  'Encrypted file with your identity, contacts and messages.':
      'あなたの身元、連絡先、メッセージを含む暗号化ファイルです。',
  'Restore backup': 'バックアップを復元',
  'Replace the identity, contacts and messages on '
  'this device from a backup file.':
      'バックアップファイルでこの端末の身元、連絡先、メッセージを置き換えます。',
  'Backup password': 'バックアップのパスワード',
  'Password must be at least {n} characters': 'パスワードは{n}文字以上必要です',
  'Backup created: {path}': 'バックアップを作成しました: {path}',
  'Backup restored': 'バックアップを復元しました',
  'Wrong password or damaged backup file':
      'パスワードが違うか、バックアップファイルが破損しています',
  'Restore this backup?': 'このバックアップを復元しますか？',
  'This replaces your identity, contacts and messages and restarts Soty.':
      '身元、連絡先、メッセージが置き換わり、Soty が再起動します。',
  'Restore': '復元',
  'Picking a file is not supported on this platform':
      'このプラットフォームではファイル選択に対応していません',
  'Backup failed': 'バックアップに失敗しました',
  'Export': '書き出す',
  'Copy code': 'コードをコピー',
  'Could not verify this contact': 'この連絡先を確認できませんでした',
  'Safety number': '安全番号',
  'Compare this code with {name} in person or over a trusted channel.':
      'このコードを{name}と対面または信頼できる経路で照合してください。',
  'Not verified': '未確認',
  'Verified': '確認済み',
  'Security code changed': '安全コードが変わりました',
  '{name} presented a new key. Compare the new code before trusting this '
      'chat.':
      '{name}が新しい鍵を提示しました。このチャットを信頼する前に'
      '新しいコードを照合してください。',
  'Mark as verified': '確認済みにする',
  'Scan their code': '相手のコードをスキャン',
  'Safety codes match': '安全コードが一致します',
  'Safety codes do not match': '安全コードが一致しません',
  'Safety code unavailable': '安全コードを取得できません',
  'This contact has not published an Ed25519 key yet.':
      'この連絡先はまだ Ed25519 鍵を公開していません。',
  'Failed to save photo': '写真を保存できませんでした',
  'Photo saved to {path}': '写真を保存しました: {path}',
  'Messaging with no server and no account. Pick a display name — it is '
  'signed into the invite other Soty users import to reach you.':
      'サーバーもアカウントも不要のメッセージング。表示名を選んでください。'
      '他の Soty ユーザーがあなたに届くために取り込む招待に署名されます。',
  'Display name': '表示名',
  'Roll another name': '別の名前を出す',
  'Continue': '続ける',
  'You can change your name later in the identity screen.':
      '名前は後で身元画面で変更できます。',
  'Cancel': 'キャンセル',
  'Save': '保存',
  'Invite copied to clipboard': '招待をクリップボードにコピーしました',
  'Import invite': '招待を取り込む',
  'Paste the invite JSON here': 'ここに招待 JSON を貼り付けてください',
  'Import': '取り込む',
  'Peer imported': 'ピアを取り込みました',
  'Invite rejected': '招待が拒否されました',
  'Import contact': '連絡先を取り込む',
  'Paste invite JSON': '招待 JSON を貼り付け',
  'Enter manually': '手動で入力',
  'Unknown contact — import it first to reply.':
      '不明な連絡先です。返信するには先に取り込んでください。',
  'Add peer': 'ピアを追加',
  'Peer X25519 public key (hex)': 'ピアの X25519 公開鍵（16進）',
  'Peer X25519 public key (hex) *': 'ピアの X25519 公開鍵（16進）*',
  'Name (optional)': '名前（任意）',
  'libp2p peer id (optional)': 'libp2p ピア ID（任意）',
  'Multiaddr (optional, e.g. /ip4/…/tcp/4001)':
      'Multiaddr（任意、例: /ip4/…/tcp/4001）',
  'Multiaddr (optional)': 'Multiaddr（任意）',
  'Public key must be 64 hex characters': '公開鍵は16進64文字である必要があります',
  'Add': '追加',
  'Identity': '身元',
  'Unnamed': '名前なし',
  'Ed25519 (identity / signing)': 'Ed25519（身元／署名）',
  'X25519 (address peers send to)': 'X25519（相手が送信するアドレス）',
  'Copy invite': '招待をコピー',
  'Signed identity claim — paste it to import your key.':
      '署名済みの身元クレームです。貼り付けて鍵を取り込んでください。',
  'Paste a friend’s signed invite to add them.':
      '友人の署名済み招待を貼り付けて追加します。',
  'Add a peer': 'ピアを追加',
  'Paste their X25519 key (+ optional libp2p address) to start a '
      'conversation.':
      '相手の X25519 鍵（＋任意の libp2p アドレス）を貼り付けると'
      '会話を始められます。',
  'Pruning': '整理',
  'Retention & integrity roots.': '保存期間と完全性ルート。',
  'Public key copied': '公開鍵をコピーしました',
  'Pruning integrity roots': '整理の完全性ルート',
  'No batches pruned yet.': 'まだ整理されたバッチはありません。',
  'Cutoff {ts}': '締め切り {ts}',
  'count: {n}\n{root}': '件数: {n}\n{root}',
  'New chat': '新しいチャット',
  'Start': '開始',
  'Invalid public key': '無効な公開鍵です',
  'Chats': 'チャット',
  'No conversations yet.\nAdd a peer to start.':
      'まだ会話がありません。\nピアを追加して始めましょう。',
  'online': 'オンライン',
  'offline': 'オフライン',
  'last seen just now': 'たった今オンライン',
  'last seen {n} min ago': '{n}分前にオンライン',
  'last seen {n} h ago': '{n}時間前にオンライン',
  'last seen {n} d ago': '{n}日前にオンライン',
  'No messages yet.': 'まだメッセージがありません。',
  'Text message': 'テキストメッセージ',
  'Message exceeds the 4 KB limit': 'メッセージが 4 KB の上限を超えています',
  'Message could not be sent': 'メッセージを送信できませんでした',
  'Reply': '返信',
  'Forward': '転送',
  'Copy': 'コピー',
  'Share': '共有',
  'Copied': 'コピーしました',
  'Forward to': '転送先',
  'Group': 'グループ',
  'No conversations yet.': 'まだ会話がありません。',
  'Recent': '最近',
  'Emoji': '絵文字',
  'No recent emoji': '最近の絵文字はありません',
  'Smileys & emotion': 'スマイリーと感情',
  'People & gestures': '人とジェスチャー',
  'Animals & nature': '動物と自然',
  'Food & drink': '食べ物と飲み物',
  'Travel & places': '旅行と場所',
  'Activities': 'アクティビティ',
  'Objects': 'オブジェクト',
  'Symbols': '記号',
  'Peers': 'ピア',
  'Rename chat': 'チャット名を変更',
  'Rename contact': '連絡先名を変更',
  'No contacts yet.\nImport an invite to start.':
      'まだ連絡先がありません。\n招待を取り込んで始めましょう。',
  'Chat name': 'チャット名',
  'Name updated': '名前を更新しました',
  'Unlock Soty': 'Soty のロックを解除',
  'Soty is locked': 'Soty はロックされています',
  'Enter your password to continue.': '続けるにはパスワードを入力してください。',
  'Password': 'パスワード',
  'Incorrect password': 'パスワードが違います',
  'Unlock with fingerprint': '指紋でロック解除',
  'Unlock': 'ロック解除',
  'Invite link copied to clipboard':
      '招待リンクをクリップボードにコピーしました',
  'My QR code': 'マイ QR コード',
  'Copy invite link': '招待リンクをコピー',
  'No identity yet.': 'まだ身元がありません。',
  'Others add you by scanning this code from Settings → Scan QR code.':
      '他の人は設定 → QR コードをスキャン でこのコードを読み取って'
      'あなたを追加できます。',
  'Copy invite text': '招待テキストをコピー',
  'Retry': '再試行',
  'Scan QR code': 'QR コードをスキャン',
  'Point the camera at a Soty contact QR code.':
      'カメラを Soty 連絡先の QR コードに向けてください。',
  'Camera unavailable. Allow camera permission and retry.':
      'カメラを利用できません。カメラ権限を許可して再試行してください。',
  'Contact added from QR code': 'QR コードから連絡先を追加しました',
  'Invalid host link': '無効なホストリンクです',
  'Relay host added': 'リレーホストを追加しました',
  'Relay host list is full (max {max})':
      'リレーホストの一覧がいっぱいです（最大 {max}）',
  'Add relay host': 'リレーホストを追加',
  'Disable app lock': 'アプリロックを無効にする',
  'Enter your current password.': '現在のパスワードを入力してください。',
  'Current password': '現在のパスワード',
  'Confirm your current password.': '現在のパスワードを確認してください。',
  'Biometrics are not available on this device':
      'この端末では生体認証を利用できません',
  'Enable fingerprint unlock': '指紋によるロック解除を有効にする',
  'Enter your password to confirm.': '確認のためパスワードを入力してください。',
  'Set app lock password': 'アプリロックのパスワードを設定',
  'Enable lock': 'ロックを有効にする',
  'Confirm': '確認',
  'Settings': '設定',
  'Contact': '連絡先',
  'Show this code so others can add you.':
      'このコードを見せると他の人があなたを追加できます。',
  'Add a contact by scanning their code.':
      '相手のコードをスキャンして連絡先を追加します。',
  'Paste the invite instead of a QR.': 'QR の代わりに招待を貼り付けます。',
  'A soty:// link that opens Soty to add you.':
      'Soty を開いてあなたを追加する soty:// リンクです。',
  'Security': 'セキュリティ',
  'App lock': 'アプリロック',
  'Require a password to open Soty.': 'Soty を開くにはパスワードが必要です。',
  'Change password': 'パスワードを変更',
  'Fingerprint unlock': '指紋によるロック解除',
  'Unlock with biometrics instead of typing the password.':
      'パスワードの入力の代わりに生体認証で解除します。',
  'Network': 'ネットワーク',
  'Peers in network': 'ネットワーク内のピア',
  '{n} registered · {online} online': '登録 {n} · オンライン {online}',
  'Active connections': 'アクティブな接続',
  appLockResetNotice:
      'アプリロックをリセットしました: 保存されたパスワードが壊れています。'
      '設定で再設定してください。',
  '{n} visible · {connected} connected': '検出 {n} · 接続 {connected}',
  '{n} of {max} direct peers in exchange': '直接ピア {n}/{max} を交換中',
  'About': '情報',
  'Version': 'バージョン',
  'Source and releases': 'ソースとリリース',
  'Link copied to clipboard': 'リンクをクリップボードにコピーしました',
  'Active peers limit': 'アクティブピアの上限',
  'Keep at most {n} direct peers connected.': '同時に接続する直接ピアは最大 {n} です。',
  'Relay hosts': 'リレーホスト',
  'Connected': '接続済み',
  'Offline': 'オフライン',
  'Remove host': 'ホストを削除',
  'Paste a ws:// URL or a soty:// host link.':
      'ws:// URL または soty:// ホストリンクを貼り付けてください。',
  'Tracker discovery': 'トラッカーによる検出',
  'Peers found via trackers: {n}.': 'トラッカーで見つかったピア: {n}。',
  'How many direct peers the device keeps available at once. Raise it for '
  'dense meshes; lower it to save battery and traffic.':
      '端末が同時に利用可能に保つ直接ピア数。密なメッシュでは増やし、'
      '電池と通信量を節約するには減らします。',
  'Apply': '適用',
  'Use {min}–{max} characters': '{min}～{max}文字を使用してください',
  'Passwords do not match': 'パスワードが一致しません',
  'Repeat password': 'パスワードを再入力',
  'A relay host stores only encrypted envelopes. Anyone running one can see '
  'who talks to whom, so use hosts you trust.':
      'リレーホストは暗号化された封筒だけを保存します。運営者は誰が誰と'
      '話しているかを見られるため、信頼できるホストを使ってください。',
  'Host': 'ホスト',
  'ws://host:port/ws or soty://host?addr=…':
      'ws://host:port/ws または soty://host?addr=…',
  'Appearance': '外観',
  'Language': '言語',
  'Theme': 'テーマ',
  'System': 'システム',
  'Light': 'ライト',
  'Dark': 'ダーク',
  'Failed to start Soty:\n{error}': 'Soty を起動できませんでした:\n{error}',
  'Invalid relay host link': '無効なリレーホストリンクです',
  'Relay host list is full': 'リレーホストの一覧がいっぱいです',
  'Invalid invite link': '無効な招待リンクです',
  'Insecure or expired invite': '安全でないか期限切れの招待です',
  'Messages': 'メッセージ',
  'Encrypted message': '暗号化メッセージ',
  'Send with Enter': 'Enter で送信',
  'Press Enter to send; turn it off to add a new line.':
      'Enter で送信します。オフにすると改行できます。',
  'Storage': 'ストレージ',
  'Keep messages': 'メッセージの保存',
  'Save sent messages': '送信メッセージを保存',
  'Relay failover': 'リレーのフェイルオーバー',
  'Only configured relays': '設定済みのリレーのみ',
  'Automatic fallback': '自動フォールバック',
  'Never use relays learned from trackers.':
      'トラッカーから学習したリレーは使いません。',
  'Use relays learned from hosts when the configured ones '
  'are unreachable.':
      '設定済みのリレーに届かないとき、ホストから学習したリレーを使います。',
  'Keep my sent messages on this device so they stay readable after '
  'restart':
      '送信したメッセージをこの端末に保存し、再起動後も読めるようにします',
  'How long your own conversations stay on this device. Envelopes you only '
  'relay for others are always pruned after 30 days (capped at 10 GB).':
      '自分の会話をこの端末に残す期間。他人のために中継するだけの封筒は'
      '常に30日後に整理されます（上限 10 GB）。',
  '{n} days': '{n}日',
  'Forever': '永久',
  'New group': '新しいグループ',
  'Group name': 'グループ名',
  'Members: {n}': 'メンバー: {n}人',
  'Create': '作成',
  'Add peers first.': '先にピアを追加してください。',
  'Notifications': '通知',
  'Message notifications': 'メッセージ通知',
  'Enabled on this device': 'この端末で有効',
  'Blocked by the system': 'システムによりブロック',
  'Not available: {reason}': '利用できません: {reason}',
  'Not supported on this platform': 'このプラットフォームでは未対応です',
  'Checking notification support…': '通知の対応を確認中…',
  'Open system notification settings': 'システムの通知設定を開く',
  'Send test notification': 'テスト通知を送信',
  'Test notification sent': 'テスト通知を送信しました',
  'Notifications are blocked by the system':
      '通知がシステムによりブロックされています',
  'Test notification failed: {reason}': 'テスト通知に失敗しました: {reason}',
  'Test notification': 'テスト通知',
  'Open': '開く',
  'Mesh (BLE/Wi-Fi Direct)': 'メッシュ（BLE/Wi-Fi Direct）',
  '{n} nodes in range': '範囲内のノード {n}',
  'Off': 'オフ',
  'Permission required': '権限が必要',
  'Unavailable': '利用不可',
  'Background': 'バックグラウンド',
  'Work in background': 'バックグラウンドで動作',
  'Keep mesh and relays alive while the app is not in the chat':
      'チャットを開いていない間もメッシュとリレーを維持します',
  'Battery optimization': '電池の最適化',
  'No restrictions': '制限なし',
  'Restricted by the system': 'システムにより制限',
  'Checking…': '確認中…',
  'Read receipts': '既読通知',
  'Send read receipts so others know when you have read their messages.':
      '既読通知を送り、相手に読んだことを知らせます。',
  'Sending': '送信中',
  'Sent': '送信済み',
  'Delivered': '配信済み',
  'Read': '既読',
  'Update available': '更新があります',
  'Version {v} is available': 'バージョン {v} が利用可能です',
  'Download': 'ダウンロード',
  'Install': 'インストール',
  'Hide': '隠す',
  'Remind later': '後で通知',
  'Allow Soty to install apps, then tap Install again.':
      'Soty にアプリのインストールを許可してから、もう一度インストールを'
      'タップしてください。',
  'Download failed': 'ダウンロードに失敗しました',
  'The downloaded file failed its checksum check':
      'ダウンロードしたファイルのチェックサム検証に失敗しました',
  'Check for updates': '更新を確認',
  'Could not check for updates': '更新を確認できませんでした',
  'You have the latest version': '最新バージョンです',
  'Current version: {v}': '現在のバージョン: {v}',
  'Release notes': 'リリースノート',
  'Close': '閉じる',
  'Voice message': '音声メッセージ',
  'Photo': '写真',
  'Recording… {s} s left': '録音中… 残り {s} 秒',
  'Photo is too large (max {kb} KB)': '写真が大きすぎます（最大 {kb} KB）',
  'Voice message is too short': '音声メッセージが短すぎます',
  'Voice message is too large': '音声メッセージが大きすぎます',
  'Microphone permission is required': 'マイクの権限が必要です',
  'Recording failed': '録音に失敗しました',
  'Voice message failed': '音声メッセージの再生に失敗しました',
  'Photo unavailable': '写真を利用できません',
  'Unsupported photo format': '未対応の写真形式です',
  'Play voice message': '音声メッセージを再生',
  'Stop': '停止',
  'Not delivered yet ({n})':
      'まだ配信されていません（{n}）',
  'Message not delivered yet — Soty will retry when the peer is '
  'reachable.':
      'まだ配信されていません。相手に届くようになると Soty が再試行します。',
  'Report abuse': '不正利用を報告',
  'Opens the report form on soty.su in a browser': 'ブラウザで soty.su の報告フォームを開きます',
  'Link copied': 'リンクをコピーしました',
  'Block contact': '連絡先をブロック',
  'Messages from this contact are ignored and never decrypted.':
      'この連絡先のメッセージは無視され、復号されることはありません。',
  'You blocked this contact. Unblock it in the safety screen.':
      'この連絡先をブロックしました。安全コード画面で解除してください。',
  'Privacy policy': 'プライバシーポリシー',
  'Terms of use': '利用規約',
  'Keys cannot be read': '鍵を読み取れません',
  'This usually happens when app data was restored from a '
      'system backup: the backup holds the encrypted keys, but '
      'the device key that decrypts them stayed on the old '
      'phone. Messages cannot be decrypted without it.':
      'これは通常、アプリのデータがシステムのバックアップから復元されたときに起こります。バックアップには暗号化された鍵'
      'が入っていますが、それを復号する端末の鍵は古い端末に残っています。その鍵がないとメッセージは復号できません。',
  'Start over': '最初からやり直す',
  'Try again': '再試行',
  'Delete local data': 'ローカルデータを削除',
  'Start over deletes the local database and media on this '
      'device. If you have a Soty backup file, restore it in '
      'Settings after the app starts.':
      '「最初からやり直す」と、この端末のローカルデータベースとメディアが削除されます。Soty '
      'のバックアップファイルがある場合は、アプリ起動後に設定から復元してください。',
};
