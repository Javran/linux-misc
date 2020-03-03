{-# LANGUAGE LambdaCase #-}
module Main
  ( main
  ) where

import Control.Monad
import Control.Exception.Safe (displayException)
import Data.Text.Encoding (encodeUtf8)
import Dhall
import Hasql.Connection
import Hasql.Session
import System.Environment
import System.Exit

import qualified Data.Map.Strict as M
import qualified Data.Set as S
import qualified Data.Text as Text

import Config
import RecordScanner

import qualified Statement

acquireFromConfig :: PsqlConfig -> IO Connection
acquireFromConfig (PsqlConfig hst pt u pw db) =
    acquire sqlSettings >>= \case
      Left e -> do
        putStrLn "error while connecting to database."
        print e
        exitFailure
      Right conn -> pure conn
  where
    sqlSettings =
      settings
        (encodeUtf8 hst)
        (fromIntegral pt)
        (encodeUtf8 u)
        (encodeUtf8 pw)
        (encodeUtf8 db)

{-
  TODO: workflow:

  - scan and collect filenames from poi battle directory.
  - query database to see which of them are new records.
  - insert records into the database.

 -}

main :: IO ()
main = getArgs >>= \case
  [configPath] -> do
    pConf@ProgConfig
      { pcSqlConfig = sqlConfig
      , pcBattleDataPath = fp
      } <- inputFile auto configPath
    -- fetch battle records
    recordsPre <- getBattleRecordIds fp
    let records = M.fromList recordsPre
    conn <- acquireFromConfig sqlConfig
    putStrLn "connection acquired successfully."
    -- create the table
    do
      let sess = statement () Statement.createTable
      run sess conn >>= \case
        Left qe -> do
          putStrLn "query error"
          print qe
        Right _ -> pure ()
    do
      putStrLn $ "record count: " <> show (length recordsPre)
      let sess = statement (fst <$> recordsPre) Statement.queryMissingRecords
      run sess conn >>= \case
        Left qe -> do
          putStrLn "query error"
          print qe
        Right rIdsPre -> do
          putStrLn $ "missing records count: " <> show (length rIdsPre)
          -- importing all at once sounds like a terrible idea for testing,
          -- so instead let's just import a small bit and ramp it up if all goes well.
          let (rIds, dropped) = splitAt 128 rIdsPre
          unless (null dropped) $
            putStrLn $ "inserting only first " <> show (length rIds) <> " records."
          let missingRecords = M.restrictKeys records (S.fromList rIds)
          forM_ (M.toList missingRecords) $ \(rId, rPath) ->
            loadBattleRecord rPath >>= \case
              Left e -> do
                putStrLn $ "Failed to load " <> show rPath
                putStrLn $ "Exception: " <> displayException e
              Right record -> do
                let insertSess = statement record Statement.insertBattleRecord
                run insertSess conn >>= \case
                  Left se -> do
                    putStrLn "insertion error"
                    print se
                  Right () -> pure ()
    putStrLn "releasing connection ..."
    release conn
  _ -> do
    putStrLn "pb2psql <config.dhall>"
    exitFailure
