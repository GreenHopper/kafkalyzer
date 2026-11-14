import 'package:kafkalyzer/src/rust/api/connection_diagnostics.dart';
import 'package:kafkalyzer/src/rust/api/kafka_types.dart';

class ConnectionDiagnosticsService {
  Future<ConnectionDiagnosis> diagnose(ClusterProfile profile) {
    return diagnoseConnection(profile: profile);
  }
}
