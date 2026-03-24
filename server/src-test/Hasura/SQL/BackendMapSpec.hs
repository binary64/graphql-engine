module Hasura.SQL.BackendMapSpec (spec) where

import Autodocodec (parseJSONViaCodec, toJSONViaCodec)
import Data.Aeson.QQ (aesonQQ)
import Data.Aeson.Types (parseEither)
import Hasura.Prelude
import Hasura.RQL.Types.BackendType (BackendType (..), PostgresKind (..))
import Hasura.RQL.Types.Metadata.Common (BackendConfigWrapper (BackendConfigWrapper))
import Hasura.SQL.BackendMap (BackendMap)
import Hasura.SQL.BackendMap qualified as BM
import Test.Hspec
import Test.Hspec.Expectations.Json (shouldBeJson)

spec :: Spec
spec = describe "BackendMap" do
  it "serializes via Autodocodec" do
    let postgresConfig = BM.singleton @('Postgres 'Vanilla) @BackendConfigWrapper (BackendConfigWrapper ())

    let expected =
          [aesonQQ|
            {
              "postgres": null
            }
          |]
    let json = toJSONViaCodec postgresConfig
    json `shouldBeJson` expected

    let decoded = parseEither (parseJSONViaCodec @(BackendMap BackendConfigWrapper)) json
    decoded `shouldBe` Right postgresConfig
