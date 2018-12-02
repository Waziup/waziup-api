{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE GeneralizedNewtypeDeriving #-}

module Orion.Types where

import Network.Wreq as W
import Control.Lens hiding ((.=))
import Data.Aeson as JSON
import Data.Aeson.BetterErrors as AB
import Data.Aeson.Casing
import Data.Aeson.Types
import Data.Text hiding (head, tail, find, map, filter)
import Data.Text.Encoding
import GHC.Generics (Generic)
import Data.Maybe
import Data.Monoid
import Control.Monad.Reader
import Data.Foldable as F
import Network.HTTP.Client (HttpException)
import Control.Monad.Except (ExceptT)

type Orion a = ReaderT OrionConfig (ExceptT OrionError IO) a

data OrionError = HTTPError HttpException  -- ^ Keycloak returned an HTTP error.
                | ParseError Text          -- ^ Failed when parsing the response
                | EmptyError               -- ^ Empty error to serve as a zero element for Monoid.

data OrionConfig = OrionConfig {
  orionUrl      :: Text,
  fiwareService :: Text} deriving (Show, Eq)

defaultOrionConfig = OrionConfig {
  orionUrl      = "http://localhost:1026",
  fiwareService = "waziup"}

newtype EntityId = EntityId {unEntityId :: Text} deriving (Show, Eq, Generic, ToJSON, FromJSON)
type EntityType = Text
newtype AttributeId = AttributeId {unAttributeId :: Text} deriving (Show, Eq, Generic, ToJSON, FromJSON)
type AttributeType = Text
newtype MetadataId = MetadataId {unMetadataId :: Text} deriving (Show, Eq, Generic, ToJSON, FromJSON)
type MetadataType = Text

data Entity = Entity {
  entId         :: EntityId,
  entType       :: EntityType,
  entAttributes :: [(AttributeId, Attribute)]
  } deriving (Generic, Show)

instance ToJSON Entity where
   toJSON (Entity entId entType attrs) = 
     object $ ["id" .= entId, 
               "type" .= entType] 
              <> map (\((AttributeId attId), att) -> attId .= toJSON att) attrs

parseEntity :: Parse e Entity
parseEntity = do
    eId   <- AB.key "id" asText
    eType <- AB.key "type" asText
    attrs <- catMaybes <$> forEachInObject parseAtt
    return $ Entity (EntityId eId) eType attrs where
      parseAtt "id" = return Nothing 
      parseAtt "type" = return Nothing 
      parseAtt k = do
        a <- parseAttribute
        return $ Just (AttributeId k, a)

data Attribute = Attribute {
  attType     :: AttributeType,
  attValue    :: Maybe Value,
  attMetadata :: [(MetadataId, Metadata)]
  } deriving (Generic, Show)

instance ToJSON Attribute where
   toJSON (Attribute attType attVal mets) = 
     object $ ["type" .= attType, 
               "value" .= attVal,
               "metadata" .= object (map (\((MetadataId metId), met) -> metId .= toJSON met) mets)]

parseAttribute :: Parse e Attribute
parseAttribute = do
    aType  <- AB.key    "type" asText
    aValue <- AB.keyMay "value" AB.asValue
    mets   <- AB.keyMay "metadata" parseMetadatas
    return $ Attribute aType aValue (F.concat mets)


data Metadata = Metadata {
  metType :: Maybe MetadataType,
  metValue :: Maybe Value
  } deriving (Generic, Show)

instance ToJSON Metadata where
   toJSON = genericToJSON $ aesonDrop 3 snakeCase

parseMetadatas :: Parse e [(MetadataId, Metadata)]
parseMetadatas = forEachInObject $ \a -> do
  m <- parseMetadata
  return (MetadataId a, m)

parseMetadata :: Parse e Metadata
parseMetadata = Metadata <$> AB.keyMay "type" asText
                         <*> AB.keyMay "value" AB.asValue

type Path = Text

