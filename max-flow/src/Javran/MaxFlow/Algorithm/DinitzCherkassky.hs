{-# LANGUAGE NamedFieldPuns #-}
{-# LANGUAGE TupleSections #-}

module Javran.MaxFlow.Algorithm.DinitzCherkassky where

{-
  TODO: Dinitz's algorithm improved by Boris Cherkassky.
 -}

import Control.Monad
import Control.Monad.Trans.RWS.CPS
import Control.Monad.Trans.Writer.CPS
import qualified Data.IntMap.Strict as IM
import qualified Data.IntSet as IS
import Data.Maybe
import Javran.MaxFlow.Algorithm.Dinitz (M, lookupArc)
import Javran.MaxFlow.Common
import Javran.MaxFlow.Types
-- import ListT
-- import Control.Monad.Trans.Class

computeRanks :: CapacityMap -> Flow -> Int -> IM.IntMap Int
computeRanks cMap fl dstNode =
  bfs
    (IS.singleton dstNode)
    [(dstNode, 0)]
    (IM.singleton dstNode 0)
  where
    {-
      reversed map for getting ranks.
      despite that edge goes in one direction, CapacityMap has keys
      in both directions so we are not missing any edges here.
     -}
    revMap :: IM.IntMap [Int]
    revMap = IM.fromListWith (<>) $ do
      (u, vs) <- IM.toList cMap
      v <- IM.keys vs
      (cur, cap) <- maybeToList $ lookupArc cMap fl (u, v)
      guard $ cap - cur > 0
      pure (v, [u])

    bfs discovered q acc = case q of
      [] -> acc
      (curNode, rank) : qRem ->
        let nextNodes =
              filter (`IS.notMember` discovered)
                . fromMaybe []
                $ revMap IM.!? curNode
            extras = fmap (,rank + 1) nextNodes
            discovered' = IS.union discovered (IS.fromList nextNodes)
            q' = qRem <> extras
            acc' = IM.union acc (IM.fromList extras)
         in bfs discovered' q' acc'

{-
  Note: phase DFS is a bit tricky to do here, as the algorithm
  requires it to resume at the starting node of first vanishing edge.
  Maybe we can try ListT or even ContT if we want full control of backtracking.

  Additional reading: https://wiki.haskell.org/ListT_done_right

  For whatever reason that I haven't get around to read, ListT in standard
  library is too strict so that extra path are explored rather than stopping
  at the first element available. So we'll probably take a look at list-t package.

  Note: what to do in this case?

  say we've found an augmenting path A -> B -> C -> D,
  and B -> C report vanishing - the expected behavior is
  that DFS backtracks to node B and resuming to try the edge next to B -> C.

  what we can probably do is to let the function return the vanishing node
  and DFS only resumes when vanishing node is the node we are visiting.

  at first glance we need only one path therefore Maybe might be sufficient,
  but then DFS does require that we visit multiple edges from the visiting node
  - therefore for now I'm thinking about ListT.

 -}

phase :: M (Maybe ())
phase = do
  (NetworkRep {nrSink, nrSource}, cMap) <- ask
  initFl <- get
  let ranks = computeRanks cMap initFl nrSink
  if IM.notMember nrSource ranks
    then pure Nothing
    else do
      let dfs :: Int -> Int -> [Int] -> M (Maybe Int)
          dfs curNode curRank path = do
            -- note that path should be constructed in reversed order
            -- with curNode as the first element.
            fl <- get
            if curNode == nrSink
              then
                {-
                  TODO: augument along this path
                  and return starting point of the first vanishing edge
                  (closer to source)
                 -}
                undefined
              else
                {-
                  TODO: visit deeper and examine resulting value to see
                  whether to end the current iteration or keep going.
                 -}
                undefined
            {-
            let nextRank = Just (curRank -1)
                notFull v = case lookupArc cMap fl (curNode, v) of
                  Nothing -> False
                  Just (cur, cap) -> cap - cur > 0
                nextNodes :: [Int]
                nextNodes =
                  filter (\v -> (ranks IM.!? v == nextRank) && notFull v)
                    . IM.keys
                    . fromMaybe IM.empty
                    $ cMap IM.!? curNode -}
            {-
              TODO: we need a proper computation context to carry out backtracking
             -}
      -- dfs nrSource (ranks IM.! nrSource) []
      pure $ Just ()

experiment :: NormalizedNetwork -> IO ()
experiment nn = do
  let nr@NetworkRep {nrSink} = getNR nn
      Right (cMap, fl) = prepare nr
  print $ computeRanks cMap fl nrSink