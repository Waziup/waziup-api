{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE ViewPatterns #-}

module Keycloak.Types where

import Data.Aeson as JSON
import Data.Aeson.Types
import Data.Aeson.Casing
import Data.Text hiding (head, tail, map)
import GHC.Generics (Generic)
import Data.Maybe
import Data.Aeson.BetterErrors as AB
import Web.HttpApiData (FromHttpApiData(..), ToHttpApiData(..))
import Data.Text.Encoding
import Network.HTTP.Client as HC hiding (responseBody)
import Data.Monoid
import Control.Monad.Except (ExceptT)
import Control.Monad.Reader as R

type ResourceId = Text
type ResourceName = Text
type ScopeId = Text
type ScopeName = Text
type Scope = Text 

type Keycloak a = ReaderT KCConfig (ExceptT KCError IO) a

data KCError = HTTPError HttpException  -- ^ Keycloak returned an HTTP error.
             | ParseError Text          -- ^ Failed when parsing the response
             | EmptyError               -- ^ Empty error to serve as a zero element for Monoid.

data KCConfig = KCConfig {
  baseUrl :: Text,
  realm :: Text,
  clientId :: Text,
  clientSecret :: Text,
  adminLogin :: Text,
  adminPassword :: Text,
  guestLogin :: Text,
  guestPassword :: Text}

defaultConfig :: KCConfig
defaultConfig = KCConfig {
  baseUrl = "http://localhost:8080/auth",
  realm = "waziup",
  clientId = "api-server",
  clientSecret = "4e9dcb80-efcd-484c-b3d7-1e95a0096ac0",
  adminLogin = "cdupont",
  adminPassword = "password",
  guestLogin = "guest",
  guestPassword = "guest"}

type Path = Text
data Token = Token {unToken :: Text} deriving (Eq, Show)

instance FromHttpApiData Token where
  parseQueryParam = parseHeader . encodeUtf8
  parseHeader ((stripPrefix "Bearer ") . decodeUtf8 -> Just tok) = Right $ Token tok
  parseHeader _ = Left "cannot extract auth Bearer"

instance ToHttpApiData Token where
  toQueryParam (Token token) = "Bearer " <> token

data Permission = Permission 
  { rsname :: ResourceName,
    rsid   :: ResourceId,
    scopes :: [Scope]
  } deriving (Generic, Show)

parsePermission :: Parse e Permission
parsePermission = do
    rsname  <- AB.key "rsname" asText
    rsid    <- AB.key "rsid" asText
    scopes  <- AB.keyMay "scopes" (eachInArray asText) 
    return $ Permission rsname rsid (if (isJust scopes) then (fromJust scopes) else [])

--instance FromJSON Permission where
--  parseJSON (Object v) = do
--    rsname <- v .: "rsname"
--    rsid <- v .: "rsid"
--    scopes <- fromMaybe [] <$> v .:? "scopes"
--    return $ Permission rsname rsid (map (\s -> Scope Nothing s) scopes)
--  parseJSON _          = mzero

data Owner = Owner {
  ownId   :: Maybe Text,
  ownName :: Text
  } deriving (Generic, Show)

instance FromJSON Owner where
  parseJSON = genericParseJSON $ aesonDrop 3 snakeCase 
instance ToJSON Owner where
  toJSON = genericToJSON $ (aesonDrop 3 snakeCase) {omitNothingFields = True}

data Resource = Resource {
     resId      :: Maybe ResourceId,
     resName    :: ResourceName,
     resType    :: Maybe Text,
     resUris    :: [Text],
     resScopes  :: [Scope],
     resOwner   :: Owner,
     resOwnerManagedAccess :: Bool,
     resAttributes :: [Attribute]
  } deriving (Generic, Show)

instance FromJSON Resource where
  parseJSON = genericParseJSON $ aesonDrop 3 camelCase 
instance ToJSON Resource where
  toJSON = genericToJSON $ (aesonDrop 3 camelCase) {omitNothingFields = True}

data Attribute = Attribute {
  attName   :: Text,
  attValues :: [Text]
  } deriving (Generic, Show)

instance FromJSON Attribute where
  parseJSON = genericParseJSON $ aesonDrop 3 camelCase 
instance ToJSON Attribute where
  toJSON = genericToJSON $ (aesonDrop 3 camelCase) {omitNothingFields = True}


