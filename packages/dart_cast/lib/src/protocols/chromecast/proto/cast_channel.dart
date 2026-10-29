/// Hand-written protobuf bindings for the CASTV2 CastMessage.
///
/// These classes mirror the Chromium `cast_channel.proto` definition without
/// requiring the `protoc` compiler.  They use the `protobuf` package's
/// [GeneratedMessage] / [ProtobufEnum] API directly.
///
/// The `CastMessage_*` nested-enum type names match the identifiers that
/// `protoc --dart_out` would emit for the underlying `.proto`, so the file
/// intentionally opts out of `camel_case_types`.
// ignore_for_file: camel_case_types
library;

import 'package:protobuf/protobuf.dart';

// ---------------------------------------------------------------------------
// Enums
// ---------------------------------------------------------------------------

/// `CastMessage.ProtocolVersion` enum.
class CastMessage_ProtocolVersion extends ProtobufEnum {
  // ignore: constant_identifier_names
  static const CastMessage_ProtocolVersion CASTV2_1_0 =
      CastMessage_ProtocolVersion._(0, 'CASTV2_1_0');

  static const List<CastMessage_ProtocolVersion> values = [CASTV2_1_0];

  static final Map<int, CastMessage_ProtocolVersion> _byValue =
      ProtobufEnum.initByValue(values);

  static CastMessage_ProtocolVersion? valueOf(int value) => _byValue[value];

  const CastMessage_ProtocolVersion._(super.v, super.n);
}

/// `CastMessage.PayloadType` enum.
class CastMessage_PayloadType extends ProtobufEnum {
  // ignore: constant_identifier_names
  static const CastMessage_PayloadType STRING = CastMessage_PayloadType._(
    0,
    'STRING',
  );
  // ignore: constant_identifier_names
  static const CastMessage_PayloadType BINARY = CastMessage_PayloadType._(
    1,
    'BINARY',
  );

  static const List<CastMessage_PayloadType> values = [STRING, BINARY];

  static final Map<int, CastMessage_PayloadType> _byValue =
      ProtobufEnum.initByValue(values);

  static CastMessage_PayloadType? valueOf(int value) => _byValue[value];

  const CastMessage_PayloadType._(super.v, super.n);
}

// ---------------------------------------------------------------------------
// CastMessage
// ---------------------------------------------------------------------------

/// A manually-coded protobuf [GeneratedMessage] matching `CastMessage` from
/// `cast_channel.proto`.
///
/// Field layout:
/// ```
/// required ProtocolVersion protocol_version = 1;
/// required string          source_id        = 2;
/// required string          destination_id   = 3;
/// required string          namespace        = 4;
/// required PayloadType     payload_type     = 5;
/// optional string          payload_utf8     = 6;
/// optional bytes           payload_binary   = 7;
/// ```
class CastMessage extends GeneratedMessage {
  /// Creates an empty [CastMessage].
  factory CastMessage() => CastMessage._();

  /// Deserialise from protobuf bytes.
  factory CastMessage.fromBuffer(
    List<int> bytes, [
    ExtensionRegistry registry = ExtensionRegistry.EMPTY,
  ]) => CastMessage._()..mergeFromBuffer(bytes, registry);

  CastMessage._() : super();

  @override
  CastMessage createEmptyInstance() => CastMessage._();

  @override
  CastMessage clone() => CastMessage._()..mergeFromMessage(this);

  static final BuilderInfo _i =
      BuilderInfo(
          'CastMessage',
          package: const PackageName('extensions.api.cast_channel'),
          createEmptyInstance: CastMessage._,
        )
        ..e<CastMessage_ProtocolVersion>(
          1,
          'protocolVersion',
          PbFieldType.QE,
          defaultOrMaker: CastMessage_ProtocolVersion.CASTV2_1_0,
          valueOf: CastMessage_ProtocolVersion.valueOf,
          enumValues: CastMessage_ProtocolVersion.values,
        )
        ..aQS(2, 'sourceId')
        ..aQS(3, 'destinationId')
        ..aQS(4, 'namespace')
        ..e<CastMessage_PayloadType>(
          5,
          'payloadType',
          PbFieldType.QE,
          defaultOrMaker: CastMessage_PayloadType.STRING,
          valueOf: CastMessage_PayloadType.valueOf,
          enumValues: CastMessage_PayloadType.values,
        )
        ..aOS(6, 'payloadUtf8')
        ..a<List<int>>(7, 'payloadBinary', PbFieldType.OY);

  @override
  BuilderInfo get info_ => _i;

  // -- Typed accessors -------------------------------------------------------

  CastMessage_ProtocolVersion get protocolVersion =>
      $_getN<CastMessage_ProtocolVersion>(0);
  set protocolVersion(CastMessage_ProtocolVersion v) => setField(1, v);
  bool hasProtocolVersion() => $_has(0);

  String get sourceId => $_getSZ(1);
  set sourceId(String v) => $_setString(1, v);
  bool hasSourceId() => $_has(1);

  String get destinationId => $_getSZ(2);
  set destinationId(String v) => $_setString(2, v);
  bool hasDestinationId() => $_has(2);

  String get namespace_ => $_getSZ(3);
  set namespace_(String v) => $_setString(3, v);
  bool hasNamespace_() => $_has(3);

  CastMessage_PayloadType get payloadType => $_getN<CastMessage_PayloadType>(4);
  set payloadType(CastMessage_PayloadType v) => setField(5, v);
  bool hasPayloadType() => $_has(4);

  String get payloadUtf8 => $_getSZ(5);
  set payloadUtf8(String v) => $_setString(5, v);
  bool hasPayloadUtf8() => $_has(5);

  List<int> get payloadBinary => $_getN<List<int>>(6);
  set payloadBinary(List<int> v) => setField(7, v);
  bool hasPayloadBinary() => $_has(6);
}
