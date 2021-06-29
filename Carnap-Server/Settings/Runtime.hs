module Settings.Runtime (
    module Settings.RuntimeDefs,
    getDisableGoogleReg,
    setRtSetting,
    getRtSettings
) where

import           Control.Monad.Trans.Maybe (MaybeT (..))
import           Import.NoFoundation
import           Settings.RuntimeDefs

getSettingRaw :: PersistentSite site => RTSetType -> MaybeT (YesodDB site) ByteString
getSettingRaw ty =
    runtimeSettingValue . entityVal
        <$> (MaybeT $ getBy (UniqueSetting ty))

getSetting :: PersistentSite site => RTSetType -> MaybeT (YesodDB site) RTSetting
getSetting ty = do
    set <- getSettingRaw $ ty
    MaybeT . return $ parseRtSetting ty set

setRtSetting :: PersistentSite site => RTSetting -> YesodDB site ()
setRtSetting set = do
    let ser = serializeRtSetting set
    _ <- upsert (RuntimeSetting (rtSettingType set) ser) [RuntimeSettingValue =. ser]
    return ()

getRtSettings :: PersistentSite site => YesodDB site [RTSetting]
getRtSettings = do
    sequence [DisableGoogleReg <$> getDisableGoogleReg]

withDefault :: Functor f => a -> MaybeT f a -> f a
withDefault def comp = maybe def id <$> (runMaybeT comp)

getDisableGoogleReg :: PersistentSite site => YesodDB site Bool
getDisableGoogleReg = withDefault False $ do
    DisableGoogleReg v <- getSetting TyDisableGoogleReg
    return v

