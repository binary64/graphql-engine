{-# OPTIONS_GHC -fno-warn-orphans #-}

-- | Postgres Instances API
--
-- Defines a 'Hasura.Server.API.Backend.BackendAPI' type class instance for Postgres.
module Hasura.Backends.Postgres.Instances.API () where

import Hasura.Prelude
import Hasura.RQL.Types.BackendType
import Hasura.SQL.AnyBackend (mkAnyBackend)
import Hasura.Server.API.Backend
import Hasura.Server.API.Metadata.Types

instance BackendAPI ('Postgres 'Vanilla) where
  metadataV1CommandParsers =
    concat
      [ sourceCommands @('Postgres 'Vanilla),
        tableCommands @('Postgres 'Vanilla),
        tablePermissionsCommands @('Postgres 'Vanilla),
        functionCommands @('Postgres 'Vanilla),
        functionPermissionsCommands @('Postgres 'Vanilla),
        relationshipCommands @('Postgres 'Vanilla),
        remoteRelationshipCommands @('Postgres 'Vanilla),
        eventTriggerCommands @('Postgres 'Vanilla),
        computedFieldCommands @('Postgres 'Vanilla),
        nativeQueriesCommands @('Postgres 'Vanilla),
        logicalModelsCommands @('Postgres 'Vanilla),
        [ commandParser
            "set_table_is_enum"
            ( RMPgSetTableIsEnum
                . mkAnyBackend @('Postgres 'Vanilla)
            )
        ],
        connectionTemplateCommands @('Postgres 'Vanilla)
      ]

