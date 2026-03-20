{-# LANGUAGE OverloadedStrings #-}

-- | Static remote schema introspection from local files.
--
-- Introspection results are loaded once at boot from
-- @/etc/hasura/introspection/<schema-name>.json@ and held in memory
-- forever. No HTTP calls, no cache invalidation, no re-introspection.
module Hasura.RemoteSchema.SchemaCache.LocalIntrospection
  ( loadLocalIntrospection,
    localIntrospectionDir,
  )
where

import Control.Exception (try)
import Data.ByteString.Lazy qualified as BL
import Data.HashMap.Strict qualified as HashMap
import Data.Text qualified as T
import Data.Text.NonEmpty (mkNonEmptyText)
import Hasura.Prelude
import Hasura.RemoteSchema.Metadata.Base (RemoteSchemaName (..))
import System.Directory (doesDirectoryExist, listDirectory)
import System.FilePath (dropExtension, takeExtension, (</>))

localIntrospectionDir :: FilePath
localIntrospectionDir = "/etc/hasura/introspection"

-- | Load all introspection files from disk. Called once at boot.
loadLocalIntrospection :: IO (HashMap.HashMap RemoteSchemaName BL.ByteString)
loadLocalIntrospection = do
  exists <- doesDirectoryExist localIntrospectionDir
  if not exists
    then pure HashMap.empty
    else do
      files <- listDirectory localIntrospectionDir
      let jsonFiles = filter (\f -> takeExtension f == ".json") files
      fmap (HashMap.fromList . catMaybes) $ for jsonFiles $ \file -> do
        let nameText = T.pack (dropExtension file)
            fullPath = localIntrospectionDir </> file
        case mkNonEmptyText nameText of
          Nothing -> pure Nothing
          Just net -> do
            result <- try @SomeException $ BL.readFile fullPath
            case result of
              Left _err -> pure Nothing
              Right bytes -> pure $ Just (RemoteSchemaName net, bytes)
