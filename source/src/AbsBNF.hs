-- Haskell data types for the abstract syntax.
-- Generated by the BNF converter.

module AbsBNF where

import Prelude (Char, Double, Int, Integer, String)
import qualified Prelude as C (Eq, Ord, Show, Read)

newtype Identifier = Identifier ((Int, Int), String)
  deriving (C.Eq, C.Ord, C.Show, C.Read)

data LGrammar = LGr [LDef]
  deriving (C.Eq, C.Ord, C.Show, C.Read)

data LDef
    = DefAll Def | DefSome [Identifier] Def | LDefView [Identifier]
  deriving (C.Eq, C.Ord, C.Show, C.Read)

data Grammar = Grammar [Def]
  deriving (C.Eq, C.Ord, C.Show, C.Read)

data Def
    = Rule Label Cat [Item]
    | Comment String
    | Comments String String
    | Internal Label Cat [Item]
    | Token Identifier Reg
    | PosToken Identifier Reg
    | Entryp [Identifier]
    | Separator MinimumSize Cat String
    | Terminator MinimumSize Cat String
    | Delimiters Cat String String Separation MinimumSize
    | Coercions Identifier Integer
    | Rules Identifier [RHS]
    | Function Identifier [Arg] Exp
    | Layout [String]
    | LayoutStop [String]
    | LayoutTop
  deriving (C.Eq, C.Ord, C.Show, C.Read)

data Item = Terminal String | NTerminal Cat
  deriving (C.Eq, C.Ord, C.Show, C.Read)

data Cat = ListCat Cat | IdCat Identifier
  deriving (C.Eq, C.Ord, C.Show, C.Read)

data Label
    = LabNoP LabelId
    | LabP LabelId [ProfItem]
    | LabPF LabelId LabelId [ProfItem]
    | LabF LabelId LabelId
  deriving (C.Eq, C.Ord, C.Show, C.Read)

data LabelId = Id Identifier | Wild | ListE | ListCons | ListOne
  deriving (C.Eq, C.Ord, C.Show, C.Read)

data ProfItem = ProfIt [IntList] [Integer]
  deriving (C.Eq, C.Ord, C.Show, C.Read)

data IntList = Ints [Integer]
  deriving (C.Eq, C.Ord, C.Show, C.Read)

data Arg = Arg Identifier
  deriving (C.Eq, C.Ord, C.Show, C.Read)

data Separation = SepNone | SepTerm String | SepSepar String
  deriving (C.Eq, C.Ord, C.Show, C.Read)

data Exp
    = Cons Exp Exp
    | App Identifier [Exp]
    | Var Identifier
    | LitInt Integer
    | LitChar Char
    | LitString String
    | LitDouble Double
    | List [Exp]
  deriving (C.Eq, C.Ord, C.Show, C.Read)

data RHS = RHS [Item]
  deriving (C.Eq, C.Ord, C.Show, C.Read)

data MinimumSize = MNonempty | MEmpty
  deriving (C.Eq, C.Ord, C.Show, C.Read)

data Reg
    = RAlt Reg Reg
    | RMinus Reg Reg
    | RSeq Reg Reg
    | RStar Reg
    | RPlus Reg
    | ROpt Reg
    | REps
    | RChar Char
    | RAlts String
    | RSeqs String
    | RDigit
    | RLetter
    | RUpper
    | RLower
    | RAny
  deriving (C.Eq, C.Ord, C.Show, C.Read)

