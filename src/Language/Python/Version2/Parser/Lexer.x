{
-----------------------------------------------------------------------------
-- |
-- Module      : Language.Python.Version2.Parser.Lexer 
-- Copyright   : (c) 2009 Bernie Pope 
-- License     : BSD-style
-- Maintainer  : bjpop@csse.unimelb.edu.au
-- Stability   : experimental
-- Portability : ghc
--
-- Implementation of a lexer for Python version 2.x programs. Generated by
-- alex. 
-----------------------------------------------------------------------------

module Language.Python.Version2.Parser.Lexer 
   (initStartCodeStack, lexToken, endOfFileToken, lexCont) where

import Language.Python.Common.Token as Token
import Language.Python.Common.ParserMonad hiding (location)
import Language.Python.Common.SrcLocation
import Language.Python.Common.LexerUtils
import qualified Data.Map as Map
import Control.Monad (liftM)
import Data.List (foldl')
import Numeric (readHex, readOct)
import qualified Data.ByteString.Char8 as BS (pack)
}

-- character sets
$lf = \n  -- line feed
$cr = \r  -- carriage return
$eol_char = [$lf $cr] -- any end of line character
$not_eol_char = ~$eol_char -- anything but an end of line character
$white_char   = [\ \n\r\f\v\t]
$white_no_nl = $white_char # $eol_char
$ident_letter = [a-zA-Z_]
$digit    = 0-9
$non_zero_digit = 1-9
$oct_digit = 0-7
$hex_digit = [$digit a-fA-F]
$bin_digit = 0-1 
$short_str_char = [^ \n \r ' \" \\]
$long_str_char = [. \n] # [' \"]
$short_byte_str_char = \0-\127 # [\n \r ' \" \\]
$long_byte_str_char = \0-\127 # [' \"]
$not_single_quote = [. \n] # '
$not_double_quote = [. \n] # \"

-- macro definitions
@exponent = (e | E) (\+ | \-)? $digit+ 
@fraction = \. $digit+
@int_part = $digit+
@point_float = (@int_part? @fraction) | @int_part \.
@exponent_float = (@int_part | @point_float) @exponent
@float_number = @point_float | @exponent_float
@eol_pattern = $lf | $cr $lf | $cr $lf  
@one_single_quote = ' $not_single_quote
@two_single_quotes = '' $not_single_quote
@one_double_quote = \" $not_double_quote
@two_double_quotes = \"\" $not_double_quote
@byte_str_prefix = b | B
@raw_str_prefix = r | R
@raw_byte_str_prefix = @byte_str_prefix @raw_str_prefix
@backslash_pair = \\ (\\|'|\"|@eol_pattern|$short_str_char)
@backslash_pair_bs = \\ (\\|'|\"|@eol_pattern|$short_byte_str_char)
@short_str_item_single = $short_str_char|@backslash_pair|\"
@short_str_item_double = $short_str_char|@backslash_pair|'
@short_byte_str_item_single = $short_byte_str_char|@backslash_pair_bs|\"
@short_byte_str_item_double = $short_byte_str_char|@backslash_pair_bs|'
@long_str_item_single = $long_str_char|@backslash_pair|@one_single_quote|@two_single_quotes|\"
@long_str_item_double = $long_str_char|@backslash_pair|@one_double_quote|@two_double_quotes|'
@long_byte_str_item_single = $long_byte_str_char|@backslash_pair_bs|@one_single_quote|@two_single_quotes|\"
@long_byte_str_item_double = $long_byte_str_char|@backslash_pair_bs|@one_double_quote|@two_double_quotes|'

tokens :-

-- these rules below could match inside a string literal, but they
-- will not be applied because the rule for the literal will always
-- match a longer sequence of characters. 

-- \# ($not_eol_char)* ;  -- skip comments 
\# ($not_eol_char)* { token CommentToken tail } 
$white_no_nl+  ;  -- skip whitespace 

-- \\ @eol_pattern ; -- line join 
\\ @eol_pattern { endOfLine lexToken } -- line join 

<0> {
   @float_number { token FloatToken readFloat }
   (@float_number | @int_part) (j | J) { token ImaginaryToken (readFloat.init) }
   $non_zero_digit $digit* { token IntegerToken read }  
   $non_zero_digit $digit* (l | L) { token LongIntegerToken (read.init) }  
   0+ { token IntegerToken read }  
   0+ (l | L)  { token LongIntegerToken (read.init) }  
   0 (o | O) $oct_digit+ { token IntegerToken read }
   0 (o | O) $oct_digit+ (l | L) { token LongIntegerToken (read.init) }
   0 $oct_digit+ { token IntegerToken readOctNoO } 
   0 $oct_digit+ (l | L) { token LongIntegerToken (readOctNoO.init) } 
   0 (x | X) $hex_digit+ { token IntegerToken read }
   0 (x | X) $hex_digit+ (l | L) { token LongIntegerToken (read.init) }
   0 (b | B) $bin_digit+ { token IntegerToken readBinary }
   0 (b | B) $bin_digit+ (l | L) { token LongIntegerToken (readBinary.init) }
}

-- String literals 

<0> {
   ' @short_str_item_single* ' { mkString 1 1 stringToken }
   @raw_str_prefix ' @short_str_item_single* ' { mkString 2 1 rawStringToken }
   @byte_str_prefix ' @short_byte_str_item_single* ' { mkString 2 1 byteStringToken }
   @raw_byte_str_prefix ' @short_byte_str_item_single* ' { mkString 3 1 rawByteStringToken }

   \" @short_str_item_double* \" { mkString 1 1 stringToken }
   @raw_str_prefix \" @short_str_item_double* \" { mkString 2 1 rawStringToken }
   @byte_str_prefix \" @short_byte_str_item_double* \" { mkString 2 1 byteStringToken }
   @raw_byte_str_prefix \" @short_byte_str_item_double* \" { mkString 3 1 rawByteStringToken }

   ''' @long_str_item_single* ''' { mkString 3 3 stringToken }
   @raw_str_prefix ''' @long_str_item_single* ''' { mkString 4 3 rawStringToken }
   @byte_str_prefix ''' @long_byte_str_item_single* ''' { mkString 4 3 byteStringToken }
   @raw_byte_str_prefix ''' @long_byte_str_item_single* ''' { mkString 5 3 rawByteStringToken }

   \"\"\" @long_str_item_double* \"\"\" { mkString 3 3 stringToken }
   @raw_str_prefix \"\"\" @long_str_item_double* \"\"\" { mkString 4 3 rawStringToken }
   @byte_str_prefix \"\"\" @long_byte_str_item_double* \"\"\" { mkString 4 3 byteStringToken }
   @raw_byte_str_prefix \"\"\" @long_byte_str_item_double* \"\"\" { mkString 5 3 rawByteStringToken }
}

-- NOTE: we pass lexToken into some functions as an argument.
-- That allows us to define those functions in a separate module,
-- which increases code reuse in the lexer (because that code can
-- be shared between the lexer for versions 2 and 3 of Python.
-- Unfortunately lexToken must be defined in this file because
-- it refers to data types which are only included by Alex in
-- the generated file (this seems like a limitation in Alex
-- that should be improved).

<0> {
   @eol_pattern     { bolEndOfLine lexToken bol }  
}

<dedent> ()                             { dedentation lexToken }

-- beginning of line
<bol> {
   -- @eol_pattern                        ; 
   @eol_pattern                         { endOfLine lexToken } 
   ()                                   { indentation lexToken dedent BOL }
}

-- beginning of file
<bof> {
   -- @eol_pattern                         ;
   @eol_pattern                         { endOfLine lexToken }
   ()                                   { indentation lexToken dedent BOF }
}


<0> $ident_letter($ident_letter|$digit)*  { \loc len str -> keywordOrIdent (take len str) loc }

-- operators and separators
--
<0> {
    "("   { openParen LeftRoundBracketToken }
    ")"   { closeParen RightRoundBracketToken }
    "["   { openParen LeftSquareBracketToken }
    "]"   { closeParen RightSquareBracketToken }
    "{"   { openParen LeftBraceToken }
    "}"   { closeParen RightBraceToken }
    "->"  { symbolToken RightArrowToken }
    "."   { symbolToken DotToken }
    "..." { symbolToken EllipsisToken }
    "~"   { symbolToken TildeToken }
    "+"   { symbolToken PlusToken }
    "-"   { symbolToken MinusToken }
    "**"  { symbolToken ExponentToken }
    "*"   { symbolToken MultToken }
    "/"   { symbolToken DivToken }
    "//"  { symbolToken FloorDivToken }
    "%"   { symbolToken ModuloToken }
    "<<"  { symbolToken ShiftLeftToken }
    ">>"  { symbolToken ShiftRightToken }
    "<"   { symbolToken LessThanToken }
    "<="  { symbolToken LessThanEqualsToken }
    ">"   { symbolToken GreaterThanToken }
    ">="  { symbolToken GreaterThanEqualsToken }
    "=="  { symbolToken EqualityToken }
    "!="  { symbolToken NotEqualsToken }
    "<>"  { symbolToken NotEqualsV2Token } -- only version 2
    "^"   { symbolToken XorToken }
    "|"   { symbolToken BinaryOrToken }
    "&&"  { symbolToken AndToken }
    "&"   { symbolToken BinaryAndToken }
    "||"  { symbolToken OrToken }
    ":"   { symbolToken ColonToken }
    "="   { symbolToken AssignToken }
    "+="  { symbolToken PlusAssignToken }
    "-="  { symbolToken MinusAssignToken }
    "*="  { symbolToken MultAssignToken }
    "/="  { symbolToken DivAssignToken }
    "%="  { symbolToken ModAssignToken }
    "**=" { symbolToken PowAssignToken }
    "&="  { symbolToken BinAndAssignToken }
    "|="  { symbolToken BinOrAssignToken }
    "^="  { symbolToken BinXorAssignToken }
    "<<=" { symbolToken LeftShiftAssignToken }
    ">>=" { symbolToken RightShiftAssignToken }
    "//=" { symbolToken FloorDivAssignToken } 
    ","   { symbolToken CommaToken }
    "@"   { symbolToken AtToken }
    \;    { symbolToken SemiColonToken }
    "`"   { symbolToken BackQuoteToken }
}

{ 
-- The lexer starts off in the beginning of file state (bof)
initStartCodeStack :: [Int]
initStartCodeStack = [bof,0]

lexToken :: P Token
lexToken = do
  location <- getLocation
  input <- getInput
  startCode <- getStartCode
  case alexScan (location, input) startCode of
    AlexEOF -> do
       depth <- getIndentStackDepth
       if depth <= 1
          then return endOfFileToken
          else do
             popIndent
             return dedentToken
    AlexError _ -> lexicalError
    AlexSkip (nextLocation, rest) len -> do
       setLocation nextLocation
       setInput rest
       lexToken
    AlexToken (nextLocation, rest) len action -> do
       setLocation nextLocation
       setInput rest
       token <- action (mkSrcSpan location $ decColumn 1 nextLocation) len input
       setLastToken token
       return token

-- This is called by the Happy parser.
lexCont :: (Token -> P a) -> P a
lexCont cont = do
   lexLoop
   where
   -- lexLoop :: P a
   lexLoop = do
      tok <- lexToken
      case tok of
         CommentToken {} -> do
            addComment tok
            lexLoop
         _other -> cont tok

-- a keyword or an identifier (the syntax overlaps)
keywordOrIdent :: String -> SrcSpan -> P Token
keywordOrIdent str location
   = return $ case Map.lookup str keywords of
         Just symbol -> symbol location
         Nothing -> IdentifierToken location str

-- mapping from strings to keywords
keywords :: Map.Map String (SrcSpan -> Token)
keywords = Map.fromList keywordNames

-- see: <http://docs.python.org/reference/lexical_analysis.html#keywords>
keywordNames :: [(String, SrcSpan -> Token)]
keywordNames =
   [ ("and", AndToken), ("as", AsToken), ("assert", AssertToken), ("break", BreakToken)
   , ("class", ClassToken), ("continue", ContinueToken), ("def", DefToken), ("del", DeleteToken)
   , ("elif", ElifToken),  ("else", ElseToken), ("except", ExceptToken), ("exec", ExecToken)
   , ("finally", FinallyToken), ("for", ForToken), ("from", FromToken),  ("global", GlobalToken)
   , ("if", IfToken), ("import", ImportToken), ("in", InToken), ("is", IsToken)
   , ("lambda", LambdaToken), ("not", NotToken), ("or", OrToken), ("pass", PassToken)
   , ("print", PrintToken), ("raise", RaiseToken), ("return", ReturnToken), ("try", TryToken)
   , ("while", WhileToken), ("with", WithToken), ("yield", YieldToken)
   ]
}
