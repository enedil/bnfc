{-
    BNF Converter: Antlr4 Java 1.8 Generator
    Copyright (C) 2004  Author:  Markus Forsberg, Michael Pellauer,
                                 Bjorn Bringert

    Description   : This module generates the ANTLR .g4 input file. It
                    follows the same basic structure of CFtoHappy.

    Author        : Gabriele Paganelli (gapag@distruzione.org)
    Created       : 15 Oct, 2015

-}

{-# LANGUAGE LambdaCase #-}

module BNFC.Backend.Java.CFtoAntlr4Parser ( cf2AntlrParse ) where

import Data.Foldable ( toList )
import Data.List     ( intercalate )
import Data.Maybe

import BNFC.CF
import BNFC.Options ( RecordPositions(..) )
import BNFC.Utils   ( (+++), (+.+), applyWhen )

import BNFC.Backend.Java.Utils
import BNFC.Backend.Common.NamedVariables

-- Type declarations

-- | A definition of a non-terminal by all its rhss,
--   together with parse actions.
data PDef = PDef
  { _pdNT   :: Maybe String
      -- ^ If given, the name of the lhss.  Usually computed from 'pdCat'.
  , _pdCat  :: Cat
      -- ^ The category to parse.
  , _pdAlts :: [(Pattern, Action, Maybe Fun)]
      -- ^ The possible rhss with actions.  If 'null', skip this 'PDef'.
      --   Where 'Nothing', skip ANTLR rule label.
  }
type Rules       = [PDef]
type Pattern     = String
type Action      = String
type MetaVar     = (String, Cat)

-- | Creates the ANTLR parser grammar for this CF.
--The environment comes from CFtoAntlr4Lexer
cf2AntlrParse :: String -> String -> CF -> RecordPositions -> KeywordEnv -> String
cf2AntlrParse packageBase packageAbsyn cf _ env = unlines $ concat
  [ [ header
    , tokens
    , ""
    -- Generate start rules [#272]
    -- _X returns [ dX result ] : x=X EOF { $result = $x.result; }
    , prRules packageAbsyn $ map entrypoint $ toList $ allEntryPoints cf
    -- Generate regular rules
    , prRules packageAbsyn $ rulesForAntlr4 packageAbsyn cf env
    ]
  ]
  where
    header :: String
    header = unlines
        [ "// -*- Java -*- Parser definition for use with ANTLRv4"
        , "parser grammar" +++ identifier ++ "Parser;"
        ]
    tokens :: String
    tokens = unlines
        [ "options {"
        , "  tokenVocab = "++identifier++"Lexer;"
        , "}"
        ]
    identifier = getLastInPackage packageBase

-- | Generate start rule to help ANTLR.
--
--   @start_X returns [ X result ] : x=X EOF { $result = $x.result; } # Start_X@
--
entrypoint :: Cat -> PDef
entrypoint cat =
  PDef (Just nt) cat [(pat, act, fun)]
  where
  nt  = firstLowerCase $ startSymbol $ identCat cat
  pat = "x=" ++ catToNT cat +++ "EOF"
  act = "$result = $x.result;"
  fun = Nothing -- No ANTLR Rule label, ("Start_" ++ identCat cat) conflicts with lhs.

--The following functions are a (relatively) straightforward translation
--of the ones in CFtoHappy.hs
rulesForAntlr4 :: String -> CF -> KeywordEnv -> Rules
rulesForAntlr4 packageAbsyn cf env = map mkOne getrules
  where
    getrules          = ruleGroups cf
    mkOne (cat,rules) = constructRule packageAbsyn cf env rules cat

-- | For every non-terminal, we construct a set of rules. A rule is a sequence of
-- terminals and non-terminals, and an action to be performed.
constructRule :: String -> CF -> KeywordEnv -> [Rule] -> NonTerminal -> PDef
constructRule packageAbsyn cf env rules nt =
  PDef Nothing nt $
    [ ( p
      , generateAction packageAbsyn nt (funRule r) m b
      , Nothing  -- labels not needed for BNFC-generated AST parser
      -- , Just label
      -- -- Did not work:
      -- -- , if firstLowerCase (getLabelName label)
      -- --   == getRuleName (firstLowerCase $ identCat nt) then Nothing else Just label
      )
    | (index, r0) <- zip [1..] rules
    , let b      = isConsFun (funRule r0) && elem (valCat r0) (cfgReversibleCats cf)
    , let r      = applyWhen b revSepListRule r0
    , let (p,m0) = generatePatterns index env r
    , let m      = applyWhen b reverse m0
    -- , let label  = funRule r
    ]

-- Generates a string containing the semantic action.
generateAction :: IsFun f => String -> NonTerminal -> f -> [MetaVar]
               -> Bool   -- ^ Whether the list should be reversed or not.
                         --   Only used if this is a list rule.
               -> Action
generateAction packageAbsyn nt f ms rev
    | isNilFun f = "$result = new " ++ c ++ "();"
    | isOneFun f = "$result = new " ++ c ++ "(); $result.addLast("
        ++ p_1 ++ ");"
    | isConsFun f = "$result = " ++ p_2 ++ "; "
                           ++ "$result." ++ add ++ "(" ++ p_1 ++ ");"
    | isCoercion f = "$result = " ++  p_1 ++ ";"
    | isDefinedRule f = "$result = " ++ packageAbsyn ++ "Def." ++ sanitize (funName f)
                        ++ "(" ++ intercalate "," (map resultvalue ms) ++ ");"
    | otherwise = "$result = new " ++ c
                  ++ "(" ++ intercalate "," (map resultvalue ms) ++ ");"
   where
     sanitize          = getRuleName
     c                 = packageAbsyn ++ "." ++
                            if isNilFun f || isOneFun f || isConsFun f
                            then identCat (normCat nt) else funName f
     p_1               = resultvalue $ ms!!0
     p_2               = resultvalue $ ms!!1
     add               = if rev then "addLast" else "addFirst"
     gettext           = "getText()"
     removeQuotes x    = "substring(1, "++ x +.+ gettext +.+ "length()-1)"
     parseint x        = "Integer.parseInt("++x++")"
     parsedouble x     = "Double.parseDouble("++x++")"
     charat            = "charAt(1)"
     resultvalue (n,c) = case c of
                          TokenCat "Ident"   -> n'+.+gettext
                          TokenCat "Integer" -> parseint $ n'+.+gettext
                          TokenCat "Char"    -> n'+.+gettext+.+charat
                          TokenCat "Double"  -> parsedouble $ n'+.+gettext
                          TokenCat "String"  -> n'+.+gettext+.+removeQuotes n'
                          _         -> (+.+) n' (if isTokenCat c then gettext else "result")
                          where n' = '$':n

-- | Generate patterns and a set of metavariables indicating
-- where in the pattern the non-terminal
-- >>> generatePatterns 2 [] $ npRule "myfun" (Cat "A") [] Parsable
-- (" /* empty */ ",[])
-- >>> generatePatterns 3 [("def", "_SYMB_1")] $ npRule "myfun" (Cat "A") [Right "def", Left (Cat "B")] Parsable
-- ("_SYMB_1 p_3_2=b",[("p_3_2",B)])
generatePatterns :: Int -> KeywordEnv -> Rule -> (Pattern,[MetaVar])
generatePatterns ind env r =
  case rhsRule r of
    []  -> (" /* empty */ ", [])
    its -> ( unwords $ mapMaybe (uncurry mkIt) nits
           , [ (var i, cat) | (i, Left cat) <- nits ]
           )
      where
      nits   = zip [1 :: Int ..] its
      var i  = "p_" ++ show ind ++"_"++ show i   -- TODO: is ind needed for ANTLR?
      mkIt i = \case
        Left  c -> Just $ var i ++ "=" ++ catToNT c
        Right s -> lookup s env

catToNT :: Cat -> String
catToNT = \case
  TokenCat "Ident"   -> "IDENT"
  TokenCat "Integer" -> "INTEGER"
  TokenCat "Char"    -> "CHAR"
  TokenCat "Double"  -> "DOUBLE"
  TokenCat "String"  -> "STRING"
  c | isTokenCat c   -> identCat c
    | otherwise      -> firstLowerCase $ getRuleName $ identCat c

-- | Puts together the pattern and actions and returns a string containing all
-- the rules.
prRules :: String -> Rules -> String
prRules packabs = concatMap $ \case

  -- No rules: skip.
  PDef _mlhs _nt []         -> ""

  -- At least one rule: print!
  PDef mlhs nt (rhs : rhss) -> unlines $ concat

    -- The definition header: lhs and type.
    [ [ unwords [ fromMaybe nt' mlhs
                , "returns" , "[" , packabs+.+normcat , "result" , "]"
                ]
      ]
    -- The first rhs.
    , alternative "  :" rhs
    -- The other rhss.
    , concatMap (alternative "  |") rhss
    -- The definition footer.
    , [ "  ;" ]
    ]
    where
    alternative sep (p, a, label) = concat
      [ [ unwords [ sep , p ] ]
      , [ unwords [ "    {" , a , "}" ] ]
      , [ unwords [ "    #" , antlrRuleLabel l ] | Just l <- [label] ]
      ]
    catid              = identCat nt
    normcat            = identCat (normCat nt)
    nt'                = getRuleName $ firstLowerCase catid
    antlrRuleLabel :: Fun -> String
    antlrRuleLabel fnc
      | isNilFun fnc   = catid ++ "_Empty"
      | isOneFun fnc   = catid ++ "_AppendLast"
      | isConsFun fnc  = catid ++ "_PrependFirst"
      | isCoercion fnc = "Coercion_" ++ catid
      | otherwise      = getLabelName fnc
