{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE LambdaCase #-}
{-# LANGUAGE NamedFieldPuns #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE TupleSections #-}
{-# LANGUAGE ViewPatterns #-}

module Javran.MaxFlow.Algorithm.EdmondsKarp
  ( maxFlow
  )
where

import Control.Monad.Except
import Control.Monad.Trans.RWS.CPS
import Control.Monad.Trans.Writer.CPS
import Data.Bifunctor
import qualified Data.DList as DL
import qualified Data.IntMap.Strict as IM
import Data.List
import qualified Data.Map.Strict as M
import Data.Maybe
import Data.Monoid
import qualified Data.Sequence as Seq
import qualified Data.Text as T
import Javran.MaxFlow.Algorithm.Internal
import Javran.MaxFlow.Common
import Javran.MaxFlow.Types

type AugPath = ([((Int, Int), Bool)], Int)

type PreInfo = (Int, Int, Bool {- whether the actual direction is reversed -})

findAugPath
  :: CapacityMap
  -> Int
  -> Int
  -> FlowAssignment
  -> IM.IntMap PreInfo
  -> Seq.Seq Int
  -> Maybe AugPath
findAugPath caps netSrc netDst flow pre q = case Seq.viewl q of
  Seq.EmptyL -> do
    guard $ netDst `IM.member` pre
    let paths = unfoldr go netDst
          where
            go cur = do
              (src, diff, rev) <- pre IM.!? cur
              pure ((((src, cur), rev), diff), src)
        flowImp = minimum (fmap snd paths)
    pure (fmap fst paths, flowImp)
  src Seq.:< q' -> do
    subCaps <- caps IM.!? src
    let alts :: [(Int, Int, Bool)]
        alts = catMaybes $ fmap go (IM.keys subCaps)
          where
            go dst = do
              guard $ dst /= netSrc
              guard $ dst `IM.notMember` pre
              let (fl, cap) = fromJust $ lookupArc caps flow (src, dst)
              guard $ cap > fl
              pure (dst, cap - fl, cap == 0)
        pre' :: IM.IntMap PreInfo
        pre' =
          -- pre: pairs of (dst, (src, diff)), where diff is cap - fl
          IM.union pre (IM.fromList $ fmap (\(dst, diff, rev) -> (dst, (src, diff, rev))) alts)
        q'' = q' Seq.>< Seq.fromList (fmap (\(v, _, _) -> v) alts)
    findAugPath caps netSrc netDst flow pre' q''

findAugPathM :: M (Maybe AugPath)
findAugPathM = do
  (NetworkRep {nrSource, nrSink}, cMap) <- ask
  curFlow <- get
  pure $ findAugPath cMap nrSource nrSink curFlow IM.empty (Seq.singleton nrSource)

applyAugPathM :: AugPath -> M ()
applyAugPathM (xs, diff) = do
  when (null xs) $ do
    let msg = "error: augmenting path should not be empty"
    logM (T.pack msg)
    lift $ throwError msg
  let ((_, sinkNode), _) : _ = xs
      nodeVis ((srcNode, _), rev) =
        show srcNode <> if rev then " -r> " else " --> "
      pathVis = concatMap nodeVis (reverse xs) <> show sinkNode
  mapM_ applyDiff xs
  Control.Monad.Trans.RWS.CPS.tell $ Sum diff
  logM $
    T.pack "augmenting path: "
      <> T.pack pathVis
      <> ", with capacity "
      <> T.pack (show diff)
  where
    applyDiff :: ((Int, Int), Bool) -> M ()
    applyDiff ((src, dst), rev) =
      modify $
        if rev
          then M.alter (\(Just v) -> Just $ v - diff) (dst, src)
          else M.alter (\(Just v) -> Just $ v + diff) (src, dst)

solve :: M ()
solve = do
  r <- findAugPathM
  case r of
    Nothing -> pure ()
    Just augPath -> applyAugPathM augPath >> solve

maxFlow :: MaxFlowSolver
maxFlow (getNR -> nr) =
  case prepare nr of
    Left errMsg -> (Left errMsg, [])
    Right (cMap, initFlow) -> do
      second DL.toList $
        runWriter $
          fmap (second (\((), flow, Sum v) -> (v, flow, cMap))) $
            runExceptT $
              (runRWST
                 solve
                 (nr, cMap)
                 initFlow)
