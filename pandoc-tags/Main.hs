{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE RecordWildCards #-}
{-# LANGUAGE DeriveTraversable #-}

module Main where

import Control.Monad ((<=<))
import Control.Monad.IO.Class
import Control.Monad.Writer.Lazy
import Data.List (intersperse)
import Data.Text (Text)
import Text.Pandoc hiding (Writer)
import Text.Pandoc.Builder
import Text.Pandoc.Walk
import Data.Map.Merge.Strict (merge, zipWithMatched, preserveMissing)
import qualified Data.Map as M
import qualified Data.Text as T

type Tag        = Text
type Tags       = [Tag]
type TagMap     = TagMapM [FilePath]
type TagsT      = WriterT TagMap
type TagPandoc = (Tag, Pandoc)

newtype TagMapM a = TagMapM { unTagMapM :: M.Map Tag a }
  deriving (Show, Functor, Foldable, Traversable)

instance (Semigroup v) => Semigroup (TagMapM v) where
  (TagMapM m1) <> (TagMapM m2) = TagMapM $
    merge 
      preserveMissing 
      preserveMissing
      (zipWithMatched (const (<>)))
      m1
      m2

instance (Monoid v) => Monoid (TagMapM v) where
  mempty = TagMapM mempty

main :: IO ()
main = undefined
  -- traverse processSourceFile 
  -- runTagsT
  -- fmap walkWithFilters
  -- traverse_ writeTagFile

writeTagFile :: TagPandoc -> IO ()
writeTagFile = undefined
  -- determine output file type
  -- generate filepath from tag
  -- write pandoc to filepath

processSourceFile :: (MonadIO m) => FilePath -> TagsT m ()
processSourceFile fp = undefined
  -- read file
  -- walkWithFilters <$> (extractAndAppendTags fp)
  -- write file

walkWithFilters :: Pandoc -> Pandoc
walkWithFilters = walk mdLinkToHtml

runTagsT :: (Monad m) => TagsT m a -> m (a, [TagPandoc])
runTagsT = fmap (fmap buildPandocsFromTagMap) . runWriterT

buildPandocsFromTagMap :: TagMap -> [TagPandoc]
buildPandocsFromTagMap = 
    M.foldMapWithKey (\t fps -> pure (t, buildTagsPandoc t fps))
  . unTagMapM 

buildTagsPandoc :: Tag -> [FilePath] -> Pandoc
buildTagsPandoc tag = 
  setTitle (str tag) . doc . bulletList . fmap mkFilePathPandoc

mkFilePathPandoc :: FilePath -> Blocks
mkFilePathPandoc fp = 
  let pFp = T.pack fp
  in plain $ maybe mempty (flip (link pFp) mempty) (filePathTitle pFp)

extractAndAppendTags :: (Monad m) => FilePath -> Pandoc -> TagsT m Pandoc
extractAndAppendTags fp = do
  writer . fmap (buildTagMap fp) . appendTagLinks

buildTagMap :: FilePath -> Tags -> TagMap
buildTagMap fp = TagMapM . M.fromList . fmap (\t -> (t, [fp]))

appendTagLinks :: Pandoc -> (Pandoc, Tags)
appendTagLinks p = 
  let t  = docTags p
      np = p <> mkTagLinks t
  in (np, t)

mkTagLinks :: Tags -> Pandoc
mkTagLinks = 
    Pandoc mempty 
  . pure . Div ("tag-links", ["tag-links"], []) 
  . pure . Para 
  . intersperse (Str ", ") 
  . fmap mkTagLink

mkTagLink :: Tag -> Inline
mkTagLink tagName = 
  Link 
  ("tag-link", ["tag-link"], [])
  [Str tagName]
  ("./" <> tagName <> ".md", tagName)

docTags :: Pandoc -> Tags
docTags (Pandoc meta _) = getTags meta

getTags :: Meta -> Tags
getTags meta
  | Just (MetaList tags) <- lookupMeta "tags" meta = [str | (MetaInlines ((Str str):[])) <- tags]
  | otherwise = []

mdLinkToHtml :: Inline -> Inline
mdLinkToHtml (Link attr@(tl, _, _) ((Str _):[]) (url, mouseover))
  | (Just name) <- filePathTitle url 
  , "tag-link" <- tl
  = Link attr [(Str $ "(see " <> name <> ")")] ("./"<>name<>".html", mouseover)
mdLinkToHtml x = x

filePathTitle :: Text -> Maybe Text
filePathTitle = T.stripPrefix "./" <=< T.stripSuffix ".md"
