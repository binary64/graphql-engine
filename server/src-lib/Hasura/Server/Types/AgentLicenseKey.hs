module Hasura.Server.Types.AgentLicenseKey
  ( AgentLicenseKey (..),
  )
where

import Data.ByteString (ByteString)

-- | A license key used for authenticating with data connector agents.
-- Retained as a type stub after the DataConnector backend was removed,
-- since it is referenced by transport and execute layer function signatures.
newtype AgentLicenseKey = AgentLicenseKey {unAgentLicenseKey :: ByteString}
