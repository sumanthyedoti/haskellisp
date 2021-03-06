{-# LANGUAGE LambdaCase #-}

module ParserLib where

import Control.Applicative
import qualified Data.Char as C
import qualified Data.List as L

type Error = String

newtype Parser v =
  Parser
    { parse :: String -> Either Error (v, String)
    }

instance Functor Parser where
  fmap f (Parser p) =
    Parser $ \input -> do
      (v, rest) <- p input
      return (f v, rest)

instance Applicative Parser where
  pure a = Parser $ \input -> Right (a, input)
  (Parser p1) <*> (Parser p2) =
    Parser $ \input -> do
      (f, input') <- p1 input
      (v, input'') <- p2 input'
      return (f v, input'')

instance Alternative Parser where
  empty = Parser $ \_ -> Left ""
  (Parser p1) <|> (Parser p2) =
    Parser $ \input ->
      case p1 input of
        Right (v1, rest1) -> return (v1, rest1)
        _ ->
          case p2 input of
            Right (v2, rest2) -> return (v2, rest2)
            _ -> Left $ "Unexpected " ++ take 1 input

instance Monad Parser where
  return = pure
  (Parser p1) >>= p2 =
    Parser $ \input -> do
      (v, rest) <- p1 input
      parse (p2 v) rest

spanTill :: (Char -> Bool) -> Parser String
spanTill f = Parser $ Right . span f

satisfy :: (Char -> Bool) -> Parser Char
satisfy predicate =
  Parser $ \case
    [] -> Left "End of input"
    (hd:rest)
      | predicate hd -> Right (hd, rest)
      | otherwise -> Left $ "Unexpected " ++ ("'" ++ [hd] ++ "'")

char :: Char -> Parser Char
char c = satisfy (== c)

string :: String -> Parser String
string = traverse char

digit :: Parser Char
digit = satisfy C.isDigit

letter :: Parser Char
letter = satisfy C.isAlpha

number :: Parser Double
number =
  Parser $ \input ->
    case reads input :: [(Double, String)] of
      [] -> Left $ "Unexpected " ++ (head input : " not a number")
      res -> Right $ head res

space :: Parser Char
space = satisfy C.isSpace

skipMany :: Parser p -> Parser [p]
skipMany = many

skipMany1 :: Parser p -> Parser [p]
skipMany1 = some

oneOf :: [Char] -> Parser Char
oneOf [] = Parser $ \_ -> Left "Can not be empty list"
oneOf str =
  Parser $ \input ->
    if head input `elem` str
      then Right (head input, tail input)
      else Left $ "Unexpected " ++ take 1 input

noneOf :: [Char] -> Parser Char
noneOf [] = Parser $ \_ -> Left "Can not be empty list"
noneOf str =
  Parser $ \input ->
    if head input `elem` str
      then Left $
           "character should be none of " ++
           (init . drop 1) (show (L.intersperse ',' str))
      else Right (head input, tail input)

sepBy :: Parser a -> Parser b -> Parser [b]
sepBy sep elem = (:) <$> elem <*> some (sep *> elem) <|> pure []
