{-# OPTIONS_GHC -Wno-dodgy-exports #-}

module Hasura.GraphQL.Transport.Instances (module B) where

import Hasura.Backends.DataConnector.Adapter.Transport as B ()
import Hasura.Backends.Postgres.Instances.Transport as B ()
