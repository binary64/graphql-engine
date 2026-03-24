-- | Metadata API Actions relating to Source Kinds
module Hasura.RQL.DDL.SourceKinds
  ( -- * List Source Kinds
    ListSourceKinds (..),
    runListSourceKinds,
    agentSourceKinds,

    -- * Source Kind Info
    SourceKindInfo (..),
    SourceType (..),
    SourceKinds (..),

    -- * List Capabilities
    GetSourceKindCapabilities (..),
    runGetSourceKindCapabilities,
  )
where

--------------------------------------------------------------------------------

import Data.Aeson (FromJSON, ToJSON, (.:), (.:?), (.=))
import Data.Aeson qualified as J
import Data.Text.Extended (ToTxt (..))
import Data.Text.NonEmpty (NonEmptyText)
import Hasura.Base.Error qualified as Error
import Hasura.EncJSON (EncJSON)
import Hasura.EncJSON qualified as EncJSON
import Hasura.Prelude
import Hasura.RQL.Types.BackendType qualified as Backend
import Hasura.RQL.Types.Metadata qualified as Metadata
import Hasura.RQL.Types.SchemaCache qualified as SchemaCache

--------------------------------------------------------------------------------

data ListSourceKinds = ListSourceKinds

instance FromJSON ListSourceKinds where
  parseJSON = J.withObject "ListSourceKinds" (const $ pure ListSourceKinds)

instance ToJSON ListSourceKinds where
  toJSON ListSourceKinds = J.object []

--------------------------------------------------------------------------------

data SourceKindInfo = SourceKindInfo
  { _skiSourceKind :: Text,
    _skiDisplayName :: Maybe Text,
    _skiReleaseName :: Maybe Text,
    _skiBuiltin :: SourceType,
    _skiAvailable :: Bool
  }

instance FromJSON SourceKindInfo where
  parseJSON = J.withObject "SourceKindInfo" \o -> do
    _skiSourceKind <- o .: "kind"
    _skiDisplayName <- o .:? "display_name"
    _skiReleaseName <- o .:? "release_name"
    _skiBuiltin <- o .: "builtin"
    _skiAvailable <- o .: "available"
    pure SourceKindInfo {..}

instance ToJSON SourceKindInfo where
  toJSON SourceKindInfo {..} =
    J.object
      $ [ "kind" .= _skiSourceKind,
          "builtin" .= _skiBuiltin,
          "available" .= _skiAvailable
        ]
      ++ ["display_name" .= _skiDisplayName | has _skiDisplayName]
      ++ ["release_name" .= _skiReleaseName | has _skiReleaseName]
    where
      has :: Maybe Text -> Bool
      has x = not $ isNothing x || x == Just ""

data SourceType = Builtin | Agent

instance FromJSON SourceType where
  parseJSON = J.withBool "source type" \case
    True -> pure Builtin
    False -> pure Agent

instance ToJSON SourceType where
  toJSON Builtin = J.Bool True
  toJSON Agent = J.Bool False

--------------------------------------------------------------------------------

newtype SourceKinds = SourceKinds {unSourceKinds :: [SourceKindInfo]}
  deriving newtype (Semigroup, Monoid)

instance ToJSON SourceKinds where
  toJSON SourceKinds {..} = J.object ["sources" .= unSourceKinds]

-- | Agent source kinds are no longer supported (DataConnector removed).
agentSourceKinds :: (Metadata.MetadataM m) => m SourceKinds
agentSourceKinds = pure mempty

mkNativeSource :: Backend.BackendType -> Maybe SourceKindInfo
mkNativeSource b =
  Just
    SourceKindInfo
      { _skiSourceKind = fromMaybe (toTxt b) (Backend.backendShortName b),
        _skiBuiltin = Builtin,
        _skiDisplayName = Nothing,
        _skiReleaseName = Nothing,
        _skiAvailable = True
      }

builtinSourceKinds :: SourceKinds
builtinSourceKinds =
  SourceKinds $ mapMaybe mkNativeSource Backend.supportedBackends

-- | Collect 'SourceKindInfo' from Native backend types.
collectSourceKinds :: (Metadata.MetadataM m) => m SourceKinds
collectSourceKinds = pure builtinSourceKinds

runListSourceKinds ::
  forall m.
  ( Metadata.MetadataM m,
    MonadError Error.QErr m,
    SchemaCache.CacheRM m
  ) =>
  ListSourceKinds ->
  m EncJSON
runListSourceKinds ListSourceKinds = fmap EncJSON.encJFromJValue collectSourceKinds

--------------------------------------------------------------------------------

newtype GetSourceKindCapabilities = GetSourceKindCapabilities {_gskcKind :: NonEmptyText}

instance FromJSON GetSourceKindCapabilities where
  parseJSON = J.withObject "GetSourceKindCapabilities" \o -> do
    _gskcKind <- o .: "name"
    pure $ GetSourceKindCapabilities {..}

-- | List Backend Capabilities. DataConnector has been removed; always returns error.
runGetSourceKindCapabilities ::
  ( MonadError Error.QErr m,
    SchemaCache.CacheRM m
  ) =>
  GetSourceKindCapabilities ->
  m EncJSON
runGetSourceKindCapabilities GetSourceKindCapabilities {..} =
  Error.throw400 Error.NotSupported ("Source Kind capabilities are not supported in this build")
