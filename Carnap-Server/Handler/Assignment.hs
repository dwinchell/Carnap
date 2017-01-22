module Handler.Assignment (getAssignmentR,getAssignmentsR) where

import Import
import Util.Data
import Util.Database
import Yesod.Markdown
import Text.Julius (juliusFile,rawJS)
import System.Directory (doesFileExist,getDirectoryContents)
import Text.Pandoc.Walk (walkM, walk)
import Filter.SynCheckers
import Filter.ProofCheckers
import Filter.Translate
import Filter.TruthTables

getAssignmentsR :: Handler Html
getAssignmentsR = do adir <- assignmentDir
                     adirContents <- lift $ getDirectoryContents adir
                     muid <- maybeAuthId
                     ud <- case muid of
                                 Nothing -> 
                                    do setMessage "you need to be logged in to access assignments"
                                       redirect HomeR
                                 Just uid -> checkUserData uid
                     assignmentMD <- runDB $ selectList 
                                        [AssignmentMetadataCourse ==. userDataEnrolledIn ud] []
                     defaultLayout
                          [whamlet|
                              <div.container>
                                  <h1>Assignments
                                  <ul>
                                      $forall a <- map entityVal assignmentMD
                                          <li>
                                            <div.assignment>
                                                <p>
                                                    <a href=@{AssignmentR $ assignmentMetadataFilename a}>
                                                        #{assignmentMetadataFilename a}
                                                $maybe desc <- assignmentMetadataDescription a
                                                    <p> #{desc}
                                                $nothing
                                                <p>Due: #{show $ assignmentMetadataDuedate a}
                          |]

getAssignmentR :: Text -> Handler Html
getAssignmentR t = do adir <- assignmentDir
                      let path = (adir </> unpack t)
                      exists <- lift $ doesFileExist path
                      if not exists 
                        then defaultLayout nopage
                        else do ehtml <- lift $ fileToHtml path
                                case ehtml of
                                    Left err -> defaultLayout $ layout (show err)
                                    Right html -> do
                                        defaultLayout $ do
                                            toWidgetHead $(juliusFile "templates/command.julius")
                                            toWidgetHead [julius|var submission_source="birmingham";|]
                                            toWidgetHead [julius|var assignment_name="#{rawJS t}";|] --Better to actually retrieve this from the metadata
                                            addScript $ StaticR ghcjs_rts_js
                                            addScript $ StaticR ghcjs_allactions_lib_js
                                            addScript $ StaticR ghcjs_allactions_out_js
                                            addStylesheet $ StaticR css_exercises_css
                                            addStylesheet $ StaticR css_tree_css
                                            addStylesheet $ StaticR css_exercises_css
                                            layout html
                                            addScript $ StaticR ghcjs_allactions_runmain_js
    where layout c = [whamlet|
                        <div.container>
                            <article>
                                #{c}
                        |]

          nopage = layout ("assignment not found" :: Text)

fileToHtml path = do md <- markdownFromFile path
                     case parseMarkdown yesodDefaultReaderOptions md of
                         Right pd -> do let pd' = walk allFilters pd
                                        return $ Right $ writePandoc yesodDefaultWriterOptions pd'
                         Left e -> return $ Left e
    where allFilters = (makeSynCheckers . makeProofChecker . makeTranslate . makeTruthTables)
                  
assignmentDir = do master <- getYesod 
                   if appDevel (appSettings master) 
                        then return "assignments"
                        else return "/root/assignments"
