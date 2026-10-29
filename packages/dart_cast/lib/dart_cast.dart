/// Coppelia's vendored Chromecast CASTV2 implementation.
library;

// Core
export 'src/core/cast_device.dart';
export 'src/core/cast_exceptions.dart';
export 'src/core/cast_media.dart';
export 'src/core/cast_service.dart';
export 'src/core/cast_session.dart';
export 'src/core/discovery_manager.dart';
export 'src/core/media_transformer.dart';
export 'src/core/ts_hls_media_transformer.dart';
export 'src/core/discovery_provider.dart';
export 'src/core/hls_parser.dart';
export 'src/core/hls_stream_proxy.dart';
export 'src/core/media_proxy.dart';
export 'src/core/media_source.dart';
export 'src/core/subtitle_converter.dart';

// Protocols — Chromecast
export 'src/protocols/chromecast/chromecast_discovery_provider.dart';
export 'src/protocols/chromecast/chromecast_session.dart';

// Utils
export 'src/utils/logger.dart';
export 'src/utils/mdns_discovery.dart';
export 'src/utils/network_utils.dart';
