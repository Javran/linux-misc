{-# LANGUAGE OverloadedStrings #-}
module Main
  ( main
  ) where

import Prelude hiding (FilePath)

import Filesystem.Path.CurrentOS
import System.Exit
import Turtle.Prelude
import Data.Text.Encoding (encodeUtf8)
import Data.Aeson
import Data.Char
import Text.ParserCombinators.ReadP

import qualified Data.Text as T
import qualified Data.ByteString.Lazy as BSL

{-
  the corresponding object looks like:

  - tempX_input
  - tempX_max
  - tempX_crit

  In which X is an integer. sensors seems to simply group them by X,
  so for parsing individual ones it is fine to just ignore it.
 -}
data TempInfo
  = TempInfo
  { tiInput :: Int
  , tiMax :: Maybe Int
  , tiCrit :: Maybe Int
  }

parseTempField :: T.Text -> Maybe T.Text
parseTempField inp = case readP_to_S pTemp (T.unpack inp) of
    [(v, "")] -> Just v
    _ -> Nothing
  where
    pTemp :: ReadP T.Text
    pTemp =
      T.pack <$> (
        string "temp"
        *> munch1 isDigit
        *> char '_'
        *> munch1 (const True))

{-
  This program parses output from `sensors` and print out useful info
  regarding temperature readings.

  Eventually this will end up being info source to some xmonad components.

 -}
toText' :: FilePath -> T.Text
toText' = either id id . toText

{-
  naming here is a bit confusing, the following doc looks authoritative on this topic:

  https://www.kernel.org/doc/Documentation/hwmon/sysfs-interface
 -}

main :: IO ()
main = do
  Just sensorsBinPath <- which "sensors"
  (ExitSuccess, rawOut) <- procStrict (toText' sensorsBinPath) ["-j"] ""
  let parsed :: Object
      Right parsed = eitherDecode' . BSL.fromStrict . encodeUtf8 $ rawOut
  print parsed
