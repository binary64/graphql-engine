-- | Interface for a service for maintaining short-lived credentials, such as
-- access tokens or JWTs.
module Hasura.CredentialCache
  ( CredentialCache (..),
    AgentLicenseKey,
  )
where

import Control.Concurrent.STM
import Hasura.Prelude

newtype CredentialCache cred = CredentialCache
  { -- | Get the stored credential. Also returns an STM action for
    -- requesting a refresh of the credential, which, in turn, returns an STM
    -- action for waiting on the arrival of the fresh credential.
    getCredential :: STM (cred, STM (STM ()))
  }
  deriving stock (Functor)

-- | Stub type formerly used by the DataConnector backend for license key authentication.
-- Retained for API compatibility with transport layer signatures.
data AgentLicenseKey
