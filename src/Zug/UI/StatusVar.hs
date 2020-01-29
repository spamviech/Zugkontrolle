{-# LANGUAGE NamedFieldPuns #-}
{-# LANGUAGE LambdaCase #-}
{-# LANGUAGE InstanceSigs #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE UndecidableInstances #-}
{-# LANGUAGE FunctionalDependencies #-}
{-# LANGUAGE DataKinds #-}

module Zug.UI.StatusVar (
    -- * Datentyp
    StatusVar(),
    -- * Konstruktor
    statusVarNew,
    -- * Grundfunktionen
    STM, atomically,
    takeStatusVar, readStatusVar, tryReadStatusVar, putStatusVar,
    -- * Zugehörigkeitsklassen
    MitStatusVar(..), StatusVarReader(..),
    -- * Hilfsfunktionen
    auswertenStatusVarIOStatus, auswertenStatusVarMStatus, auswertenStatusVarMStatusT,
    ausführenStatusVarBefehl, ausführenStatusVarPlan, ausführenStatusVarAktion) where

-- Bibliotheken
import Control.Concurrent.STM (STM, atomically, TVar, readTVar, writeTVar, retry, newTVarIO)
import Control.Lens ((^.))
import Control.Monad.Reader.Class (MonadReader(..), asks)
import Control.Monad.RWS.Lazy (runRWS, runRWST)
import Control.Monad.Trans (MonadIO(..))
import Data.Aeson (ToJSON())
import Numeric.Natural (Natural)
-- Abhängigkeit von anderen Modulen
import Zug.Enums (Zugtyp(..))
import Zug.Language (MitSprache())
import Zug.Objekt (ObjektKlasse(..))
import Zug.Plan (PlanKlasse(..), AktionKlasse(..))
import Zug.UI.Base (
    StatusAllgemein(), sprache, IOStatusAllgemein, MStatusAllgemein, MStatusAllgemeinT,
    ReaderFamilie, ObjektReader(), MitTVarMaps(), liftIOStatus)
import Zug.UI.Befehl (BefehlKlasse(..))

-- | 'TVar', welche gelehrt werden kann, aber immer eine 'Sprache' enthält
newtype StatusVar o = StatusVar {tvar :: TVar (Either (StatusAllgemein o) (SP o))}
    deriving (Eq)

-- | Erstelle eine neue 'StatusVar'
statusVarNew :: StatusAllgemein o -> IO (StatusVar o)
statusVarNew = fmap StatusVar . newTVarIO . Left

-- | Erhalte den 'StatusAllgemein' aus einer 'StatusVar' und leere sie.
-- Ist die 'StatusVar' leer, blockiere so lange bis sie wieder gefüllt wird.
takeStatusVar :: StatusVar o -> STM (StatusAllgemein o)
takeStatusVar StatusVar {tvar} = readTVar tvar >>= \case
        (Left status)
            -> do
                writeTVar tvar $ Right $ status ^. sprache
                pure status
        (Right _sprache)
            -> retry

-- | Erhalte den 'StatusAllgemein' aus einer 'StatusVar' ohne diese zu verändern.
-- Ist die 'StatusVar' leer, blockiere so lange bis sie wieder gefüllt wird.
readStatusVar :: StatusVar o -> STM (StatusAllgemein o)
readStatusVar StatusVar {tvar} = readTVar tvar >>= \case
        (Left status)
            -> pure status
        (Right _sprache)
            -> retry

-- | Versuche den 'StatusAllgemein' aus einer 'StatusVar' zu lesen.
-- Ist die 'StatusVar' leer, gebe stattdessen die 'Sprache' zurück.
tryReadStatusVar :: StatusVar o -> STM (Either (StatusAllgemein o) (SP o))
tryReadStatusVar = readTVar . tvar

-- | Schreibe den 'StatusAllgemein' eine leere 'StatusVar'.
-- Ist die 'StatusVar' nicht leer, blockiere so lange bis sie geleert wird.
putStatusVar :: StatusVar o -> StatusAllgemein o -> STM ()
putStatusVar StatusVar {tvar} status = readTVar tvar >>= \case
    (Left _statusAlt)
        -> retry
    (Right _sprache)
        -> writeTVar tvar $ Left status

-- | Klasse für Typen mit dem in einer 'StatusVar'
class MitStatusVar r o where
    statusVar :: r -> StatusVar o
instance MitStatusVar (StatusVar o) o where
    statusVar :: StatusVar o -> StatusVar o
    statusVar = id
-- | Abkürzung für Funktionen, die den in einer 'TMVar' gespeicherten 'StatusAllgemein' benötigen.
class (MonadReader r m) => StatusVarReader r o m | m -> r where
    erhalteStatusVar :: m (StatusVar o)
instance (MonadReader r m, MitStatusVar r o) => StatusVarReader r o m where
    erhalteStatusVar :: m (StatusVar o)
    erhalteStatusVar = asks statusVar

-- | Führe 'IO'-Aktion mit 'StatusAllgemein' in 'StatusVar' aus
auswertenStatusVarIOStatus :: (ObjektReader o m, MonadIO m) =>
    IOStatusAllgemein o a -> StatusVar o -> m a
auswertenStatusVarIOStatus action = auswertenStatusVarMStatusT $ liftIOStatus action

-- | Führe 'MonadIO'-Aktion mit 'StatusAllgemein' in 'StatusVar' aus
auswertenStatusVarMStatusT :: (ObjektReader o m, MonadIO m) =>
    MStatusAllgemeinT m o a -> StatusVar o -> m a
auswertenStatusVarMStatusT action statusVar = do
    reader <- ask
    status0 <- liftIO $ atomically $ takeStatusVar statusVar
    (a, status1, ()) <- runRWST action reader status0
    liftIO $ atomically $ putStatusVar statusVar status1
    pure a

-- | Führe Aktion mit 'StatusAllgemein' in 'StatusVar' aus
auswertenStatusVarMStatus :: (ObjektReader o m, MonadIO m) => MStatusAllgemein o a -> StatusVar o -> m a
auswertenStatusVarMStatus action statusVar = do
    reader <- ask
    liftIO $ atomically $ do
        status0 <- takeStatusVar statusVar
        let (a, status1, ()) = runRWS action reader status0
        putStatusVar statusVar status1
        pure a

-- | Führe einen Plan mit einem in einer 'StatusVar' gespeichertem Zustand aus
ausführenStatusVarPlan :: (ObjektReader o m, MonadIO m, PlanKlasse (PL o), MitTVarMaps (ReaderFamilie o)) =>
    PL o -> (Natural -> IO ()) -> IO () -> StatusVar o -> m ()
ausführenStatusVarPlan plan showAktion endAktion = auswertenStatusVarIOStatus $ ausführenPlan plan showAktion endAktion

-- | Führe eine Aktion mit einem in einer 'StatusVar' gespeichertem Zustand aus
ausführenStatusVarAktion   :: (ObjektReader o m, MonadIO m, AktionKlasse a, MitTVarMaps (ReaderFamilie o)) =>
    a -> StatusVar o -> m ()
ausführenStatusVarAktion aktion = auswertenStatusVarIOStatus $ ausführenAktion aktion

-- | Führe einen Befehl mit einem in einer 'StatusVar' gespeichertem Zustand aus
ausführenStatusVarBefehl :: (ObjektReader o m, MonadIO m, BefehlKlasse b o,
    ObjektKlasse o, ToJSON o, Eq ((BG o) 'Märklin), Eq ((BG o) 'Lego),
    Eq (ST o), Eq ((WE o) 'Märklin), Eq ((WE o) 'Lego), Eq (KU o),
    Eq ((WS o) 'Märklin), Eq ((WS o) 'Lego), Eq (PL o),
    MitSprache (SP o), MitTVarMaps (ReaderFamilie o))
        => b o -> StatusVar o -> m Bool
ausführenStatusVarBefehl befehl = auswertenStatusVarIOStatus $ ausführenBefehl befehl