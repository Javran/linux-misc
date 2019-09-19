{-# LANGUAGE RecordWildCards #-}
module Game.Reversi.Core
  ( GameState
  , Coord
  , Color
  , Board
  , initGameState
  , possibleMoves
  , applyMove
  , applyMoveOnGs
  , possibleMovesGs
  , gsBoard
  , gsTurn
  , gameConcludedGs
  ) where

import Control.Monad
import Data.Bifunctor
import Data.Bool
import Data.Maybe

import qualified Data.Map.Strict as M
import qualified Data.Set as S

type Coord = (Int {- row -}, Int {- col -}) -- note that this is 0-based index
type Color = Bool -- False for light, True for dark

type Board = M.Map Coord Color

data GameState
  = GameState
  { gsBoard :: Board
  , gsFreeCells :: S.Set Coord -- not yet occupied cells
  , gsTurn :: Color -- who's turn
  , gsNextMoves :: (S.Set Coord, S.Set Coord)
    -- (<next possible moves for light>, <next possible moves for dark>)
  }

allCoords :: S.Set Coord
allCoords = S.fromList [ (r,c) | r <- [0..7], c <- [0..7] ]

initBoard :: Board
initBoard = M.fromList [((3,3),False), ((4,4),False), ((3,4),True), ((4,3),True)]

initGameState :: GameState
initGameState = GameState {..}
  where
    gsBoard = initBoard
    gsFreeCells = S.difference allCoords (M.keysSet gsBoard)
    gsTurn = True -- dark always moves first.
    gsNextMoves = bimap pm pm (False, True)
      where
        pm = possibleMoves gsBoard

type Dir = (Int, Int)

dirs :: [] Dir
dirs = ds <> ((\(r,c) -> (-r,-c)) <$> ds)
  where
    ds = [(1,0),(0,1),(1,1),(1,-1)]

-- get the list of disks starting from coord, along dir.
getDisks :: Board -> Coord -> Dir -> [(Coord, Maybe Color)]
getDisks bd coord (dr,dc) = (\k -> (k, M.lookup k bd)) <$> coords
  where
    coords = iterate (\(r,c) -> (r+dr,c+dc)) coord

-- get the list of coordinates of disks that will be filpped
-- because of next moving being coord :: Coord.
applyMoveOnDir :: Board -> Color -> Coord -> Dir -> [Coord]
applyMoveOnDir bd who coord dir =
    if null owns
      then []
      else fst <$> oppos
  where
    (oppos, owns) = span ((/= who) . snd) consecutives
    consecutives =
      fmap (\(k, Just v) -> (k, v))
      -- only take consecutive non-empty values
      . takeWhile (isJust . snd)
      -- skip first element, which is coord itself.
      . tail $ getDisks bd coord dir

applyMove :: Board -> Color -> Coord -> Maybe (S.Set Coord, Board)
applyMove bd who coord = do
  guard $ M.notMember coord bd
  let flipCoords = dirs >>= \dir -> applyMoveOnDir bd who coord dir
      flipCoordsSet = S.fromList flipCoords
      bd' =
        S.foldr
          (\coord' -> M.insert coord' who)
          (M.insert coord who bd)
          flipCoordsSet
  guard . not . null $ flipCoords
  pure (flipCoordsSet, bd')

possibleMoves :: Board -> Color -> S.Set Coord
possibleMoves bd who =
  S.filter (\c -> isJust $ applyMove bd who c) allCoords

possibleMovesGs :: GameState -> S.Set Coord
possibleMovesGs gs = bool fst snd (gsTurn gs) . gsNextMoves $ gs

gameConcludedGs :: GameState -> Bool
gameConcludedGs GameState { gsNextMoves = (movesLight, movesDark)} =
  S.null movesLight && S.null movesDark

applyMoveOnGs :: GameState -> Coord -> Maybe GameState
applyMoveOnGs gs coord = do
  let who = gsTurn gs
      nextMoves = possibleMovesGs gs
  guard $ S.member coord nextMoves
  let -- TODO: safe destruct
      Just (_, bd') = applyMove (gsBoard gs) who coord
      freeCells = S.delete coord (gsFreeCells gs)
  pure GameState
    { gsBoard = bd'
    , gsFreeCells = freeCells
    , gsTurn = not who
    , gsNextMoves =
        let pm = possibleMoves bd'
        in bimap pm pm (False, True)
    }
