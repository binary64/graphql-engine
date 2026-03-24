{-# LANGUAGE DuplicateRecordFields #-}

-- | Telemetry counters — disabled in stripped fork. All functions are no-ops.
module Hasura.Server.Telemetry.Counters
  ( -- * Service timing and counts, by various dimensions

    -- ** Local metric recording
    recordTimingMetric,
    RequestDimensions (..),
    RequestTimings (..),

    -- *** Dimensions
    QueryType (..),
    Locality (..),
    Transport (..),

    -- ** Metric upload
    dumpServiceTimingMetrics,
    ServiceTimingMetrics (..),
    ServiceTimingMetric (..),
    RunningTimeBucket (..),
    RequestTimingsCount (..),
  )
where

import Data.Aeson qualified as J
import Hasura.Prelude

-- | The properties that characterize this request.
data RequestDimensions = RequestDimensions
  { telemQueryType :: !QueryType,
    telemLocality :: !Locality,
    telemTransport :: !Transport
  }
  deriving (Show, Generic, Eq, Ord)

instance Hashable RequestDimensions

-- | Accumulated time metrics.
data RequestTimings = RequestTimings
  { telemTimeIO :: !Seconds,
    telemTimeTot :: !Seconds
  }

instance Semigroup RequestTimings where
  RequestTimings a b <> RequestTimings x y = RequestTimings (a + x) (b + y)

-- | 'RequestTimings' along with the count
data RequestTimingsCount = RequestTimingsCount
  { telemTimeIO :: !Seconds,
    telemTimeTot :: !Seconds,
    telemCount :: !Word
  }
  deriving (Show, Generic, Eq, Ord)

instance Semigroup RequestTimingsCount where
  RequestTimingsCount a b c <> RequestTimingsCount x y z =
    RequestTimingsCount (a + x) (b + y) (c + z)

-- | Was this request a mutation (involved DB writes)?
data QueryType = Mutation | Query
  deriving (Enum, Show, Eq, Ord, Generic)

instance Hashable QueryType

instance J.ToJSON QueryType

instance J.FromJSON QueryType

-- | Was this a PG local query, or did it involve remote execution?
data Locality
  = -- | No data was fetched
    Empty
  | -- | local DB data
    Local
  | -- | remote schema
    Remote
  | -- | mixed
    Heterogeneous
  deriving (Enum, Show, Eq, Ord, Generic)

instance Hashable Locality

instance J.ToJSON Locality

instance J.FromJSON Locality

instance Semigroup Locality where
  Empty <> x = x
  x <> Empty = x
  x <> y | x == y = x
  _ <> _ = Heterogeneous

instance Monoid Locality where
  mempty = Empty

-- | Was this a query over http or websockets?
data Transport = HTTP | WebSocket
  deriving (Enum, Show, Eq, Ord, Generic)

instance Hashable Transport

instance J.ToJSON Transport

instance J.FromJSON Transport

-- | The timings and counts here were from requests with total time longer than
-- 'bucketGreaterThan'.
newtype RunningTimeBucket = RunningTimeBucket {bucketGreaterThan :: Seconds}
  deriving (Ord, Eq, Show, Generic, J.ToJSON, J.FromJSON, Hashable)

-- | No-op: telemetry disabled in stripped fork.
recordTimingMetric :: (MonadIO m) => RequestDimensions -> RequestTimings -> m ()
recordTimingMetric _ _ = pure ()

data ServiceTimingMetrics = ServiceTimingMetrics
  { collectionTag :: Int,
    serviceTimingMetrics :: [ServiceTimingMetric]
  }
  deriving (Show, Generic, Eq, Ord)

data ServiceTimingMetric = ServiceTimingMetric
  { dimensions :: RequestDimensions,
    bucket :: RunningTimeBucket,
    metrics :: RequestTimingsCount
  }
  deriving (Show, Generic, Eq, Ord)

instance J.FromJSON RequestTimingsCount where
  parseJSON = J.genericParseJSON hasuraJSON

instance J.ToJSON RequestTimingsCount where
  toJSON = J.genericToJSON hasuraJSON
  toEncoding = J.genericToEncoding hasuraJSON

instance J.FromJSON RequestDimensions where
  parseJSON = J.genericParseJSON hasuraJSON

instance J.ToJSON RequestDimensions where
  toJSON = J.genericToJSON hasuraJSON
  toEncoding = J.genericToEncoding hasuraJSON

instance J.ToJSON ServiceTimingMetric

instance J.FromJSON ServiceTimingMetric

instance J.ToJSON ServiceTimingMetrics

instance J.FromJSON ServiceTimingMetrics

-- | Returns empty metrics — telemetry disabled in stripped fork.
dumpServiceTimingMetrics :: (MonadIO m) => m ServiceTimingMetrics
dumpServiceTimingMetrics = pure $ ServiceTimingMetrics 0 []
