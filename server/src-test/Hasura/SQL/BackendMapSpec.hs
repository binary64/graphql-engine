{-# LANGUAGE QuasiQuotes #-}

module Hasura.SQL.BackendMapSpec (spec) where

import Autodocodec (parseJSONViaCodec, toJSONViaCodec)
import Data.Aeson.QQ (aesonQQ)
import Data.Aeson.Types (parseEither)
import Hasura.Prelude
import Hasura.RQL.Types.Metadata.Common (BackendConfigWrapper (BackendConfigWrapper))
import Hasura.SQL.BackendMap (BackendMap)
import Hasura.SQL.BackendMap qualified as BM
import Test.Hspec
import Test.Hspec.Expectations.Json (shouldBeJson)

spec :: Spec
spec = describe "BackendMap" do
  it "serializes via Autodocodec" do
    let mssqlConfig = BM.singleton @'MSSQL @BackendConfigWrapper (BackendConfigWrapper ())

    let expected =
          [aesonQQ|
            {
              "mssql": []
            }
          |]
    let json = toJSONViaCodec mssqlConfig
    json `shouldBeJson` expected

    let decoded = parseEither (parseJSONViaCodec @(BackendMap BackendConfigWrapper)) json
    decoded `shouldBe` Right mssqlConfig
