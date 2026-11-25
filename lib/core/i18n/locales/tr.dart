part of '../soty_l10n.dart';

/// Turkish translations.
const Map<String, String> _tr = {
  'File': 'Dosya',
  'Attach': 'Ekle',
  'Take photo': 'Fotoğraf çek',
  'Record video': 'Video kaydet',
  'Recording… {time}': 'Kaydediliyor… {time}',
  'Save file': 'Dosyayı kaydet',
  'File saved to {path}': 'Dosya {path} konumuna kaydedildi',
  'Failed to save file': 'Dosya kaydedilemedi',
  'File is too large (max {mb} MB)': 'Dosya çok büyük (en fazla {mb} MB)',
  'The sender is offline. The file will download when they return.':
      'Gönderen çevrimdışı. Geri döndüğünde dosya indirilecek.',
  'Waiting for a group member to share this file':
      'Dosyayı paylaşacak bir grup üyesi bekleniyor',
  'Video saved to {path}': 'Video {path} konumuna kaydedildi',
  'Failed to save video': 'Video kaydedilemedi',
  'Save video': 'Videoyu kaydet',
  'Receiving': 'Alınıyor',
  'Transfer cancelled': 'Aktarım iptal edildi',
  'Cancel transfer': 'Aktarımı iptal et',
  'Video is too large (max {mb} MB)': 'Video çok büyük (en fazla {mb} MB)',
  'Unsupported video format': 'Desteklenmeyen video biçimi',
  'Video unavailable': 'Video kullanılamıyor',
  'Video': 'Video',
  'Send': 'Gönder',
  'You are no longer a member of this group.':
      'Artık bu grubun üyesi değilsin.',
  'You': 'Sen',
  'Group info': 'Grup bilgileri',
  'Members': 'Üyeler',
  'Admin': 'Yönetici',
  'Member': 'Üye',
  'Add member': 'Üye ekle',
  'Remove member': 'Üyeyi çıkar',
  'Make admin': 'Yönetici yap',
  'Remove admin': 'Yöneticiliği al',
  'Only admins can change this group.':
      'Bu grubu yalnızca yöneticiler değiştirebilir.',
  '{actor} added {name}': '{actor}, {name} adlı kişiyi ekledi',
  '{actor} removed {name}': '{actor}, {name} adlı kişiyi çıkardı',
  '{actor} made {name} an admin': '{actor}, {name} adlı kişiyi yönetici yaptı',
  '{actor} removed admin rights from {name}':
      '{actor}, {name} adlı kişinin yöneticilik yetkisini aldı',
  'Could not update the group.': 'Grup güncellenemedi.',
  'Not sent ({n})': 'Gönderilmedi ({n})',
  'No connection — Soty will retry when the peer is reachable.':
      'Bağlantı yok — Soty, eş ulaşılabilir olduğunda yeniden deneyecek.',
  'Search': 'Ara',
  'Search messages': 'Mesajlarda ara',
  'Search in this chat': 'Bu sohbette ara',
  'No messages found': 'Mesaj bulunamadı',
  'Type to search your messages.': 'Mesajlarında aramak için yazmaya başla.',
  'All': 'Tümü',
  'Photos': 'Fotoğraflar',
  'Voice': 'Sesli',
  'Unread': 'Okunmamış',
  'The new version is signed with a different key. Save a backup, uninstall '
  'Soty, then install the new release by hand and restore the backup.':
      'Yeni sürüm farklı bir anahtarla imzalanmış. Bir yedek al, Soty '
      'uygulamasını kaldır, yeni sürümü elle kur ve yedeği geri yükle.',
  'Backup': 'Yedek',
  'Export backup': 'Yedeği dışa aktar',
  'Encrypted file with your identity, contacts and messages.':
      'Kimliğini, kişilerini ve mesajlarını içeren şifreli dosya.',
  'Restore backup': 'Yedekten geri yükle',
  'Replace the identity, contacts and messages on this device from a backup '
  'file.':
      'Bu cihazdaki kimliği, kişileri ve mesajları bir yedek dosyasından '
      'değiştir.',
  'Backup password': 'Yedek parolası',
  'Password must be at least {n} characters':
      'Parola en az {n} karakter olmalı',
  'Backup created: {path}': 'Yedek oluşturuldu: {path}',
  'Backup restored': 'Yedek geri yüklendi',
  'Wrong password or damaged backup file':
      'Parola yanlış ya da yedek dosyası bozuk',
  'Restore this backup?': 'Bu yedek geri yüklensin mi?',
  'This replaces your identity, contacts and messages and restarts Soty.':
      'Bu işlem kimliğini, kişilerini ve mesajlarını değiştirir ve Soty '
      'uygulamasını yeniden başlatır.',
  'Restore': 'Geri yükle',
  'Picking a file is not supported on this platform':
      'Bu platformda dosya seçme desteklenmiyor',
  'Backup failed': 'Yedek alınamadı',
  'Export': 'Dışa aktar',
  'Copy code': 'Kodu kopyala',
  'Could not verify this contact': 'Bu kişi doğrulanamadı',
  'Safety number': 'Güvenlik numarası',
  'Compare this code with {name} in person or over a trusted channel.':
      'Bu kodu {name} ile yüz yüze ya da güvendiğin bir kanal üzerinden '
      'karşılaştır.',
  'Not verified': 'Doğrulanmadı',
  'Verified': 'Doğrulandı',
  'Security code changed': 'Güvenlik kodu değişti',
  '{name} presented a new key. Compare the new code before trusting this chat.':
      '{name} yeni bir anahtar sundu. Bu sohbete güvenmeden önce yeni kodu '
      'karşılaştır.',
  'Mark as verified': 'Doğrulanmış olarak işaretle',
  'Scan their code': 'Kodunu tara',
  'Safety codes match': 'Güvenlik kodları eşleşiyor',
  'Safety codes do not match': 'Güvenlik kodları eşleşmiyor',
  'Safety code unavailable': 'Güvenlik kodu kullanılamıyor',
  'This contact has not published an Ed25519 key yet.':
      'Bu kişi henüz bir Ed25519 anahtarı yayımlamadı.',
  'Failed to save photo': 'Fotoğraf kaydedilemedi',
  'Photo saved to {path}': 'Fotoğraf {path} konumuna kaydedildi',
  'Messaging with no server and no account. Pick a display name — it is '
  'signed into the invite other Soty users import to reach you.':
      'Sunucusuz ve hesapsız mesajlaşma. Bir görünen ad seç — bu ad, diğer '
      'Soty kullanıcılarının sana ulaşmak için içe aktardığı davete imzalanır.',
  'Display name': 'Görünen ad',
  'Roll another name': 'Başka bir ad öner',
  'Continue': 'Devam',
  'You can change your name later in the identity screen.':
      'Adını daha sonra kimlik ekranında değiştirebilirsin.',
  'Cancel': 'İptal',
  'Save': 'Kaydet',
  'Invite copied to clipboard': 'Davet panoya kopyalandı',
  'Import invite': 'Daveti içe aktar',
  'Paste the invite JSON here': 'Davet JSON değerini buraya yapıştır',
  'Import': 'İçe aktar',
  'Peer imported': 'Eş içe aktarıldı',
  'Invite rejected': 'Davet reddedildi',
  'Import contact': 'Kişiyi içe aktar',
  'Paste invite JSON': 'Davet JSON değerini yapıştır',
  'Enter manually': 'Elle gir',
  'Unknown contact — import it first to reply.':
      'Bilinmeyen kişi — yanıtlamak için önce içe aktar.',
  'Add peer': 'Eş ekle',
  'Peer X25519 public key (hex)': 'Eşin X25519 açık anahtarı (hex)',
  'Peer X25519 public key (hex) *': 'Eşin X25519 açık anahtarı (hex) *',
  'Name (optional)': 'Ad (isteğe bağlı)',
  'libp2p peer id (optional)': 'libp2p eş kimliği (isteğe bağlı)',
  'Multiaddr (optional, e.g. /ip4/…/tcp/4001)':
      'Multiaddr (isteğe bağlı, örn. /ip4/…/tcp/4001)',
  'Multiaddr (optional)': 'Multiaddr (isteğe bağlı)',
  'Public key must be 64 hex characters': 'Açık anahtar 64 hex karakter olmalı',
  'Add': 'Ekle',
  'Identity': 'Kimlik',
  'Unnamed': 'Adsız',
  'Ed25519 (identity / signing)': 'Ed25519 (kimlik / imzalama)',
  'X25519 (address peers send to)': 'X25519 (eşlerin gönderdiği adres)',
  'Copy invite': 'Daveti kopyala',
  'Signed identity claim — paste it to import your key.':
      'İmzalı kimlik beyanı — anahtarını içe aktarmak için yapıştır.',
  'Paste a friend’s signed invite to add them.':
      'Bir arkadaşını eklemek için imzalı davetini yapıştır.',
  'Add a peer': 'Eş ekle',
  'Paste their X25519 key (+ optional libp2p address) to start a conversation.':
      'Sohbet başlatmak için X25519 anahtarını (+ isteğe bağlı libp2p adresi) '
      'yapıştır.',
  'Pruning': 'Temizleme',
  'Retention & integrity roots.': 'Saklama ve bütünlük kökleri.',
  'Public key copied': 'Açık anahtar kopyalandı',
  'Pruning integrity roots': 'Temizleme bütünlük kökleri',
  'No batches pruned yet.': 'Henüz hiçbir parti temizlenmedi.',
  'Cutoff {ts}': 'Sınır {ts}',
  'count: {n}\n{root}': 'adet: {n}\n{root}',
  'New chat': 'Yeni sohbet',
  'Start': 'Başlat',
  'Invalid public key': 'Geçersiz açık anahtar',
  'Chats': 'Sohbetler',
  'No conversations yet.\nAdd a peer to start.':
      'Henüz sohbet yok.\nBaşlamak için bir eş ekle.',
  'online': 'online',
  'offline': 'offline',
  'last seen just now': 'az önce görüldü',
  'last seen {n} min ago': '{n} dk önce görüldü',
  'last seen {n} h ago': '{n} sa önce görüldü',
  'last seen {n} d ago': '{n} gün önce görüldü',
  'No messages yet.': 'Henüz mesaj yok.',
  'Text message': 'Metin mesajı',
  'Message exceeds the 4 KB limit': 'Mesaj 4 KB sınırını aşıyor',
  'Message could not be sent': 'Mesaj gönderilemedi',
  'Reply': 'Yanıtla',
  'Forward': 'İlet',
  'Copy': 'Kopyala',
  'Share': 'Paylaş',
  'Copied': 'Kopyalandı',
  'Forward to': 'Şuraya ilet',
  'Group': 'Grup',
  'No conversations yet.': 'Henüz sohbet yok.',
  'Recent': 'Son kullanılanlar',
  'Emoji': 'Emoji',
  'No recent emoji': 'Son kullanılan emoji yok',
  'Smileys & emotion': 'İfadeler ve duygular',
  'People & gestures': 'İnsanlar ve jestler',
  'Animals & nature': 'Hayvanlar ve doğa',
  'Food & drink': 'Yiyecek ve içecek',
  'Travel & places': 'Seyahat ve yerler',
  'Activities': 'Etkinlikler',
  'Objects': 'Nesneler',
  'Symbols': 'Semboller',
  'Peers': 'Eşler',
  'Rename chat': 'Sohbeti yeniden adlandır',
  'Rename contact': 'Kişiyi yeniden adlandır',
  'No contacts yet.\nImport an invite to start.':
      'Henüz kişi yok.\nBaşlamak için bir davet içe aktar.',
  'Chat name': 'Sohbet adı',
  'Name updated': 'Ad güncellendi',
  'Unlock Soty': 'Soty kilidini aç',
  'Soty is locked': 'Soty kilitli',
  'Enter your password to continue.': 'Devam etmek için parolanı gir.',
  'Password': 'Parola',
  'Incorrect password': 'Parola yanlış',
  'Unlock with fingerprint': 'Parmak iziyle aç',
  'Unlock': 'Kilidi aç',
  'Invite link copied to clipboard': 'Davet bağlantısı panoya kopyalandı',
  'My QR code': 'QR kodum',
  'Copy invite link': 'Davet bağlantısını kopyala',
  'No identity yet.': 'Henüz kimlik yok.',
  'Others add you by scanning this code from Settings → Scan QR code.':
      'Başkaları bu kodu Ayarlar → QR kod tara yolundan okutarak seni ekler.',
  'Copy invite text': 'Davet metnini kopyala',
  'Retry': 'Yeniden dene',
  'Scan QR code': 'QR kod tara',
  'Point the camera at a Soty contact QR code.':
      'Kamerayı bir Soty kişi QR koduna doğrult.',
  'Camera unavailable. Allow camera permission and retry.':
      'Kamera kullanılamıyor. Kamera iznini ver ve yeniden dene.',
  'Contact added from QR code': 'Kişi QR koddan eklendi',
  'Invalid host link': 'Geçersiz sunucu bağlantısı',
  'Relay host added': 'Relay sunucusu eklendi',
  'Relay host list is full (max {max})':
      'Relay sunucusu listesi dolu (en fazla {max})',
  'Add relay host': 'Relay sunucusu ekle',
  'Disable app lock': 'Uygulama kilidini kapat',
  'Enter your current password.': 'Mevcut parolanı gir.',
  'Current password': 'Mevcut parola',
  'Confirm your current password.': 'Mevcut parolanı doğrula.',
  'Biometrics are not available on this device':
      'Bu cihazda biyometri kullanılamıyor',
  'Enable fingerprint unlock': 'Parmak iziyle açmayı etkinleştir',
  'Enter your password to confirm.': 'Onaylamak için parolanı gir.',
  'Set app lock password': 'Uygulama kilidi parolasını belirle',
  'Enable lock': 'Kilidi etkinleştir',
  'Confirm': 'Onayla',
  'Settings': 'Ayarlar',
  'Contact': 'Kişi',
  'Show this code so others can add you.':
      'Başkaları seni ekleyebilsin diye bu kodu göster.',
  'Add a contact by scanning their code.': 'Kodunu okutarak bir kişi ekle.',
  'Paste the invite instead of a QR.': 'QR yerine daveti yapıştır.',
  'A soty:// link that opens Soty to add you.':
      'Seni eklemek için Soty uygulamasını açan bir soty:// bağlantısı.',
  'Security': 'Güvenlik',
  'App lock': 'Uygulama kilidi',
  'Require a password to open Soty.':
      'Soty uygulamasını açmak için parola iste.',
  'Change password': 'Parolayı değiştir',
  'Fingerprint unlock': 'Parmak iziyle açma',
  'Unlock with biometrics instead of typing the password.':
      'Parola yazmak yerine biyometriyle aç.',
  'Network': 'Ağ',
  'Peers in network': 'Ağdaki eşler',
  '{n} registered · {online} online': '{n} kayıtlı · {online} çevrimiçi',
  'Active connections': 'Etkin bağlantılar',
  appLockResetNotice:
      'Uygulama kilidi sıfırlandı: kayıtlı parola bozuktu. Ayarlardan yeniden '
      'belirle.',
  '{n} visible · {connected} connected': '{n} görünür · {connected} bağlı',
  '{n} of {max} direct peers in exchange':
      '{max} doğrudan eşten {n} tanesi değişimde',
  'About': 'Hakkında',
  'Version': 'Sürüm',
  'Source and releases': 'Kaynak kodu ve sürümler',
  'Link copied to clipboard': 'Bağlantı panoya kopyalandı',
  'Active peers limit': 'Etkin eş sınırı',
  'Keep at most {n} direct peers connected.':
      'En fazla {n} doğrudan eş bağlı tut.',
  'Relay hosts': 'Relay sunucuları',
  'Connected': 'Bağlı',
  'Offline': 'Çevrimdışı',
  'Remove host': 'Sunucuyu kaldır',
  'Paste a ws:// URL or a soty:// host link.':
      'Bir ws:// adresi ya da soty:// sunucu bağlantısı yapıştır.',
  'Tracker discovery': 'İzleyiciyle keşif',
  'Peers found via trackers: {n}.': 'İzleyiciler üzerinden bulunan eşler: {n}.',
  'How many direct peers the device keeps available at once. Raise it for '
  'dense meshes; lower it to save battery and traffic.':
      'Cihazın aynı anda kaç doğrudan eşi hazır tuttuğu. Yoğun mesh ağlarında '
      'artır; pil ve trafikten tasarruf için azalt.',
  'Apply': 'Uygula',
  'Use {min}–{max} characters': '{min}–{max} karakter kullan',
  'Passwords do not match': 'Parolalar eşleşmiyor',
  'Repeat password': 'Parolayı yinele',
  'A relay host stores only encrypted envelopes. Anyone running one can see '
  'who talks to whom, so use hosts you trust.':
      'Relay sunucusu yalnızca şifreli zarflar saklar. Onu işleten herkes '
      'kimin kiminle konuştuğunu görebilir, bu yüzden güvendiğin sunucuları '
      'kullan.',
  'Host': 'Sunucu',
  'ws://host:port/ws or soty://host?addr=…':
      'ws://host:port/ws veya soty://host?addr=…',
  'Appearance': 'Görünüm',
  'Language': 'Dil',
  'Theme': 'Tema',
  'System': 'Sistem',
  'Light': 'Açık',
  'Dark': 'Koyu',
  'Failed to start Soty:\n{error}': 'Soty başlatılamadı:\n{error}',
  'Invalid relay host link': 'Geçersiz relay sunucusu bağlantısı',
  'Relay host list is full': 'Relay sunucusu listesi dolu',
  'Invalid invite link': 'Geçersiz davet bağlantısı',
  'Insecure or expired invite': 'Güvenli olmayan ya da süresi geçmiş davet',
  'Messages': 'Mesajlar',
  'Encrypted message': 'Şifreli mesaj',
  'Send with Enter': 'Enter ile gönder',
  'Press Enter to send; turn it off to add a new line.':
      'Göndermek için Enter tuşuna bas; kapatırsan yeni satır eklersin.',
  'Storage': 'Depolama',
  'Keep messages': 'Mesajları sakla',
  'Save sent messages': 'Gönderilen mesajları kaydet',
  'Relay failover': 'Relay yedeklemesi',
  'Only configured relays': 'Yalnızca tanımlı relay sunucuları',
  'Automatic fallback': 'Otomatik yedek',
  'Never use relays learned from trackers.':
      'İzleyicilerden öğrenilen relay sunucularını kullanma.',
  'Use relays learned from hosts when the configured ones are unreachable.':
      'Tanımlı sunuculara ulaşılamadığında sunuculardan öğrenilen relay '
      'sunucularını kullan.',
  'Keep my sent messages on this device so they stay readable after restart':
      'Gönderdiğim mesajları bu cihazda sakla, yeniden başlatmadan sonra da '
      'okunabilsin',
  'How long your own conversations stay on this device. Envelopes you only '
  'relay for others are always pruned after 30 days (capped at 10 GB).':
      'Kendi sohbetlerinin bu cihazda ne kadar kaldığı. Yalnızca başkaları '
      'için ilettiğin zarflar her zaman 30 gün sonra temizlenir (en fazla 10 '
      'GB).',
  '{n} days': '{n} gün',
  '{n} days|one': '{n} gün',
  'Forever': 'Sonsuza kadar',
  'New group': 'Yeni grup',
  'Group name': 'Grup adı',
  'Members: {n}': 'Üyeler: {n}',
  'Members: {n}|one': 'Üye: {n}',
  'Create': 'Oluştur',
  'Add peers first.': 'Önce eş ekle.',
  'Notifications': 'Bildirimler',
  'Message notifications': 'Mesaj bildirimleri',
  'Enabled on this device': 'Bu cihazda etkin',
  'Blocked by the system': 'Sistem tarafından engellendi',
  'Not available: {reason}': 'Kullanılamıyor: {reason}',
  'Not supported on this platform': 'Bu platformda desteklenmiyor',
  'Checking notification support…': 'Bildirim desteği denetleniyor…',
  'Open system notification settings': 'Sistem bildirim ayarlarını aç',
  'Send test notification': 'Test bildirimi gönder',
  'Test notification sent': 'Test bildirimi gönderildi',
  'Notifications are blocked by the system':
      'Bildirimler sistem tarafından engellendi',
  'Test notification failed: {reason}':
      'Test bildirimi gönderilemedi: {reason}',
  'Test notification': 'Test bildirimi',
  'Open': 'Aç',
  'Mesh (BLE/Wi-Fi Direct)': 'Mesh (BLE/Wi-Fi Direct)',
  '{n} nodes in range': 'Menzilde {n} düğüm',
  'Off': 'Kapalı',
  'Permission required': 'İzin gerekli',
  'Unavailable': 'Kullanılamıyor',
  'Background': 'Arka plan',
  'Work in background': 'Arka planda çalış',
  'Keep mesh and relays alive while the app is not in the chat':
      'Uygulama sohbette değilken mesh ağını ve relay sunucularını açık tut',
  'Battery optimization': 'Pil optimizasyonu',
  'No restrictions': 'Kısıtlama yok',
  'Restricted by the system': 'Sistem tarafından kısıtlandı',
  'Checking…': 'Denetleniyor…',
  'Read receipts': 'Okundu bilgisi',
  'Send read receipts so others know when you have read their messages.':
      'Mesajlarını okuduğunda karşı tarafın bilmesi için okundu bilgisi '
      'gönder.',
  'Sending': 'Gönderiliyor',
  'Sent': 'Gönderildi',
  'Delivered': 'İletildi',
  'Read': 'Okundu',
  'Update available': 'Güncelleme var',
  'Version {v} is available': '{v} sürümü hazır',
  'Download': 'İndir',
  'Install': 'Kur',
  'Hide': 'Gizle',
  'Remind later': 'Sonra hatırlat',
  'Allow Soty to install apps, then tap Install again.':
      'Soty uygulamasına uygulama kurma izni ver, sonra yeniden Kur düğmesine '
      'dokun.',
  'Download failed': 'İndirme başarısız',
  'The downloaded file failed its checksum check':
      'İndirilen dosya sağlama toplamı denetimini geçemedi',
  'Check for updates': 'Güncellemeleri denetle',
  'Could not check for updates': 'Güncellemeler denetlenemedi',
  'You have the latest version': 'En son sürümü kullanıyorsun',
  'Current version: {v}': 'Geçerli sürüm: {v}',
  'Release notes': 'Sürüm notları',
  'Close': 'Kapat',
  'Voice message': 'Sesli mesaj',
  'Photo': 'Fotoğraf',
  'Recording… {s} s left': 'Kaydediliyor… {s} sn kaldı',
  'Photo is too large (max {kb} KB)': 'Fotoğraf çok büyük (en fazla {kb} KB)',
  'Voice message is too short': 'Sesli mesaj çok kısa',
  'Voice message is too large': 'Sesli mesaj çok büyük',
  'Microphone permission is required': 'Mikrofon izni gerekiyor',
  'Recording failed': 'Kayıt başarısız',
  'Voice message failed': 'Sesli mesaj başarısız',
  'Photo unavailable': 'Fotoğraf kullanılamıyor',
  'Unsupported photo format': 'Desteklenmeyen fotoğraf biçimi',
  'Play voice message': 'Sesli mesajı oynat',
  'Stop': 'Durdur',
  'Not delivered yet ({n})':
      'Henüz teslim edilmedi ({n})',
  'Message not delivered yet — Soty will retry when the peer is '
  'reachable.':
      'Henüz teslim edilmedi — Soty alıcıya ulaşılabildiğinde yeniden '
      'deneyecek.',
  'Report abuse': 'Kötüye kullanım bildir',
  'Opens the report form on soty.su in a browser':
      'soty.su üzerindeki bildirim formunu tarayıcıda açar',
  'Link copied': 'Bağlantı kopyalandı',
  'Block contact': 'Kişiyi engelle',
  'Messages from this contact are ignored and never decrypted.':
      'Bu kişinin mesajları yok sayılır ve hiçbir zaman çözülmez.',
  'You blocked this contact. Unblock it in the safety screen.':
      'Bu kişiyi engellediniz. Güvenlik kodu ekranından engeli kaldırın.',
  'Privacy policy': 'Gizlilik politikası',
  'Terms of use': 'Kullanım koşulları',
  'Keys cannot be read': 'Anahtarlar okunamıyor',
  'This usually happens when app data was restored from a '
      'system backup: the backup holds the encrypted keys, but '
      'the device key that decrypts them stayed on the old '
      'phone. Messages cannot be decrypted without it.':
      'Bu genellikle uygulama verileri sistem yedeğinden geri '
      'yüklendiğinde olur: yedekte şifreli anahtarlar vardır, '
      'ancak onları çözen cihaz anahtarı eski telefonda '
      'kalmıştır. O olmadan mesajlar çözülemez.',
  'Start over': 'Baştan başla',
  'Try again': 'Yeniden dene',
  'Delete local data': 'Yerel verileri sil',
  'Start over deletes the local database and media on this '
      'device. If you have a Soty backup file, restore it in '
      'Settings after the app starts.':
      '«Baştan başla» bu cihazdaki yerel veritabanını ve '
      'medyayı siler. Soty yedek dosyanız varsa uygulama '
      'açıldıktan sonra Ayarlar’dan geri yükleyin.',
};
