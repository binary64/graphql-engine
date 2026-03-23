-- | OpenTelemetry disabled in stripped fork. All functions are no-ops.
module Hasura.RQL.DDL.OpenTelemetry
  ( parseOtelExporterConfig,
    parseOtelBatchSpanProcessorConfig,
    runSetOpenTelemetryConfig,
    runSetOpenTelemetryStatus,
  )
where

import Hasura.Base.Error
import Hasura.EncJSON
import Hasura.Metadata.Class
import Hasura.Prelude
import Hasura.RQL.Types.Metadata
import Hasura.RQL.Types.OpenTelemetry

parseOtelExporterConfig :: (MonadError QErr m) => OpenTelemetryConfig -> m OpenTelemetryInfo
parseOtelExporterConfig _ = pure emptyOpenTelemetryInfo

parseOtelBatchSpanProcessorConfig :: (MonadError QErr m) => OpenTelemetryConfig -> m OpenTelemetryInfo
parseOtelBatchSpanProcessorConfig _ = pure emptyOpenTelemetryInfo

runSetOpenTelemetryConfig ::
  (MetadataM m, MonadError QErr m) =>
  OpenTelemetryConfig ->
  m EncJSON
runSetOpenTelemetryConfig _ = pure successMsg

runSetOpenTelemetryStatus ::
  (MetadataM m, MonadError QErr m) =>
  OtelStatus ->
  m EncJSON
runSetOpenTelemetryStatus _ = pure successMsg
