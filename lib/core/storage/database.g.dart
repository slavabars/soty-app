// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
class $MessagesTable extends Messages with TableInfo<$MessagesTable, Message> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MessagesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _senderPubKeyMeta = const VerificationMeta(
    'senderPubKey',
  );
  @override
  late final GeneratedColumn<String> senderPubKey = GeneratedColumn<String>(
    'sender_pub_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _recipientPubKeyMeta = const VerificationMeta(
    'recipientPubKey',
  );
  @override
  late final GeneratedColumn<String> recipientPubKey = GeneratedColumn<String>(
    'recipient_pub_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _timestampMeta = const VerificationMeta(
    'timestamp',
  );
  @override
  late final GeneratedColumn<int> timestamp = GeneratedColumn<int>(
    'timestamp',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _ciphertextMeta = const VerificationMeta(
    'ciphertext',
  );
  @override
  late final GeneratedColumn<String> ciphertext = GeneratedColumn<String>(
    'ciphertext',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _ephemeralPubKeyMeta = const VerificationMeta(
    'ephemeralPubKey',
  );
  @override
  late final GeneratedColumn<String> ephemeralPubKey = GeneratedColumn<String>(
    'ephemeral_pub_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _signatureMeta = const VerificationMeta(
    'signature',
  );
  @override
  late final GeneratedColumn<String> signature = GeneratedColumn<String>(
    'signature',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sourceMeta = const VerificationMeta('source');
  @override
  late final GeneratedColumn<String> source = GeneratedColumn<String>(
    'source',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _hopsMeta = const VerificationMeta('hops');
  @override
  late final GeneratedColumn<int> hops = GeneratedColumn<int>(
    'hops',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _chainLinkMeta = const VerificationMeta(
    'chainLink',
  );
  @override
  late final GeneratedColumn<String> chainLink = GeneratedColumn<String>(
    'chain_link',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _forkedMeta = const VerificationMeta('forked');
  @override
  late final GeneratedColumn<int> forked = GeneratedColumn<int>(
    'forked',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _controlMeta = const VerificationMeta(
    'control',
  );
  @override
  late final GeneratedColumn<int> control = GeneratedColumn<int>(
    'control',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _groupPayloadMeta = const VerificationMeta(
    'groupPayload',
  );
  @override
  late final GeneratedColumn<int> groupPayload = GeneratedColumn<int>(
    'group_payload',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _groupIdMeta = const VerificationMeta(
    'groupId',
  );
  @override
  late final GeneratedColumn<String> groupId = GeneratedColumn<String>(
    'group_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _directOnlyMeta = const VerificationMeta(
    'directOnly',
  );
  @override
  late final GeneratedColumn<int> directOnly = GeneratedColumn<int>(
    'direct_only',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    senderPubKey,
    recipientPubKey,
    timestamp,
    ciphertext,
    ephemeralPubKey,
    signature,
    source,
    hops,
    chainLink,
    forked,
    control,
    groupPayload,
    groupId,
    directOnly,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'messages';
  @override
  VerificationContext validateIntegrity(
    Insertable<Message> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('sender_pub_key')) {
      context.handle(
        _senderPubKeyMeta,
        senderPubKey.isAcceptableOrUnknown(
          data['sender_pub_key']!,
          _senderPubKeyMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_senderPubKeyMeta);
    }
    if (data.containsKey('recipient_pub_key')) {
      context.handle(
        _recipientPubKeyMeta,
        recipientPubKey.isAcceptableOrUnknown(
          data['recipient_pub_key']!,
          _recipientPubKeyMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_recipientPubKeyMeta);
    }
    if (data.containsKey('timestamp')) {
      context.handle(
        _timestampMeta,
        timestamp.isAcceptableOrUnknown(data['timestamp']!, _timestampMeta),
      );
    } else if (isInserting) {
      context.missing(_timestampMeta);
    }
    if (data.containsKey('ciphertext')) {
      context.handle(
        _ciphertextMeta,
        ciphertext.isAcceptableOrUnknown(data['ciphertext']!, _ciphertextMeta),
      );
    } else if (isInserting) {
      context.missing(_ciphertextMeta);
    }
    if (data.containsKey('ephemeral_pub_key')) {
      context.handle(
        _ephemeralPubKeyMeta,
        ephemeralPubKey.isAcceptableOrUnknown(
          data['ephemeral_pub_key']!,
          _ephemeralPubKeyMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_ephemeralPubKeyMeta);
    }
    if (data.containsKey('signature')) {
      context.handle(
        _signatureMeta,
        signature.isAcceptableOrUnknown(data['signature']!, _signatureMeta),
      );
    } else if (isInserting) {
      context.missing(_signatureMeta);
    }
    if (data.containsKey('source')) {
      context.handle(
        _sourceMeta,
        source.isAcceptableOrUnknown(data['source']!, _sourceMeta),
      );
    } else if (isInserting) {
      context.missing(_sourceMeta);
    }
    if (data.containsKey('hops')) {
      context.handle(
        _hopsMeta,
        hops.isAcceptableOrUnknown(data['hops']!, _hopsMeta),
      );
    }
    if (data.containsKey('chain_link')) {
      context.handle(
        _chainLinkMeta,
        chainLink.isAcceptableOrUnknown(data['chain_link']!, _chainLinkMeta),
      );
    }
    if (data.containsKey('forked')) {
      context.handle(
        _forkedMeta,
        forked.isAcceptableOrUnknown(data['forked']!, _forkedMeta),
      );
    }
    if (data.containsKey('control')) {
      context.handle(
        _controlMeta,
        control.isAcceptableOrUnknown(data['control']!, _controlMeta),
      );
    }
    if (data.containsKey('group_payload')) {
      context.handle(
        _groupPayloadMeta,
        groupPayload.isAcceptableOrUnknown(
          data['group_payload']!,
          _groupPayloadMeta,
        ),
      );
    }
    if (data.containsKey('group_id')) {
      context.handle(
        _groupIdMeta,
        groupId.isAcceptableOrUnknown(data['group_id']!, _groupIdMeta),
      );
    }
    if (data.containsKey('direct_only')) {
      context.handle(
        _directOnlyMeta,
        directOnly.isAcceptableOrUnknown(data['direct_only']!, _directOnlyMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Message map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Message(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      senderPubKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sender_pub_key'],
      )!,
      recipientPubKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}recipient_pub_key'],
      )!,
      timestamp: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}timestamp'],
      )!,
      ciphertext: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}ciphertext'],
      )!,
      ephemeralPubKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}ephemeral_pub_key'],
      )!,
      signature: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}signature'],
      )!,
      source: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source'],
      )!,
      hops: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}hops'],
      )!,
      chainLink: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}chain_link'],
      )!,
      forked: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}forked'],
      )!,
      control: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}control'],
      )!,
      groupPayload: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}group_payload'],
      )!,
      groupId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}group_id'],
      ),
      directOnly: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}direct_only'],
      )!,
    );
  }

  @override
  $MessagesTable createAlias(String alias) {
    return $MessagesTable(attachedDatabase, alias);
  }
}

class Message extends DataClass implements Insertable<Message> {
  final String id;
  final String senderPubKey;
  final String recipientPubKey;
  final int timestamp;
  final String ciphertext;
  final String ephemeralPubKey;
  final String signature;
  final String source;
  final int hops;
  final String chainLink;
  final int forked;

  /// Local-only: marks an envelope that carries a control payload (a delivery
  /// or read receipt) rather than a chat message. Such rows are evidence and
  /// are deduped like any other, but never render as a bubble nor count as
  /// unread. Not part of the wire format.
  final int control;

  /// Local-only: marks an envelope that carries a group container (`g2`/`g3`/
  /// `t1`/legacy `g1`). Such a row is addressed to us like any 1:1 message, so
  /// without the mark it would count as unread on the sender's direct chat as
  /// well as on the group. Not part of the wire format.
  final int groupPayload;

  /// Local-only: the group conversation a container belongs to. Without it a
  /// member shared by two groups would make one group's message count as
  /// unread in the other. Not part of the wire format.
  final String? groupId;

  /// Local-only: the envelope may only travel over a direct peer transport
  /// (p2p/mesh), never through a relay host. Media slices use it so relays
  /// never store a file; the manifest still travels normally and lets the
  /// recipient show a "wait for the sender" placeholder.
  final int directOnly;
  const Message({
    required this.id,
    required this.senderPubKey,
    required this.recipientPubKey,
    required this.timestamp,
    required this.ciphertext,
    required this.ephemeralPubKey,
    required this.signature,
    required this.source,
    required this.hops,
    required this.chainLink,
    required this.forked,
    required this.control,
    required this.groupPayload,
    this.groupId,
    required this.directOnly,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['sender_pub_key'] = Variable<String>(senderPubKey);
    map['recipient_pub_key'] = Variable<String>(recipientPubKey);
    map['timestamp'] = Variable<int>(timestamp);
    map['ciphertext'] = Variable<String>(ciphertext);
    map['ephemeral_pub_key'] = Variable<String>(ephemeralPubKey);
    map['signature'] = Variable<String>(signature);
    map['source'] = Variable<String>(source);
    map['hops'] = Variable<int>(hops);
    map['chain_link'] = Variable<String>(chainLink);
    map['forked'] = Variable<int>(forked);
    map['control'] = Variable<int>(control);
    map['group_payload'] = Variable<int>(groupPayload);
    if (!nullToAbsent || groupId != null) {
      map['group_id'] = Variable<String>(groupId);
    }
    map['direct_only'] = Variable<int>(directOnly);
    return map;
  }

  MessagesCompanion toCompanion(bool nullToAbsent) {
    return MessagesCompanion(
      id: Value(id),
      senderPubKey: Value(senderPubKey),
      recipientPubKey: Value(recipientPubKey),
      timestamp: Value(timestamp),
      ciphertext: Value(ciphertext),
      ephemeralPubKey: Value(ephemeralPubKey),
      signature: Value(signature),
      source: Value(source),
      hops: Value(hops),
      chainLink: Value(chainLink),
      forked: Value(forked),
      control: Value(control),
      groupPayload: Value(groupPayload),
      groupId: groupId == null && nullToAbsent
          ? const Value.absent()
          : Value(groupId),
      directOnly: Value(directOnly),
    );
  }

  factory Message.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Message(
      id: serializer.fromJson<String>(json['id']),
      senderPubKey: serializer.fromJson<String>(json['senderPubKey']),
      recipientPubKey: serializer.fromJson<String>(json['recipientPubKey']),
      timestamp: serializer.fromJson<int>(json['timestamp']),
      ciphertext: serializer.fromJson<String>(json['ciphertext']),
      ephemeralPubKey: serializer.fromJson<String>(json['ephemeralPubKey']),
      signature: serializer.fromJson<String>(json['signature']),
      source: serializer.fromJson<String>(json['source']),
      hops: serializer.fromJson<int>(json['hops']),
      chainLink: serializer.fromJson<String>(json['chainLink']),
      forked: serializer.fromJson<int>(json['forked']),
      control: serializer.fromJson<int>(json['control']),
      groupPayload: serializer.fromJson<int>(json['groupPayload']),
      groupId: serializer.fromJson<String?>(json['groupId']),
      directOnly: serializer.fromJson<int>(json['directOnly']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'senderPubKey': serializer.toJson<String>(senderPubKey),
      'recipientPubKey': serializer.toJson<String>(recipientPubKey),
      'timestamp': serializer.toJson<int>(timestamp),
      'ciphertext': serializer.toJson<String>(ciphertext),
      'ephemeralPubKey': serializer.toJson<String>(ephemeralPubKey),
      'signature': serializer.toJson<String>(signature),
      'source': serializer.toJson<String>(source),
      'hops': serializer.toJson<int>(hops),
      'chainLink': serializer.toJson<String>(chainLink),
      'forked': serializer.toJson<int>(forked),
      'control': serializer.toJson<int>(control),
      'groupPayload': serializer.toJson<int>(groupPayload),
      'groupId': serializer.toJson<String?>(groupId),
      'directOnly': serializer.toJson<int>(directOnly),
    };
  }

  Message copyWith({
    String? id,
    String? senderPubKey,
    String? recipientPubKey,
    int? timestamp,
    String? ciphertext,
    String? ephemeralPubKey,
    String? signature,
    String? source,
    int? hops,
    String? chainLink,
    int? forked,
    int? control,
    int? groupPayload,
    Value<String?> groupId = const Value.absent(),
    int? directOnly,
  }) => Message(
    id: id ?? this.id,
    senderPubKey: senderPubKey ?? this.senderPubKey,
    recipientPubKey: recipientPubKey ?? this.recipientPubKey,
    timestamp: timestamp ?? this.timestamp,
    ciphertext: ciphertext ?? this.ciphertext,
    ephemeralPubKey: ephemeralPubKey ?? this.ephemeralPubKey,
    signature: signature ?? this.signature,
    source: source ?? this.source,
    hops: hops ?? this.hops,
    chainLink: chainLink ?? this.chainLink,
    forked: forked ?? this.forked,
    control: control ?? this.control,
    groupPayload: groupPayload ?? this.groupPayload,
    groupId: groupId.present ? groupId.value : this.groupId,
    directOnly: directOnly ?? this.directOnly,
  );
  Message copyWithCompanion(MessagesCompanion data) {
    return Message(
      id: data.id.present ? data.id.value : this.id,
      senderPubKey: data.senderPubKey.present
          ? data.senderPubKey.value
          : this.senderPubKey,
      recipientPubKey: data.recipientPubKey.present
          ? data.recipientPubKey.value
          : this.recipientPubKey,
      timestamp: data.timestamp.present ? data.timestamp.value : this.timestamp,
      ciphertext: data.ciphertext.present
          ? data.ciphertext.value
          : this.ciphertext,
      ephemeralPubKey: data.ephemeralPubKey.present
          ? data.ephemeralPubKey.value
          : this.ephemeralPubKey,
      signature: data.signature.present ? data.signature.value : this.signature,
      source: data.source.present ? data.source.value : this.source,
      hops: data.hops.present ? data.hops.value : this.hops,
      chainLink: data.chainLink.present ? data.chainLink.value : this.chainLink,
      forked: data.forked.present ? data.forked.value : this.forked,
      control: data.control.present ? data.control.value : this.control,
      groupPayload: data.groupPayload.present
          ? data.groupPayload.value
          : this.groupPayload,
      groupId: data.groupId.present ? data.groupId.value : this.groupId,
      directOnly: data.directOnly.present
          ? data.directOnly.value
          : this.directOnly,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Message(')
          ..write('id: $id, ')
          ..write('senderPubKey: $senderPubKey, ')
          ..write('recipientPubKey: $recipientPubKey, ')
          ..write('timestamp: $timestamp, ')
          ..write('ciphertext: $ciphertext, ')
          ..write('ephemeralPubKey: $ephemeralPubKey, ')
          ..write('signature: $signature, ')
          ..write('source: $source, ')
          ..write('hops: $hops, ')
          ..write('chainLink: $chainLink, ')
          ..write('forked: $forked, ')
          ..write('control: $control, ')
          ..write('groupPayload: $groupPayload, ')
          ..write('groupId: $groupId, ')
          ..write('directOnly: $directOnly')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    senderPubKey,
    recipientPubKey,
    timestamp,
    ciphertext,
    ephemeralPubKey,
    signature,
    source,
    hops,
    chainLink,
    forked,
    control,
    groupPayload,
    groupId,
    directOnly,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Message &&
          other.id == this.id &&
          other.senderPubKey == this.senderPubKey &&
          other.recipientPubKey == this.recipientPubKey &&
          other.timestamp == this.timestamp &&
          other.ciphertext == this.ciphertext &&
          other.ephemeralPubKey == this.ephemeralPubKey &&
          other.signature == this.signature &&
          other.source == this.source &&
          other.hops == this.hops &&
          other.chainLink == this.chainLink &&
          other.forked == this.forked &&
          other.control == this.control &&
          other.groupPayload == this.groupPayload &&
          other.groupId == this.groupId &&
          other.directOnly == this.directOnly);
}

class MessagesCompanion extends UpdateCompanion<Message> {
  final Value<String> id;
  final Value<String> senderPubKey;
  final Value<String> recipientPubKey;
  final Value<int> timestamp;
  final Value<String> ciphertext;
  final Value<String> ephemeralPubKey;
  final Value<String> signature;
  final Value<String> source;
  final Value<int> hops;
  final Value<String> chainLink;
  final Value<int> forked;
  final Value<int> control;
  final Value<int> groupPayload;
  final Value<String?> groupId;
  final Value<int> directOnly;
  final Value<int> rowid;
  const MessagesCompanion({
    this.id = const Value.absent(),
    this.senderPubKey = const Value.absent(),
    this.recipientPubKey = const Value.absent(),
    this.timestamp = const Value.absent(),
    this.ciphertext = const Value.absent(),
    this.ephemeralPubKey = const Value.absent(),
    this.signature = const Value.absent(),
    this.source = const Value.absent(),
    this.hops = const Value.absent(),
    this.chainLink = const Value.absent(),
    this.forked = const Value.absent(),
    this.control = const Value.absent(),
    this.groupPayload = const Value.absent(),
    this.groupId = const Value.absent(),
    this.directOnly = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  MessagesCompanion.insert({
    required String id,
    required String senderPubKey,
    required String recipientPubKey,
    required int timestamp,
    required String ciphertext,
    required String ephemeralPubKey,
    required String signature,
    required String source,
    this.hops = const Value.absent(),
    this.chainLink = const Value.absent(),
    this.forked = const Value.absent(),
    this.control = const Value.absent(),
    this.groupPayload = const Value.absent(),
    this.groupId = const Value.absent(),
    this.directOnly = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       senderPubKey = Value(senderPubKey),
       recipientPubKey = Value(recipientPubKey),
       timestamp = Value(timestamp),
       ciphertext = Value(ciphertext),
       ephemeralPubKey = Value(ephemeralPubKey),
       signature = Value(signature),
       source = Value(source);
  static Insertable<Message> custom({
    Expression<String>? id,
    Expression<String>? senderPubKey,
    Expression<String>? recipientPubKey,
    Expression<int>? timestamp,
    Expression<String>? ciphertext,
    Expression<String>? ephemeralPubKey,
    Expression<String>? signature,
    Expression<String>? source,
    Expression<int>? hops,
    Expression<String>? chainLink,
    Expression<int>? forked,
    Expression<int>? control,
    Expression<int>? groupPayload,
    Expression<String>? groupId,
    Expression<int>? directOnly,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (senderPubKey != null) 'sender_pub_key': senderPubKey,
      if (recipientPubKey != null) 'recipient_pub_key': recipientPubKey,
      if (timestamp != null) 'timestamp': timestamp,
      if (ciphertext != null) 'ciphertext': ciphertext,
      if (ephemeralPubKey != null) 'ephemeral_pub_key': ephemeralPubKey,
      if (signature != null) 'signature': signature,
      if (source != null) 'source': source,
      if (hops != null) 'hops': hops,
      if (chainLink != null) 'chain_link': chainLink,
      if (forked != null) 'forked': forked,
      if (control != null) 'control': control,
      if (groupPayload != null) 'group_payload': groupPayload,
      if (groupId != null) 'group_id': groupId,
      if (directOnly != null) 'direct_only': directOnly,
      if (rowid != null) 'rowid': rowid,
    });
  }

  MessagesCompanion copyWith({
    Value<String>? id,
    Value<String>? senderPubKey,
    Value<String>? recipientPubKey,
    Value<int>? timestamp,
    Value<String>? ciphertext,
    Value<String>? ephemeralPubKey,
    Value<String>? signature,
    Value<String>? source,
    Value<int>? hops,
    Value<String>? chainLink,
    Value<int>? forked,
    Value<int>? control,
    Value<int>? groupPayload,
    Value<String?>? groupId,
    Value<int>? directOnly,
    Value<int>? rowid,
  }) {
    return MessagesCompanion(
      id: id ?? this.id,
      senderPubKey: senderPubKey ?? this.senderPubKey,
      recipientPubKey: recipientPubKey ?? this.recipientPubKey,
      timestamp: timestamp ?? this.timestamp,
      ciphertext: ciphertext ?? this.ciphertext,
      ephemeralPubKey: ephemeralPubKey ?? this.ephemeralPubKey,
      signature: signature ?? this.signature,
      source: source ?? this.source,
      hops: hops ?? this.hops,
      chainLink: chainLink ?? this.chainLink,
      forked: forked ?? this.forked,
      control: control ?? this.control,
      groupPayload: groupPayload ?? this.groupPayload,
      groupId: groupId ?? this.groupId,
      directOnly: directOnly ?? this.directOnly,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (senderPubKey.present) {
      map['sender_pub_key'] = Variable<String>(senderPubKey.value);
    }
    if (recipientPubKey.present) {
      map['recipient_pub_key'] = Variable<String>(recipientPubKey.value);
    }
    if (timestamp.present) {
      map['timestamp'] = Variable<int>(timestamp.value);
    }
    if (ciphertext.present) {
      map['ciphertext'] = Variable<String>(ciphertext.value);
    }
    if (ephemeralPubKey.present) {
      map['ephemeral_pub_key'] = Variable<String>(ephemeralPubKey.value);
    }
    if (signature.present) {
      map['signature'] = Variable<String>(signature.value);
    }
    if (source.present) {
      map['source'] = Variable<String>(source.value);
    }
    if (hops.present) {
      map['hops'] = Variable<int>(hops.value);
    }
    if (chainLink.present) {
      map['chain_link'] = Variable<String>(chainLink.value);
    }
    if (forked.present) {
      map['forked'] = Variable<int>(forked.value);
    }
    if (control.present) {
      map['control'] = Variable<int>(control.value);
    }
    if (groupPayload.present) {
      map['group_payload'] = Variable<int>(groupPayload.value);
    }
    if (groupId.present) {
      map['group_id'] = Variable<String>(groupId.value);
    }
    if (directOnly.present) {
      map['direct_only'] = Variable<int>(directOnly.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MessagesCompanion(')
          ..write('id: $id, ')
          ..write('senderPubKey: $senderPubKey, ')
          ..write('recipientPubKey: $recipientPubKey, ')
          ..write('timestamp: $timestamp, ')
          ..write('ciphertext: $ciphertext, ')
          ..write('ephemeralPubKey: $ephemeralPubKey, ')
          ..write('signature: $signature, ')
          ..write('source: $source, ')
          ..write('hops: $hops, ')
          ..write('chainLink: $chainLink, ')
          ..write('forked: $forked, ')
          ..write('control: $control, ')
          ..write('groupPayload: $groupPayload, ')
          ..write('groupId: $groupId, ')
          ..write('directOnly: $directOnly, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PrunedRootsTable extends PrunedRoots
    with TableInfo<$PrunedRootsTable, PrunedRoot> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PrunedRootsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _cutoffTsMeta = const VerificationMeta(
    'cutoffTs',
  );
  @override
  late final GeneratedColumn<int> cutoffTs = GeneratedColumn<int>(
    'cutoff_ts',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _merkleRootMeta = const VerificationMeta(
    'merkleRoot',
  );
  @override
  late final GeneratedColumn<String> merkleRoot = GeneratedColumn<String>(
    'merkle_root',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _countMeta = const VerificationMeta('count');
  @override
  late final GeneratedColumn<int> count = GeneratedColumn<int>(
    'count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _devicePubKeyMeta = const VerificationMeta(
    'devicePubKey',
  );
  @override
  late final GeneratedColumn<String> devicePubKey = GeneratedColumn<String>(
    'device_pub_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _signatureMeta = const VerificationMeta(
    'signature',
  );
  @override
  late final GeneratedColumn<String> signature = GeneratedColumn<String>(
    'signature',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    cutoffTs,
    merkleRoot,
    count,
    devicePubKey,
    signature,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'pruned_roots';
  @override
  VerificationContext validateIntegrity(
    Insertable<PrunedRoot> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('cutoff_ts')) {
      context.handle(
        _cutoffTsMeta,
        cutoffTs.isAcceptableOrUnknown(data['cutoff_ts']!, _cutoffTsMeta),
      );
    } else if (isInserting) {
      context.missing(_cutoffTsMeta);
    }
    if (data.containsKey('merkle_root')) {
      context.handle(
        _merkleRootMeta,
        merkleRoot.isAcceptableOrUnknown(data['merkle_root']!, _merkleRootMeta),
      );
    } else if (isInserting) {
      context.missing(_merkleRootMeta);
    }
    if (data.containsKey('count')) {
      context.handle(
        _countMeta,
        count.isAcceptableOrUnknown(data['count']!, _countMeta),
      );
    } else if (isInserting) {
      context.missing(_countMeta);
    }
    if (data.containsKey('device_pub_key')) {
      context.handle(
        _devicePubKeyMeta,
        devicePubKey.isAcceptableOrUnknown(
          data['device_pub_key']!,
          _devicePubKeyMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_devicePubKeyMeta);
    }
    if (data.containsKey('signature')) {
      context.handle(
        _signatureMeta,
        signature.isAcceptableOrUnknown(data['signature']!, _signatureMeta),
      );
    } else if (isInserting) {
      context.missing(_signatureMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  PrunedRoot map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PrunedRoot(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      cutoffTs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}cutoff_ts'],
      )!,
      merkleRoot: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}merkle_root'],
      )!,
      count: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}count'],
      )!,
      devicePubKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}device_pub_key'],
      )!,
      signature: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}signature'],
      )!,
    );
  }

  @override
  $PrunedRootsTable createAlias(String alias) {
    return $PrunedRootsTable(attachedDatabase, alias);
  }
}

class PrunedRoot extends DataClass implements Insertable<PrunedRoot> {
  final int id;
  final int cutoffTs;
  final String merkleRoot;
  final int count;
  final String devicePubKey;
  final String signature;
  const PrunedRoot({
    required this.id,
    required this.cutoffTs,
    required this.merkleRoot,
    required this.count,
    required this.devicePubKey,
    required this.signature,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['cutoff_ts'] = Variable<int>(cutoffTs);
    map['merkle_root'] = Variable<String>(merkleRoot);
    map['count'] = Variable<int>(count);
    map['device_pub_key'] = Variable<String>(devicePubKey);
    map['signature'] = Variable<String>(signature);
    return map;
  }

  PrunedRootsCompanion toCompanion(bool nullToAbsent) {
    return PrunedRootsCompanion(
      id: Value(id),
      cutoffTs: Value(cutoffTs),
      merkleRoot: Value(merkleRoot),
      count: Value(count),
      devicePubKey: Value(devicePubKey),
      signature: Value(signature),
    );
  }

  factory PrunedRoot.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PrunedRoot(
      id: serializer.fromJson<int>(json['id']),
      cutoffTs: serializer.fromJson<int>(json['cutoffTs']),
      merkleRoot: serializer.fromJson<String>(json['merkleRoot']),
      count: serializer.fromJson<int>(json['count']),
      devicePubKey: serializer.fromJson<String>(json['devicePubKey']),
      signature: serializer.fromJson<String>(json['signature']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'cutoffTs': serializer.toJson<int>(cutoffTs),
      'merkleRoot': serializer.toJson<String>(merkleRoot),
      'count': serializer.toJson<int>(count),
      'devicePubKey': serializer.toJson<String>(devicePubKey),
      'signature': serializer.toJson<String>(signature),
    };
  }

  PrunedRoot copyWith({
    int? id,
    int? cutoffTs,
    String? merkleRoot,
    int? count,
    String? devicePubKey,
    String? signature,
  }) => PrunedRoot(
    id: id ?? this.id,
    cutoffTs: cutoffTs ?? this.cutoffTs,
    merkleRoot: merkleRoot ?? this.merkleRoot,
    count: count ?? this.count,
    devicePubKey: devicePubKey ?? this.devicePubKey,
    signature: signature ?? this.signature,
  );
  PrunedRoot copyWithCompanion(PrunedRootsCompanion data) {
    return PrunedRoot(
      id: data.id.present ? data.id.value : this.id,
      cutoffTs: data.cutoffTs.present ? data.cutoffTs.value : this.cutoffTs,
      merkleRoot: data.merkleRoot.present
          ? data.merkleRoot.value
          : this.merkleRoot,
      count: data.count.present ? data.count.value : this.count,
      devicePubKey: data.devicePubKey.present
          ? data.devicePubKey.value
          : this.devicePubKey,
      signature: data.signature.present ? data.signature.value : this.signature,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PrunedRoot(')
          ..write('id: $id, ')
          ..write('cutoffTs: $cutoffTs, ')
          ..write('merkleRoot: $merkleRoot, ')
          ..write('count: $count, ')
          ..write('devicePubKey: $devicePubKey, ')
          ..write('signature: $signature')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, cutoffTs, merkleRoot, count, devicePubKey, signature);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PrunedRoot &&
          other.id == this.id &&
          other.cutoffTs == this.cutoffTs &&
          other.merkleRoot == this.merkleRoot &&
          other.count == this.count &&
          other.devicePubKey == this.devicePubKey &&
          other.signature == this.signature);
}

class PrunedRootsCompanion extends UpdateCompanion<PrunedRoot> {
  final Value<int> id;
  final Value<int> cutoffTs;
  final Value<String> merkleRoot;
  final Value<int> count;
  final Value<String> devicePubKey;
  final Value<String> signature;
  const PrunedRootsCompanion({
    this.id = const Value.absent(),
    this.cutoffTs = const Value.absent(),
    this.merkleRoot = const Value.absent(),
    this.count = const Value.absent(),
    this.devicePubKey = const Value.absent(),
    this.signature = const Value.absent(),
  });
  PrunedRootsCompanion.insert({
    this.id = const Value.absent(),
    required int cutoffTs,
    required String merkleRoot,
    required int count,
    required String devicePubKey,
    required String signature,
  }) : cutoffTs = Value(cutoffTs),
       merkleRoot = Value(merkleRoot),
       count = Value(count),
       devicePubKey = Value(devicePubKey),
       signature = Value(signature);
  static Insertable<PrunedRoot> custom({
    Expression<int>? id,
    Expression<int>? cutoffTs,
    Expression<String>? merkleRoot,
    Expression<int>? count,
    Expression<String>? devicePubKey,
    Expression<String>? signature,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (cutoffTs != null) 'cutoff_ts': cutoffTs,
      if (merkleRoot != null) 'merkle_root': merkleRoot,
      if (count != null) 'count': count,
      if (devicePubKey != null) 'device_pub_key': devicePubKey,
      if (signature != null) 'signature': signature,
    });
  }

  PrunedRootsCompanion copyWith({
    Value<int>? id,
    Value<int>? cutoffTs,
    Value<String>? merkleRoot,
    Value<int>? count,
    Value<String>? devicePubKey,
    Value<String>? signature,
  }) {
    return PrunedRootsCompanion(
      id: id ?? this.id,
      cutoffTs: cutoffTs ?? this.cutoffTs,
      merkleRoot: merkleRoot ?? this.merkleRoot,
      count: count ?? this.count,
      devicePubKey: devicePubKey ?? this.devicePubKey,
      signature: signature ?? this.signature,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (cutoffTs.present) {
      map['cutoff_ts'] = Variable<int>(cutoffTs.value);
    }
    if (merkleRoot.present) {
      map['merkle_root'] = Variable<String>(merkleRoot.value);
    }
    if (count.present) {
      map['count'] = Variable<int>(count.value);
    }
    if (devicePubKey.present) {
      map['device_pub_key'] = Variable<String>(devicePubKey.value);
    }
    if (signature.present) {
      map['signature'] = Variable<String>(signature.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PrunedRootsCompanion(')
          ..write('id: $id, ')
          ..write('cutoffTs: $cutoffTs, ')
          ..write('merkleRoot: $merkleRoot, ')
          ..write('count: $count, ')
          ..write('devicePubKey: $devicePubKey, ')
          ..write('signature: $signature')
          ..write(')'))
        .toString();
  }
}

class $IdentityEntryTable extends IdentityEntry
    with TableInfo<$IdentityEntryTable, IdentityEntryData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $IdentityEntryTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    clientDefault: () => 'self',
  );
  static const VerificationMeta _edSeedHexMeta = const VerificationMeta(
    'edSeedHex',
  );
  @override
  late final GeneratedColumn<String> edSeedHex = GeneratedColumn<String>(
    'ed_seed_hex',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _xSeedHexMeta = const VerificationMeta(
    'xSeedHex',
  );
  @override
  late final GeneratedColumn<String> xSeedHex = GeneratedColumn<String>(
    'x_seed_hex',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _displayNameMeta = const VerificationMeta(
    'displayName',
  );
  @override
  late final GeneratedColumn<String> displayName = GeneratedColumn<String>(
    'display_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    key,
    edSeedHex,
    xSeedHex,
    displayName,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'identity_entry';
  @override
  VerificationContext validateIntegrity(
    Insertable<IdentityEntryData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
        _keyMeta,
        key.isAcceptableOrUnknown(data['key']!, _keyMeta),
      );
    }
    if (data.containsKey('ed_seed_hex')) {
      context.handle(
        _edSeedHexMeta,
        edSeedHex.isAcceptableOrUnknown(data['ed_seed_hex']!, _edSeedHexMeta),
      );
    } else if (isInserting) {
      context.missing(_edSeedHexMeta);
    }
    if (data.containsKey('x_seed_hex')) {
      context.handle(
        _xSeedHexMeta,
        xSeedHex.isAcceptableOrUnknown(data['x_seed_hex']!, _xSeedHexMeta),
      );
    } else if (isInserting) {
      context.missing(_xSeedHexMeta);
    }
    if (data.containsKey('display_name')) {
      context.handle(
        _displayNameMeta,
        displayName.isAcceptableOrUnknown(
          data['display_name']!,
          _displayNameMeta,
        ),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  IdentityEntryData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return IdentityEntryData(
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      )!,
      edSeedHex: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}ed_seed_hex'],
      )!,
      xSeedHex: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}x_seed_hex'],
      )!,
      displayName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}display_name'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $IdentityEntryTable createAlias(String alias) {
    return $IdentityEntryTable(attachedDatabase, alias);
  }
}

class IdentityEntryData extends DataClass
    implements Insertable<IdentityEntryData> {
  final String key;
  final String edSeedHex;
  final String xSeedHex;
  final String displayName;
  final int createdAt;
  const IdentityEntryData({
    required this.key,
    required this.edSeedHex,
    required this.xSeedHex,
    required this.displayName,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['ed_seed_hex'] = Variable<String>(edSeedHex);
    map['x_seed_hex'] = Variable<String>(xSeedHex);
    map['display_name'] = Variable<String>(displayName);
    map['created_at'] = Variable<int>(createdAt);
    return map;
  }

  IdentityEntryCompanion toCompanion(bool nullToAbsent) {
    return IdentityEntryCompanion(
      key: Value(key),
      edSeedHex: Value(edSeedHex),
      xSeedHex: Value(xSeedHex),
      displayName: Value(displayName),
      createdAt: Value(createdAt),
    );
  }

  factory IdentityEntryData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return IdentityEntryData(
      key: serializer.fromJson<String>(json['key']),
      edSeedHex: serializer.fromJson<String>(json['edSeedHex']),
      xSeedHex: serializer.fromJson<String>(json['xSeedHex']),
      displayName: serializer.fromJson<String>(json['displayName']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'edSeedHex': serializer.toJson<String>(edSeedHex),
      'xSeedHex': serializer.toJson<String>(xSeedHex),
      'displayName': serializer.toJson<String>(displayName),
      'createdAt': serializer.toJson<int>(createdAt),
    };
  }

  IdentityEntryData copyWith({
    String? key,
    String? edSeedHex,
    String? xSeedHex,
    String? displayName,
    int? createdAt,
  }) => IdentityEntryData(
    key: key ?? this.key,
    edSeedHex: edSeedHex ?? this.edSeedHex,
    xSeedHex: xSeedHex ?? this.xSeedHex,
    displayName: displayName ?? this.displayName,
    createdAt: createdAt ?? this.createdAt,
  );
  IdentityEntryData copyWithCompanion(IdentityEntryCompanion data) {
    return IdentityEntryData(
      key: data.key.present ? data.key.value : this.key,
      edSeedHex: data.edSeedHex.present ? data.edSeedHex.value : this.edSeedHex,
      xSeedHex: data.xSeedHex.present ? data.xSeedHex.value : this.xSeedHex,
      displayName: data.displayName.present
          ? data.displayName.value
          : this.displayName,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('IdentityEntryData(')
          ..write('key: $key, ')
          ..write('edSeedHex: $edSeedHex, ')
          ..write('xSeedHex: $xSeedHex, ')
          ..write('displayName: $displayName, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(key, edSeedHex, xSeedHex, displayName, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is IdentityEntryData &&
          other.key == this.key &&
          other.edSeedHex == this.edSeedHex &&
          other.xSeedHex == this.xSeedHex &&
          other.displayName == this.displayName &&
          other.createdAt == this.createdAt);
}

class IdentityEntryCompanion extends UpdateCompanion<IdentityEntryData> {
  final Value<String> key;
  final Value<String> edSeedHex;
  final Value<String> xSeedHex;
  final Value<String> displayName;
  final Value<int> createdAt;
  final Value<int> rowid;
  const IdentityEntryCompanion({
    this.key = const Value.absent(),
    this.edSeedHex = const Value.absent(),
    this.xSeedHex = const Value.absent(),
    this.displayName = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  IdentityEntryCompanion.insert({
    this.key = const Value.absent(),
    required String edSeedHex,
    required String xSeedHex,
    this.displayName = const Value.absent(),
    required int createdAt,
    this.rowid = const Value.absent(),
  }) : edSeedHex = Value(edSeedHex),
       xSeedHex = Value(xSeedHex),
       createdAt = Value(createdAt);
  static Insertable<IdentityEntryData> custom({
    Expression<String>? key,
    Expression<String>? edSeedHex,
    Expression<String>? xSeedHex,
    Expression<String>? displayName,
    Expression<int>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (edSeedHex != null) 'ed_seed_hex': edSeedHex,
      if (xSeedHex != null) 'x_seed_hex': xSeedHex,
      if (displayName != null) 'display_name': displayName,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  IdentityEntryCompanion copyWith({
    Value<String>? key,
    Value<String>? edSeedHex,
    Value<String>? xSeedHex,
    Value<String>? displayName,
    Value<int>? createdAt,
    Value<int>? rowid,
  }) {
    return IdentityEntryCompanion(
      key: key ?? this.key,
      edSeedHex: edSeedHex ?? this.edSeedHex,
      xSeedHex: xSeedHex ?? this.xSeedHex,
      displayName: displayName ?? this.displayName,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (edSeedHex.present) {
      map['ed_seed_hex'] = Variable<String>(edSeedHex.value);
    }
    if (xSeedHex.present) {
      map['x_seed_hex'] = Variable<String>(xSeedHex.value);
    }
    if (displayName.present) {
      map['display_name'] = Variable<String>(displayName.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('IdentityEntryCompanion(')
          ..write('key: $key, ')
          ..write('edSeedHex: $edSeedHex, ')
          ..write('xSeedHex: $xSeedHex, ')
          ..write('displayName: $displayName, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $AppSettingsTable extends AppSettings
    with TableInfo<$AppSettingsTable, AppSetting> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AppSettingsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
    'value',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [key, value];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'app_settings';
  @override
  VerificationContext validateIntegrity(
    Insertable<AppSetting> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
        _keyMeta,
        key.isAcceptableOrUnknown(data['key']!, _keyMeta),
      );
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
        _valueMeta,
        value.isAcceptableOrUnknown(data['value']!, _valueMeta),
      );
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  AppSetting map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AppSetting(
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      )!,
      value: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}value'],
      )!,
    );
  }

  @override
  $AppSettingsTable createAlias(String alias) {
    return $AppSettingsTable(attachedDatabase, alias);
  }
}

class AppSetting extends DataClass implements Insertable<AppSetting> {
  final String key;
  final String value;
  const AppSetting({required this.key, required this.value});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['value'] = Variable<String>(value);
    return map;
  }

  AppSettingsCompanion toCompanion(bool nullToAbsent) {
    return AppSettingsCompanion(key: Value(key), value: Value(value));
  }

  factory AppSetting.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AppSetting(
      key: serializer.fromJson<String>(json['key']),
      value: serializer.fromJson<String>(json['value']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'value': serializer.toJson<String>(value),
    };
  }

  AppSetting copyWith({String? key, String? value}) =>
      AppSetting(key: key ?? this.key, value: value ?? this.value);
  AppSetting copyWithCompanion(AppSettingsCompanion data) {
    return AppSetting(
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AppSetting(')
          ..write('key: $key, ')
          ..write('value: $value')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, value);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AppSetting &&
          other.key == this.key &&
          other.value == this.value);
}

class AppSettingsCompanion extends UpdateCompanion<AppSetting> {
  final Value<String> key;
  final Value<String> value;
  final Value<int> rowid;
  const AppSettingsCompanion({
    this.key = const Value.absent(),
    this.value = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AppSettingsCompanion.insert({
    required String key,
    required String value,
    this.rowid = const Value.absent(),
  }) : key = Value(key),
       value = Value(value);
  static Insertable<AppSetting> custom({
    Expression<String>? key,
    Expression<String>? value,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (value != null) 'value': value,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AppSettingsCompanion copyWith({
    Value<String>? key,
    Value<String>? value,
    Value<int>? rowid,
  }) {
    return AppSettingsCompanion(
      key: key ?? this.key,
      value: value ?? this.value,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AppSettingsCompanion(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ConversationHeadsTable extends ConversationHeads
    with TableInfo<$ConversationHeadsTable, ConversationHead> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ConversationHeadsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _linkKeyMeta = const VerificationMeta(
    'linkKey',
  );
  @override
  late final GeneratedColumn<String> linkKey = GeneratedColumn<String>(
    'link_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _headIdMeta = const VerificationMeta('headId');
  @override
  late final GeneratedColumn<String> headId = GeneratedColumn<String>(
    'head_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _countMeta = const VerificationMeta('count');
  @override
  late final GeneratedColumn<int> count = GeneratedColumn<int>(
    'count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _lastTsMeta = const VerificationMeta('lastTs');
  @override
  late final GeneratedColumn<int> lastTs = GeneratedColumn<int>(
    'last_ts',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  List<GeneratedColumn> get $columns => [linkKey, headId, count, lastTs];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'conversation_heads';
  @override
  VerificationContext validateIntegrity(
    Insertable<ConversationHead> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('link_key')) {
      context.handle(
        _linkKeyMeta,
        linkKey.isAcceptableOrUnknown(data['link_key']!, _linkKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_linkKeyMeta);
    }
    if (data.containsKey('head_id')) {
      context.handle(
        _headIdMeta,
        headId.isAcceptableOrUnknown(data['head_id']!, _headIdMeta),
      );
    } else if (isInserting) {
      context.missing(_headIdMeta);
    }
    if (data.containsKey('count')) {
      context.handle(
        _countMeta,
        count.isAcceptableOrUnknown(data['count']!, _countMeta),
      );
    }
    if (data.containsKey('last_ts')) {
      context.handle(
        _lastTsMeta,
        lastTs.isAcceptableOrUnknown(data['last_ts']!, _lastTsMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {linkKey};
  @override
  ConversationHead map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ConversationHead(
      linkKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}link_key'],
      )!,
      headId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}head_id'],
      )!,
      count: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}count'],
      )!,
      lastTs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}last_ts'],
      )!,
    );
  }

  @override
  $ConversationHeadsTable createAlias(String alias) {
    return $ConversationHeadsTable(attachedDatabase, alias);
  }
}

class ConversationHead extends DataClass
    implements Insertable<ConversationHead> {
  final String linkKey;
  final String headId;
  final int count;
  final int lastTs;
  const ConversationHead({
    required this.linkKey,
    required this.headId,
    required this.count,
    required this.lastTs,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['link_key'] = Variable<String>(linkKey);
    map['head_id'] = Variable<String>(headId);
    map['count'] = Variable<int>(count);
    map['last_ts'] = Variable<int>(lastTs);
    return map;
  }

  ConversationHeadsCompanion toCompanion(bool nullToAbsent) {
    return ConversationHeadsCompanion(
      linkKey: Value(linkKey),
      headId: Value(headId),
      count: Value(count),
      lastTs: Value(lastTs),
    );
  }

  factory ConversationHead.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ConversationHead(
      linkKey: serializer.fromJson<String>(json['linkKey']),
      headId: serializer.fromJson<String>(json['headId']),
      count: serializer.fromJson<int>(json['count']),
      lastTs: serializer.fromJson<int>(json['lastTs']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'linkKey': serializer.toJson<String>(linkKey),
      'headId': serializer.toJson<String>(headId),
      'count': serializer.toJson<int>(count),
      'lastTs': serializer.toJson<int>(lastTs),
    };
  }

  ConversationHead copyWith({
    String? linkKey,
    String? headId,
    int? count,
    int? lastTs,
  }) => ConversationHead(
    linkKey: linkKey ?? this.linkKey,
    headId: headId ?? this.headId,
    count: count ?? this.count,
    lastTs: lastTs ?? this.lastTs,
  );
  ConversationHead copyWithCompanion(ConversationHeadsCompanion data) {
    return ConversationHead(
      linkKey: data.linkKey.present ? data.linkKey.value : this.linkKey,
      headId: data.headId.present ? data.headId.value : this.headId,
      count: data.count.present ? data.count.value : this.count,
      lastTs: data.lastTs.present ? data.lastTs.value : this.lastTs,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ConversationHead(')
          ..write('linkKey: $linkKey, ')
          ..write('headId: $headId, ')
          ..write('count: $count, ')
          ..write('lastTs: $lastTs')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(linkKey, headId, count, lastTs);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ConversationHead &&
          other.linkKey == this.linkKey &&
          other.headId == this.headId &&
          other.count == this.count &&
          other.lastTs == this.lastTs);
}

class ConversationHeadsCompanion extends UpdateCompanion<ConversationHead> {
  final Value<String> linkKey;
  final Value<String> headId;
  final Value<int> count;
  final Value<int> lastTs;
  final Value<int> rowid;
  const ConversationHeadsCompanion({
    this.linkKey = const Value.absent(),
    this.headId = const Value.absent(),
    this.count = const Value.absent(),
    this.lastTs = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ConversationHeadsCompanion.insert({
    required String linkKey,
    required String headId,
    this.count = const Value.absent(),
    this.lastTs = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : linkKey = Value(linkKey),
       headId = Value(headId);
  static Insertable<ConversationHead> custom({
    Expression<String>? linkKey,
    Expression<String>? headId,
    Expression<int>? count,
    Expression<int>? lastTs,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (linkKey != null) 'link_key': linkKey,
      if (headId != null) 'head_id': headId,
      if (count != null) 'count': count,
      if (lastTs != null) 'last_ts': lastTs,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ConversationHeadsCompanion copyWith({
    Value<String>? linkKey,
    Value<String>? headId,
    Value<int>? count,
    Value<int>? lastTs,
    Value<int>? rowid,
  }) {
    return ConversationHeadsCompanion(
      linkKey: linkKey ?? this.linkKey,
      headId: headId ?? this.headId,
      count: count ?? this.count,
      lastTs: lastTs ?? this.lastTs,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (linkKey.present) {
      map['link_key'] = Variable<String>(linkKey.value);
    }
    if (headId.present) {
      map['head_id'] = Variable<String>(headId.value);
    }
    if (count.present) {
      map['count'] = Variable<int>(count.value);
    }
    if (lastTs.present) {
      map['last_ts'] = Variable<int>(lastTs.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ConversationHeadsCompanion(')
          ..write('linkKey: $linkKey, ')
          ..write('headId: $headId, ')
          ..write('count: $count, ')
          ..write('lastTs: $lastTs, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PeersTable extends Peers with TableInfo<$PeersTable, Peer> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PeersTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _pubKeyMeta = const VerificationMeta('pubKey');
  @override
  late final GeneratedColumn<String> pubKey = GeneratedColumn<String>(
    'pub_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _edPubKeyMeta = const VerificationMeta(
    'edPubKey',
  );
  @override
  late final GeneratedColumn<String> edPubKey = GeneratedColumn<String>(
    'ed_pub_key',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _displayNameMeta = const VerificationMeta(
    'displayName',
  );
  @override
  late final GeneratedColumn<String> displayName = GeneratedColumn<String>(
    'display_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _peerIdMeta = const VerificationMeta('peerId');
  @override
  late final GeneratedColumn<String> peerId = GeneratedColumn<String>(
    'peer_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _addrsJsonMeta = const VerificationMeta(
    'addrsJson',
  );
  @override
  late final GeneratedColumn<String> addrsJson = GeneratedColumn<String>(
    'addrs_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('[]'),
  );
  static const VerificationMeta _lastSeenMeta = const VerificationMeta(
    'lastSeen',
  );
  @override
  late final GeneratedColumn<int> lastSeen = GeneratedColumn<int>(
    'last_seen',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _isContactMeta = const VerificationMeta(
    'isContact',
  );
  @override
  late final GeneratedColumn<bool> isContact = GeneratedColumn<bool>(
    'is_contact',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_contact" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _verifiedEdPubKeyMeta = const VerificationMeta(
    'verifiedEdPubKey',
  );
  @override
  late final GeneratedColumn<String> verifiedEdPubKey = GeneratedColumn<String>(
    'verified_ed_pub_key',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _verifiedAtMeta = const VerificationMeta(
    'verifiedAt',
  );
  @override
  late final GeneratedColumn<int> verifiedAt = GeneratedColumn<int>(
    'verified_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _blockedMeta = const VerificationMeta(
    'blocked',
  );
  @override
  late final GeneratedColumn<bool> blocked = GeneratedColumn<bool>(
    'blocked',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("blocked" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [
    pubKey,
    edPubKey,
    displayName,
    peerId,
    addrsJson,
    lastSeen,
    isContact,
    verifiedEdPubKey,
    verifiedAt,
    blocked,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'peers';
  @override
  VerificationContext validateIntegrity(
    Insertable<Peer> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('pub_key')) {
      context.handle(
        _pubKeyMeta,
        pubKey.isAcceptableOrUnknown(data['pub_key']!, _pubKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_pubKeyMeta);
    }
    if (data.containsKey('ed_pub_key')) {
      context.handle(
        _edPubKeyMeta,
        edPubKey.isAcceptableOrUnknown(data['ed_pub_key']!, _edPubKeyMeta),
      );
    }
    if (data.containsKey('display_name')) {
      context.handle(
        _displayNameMeta,
        displayName.isAcceptableOrUnknown(
          data['display_name']!,
          _displayNameMeta,
        ),
      );
    }
    if (data.containsKey('peer_id')) {
      context.handle(
        _peerIdMeta,
        peerId.isAcceptableOrUnknown(data['peer_id']!, _peerIdMeta),
      );
    }
    if (data.containsKey('addrs_json')) {
      context.handle(
        _addrsJsonMeta,
        addrsJson.isAcceptableOrUnknown(data['addrs_json']!, _addrsJsonMeta),
      );
    }
    if (data.containsKey('last_seen')) {
      context.handle(
        _lastSeenMeta,
        lastSeen.isAcceptableOrUnknown(data['last_seen']!, _lastSeenMeta),
      );
    }
    if (data.containsKey('is_contact')) {
      context.handle(
        _isContactMeta,
        isContact.isAcceptableOrUnknown(data['is_contact']!, _isContactMeta),
      );
    }
    if (data.containsKey('verified_ed_pub_key')) {
      context.handle(
        _verifiedEdPubKeyMeta,
        verifiedEdPubKey.isAcceptableOrUnknown(
          data['verified_ed_pub_key']!,
          _verifiedEdPubKeyMeta,
        ),
      );
    }
    if (data.containsKey('verified_at')) {
      context.handle(
        _verifiedAtMeta,
        verifiedAt.isAcceptableOrUnknown(data['verified_at']!, _verifiedAtMeta),
      );
    }
    if (data.containsKey('blocked')) {
      context.handle(
        _blockedMeta,
        blocked.isAcceptableOrUnknown(data['blocked']!, _blockedMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {pubKey};
  @override
  Peer map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Peer(
      pubKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}pub_key'],
      )!,
      edPubKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}ed_pub_key'],
      ),
      displayName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}display_name'],
      )!,
      peerId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}peer_id'],
      ),
      addrsJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}addrs_json'],
      )!,
      lastSeen: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}last_seen'],
      )!,
      isContact: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_contact'],
      )!,
      verifiedEdPubKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}verified_ed_pub_key'],
      ),
      verifiedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}verified_at'],
      ),
      blocked: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}blocked'],
      )!,
    );
  }

  @override
  $PeersTable createAlias(String alias) {
    return $PeersTable(attachedDatabase, alias);
  }
}

class Peer extends DataClass implements Insertable<Peer> {
  final String pubKey;
  final String? edPubKey;
  final String displayName;
  final String? peerId;
  final String addrsJson;
  final int lastSeen;
  final bool isContact;

  /// Ed25519 binding the user confirmed by comparing safety numbers. Kept
  /// across later upserts so a swapped key can be detected instead of trusted.
  final String? verifiedEdPubKey;

  /// When [verifiedEdPubKey] was confirmed, epoch milliseconds.
  final int? verifiedAt;

  /// Local-only block: the processor drops this contact's envelopes after
  /// verification and never decrypts them. Kept across upserts.
  final bool blocked;
  const Peer({
    required this.pubKey,
    this.edPubKey,
    required this.displayName,
    this.peerId,
    required this.addrsJson,
    required this.lastSeen,
    required this.isContact,
    this.verifiedEdPubKey,
    this.verifiedAt,
    required this.blocked,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['pub_key'] = Variable<String>(pubKey);
    if (!nullToAbsent || edPubKey != null) {
      map['ed_pub_key'] = Variable<String>(edPubKey);
    }
    map['display_name'] = Variable<String>(displayName);
    if (!nullToAbsent || peerId != null) {
      map['peer_id'] = Variable<String>(peerId);
    }
    map['addrs_json'] = Variable<String>(addrsJson);
    map['last_seen'] = Variable<int>(lastSeen);
    map['is_contact'] = Variable<bool>(isContact);
    if (!nullToAbsent || verifiedEdPubKey != null) {
      map['verified_ed_pub_key'] = Variable<String>(verifiedEdPubKey);
    }
    if (!nullToAbsent || verifiedAt != null) {
      map['verified_at'] = Variable<int>(verifiedAt);
    }
    map['blocked'] = Variable<bool>(blocked);
    return map;
  }

  PeersCompanion toCompanion(bool nullToAbsent) {
    return PeersCompanion(
      pubKey: Value(pubKey),
      edPubKey: edPubKey == null && nullToAbsent
          ? const Value.absent()
          : Value(edPubKey),
      displayName: Value(displayName),
      peerId: peerId == null && nullToAbsent
          ? const Value.absent()
          : Value(peerId),
      addrsJson: Value(addrsJson),
      lastSeen: Value(lastSeen),
      isContact: Value(isContact),
      verifiedEdPubKey: verifiedEdPubKey == null && nullToAbsent
          ? const Value.absent()
          : Value(verifiedEdPubKey),
      verifiedAt: verifiedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(verifiedAt),
      blocked: Value(blocked),
    );
  }

  factory Peer.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Peer(
      pubKey: serializer.fromJson<String>(json['pubKey']),
      edPubKey: serializer.fromJson<String?>(json['edPubKey']),
      displayName: serializer.fromJson<String>(json['displayName']),
      peerId: serializer.fromJson<String?>(json['peerId']),
      addrsJson: serializer.fromJson<String>(json['addrsJson']),
      lastSeen: serializer.fromJson<int>(json['lastSeen']),
      isContact: serializer.fromJson<bool>(json['isContact']),
      verifiedEdPubKey: serializer.fromJson<String?>(json['verifiedEdPubKey']),
      verifiedAt: serializer.fromJson<int?>(json['verifiedAt']),
      blocked: serializer.fromJson<bool>(json['blocked']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'pubKey': serializer.toJson<String>(pubKey),
      'edPubKey': serializer.toJson<String?>(edPubKey),
      'displayName': serializer.toJson<String>(displayName),
      'peerId': serializer.toJson<String?>(peerId),
      'addrsJson': serializer.toJson<String>(addrsJson),
      'lastSeen': serializer.toJson<int>(lastSeen),
      'isContact': serializer.toJson<bool>(isContact),
      'verifiedEdPubKey': serializer.toJson<String?>(verifiedEdPubKey),
      'verifiedAt': serializer.toJson<int?>(verifiedAt),
      'blocked': serializer.toJson<bool>(blocked),
    };
  }

  Peer copyWith({
    String? pubKey,
    Value<String?> edPubKey = const Value.absent(),
    String? displayName,
    Value<String?> peerId = const Value.absent(),
    String? addrsJson,
    int? lastSeen,
    bool? isContact,
    Value<String?> verifiedEdPubKey = const Value.absent(),
    Value<int?> verifiedAt = const Value.absent(),
    bool? blocked,
  }) => Peer(
    pubKey: pubKey ?? this.pubKey,
    edPubKey: edPubKey.present ? edPubKey.value : this.edPubKey,
    displayName: displayName ?? this.displayName,
    peerId: peerId.present ? peerId.value : this.peerId,
    addrsJson: addrsJson ?? this.addrsJson,
    lastSeen: lastSeen ?? this.lastSeen,
    isContact: isContact ?? this.isContact,
    verifiedEdPubKey: verifiedEdPubKey.present
        ? verifiedEdPubKey.value
        : this.verifiedEdPubKey,
    verifiedAt: verifiedAt.present ? verifiedAt.value : this.verifiedAt,
    blocked: blocked ?? this.blocked,
  );
  Peer copyWithCompanion(PeersCompanion data) {
    return Peer(
      pubKey: data.pubKey.present ? data.pubKey.value : this.pubKey,
      edPubKey: data.edPubKey.present ? data.edPubKey.value : this.edPubKey,
      displayName: data.displayName.present
          ? data.displayName.value
          : this.displayName,
      peerId: data.peerId.present ? data.peerId.value : this.peerId,
      addrsJson: data.addrsJson.present ? data.addrsJson.value : this.addrsJson,
      lastSeen: data.lastSeen.present ? data.lastSeen.value : this.lastSeen,
      isContact: data.isContact.present ? data.isContact.value : this.isContact,
      verifiedEdPubKey: data.verifiedEdPubKey.present
          ? data.verifiedEdPubKey.value
          : this.verifiedEdPubKey,
      verifiedAt: data.verifiedAt.present
          ? data.verifiedAt.value
          : this.verifiedAt,
      blocked: data.blocked.present ? data.blocked.value : this.blocked,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Peer(')
          ..write('pubKey: $pubKey, ')
          ..write('edPubKey: $edPubKey, ')
          ..write('displayName: $displayName, ')
          ..write('peerId: $peerId, ')
          ..write('addrsJson: $addrsJson, ')
          ..write('lastSeen: $lastSeen, ')
          ..write('isContact: $isContact, ')
          ..write('verifiedEdPubKey: $verifiedEdPubKey, ')
          ..write('verifiedAt: $verifiedAt, ')
          ..write('blocked: $blocked')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    pubKey,
    edPubKey,
    displayName,
    peerId,
    addrsJson,
    lastSeen,
    isContact,
    verifiedEdPubKey,
    verifiedAt,
    blocked,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Peer &&
          other.pubKey == this.pubKey &&
          other.edPubKey == this.edPubKey &&
          other.displayName == this.displayName &&
          other.peerId == this.peerId &&
          other.addrsJson == this.addrsJson &&
          other.lastSeen == this.lastSeen &&
          other.isContact == this.isContact &&
          other.verifiedEdPubKey == this.verifiedEdPubKey &&
          other.verifiedAt == this.verifiedAt &&
          other.blocked == this.blocked);
}

class PeersCompanion extends UpdateCompanion<Peer> {
  final Value<String> pubKey;
  final Value<String?> edPubKey;
  final Value<String> displayName;
  final Value<String?> peerId;
  final Value<String> addrsJson;
  final Value<int> lastSeen;
  final Value<bool> isContact;
  final Value<String?> verifiedEdPubKey;
  final Value<int?> verifiedAt;
  final Value<bool> blocked;
  final Value<int> rowid;
  const PeersCompanion({
    this.pubKey = const Value.absent(),
    this.edPubKey = const Value.absent(),
    this.displayName = const Value.absent(),
    this.peerId = const Value.absent(),
    this.addrsJson = const Value.absent(),
    this.lastSeen = const Value.absent(),
    this.isContact = const Value.absent(),
    this.verifiedEdPubKey = const Value.absent(),
    this.verifiedAt = const Value.absent(),
    this.blocked = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PeersCompanion.insert({
    required String pubKey,
    this.edPubKey = const Value.absent(),
    this.displayName = const Value.absent(),
    this.peerId = const Value.absent(),
    this.addrsJson = const Value.absent(),
    this.lastSeen = const Value.absent(),
    this.isContact = const Value.absent(),
    this.verifiedEdPubKey = const Value.absent(),
    this.verifiedAt = const Value.absent(),
    this.blocked = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : pubKey = Value(pubKey);
  static Insertable<Peer> custom({
    Expression<String>? pubKey,
    Expression<String>? edPubKey,
    Expression<String>? displayName,
    Expression<String>? peerId,
    Expression<String>? addrsJson,
    Expression<int>? lastSeen,
    Expression<bool>? isContact,
    Expression<String>? verifiedEdPubKey,
    Expression<int>? verifiedAt,
    Expression<bool>? blocked,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (pubKey != null) 'pub_key': pubKey,
      if (edPubKey != null) 'ed_pub_key': edPubKey,
      if (displayName != null) 'display_name': displayName,
      if (peerId != null) 'peer_id': peerId,
      if (addrsJson != null) 'addrs_json': addrsJson,
      if (lastSeen != null) 'last_seen': lastSeen,
      if (isContact != null) 'is_contact': isContact,
      if (verifiedEdPubKey != null) 'verified_ed_pub_key': verifiedEdPubKey,
      if (verifiedAt != null) 'verified_at': verifiedAt,
      if (blocked != null) 'blocked': blocked,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PeersCompanion copyWith({
    Value<String>? pubKey,
    Value<String?>? edPubKey,
    Value<String>? displayName,
    Value<String?>? peerId,
    Value<String>? addrsJson,
    Value<int>? lastSeen,
    Value<bool>? isContact,
    Value<String?>? verifiedEdPubKey,
    Value<int?>? verifiedAt,
    Value<bool>? blocked,
    Value<int>? rowid,
  }) {
    return PeersCompanion(
      pubKey: pubKey ?? this.pubKey,
      edPubKey: edPubKey ?? this.edPubKey,
      displayName: displayName ?? this.displayName,
      peerId: peerId ?? this.peerId,
      addrsJson: addrsJson ?? this.addrsJson,
      lastSeen: lastSeen ?? this.lastSeen,
      isContact: isContact ?? this.isContact,
      verifiedEdPubKey: verifiedEdPubKey ?? this.verifiedEdPubKey,
      verifiedAt: verifiedAt ?? this.verifiedAt,
      blocked: blocked ?? this.blocked,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (pubKey.present) {
      map['pub_key'] = Variable<String>(pubKey.value);
    }
    if (edPubKey.present) {
      map['ed_pub_key'] = Variable<String>(edPubKey.value);
    }
    if (displayName.present) {
      map['display_name'] = Variable<String>(displayName.value);
    }
    if (peerId.present) {
      map['peer_id'] = Variable<String>(peerId.value);
    }
    if (addrsJson.present) {
      map['addrs_json'] = Variable<String>(addrsJson.value);
    }
    if (lastSeen.present) {
      map['last_seen'] = Variable<int>(lastSeen.value);
    }
    if (isContact.present) {
      map['is_contact'] = Variable<bool>(isContact.value);
    }
    if (verifiedEdPubKey.present) {
      map['verified_ed_pub_key'] = Variable<String>(verifiedEdPubKey.value);
    }
    if (verifiedAt.present) {
      map['verified_at'] = Variable<int>(verifiedAt.value);
    }
    if (blocked.present) {
      map['blocked'] = Variable<bool>(blocked.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PeersCompanion(')
          ..write('pubKey: $pubKey, ')
          ..write('edPubKey: $edPubKey, ')
          ..write('displayName: $displayName, ')
          ..write('peerId: $peerId, ')
          ..write('addrsJson: $addrsJson, ')
          ..write('lastSeen: $lastSeen, ')
          ..write('isContact: $isContact, ')
          ..write('verifiedEdPubKey: $verifiedEdPubKey, ')
          ..write('verifiedAt: $verifiedAt, ')
          ..write('blocked: $blocked, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ConversationsTable extends Conversations
    with TableInfo<$ConversationsTable, Conversation> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ConversationsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
    'kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('dm'),
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _createdTsMeta = const VerificationMeta(
    'createdTs',
  );
  @override
  late final GeneratedColumn<int> createdTs = GeneratedColumn<int>(
    'created_ts',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _lastTsMeta = const VerificationMeta('lastTs');
  @override
  late final GeneratedColumn<int> lastTs = GeneratedColumn<int>(
    'last_ts',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _readAtMeta = const VerificationMeta('readAt');
  @override
  late final GeneratedColumn<int> readAt = GeneratedColumn<int>(
    'read_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    kind,
    title,
    createdTs,
    lastTs,
    readAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'conversations';
  @override
  VerificationContext validateIntegrity(
    Insertable<Conversation> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('kind')) {
      context.handle(
        _kindMeta,
        kind.isAcceptableOrUnknown(data['kind']!, _kindMeta),
      );
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    }
    if (data.containsKey('created_ts')) {
      context.handle(
        _createdTsMeta,
        createdTs.isAcceptableOrUnknown(data['created_ts']!, _createdTsMeta),
      );
    }
    if (data.containsKey('last_ts')) {
      context.handle(
        _lastTsMeta,
        lastTs.isAcceptableOrUnknown(data['last_ts']!, _lastTsMeta),
      );
    }
    if (data.containsKey('read_at')) {
      context.handle(
        _readAtMeta,
        readAt.isAcceptableOrUnknown(data['read_at']!, _readAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Conversation map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Conversation(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      kind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kind'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      createdTs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_ts'],
      )!,
      lastTs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}last_ts'],
      )!,
      readAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}read_at'],
      )!,
    );
  }

  @override
  $ConversationsTable createAlias(String alias) {
    return $ConversationsTable(attachedDatabase, alias);
  }
}

class Conversation extends DataClass implements Insertable<Conversation> {
  final String id;
  final String kind;
  final String title;
  final int createdTs;
  final int lastTs;

  /// Timestamp of the last time the user had this chat on screen. Unread is
  /// derived from the messages table (`timestamp > readAt`), so a count can
  /// never drift away from the messages it is counting.
  final int readAt;
  const Conversation({
    required this.id,
    required this.kind,
    required this.title,
    required this.createdTs,
    required this.lastTs,
    required this.readAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['kind'] = Variable<String>(kind);
    map['title'] = Variable<String>(title);
    map['created_ts'] = Variable<int>(createdTs);
    map['last_ts'] = Variable<int>(lastTs);
    map['read_at'] = Variable<int>(readAt);
    return map;
  }

  ConversationsCompanion toCompanion(bool nullToAbsent) {
    return ConversationsCompanion(
      id: Value(id),
      kind: Value(kind),
      title: Value(title),
      createdTs: Value(createdTs),
      lastTs: Value(lastTs),
      readAt: Value(readAt),
    );
  }

  factory Conversation.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Conversation(
      id: serializer.fromJson<String>(json['id']),
      kind: serializer.fromJson<String>(json['kind']),
      title: serializer.fromJson<String>(json['title']),
      createdTs: serializer.fromJson<int>(json['createdTs']),
      lastTs: serializer.fromJson<int>(json['lastTs']),
      readAt: serializer.fromJson<int>(json['readAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'kind': serializer.toJson<String>(kind),
      'title': serializer.toJson<String>(title),
      'createdTs': serializer.toJson<int>(createdTs),
      'lastTs': serializer.toJson<int>(lastTs),
      'readAt': serializer.toJson<int>(readAt),
    };
  }

  Conversation copyWith({
    String? id,
    String? kind,
    String? title,
    int? createdTs,
    int? lastTs,
    int? readAt,
  }) => Conversation(
    id: id ?? this.id,
    kind: kind ?? this.kind,
    title: title ?? this.title,
    createdTs: createdTs ?? this.createdTs,
    lastTs: lastTs ?? this.lastTs,
    readAt: readAt ?? this.readAt,
  );
  Conversation copyWithCompanion(ConversationsCompanion data) {
    return Conversation(
      id: data.id.present ? data.id.value : this.id,
      kind: data.kind.present ? data.kind.value : this.kind,
      title: data.title.present ? data.title.value : this.title,
      createdTs: data.createdTs.present ? data.createdTs.value : this.createdTs,
      lastTs: data.lastTs.present ? data.lastTs.value : this.lastTs,
      readAt: data.readAt.present ? data.readAt.value : this.readAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Conversation(')
          ..write('id: $id, ')
          ..write('kind: $kind, ')
          ..write('title: $title, ')
          ..write('createdTs: $createdTs, ')
          ..write('lastTs: $lastTs, ')
          ..write('readAt: $readAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, kind, title, createdTs, lastTs, readAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Conversation &&
          other.id == this.id &&
          other.kind == this.kind &&
          other.title == this.title &&
          other.createdTs == this.createdTs &&
          other.lastTs == this.lastTs &&
          other.readAt == this.readAt);
}

class ConversationsCompanion extends UpdateCompanion<Conversation> {
  final Value<String> id;
  final Value<String> kind;
  final Value<String> title;
  final Value<int> createdTs;
  final Value<int> lastTs;
  final Value<int> readAt;
  final Value<int> rowid;
  const ConversationsCompanion({
    this.id = const Value.absent(),
    this.kind = const Value.absent(),
    this.title = const Value.absent(),
    this.createdTs = const Value.absent(),
    this.lastTs = const Value.absent(),
    this.readAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ConversationsCompanion.insert({
    required String id,
    this.kind = const Value.absent(),
    this.title = const Value.absent(),
    this.createdTs = const Value.absent(),
    this.lastTs = const Value.absent(),
    this.readAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id);
  static Insertable<Conversation> custom({
    Expression<String>? id,
    Expression<String>? kind,
    Expression<String>? title,
    Expression<int>? createdTs,
    Expression<int>? lastTs,
    Expression<int>? readAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (kind != null) 'kind': kind,
      if (title != null) 'title': title,
      if (createdTs != null) 'created_ts': createdTs,
      if (lastTs != null) 'last_ts': lastTs,
      if (readAt != null) 'read_at': readAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ConversationsCompanion copyWith({
    Value<String>? id,
    Value<String>? kind,
    Value<String>? title,
    Value<int>? createdTs,
    Value<int>? lastTs,
    Value<int>? readAt,
    Value<int>? rowid,
  }) {
    return ConversationsCompanion(
      id: id ?? this.id,
      kind: kind ?? this.kind,
      title: title ?? this.title,
      createdTs: createdTs ?? this.createdTs,
      lastTs: lastTs ?? this.lastTs,
      readAt: readAt ?? this.readAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (createdTs.present) {
      map['created_ts'] = Variable<int>(createdTs.value);
    }
    if (lastTs.present) {
      map['last_ts'] = Variable<int>(lastTs.value);
    }
    if (readAt.present) {
      map['read_at'] = Variable<int>(readAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ConversationsCompanion(')
          ..write('id: $id, ')
          ..write('kind: $kind, ')
          ..write('title: $title, ')
          ..write('createdTs: $createdTs, ')
          ..write('lastTs: $lastTs, ')
          ..write('readAt: $readAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ConversationMembersTable extends ConversationMembers
    with TableInfo<$ConversationMembersTable, ConversationMember> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ConversationMembersTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _conversationIdMeta = const VerificationMeta(
    'conversationId',
  );
  @override
  late final GeneratedColumn<String> conversationId = GeneratedColumn<String>(
    'conversation_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _peerXKeyMeta = const VerificationMeta(
    'peerXKey',
  );
  @override
  late final GeneratedColumn<String> peerXKey = GeneratedColumn<String>(
    'peer_x_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _roleMeta = const VerificationMeta('role');
  @override
  late final GeneratedColumn<String> role = GeneratedColumn<String>(
    'role',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('member'),
  );
  @override
  List<GeneratedColumn> get $columns => [conversationId, peerXKey, role];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'conversation_members';
  @override
  VerificationContext validateIntegrity(
    Insertable<ConversationMember> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('conversation_id')) {
      context.handle(
        _conversationIdMeta,
        conversationId.isAcceptableOrUnknown(
          data['conversation_id']!,
          _conversationIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_conversationIdMeta);
    }
    if (data.containsKey('peer_x_key')) {
      context.handle(
        _peerXKeyMeta,
        peerXKey.isAcceptableOrUnknown(data['peer_x_key']!, _peerXKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_peerXKeyMeta);
    }
    if (data.containsKey('role')) {
      context.handle(
        _roleMeta,
        role.isAcceptableOrUnknown(data['role']!, _roleMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {conversationId, peerXKey};
  @override
  ConversationMember map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ConversationMember(
      conversationId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}conversation_id'],
      )!,
      peerXKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}peer_x_key'],
      )!,
      role: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}role'],
      )!,
    );
  }

  @override
  $ConversationMembersTable createAlias(String alias) {
    return $ConversationMembersTable(attachedDatabase, alias);
  }
}

class ConversationMember extends DataClass
    implements Insertable<ConversationMember> {
  final String conversationId;
  final String peerXKey;

  /// `admin` may change the roster and title; `member` may only write.
  final String role;
  const ConversationMember({
    required this.conversationId,
    required this.peerXKey,
    required this.role,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['conversation_id'] = Variable<String>(conversationId);
    map['peer_x_key'] = Variable<String>(peerXKey);
    map['role'] = Variable<String>(role);
    return map;
  }

  ConversationMembersCompanion toCompanion(bool nullToAbsent) {
    return ConversationMembersCompanion(
      conversationId: Value(conversationId),
      peerXKey: Value(peerXKey),
      role: Value(role),
    );
  }

  factory ConversationMember.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ConversationMember(
      conversationId: serializer.fromJson<String>(json['conversationId']),
      peerXKey: serializer.fromJson<String>(json['peerXKey']),
      role: serializer.fromJson<String>(json['role']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'conversationId': serializer.toJson<String>(conversationId),
      'peerXKey': serializer.toJson<String>(peerXKey),
      'role': serializer.toJson<String>(role),
    };
  }

  ConversationMember copyWith({
    String? conversationId,
    String? peerXKey,
    String? role,
  }) => ConversationMember(
    conversationId: conversationId ?? this.conversationId,
    peerXKey: peerXKey ?? this.peerXKey,
    role: role ?? this.role,
  );
  ConversationMember copyWithCompanion(ConversationMembersCompanion data) {
    return ConversationMember(
      conversationId: data.conversationId.present
          ? data.conversationId.value
          : this.conversationId,
      peerXKey: data.peerXKey.present ? data.peerXKey.value : this.peerXKey,
      role: data.role.present ? data.role.value : this.role,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ConversationMember(')
          ..write('conversationId: $conversationId, ')
          ..write('peerXKey: $peerXKey, ')
          ..write('role: $role')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(conversationId, peerXKey, role);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ConversationMember &&
          other.conversationId == this.conversationId &&
          other.peerXKey == this.peerXKey &&
          other.role == this.role);
}

class ConversationMembersCompanion extends UpdateCompanion<ConversationMember> {
  final Value<String> conversationId;
  final Value<String> peerXKey;
  final Value<String> role;
  final Value<int> rowid;
  const ConversationMembersCompanion({
    this.conversationId = const Value.absent(),
    this.peerXKey = const Value.absent(),
    this.role = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ConversationMembersCompanion.insert({
    required String conversationId,
    required String peerXKey,
    this.role = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : conversationId = Value(conversationId),
       peerXKey = Value(peerXKey);
  static Insertable<ConversationMember> custom({
    Expression<String>? conversationId,
    Expression<String>? peerXKey,
    Expression<String>? role,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (conversationId != null) 'conversation_id': conversationId,
      if (peerXKey != null) 'peer_x_key': peerXKey,
      if (role != null) 'role': role,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ConversationMembersCompanion copyWith({
    Value<String>? conversationId,
    Value<String>? peerXKey,
    Value<String>? role,
    Value<int>? rowid,
  }) {
    return ConversationMembersCompanion(
      conversationId: conversationId ?? this.conversationId,
      peerXKey: peerXKey ?? this.peerXKey,
      role: role ?? this.role,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (conversationId.present) {
      map['conversation_id'] = Variable<String>(conversationId.value);
    }
    if (peerXKey.present) {
      map['peer_x_key'] = Variable<String>(peerXKey.value);
    }
    if (role.present) {
      map['role'] = Variable<String>(role.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ConversationMembersCompanion(')
          ..write('conversationId: $conversationId, ')
          ..write('peerXKey: $peerXKey, ')
          ..write('role: $role, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $OutgoingBodiesTable extends OutgoingBodies
    with TableInfo<$OutgoingBodiesTable, OutgoingBody> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $OutgoingBodiesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _plaintextMeta = const VerificationMeta(
    'plaintext',
  );
  @override
  late final GeneratedColumn<String> plaintext = GeneratedColumn<String>(
    'plaintext',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _timestampMeta = const VerificationMeta(
    'timestamp',
  );
  @override
  late final GeneratedColumn<int> timestamp = GeneratedColumn<int>(
    'timestamp',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [id, plaintext, timestamp];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'outgoing_bodies';
  @override
  VerificationContext validateIntegrity(
    Insertable<OutgoingBody> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('plaintext')) {
      context.handle(
        _plaintextMeta,
        plaintext.isAcceptableOrUnknown(data['plaintext']!, _plaintextMeta),
      );
    } else if (isInserting) {
      context.missing(_plaintextMeta);
    }
    if (data.containsKey('timestamp')) {
      context.handle(
        _timestampMeta,
        timestamp.isAcceptableOrUnknown(data['timestamp']!, _timestampMeta),
      );
    } else if (isInserting) {
      context.missing(_timestampMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  OutgoingBody map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return OutgoingBody(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      plaintext: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}plaintext'],
      )!,
      timestamp: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}timestamp'],
      )!,
    );
  }

  @override
  $OutgoingBodiesTable createAlias(String alias) {
    return $OutgoingBodiesTable(attachedDatabase, alias);
  }
}

class OutgoingBody extends DataClass implements Insertable<OutgoingBody> {
  final String id;
  final String plaintext;
  final int timestamp;
  const OutgoingBody({
    required this.id,
    required this.plaintext,
    required this.timestamp,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['plaintext'] = Variable<String>(plaintext);
    map['timestamp'] = Variable<int>(timestamp);
    return map;
  }

  OutgoingBodiesCompanion toCompanion(bool nullToAbsent) {
    return OutgoingBodiesCompanion(
      id: Value(id),
      plaintext: Value(plaintext),
      timestamp: Value(timestamp),
    );
  }

  factory OutgoingBody.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return OutgoingBody(
      id: serializer.fromJson<String>(json['id']),
      plaintext: serializer.fromJson<String>(json['plaintext']),
      timestamp: serializer.fromJson<int>(json['timestamp']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'plaintext': serializer.toJson<String>(plaintext),
      'timestamp': serializer.toJson<int>(timestamp),
    };
  }

  OutgoingBody copyWith({String? id, String? plaintext, int? timestamp}) =>
      OutgoingBody(
        id: id ?? this.id,
        plaintext: plaintext ?? this.plaintext,
        timestamp: timestamp ?? this.timestamp,
      );
  OutgoingBody copyWithCompanion(OutgoingBodiesCompanion data) {
    return OutgoingBody(
      id: data.id.present ? data.id.value : this.id,
      plaintext: data.plaintext.present ? data.plaintext.value : this.plaintext,
      timestamp: data.timestamp.present ? data.timestamp.value : this.timestamp,
    );
  }

  @override
  String toString() {
    return (StringBuffer('OutgoingBody(')
          ..write('id: $id, ')
          ..write('plaintext: $plaintext, ')
          ..write('timestamp: $timestamp')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, plaintext, timestamp);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is OutgoingBody &&
          other.id == this.id &&
          other.plaintext == this.plaintext &&
          other.timestamp == this.timestamp);
}

class OutgoingBodiesCompanion extends UpdateCompanion<OutgoingBody> {
  final Value<String> id;
  final Value<String> plaintext;
  final Value<int> timestamp;
  final Value<int> rowid;
  const OutgoingBodiesCompanion({
    this.id = const Value.absent(),
    this.plaintext = const Value.absent(),
    this.timestamp = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  OutgoingBodiesCompanion.insert({
    required String id,
    required String plaintext,
    required int timestamp,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       plaintext = Value(plaintext),
       timestamp = Value(timestamp);
  static Insertable<OutgoingBody> custom({
    Expression<String>? id,
    Expression<String>? plaintext,
    Expression<int>? timestamp,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (plaintext != null) 'plaintext': plaintext,
      if (timestamp != null) 'timestamp': timestamp,
      if (rowid != null) 'rowid': rowid,
    });
  }

  OutgoingBodiesCompanion copyWith({
    Value<String>? id,
    Value<String>? plaintext,
    Value<int>? timestamp,
    Value<int>? rowid,
  }) {
    return OutgoingBodiesCompanion(
      id: id ?? this.id,
      plaintext: plaintext ?? this.plaintext,
      timestamp: timestamp ?? this.timestamp,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (plaintext.present) {
      map['plaintext'] = Variable<String>(plaintext.value);
    }
    if (timestamp.present) {
      map['timestamp'] = Variable<int>(timestamp.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('OutgoingBodiesCompanion(')
          ..write('id: $id, ')
          ..write('plaintext: $plaintext, ')
          ..write('timestamp: $timestamp, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $MessageStatusesTable extends MessageStatuses
    with TableInfo<$MessageStatusesTable, MessageStatuse> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MessageStatusesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<int> status = GeneratedColumn<int>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  List<GeneratedColumn> get $columns => [id, status, updatedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'message_statuses';
  @override
  VerificationContext validateIntegrity(
    Insertable<MessageStatuse> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  MessageStatuse map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return MessageStatuse(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}status'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $MessageStatusesTable createAlias(String alias) {
    return $MessageStatusesTable(attachedDatabase, alias);
  }
}

class MessageStatuse extends DataClass implements Insertable<MessageStatuse> {
  final String id;
  final int status;
  final int updatedAt;
  const MessageStatuse({
    required this.id,
    required this.status,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['status'] = Variable<int>(status);
    map['updated_at'] = Variable<int>(updatedAt);
    return map;
  }

  MessageStatusesCompanion toCompanion(bool nullToAbsent) {
    return MessageStatusesCompanion(
      id: Value(id),
      status: Value(status),
      updatedAt: Value(updatedAt),
    );
  }

  factory MessageStatuse.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return MessageStatuse(
      id: serializer.fromJson<String>(json['id']),
      status: serializer.fromJson<int>(json['status']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'status': serializer.toJson<int>(status),
      'updatedAt': serializer.toJson<int>(updatedAt),
    };
  }

  MessageStatuse copyWith({String? id, int? status, int? updatedAt}) =>
      MessageStatuse(
        id: id ?? this.id,
        status: status ?? this.status,
        updatedAt: updatedAt ?? this.updatedAt,
      );
  MessageStatuse copyWithCompanion(MessageStatusesCompanion data) {
    return MessageStatuse(
      id: data.id.present ? data.id.value : this.id,
      status: data.status.present ? data.status.value : this.status,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('MessageStatuse(')
          ..write('id: $id, ')
          ..write('status: $status, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, status, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MessageStatuse &&
          other.id == this.id &&
          other.status == this.status &&
          other.updatedAt == this.updatedAt);
}

class MessageStatusesCompanion extends UpdateCompanion<MessageStatuse> {
  final Value<String> id;
  final Value<int> status;
  final Value<int> updatedAt;
  final Value<int> rowid;
  const MessageStatusesCompanion({
    this.id = const Value.absent(),
    this.status = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  MessageStatusesCompanion.insert({
    required String id,
    this.status = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id);
  static Insertable<MessageStatuse> custom({
    Expression<String>? id,
    Expression<int>? status,
    Expression<int>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (status != null) 'status': status,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  MessageStatusesCompanion copyWith({
    Value<String>? id,
    Value<int>? status,
    Value<int>? updatedAt,
    Value<int>? rowid,
  }) {
    return MessageStatusesCompanion(
      id: id ?? this.id,
      status: status ?? this.status,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (status.present) {
      map['status'] = Variable<int>(status.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MessageStatusesCompanion(')
          ..write('id: $id, ')
          ..write('status: $status, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $MediaBlobsTable extends MediaBlobs
    with TableInfo<$MediaBlobsTable, MediaBlob> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MediaBlobsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _blobIdMeta = const VerificationMeta('blobId');
  @override
  late final GeneratedColumn<String> blobId = GeneratedColumn<String>(
    'blob_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
    'kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _mimeMeta = const VerificationMeta('mime');
  @override
  late final GeneratedColumn<String> mime = GeneratedColumn<String>(
    'mime',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _byteCountMeta = const VerificationMeta(
    'byteCount',
  );
  @override
  late final GeneratedColumn<int> byteCount = GeneratedColumn<int>(
    'byte_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _durationMsMeta = const VerificationMeta(
    'durationMs',
  );
  @override
  late final GeneratedColumn<int> durationMs = GeneratedColumn<int>(
    'duration_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _dataMeta = const VerificationMeta('data');
  @override
  late final GeneratedColumn<String> data = GeneratedColumn<String>(
    'data',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _timestampMeta = const VerificationMeta(
    'timestamp',
  );
  @override
  late final GeneratedColumn<int> timestamp = GeneratedColumn<int>(
    'timestamp',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _pathMeta = const VerificationMeta('path');
  @override
  late final GeneratedColumn<String> path = GeneratedColumn<String>(
    'path',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  @override
  List<GeneratedColumn> get $columns => [
    blobId,
    kind,
    mime,
    byteCount,
    durationMs,
    data,
    timestamp,
    path,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'media_blobs';
  @override
  VerificationContext validateIntegrity(
    Insertable<MediaBlob> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('blob_id')) {
      context.handle(
        _blobIdMeta,
        blobId.isAcceptableOrUnknown(data['blob_id']!, _blobIdMeta),
      );
    } else if (isInserting) {
      context.missing(_blobIdMeta);
    }
    if (data.containsKey('kind')) {
      context.handle(
        _kindMeta,
        kind.isAcceptableOrUnknown(data['kind']!, _kindMeta),
      );
    } else if (isInserting) {
      context.missing(_kindMeta);
    }
    if (data.containsKey('mime')) {
      context.handle(
        _mimeMeta,
        mime.isAcceptableOrUnknown(data['mime']!, _mimeMeta),
      );
    } else if (isInserting) {
      context.missing(_mimeMeta);
    }
    if (data.containsKey('byte_count')) {
      context.handle(
        _byteCountMeta,
        byteCount.isAcceptableOrUnknown(data['byte_count']!, _byteCountMeta),
      );
    } else if (isInserting) {
      context.missing(_byteCountMeta);
    }
    if (data.containsKey('duration_ms')) {
      context.handle(
        _durationMsMeta,
        durationMs.isAcceptableOrUnknown(data['duration_ms']!, _durationMsMeta),
      );
    }
    if (data.containsKey('data')) {
      context.handle(
        _dataMeta,
        this.data.isAcceptableOrUnknown(data['data']!, _dataMeta),
      );
    } else if (isInserting) {
      context.missing(_dataMeta);
    }
    if (data.containsKey('timestamp')) {
      context.handle(
        _timestampMeta,
        timestamp.isAcceptableOrUnknown(data['timestamp']!, _timestampMeta),
      );
    }
    if (data.containsKey('path')) {
      context.handle(
        _pathMeta,
        path.isAcceptableOrUnknown(data['path']!, _pathMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {blobId};
  @override
  MediaBlob map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return MediaBlob(
      blobId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}blob_id'],
      )!,
      kind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kind'],
      )!,
      mime: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}mime'],
      )!,
      byteCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}byte_count'],
      )!,
      durationMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}duration_ms'],
      )!,
      data: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}data'],
      )!,
      timestamp: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}timestamp'],
      )!,
      path: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}path'],
      )!,
    );
  }

  @override
  $MediaBlobsTable createAlias(String alias) {
    return $MediaBlobsTable(attachedDatabase, alias);
  }
}

class MediaBlob extends DataClass implements Insertable<MediaBlob> {
  final String blobId;

  /// `voice` or `photo`; stored as the wire tag so a value survives without
  /// depending on an enum ordinal.
  final String kind;
  final String mime;
  final int byteCount;
  final int durationMs;

  /// Base64 of the raw bytes for inline media (voice, photo). Empty for a
  /// chunked file stored on disk under [path].
  final String data;
  final int timestamp;

  /// Relative path of the blob file for chunked media; empty for inline rows.
  final String path;
  const MediaBlob({
    required this.blobId,
    required this.kind,
    required this.mime,
    required this.byteCount,
    required this.durationMs,
    required this.data,
    required this.timestamp,
    required this.path,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['blob_id'] = Variable<String>(blobId);
    map['kind'] = Variable<String>(kind);
    map['mime'] = Variable<String>(mime);
    map['byte_count'] = Variable<int>(byteCount);
    map['duration_ms'] = Variable<int>(durationMs);
    map['data'] = Variable<String>(data);
    map['timestamp'] = Variable<int>(timestamp);
    map['path'] = Variable<String>(path);
    return map;
  }

  MediaBlobsCompanion toCompanion(bool nullToAbsent) {
    return MediaBlobsCompanion(
      blobId: Value(blobId),
      kind: Value(kind),
      mime: Value(mime),
      byteCount: Value(byteCount),
      durationMs: Value(durationMs),
      data: Value(data),
      timestamp: Value(timestamp),
      path: Value(path),
    );
  }

  factory MediaBlob.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return MediaBlob(
      blobId: serializer.fromJson<String>(json['blobId']),
      kind: serializer.fromJson<String>(json['kind']),
      mime: serializer.fromJson<String>(json['mime']),
      byteCount: serializer.fromJson<int>(json['byteCount']),
      durationMs: serializer.fromJson<int>(json['durationMs']),
      data: serializer.fromJson<String>(json['data']),
      timestamp: serializer.fromJson<int>(json['timestamp']),
      path: serializer.fromJson<String>(json['path']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'blobId': serializer.toJson<String>(blobId),
      'kind': serializer.toJson<String>(kind),
      'mime': serializer.toJson<String>(mime),
      'byteCount': serializer.toJson<int>(byteCount),
      'durationMs': serializer.toJson<int>(durationMs),
      'data': serializer.toJson<String>(data),
      'timestamp': serializer.toJson<int>(timestamp),
      'path': serializer.toJson<String>(path),
    };
  }

  MediaBlob copyWith({
    String? blobId,
    String? kind,
    String? mime,
    int? byteCount,
    int? durationMs,
    String? data,
    int? timestamp,
    String? path,
  }) => MediaBlob(
    blobId: blobId ?? this.blobId,
    kind: kind ?? this.kind,
    mime: mime ?? this.mime,
    byteCount: byteCount ?? this.byteCount,
    durationMs: durationMs ?? this.durationMs,
    data: data ?? this.data,
    timestamp: timestamp ?? this.timestamp,
    path: path ?? this.path,
  );
  MediaBlob copyWithCompanion(MediaBlobsCompanion data) {
    return MediaBlob(
      blobId: data.blobId.present ? data.blobId.value : this.blobId,
      kind: data.kind.present ? data.kind.value : this.kind,
      mime: data.mime.present ? data.mime.value : this.mime,
      byteCount: data.byteCount.present ? data.byteCount.value : this.byteCount,
      durationMs: data.durationMs.present
          ? data.durationMs.value
          : this.durationMs,
      data: data.data.present ? data.data.value : this.data,
      timestamp: data.timestamp.present ? data.timestamp.value : this.timestamp,
      path: data.path.present ? data.path.value : this.path,
    );
  }

  @override
  String toString() {
    return (StringBuffer('MediaBlob(')
          ..write('blobId: $blobId, ')
          ..write('kind: $kind, ')
          ..write('mime: $mime, ')
          ..write('byteCount: $byteCount, ')
          ..write('durationMs: $durationMs, ')
          ..write('data: $data, ')
          ..write('timestamp: $timestamp, ')
          ..write('path: $path')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    blobId,
    kind,
    mime,
    byteCount,
    durationMs,
    data,
    timestamp,
    path,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MediaBlob &&
          other.blobId == this.blobId &&
          other.kind == this.kind &&
          other.mime == this.mime &&
          other.byteCount == this.byteCount &&
          other.durationMs == this.durationMs &&
          other.data == this.data &&
          other.timestamp == this.timestamp &&
          other.path == this.path);
}

class MediaBlobsCompanion extends UpdateCompanion<MediaBlob> {
  final Value<String> blobId;
  final Value<String> kind;
  final Value<String> mime;
  final Value<int> byteCount;
  final Value<int> durationMs;
  final Value<String> data;
  final Value<int> timestamp;
  final Value<String> path;
  final Value<int> rowid;
  const MediaBlobsCompanion({
    this.blobId = const Value.absent(),
    this.kind = const Value.absent(),
    this.mime = const Value.absent(),
    this.byteCount = const Value.absent(),
    this.durationMs = const Value.absent(),
    this.data = const Value.absent(),
    this.timestamp = const Value.absent(),
    this.path = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  MediaBlobsCompanion.insert({
    required String blobId,
    required String kind,
    required String mime,
    required int byteCount,
    this.durationMs = const Value.absent(),
    required String data,
    this.timestamp = const Value.absent(),
    this.path = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : blobId = Value(blobId),
       kind = Value(kind),
       mime = Value(mime),
       byteCount = Value(byteCount),
       data = Value(data);
  static Insertable<MediaBlob> custom({
    Expression<String>? blobId,
    Expression<String>? kind,
    Expression<String>? mime,
    Expression<int>? byteCount,
    Expression<int>? durationMs,
    Expression<String>? data,
    Expression<int>? timestamp,
    Expression<String>? path,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (blobId != null) 'blob_id': blobId,
      if (kind != null) 'kind': kind,
      if (mime != null) 'mime': mime,
      if (byteCount != null) 'byte_count': byteCount,
      if (durationMs != null) 'duration_ms': durationMs,
      if (data != null) 'data': data,
      if (timestamp != null) 'timestamp': timestamp,
      if (path != null) 'path': path,
      if (rowid != null) 'rowid': rowid,
    });
  }

  MediaBlobsCompanion copyWith({
    Value<String>? blobId,
    Value<String>? kind,
    Value<String>? mime,
    Value<int>? byteCount,
    Value<int>? durationMs,
    Value<String>? data,
    Value<int>? timestamp,
    Value<String>? path,
    Value<int>? rowid,
  }) {
    return MediaBlobsCompanion(
      blobId: blobId ?? this.blobId,
      kind: kind ?? this.kind,
      mime: mime ?? this.mime,
      byteCount: byteCount ?? this.byteCount,
      durationMs: durationMs ?? this.durationMs,
      data: data ?? this.data,
      timestamp: timestamp ?? this.timestamp,
      path: path ?? this.path,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (blobId.present) {
      map['blob_id'] = Variable<String>(blobId.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (mime.present) {
      map['mime'] = Variable<String>(mime.value);
    }
    if (byteCount.present) {
      map['byte_count'] = Variable<int>(byteCount.value);
    }
    if (durationMs.present) {
      map['duration_ms'] = Variable<int>(durationMs.value);
    }
    if (data.present) {
      map['data'] = Variable<String>(data.value);
    }
    if (timestamp.present) {
      map['timestamp'] = Variable<int>(timestamp.value);
    }
    if (path.present) {
      map['path'] = Variable<String>(path.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MediaBlobsCompanion(')
          ..write('blobId: $blobId, ')
          ..write('kind: $kind, ')
          ..write('mime: $mime, ')
          ..write('byteCount: $byteCount, ')
          ..write('durationMs: $durationMs, ')
          ..write('data: $data, ')
          ..write('timestamp: $timestamp, ')
          ..write('path: $path, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $TransfersTable extends Transfers
    with TableInfo<$TransfersTable, Transfer> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TransfersTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _transferIdMeta = const VerificationMeta(
    'transferId',
  );
  @override
  late final GeneratedColumn<String> transferId = GeneratedColumn<String>(
    'transfer_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _blobIdMeta = const VerificationMeta('blobId');
  @override
  late final GeneratedColumn<String> blobId = GeneratedColumn<String>(
    'blob_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
    'kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _mimeMeta = const VerificationMeta('mime');
  @override
  late final GeneratedColumn<String> mime = GeneratedColumn<String>(
    'mime',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _byteCountMeta = const VerificationMeta(
    'byteCount',
  );
  @override
  late final GeneratedColumn<int> byteCount = GeneratedColumn<int>(
    'byte_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _chunkSizeMeta = const VerificationMeta(
    'chunkSize',
  );
  @override
  late final GeneratedColumn<int> chunkSize = GeneratedColumn<int>(
    'chunk_size',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _chunkCountMeta = const VerificationMeta(
    'chunkCount',
  );
  @override
  late final GeneratedColumn<int> chunkCount = GeneratedColumn<int>(
    'chunk_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sha256Meta = const VerificationMeta('sha256');
  @override
  late final GeneratedColumn<String> sha256 = GeneratedColumn<String>(
    'sha256',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _durationMsMeta = const VerificationMeta(
    'durationMs',
  );
  @override
  late final GeneratedColumn<int> durationMs = GeneratedColumn<int>(
    'duration_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _senderXMeta = const VerificationMeta(
    'senderX',
  );
  @override
  late final GeneratedColumn<String> senderX = GeneratedColumn<String>(
    'sender_x',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _conversationIdMeta = const VerificationMeta(
    'conversationId',
  );
  @override
  late final GeneratedColumn<String> conversationId = GeneratedColumn<String>(
    'conversation_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _startedMeta = const VerificationMeta(
    'started',
  );
  @override
  late final GeneratedColumn<int> started = GeneratedColumn<int>(
    'started',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _timestampMeta = const VerificationMeta(
    'timestamp',
  );
  @override
  late final GeneratedColumn<int> timestamp = GeneratedColumn<int>(
    'timestamp',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _completedMeta = const VerificationMeta(
    'completed',
  );
  @override
  late final GeneratedColumn<int> completed = GeneratedColumn<int>(
    'completed',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  List<GeneratedColumn> get $columns => [
    transferId,
    blobId,
    kind,
    mime,
    byteCount,
    chunkSize,
    chunkCount,
    sha256,
    durationMs,
    senderX,
    conversationId,
    started,
    timestamp,
    completed,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'transfers';
  @override
  VerificationContext validateIntegrity(
    Insertable<Transfer> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('transfer_id')) {
      context.handle(
        _transferIdMeta,
        transferId.isAcceptableOrUnknown(data['transfer_id']!, _transferIdMeta),
      );
    } else if (isInserting) {
      context.missing(_transferIdMeta);
    }
    if (data.containsKey('blob_id')) {
      context.handle(
        _blobIdMeta,
        blobId.isAcceptableOrUnknown(data['blob_id']!, _blobIdMeta),
      );
    } else if (isInserting) {
      context.missing(_blobIdMeta);
    }
    if (data.containsKey('kind')) {
      context.handle(
        _kindMeta,
        kind.isAcceptableOrUnknown(data['kind']!, _kindMeta),
      );
    } else if (isInserting) {
      context.missing(_kindMeta);
    }
    if (data.containsKey('mime')) {
      context.handle(
        _mimeMeta,
        mime.isAcceptableOrUnknown(data['mime']!, _mimeMeta),
      );
    } else if (isInserting) {
      context.missing(_mimeMeta);
    }
    if (data.containsKey('byte_count')) {
      context.handle(
        _byteCountMeta,
        byteCount.isAcceptableOrUnknown(data['byte_count']!, _byteCountMeta),
      );
    } else if (isInserting) {
      context.missing(_byteCountMeta);
    }
    if (data.containsKey('chunk_size')) {
      context.handle(
        _chunkSizeMeta,
        chunkSize.isAcceptableOrUnknown(data['chunk_size']!, _chunkSizeMeta),
      );
    } else if (isInserting) {
      context.missing(_chunkSizeMeta);
    }
    if (data.containsKey('chunk_count')) {
      context.handle(
        _chunkCountMeta,
        chunkCount.isAcceptableOrUnknown(data['chunk_count']!, _chunkCountMeta),
      );
    } else if (isInserting) {
      context.missing(_chunkCountMeta);
    }
    if (data.containsKey('sha256')) {
      context.handle(
        _sha256Meta,
        sha256.isAcceptableOrUnknown(data['sha256']!, _sha256Meta),
      );
    } else if (isInserting) {
      context.missing(_sha256Meta);
    }
    if (data.containsKey('duration_ms')) {
      context.handle(
        _durationMsMeta,
        durationMs.isAcceptableOrUnknown(data['duration_ms']!, _durationMsMeta),
      );
    }
    if (data.containsKey('sender_x')) {
      context.handle(
        _senderXMeta,
        senderX.isAcceptableOrUnknown(data['sender_x']!, _senderXMeta),
      );
    } else if (isInserting) {
      context.missing(_senderXMeta);
    }
    if (data.containsKey('conversation_id')) {
      context.handle(
        _conversationIdMeta,
        conversationId.isAcceptableOrUnknown(
          data['conversation_id']!,
          _conversationIdMeta,
        ),
      );
    }
    if (data.containsKey('started')) {
      context.handle(
        _startedMeta,
        started.isAcceptableOrUnknown(data['started']!, _startedMeta),
      );
    }
    if (data.containsKey('timestamp')) {
      context.handle(
        _timestampMeta,
        timestamp.isAcceptableOrUnknown(data['timestamp']!, _timestampMeta),
      );
    }
    if (data.containsKey('completed')) {
      context.handle(
        _completedMeta,
        completed.isAcceptableOrUnknown(data['completed']!, _completedMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {transferId};
  @override
  Transfer map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Transfer(
      transferId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}transfer_id'],
      )!,
      blobId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}blob_id'],
      )!,
      kind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kind'],
      )!,
      mime: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}mime'],
      )!,
      byteCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}byte_count'],
      )!,
      chunkSize: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}chunk_size'],
      )!,
      chunkCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}chunk_count'],
      )!,
      sha256: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sha256'],
      )!,
      durationMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}duration_ms'],
      )!,
      senderX: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sender_x'],
      )!,
      conversationId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}conversation_id'],
      )!,
      started: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}started'],
      )!,
      timestamp: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}timestamp'],
      )!,
      completed: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}completed'],
      )!,
    );
  }

  @override
  $TransfersTable createAlias(String alias) {
    return $TransfersTable(attachedDatabase, alias);
  }
}

class Transfer extends DataClass implements Insertable<Transfer> {
  final String transferId;
  final String blobId;
  final String kind;
  final String mime;
  final int byteCount;
  final int chunkSize;
  final int chunkCount;
  final String sha256;
  final int durationMs;

  /// X25519 address of the sender, used for receipts and rendering.
  final String senderX;

  /// Group the transfer belongs to (`''` for a 1:1 chat).
  final String conversationId;

  /// Whether the download was started: automatic for files up to
  /// [autoDownloadBytes], explicit for larger ones.
  final int started;
  final int timestamp;

  /// A finished transfer keeps its manifest row (without slices) so the
  /// device can still prove who may request the completed blob. Excluded
  /// from active counts and staging bounds; pruned by age like any row.
  final int completed;
  const Transfer({
    required this.transferId,
    required this.blobId,
    required this.kind,
    required this.mime,
    required this.byteCount,
    required this.chunkSize,
    required this.chunkCount,
    required this.sha256,
    required this.durationMs,
    required this.senderX,
    required this.conversationId,
    required this.started,
    required this.timestamp,
    required this.completed,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['transfer_id'] = Variable<String>(transferId);
    map['blob_id'] = Variable<String>(blobId);
    map['kind'] = Variable<String>(kind);
    map['mime'] = Variable<String>(mime);
    map['byte_count'] = Variable<int>(byteCount);
    map['chunk_size'] = Variable<int>(chunkSize);
    map['chunk_count'] = Variable<int>(chunkCount);
    map['sha256'] = Variable<String>(sha256);
    map['duration_ms'] = Variable<int>(durationMs);
    map['sender_x'] = Variable<String>(senderX);
    map['conversation_id'] = Variable<String>(conversationId);
    map['started'] = Variable<int>(started);
    map['timestamp'] = Variable<int>(timestamp);
    map['completed'] = Variable<int>(completed);
    return map;
  }

  TransfersCompanion toCompanion(bool nullToAbsent) {
    return TransfersCompanion(
      transferId: Value(transferId),
      blobId: Value(blobId),
      kind: Value(kind),
      mime: Value(mime),
      byteCount: Value(byteCount),
      chunkSize: Value(chunkSize),
      chunkCount: Value(chunkCount),
      sha256: Value(sha256),
      durationMs: Value(durationMs),
      senderX: Value(senderX),
      conversationId: Value(conversationId),
      started: Value(started),
      timestamp: Value(timestamp),
      completed: Value(completed),
    );
  }

  factory Transfer.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Transfer(
      transferId: serializer.fromJson<String>(json['transferId']),
      blobId: serializer.fromJson<String>(json['blobId']),
      kind: serializer.fromJson<String>(json['kind']),
      mime: serializer.fromJson<String>(json['mime']),
      byteCount: serializer.fromJson<int>(json['byteCount']),
      chunkSize: serializer.fromJson<int>(json['chunkSize']),
      chunkCount: serializer.fromJson<int>(json['chunkCount']),
      sha256: serializer.fromJson<String>(json['sha256']),
      durationMs: serializer.fromJson<int>(json['durationMs']),
      senderX: serializer.fromJson<String>(json['senderX']),
      conversationId: serializer.fromJson<String>(json['conversationId']),
      started: serializer.fromJson<int>(json['started']),
      timestamp: serializer.fromJson<int>(json['timestamp']),
      completed: serializer.fromJson<int>(json['completed']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'transferId': serializer.toJson<String>(transferId),
      'blobId': serializer.toJson<String>(blobId),
      'kind': serializer.toJson<String>(kind),
      'mime': serializer.toJson<String>(mime),
      'byteCount': serializer.toJson<int>(byteCount),
      'chunkSize': serializer.toJson<int>(chunkSize),
      'chunkCount': serializer.toJson<int>(chunkCount),
      'sha256': serializer.toJson<String>(sha256),
      'durationMs': serializer.toJson<int>(durationMs),
      'senderX': serializer.toJson<String>(senderX),
      'conversationId': serializer.toJson<String>(conversationId),
      'started': serializer.toJson<int>(started),
      'timestamp': serializer.toJson<int>(timestamp),
      'completed': serializer.toJson<int>(completed),
    };
  }

  Transfer copyWith({
    String? transferId,
    String? blobId,
    String? kind,
    String? mime,
    int? byteCount,
    int? chunkSize,
    int? chunkCount,
    String? sha256,
    int? durationMs,
    String? senderX,
    String? conversationId,
    int? started,
    int? timestamp,
    int? completed,
  }) => Transfer(
    transferId: transferId ?? this.transferId,
    blobId: blobId ?? this.blobId,
    kind: kind ?? this.kind,
    mime: mime ?? this.mime,
    byteCount: byteCount ?? this.byteCount,
    chunkSize: chunkSize ?? this.chunkSize,
    chunkCount: chunkCount ?? this.chunkCount,
    sha256: sha256 ?? this.sha256,
    durationMs: durationMs ?? this.durationMs,
    senderX: senderX ?? this.senderX,
    conversationId: conversationId ?? this.conversationId,
    started: started ?? this.started,
    timestamp: timestamp ?? this.timestamp,
    completed: completed ?? this.completed,
  );
  Transfer copyWithCompanion(TransfersCompanion data) {
    return Transfer(
      transferId: data.transferId.present
          ? data.transferId.value
          : this.transferId,
      blobId: data.blobId.present ? data.blobId.value : this.blobId,
      kind: data.kind.present ? data.kind.value : this.kind,
      mime: data.mime.present ? data.mime.value : this.mime,
      byteCount: data.byteCount.present ? data.byteCount.value : this.byteCount,
      chunkSize: data.chunkSize.present ? data.chunkSize.value : this.chunkSize,
      chunkCount: data.chunkCount.present
          ? data.chunkCount.value
          : this.chunkCount,
      sha256: data.sha256.present ? data.sha256.value : this.sha256,
      durationMs: data.durationMs.present
          ? data.durationMs.value
          : this.durationMs,
      senderX: data.senderX.present ? data.senderX.value : this.senderX,
      conversationId: data.conversationId.present
          ? data.conversationId.value
          : this.conversationId,
      started: data.started.present ? data.started.value : this.started,
      timestamp: data.timestamp.present ? data.timestamp.value : this.timestamp,
      completed: data.completed.present ? data.completed.value : this.completed,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Transfer(')
          ..write('transferId: $transferId, ')
          ..write('blobId: $blobId, ')
          ..write('kind: $kind, ')
          ..write('mime: $mime, ')
          ..write('byteCount: $byteCount, ')
          ..write('chunkSize: $chunkSize, ')
          ..write('chunkCount: $chunkCount, ')
          ..write('sha256: $sha256, ')
          ..write('durationMs: $durationMs, ')
          ..write('senderX: $senderX, ')
          ..write('conversationId: $conversationId, ')
          ..write('started: $started, ')
          ..write('timestamp: $timestamp, ')
          ..write('completed: $completed')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    transferId,
    blobId,
    kind,
    mime,
    byteCount,
    chunkSize,
    chunkCount,
    sha256,
    durationMs,
    senderX,
    conversationId,
    started,
    timestamp,
    completed,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Transfer &&
          other.transferId == this.transferId &&
          other.blobId == this.blobId &&
          other.kind == this.kind &&
          other.mime == this.mime &&
          other.byteCount == this.byteCount &&
          other.chunkSize == this.chunkSize &&
          other.chunkCount == this.chunkCount &&
          other.sha256 == this.sha256 &&
          other.durationMs == this.durationMs &&
          other.senderX == this.senderX &&
          other.conversationId == this.conversationId &&
          other.started == this.started &&
          other.timestamp == this.timestamp &&
          other.completed == this.completed);
}

class TransfersCompanion extends UpdateCompanion<Transfer> {
  final Value<String> transferId;
  final Value<String> blobId;
  final Value<String> kind;
  final Value<String> mime;
  final Value<int> byteCount;
  final Value<int> chunkSize;
  final Value<int> chunkCount;
  final Value<String> sha256;
  final Value<int> durationMs;
  final Value<String> senderX;
  final Value<String> conversationId;
  final Value<int> started;
  final Value<int> timestamp;
  final Value<int> completed;
  final Value<int> rowid;
  const TransfersCompanion({
    this.transferId = const Value.absent(),
    this.blobId = const Value.absent(),
    this.kind = const Value.absent(),
    this.mime = const Value.absent(),
    this.byteCount = const Value.absent(),
    this.chunkSize = const Value.absent(),
    this.chunkCount = const Value.absent(),
    this.sha256 = const Value.absent(),
    this.durationMs = const Value.absent(),
    this.senderX = const Value.absent(),
    this.conversationId = const Value.absent(),
    this.started = const Value.absent(),
    this.timestamp = const Value.absent(),
    this.completed = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  TransfersCompanion.insert({
    required String transferId,
    required String blobId,
    required String kind,
    required String mime,
    required int byteCount,
    required int chunkSize,
    required int chunkCount,
    required String sha256,
    this.durationMs = const Value.absent(),
    required String senderX,
    this.conversationId = const Value.absent(),
    this.started = const Value.absent(),
    this.timestamp = const Value.absent(),
    this.completed = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : transferId = Value(transferId),
       blobId = Value(blobId),
       kind = Value(kind),
       mime = Value(mime),
       byteCount = Value(byteCount),
       chunkSize = Value(chunkSize),
       chunkCount = Value(chunkCount),
       sha256 = Value(sha256),
       senderX = Value(senderX);
  static Insertable<Transfer> custom({
    Expression<String>? transferId,
    Expression<String>? blobId,
    Expression<String>? kind,
    Expression<String>? mime,
    Expression<int>? byteCount,
    Expression<int>? chunkSize,
    Expression<int>? chunkCount,
    Expression<String>? sha256,
    Expression<int>? durationMs,
    Expression<String>? senderX,
    Expression<String>? conversationId,
    Expression<int>? started,
    Expression<int>? timestamp,
    Expression<int>? completed,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (transferId != null) 'transfer_id': transferId,
      if (blobId != null) 'blob_id': blobId,
      if (kind != null) 'kind': kind,
      if (mime != null) 'mime': mime,
      if (byteCount != null) 'byte_count': byteCount,
      if (chunkSize != null) 'chunk_size': chunkSize,
      if (chunkCount != null) 'chunk_count': chunkCount,
      if (sha256 != null) 'sha256': sha256,
      if (durationMs != null) 'duration_ms': durationMs,
      if (senderX != null) 'sender_x': senderX,
      if (conversationId != null) 'conversation_id': conversationId,
      if (started != null) 'started': started,
      if (timestamp != null) 'timestamp': timestamp,
      if (completed != null) 'completed': completed,
      if (rowid != null) 'rowid': rowid,
    });
  }

  TransfersCompanion copyWith({
    Value<String>? transferId,
    Value<String>? blobId,
    Value<String>? kind,
    Value<String>? mime,
    Value<int>? byteCount,
    Value<int>? chunkSize,
    Value<int>? chunkCount,
    Value<String>? sha256,
    Value<int>? durationMs,
    Value<String>? senderX,
    Value<String>? conversationId,
    Value<int>? started,
    Value<int>? timestamp,
    Value<int>? completed,
    Value<int>? rowid,
  }) {
    return TransfersCompanion(
      transferId: transferId ?? this.transferId,
      blobId: blobId ?? this.blobId,
      kind: kind ?? this.kind,
      mime: mime ?? this.mime,
      byteCount: byteCount ?? this.byteCount,
      chunkSize: chunkSize ?? this.chunkSize,
      chunkCount: chunkCount ?? this.chunkCount,
      sha256: sha256 ?? this.sha256,
      durationMs: durationMs ?? this.durationMs,
      senderX: senderX ?? this.senderX,
      conversationId: conversationId ?? this.conversationId,
      started: started ?? this.started,
      timestamp: timestamp ?? this.timestamp,
      completed: completed ?? this.completed,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (transferId.present) {
      map['transfer_id'] = Variable<String>(transferId.value);
    }
    if (blobId.present) {
      map['blob_id'] = Variable<String>(blobId.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (mime.present) {
      map['mime'] = Variable<String>(mime.value);
    }
    if (byteCount.present) {
      map['byte_count'] = Variable<int>(byteCount.value);
    }
    if (chunkSize.present) {
      map['chunk_size'] = Variable<int>(chunkSize.value);
    }
    if (chunkCount.present) {
      map['chunk_count'] = Variable<int>(chunkCount.value);
    }
    if (sha256.present) {
      map['sha256'] = Variable<String>(sha256.value);
    }
    if (durationMs.present) {
      map['duration_ms'] = Variable<int>(durationMs.value);
    }
    if (senderX.present) {
      map['sender_x'] = Variable<String>(senderX.value);
    }
    if (conversationId.present) {
      map['conversation_id'] = Variable<String>(conversationId.value);
    }
    if (started.present) {
      map['started'] = Variable<int>(started.value);
    }
    if (timestamp.present) {
      map['timestamp'] = Variable<int>(timestamp.value);
    }
    if (completed.present) {
      map['completed'] = Variable<int>(completed.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TransfersCompanion(')
          ..write('transferId: $transferId, ')
          ..write('blobId: $blobId, ')
          ..write('kind: $kind, ')
          ..write('mime: $mime, ')
          ..write('byteCount: $byteCount, ')
          ..write('chunkSize: $chunkSize, ')
          ..write('chunkCount: $chunkCount, ')
          ..write('sha256: $sha256, ')
          ..write('durationMs: $durationMs, ')
          ..write('senderX: $senderX, ')
          ..write('conversationId: $conversationId, ')
          ..write('started: $started, ')
          ..write('timestamp: $timestamp, ')
          ..write('completed: $completed, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $TransferPartsTable extends TransferParts
    with TableInfo<$TransferPartsTable, TransferPart> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TransferPartsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _transferIdMeta = const VerificationMeta(
    'transferId',
  );
  @override
  late final GeneratedColumn<String> transferId = GeneratedColumn<String>(
    'transfer_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _indexMeta = const VerificationMeta('index');
  @override
  late final GeneratedColumn<int> index = GeneratedColumn<int>(
    'index',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _byteCountMeta = const VerificationMeta(
    'byteCount',
  );
  @override
  late final GeneratedColumn<int> byteCount = GeneratedColumn<int>(
    'byte_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _dataMeta = const VerificationMeta('data');
  @override
  late final GeneratedColumn<String> data = GeneratedColumn<String>(
    'data',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _pathMeta = const VerificationMeta('path');
  @override
  late final GeneratedColumn<String> path = GeneratedColumn<String>(
    'path',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  @override
  List<GeneratedColumn> get $columns => [
    transferId,
    index,
    byteCount,
    data,
    path,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'transfer_parts';
  @override
  VerificationContext validateIntegrity(
    Insertable<TransferPart> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('transfer_id')) {
      context.handle(
        _transferIdMeta,
        transferId.isAcceptableOrUnknown(data['transfer_id']!, _transferIdMeta),
      );
    } else if (isInserting) {
      context.missing(_transferIdMeta);
    }
    if (data.containsKey('index')) {
      context.handle(
        _indexMeta,
        index.isAcceptableOrUnknown(data['index']!, _indexMeta),
      );
    } else if (isInserting) {
      context.missing(_indexMeta);
    }
    if (data.containsKey('byte_count')) {
      context.handle(
        _byteCountMeta,
        byteCount.isAcceptableOrUnknown(data['byte_count']!, _byteCountMeta),
      );
    } else if (isInserting) {
      context.missing(_byteCountMeta);
    }
    if (data.containsKey('data')) {
      context.handle(
        _dataMeta,
        this.data.isAcceptableOrUnknown(data['data']!, _dataMeta),
      );
    }
    if (data.containsKey('path')) {
      context.handle(
        _pathMeta,
        path.isAcceptableOrUnknown(data['path']!, _pathMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {transferId, index};
  @override
  TransferPart map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TransferPart(
      transferId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}transfer_id'],
      )!,
      index: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}index'],
      )!,
      byteCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}byte_count'],
      )!,
      data: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}data'],
      )!,
      path: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}path'],
      )!,
    );
  }

  @override
  $TransferPartsTable createAlias(String alias) {
    return $TransferPartsTable(attachedDatabase, alias);
  }
}

class TransferPart extends DataClass implements Insertable<TransferPart> {
  final String transferId;
  final int index;
  final int byteCount;

  /// Legacy base64 slices from older builds; new slices are written to [path].
  final String data;

  /// Relative path of one received slice under the media directory.
  final String path;
  const TransferPart({
    required this.transferId,
    required this.index,
    required this.byteCount,
    required this.data,
    required this.path,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['transfer_id'] = Variable<String>(transferId);
    map['index'] = Variable<int>(index);
    map['byte_count'] = Variable<int>(byteCount);
    map['data'] = Variable<String>(data);
    map['path'] = Variable<String>(path);
    return map;
  }

  TransferPartsCompanion toCompanion(bool nullToAbsent) {
    return TransferPartsCompanion(
      transferId: Value(transferId),
      index: Value(index),
      byteCount: Value(byteCount),
      data: Value(data),
      path: Value(path),
    );
  }

  factory TransferPart.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TransferPart(
      transferId: serializer.fromJson<String>(json['transferId']),
      index: serializer.fromJson<int>(json['index']),
      byteCount: serializer.fromJson<int>(json['byteCount']),
      data: serializer.fromJson<String>(json['data']),
      path: serializer.fromJson<String>(json['path']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'transferId': serializer.toJson<String>(transferId),
      'index': serializer.toJson<int>(index),
      'byteCount': serializer.toJson<int>(byteCount),
      'data': serializer.toJson<String>(data),
      'path': serializer.toJson<String>(path),
    };
  }

  TransferPart copyWith({
    String? transferId,
    int? index,
    int? byteCount,
    String? data,
    String? path,
  }) => TransferPart(
    transferId: transferId ?? this.transferId,
    index: index ?? this.index,
    byteCount: byteCount ?? this.byteCount,
    data: data ?? this.data,
    path: path ?? this.path,
  );
  TransferPart copyWithCompanion(TransferPartsCompanion data) {
    return TransferPart(
      transferId: data.transferId.present
          ? data.transferId.value
          : this.transferId,
      index: data.index.present ? data.index.value : this.index,
      byteCount: data.byteCount.present ? data.byteCount.value : this.byteCount,
      data: data.data.present ? data.data.value : this.data,
      path: data.path.present ? data.path.value : this.path,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TransferPart(')
          ..write('transferId: $transferId, ')
          ..write('index: $index, ')
          ..write('byteCount: $byteCount, ')
          ..write('data: $data, ')
          ..write('path: $path')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(transferId, index, byteCount, data, path);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TransferPart &&
          other.transferId == this.transferId &&
          other.index == this.index &&
          other.byteCount == this.byteCount &&
          other.data == this.data &&
          other.path == this.path);
}

class TransferPartsCompanion extends UpdateCompanion<TransferPart> {
  final Value<String> transferId;
  final Value<int> index;
  final Value<int> byteCount;
  final Value<String> data;
  final Value<String> path;
  final Value<int> rowid;
  const TransferPartsCompanion({
    this.transferId = const Value.absent(),
    this.index = const Value.absent(),
    this.byteCount = const Value.absent(),
    this.data = const Value.absent(),
    this.path = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  TransferPartsCompanion.insert({
    required String transferId,
    required int index,
    required int byteCount,
    this.data = const Value.absent(),
    this.path = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : transferId = Value(transferId),
       index = Value(index),
       byteCount = Value(byteCount);
  static Insertable<TransferPart> custom({
    Expression<String>? transferId,
    Expression<int>? index,
    Expression<int>? byteCount,
    Expression<String>? data,
    Expression<String>? path,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (transferId != null) 'transfer_id': transferId,
      if (index != null) 'index': index,
      if (byteCount != null) 'byte_count': byteCount,
      if (data != null) 'data': data,
      if (path != null) 'path': path,
      if (rowid != null) 'rowid': rowid,
    });
  }

  TransferPartsCompanion copyWith({
    Value<String>? transferId,
    Value<int>? index,
    Value<int>? byteCount,
    Value<String>? data,
    Value<String>? path,
    Value<int>? rowid,
  }) {
    return TransferPartsCompanion(
      transferId: transferId ?? this.transferId,
      index: index ?? this.index,
      byteCount: byteCount ?? this.byteCount,
      data: data ?? this.data,
      path: path ?? this.path,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (transferId.present) {
      map['transfer_id'] = Variable<String>(transferId.value);
    }
    if (index.present) {
      map['index'] = Variable<int>(index.value);
    }
    if (byteCount.present) {
      map['byte_count'] = Variable<int>(byteCount.value);
    }
    if (data.present) {
      map['data'] = Variable<String>(data.value);
    }
    if (path.present) {
      map['path'] = Variable<String>(path.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TransferPartsCompanion(')
          ..write('transferId: $transferId, ')
          ..write('index: $index, ')
          ..write('byteCount: $byteCount, ')
          ..write('data: $data, ')
          ..write('path: $path, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $MessagesTable messages = $MessagesTable(this);
  late final $PrunedRootsTable prunedRoots = $PrunedRootsTable(this);
  late final $IdentityEntryTable identityEntry = $IdentityEntryTable(this);
  late final $AppSettingsTable appSettings = $AppSettingsTable(this);
  late final $ConversationHeadsTable conversationHeads =
      $ConversationHeadsTable(this);
  late final $PeersTable peers = $PeersTable(this);
  late final $ConversationsTable conversations = $ConversationsTable(this);
  late final $ConversationMembersTable conversationMembers =
      $ConversationMembersTable(this);
  late final $OutgoingBodiesTable outgoingBodies = $OutgoingBodiesTable(this);
  late final $MessageStatusesTable messageStatuses = $MessageStatusesTable(
    this,
  );
  late final $MediaBlobsTable mediaBlobs = $MediaBlobsTable(this);
  late final $TransfersTable transfers = $TransfersTable(this);
  late final $TransferPartsTable transferParts = $TransferPartsTable(this);
  late final Index idxMessagesRecipientTs = Index(
    'idx_messages_recipient_ts',
    'CREATE INDEX idx_messages_recipient_ts ON messages (recipient_pub_key, timestamp)',
  );
  late final Index idxMessagesSenderTs = Index(
    'idx_messages_sender_ts',
    'CREATE INDEX idx_messages_sender_ts ON messages (sender_pub_key, timestamp)',
  );
  late final Index idxMessagesGroupTs = Index(
    'idx_messages_group_ts',
    'CREATE INDEX idx_messages_group_ts ON messages (group_id, timestamp)',
  );
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    messages,
    prunedRoots,
    identityEntry,
    appSettings,
    conversationHeads,
    peers,
    conversations,
    conversationMembers,
    outgoingBodies,
    messageStatuses,
    mediaBlobs,
    transfers,
    transferParts,
    idxMessagesRecipientTs,
    idxMessagesSenderTs,
    idxMessagesGroupTs,
  ];
}

typedef $$MessagesTableCreateCompanionBuilder =
    MessagesCompanion Function({
      required String id,
      required String senderPubKey,
      required String recipientPubKey,
      required int timestamp,
      required String ciphertext,
      required String ephemeralPubKey,
      required String signature,
      required String source,
      Value<int> hops,
      Value<String> chainLink,
      Value<int> forked,
      Value<int> control,
      Value<int> groupPayload,
      Value<String?> groupId,
      Value<int> directOnly,
      Value<int> rowid,
    });
typedef $$MessagesTableUpdateCompanionBuilder =
    MessagesCompanion Function({
      Value<String> id,
      Value<String> senderPubKey,
      Value<String> recipientPubKey,
      Value<int> timestamp,
      Value<String> ciphertext,
      Value<String> ephemeralPubKey,
      Value<String> signature,
      Value<String> source,
      Value<int> hops,
      Value<String> chainLink,
      Value<int> forked,
      Value<int> control,
      Value<int> groupPayload,
      Value<String?> groupId,
      Value<int> directOnly,
      Value<int> rowid,
    });

class $$MessagesTableFilterComposer
    extends Composer<_$AppDatabase, $MessagesTable> {
  $$MessagesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get senderPubKey => $composableBuilder(
    column: $table.senderPubKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get recipientPubKey => $composableBuilder(
    column: $table.recipientPubKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get timestamp => $composableBuilder(
    column: $table.timestamp,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get ciphertext => $composableBuilder(
    column: $table.ciphertext,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get ephemeralPubKey => $composableBuilder(
    column: $table.ephemeralPubKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get signature => $composableBuilder(
    column: $table.signature,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get hops => $composableBuilder(
    column: $table.hops,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get chainLink => $composableBuilder(
    column: $table.chainLink,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get forked => $composableBuilder(
    column: $table.forked,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get control => $composableBuilder(
    column: $table.control,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get groupPayload => $composableBuilder(
    column: $table.groupPayload,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get groupId => $composableBuilder(
    column: $table.groupId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get directOnly => $composableBuilder(
    column: $table.directOnly,
    builder: (column) => ColumnFilters(column),
  );
}

class $$MessagesTableOrderingComposer
    extends Composer<_$AppDatabase, $MessagesTable> {
  $$MessagesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get senderPubKey => $composableBuilder(
    column: $table.senderPubKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get recipientPubKey => $composableBuilder(
    column: $table.recipientPubKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get timestamp => $composableBuilder(
    column: $table.timestamp,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get ciphertext => $composableBuilder(
    column: $table.ciphertext,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get ephemeralPubKey => $composableBuilder(
    column: $table.ephemeralPubKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get signature => $composableBuilder(
    column: $table.signature,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get hops => $composableBuilder(
    column: $table.hops,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get chainLink => $composableBuilder(
    column: $table.chainLink,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get forked => $composableBuilder(
    column: $table.forked,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get control => $composableBuilder(
    column: $table.control,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get groupPayload => $composableBuilder(
    column: $table.groupPayload,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get groupId => $composableBuilder(
    column: $table.groupId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get directOnly => $composableBuilder(
    column: $table.directOnly,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$MessagesTableAnnotationComposer
    extends Composer<_$AppDatabase, $MessagesTable> {
  $$MessagesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get senderPubKey => $composableBuilder(
    column: $table.senderPubKey,
    builder: (column) => column,
  );

  GeneratedColumn<String> get recipientPubKey => $composableBuilder(
    column: $table.recipientPubKey,
    builder: (column) => column,
  );

  GeneratedColumn<int> get timestamp =>
      $composableBuilder(column: $table.timestamp, builder: (column) => column);

  GeneratedColumn<String> get ciphertext => $composableBuilder(
    column: $table.ciphertext,
    builder: (column) => column,
  );

  GeneratedColumn<String> get ephemeralPubKey => $composableBuilder(
    column: $table.ephemeralPubKey,
    builder: (column) => column,
  );

  GeneratedColumn<String> get signature =>
      $composableBuilder(column: $table.signature, builder: (column) => column);

  GeneratedColumn<String> get source =>
      $composableBuilder(column: $table.source, builder: (column) => column);

  GeneratedColumn<int> get hops =>
      $composableBuilder(column: $table.hops, builder: (column) => column);

  GeneratedColumn<String> get chainLink =>
      $composableBuilder(column: $table.chainLink, builder: (column) => column);

  GeneratedColumn<int> get forked =>
      $composableBuilder(column: $table.forked, builder: (column) => column);

  GeneratedColumn<int> get control =>
      $composableBuilder(column: $table.control, builder: (column) => column);

  GeneratedColumn<int> get groupPayload => $composableBuilder(
    column: $table.groupPayload,
    builder: (column) => column,
  );

  GeneratedColumn<String> get groupId =>
      $composableBuilder(column: $table.groupId, builder: (column) => column);

  GeneratedColumn<int> get directOnly => $composableBuilder(
    column: $table.directOnly,
    builder: (column) => column,
  );
}

class $$MessagesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $MessagesTable,
          Message,
          $$MessagesTableFilterComposer,
          $$MessagesTableOrderingComposer,
          $$MessagesTableAnnotationComposer,
          $$MessagesTableCreateCompanionBuilder,
          $$MessagesTableUpdateCompanionBuilder,
          (Message, BaseReferences<_$AppDatabase, $MessagesTable, Message>),
          Message,
          PrefetchHooks Function()
        > {
  $$MessagesTableTableManager(_$AppDatabase db, $MessagesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MessagesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MessagesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$MessagesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> senderPubKey = const Value.absent(),
                Value<String> recipientPubKey = const Value.absent(),
                Value<int> timestamp = const Value.absent(),
                Value<String> ciphertext = const Value.absent(),
                Value<String> ephemeralPubKey = const Value.absent(),
                Value<String> signature = const Value.absent(),
                Value<String> source = const Value.absent(),
                Value<int> hops = const Value.absent(),
                Value<String> chainLink = const Value.absent(),
                Value<int> forked = const Value.absent(),
                Value<int> control = const Value.absent(),
                Value<int> groupPayload = const Value.absent(),
                Value<String?> groupId = const Value.absent(),
                Value<int> directOnly = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => MessagesCompanion(
                id: id,
                senderPubKey: senderPubKey,
                recipientPubKey: recipientPubKey,
                timestamp: timestamp,
                ciphertext: ciphertext,
                ephemeralPubKey: ephemeralPubKey,
                signature: signature,
                source: source,
                hops: hops,
                chainLink: chainLink,
                forked: forked,
                control: control,
                groupPayload: groupPayload,
                groupId: groupId,
                directOnly: directOnly,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String senderPubKey,
                required String recipientPubKey,
                required int timestamp,
                required String ciphertext,
                required String ephemeralPubKey,
                required String signature,
                required String source,
                Value<int> hops = const Value.absent(),
                Value<String> chainLink = const Value.absent(),
                Value<int> forked = const Value.absent(),
                Value<int> control = const Value.absent(),
                Value<int> groupPayload = const Value.absent(),
                Value<String?> groupId = const Value.absent(),
                Value<int> directOnly = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => MessagesCompanion.insert(
                id: id,
                senderPubKey: senderPubKey,
                recipientPubKey: recipientPubKey,
                timestamp: timestamp,
                ciphertext: ciphertext,
                ephemeralPubKey: ephemeralPubKey,
                signature: signature,
                source: source,
                hops: hops,
                chainLink: chainLink,
                forked: forked,
                control: control,
                groupPayload: groupPayload,
                groupId: groupId,
                directOnly: directOnly,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$MessagesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $MessagesTable,
      Message,
      $$MessagesTableFilterComposer,
      $$MessagesTableOrderingComposer,
      $$MessagesTableAnnotationComposer,
      $$MessagesTableCreateCompanionBuilder,
      $$MessagesTableUpdateCompanionBuilder,
      (Message, BaseReferences<_$AppDatabase, $MessagesTable, Message>),
      Message,
      PrefetchHooks Function()
    >;
typedef $$PrunedRootsTableCreateCompanionBuilder =
    PrunedRootsCompanion Function({
      Value<int> id,
      required int cutoffTs,
      required String merkleRoot,
      required int count,
      required String devicePubKey,
      required String signature,
    });
typedef $$PrunedRootsTableUpdateCompanionBuilder =
    PrunedRootsCompanion Function({
      Value<int> id,
      Value<int> cutoffTs,
      Value<String> merkleRoot,
      Value<int> count,
      Value<String> devicePubKey,
      Value<String> signature,
    });

class $$PrunedRootsTableFilterComposer
    extends Composer<_$AppDatabase, $PrunedRootsTable> {
  $$PrunedRootsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get cutoffTs => $composableBuilder(
    column: $table.cutoffTs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get merkleRoot => $composableBuilder(
    column: $table.merkleRoot,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get count => $composableBuilder(
    column: $table.count,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get devicePubKey => $composableBuilder(
    column: $table.devicePubKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get signature => $composableBuilder(
    column: $table.signature,
    builder: (column) => ColumnFilters(column),
  );
}

class $$PrunedRootsTableOrderingComposer
    extends Composer<_$AppDatabase, $PrunedRootsTable> {
  $$PrunedRootsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get cutoffTs => $composableBuilder(
    column: $table.cutoffTs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get merkleRoot => $composableBuilder(
    column: $table.merkleRoot,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get count => $composableBuilder(
    column: $table.count,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get devicePubKey => $composableBuilder(
    column: $table.devicePubKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get signature => $composableBuilder(
    column: $table.signature,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$PrunedRootsTableAnnotationComposer
    extends Composer<_$AppDatabase, $PrunedRootsTable> {
  $$PrunedRootsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get cutoffTs =>
      $composableBuilder(column: $table.cutoffTs, builder: (column) => column);

  GeneratedColumn<String> get merkleRoot => $composableBuilder(
    column: $table.merkleRoot,
    builder: (column) => column,
  );

  GeneratedColumn<int> get count =>
      $composableBuilder(column: $table.count, builder: (column) => column);

  GeneratedColumn<String> get devicePubKey => $composableBuilder(
    column: $table.devicePubKey,
    builder: (column) => column,
  );

  GeneratedColumn<String> get signature =>
      $composableBuilder(column: $table.signature, builder: (column) => column);
}

class $$PrunedRootsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PrunedRootsTable,
          PrunedRoot,
          $$PrunedRootsTableFilterComposer,
          $$PrunedRootsTableOrderingComposer,
          $$PrunedRootsTableAnnotationComposer,
          $$PrunedRootsTableCreateCompanionBuilder,
          $$PrunedRootsTableUpdateCompanionBuilder,
          (
            PrunedRoot,
            BaseReferences<_$AppDatabase, $PrunedRootsTable, PrunedRoot>,
          ),
          PrunedRoot,
          PrefetchHooks Function()
        > {
  $$PrunedRootsTableTableManager(_$AppDatabase db, $PrunedRootsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PrunedRootsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PrunedRootsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PrunedRootsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> cutoffTs = const Value.absent(),
                Value<String> merkleRoot = const Value.absent(),
                Value<int> count = const Value.absent(),
                Value<String> devicePubKey = const Value.absent(),
                Value<String> signature = const Value.absent(),
              }) => PrunedRootsCompanion(
                id: id,
                cutoffTs: cutoffTs,
                merkleRoot: merkleRoot,
                count: count,
                devicePubKey: devicePubKey,
                signature: signature,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int cutoffTs,
                required String merkleRoot,
                required int count,
                required String devicePubKey,
                required String signature,
              }) => PrunedRootsCompanion.insert(
                id: id,
                cutoffTs: cutoffTs,
                merkleRoot: merkleRoot,
                count: count,
                devicePubKey: devicePubKey,
                signature: signature,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$PrunedRootsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PrunedRootsTable,
      PrunedRoot,
      $$PrunedRootsTableFilterComposer,
      $$PrunedRootsTableOrderingComposer,
      $$PrunedRootsTableAnnotationComposer,
      $$PrunedRootsTableCreateCompanionBuilder,
      $$PrunedRootsTableUpdateCompanionBuilder,
      (
        PrunedRoot,
        BaseReferences<_$AppDatabase, $PrunedRootsTable, PrunedRoot>,
      ),
      PrunedRoot,
      PrefetchHooks Function()
    >;
typedef $$IdentityEntryTableCreateCompanionBuilder =
    IdentityEntryCompanion Function({
      Value<String> key,
      required String edSeedHex,
      required String xSeedHex,
      Value<String> displayName,
      required int createdAt,
      Value<int> rowid,
    });
typedef $$IdentityEntryTableUpdateCompanionBuilder =
    IdentityEntryCompanion Function({
      Value<String> key,
      Value<String> edSeedHex,
      Value<String> xSeedHex,
      Value<String> displayName,
      Value<int> createdAt,
      Value<int> rowid,
    });

class $$IdentityEntryTableFilterComposer
    extends Composer<_$AppDatabase, $IdentityEntryTable> {
  $$IdentityEntryTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get edSeedHex => $composableBuilder(
    column: $table.edSeedHex,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get xSeedHex => $composableBuilder(
    column: $table.xSeedHex,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$IdentityEntryTableOrderingComposer
    extends Composer<_$AppDatabase, $IdentityEntryTable> {
  $$IdentityEntryTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get edSeedHex => $composableBuilder(
    column: $table.edSeedHex,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get xSeedHex => $composableBuilder(
    column: $table.xSeedHex,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$IdentityEntryTableAnnotationComposer
    extends Composer<_$AppDatabase, $IdentityEntryTable> {
  $$IdentityEntryTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get edSeedHex =>
      $composableBuilder(column: $table.edSeedHex, builder: (column) => column);

  GeneratedColumn<String> get xSeedHex =>
      $composableBuilder(column: $table.xSeedHex, builder: (column) => column);

  GeneratedColumn<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => column,
  );

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$IdentityEntryTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $IdentityEntryTable,
          IdentityEntryData,
          $$IdentityEntryTableFilterComposer,
          $$IdentityEntryTableOrderingComposer,
          $$IdentityEntryTableAnnotationComposer,
          $$IdentityEntryTableCreateCompanionBuilder,
          $$IdentityEntryTableUpdateCompanionBuilder,
          (
            IdentityEntryData,
            BaseReferences<
              _$AppDatabase,
              $IdentityEntryTable,
              IdentityEntryData
            >,
          ),
          IdentityEntryData,
          PrefetchHooks Function()
        > {
  $$IdentityEntryTableTableManager(_$AppDatabase db, $IdentityEntryTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$IdentityEntryTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$IdentityEntryTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$IdentityEntryTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> key = const Value.absent(),
                Value<String> edSeedHex = const Value.absent(),
                Value<String> xSeedHex = const Value.absent(),
                Value<String> displayName = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => IdentityEntryCompanion(
                key: key,
                edSeedHex: edSeedHex,
                xSeedHex: xSeedHex,
                displayName: displayName,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                Value<String> key = const Value.absent(),
                required String edSeedHex,
                required String xSeedHex,
                Value<String> displayName = const Value.absent(),
                required int createdAt,
                Value<int> rowid = const Value.absent(),
              }) => IdentityEntryCompanion.insert(
                key: key,
                edSeedHex: edSeedHex,
                xSeedHex: xSeedHex,
                displayName: displayName,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$IdentityEntryTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $IdentityEntryTable,
      IdentityEntryData,
      $$IdentityEntryTableFilterComposer,
      $$IdentityEntryTableOrderingComposer,
      $$IdentityEntryTableAnnotationComposer,
      $$IdentityEntryTableCreateCompanionBuilder,
      $$IdentityEntryTableUpdateCompanionBuilder,
      (
        IdentityEntryData,
        BaseReferences<_$AppDatabase, $IdentityEntryTable, IdentityEntryData>,
      ),
      IdentityEntryData,
      PrefetchHooks Function()
    >;
typedef $$AppSettingsTableCreateCompanionBuilder =
    AppSettingsCompanion Function({
      required String key,
      required String value,
      Value<int> rowid,
    });
typedef $$AppSettingsTableUpdateCompanionBuilder =
    AppSettingsCompanion Function({
      Value<String> key,
      Value<String> value,
      Value<int> rowid,
    });

class $$AppSettingsTableFilterComposer
    extends Composer<_$AppDatabase, $AppSettingsTable> {
  $$AppSettingsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnFilters(column),
  );
}

class $$AppSettingsTableOrderingComposer
    extends Composer<_$AppDatabase, $AppSettingsTable> {
  $$AppSettingsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$AppSettingsTableAnnotationComposer
    extends Composer<_$AppDatabase, $AppSettingsTable> {
  $$AppSettingsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);
}

class $$AppSettingsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $AppSettingsTable,
          AppSetting,
          $$AppSettingsTableFilterComposer,
          $$AppSettingsTableOrderingComposer,
          $$AppSettingsTableAnnotationComposer,
          $$AppSettingsTableCreateCompanionBuilder,
          $$AppSettingsTableUpdateCompanionBuilder,
          (
            AppSetting,
            BaseReferences<_$AppDatabase, $AppSettingsTable, AppSetting>,
          ),
          AppSetting,
          PrefetchHooks Function()
        > {
  $$AppSettingsTableTableManager(_$AppDatabase db, $AppSettingsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AppSettingsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AppSettingsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AppSettingsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> key = const Value.absent(),
                Value<String> value = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AppSettingsCompanion(key: key, value: value, rowid: rowid),
          createCompanionCallback:
              ({
                required String key,
                required String value,
                Value<int> rowid = const Value.absent(),
              }) => AppSettingsCompanion.insert(
                key: key,
                value: value,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$AppSettingsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $AppSettingsTable,
      AppSetting,
      $$AppSettingsTableFilterComposer,
      $$AppSettingsTableOrderingComposer,
      $$AppSettingsTableAnnotationComposer,
      $$AppSettingsTableCreateCompanionBuilder,
      $$AppSettingsTableUpdateCompanionBuilder,
      (
        AppSetting,
        BaseReferences<_$AppDatabase, $AppSettingsTable, AppSetting>,
      ),
      AppSetting,
      PrefetchHooks Function()
    >;
typedef $$ConversationHeadsTableCreateCompanionBuilder =
    ConversationHeadsCompanion Function({
      required String linkKey,
      required String headId,
      Value<int> count,
      Value<int> lastTs,
      Value<int> rowid,
    });
typedef $$ConversationHeadsTableUpdateCompanionBuilder =
    ConversationHeadsCompanion Function({
      Value<String> linkKey,
      Value<String> headId,
      Value<int> count,
      Value<int> lastTs,
      Value<int> rowid,
    });

class $$ConversationHeadsTableFilterComposer
    extends Composer<_$AppDatabase, $ConversationHeadsTable> {
  $$ConversationHeadsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get linkKey => $composableBuilder(
    column: $table.linkKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get headId => $composableBuilder(
    column: $table.headId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get count => $composableBuilder(
    column: $table.count,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lastTs => $composableBuilder(
    column: $table.lastTs,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ConversationHeadsTableOrderingComposer
    extends Composer<_$AppDatabase, $ConversationHeadsTable> {
  $$ConversationHeadsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get linkKey => $composableBuilder(
    column: $table.linkKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get headId => $composableBuilder(
    column: $table.headId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get count => $composableBuilder(
    column: $table.count,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lastTs => $composableBuilder(
    column: $table.lastTs,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ConversationHeadsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ConversationHeadsTable> {
  $$ConversationHeadsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get linkKey =>
      $composableBuilder(column: $table.linkKey, builder: (column) => column);

  GeneratedColumn<String> get headId =>
      $composableBuilder(column: $table.headId, builder: (column) => column);

  GeneratedColumn<int> get count =>
      $composableBuilder(column: $table.count, builder: (column) => column);

  GeneratedColumn<int> get lastTs =>
      $composableBuilder(column: $table.lastTs, builder: (column) => column);
}

class $$ConversationHeadsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ConversationHeadsTable,
          ConversationHead,
          $$ConversationHeadsTableFilterComposer,
          $$ConversationHeadsTableOrderingComposer,
          $$ConversationHeadsTableAnnotationComposer,
          $$ConversationHeadsTableCreateCompanionBuilder,
          $$ConversationHeadsTableUpdateCompanionBuilder,
          (
            ConversationHead,
            BaseReferences<
              _$AppDatabase,
              $ConversationHeadsTable,
              ConversationHead
            >,
          ),
          ConversationHead,
          PrefetchHooks Function()
        > {
  $$ConversationHeadsTableTableManager(
    _$AppDatabase db,
    $ConversationHeadsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ConversationHeadsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ConversationHeadsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ConversationHeadsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> linkKey = const Value.absent(),
                Value<String> headId = const Value.absent(),
                Value<int> count = const Value.absent(),
                Value<int> lastTs = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ConversationHeadsCompanion(
                linkKey: linkKey,
                headId: headId,
                count: count,
                lastTs: lastTs,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String linkKey,
                required String headId,
                Value<int> count = const Value.absent(),
                Value<int> lastTs = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ConversationHeadsCompanion.insert(
                linkKey: linkKey,
                headId: headId,
                count: count,
                lastTs: lastTs,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ConversationHeadsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ConversationHeadsTable,
      ConversationHead,
      $$ConversationHeadsTableFilterComposer,
      $$ConversationHeadsTableOrderingComposer,
      $$ConversationHeadsTableAnnotationComposer,
      $$ConversationHeadsTableCreateCompanionBuilder,
      $$ConversationHeadsTableUpdateCompanionBuilder,
      (
        ConversationHead,
        BaseReferences<
          _$AppDatabase,
          $ConversationHeadsTable,
          ConversationHead
        >,
      ),
      ConversationHead,
      PrefetchHooks Function()
    >;
typedef $$PeersTableCreateCompanionBuilder =
    PeersCompanion Function({
      required String pubKey,
      Value<String?> edPubKey,
      Value<String> displayName,
      Value<String?> peerId,
      Value<String> addrsJson,
      Value<int> lastSeen,
      Value<bool> isContact,
      Value<String?> verifiedEdPubKey,
      Value<int?> verifiedAt,
      Value<bool> blocked,
      Value<int> rowid,
    });
typedef $$PeersTableUpdateCompanionBuilder =
    PeersCompanion Function({
      Value<String> pubKey,
      Value<String?> edPubKey,
      Value<String> displayName,
      Value<String?> peerId,
      Value<String> addrsJson,
      Value<int> lastSeen,
      Value<bool> isContact,
      Value<String?> verifiedEdPubKey,
      Value<int?> verifiedAt,
      Value<bool> blocked,
      Value<int> rowid,
    });

class $$PeersTableFilterComposer extends Composer<_$AppDatabase, $PeersTable> {
  $$PeersTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get pubKey => $composableBuilder(
    column: $table.pubKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get edPubKey => $composableBuilder(
    column: $table.edPubKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get peerId => $composableBuilder(
    column: $table.peerId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get addrsJson => $composableBuilder(
    column: $table.addrsJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lastSeen => $composableBuilder(
    column: $table.lastSeen,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isContact => $composableBuilder(
    column: $table.isContact,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get verifiedEdPubKey => $composableBuilder(
    column: $table.verifiedEdPubKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get verifiedAt => $composableBuilder(
    column: $table.verifiedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get blocked => $composableBuilder(
    column: $table.blocked,
    builder: (column) => ColumnFilters(column),
  );
}

class $$PeersTableOrderingComposer
    extends Composer<_$AppDatabase, $PeersTable> {
  $$PeersTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get pubKey => $composableBuilder(
    column: $table.pubKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get edPubKey => $composableBuilder(
    column: $table.edPubKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get peerId => $composableBuilder(
    column: $table.peerId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get addrsJson => $composableBuilder(
    column: $table.addrsJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lastSeen => $composableBuilder(
    column: $table.lastSeen,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isContact => $composableBuilder(
    column: $table.isContact,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get verifiedEdPubKey => $composableBuilder(
    column: $table.verifiedEdPubKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get verifiedAt => $composableBuilder(
    column: $table.verifiedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get blocked => $composableBuilder(
    column: $table.blocked,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$PeersTableAnnotationComposer
    extends Composer<_$AppDatabase, $PeersTable> {
  $$PeersTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get pubKey =>
      $composableBuilder(column: $table.pubKey, builder: (column) => column);

  GeneratedColumn<String> get edPubKey =>
      $composableBuilder(column: $table.edPubKey, builder: (column) => column);

  GeneratedColumn<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get peerId =>
      $composableBuilder(column: $table.peerId, builder: (column) => column);

  GeneratedColumn<String> get addrsJson =>
      $composableBuilder(column: $table.addrsJson, builder: (column) => column);

  GeneratedColumn<int> get lastSeen =>
      $composableBuilder(column: $table.lastSeen, builder: (column) => column);

  GeneratedColumn<bool> get isContact =>
      $composableBuilder(column: $table.isContact, builder: (column) => column);

  GeneratedColumn<String> get verifiedEdPubKey => $composableBuilder(
    column: $table.verifiedEdPubKey,
    builder: (column) => column,
  );

  GeneratedColumn<int> get verifiedAt => $composableBuilder(
    column: $table.verifiedAt,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get blocked =>
      $composableBuilder(column: $table.blocked, builder: (column) => column);
}

class $$PeersTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PeersTable,
          Peer,
          $$PeersTableFilterComposer,
          $$PeersTableOrderingComposer,
          $$PeersTableAnnotationComposer,
          $$PeersTableCreateCompanionBuilder,
          $$PeersTableUpdateCompanionBuilder,
          (Peer, BaseReferences<_$AppDatabase, $PeersTable, Peer>),
          Peer,
          PrefetchHooks Function()
        > {
  $$PeersTableTableManager(_$AppDatabase db, $PeersTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PeersTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PeersTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PeersTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> pubKey = const Value.absent(),
                Value<String?> edPubKey = const Value.absent(),
                Value<String> displayName = const Value.absent(),
                Value<String?> peerId = const Value.absent(),
                Value<String> addrsJson = const Value.absent(),
                Value<int> lastSeen = const Value.absent(),
                Value<bool> isContact = const Value.absent(),
                Value<String?> verifiedEdPubKey = const Value.absent(),
                Value<int?> verifiedAt = const Value.absent(),
                Value<bool> blocked = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PeersCompanion(
                pubKey: pubKey,
                edPubKey: edPubKey,
                displayName: displayName,
                peerId: peerId,
                addrsJson: addrsJson,
                lastSeen: lastSeen,
                isContact: isContact,
                verifiedEdPubKey: verifiedEdPubKey,
                verifiedAt: verifiedAt,
                blocked: blocked,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String pubKey,
                Value<String?> edPubKey = const Value.absent(),
                Value<String> displayName = const Value.absent(),
                Value<String?> peerId = const Value.absent(),
                Value<String> addrsJson = const Value.absent(),
                Value<int> lastSeen = const Value.absent(),
                Value<bool> isContact = const Value.absent(),
                Value<String?> verifiedEdPubKey = const Value.absent(),
                Value<int?> verifiedAt = const Value.absent(),
                Value<bool> blocked = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PeersCompanion.insert(
                pubKey: pubKey,
                edPubKey: edPubKey,
                displayName: displayName,
                peerId: peerId,
                addrsJson: addrsJson,
                lastSeen: lastSeen,
                isContact: isContact,
                verifiedEdPubKey: verifiedEdPubKey,
                verifiedAt: verifiedAt,
                blocked: blocked,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$PeersTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PeersTable,
      Peer,
      $$PeersTableFilterComposer,
      $$PeersTableOrderingComposer,
      $$PeersTableAnnotationComposer,
      $$PeersTableCreateCompanionBuilder,
      $$PeersTableUpdateCompanionBuilder,
      (Peer, BaseReferences<_$AppDatabase, $PeersTable, Peer>),
      Peer,
      PrefetchHooks Function()
    >;
typedef $$ConversationsTableCreateCompanionBuilder =
    ConversationsCompanion Function({
      required String id,
      Value<String> kind,
      Value<String> title,
      Value<int> createdTs,
      Value<int> lastTs,
      Value<int> readAt,
      Value<int> rowid,
    });
typedef $$ConversationsTableUpdateCompanionBuilder =
    ConversationsCompanion Function({
      Value<String> id,
      Value<String> kind,
      Value<String> title,
      Value<int> createdTs,
      Value<int> lastTs,
      Value<int> readAt,
      Value<int> rowid,
    });

class $$ConversationsTableFilterComposer
    extends Composer<_$AppDatabase, $ConversationsTable> {
  $$ConversationsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdTs => $composableBuilder(
    column: $table.createdTs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lastTs => $composableBuilder(
    column: $table.lastTs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get readAt => $composableBuilder(
    column: $table.readAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ConversationsTableOrderingComposer
    extends Composer<_$AppDatabase, $ConversationsTable> {
  $$ConversationsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdTs => $composableBuilder(
    column: $table.createdTs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lastTs => $composableBuilder(
    column: $table.lastTs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get readAt => $composableBuilder(
    column: $table.readAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ConversationsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ConversationsTable> {
  $$ConversationsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<int> get createdTs =>
      $composableBuilder(column: $table.createdTs, builder: (column) => column);

  GeneratedColumn<int> get lastTs =>
      $composableBuilder(column: $table.lastTs, builder: (column) => column);

  GeneratedColumn<int> get readAt =>
      $composableBuilder(column: $table.readAt, builder: (column) => column);
}

class $$ConversationsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ConversationsTable,
          Conversation,
          $$ConversationsTableFilterComposer,
          $$ConversationsTableOrderingComposer,
          $$ConversationsTableAnnotationComposer,
          $$ConversationsTableCreateCompanionBuilder,
          $$ConversationsTableUpdateCompanionBuilder,
          (
            Conversation,
            BaseReferences<_$AppDatabase, $ConversationsTable, Conversation>,
          ),
          Conversation,
          PrefetchHooks Function()
        > {
  $$ConversationsTableTableManager(_$AppDatabase db, $ConversationsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ConversationsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ConversationsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ConversationsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> kind = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<int> createdTs = const Value.absent(),
                Value<int> lastTs = const Value.absent(),
                Value<int> readAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ConversationsCompanion(
                id: id,
                kind: kind,
                title: title,
                createdTs: createdTs,
                lastTs: lastTs,
                readAt: readAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                Value<String> kind = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<int> createdTs = const Value.absent(),
                Value<int> lastTs = const Value.absent(),
                Value<int> readAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ConversationsCompanion.insert(
                id: id,
                kind: kind,
                title: title,
                createdTs: createdTs,
                lastTs: lastTs,
                readAt: readAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ConversationsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ConversationsTable,
      Conversation,
      $$ConversationsTableFilterComposer,
      $$ConversationsTableOrderingComposer,
      $$ConversationsTableAnnotationComposer,
      $$ConversationsTableCreateCompanionBuilder,
      $$ConversationsTableUpdateCompanionBuilder,
      (
        Conversation,
        BaseReferences<_$AppDatabase, $ConversationsTable, Conversation>,
      ),
      Conversation,
      PrefetchHooks Function()
    >;
typedef $$ConversationMembersTableCreateCompanionBuilder =
    ConversationMembersCompanion Function({
      required String conversationId,
      required String peerXKey,
      Value<String> role,
      Value<int> rowid,
    });
typedef $$ConversationMembersTableUpdateCompanionBuilder =
    ConversationMembersCompanion Function({
      Value<String> conversationId,
      Value<String> peerXKey,
      Value<String> role,
      Value<int> rowid,
    });

class $$ConversationMembersTableFilterComposer
    extends Composer<_$AppDatabase, $ConversationMembersTable> {
  $$ConversationMembersTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get conversationId => $composableBuilder(
    column: $table.conversationId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get peerXKey => $composableBuilder(
    column: $table.peerXKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get role => $composableBuilder(
    column: $table.role,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ConversationMembersTableOrderingComposer
    extends Composer<_$AppDatabase, $ConversationMembersTable> {
  $$ConversationMembersTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get conversationId => $composableBuilder(
    column: $table.conversationId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get peerXKey => $composableBuilder(
    column: $table.peerXKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get role => $composableBuilder(
    column: $table.role,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ConversationMembersTableAnnotationComposer
    extends Composer<_$AppDatabase, $ConversationMembersTable> {
  $$ConversationMembersTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get conversationId => $composableBuilder(
    column: $table.conversationId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get peerXKey =>
      $composableBuilder(column: $table.peerXKey, builder: (column) => column);

  GeneratedColumn<String> get role =>
      $composableBuilder(column: $table.role, builder: (column) => column);
}

class $$ConversationMembersTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ConversationMembersTable,
          ConversationMember,
          $$ConversationMembersTableFilterComposer,
          $$ConversationMembersTableOrderingComposer,
          $$ConversationMembersTableAnnotationComposer,
          $$ConversationMembersTableCreateCompanionBuilder,
          $$ConversationMembersTableUpdateCompanionBuilder,
          (
            ConversationMember,
            BaseReferences<
              _$AppDatabase,
              $ConversationMembersTable,
              ConversationMember
            >,
          ),
          ConversationMember,
          PrefetchHooks Function()
        > {
  $$ConversationMembersTableTableManager(
    _$AppDatabase db,
    $ConversationMembersTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ConversationMembersTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ConversationMembersTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$ConversationMembersTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> conversationId = const Value.absent(),
                Value<String> peerXKey = const Value.absent(),
                Value<String> role = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ConversationMembersCompanion(
                conversationId: conversationId,
                peerXKey: peerXKey,
                role: role,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String conversationId,
                required String peerXKey,
                Value<String> role = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ConversationMembersCompanion.insert(
                conversationId: conversationId,
                peerXKey: peerXKey,
                role: role,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ConversationMembersTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ConversationMembersTable,
      ConversationMember,
      $$ConversationMembersTableFilterComposer,
      $$ConversationMembersTableOrderingComposer,
      $$ConversationMembersTableAnnotationComposer,
      $$ConversationMembersTableCreateCompanionBuilder,
      $$ConversationMembersTableUpdateCompanionBuilder,
      (
        ConversationMember,
        BaseReferences<
          _$AppDatabase,
          $ConversationMembersTable,
          ConversationMember
        >,
      ),
      ConversationMember,
      PrefetchHooks Function()
    >;
typedef $$OutgoingBodiesTableCreateCompanionBuilder =
    OutgoingBodiesCompanion Function({
      required String id,
      required String plaintext,
      required int timestamp,
      Value<int> rowid,
    });
typedef $$OutgoingBodiesTableUpdateCompanionBuilder =
    OutgoingBodiesCompanion Function({
      Value<String> id,
      Value<String> plaintext,
      Value<int> timestamp,
      Value<int> rowid,
    });

class $$OutgoingBodiesTableFilterComposer
    extends Composer<_$AppDatabase, $OutgoingBodiesTable> {
  $$OutgoingBodiesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get plaintext => $composableBuilder(
    column: $table.plaintext,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get timestamp => $composableBuilder(
    column: $table.timestamp,
    builder: (column) => ColumnFilters(column),
  );
}

class $$OutgoingBodiesTableOrderingComposer
    extends Composer<_$AppDatabase, $OutgoingBodiesTable> {
  $$OutgoingBodiesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get plaintext => $composableBuilder(
    column: $table.plaintext,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get timestamp => $composableBuilder(
    column: $table.timestamp,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$OutgoingBodiesTableAnnotationComposer
    extends Composer<_$AppDatabase, $OutgoingBodiesTable> {
  $$OutgoingBodiesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get plaintext =>
      $composableBuilder(column: $table.plaintext, builder: (column) => column);

  GeneratedColumn<int> get timestamp =>
      $composableBuilder(column: $table.timestamp, builder: (column) => column);
}

class $$OutgoingBodiesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $OutgoingBodiesTable,
          OutgoingBody,
          $$OutgoingBodiesTableFilterComposer,
          $$OutgoingBodiesTableOrderingComposer,
          $$OutgoingBodiesTableAnnotationComposer,
          $$OutgoingBodiesTableCreateCompanionBuilder,
          $$OutgoingBodiesTableUpdateCompanionBuilder,
          (
            OutgoingBody,
            BaseReferences<_$AppDatabase, $OutgoingBodiesTable, OutgoingBody>,
          ),
          OutgoingBody,
          PrefetchHooks Function()
        > {
  $$OutgoingBodiesTableTableManager(
    _$AppDatabase db,
    $OutgoingBodiesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$OutgoingBodiesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$OutgoingBodiesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$OutgoingBodiesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> plaintext = const Value.absent(),
                Value<int> timestamp = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => OutgoingBodiesCompanion(
                id: id,
                plaintext: plaintext,
                timestamp: timestamp,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String plaintext,
                required int timestamp,
                Value<int> rowid = const Value.absent(),
              }) => OutgoingBodiesCompanion.insert(
                id: id,
                plaintext: plaintext,
                timestamp: timestamp,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$OutgoingBodiesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $OutgoingBodiesTable,
      OutgoingBody,
      $$OutgoingBodiesTableFilterComposer,
      $$OutgoingBodiesTableOrderingComposer,
      $$OutgoingBodiesTableAnnotationComposer,
      $$OutgoingBodiesTableCreateCompanionBuilder,
      $$OutgoingBodiesTableUpdateCompanionBuilder,
      (
        OutgoingBody,
        BaseReferences<_$AppDatabase, $OutgoingBodiesTable, OutgoingBody>,
      ),
      OutgoingBody,
      PrefetchHooks Function()
    >;
typedef $$MessageStatusesTableCreateCompanionBuilder =
    MessageStatusesCompanion Function({
      required String id,
      Value<int> status,
      Value<int> updatedAt,
      Value<int> rowid,
    });
typedef $$MessageStatusesTableUpdateCompanionBuilder =
    MessageStatusesCompanion Function({
      Value<String> id,
      Value<int> status,
      Value<int> updatedAt,
      Value<int> rowid,
    });

class $$MessageStatusesTableFilterComposer
    extends Composer<_$AppDatabase, $MessageStatusesTable> {
  $$MessageStatusesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$MessageStatusesTableOrderingComposer
    extends Composer<_$AppDatabase, $MessageStatusesTable> {
  $$MessageStatusesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$MessageStatusesTableAnnotationComposer
    extends Composer<_$AppDatabase, $MessageStatusesTable> {
  $$MessageStatusesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$MessageStatusesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $MessageStatusesTable,
          MessageStatuse,
          $$MessageStatusesTableFilterComposer,
          $$MessageStatusesTableOrderingComposer,
          $$MessageStatusesTableAnnotationComposer,
          $$MessageStatusesTableCreateCompanionBuilder,
          $$MessageStatusesTableUpdateCompanionBuilder,
          (
            MessageStatuse,
            BaseReferences<
              _$AppDatabase,
              $MessageStatusesTable,
              MessageStatuse
            >,
          ),
          MessageStatuse,
          PrefetchHooks Function()
        > {
  $$MessageStatusesTableTableManager(
    _$AppDatabase db,
    $MessageStatusesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MessageStatusesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MessageStatusesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$MessageStatusesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<int> status = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => MessageStatusesCompanion(
                id: id,
                status: status,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                Value<int> status = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => MessageStatusesCompanion.insert(
                id: id,
                status: status,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$MessageStatusesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $MessageStatusesTable,
      MessageStatuse,
      $$MessageStatusesTableFilterComposer,
      $$MessageStatusesTableOrderingComposer,
      $$MessageStatusesTableAnnotationComposer,
      $$MessageStatusesTableCreateCompanionBuilder,
      $$MessageStatusesTableUpdateCompanionBuilder,
      (
        MessageStatuse,
        BaseReferences<_$AppDatabase, $MessageStatusesTable, MessageStatuse>,
      ),
      MessageStatuse,
      PrefetchHooks Function()
    >;
typedef $$MediaBlobsTableCreateCompanionBuilder =
    MediaBlobsCompanion Function({
      required String blobId,
      required String kind,
      required String mime,
      required int byteCount,
      Value<int> durationMs,
      required String data,
      Value<int> timestamp,
      Value<String> path,
      Value<int> rowid,
    });
typedef $$MediaBlobsTableUpdateCompanionBuilder =
    MediaBlobsCompanion Function({
      Value<String> blobId,
      Value<String> kind,
      Value<String> mime,
      Value<int> byteCount,
      Value<int> durationMs,
      Value<String> data,
      Value<int> timestamp,
      Value<String> path,
      Value<int> rowid,
    });

class $$MediaBlobsTableFilterComposer
    extends Composer<_$AppDatabase, $MediaBlobsTable> {
  $$MediaBlobsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get blobId => $composableBuilder(
    column: $table.blobId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get mime => $composableBuilder(
    column: $table.mime,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get byteCount => $composableBuilder(
    column: $table.byteCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get durationMs => $composableBuilder(
    column: $table.durationMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get data => $composableBuilder(
    column: $table.data,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get timestamp => $composableBuilder(
    column: $table.timestamp,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get path => $composableBuilder(
    column: $table.path,
    builder: (column) => ColumnFilters(column),
  );
}

class $$MediaBlobsTableOrderingComposer
    extends Composer<_$AppDatabase, $MediaBlobsTable> {
  $$MediaBlobsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get blobId => $composableBuilder(
    column: $table.blobId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get mime => $composableBuilder(
    column: $table.mime,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get byteCount => $composableBuilder(
    column: $table.byteCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get durationMs => $composableBuilder(
    column: $table.durationMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get data => $composableBuilder(
    column: $table.data,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get timestamp => $composableBuilder(
    column: $table.timestamp,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get path => $composableBuilder(
    column: $table.path,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$MediaBlobsTableAnnotationComposer
    extends Composer<_$AppDatabase, $MediaBlobsTable> {
  $$MediaBlobsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get blobId =>
      $composableBuilder(column: $table.blobId, builder: (column) => column);

  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get mime =>
      $composableBuilder(column: $table.mime, builder: (column) => column);

  GeneratedColumn<int> get byteCount =>
      $composableBuilder(column: $table.byteCount, builder: (column) => column);

  GeneratedColumn<int> get durationMs => $composableBuilder(
    column: $table.durationMs,
    builder: (column) => column,
  );

  GeneratedColumn<String> get data =>
      $composableBuilder(column: $table.data, builder: (column) => column);

  GeneratedColumn<int> get timestamp =>
      $composableBuilder(column: $table.timestamp, builder: (column) => column);

  GeneratedColumn<String> get path =>
      $composableBuilder(column: $table.path, builder: (column) => column);
}

class $$MediaBlobsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $MediaBlobsTable,
          MediaBlob,
          $$MediaBlobsTableFilterComposer,
          $$MediaBlobsTableOrderingComposer,
          $$MediaBlobsTableAnnotationComposer,
          $$MediaBlobsTableCreateCompanionBuilder,
          $$MediaBlobsTableUpdateCompanionBuilder,
          (
            MediaBlob,
            BaseReferences<_$AppDatabase, $MediaBlobsTable, MediaBlob>,
          ),
          MediaBlob,
          PrefetchHooks Function()
        > {
  $$MediaBlobsTableTableManager(_$AppDatabase db, $MediaBlobsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MediaBlobsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MediaBlobsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$MediaBlobsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> blobId = const Value.absent(),
                Value<String> kind = const Value.absent(),
                Value<String> mime = const Value.absent(),
                Value<int> byteCount = const Value.absent(),
                Value<int> durationMs = const Value.absent(),
                Value<String> data = const Value.absent(),
                Value<int> timestamp = const Value.absent(),
                Value<String> path = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => MediaBlobsCompanion(
                blobId: blobId,
                kind: kind,
                mime: mime,
                byteCount: byteCount,
                durationMs: durationMs,
                data: data,
                timestamp: timestamp,
                path: path,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String blobId,
                required String kind,
                required String mime,
                required int byteCount,
                Value<int> durationMs = const Value.absent(),
                required String data,
                Value<int> timestamp = const Value.absent(),
                Value<String> path = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => MediaBlobsCompanion.insert(
                blobId: blobId,
                kind: kind,
                mime: mime,
                byteCount: byteCount,
                durationMs: durationMs,
                data: data,
                timestamp: timestamp,
                path: path,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$MediaBlobsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $MediaBlobsTable,
      MediaBlob,
      $$MediaBlobsTableFilterComposer,
      $$MediaBlobsTableOrderingComposer,
      $$MediaBlobsTableAnnotationComposer,
      $$MediaBlobsTableCreateCompanionBuilder,
      $$MediaBlobsTableUpdateCompanionBuilder,
      (MediaBlob, BaseReferences<_$AppDatabase, $MediaBlobsTable, MediaBlob>),
      MediaBlob,
      PrefetchHooks Function()
    >;
typedef $$TransfersTableCreateCompanionBuilder =
    TransfersCompanion Function({
      required String transferId,
      required String blobId,
      required String kind,
      required String mime,
      required int byteCount,
      required int chunkSize,
      required int chunkCount,
      required String sha256,
      Value<int> durationMs,
      required String senderX,
      Value<String> conversationId,
      Value<int> started,
      Value<int> timestamp,
      Value<int> completed,
      Value<int> rowid,
    });
typedef $$TransfersTableUpdateCompanionBuilder =
    TransfersCompanion Function({
      Value<String> transferId,
      Value<String> blobId,
      Value<String> kind,
      Value<String> mime,
      Value<int> byteCount,
      Value<int> chunkSize,
      Value<int> chunkCount,
      Value<String> sha256,
      Value<int> durationMs,
      Value<String> senderX,
      Value<String> conversationId,
      Value<int> started,
      Value<int> timestamp,
      Value<int> completed,
      Value<int> rowid,
    });

class $$TransfersTableFilterComposer
    extends Composer<_$AppDatabase, $TransfersTable> {
  $$TransfersTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get transferId => $composableBuilder(
    column: $table.transferId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get blobId => $composableBuilder(
    column: $table.blobId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get mime => $composableBuilder(
    column: $table.mime,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get byteCount => $composableBuilder(
    column: $table.byteCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get chunkSize => $composableBuilder(
    column: $table.chunkSize,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get chunkCount => $composableBuilder(
    column: $table.chunkCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sha256 => $composableBuilder(
    column: $table.sha256,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get durationMs => $composableBuilder(
    column: $table.durationMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get senderX => $composableBuilder(
    column: $table.senderX,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get conversationId => $composableBuilder(
    column: $table.conversationId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get started => $composableBuilder(
    column: $table.started,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get timestamp => $composableBuilder(
    column: $table.timestamp,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get completed => $composableBuilder(
    column: $table.completed,
    builder: (column) => ColumnFilters(column),
  );
}

class $$TransfersTableOrderingComposer
    extends Composer<_$AppDatabase, $TransfersTable> {
  $$TransfersTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get transferId => $composableBuilder(
    column: $table.transferId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get blobId => $composableBuilder(
    column: $table.blobId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get mime => $composableBuilder(
    column: $table.mime,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get byteCount => $composableBuilder(
    column: $table.byteCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get chunkSize => $composableBuilder(
    column: $table.chunkSize,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get chunkCount => $composableBuilder(
    column: $table.chunkCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sha256 => $composableBuilder(
    column: $table.sha256,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get durationMs => $composableBuilder(
    column: $table.durationMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get senderX => $composableBuilder(
    column: $table.senderX,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get conversationId => $composableBuilder(
    column: $table.conversationId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get started => $composableBuilder(
    column: $table.started,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get timestamp => $composableBuilder(
    column: $table.timestamp,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get completed => $composableBuilder(
    column: $table.completed,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$TransfersTableAnnotationComposer
    extends Composer<_$AppDatabase, $TransfersTable> {
  $$TransfersTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get transferId => $composableBuilder(
    column: $table.transferId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get blobId =>
      $composableBuilder(column: $table.blobId, builder: (column) => column);

  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get mime =>
      $composableBuilder(column: $table.mime, builder: (column) => column);

  GeneratedColumn<int> get byteCount =>
      $composableBuilder(column: $table.byteCount, builder: (column) => column);

  GeneratedColumn<int> get chunkSize =>
      $composableBuilder(column: $table.chunkSize, builder: (column) => column);

  GeneratedColumn<int> get chunkCount => $composableBuilder(
    column: $table.chunkCount,
    builder: (column) => column,
  );

  GeneratedColumn<String> get sha256 =>
      $composableBuilder(column: $table.sha256, builder: (column) => column);

  GeneratedColumn<int> get durationMs => $composableBuilder(
    column: $table.durationMs,
    builder: (column) => column,
  );

  GeneratedColumn<String> get senderX =>
      $composableBuilder(column: $table.senderX, builder: (column) => column);

  GeneratedColumn<String> get conversationId => $composableBuilder(
    column: $table.conversationId,
    builder: (column) => column,
  );

  GeneratedColumn<int> get started =>
      $composableBuilder(column: $table.started, builder: (column) => column);

  GeneratedColumn<int> get timestamp =>
      $composableBuilder(column: $table.timestamp, builder: (column) => column);

  GeneratedColumn<int> get completed =>
      $composableBuilder(column: $table.completed, builder: (column) => column);
}

class $$TransfersTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $TransfersTable,
          Transfer,
          $$TransfersTableFilterComposer,
          $$TransfersTableOrderingComposer,
          $$TransfersTableAnnotationComposer,
          $$TransfersTableCreateCompanionBuilder,
          $$TransfersTableUpdateCompanionBuilder,
          (Transfer, BaseReferences<_$AppDatabase, $TransfersTable, Transfer>),
          Transfer,
          PrefetchHooks Function()
        > {
  $$TransfersTableTableManager(_$AppDatabase db, $TransfersTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TransfersTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TransfersTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TransfersTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> transferId = const Value.absent(),
                Value<String> blobId = const Value.absent(),
                Value<String> kind = const Value.absent(),
                Value<String> mime = const Value.absent(),
                Value<int> byteCount = const Value.absent(),
                Value<int> chunkSize = const Value.absent(),
                Value<int> chunkCount = const Value.absent(),
                Value<String> sha256 = const Value.absent(),
                Value<int> durationMs = const Value.absent(),
                Value<String> senderX = const Value.absent(),
                Value<String> conversationId = const Value.absent(),
                Value<int> started = const Value.absent(),
                Value<int> timestamp = const Value.absent(),
                Value<int> completed = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TransfersCompanion(
                transferId: transferId,
                blobId: blobId,
                kind: kind,
                mime: mime,
                byteCount: byteCount,
                chunkSize: chunkSize,
                chunkCount: chunkCount,
                sha256: sha256,
                durationMs: durationMs,
                senderX: senderX,
                conversationId: conversationId,
                started: started,
                timestamp: timestamp,
                completed: completed,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String transferId,
                required String blobId,
                required String kind,
                required String mime,
                required int byteCount,
                required int chunkSize,
                required int chunkCount,
                required String sha256,
                Value<int> durationMs = const Value.absent(),
                required String senderX,
                Value<String> conversationId = const Value.absent(),
                Value<int> started = const Value.absent(),
                Value<int> timestamp = const Value.absent(),
                Value<int> completed = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TransfersCompanion.insert(
                transferId: transferId,
                blobId: blobId,
                kind: kind,
                mime: mime,
                byteCount: byteCount,
                chunkSize: chunkSize,
                chunkCount: chunkCount,
                sha256: sha256,
                durationMs: durationMs,
                senderX: senderX,
                conversationId: conversationId,
                started: started,
                timestamp: timestamp,
                completed: completed,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$TransfersTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $TransfersTable,
      Transfer,
      $$TransfersTableFilterComposer,
      $$TransfersTableOrderingComposer,
      $$TransfersTableAnnotationComposer,
      $$TransfersTableCreateCompanionBuilder,
      $$TransfersTableUpdateCompanionBuilder,
      (Transfer, BaseReferences<_$AppDatabase, $TransfersTable, Transfer>),
      Transfer,
      PrefetchHooks Function()
    >;
typedef $$TransferPartsTableCreateCompanionBuilder =
    TransferPartsCompanion Function({
      required String transferId,
      required int index,
      required int byteCount,
      Value<String> data,
      Value<String> path,
      Value<int> rowid,
    });
typedef $$TransferPartsTableUpdateCompanionBuilder =
    TransferPartsCompanion Function({
      Value<String> transferId,
      Value<int> index,
      Value<int> byteCount,
      Value<String> data,
      Value<String> path,
      Value<int> rowid,
    });

class $$TransferPartsTableFilterComposer
    extends Composer<_$AppDatabase, $TransferPartsTable> {
  $$TransferPartsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get transferId => $composableBuilder(
    column: $table.transferId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get index => $composableBuilder(
    column: $table.index,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get byteCount => $composableBuilder(
    column: $table.byteCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get data => $composableBuilder(
    column: $table.data,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get path => $composableBuilder(
    column: $table.path,
    builder: (column) => ColumnFilters(column),
  );
}

class $$TransferPartsTableOrderingComposer
    extends Composer<_$AppDatabase, $TransferPartsTable> {
  $$TransferPartsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get transferId => $composableBuilder(
    column: $table.transferId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get index => $composableBuilder(
    column: $table.index,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get byteCount => $composableBuilder(
    column: $table.byteCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get data => $composableBuilder(
    column: $table.data,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get path => $composableBuilder(
    column: $table.path,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$TransferPartsTableAnnotationComposer
    extends Composer<_$AppDatabase, $TransferPartsTable> {
  $$TransferPartsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get transferId => $composableBuilder(
    column: $table.transferId,
    builder: (column) => column,
  );

  GeneratedColumn<int> get index =>
      $composableBuilder(column: $table.index, builder: (column) => column);

  GeneratedColumn<int> get byteCount =>
      $composableBuilder(column: $table.byteCount, builder: (column) => column);

  GeneratedColumn<String> get data =>
      $composableBuilder(column: $table.data, builder: (column) => column);

  GeneratedColumn<String> get path =>
      $composableBuilder(column: $table.path, builder: (column) => column);
}

class $$TransferPartsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $TransferPartsTable,
          TransferPart,
          $$TransferPartsTableFilterComposer,
          $$TransferPartsTableOrderingComposer,
          $$TransferPartsTableAnnotationComposer,
          $$TransferPartsTableCreateCompanionBuilder,
          $$TransferPartsTableUpdateCompanionBuilder,
          (
            TransferPart,
            BaseReferences<_$AppDatabase, $TransferPartsTable, TransferPart>,
          ),
          TransferPart,
          PrefetchHooks Function()
        > {
  $$TransferPartsTableTableManager(_$AppDatabase db, $TransferPartsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TransferPartsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TransferPartsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TransferPartsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> transferId = const Value.absent(),
                Value<int> index = const Value.absent(),
                Value<int> byteCount = const Value.absent(),
                Value<String> data = const Value.absent(),
                Value<String> path = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TransferPartsCompanion(
                transferId: transferId,
                index: index,
                byteCount: byteCount,
                data: data,
                path: path,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String transferId,
                required int index,
                required int byteCount,
                Value<String> data = const Value.absent(),
                Value<String> path = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TransferPartsCompanion.insert(
                transferId: transferId,
                index: index,
                byteCount: byteCount,
                data: data,
                path: path,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$TransferPartsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $TransferPartsTable,
      TransferPart,
      $$TransferPartsTableFilterComposer,
      $$TransferPartsTableOrderingComposer,
      $$TransferPartsTableAnnotationComposer,
      $$TransferPartsTableCreateCompanionBuilder,
      $$TransferPartsTableUpdateCompanionBuilder,
      (
        TransferPart,
        BaseReferences<_$AppDatabase, $TransferPartsTable, TransferPart>,
      ),
      TransferPart,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$MessagesTableTableManager get messages =>
      $$MessagesTableTableManager(_db, _db.messages);
  $$PrunedRootsTableTableManager get prunedRoots =>
      $$PrunedRootsTableTableManager(_db, _db.prunedRoots);
  $$IdentityEntryTableTableManager get identityEntry =>
      $$IdentityEntryTableTableManager(_db, _db.identityEntry);
  $$AppSettingsTableTableManager get appSettings =>
      $$AppSettingsTableTableManager(_db, _db.appSettings);
  $$ConversationHeadsTableTableManager get conversationHeads =>
      $$ConversationHeadsTableTableManager(_db, _db.conversationHeads);
  $$PeersTableTableManager get peers =>
      $$PeersTableTableManager(_db, _db.peers);
  $$ConversationsTableTableManager get conversations =>
      $$ConversationsTableTableManager(_db, _db.conversations);
  $$ConversationMembersTableTableManager get conversationMembers =>
      $$ConversationMembersTableTableManager(_db, _db.conversationMembers);
  $$OutgoingBodiesTableTableManager get outgoingBodies =>
      $$OutgoingBodiesTableTableManager(_db, _db.outgoingBodies);
  $$MessageStatusesTableTableManager get messageStatuses =>
      $$MessageStatusesTableTableManager(_db, _db.messageStatuses);
  $$MediaBlobsTableTableManager get mediaBlobs =>
      $$MediaBlobsTableTableManager(_db, _db.mediaBlobs);
  $$TransfersTableTableManager get transfers =>
      $$TransfersTableTableManager(_db, _db.transfers);
  $$TransferPartsTableTableManager get transferParts =>
      $$TransferPartsTableTableManager(_db, _db.transferParts);
}
