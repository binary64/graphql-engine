{-# OPTIONS_GHC -Wno-dodgy-exports #-}

module Hasura.GraphQL.Execute.Instances (module B) where

import Hasura.Backends.DataConnector.Adapter.Execute as B ()
import Hasura.Backends.Postgres.Instances.Execute as B ()
