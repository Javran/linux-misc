{-# LANGUAGE
    MultiWayIf
  , LambdaCase
  , OverloadedStrings
  #-}
module Main
  ( main
  ) where

import Control.Monad.State.Strict
import System.Environment
import System.Random.TF
import System.Random.TF.Instances

import qualified Data.Set as S
import qualified Data.Text as T

{-
  Use Willson's algorithm to generate mazes.

  TODO: use brick to implement a playable game?
 -}

type Coord = (Int, Int)

-- undirected, Edge a b where a <= b
data Edge = Edge Coord Coord
  deriving (Show, Eq, Ord)

mkEdge :: Coord -> Coord -> Edge
mkEdge a b = if a > b then Edge b a else Edge a b

{-
  indexing: U,D,L,R from most significant bit to the least one.
 -}
crosses :: T.Text
crosses = " ╶╴─╷┌┐┬╵└┘┴│├┤┼"

renderCross :: Bool -> Bool -> Bool -> Bool -> Char
renderCross up down left right = T.index crosses ind
  where
    ind = sum
      [ if up then 8 else 0
      , if down then 4 else 0
      , if left then 2 else 0
      , if right then 1 else 0
      ]

-- initial set consists of all nodes.
initMaze :: Int -> Int -> S.Set Coord
initMaze rows cols = S.fromList $ (,) <$> [0..rows-1] <*> [0..cols-1]

genNext :: Random a => (a, a) -> State TFGen a
genNext range =
  state $ \g -> let (v, g') = randomR range g in (v, g')

pickOneFromSet :: Ord a => S.Set a -> State TFGen (a, S.Set a)
pickOneFromSet s = do
  ind <- genNext (0, S.size s - 1)
  let x = S.toAscList s !! ind
  pure (x, S.delete x s)

-- cellSet: set of nodes contained in the maze
-- curPathRev: current path in reversed order.
randomWalk :: Int -> Int -> S.Set Coord -> [Coord] -> State TFGen [Coord]
randomWalk rows cols cellSet curPathRev = do
  -- INVARIANT: always non-empty.
  let (r,c):_ = curPathRev
  let alts = do
        (dr,dc) <- [(-1,0),(1,0),(0,-1),(0,1)]
        let (r'',c'') = (r + dr, c + dc)
        guard $ r'' >= 0 && r'' < rows && c'' >= 0 && c'' < cols
        pure (r'',c'')
      altsR = (0, length alts - 1)
  altInd <- genNext altsR
  let cell = alts !! altInd
  if
    | S.member cell cellSet ->
        -- next step walks into the maze, we are done.
        pure (cell:curPathRev)
    | elem cell curPathRev ->
        -- walks into current, need elimination
        randomWalk rows cols cellSet (cell : dropWhile (/=cell) curPathRev)
    | otherwise ->
        randomWalk rows cols cellSet (cell:curPathRev)

genMaze :: TFGen -> Int -> Int -> [] Edge
genMaze g rows cols = (`evalState` g) $ do
    let allCells = initMaze rows cols
    (x, initUnused) <- pickOneFromSet allCells
    fix (\loop curUnused curCellSet curEdges ->
      if S.null curUnused
        then pure curEdges
        else do
          (c, curUnused') <- pickOneFromSet curUnused
          path <- randomWalk rows cols curCellSet [c]
          let edges = zipWith mkEdge path (tail path)
              cells = S.fromList path
              curUnused'' = S.difference curUnused' cells
              curCellSet' = S.union curCellSet cells
              curEdges' = curEdges <> edges
          loop curUnused'' curCellSet' curEdges'
        )
      initUnused
      (S.singleton x)
      []

{-
  renderCorner rows cols edgeSet (r,c) renders
  the bottom right corner of cell (r,c).
  edgeSet should contain all inner connections of the maze.
 -}
renderCorner :: Int -> Int -> S.Set Edge -> Coord -> Char
renderCorner rows cols edgeSet (r,c) = renderCross up down left right
  where
    inside (r',c') = 0 <= r' && r' < rows && 0 <= c' && c' < cols
    tl = (r,c)
    tr = (r,c+1)
    bl = (r+1,c)
    br = (r+1,c+1)
    checkLoc x y
      | not (inside x) && not (inside y) = False
      | inside x && inside y = S.notMember (mkEdge x y) edgeSet
      | otherwise = True
    up = checkLoc tl tr
    down = checkLoc bl br
    left = checkLoc tl bl
    right = checkLoc tr br

renderMaze :: Int -> Int -> S.Set Edge -> [String]
renderMaze rows cols edgeSet =
    tail $ concatMap renderRow [-1..rows-1]
  where
    corner = renderCorner rows cols edgeSet
    cs = [-1..cols-1]
    renderRow :: Int -> [String]
    renderRow r = [topLine, bottomLine]
      where
        topLine = tail $ concatMap render cs
          where
            render c = ' ' : let e = mkEdge (r,c) (r,c+1)
                             in if S.member e edgeSet then " " else "│"
        bottomLine = tail $ concatMap render cs
          where
            render c =
              (let e = mkEdge tl bl
                in if S.member e edgeSet then " " else "─")
              <> [corner (r,c)]
              where
                tl = (r,c)
                bl = (r+1,c)

main :: IO ()
main = getArgs >>= \case
  [rRaw, cRaw]
    | [(r,"")] <- reads rRaw
    , [(c,"")] <- reads cRaw
    -> do
        g <- newTFGen
        let edgeSet = S.fromList $ genMaze g r c
        mapM_ putStrLn $ renderMaze r c edgeSet
  _ ->
    putStrLn "maze-gen <rows :: Int> <cols :: Int>"
