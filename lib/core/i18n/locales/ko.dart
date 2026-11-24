part of '../soty_l10n.dart';

/// Korean translations.
const Map<String, String> _ko = {
  'File': '파일',
  'Attach': '첨부',
  'Take photo': '사진 촬영',
  'Record video': '동영상 촬영',
  'Recording… {time}': '녹음 중… {time}',
  'Save file': '파일 저장',
  'File saved to {path}': '파일을 {path}에 저장했어요',
  'Failed to save file': '파일을 저장하지 못했어요',
  'File is too large (max {mb} MB)': '파일이 너무 커요 (최대 {mb} MB)',
  'The sender is offline. The file will download when they return.':
      '보낸 사람이 오프라인이에요. 다시 연결되면 파일을 내려받아요.',
  'Waiting for a group member to share this file':
      '이 파일을 가진 그룹 멤버가 공유해 주기를 기다리는 중이에요',
  'Video saved to {path}': '동영상을 {path}에 저장했어요',
  'Failed to save video': '동영상을 저장하지 못했어요',
  'Save video': '동영상 저장',
  'Receiving': '받는 중',
  'Transfer cancelled': '전송이 취소되었어요',
  'Cancel transfer': '전송 취소',
  'Video is too large (max {mb} MB)': '동영상이 너무 커요 (최대 {mb} MB)',
  'Unsupported video format': '지원하지 않는 동영상 형식이에요',
  'Video unavailable': '동영상을 사용할 수 없어요',
  'Video': '동영상',
  'Send': '보내기',
  'You are no longer a member of this group.':
      '더 이상 이 그룹의 멤버가 아니에요.',
  'You': '나',
  'Group info': '그룹 정보',
  'Members': '멤버',
  'Admin': '관리자',
  'Member': '멤버',
  'Add member': '멤버 추가',
  'Remove member': '멤버 삭제',
  'Make admin': '관리자로 지정',
  'Remove admin': '관리자 해제',
  'Only admins can change this group.':
      '관리자만 이 그룹을 바꿀 수 있어요.',
  '{actor} added {name}': '{actor}님이 {name}님을 추가했어요',
  '{actor} removed {name}': '{actor}님이 {name}님을 삭제했어요',
  '{actor} made {name} an admin': '{actor}님이 {name}님을 관리자로 지정했어요',
  '{actor} removed admin rights from {name}':
      '{actor}님이 {name}님의 관리자 권한을 해제했어요',
  'Could not update the group.': '그룹을 업데이트하지 못했어요.',
  'Not sent ({n})': '보내지 못함 ({n})',
  'No connection — Soty will retry when the peer is reachable.':
      '연결이 없어요 — 피어에 연결되면 Soty가 다시 시도해요.',
  'Search': '검색',
  'Search messages': '메시지 검색',
  'Search in this chat': '이 채팅에서 검색',
  'No messages found': '메시지를 찾지 못했어요',
  'Type to search your messages.': '검색어를 입력해 주세요.',
  'All': '전체',
  'Photos': '사진',
  'Voice': '음성',
  'Unread': '읽지 않음',
  'The new version is signed with a different key. Save a backup, '
  'uninstall Soty, then install the new release by hand and restore '
  'the backup.':
      '새 버전은 다른 키로 서명되었어요. 백업을 저장한 뒤 Soty를 삭제하고, '
      '새 버전을 직접 설치한 다음 백업을 복원해 주세요.',
  'Backup': '백업',
  'Export backup': '백업 내보내기',
  'Encrypted file with your identity, contacts and messages.':
      '신원, 연락처, 메시지가 담긴 암호화된 파일이에요.',
  'Restore backup': '백업 복원',
  'Replace the identity, contacts and messages on '
  'this device from a backup file.':
      '백업 파일로 이 기기의 신원, 연락처, 메시지를 바꿔요.',
  'Backup password': '백업 비밀번호',
  'Password must be at least {n} characters':
      '비밀번호는 {n}자 이상이어야 해요',
  'Backup created: {path}': '백업을 만들었어요: {path}',
  'Backup restored': '백업을 복원했어요',
  'Wrong password or damaged backup file':
      '비밀번호가 틀리거나 백업 파일이 손상되었어요',
  'Restore this backup?': '이 백업을 복원할까요?',
  'This replaces your identity, contacts and messages and restarts Soty.':
      '신원, 연락처, 메시지를 교체하고 Soty를 다시 시작해요.',
  'Restore': '복원',
  'Picking a file is not supported on this platform':
      '이 플랫폼에서는 파일 선택을 지원하지 않아요',
  'Backup failed': '백업하지 못했어요',
  'Export': '내보내기',
  'Copy code': '코드 복사',
  'Could not verify this contact': '이 연락처를 확인하지 못했어요',
  'Safety number': '안전 번호',
  'Compare this code with {name} in person or over a trusted channel.':
      '이 코드를 {name}님과 직접 만나거나 신뢰하는 채널에서 비교해 보세요.',
  'Not verified': '확인되지 않음',
  'Verified': '확인됨',
  'Security code changed': '보안 코드가 바뀌었어요',
  '{name} presented a new key. Compare the new code before trusting this '
      'chat.':
      '{name}님이 새 키를 제시했어요. 이 채팅을 믿기 전에 새 코드를 '
      '비교해 보세요.',
  'Mark as verified': '확인됨으로 표시',
  'Scan their code': '상대 코드 스캔',
  'Safety codes match': '안전 코드가 일치해요',
  'Safety codes do not match': '안전 코드가 일치하지 않아요',
  'Safety code unavailable': '안전 코드를 사용할 수 없어요',
  'This contact has not published an Ed25519 key yet.':
      '이 연락처는 아직 Ed25519 키를 공개하지 않았어요.',
  'Failed to save photo': '사진을 저장하지 못했어요',
  'Photo saved to {path}': '사진을 {path}에 저장했어요',
  'Messaging with no server and no account. Pick a display name — it is '
  'signed into the invite other Soty users import to reach you.':
      '서버도 계정도 없는 메신저예요. 표시 이름을 골라 주세요 — 이 이름은 '
      '다른 Soty 사용자가 당신에게 연락할 때 가져오는 초대에 서명되어 들어가요.',
  'Display name': '표시 이름',
  'Roll another name': '다른 이름 제안',
  'Continue': '계속',
  'You can change your name later in the identity screen.':
      '이름은 나중에 신원 화면에서 바꿀 수 있어요.',
  'Cancel': '취소',
  'Save': '저장',
  'Invite copied to clipboard': '초대를 클립보드에 복사했어요',
  'Import invite': '초대 가져오기',
  'Paste the invite JSON here': '여기에 초대 JSON을 붙여넣으세요',
  'Import': '가져오기',
  'Peer imported': '피어를 가져왔어요',
  'Invite rejected': '초대를 거부했어요',
  'Import contact': '연락처 가져오기',
  'Paste invite JSON': '초대 JSON 붙여넣기',
  'Enter manually': '직접 입력',
  'Unknown contact — import it first to reply.':
      '알 수 없는 연락처예요 — 답장하려면 먼저 가져오세요.',
  'Add peer': '피어 추가',
  'Peer X25519 public key (hex)': '피어 X25519 공개 키 (hex)',
  'Peer X25519 public key (hex) *': '피어 X25519 공개 키 (hex) *',
  'Name (optional)': '이름 (선택)',
  'libp2p peer id (optional)': 'libp2p 피어 ID (선택)',
  'Multiaddr (optional, e.g. /ip4/…/tcp/4001)':
      'Multiaddr (선택, 예: /ip4/…/tcp/4001)',
  'Multiaddr (optional)': 'Multiaddr (선택)',
  'Public key must be 64 hex characters':
      '공개 키는 64자리 hex여야 해요',
  'Add': '추가',
  'Identity': '신원',
  'Unnamed': '이름 없음',
  'Ed25519 (identity / signing)': 'Ed25519 (신원 / 서명)',
  'X25519 (address peers send to)': 'X25519 (피어가 보내는 주소)',
  'Copy invite': '초대 복사',
  'Signed identity claim — paste it to import your key.':
      '서명된 신원 증명이에요 — 붙여넣으면 키를 가져와요.',
  'Paste a friend’s signed invite to add them.':
      '친구의 서명된 초대를 붙여넣으면 추가할 수 있어요.',
  'Add a peer': '피어 추가',
  'Paste their X25519 key (+ optional libp2p address) to start a '
  'conversation.':
      '상대의 X25519 키(+ 선택 사항인 libp2p 주소)를 붙여넣으면 대화를 '
      '시작할 수 있어요.',
  'Pruning': '정리',
  'Retention & integrity roots.': '보관 기간과 무결성 루트예요.',
  'Public key copied': '공개 키를 복사했어요',
  'Pruning integrity roots': '정리 무결성 루트',
  'No batches pruned yet.': '아직 정리된 배치가 없어요.',
  'Cutoff {ts}': '기준 시각 {ts}',
  'count: {n}\n{root}': '개수: {n}\n{root}',
  'New chat': '새 채팅',
  'Start': '시작',
  'Invalid public key': '잘못된 공개 키예요',
  'Chats': '채팅',
  'No conversations yet.\nAdd a peer to start.':
      '아직 대화가 없어요.\n피어를 추가해 시작하세요.',
  'online': '온라인',
  'offline': '오프라인',
  'last seen just now': '방금 접속함',
  'last seen {n} min ago': '{n}분 전 접속',
  'last seen {n} h ago': '{n}시간 전 접속',
  'last seen {n} d ago': '{n}일 전 접속',
  'No messages yet.': '아직 메시지가 없어요.',
  'Text message': '텍스트 메시지',
  'Message exceeds the 4 KB limit': '메시지가 4 KB 제한을 넘었어요',
  'Message could not be sent': '메시지를 보내지 못했어요',
  'Reply': '답장',
  'Forward': '전달',
  'Copy': '복사',
  'Share': '공유',
  'Copied': '복사됨',
  'Forward to': '전달 대상',
  'Group': '그룹',
  'No conversations yet.': '아직 대화가 없어요.',
  'Recent': '최근',
  'Emoji': '이모지',
  'No recent emoji': '최근 이모지가 없어요',
  'Smileys & emotion': '표정 및 감정',
  'People & gestures': '사람 및 제스처',
  'Animals & nature': '동물 및 자연',
  'Food & drink': '음식 및 음료',
  'Travel & places': '여행 및 장소',
  'Activities': '활동',
  'Objects': '사물',
  'Symbols': '기호',
  'Peers': '피어',
  'Rename chat': '채팅 이름 바꾸기',
  'Rename contact': '연락처 이름 바꾸기',
  'No contacts yet.\nImport an invite to start.':
      '아직 연락처가 없어요.\n초대를 가져와 시작하세요.',
  'Chat name': '채팅 이름',
  'Name updated': '이름을 바꿨어요',
  'Unlock Soty': 'Soty 잠금 해제',
  'Soty is locked': 'Soty가 잠겨 있어요',
  'Enter your password to continue.': '계속하려면 비밀번호를 입력하세요.',
  'Password': '비밀번호',
  'Incorrect password': '비밀번호가 틀렸어요',
  'Unlock with fingerprint': '지문으로 잠금 해제',
  'Unlock': '잠금 해제',
  'Invite link copied to clipboard':
      '초대 링크를 클립보드에 복사했어요',
  'My QR code': '내 QR 코드',
  'Copy invite link': '초대 링크 복사',
  'No identity yet.': '아직 신원이 없어요.',
  'Others add you by scanning this code from Settings → Scan QR code.':
      '다른 사람은 설정 → QR 코드 스캔에서 이 코드를 스캔해 '
      '당신을 추가할 수 있어요.',
  'Copy invite text': '초대 텍스트 복사',
  'Retry': '다시 시도',
  'Scan QR code': 'QR 코드 스캔',
  'Point the camera at a Soty contact QR code.':
      'Soty 연락처 QR 코드에 카메라를 비춰 주세요.',
  'Camera unavailable. Allow camera permission and retry.':
      '카메라를 사용할 수 없어요. 카메라 권한을 허용하고 다시 시도하세요.',
  'Contact added from QR code': 'QR 코드로 연락처를 추가했어요',
  'Invalid host link': '잘못된 호스트 링크예요',
  'Relay host added': '릴레이 서버를 추가했어요',
  'Relay host list is full (max {max})':
      '릴레이 서버 목록이 가득 찼어요 (최대 {max})',
  'Add relay host': '릴레이 서버 추가',
  'Disable app lock': '앱 잠금 끄기',
  'Enter your current password.': '현재 비밀번호를 입력하세요.',
  'Current password': '현재 비밀번호',
  'Confirm your current password.': '현재 비밀번호를 확인해 주세요.',
  'Biometrics are not available on this device':
      '이 기기에서는 생체 인식을 사용할 수 없어요',
  'Enable fingerprint unlock': '지문 잠금 해제 켜기',
  'Enter your password to confirm.':
      '확인을 위해 비밀번호를 입력하세요.',
  'Set app lock password': '앱 잠금 비밀번호 설정',
  'Enable lock': '잠금 켜기',
  'Confirm': '확인',
  'Settings': '설정',
  'Contact': '연락처',
  'Show this code so others can add you.':
      '다른 사람이 당신을 추가할 수 있도록 이 코드를 보여 주세요.',
  'Add a contact by scanning their code.':
      '상대의 코드를 스캔해 연락처를 추가하세요.',
  'Paste the invite instead of a QR.': 'QR 대신 초대를 붙여넣어도 돼요.',
  'A soty:// link that opens Soty to add you.':
      'Soty를 열어 당신을 추가하는 soty:// 링크예요.',
  'Security': '보안',
  'App lock': '앱 잠금',
  'Require a password to open Soty.': 'Soty를 열 때 비밀번호를 요구해요.',
  'Change password': '비밀번호 변경',
  'Fingerprint unlock': '지문 잠금 해제',
  'Unlock with biometrics instead of typing the password.':
      '비밀번호를 입력하는 대신 생체 인식으로 잠금을 해제해요.',
  'Network': '네트워크',
  'Peers in network': '네트워크의 피어',
  '{n} registered · {online} online': '{n}개 등록 · {online}개 온라인',
  'Active connections': '활성 연결',
  appLockResetNotice:
      '앱 잠금이 초기화되었어요: 저장된 비밀번호가 손상되었어요. '
      '설정에서 다시 설정해 주세요.',
  '{n} visible · {connected} connected': '{n}개 표시 · {connected}개 연결됨',
  '{n} of {max} direct peers in exchange':
      '직접 피어 {max}개 중 {n}개 교환 중',
  'About': '정보',
  'Version': '버전',
  'Source and releases': '소스 및 릴리스',
  'Link copied to clipboard': '링크를 클립보드에 복사했어요',
  'Active peers limit': '활성 피어 한도',
  'Keep at most {n} direct peers connected.':
      '직접 피어를 최대 {n}개까지 연결해요.',
  'Relay hosts': '릴레이 서버',
  'Connected': '연결됨',
  'Offline': '오프라인',
  'Remove host': '호스트 삭제',
  'Paste a ws:// URL or a soty:// host link.':
      'ws:// URL 또는 soty:// 호스트 링크를 붙여넣으세요.',
  'Tracker discovery': '트래커 검색',
  'Peers found via trackers: {n}.': '트래커로 찾은 피어: {n}개.',
  'How many direct peers the device keeps available at once. Raise it for '
  'dense meshes; lower it to save battery and traffic.':
      '기기가 동시에 유지하는 직접 피어 수예요. 메시가 촘촘하면 늘리고, '
      '배터리와 트래픽을 아끼려면 줄이세요.',
  'Apply': '적용',
  'Use {min}–{max} characters': '{min}–{max}자 사이로 입력하세요',
  'Passwords do not match': '비밀번호가 일치하지 않아요',
  'Repeat password': '비밀번호 확인',
  'A relay host stores only encrypted envelopes. Anyone running one can see '
  'who talks to whom, so use hosts you trust.':
      '릴레이 서버는 암호화된 봉투만 저장해요. 운영자는 누가 누구와 '
      '대화하는지 볼 수 있으니 신뢰하는 호스트를 사용하세요.',
  'Host': '호스트',
  'ws://host:port/ws or soty://host?addr=…':
      'ws://host:port/ws 또는 soty://host?addr=…',
  'Appearance': '화면',
  'Language': '언어',
  'Theme': '테마',
  'System': '시스템',
  'Light': '라이트',
  'Dark': '다크',
  'Failed to start Soty:\n{error}': 'Soty를 시작하지 못했어요:\n{error}',
  'Invalid relay host link': '잘못된 릴레이 서버 링크예요',
  'Relay host list is full': '릴레이 서버 목록이 가득 찼어요',
  'Invalid invite link': '잘못된 초대 링크예요',
  'Insecure or expired invite': '안전하지 않거나 만료된 초대예요',
  'Messages': '메시지',
  'Encrypted message': '암호화된 메시지',
  'Send with Enter': 'Enter로 보내기',
  'Press Enter to send; turn it off to add a new line.':
      'Enter를 누르면 전송돼요. 끄면 줄을 바꿀 수 있어요.',
  'Storage': '저장 공간',
  'Keep messages': '메시지 보관',
  'Save sent messages': '보낸 메시지 저장',
  'Relay failover': '릴레이 전환',
  'Only configured relays': '설정된 릴레이만',
  'Automatic fallback': '자동 전환',
  'Never use relays learned from trackers.':
      '트래커에서 찾은 릴레이는 사용하지 않아요.',
  'Use relays learned from hosts when the configured ones '
  'are unreachable.':
      '설정된 릴레이에 연결할 수 없으면 호스트에서 알게 된 릴레이를 사용해요.',
  'Keep my sent messages on this device so they stay readable after '
  'restart':
      '보낸 메시지를 이 기기에 보관해 다시 시작한 뒤에도 읽을 수 있게 해요',
  'How long your own conversations stay on this device. Envelopes you only '
  'relay for others are always pruned after 30 days (capped at 10 GB).':
      '내 대화를 이 기기에 얼마나 오래 보관할지 정해요. 다른 사람을 위해 '
      '중계만 하는 봉투는 항상 30일 뒤에 정리돼요 (최대 10 GB).',
  '{n} days': '{n}일',
  'Forever': '영구 보관',
  'New group': '새 그룹',
  'Group name': '그룹 이름',
  'Members: {n}': '멤버: {n}',
  'Create': '만들기',
  'Add peers first.': '먼저 연락처를 추가하세요.',
  'Notifications': '알림',
  'Message notifications': '메시지 알림',
  'Enabled on this device': '이 기기에서 켜져 있어요',
  'Blocked by the system': '시스템에서 차단되었어요',
  'Not available: {reason}': '사용할 수 없어요: {reason}',
  'Not supported on this platform': '이 플랫폼에서는 지원하지 않아요',
  'Checking notification support…': '알림 지원을 확인하는 중…',
  'Open system notification settings': '시스템 알림 설정 열기',
  'Send test notification': '테스트 알림 보내기',
  'Test notification sent': '테스트 알림을 보냈어요',
  'Notifications are blocked by the system':
      '알림이 시스템에서 차단되었어요',
  'Test notification failed: {reason}':
      '테스트 알림을 보내지 못했어요: {reason}',
  'Test notification': '테스트 알림',
  'Open': '열기',
  'Mesh (BLE/Wi-Fi Direct)': '메시 (BLE/Wi-Fi Direct)',
  '{n} nodes in range': '범위 안의 노드 {n}개',
  'Off': '끔',
  'Permission required': '권한 필요',
  'Unavailable': '사용할 수 없음',
  'Background': '백그라운드',
  'Work in background': '백그라운드에서 작동',
  'Keep mesh and relays alive while the app is not in the chat':
      '채팅 화면이 아닐 때도 메시와 릴레이를 유지해요',
  'Battery optimization': '배터리 최적화',
  'No restrictions': '제한 없음',
  'Restricted by the system': '시스템에서 제한됨',
  'Checking…': '확인 중…',

  'Read receipts': '읽음 표시',
  'Send read receipts so others know when you have read their messages.':
      '읽음 표시를 보내 상대가 메시지를 읽은 시점을 알 수 있게 해요.',
  'Sending': '보내는 중',
  'Sent': '보냄',
  'Delivered': '전달됨',
  'Read': '읽음',
  'Update available': '업데이트 있음',
  'Version {v} is available': '버전 {v}이 나왔어요',
  'Download': '다운로드',
  'Install': '설치',
  'Hide': '숨기기',
  'Remind later': '나중에 알림',
  'Allow Soty to install apps, then tap Install again.':
      'Soty가 앱을 설치하도록 허용한 뒤 설치를 다시 눌러 주세요.',
  'Download failed': '다운로드하지 못했어요',
  'The downloaded file failed its checksum check':
      '내려받은 파일이 체크섬 검사를 통과하지 못했어요',
  'Check for updates': '업데이트 확인',
  'Could not check for updates': '업데이트를 확인하지 못했어요',
  'You have the latest version': '최신 버전을 사용 중이에요',
  'Current version: {v}': '현재 버전: {v}',
  'Release notes': '릴리스 노트',
  'Close': '닫기',
  'Voice message': '음성 메시지',
  'Photo': '사진',
  'Recording… {s} s left': '녹음 중… {s}초 남음',
  'Photo is too large (max {kb} KB)': '사진이 너무 커요 (최대 {kb} KB)',
  'Voice message is too short': '음성 메시지가 너무 짧아요',
  'Voice message is too large': '음성 메시지가 너무 커요',
  'Microphone permission is required': '마이크 권한이 필요해요',
  'Recording failed': '녹음하지 못했어요',
  'Voice message failed': '음성 메시지를 재생하지 못했어요',
  'Photo unavailable': '사진을 사용할 수 없어요',
  'Unsupported photo format': '지원하지 않는 사진 형식이에요',
  'Play voice message': '음성 메시지 재생',
  'Stop': '중지',
  'Not delivered yet ({n})':
      '아직 전달되지 않음 ({n})',
  'Message not delivered yet — Soty will retry when the peer is '
  'reachable.':
      '아직 전달되지 않았어요. 상대에게 닿을 수 있게 되면 Soty가 다시 시도해요.',
  'Report abuse': '악용 신고',
  'Opens the report form on soty.su in a browser': '브라우저에서 soty.su 신고 양식을 엽니다',
  'Link copied': '링크가 복사되었습니다',
  'Block contact': '연락처 차단',
  'Messages from this contact are ignored and never decrypted.':
      '이 연락처의 메시지는 무시되며 복호화되지 않습니다.',
  'You blocked this contact. Unblock it in the safety screen.':
      '이 연락처를 차단했습니다. 보안 코드 화면에서 해제하세요.',
  'Privacy policy': '개인정보 처리방침',
  'Terms of use': '이용약관',
};
