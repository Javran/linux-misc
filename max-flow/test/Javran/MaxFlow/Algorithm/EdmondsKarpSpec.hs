{-# LANGUAGE NamedFieldPuns #-}

module Javran.MaxFlow.Algorithm.EdmondsKarpSpec where

import Javran.MaxFlow.Algorithm.EdmondsKarp
import Javran.MaxFlow.Algorithm.TestPack
import Test.Hspec

spec :: Spec
spec = allPackSpec maxFlow
