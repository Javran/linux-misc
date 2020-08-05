{-# LANGUAGE ScopedTypeVariables #-}

module Main
  ( main
  )
where

import Control.Monad
import Control.Monad.Trans
import Data.Random
import Data.Random.Source.MWC
import qualified Data.Vector as V
import qualified Data.Vector.Mutable as VM

-- experiment to generate different random distributions

-- a Double is generated and multipled by `scale` to give range from 0 to scale-1
scaledExperiment :: Int -> Int -> IO (V.Vector Int)
scaledExperiment scale totalCount = do
  mv <- VM.replicate scale 0
  let roll :: RVarT IO ()
      roll = do
        (d :: Double) <- rvarT (Normal 0.5 0.2)
        when (d >= 0 && d < 1) $ do
          let result :: Int
              result = floor (fromIntegral scale * d)
          lift $ VM.modify mv succ result
  g <- create -- TODO: use a random source
  _ <- runRVarT (replicateM totalCount roll) g
  V.unsafeFreeze mv

main :: IO ()
main = scaledExperiment 100 100000 >>= print
