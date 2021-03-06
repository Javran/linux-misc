module GeneralCategoryPredicates
  ( GeneralCategoryPredicates (..)
  , predicates
  , mk
  )
where

import Data.Char (GeneralCategory (..))
import Data.Functor.Contravariant

gcIsLetter :: GeneralCategory -> Bool
gcIsLetter c = case c of
  UppercaseLetter -> True
  LowercaseLetter -> True
  TitlecaseLetter -> True
  ModifierLetter -> True
  OtherLetter -> True
  _ -> False

gcIsMark :: GeneralCategory -> Bool
gcIsMark c = case c of
  NonSpacingMark -> True
  SpacingCombiningMark -> True
  EnclosingMark -> True
  _ -> False

gcIsNumber :: GeneralCategory -> Bool
gcIsNumber c = case c of
  DecimalNumber -> True
  LetterNumber -> True
  OtherNumber -> True
  _ -> False

gcIsPunctuation :: GeneralCategory -> Bool
gcIsPunctuation c = case c of
  ConnectorPunctuation -> True
  DashPunctuation -> True
  OpenPunctuation -> True
  ClosePunctuation -> True
  InitialQuote -> True
  FinalQuote -> True
  OtherPunctuation -> True
  _ -> False

gcIsSymbol :: GeneralCategory -> Bool
gcIsSymbol c = case c of
  MathSymbol -> True
  CurrencySymbol -> True
  ModifierSymbol -> True
  OtherSymbol -> True
  _ -> False

gcIsSeparator :: GeneralCategory -> Bool
gcIsSeparator c = case c of
  Space -> True
  LineSeparator -> True
  ParagraphSeparator -> True
  _ -> False

data GeneralCategoryPredicates i = GeneralCategoryPredicates
  { generalCategory :: i -> GeneralCategory
  , isLetter :: i -> Bool
  , isMark :: i -> Bool
  , isNumber :: i -> Bool
  , isPunctuation :: i -> Bool
  , isSymbol :: i -> Bool
  , isSeparator :: i -> Bool
  }

instance Contravariant GeneralCategoryPredicates where
  contramap f (GeneralCategoryPredicates g l m n p sy se) =
    GeneralCategoryPredicates
      (g . f)
      (l . f)
      (m . f)
      (n . f)
      (p . f)
      (sy . f)
      (se . f)

predicates :: GeneralCategoryPredicates GeneralCategory
predicates =
  GeneralCategoryPredicates
    { isLetter = gcIsLetter
    , isMark = gcIsMark
    , isNumber = gcIsNumber
    , isPunctuation = gcIsPunctuation
    , isSymbol = gcIsSymbol
    , isSeparator = gcIsSeparator
    , generalCategory = id
    }

mk :: (Char -> GeneralCategory) -> GeneralCategoryPredicates Char
mk = (>$< predicates)
