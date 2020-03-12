{-# LANGUAGE OverloadedStrings #-}
module Main
  ( main
  ) where

import Turtle.Prelude
import Turtle.Pattern
import System.Exit
import Control.Applicative
import Control.Monad
import Data.Char

import qualified Data.Text as T

-- recognize from short output of xinput
patDevice :: Pattern (T.Text, Int)
patDevice = do
  let isJunk = (||) <$> isSpace <*> isSymbol
  skip $ some (satisfy isJunk)
  col0 <- plus anyChar
  -- safe because "plus" ensured that col0 is non-empty
  guard $ not . isJunk $ T.head col0
  guard $ T.last col0 /= ' '
  skip spaces1
  devId <-  "id=" *> decimal
  skip spaces1
  skip $ between "[" "]" (many anyChar)
  skip spaces
  eof
  pure (col0, devId)

main :: IO ()
main = do
  (ExitSuccess, raw) <- procStrict "xinput" ["list", "--short"] ""
  let touchscreenDevs = do
        rawLine <- T.lines raw
        d@(devName,_):_ <- [match patDevice rawLine]
        guard $ "touchscreen" `T.isInfixOf` T.toLower devName
        pure d

  mapM_ print touchscreenDevs
