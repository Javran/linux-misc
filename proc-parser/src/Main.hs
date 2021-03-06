{-# LANGUAGE BangPatterns #-}
module Main
  ( main
  ) where

{-
  Proof of concept of holding file handle without closing
  on pseudo file systems like procfs and sysfs.

  Few places that we might want to try:

  - /proc/cpuinfo
  - /proc/stat
  - /proc/net/dev
  - /proc/meminfo

  Well we don't actually need to try sysfs - it was
  required for dealing with battery, but there's no need for Senatus.

 -}

import Control.Monad
import Data.Attoparsec.ByteString.Char8
import Data.Function
import Control.DeepSeq
import System.IO
import Data.Time.Clock
import Text.Printf

import qualified Data.ByteString.Char8 as BSC

import ProcFsReader hiding (main)

reseekAndParse :: Handle -> Parser a -> IO a
reseekAndParse h p = do
  hSeek h AbsoluteSeek 0
  let bufSize = 512
  fix (\loop parseNext -> do
    inp <- BSC.hGet h bufSize
    case parseNext inp of
      Fail _ ctxt errs ->
        error $ "Parsing failed, context: " <> show ctxt <> "error: " <> show errs
      Partial parseK ->
        loop parseK
      Done _ r ->
        pure r) (parse p)

reseekContent :: Handle -> IO BSC.ByteString
reseekContent h = do
  hSeek h AbsoluteSeek 0
  -- we need to do this in low-level fashion because
  -- hGetContents will automatically close the file
  -- so that it needs to be re-opened every time.

  -- Looks like large buffer (> 16384-ish) is slower,
  -- presumbly there are allocation penalty involved.
  let bufSize = 512
  dlist <- fix
    (\readMore acc -> do
        b <- hIsEOF h
        if b
          then pure acc
          else do
            raw <- BSC.hGetNonBlocking h bufSize
            readMore (acc . (raw:))
          ) id
  pure (BSC.concat (dlist []))

readProc :: IO BSC.ByteString
readProc = do
  h <- openFile "/proc/cpuinfo" ReadMode
  BSC.hGetContents h -- no need of closing as hGetContents does that automatically.

{-
  Few conclusions on this:

  - parsingTestReseek is slower than parsingTestNormal, I guess the problem being
    there are too many context switches between feeding buffers and reading from IO.
  - I suspect tuning the buffer size will impact performance of re-seeking approach,
    but this is another layer of complication that I don't really want to deal with
    (and unjustified, given that the performance doesn't seem to matter that much).
 -}
parsingTestNormal, parsingTestReseek :: NFData a => Int -> FilePath -> Parser a -> IO ()
parsingTestNormal nTimes fPath parser = replicateM_ nTimes doParsing
  where
    doParsing = do
      h <- openFile fPath ReadMode
      raw <- BSC.hGetContents h
      pure $ rnf (parseOnly parser)

parsingTestReseek nTimes fPath parser = do
  h <- openFile fPath ReadMode
  replicateM_ nTimes $ do
    r <- reseekAndParse h parser
    pure (rnf r)
  hClose h

mainNormal :: Int -> IO ()
mainNormal opCount = replicateM_ opCount $ do
  raw <- readProc
  putStrLn $ "Got " <> show (BSC.length raw) <> " bytes."

mainReseek :: Int -> IO ()
mainReseek opCount = do
  h <- openFile "/proc/cpuinfo" ReadMode
  replicateM_ opCount $ do
    raw <- reseekContent h
    putStrLn $ "Got " <> show (BSC.length raw) <> " bytes."
  hClose h

measuredAction :: IO r -> IO r
measuredAction act = do
  tStart <- getCurrentTime
  r <- act
  tEnd <- getCurrentTime
  printf "Action completed in %.4f\n" (realToFrac $ diffUTCTime tEnd tStart :: Double)
  pure r

main :: IO ()
main = do
  putStrLn "normal"
  measuredAction $
    parsingTestNormal 10000 "/proc/cpuinfo" parseCpuFreqs
  putStrLn "reseek"
  measuredAction $
    parsingTestReseek 10000 "/proc/cpuinfo" parseCpuFreqs

{-
  Note: so far mainNormal vs. mainReseek doesn't appear to have significant difference.
  but mainReseek defintely requires some tuning on bufSize to get a little bit better on performance.

  However, this situation might change once we use attoparsec to parse the data on the fly,
  for now the re-seeking method has to piece things together with concat, which still require some copy
  while we don't need to worry about that for hGetContents.
 -}
-- main :: IO ()
-- main = mainNormal 10000
-- main = mainReseek 10000
