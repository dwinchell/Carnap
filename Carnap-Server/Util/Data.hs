{-# LANGUAGE DeriveGeneric #-}
{-# OPTIONS_GHC -Wno-orphans #-}
module Util.Data where

import           Carnap.GHCJS.SharedFunctions              (rewriteWith)
import           Carnap.GHCJS.SharedTypes                  (ProblemData (..),
                                                            ProblemSource (..),
                                                            ProblemType (..),
                                                            SomeRule (..))
import           Carnap.Languages.PureFirstOrder.Syntax    (PureFOLForm)
import           Carnap.Languages.PurePropositional.Syntax (PureForm)
import           ClassyPrelude.Yesod
import           Data.Aeson                                (decode, encode)
import qualified Data.IntMap                               as IM (fromList)
import qualified Data.Map                                  as M
import qualified Data.Text.Lazy                            as LT
import           Data.Time
import           Text.HTML.TagSoup
import           Text.Pandoc                               (Extension (..),
                                                            Extensions,
                                                            extensionsFromList)
import           Text.Read                                 (readMaybe)

derivePersistField "Value"

derivePersistField "ProblemSource"

derivePersistField "ProblemType"

derivePersistField "ProblemData"

derivePersistField "SomeRule"

newtype BookAssignmentTable = BookAssignmentTable {readAssignmentTable :: IntMap UTCTime}
    deriving (Show, Read, Eq, Generic)
instance ToJSON BookAssignmentTable
instance FromJSON BookAssignmentTable
derivePersistField "BookAssignmentTable"

data SharingScope = Public | InstructorsOnly | LinkOnly | Private
    deriving (Show, Read, Eq, Generic)
instance ToJSON SharingScope
instance FromJSON SharingScope
derivePersistField "SharingScope"

--for access scoping in the future, if necessary
data APIKeyScope = APIKeyScopeRoot
    deriving (Show, Read, Eq)
derivePersistField "APIKeyScope"

data AvailabilityStatus = ViaPassword Text
                        | HiddenViaPassword Text
                        | ViaPasswordExpiring Text Int
                        | HiddenViaPasswordExpiring Text Int
    deriving (Show, Read, Eq, Generic)
instance ToJSON AvailabilityStatus
instance FromJSON AvailabilityStatus
derivePersistField "AvailabilityStatus"

availabilityPassword :: AvailabilityStatus -> Text
availabilityPassword (ViaPassword pass)                 = pass
availabilityPassword (HiddenViaPassword pass)           = pass
availabilityPassword (ViaPasswordExpiring pass _)       = pass
availabilityPassword (HiddenViaPasswordExpiring pass _) = pass

availabilityHidden :: AvailabilityStatus -> Bool
availabilityHidden (HiddenViaPassword _)           = True
availabilityHidden (HiddenViaPasswordExpiring _ _) = True
availabilityHidden _                               = False

availabilityMinutes :: AvailabilityStatus -> Maybe Int
availabilityMinutes (ViaPasswordExpiring _ min)       = Just min
availabilityMinutes (HiddenViaPasswordExpiring _ min) = Just min
availabilityMinutes _                                 = Nothing

sanitizeForJS :: String -> String
sanitizeForJS ('\n':xs) = '\\' : 'n' : sanitizeForJS xs
sanitizeForJS ('\\':xs) = '\\' : '\\' : sanitizeForJS xs
sanitizeForJS ('\'':xs) = '\\' : '\'' : sanitizeForJS xs
sanitizeForJS ('"':xs)  = '\\' : '"' : sanitizeForJS xs
sanitizeForJS ('\r':xs) = sanitizeForJS xs
sanitizeForJS (x:xs)    = x : sanitizeForJS xs
sanitizeForJS []        = []

chapterOfProblemSet :: IntMap Int
chapterOfProblemSet = IM.fromList
    [ (1,1)
    , (2,2)
    , (3,2)
    , (4,3)
    , (5,4)
    , (6,5)
    , (7,6)
    , (8,7)
    , (9,8)
    , (10,9)
    , (11,9)
    , (12,9)
    , (13,10)
    , (14,10)
    , (15,11)
    , (16,12)
    , (17,12)
    ]

carnapPandocExtensions :: Extensions
carnapPandocExtensions = extensionsFromList
        [ Ext_raw_html
        , Ext_markdown_in_html_blocks
        , Ext_auto_identifiers
        , Ext_tex_math_dollars
        , Ext_fenced_code_blocks
        , Ext_backtick_code_blocks
        , Ext_line_blocks
        , Ext_fancy_lists
        , Ext_definition_lists
        , Ext_example_lists
        , Ext_simple_tables
        , Ext_multiline_tables
        , Ext_footnotes
        , Ext_fenced_code_attributes
        , Ext_inline_code_attributes
        , Ext_shortcut_reference_links
        , Ext_yaml_metadata_block
        , Ext_task_lists
        , Ext_link_attributes
        , Ext_bracketed_spans
        , Ext_fenced_divs
        , Ext_startnum
        ]

toTime :: String -> UTCTime
toTime = parseTimeOrError True defaultTimeLocale "%l:%M %P %Z, %b %e, %Y"

laterThan :: UTCTime -> UTCTime -> Bool
laterThan t1 t2 = diffUTCTime t1 t2 > 0

jsonSerialize :: ToJSON a => a -> LT.Text
jsonSerialize = decodeUtf8 . encode

jsonDeSerialize :: FromJSON a => Text -> Maybe a
jsonDeSerialize = decode . encodeUtf8 . fromStrict

rewriteText :: Map String String -> Text -> Text
rewriteText opts = pack . rewriteWith opts . unpack

displayProblemData :: ProblemData -> Text
displayProblemData (DerivationData t _)  = t
displayProblemData (DerivationDataOpts t _ opts') = rewriteText opts t
    where opts = M.fromList opts'
displayProblemData (TruthTableData t _)  = t
displayProblemData (CounterModelDataOpts t _ opts') = maybe (rewriteText opts t) pack ms
    where opts = M.fromList opts'
          ms = (rewriteWith opts . show <$> (readMaybe s :: Maybe PureFOLForm))
               `mplus` (intercalate "," . map (rewriteWith opts . show) <$> (readMaybe s :: Maybe [PureFOLForm]))
          s = unpack t
displayProblemData (TruthTableDataOpts t _ opts') = maybe (rewriteText opts t) pack  ms
    where opts = M.fromList opts'
          ms = (rewriteWith opts . show <$> (readMaybe s :: Maybe PureForm))
               `mplus` (intercalate "," . map (rewriteWith opts . show) <$> (readMaybe s :: Maybe [PureForm]))
               `mplus` case readMaybe s :: Maybe ([PureForm],[PureForm]) of
                                 Nothing -> Nothing
                                 Just (fs,gs) -> Just $ intercalate "," (map (rewriteWith opts . show) fs)
                                                      ++ " || "
                                                      ++ intercalate "," (map (rewriteWith opts . show) gs)
          s = unpack t
displayProblemData (TranslationData _ _) = "-"
displayProblemData (TranslationDataOpts _ _ opts) = maybe "-" id $
                                                        lookup "problem" opts
                                                        >>= headMay . parseTags . pack
                                                        >>= maybeTagText
displayProblemData (QualitativeMultipleSelection t _ _) = t
displayProblemData (QualitativeProblemDataOpts t _ _opts) = t
displayProblemData (QualitativeNumericalData t _ _) = t
displayProblemData (SequentCalcData t _ _opts) = t
displayProblemData (DeductionTreeData t _ _opts) = t
displayProblemData (ProblemContent t) = maybe t pack ms
    where ms = (show <$> (readMaybe s :: Maybe PureForm))
               `mplus` (intercalate "," . map show <$> (readMaybe s :: Maybe [PureForm]))
               `mplus` case readMaybe s :: Maybe ([PureForm],[PureForm]) of
                                 Just (fs,gs) -> Just $ intercalate "," (map show fs) ++ " || " ++ intercalate "," (map show gs)
                                 Nothing -> Nothing
               `mplus` (show <$> (readMaybe s :: Maybe PureFOLForm))
               `mplus` (intercalate "," . map show <$> (readMaybe s :: Maybe [PureFOLForm]))
          s = unpack t
