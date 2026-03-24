-- | OpenTelemetry disabled in stripped fork. All functions are no-ops/defaults.
module Hasura.RQL.DDL.OpenTelemetry
  ( runSetOpenTelemetryConfig,
    runSetOpenTelemetryStatus,
    parseOtelExporterConfig,
    parseOtelBatchSpanProcessorConfig,
  )
where

import Data.Environment (Environment)
import Data.Set qualified as Set
import Hasura.Base.Error
import Hasura.EncJSON
import Hasura.Metadata.Class ()
import Hasura.Prelude
import Hasura.RQL.Types.Common (successMsg)
import Hasura.RQL.Types.Metadata
import Hasura.RQL.Types.OpenTelemetry
import Hasura.RQL.Types.SchemaCache.Build

runSetOpenTelemetryConfig ::
  (MonadError QErr m, MetadataM m, CacheRWM m) =>
  OpenTelemetryConfig ->
  m EncJSON
runSetOpenTelemetryConfig _ = pure successMsg

runSetOpenTelemetryStatus ::
  (MonadError QErr m, MetadataM m, CacheRWM m) =>
  OtelStatusConfig ->
  m EncJSON
runSetOpenTelemetryStatus _ = pure successMsg

parseOtelExporterConfig ::
  Environment ->
  Set.Set OtelDataType ->
  OtelExporterConfig ->
  Either QErr OtelExporterInfo
parseOtelExporterConfig _ _ _ = Right emptyOtelExporterInfo

parseOtelBatchSpanProcessorConfig ::
  OtelBatchSpanProcessorConfig -> Either QErr OtelBatchSpanProcessorInfo
parseOtelBatchSpanProcessorConfig _ = Right defaultOtelBatchSpanProcessorInfo
