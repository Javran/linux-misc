{-# LANGUAGE TypeFamilies #-}
{-# LANGUAGE NoMonomorphismRestriction #-}

module Lib
  ( main
  )
where

import Diagrams.Angle
import Diagrams.Backend.Cairo.CmdLine
import Diagrams.Prelude

main :: IO ()
main = mainWith example

example :: Diagram Cairo
example =
  polygon
    (with
       & polyType
         .~ PolySides
           [tau / 4 @@ rad, tau / 6 @@ rad, tau / 4 @@ rad, tau / 6 @@ rad]
           [1, 1, 1, 1])
