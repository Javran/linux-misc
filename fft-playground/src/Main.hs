{-
  An attempt to implement a basic case of Cooley-Tukey FFT algorithm.
 -}
{-# LANGUAGE ViewPatterns #-}
module Main
  ( main
  ) where

import Control.Monad
import Data.Complex
import Data.Function

import qualified Data.Vector as V
import qualified Data.Vector.Mutable as VM

type Cpx = Complex Double

-- e^((c pi i) * (k / N))
expAuxCommon :: Int -> Int -> Int -> Cpx
expAuxCommon c k n = cos theta :+ sin theta
  where
    theta = pi * fromIntegral (c * k) / fromIntegral n

-- Computes e^((-2 pi i) * (k / N))
expFft :: Int -> Int -> Cpx
expFft = expAuxCommon (-2)

-- Computes e^((2 pi i) * (k / N))
expIfft :: Int -> Int -> Cpx
expIfft = expAuxCommon 2

splitByParity :: V.Vector Cpx -> (V.Vector Cpx, V.Vector Cpx)
splitByParity vs = (evens, odds)
  where
    l = V.length vs
    oddCount = (l + 1) `quot` 2
    evenCount = l - oddCount
    evens =
      V.fromListN evenCount $ (vs V.!) <$> [0,2..]
    odds =
      V.fromListN oddCount $ (vs V.!) <$> [1,3..]

-- TODO: For now we assume that vector length is a power of two,
-- this can be easily extended to any length, by pretending out-of-range
-- values are 0.
gDitFft :: (Int -> Int -> Cpx) -> V.Vector Cpx -> V.Vector Cpx
gDitFft expF = fix $
  \impl vs ->
    let l = V.length vs
    in if l <= 1
      then vs
      else V.create $ do
        let (impl -> es, impl -> os) = splitByParity vs
            hf = l `quot` 2
        vec <- VM.unsafeNew l
        forM_ [0 .. hf - 1] $ \k -> do
          let a = es V.! k
              b = expF k l * os V.! k
          VM.unsafeWrite vec k (a + b)
          VM.unsafeWrite vec (hf + k) (a - b)
        pure vec

ditFft :: V.Vector Cpx -> V.Vector Cpx
ditFft = gDitFft expFft

iditFft' :: V.Vector Cpx -> V.Vector Cpx
iditFft' = gDitFft expIfft

iditFft :: V.Vector Cpx -> V.Vector Cpx
iditFft vs = V.map (/ fromIntegral l) (iditFft' vs)
  where
    l = V.length vs

main :: IO ()
main = do
  let cs = zipWith (:+) [0..15] [2,4..]
      vs = V.fromList cs
      vs1 = ditFft vs
      vs2 = iditFft vs1
  print vs1
  print vs2