module Javran.MaxFlow.Algorithm.Internal
  ( M
  , RInfo
  , logM
  , showM
  , lookupArc
  , getArc
  )
where

{-
  Internally shared infrastructure among max flow algorithms
 -}

import Control.Monad.Except
import Control.Monad.Trans.RWS.CPS
import Control.Monad.Trans.Writer.CPS
import qualified Data.DList as DL
import qualified Data.IntMap.Strict as IM
import qualified Data.Map.Strict as M
import Data.Monoid
import qualified Data.Text as T
import Javran.MaxFlow.Types

type RInfo = (NetworkRep, CapacityMap)

{-
  We can certainly extend Sum Int to (DList Text, Sum Int)
  to support logging, which is awkward because every `tell` call will
  then consist of wrapping and unwrapping, with placeholder values (mempty),
  which isn't really ideal.
 -}

type M =
  RWST
    RInfo
    (Sum Int)
    Flow
    ( ExceptT
        String
        (Writer (DL.DList T.Text))
    )

logM :: T.Text -> M ()
logM t =
  lift $
    lift $
      Control.Monad.Trans.Writer.CPS.tell $
        DL.singleton t

showM :: Show a => a -> M ()
showM = logM . T.pack . show

{-
  Lookup current flow value and capacity of an arc.
  TODO: getArc should be preferred now that we are sharing M.
 -}
lookupArc :: CapacityMap -> Flow -> (Int, Int) -> Maybe (Int, Int)
lookupArc cMap fl p@(u, v) = do
  subCMap <- cMap IM.!? u
  cap <- subCMap IM.!? v
  {-
    direct lookup without fallback.
    constraint on types should be sufficient to ensure that
    this lookup won't fail.
   -}
  let cur =
        if cap == 0
          then - (fl M.! (v, u))
          else fl M.! p
  pure (cur, cap)

getArc :: (Int, Int) -> M (Int, Int)
getArc p = do
  cMap <- asks snd
  fl <- get
  case lookupArc cMap fl p of
    Just v -> pure v
    Nothing -> do
      let msg = "lookup failed for edge " <> show p
      logM (T.pack msg)
      lift $ throwError msg
