-- | Telemetry disabled in stripped fork. All functions are no-ops.
module Hasura.Server.Telemetry
  ( runTelemetry,
  )
where

import Control.Concurrent.Extended qualified as C
import Data.Void (Void)
import Hasura.App.State qualified as State
import Hasura.Logging
import Hasura.Prelude
import Hasura.Server.AppStateRef qualified as HGE
import Hasura.Server.ResourceChecker (ComputeResourcesResponse)
import Hasura.Server.Types (MetadataDbId, PGVersion)

runTelemetry ::
  forall m impl.
  ( MonadIO m,
    State.HasAppEnv m
  ) =>
  Logger Hasura ->
  HGE.AppStateRef impl ->
  MetadataDbId ->
  PGVersion ->
  ComputeResourcesResponse ->
  m Void
runTelemetry _ _ _ _ _ =
  liftIO $ forever $ C.sleep $ seconds 86400
