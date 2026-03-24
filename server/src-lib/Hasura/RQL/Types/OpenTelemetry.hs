{-# LANGUAGE DeriveAnyClass #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE TemplateHaskell #-}

-- | OpenTelemetry types — disabled in stripped fork. Types kept for metadata compatibility.
module Hasura.RQL.Types.OpenTelemetry
  ( -- * User-facing configuration (metadata)
    OpenTelemetryConfig (..),
    ocStatus,
    ocEnabledDataTypes,
    ocExporterOtlp,
    ocBatchSpanProcessor,
    emptyOpenTelemetryConfig,
    OpenTelemetryConfigSubobject (..),
    OtelStatus (..),
    OtelStatusConfig (..),
    OtelDataType (..),
    OtelExporterConfig (..),
    defaultOtelExporterConfig,
    OtlpProtocol (..),
    OtelBatchSpanProcessorConfig (..),
    defaultOtelBatchSpanProcessorConfig,
    NameValue (..),
    TracePropagator (..),

    -- * Parsed configuration (schema cache)
    OpenTelemetryInfo (..),
    otiExporterOtlp,
    otiBatchSpanProcessorInfo,
    OtelExporterInfo (..),
    emptyOtelExporterInfo,
    OtelBatchSpanProcessorInfo (..),
    getMaxExportBatchSize,
    getMaxQueueSize,
    defaultOtelBatchSpanProcessorInfo,
    defaultOtelExporterTracesPropagators,
    mkOtelTracesPropagator,
    getOtelTracesPropagator,
    defaultOtelStatusConfig,
    mkOtelStatusFromEnv,
  )
where

import Autodocodec (HasCodec, optionalField, optionalFieldWithDefault, optionalFieldWithDefault', requiredField', (<?>))
import Autodocodec qualified as AC
import Autodocodec.Extended (boundedEnumCodec)
import Control.Lens.TH (makeLenses)
import Data.Aeson (FromJSON, ToJSON (..), (.!=), (.:), (.:?), (.=))
import Data.Aeson qualified as J
import Data.Environment qualified as Env
import Data.Map.Strict (Map)
import Data.Set (Set)
import Data.Set qualified as Set
import Data.Text qualified as T
import Data.URL.Template (Template (unTemplate), TemplateItem (..), Variable (unVariable), parseTemplate, printVariable)
import GHC.Generics
import Hasura.Prelude hiding (first)
import Hasura.RQL.Types.Headers (HeaderConf)
import Hasura.Tracing qualified as Tracing
import Language.Haskell.TH.Syntax (Lift)
import Network.HTTP.Client (Request)
import Network.HTTP.Types (RequestHeaders, ResponseHeaders)

--------------------------------------------------------------------------------

-- * User-facing configuration (metadata)

data OpenTelemetryConfig = OpenTelemetryConfig
  { _ocStatus :: OtelStatusConfig,
    _ocEnabledDataTypes :: Set OtelDataType,
    _ocExporterOtlp :: OtelExporterConfig,
    _ocBatchSpanProcessor :: OtelBatchSpanProcessorConfig
  }
  deriving stock (Eq, Show)

instance HasCodec OpenTelemetryConfig where
  codec =
    AC.object "OpenTelemetryConfig"
      $ OpenTelemetryConfig
      <$> optionalFieldWithDefault' "status" defaultOtelStatusConfig
      AC..= _ocStatus
        <*> optionalFieldWithDefault' "data_types" defaultOtelEnabledDataTypes
      AC..= _ocEnabledDataTypes
        <*> optionalFieldWithDefault' "exporter_otlp" defaultOtelExporterConfig
      AC..= _ocExporterOtlp
        <*> optionalFieldWithDefault' "batch_span_processor" defaultOtelBatchSpanProcessorConfig
      AC..= _ocBatchSpanProcessor

instance FromJSON OpenTelemetryConfig where
  parseJSON = J.withObject "OpenTelemetryConfig" $ \o ->
    OpenTelemetryConfig
      <$> o .:? "status" .!= defaultOtelStatusConfig
      <*> o .:? "data_types" .!= defaultOtelEnabledDataTypes
      <*> o .:? "exporter_otlp" .!= defaultOtelExporterConfig
      <*> o .:? "batch_span_processor" .!= defaultOtelBatchSpanProcessorConfig

emptyOpenTelemetryConfig :: OpenTelemetryConfig
emptyOpenTelemetryConfig =
  OpenTelemetryConfig
    { _ocStatus = defaultOtelStatusConfig,
      _ocEnabledDataTypes = defaultOtelEnabledDataTypes,
      _ocExporterOtlp = defaultOtelExporterConfig,
      _ocBatchSpanProcessor = defaultOtelBatchSpanProcessorConfig
    }

data OpenTelemetryConfigSubobject
  = OtelSubobjectAll
  | OtelSubobjectExporterOtlp
  | OtelSubobjectBatchSpanProcessor
  deriving stock (Eq, Generic, Ord, Show)
  deriving anyclass (Hashable)

data OtelStatus = OtelEnabled | OtelDisabled
  deriving stock (Eq, Bounded, Enum)

defaultOtelStatus :: OtelStatus
defaultOtelStatus = OtelDisabled

instance Show OtelStatus where
  show OtelEnabled = "enabled"
  show OtelDisabled = "disabled"

instance HasCodec OtelStatus where
  codec = boundedEnumCodec show

instance FromJSON OtelStatus where
  parseJSON = \case
    J.String s -> onLeft (parseOtelStatus s) (\_ -> fail $ invalidOtelStatusMessage (show s))
    v -> fail $ invalidOtelStatusMessage (show v)

instance ToJSON OtelStatus where
  toJSON status = J.String $ tshow status

data OtelStatusConfig
  = OtelStatusValue !OtelStatus
  | OtelStatusVariable !Variable
  deriving stock (Eq)

instance Show OtelStatusConfig where
  show (OtelStatusValue value) = show value
  show (OtelStatusVariable var) = T.unpack (printVariable var)

instance HasCodec OtelStatusConfig where
  codec = AC.bimapCodec dec enc AC.textCodec
    where
      dec = parseOtelStatusConfig
      enc = tshow

instance FromJSON OtelStatusConfig where
  parseJSON = J.withText "OtelStatusConfig" \s ->
    onLeft (parseOtelStatusConfig s) fail

instance ToJSON OtelStatusConfig where
  toJSON status =
    J.String
      $ case status of
        OtelStatusValue s -> tshow s
        OtelStatusVariable var -> printVariable var

defaultOtelStatusConfig :: OtelStatusConfig
defaultOtelStatusConfig = OtelStatusValue defaultOtelStatus

parseOtelStatus :: Text -> Either String OtelStatus
parseOtelStatus s
  | s == "enabled" = pure OtelEnabled
  | s == "disabled" = pure OtelDisabled
  | otherwise = Left $ invalidOtelStatusMessage (T.unpack s)

mkOtelStatusFromEnv :: OtelStatusConfig -> Env.Environment -> Either String OtelStatus
mkOtelStatusFromEnv (OtelStatusValue status) _ = Right status
mkOtelStatusFromEnv (OtelStatusVariable var) env = case Env.lookupEnv env strVar of
  Nothing -> Left $ "environment variable " <> strVar <> " does not exist"
  Just value -> parseOtelStatus (T.pack value)
  where
    strVar = T.unpack $ unVariable var

parseOtelStatusConfig :: Text -> Either String OtelStatusConfig
parseOtelStatusConfig s = case parseTemplate s of
  Left _ -> Left $ invalidOtelStatusMessage (T.unpack s)
  Right t -> case filter ((TIText "") /=) (unTemplate t) of
    [TIText txt] -> OtelStatusValue <$> parseOtelStatus txt
    [TIVariable var] -> Right $ OtelStatusVariable var
    _ -> Left $ invalidOtelStatusMessage (show t)

invalidOtelStatusMessage :: String -> String
invalidOtelStatusMessage = (<>) "OpenTelemetry status must be either \"enabled\" or \"disabled\", got "

data OtelDataType
  = OtelTraces
  | OtelMetrics
  | OtelLogs
  deriving stock (Eq, Ord, Show, Bounded, Enum)

instance HasCodec OtelDataType where
  codec = boundedEnumCodec \case
    OtelTraces -> "traces"
    OtelMetrics -> "metrics"
    OtelLogs -> "logs"

instance FromJSON OtelDataType where
  parseJSON = J.withText "OtelDataType" \case
    "traces" -> pure OtelTraces
    "metrics" -> pure OtelMetrics
    "logs" -> pure OtelLogs
    x -> fail $ "unexpected string '" <> show x <> "'."

instance ToJSON OtelDataType where
  toJSON = \case
    OtelTraces -> J.String "traces"
    OtelMetrics -> J.String "metrics"
    OtelLogs -> J.String "logs"

defaultOtelEnabledDataTypes :: Set OtelDataType
defaultOtelEnabledDataTypes = Set.empty

data OtelExporterConfig = OtelExporterConfig
  { _oecTracesEndpoint :: Maybe Text,
    _oecMetricsEndpoint :: Maybe Text,
    _oecLogsEndpoint :: Maybe Text,
    _oecProtocol :: OtlpProtocol,
    _oecHeaders :: [HeaderConf],
    _oecResourceAttributes :: [NameValue],
    _oecTracesPropagators :: [TracePropagator]
  }
  deriving stock (Eq, Show)

instance HasCodec OtelExporterConfig where
  codec =
    AC.object "OtelExporterConfig"
      $ OtelExporterConfig
      <$> optionalField "otlp_traces_endpoint" "Target URL for traces."
      AC..= _oecTracesEndpoint
        <*> optionalField "otlp_metrics_endpoint" "Target URL for metrics."
      AC..= _oecMetricsEndpoint
        <*> optionalField "otlp_logs_endpoint" "Target URL for logs."
      AC..= _oecLogsEndpoint
        <*> optionalFieldWithDefault "protocol" defaultOtelExporterProtocol "The transport protocol"
      AC..= _oecProtocol
        <*> optionalFieldWithDefault "headers" defaultOtelExporterHeaders "Export request headers."
      AC..= _oecHeaders
        <*> optionalFieldWithDefault "resource_attributes" defaultOtelExporterResourceAttributes "Resource attributes."
      AC..= _oecResourceAttributes
        <*> optionalFieldWithDefault "traces_propagators" defaultOtelExporterTracesPropagators "Trace propagators."
      AC..= _oecTracesPropagators

instance FromJSON OtelExporterConfig where
  parseJSON = J.withObject "OtelExporterConfig" $ \o -> do
    _oecTracesEndpoint <- o .:? "otlp_traces_endpoint" .!= Nothing
    _oecMetricsEndpoint <- o .:? "otlp_metrics_endpoint" .!= Nothing
    _oecLogsEndpoint <- o .:? "otlp_logs_endpoint" .!= Nothing
    _oecProtocol <- o .:? "protocol" .!= defaultOtelExporterProtocol
    _oecHeaders <- o .:? "headers" .!= defaultOtelExporterHeaders
    _oecResourceAttributes <- o .:? "resource_attributes" .!= defaultOtelExporterResourceAttributes
    _oecTracesPropagators <- o .:? "traces_propagators" .!= defaultOtelExporterTracesPropagators
    pure OtelExporterConfig {..}

instance ToJSON OtelExporterConfig where
  toJSON (OtelExporterConfig otlpTracesEndpoint otlpMetricsEndpoint otlpLogsEndpoint protocol headers resourceAttributes tracesPropagators) =
    J.object
      $ catMaybes
        [ ("otlp_traces_endpoint" .=) <$> otlpTracesEndpoint,
          ("otlp_metrics_endpoint" .=) <$> otlpMetricsEndpoint,
          ("otlp_logs_endpoint" .=) <$> otlpLogsEndpoint,
          Just $ "protocol" .= protocol,
          Just $ "headers" .= headers,
          Just $ "resource_attributes" .= resourceAttributes,
          Just $ "traces_propagators" .= tracesPropagators
        ]

defaultOtelExporterConfig :: OtelExporterConfig
defaultOtelExporterConfig =
  OtelExporterConfig
    { _oecTracesEndpoint = Nothing,
      _oecMetricsEndpoint = Nothing,
      _oecLogsEndpoint = Nothing,
      _oecProtocol = defaultOtelExporterProtocol,
      _oecHeaders = defaultOtelExporterHeaders,
      _oecResourceAttributes = defaultOtelExporterResourceAttributes,
      _oecTracesPropagators = defaultOtelExporterTracesPropagators
    }

data OtlpProtocol
  = OtlpProtocolHttpProtobuf
  deriving stock (Eq, Show, Bounded, Enum)

instance HasCodec OtlpProtocol where
  codec =
    ( boundedEnumCodec \case
        OtlpProtocolHttpProtobuf -> "http/protobuf"
    )
      <?> "Possible protocol to use with OTLP. Currently, only http/protobuf is supported."

instance FromJSON OtlpProtocol where
  parseJSON = J.withText "OtlpProtocol" \case
    "http/protobuf" -> pure OtlpProtocolHttpProtobuf
    "http/json" -> fail "http/json is not supported"
    "grpc" -> fail "gRPC is not supported"
    x -> fail $ "unexpected string '" <> show x <> "'."

instance ToJSON OtlpProtocol where
  toJSON = \case
    OtlpProtocolHttpProtobuf -> J.String "http/protobuf"

data NameValue = NameValue
  { nv_name :: Text,
    nv_value :: Text
  }
  deriving stock (Eq, Show)

instance HasCodec NameValue where
  codec =
    AC.object
      "OtelNameValue"
      ( NameValue
          <$> requiredField' "name"
          AC..= nv_name
            <*> requiredField' "value"
          AC..= nv_value
      )
      <?> "Internal helper type for JSON lists of key-value pairs"

instance ToJSON NameValue where
  toJSON (NameValue {nv_name, nv_value}) =
    J.object ["name" .= nv_name, "value" .= nv_value]

instance FromJSON NameValue where
  parseJSON = J.withObject "name-value pair" $ \o -> do
    nv_name <- o .: "name"
    nv_value <- o .: "value"
    pure NameValue {..}

data TracePropagator
  = B3
  | TraceContext
  deriving stock (Eq, Ord, Show, Bounded, Enum)

instance HasCodec TracePropagator where
  codec =
    ( boundedEnumCodec \case
        B3 -> "b3"
        TraceContext -> "tracecontext"
    )
      <?> "Possible trace propagators to use with OTLP"

instance FromJSON TracePropagator where
  parseJSON = J.withText "TracePropagator" \case
    "b3" -> pure B3
    "tracecontext" -> pure TraceContext
    x -> fail $ "unexpected string '" <> show x <> "'."

instance ToJSON TracePropagator where
  toJSON = \case
    B3 -> J.String "b3"
    TraceContext -> J.String "tracecontext"

defaultOtelExporterProtocol :: OtlpProtocol
defaultOtelExporterProtocol = OtlpProtocolHttpProtobuf

defaultOtelExporterHeaders :: [HeaderConf]
defaultOtelExporterHeaders = []

defaultOtelExporterResourceAttributes :: [NameValue]
defaultOtelExporterResourceAttributes = []

defaultOtelExporterTracesPropagators :: [TracePropagator]
defaultOtelExporterTracesPropagators = [B3]

newtype OtelBatchSpanProcessorConfig = OtelBatchSpanProcessorConfig
  { _obspcMaxExportBatchSize :: Int
  }
  deriving stock (Eq, Show)

instance HasCodec OtelBatchSpanProcessorConfig where
  codec =
    AC.object "OtelBatchSpanProcessorConfig"
      $ OtelBatchSpanProcessorConfig
      <$> optionalFieldWithDefault "max_export_batch_size" defaultMaxExportBatchSize "The maximum batch size of every export. Default 512."
      AC..= _obspcMaxExportBatchSize

instance FromJSON OtelBatchSpanProcessorConfig where
  parseJSON = J.withObject "OtelBatchSpanProcessorConfig" $ \o ->
    OtelBatchSpanProcessorConfig
      <$> o .:? "max_export_batch_size" .!= defaultMaxExportBatchSize

instance ToJSON OtelBatchSpanProcessorConfig where
  toJSON (OtelBatchSpanProcessorConfig maxExportBatchSize) =
    J.object ["max_export_batch_size" .= maxExportBatchSize]

defaultOtelBatchSpanProcessorConfig :: OtelBatchSpanProcessorConfig
defaultOtelBatchSpanProcessorConfig =
  OtelBatchSpanProcessorConfig
    { _obspcMaxExportBatchSize = defaultMaxExportBatchSize
    }

defaultMaxExportBatchSize :: Int
defaultMaxExportBatchSize = 512

$(makeLenses ''OpenTelemetryConfig)

--------------------------------------------------------------------------------

-- * Parsed configuration (schema cache)

data OpenTelemetryInfo = OpenTelemetryInfo
  { _otiExporterOtlp :: OtelExporterInfo,
    _otiBatchSpanProcessorInfo :: OtelBatchSpanProcessorInfo
  }

data OtelExporterInfo = OtelExporterInfo
  { _oteleiTracesBaseRequest :: Maybe Request,
    _oteleiMetricsBaseRequest :: Maybe Request,
    _oteleiLogsBaseRequest :: Maybe Request,
    _oteleiResourceAttributes :: Map Text Text,
    _oteleiTracesPropagator :: Tracing.Propagator RequestHeaders ResponseHeaders
  }

emptyOtelExporterInfo :: OtelExporterInfo
emptyOtelExporterInfo = OtelExporterInfo Nothing Nothing Nothing mempty mempty

data OtelBatchSpanProcessorInfo = OtelBatchSpanProcessorInfo
  { _obspiMaxExportBatchSize :: Int,
    _obspiMaxQueueSize :: Int
  }
  deriving (Lift)

getMaxExportBatchSize :: OtelBatchSpanProcessorInfo -> Int
getMaxExportBatchSize = _obspiMaxExportBatchSize

getMaxQueueSize :: OtelBatchSpanProcessorInfo -> Int
getMaxQueueSize = _obspiMaxQueueSize

-- | No-op stub — returns empty propagator. OTel disabled in stripped fork.
mkOtelTracesPropagator :: [TracePropagator] -> Tracing.HttpPropagator
mkOtelTracesPropagator _ = mempty

getOtelTracesPropagator :: OpenTelemetryInfo -> Tracing.HttpPropagator
getOtelTracesPropagator = _oteleiTracesPropagator . _otiExporterOtlp

defaultOtelBatchSpanProcessorInfo :: OtelBatchSpanProcessorInfo
defaultOtelBatchSpanProcessorInfo =
  OtelBatchSpanProcessorInfo
    { _obspiMaxExportBatchSize = 512,
      _obspiMaxQueueSize = 2048
    }

$(makeLenses ''OpenTelemetryInfo)
