{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE NamedFieldPuns #-}
{-# LANGUAGE InstanceSigs #-}
{-# LANGUAGE LambdaCase #-}
{-# LANGUAGE BlockArguments #-}
{-# LANGUAGE TupleSections #-}
{-# LANGUAGE MonoLocalBinds #-}

{-|
Description : Starte Main-Loop für Kommandozeilen-basiertes UI.
-}
module Zug.UI.Cmd (main, mainStatus) where

import Control.Monad (unless, void)
import Control.Monad.RWS.Strict (evalRWST)
import Control.Monad.State.Class (MonadState(..))
import Control.Monad.Trans (MonadIO(liftIO))
import Data.Text (Text)
import qualified Data.Text as Text
import qualified Data.Text.IO as Text
-- Farbige Konsolenausgabe
import System.Console.ANSI (setSGR, Color(..), ColorIntensity(..), ConsoleLayer(..), SGR(..))
import System.IO (hFlush, stdout)

import Zug.Enums (ZugtypKlasse())
import qualified Zug.Language as Language
import Zug.Language (Anzeige(..), Sprache(), ($#), (<~>), (<\>), (<=>), (<!>), (<:>)
                   , fehlerhafteEingabe, toBefehlsString)
import Zug.Objekt (Objekt)
import Zug.Options (Options(..), getOptions, VersionReader(erhalteVersion))
import Zug.UI.Base (getSprache, IOStatus, auswertenLeererIOStatus, tvarMapsNeu
                  , AusführenMöglich(..), ausführenMöglich)
import Zug.UI.Befehl (BefehlAllgemein(..), Befehl, BefehlListeAllgemein(..), ausführenBefehl)
import Zug.UI.Cmd.Lexer (EingabeTokenAllgemein(..), lexer)
import Zug.UI.Cmd.Parser
       (AnfrageFortsetzung(..), AnfrageBefehl(..), Anfrage(..), StatusAnfrageObjekt(..)
      , statusAnfrageObjekt, StatusAnfrageObjektZugtyp(..), statusAnfrageObjektZugtyp
      , ObjektZugtyp(..), BefehlSofort(..), AnfrageNeu(..), parser, unbekanntShowText, zeigeAnfrage
      , zeigeAnfrageOptionen, zeigeAnfrageFehlgeschlagen)
import qualified Zug.UI.Save as Save

-- | Lade per Kommandozeile übergebenen Anfangszustand und führe den main loop aus.
main :: (VersionReader r m, MonadIO m) => m ()
main = do
    -- Lade Datei angegeben in Kommandozeilenargument
    Options {load = path, sprache} <- getOptions
    v <- erhalteVersion
    liftIO $ Save.laden path pure sprache >>= \case
        Nothing -> auswertenLeererIOStatus mainStatus ((, v) <$> tvarMapsNeu) sprache
        (Just anfangsZustand) -> do
            tvarMaps <- tvarMapsNeu
            void $ evalRWST mainStatus (tvarMaps, v) anfangsZustand

-- | main loop
mainStatus :: IOStatus ()
mainStatus = do
    status <- get
    sp <- getSprache
    v <- erhalteVersion
    let putStrLnSprache :: (Sprache -> Text) -> IO ()
        putStrLnSprache s = Text.putStrLn $ s sp
    liftIO $ do
        setSGR [SetColor Foreground Dull Green]
        putStrLnSprache $ Text.empty <\> Language.zugkontrolle
        setSGR [Reset]
        putStrLnSprache $ Text.empty <~> Language.version v
        setSGR [SetColor Foreground Dull Cyan]
        Text.putStrLn $ Text.map (const '-') $ Language.zugkontrolle <~> Language.version v $ sp
        setSGR [Reset]
        putStrLnSprache $ anzeige status
        setSGR [SetColor Foreground Dull Blue]
        putStrLnSprache $ toBefehlsString . Language.befehlAlle
        setSGR [Reset]
    ende <- promptS (const "\n") >>= statusParser . lexer
    unless ende mainStatus

-- | Gesamter Auswert-Prozess
statusParser :: [EingabeTokenAllgemein] -> IOStatus Bool
statusParser = statusParserAux . parser AnfrageBefehl
    where
        statusParserAux :: ( [Befehl]
                           , AnfrageFortsetzung AnfrageBefehl (Either BefehlSofort Befehl)
                           , [EingabeTokenAllgemein]
                           , AnfrageBefehl
                           )
                        -> IOStatus Bool
        statusParserAux (befehle, fortsetzung, eingabeRest, backup) = do
            sprache <- getSprache
            ende <- ausführenBefehl (BefehlListe befehle)
            if ende
                then pure True
                else case fortsetzung of
                    (AFErgebnis (Right befehl)) -> ausführenBefehl befehl
                    (AFErgebnis (Left befehlSofort)) -> do
                        ergebnis <- ausführenBefehlSofort befehlSofort
                        statusParserAux $ parser ergebnis eingabeRest
                    (AFStatusAnfrage aObjektIOStatus konstruktor)
                        -> statusAnfrage aObjektIOStatus konstruktor backup eingabeRest
                    (AFStatusAnfrageMärklin aObjektIOStatus konstruktor)
                        -> statusAnfrageZugtyp aObjektIOStatus konstruktor backup eingabeRest
                    (AFStatusAnfrageLego aObjektIOStatus konstruktor)
                        -> statusAnfrageZugtyp aObjektIOStatus konstruktor backup eingabeRest
                    (AFZwischenwert AnfrageBefehl) -> pure False
                    (AFFehler eingabe) -> do
                        liftIO $ do
                            setSGR [SetColor Foreground Vivid Red]
                            Text.putStr $ unbekanntShowText backup eingabe sprache
                            setSGR [Reset]
                        promptS (const Text.empty) >>= statusParserAux . parser backup . lexer
                    (AFZwischenwert anfrage) -> do
                        case zeigeAnfrageOptionen anfrage of
                            Nothing -> pure ()
                            (Just anfrageOptionen) -> liftIO $ do
                                setSGR [SetColor Foreground Dull Blue]
                                Text.putStrLn $ anfrageOptionen sprache
                                setSGR [Reset]
                        promptS (anfrage <:> Text.empty)
                            >>= statusParserAux . parser anfrage . lexer

        statusAnfrage :: StatusAnfrageObjekt
                      -> (Objekt -> AnfrageFortsetzung AnfrageBefehl (Either BefehlSofort Befehl))
                      -> AnfrageBefehl
                      -> [EingabeTokenAllgemein]
                      -> IOStatus Bool
        statusAnfrage aObjektIOStatus konstruktor backup eingabeRest =
            statusAnfrageObjekt aObjektIOStatus >>= statusAnfrageAux konstruktor backup eingabeRest

        statusAnfrageZugtyp
            :: (ZugtypKlasse z)
            => StatusAnfrageObjektZugtyp z
            -> (ObjektZugtyp z -> AnfrageFortsetzung AnfrageBefehl (Either BefehlSofort Befehl))
            -> AnfrageBefehl
            -> [EingabeTokenAllgemein]
            -> IOStatus Bool
        statusAnfrageZugtyp aObjektIOStatus konstruktor backup eingabeRest =
            statusAnfrageObjektZugtyp aObjektIOStatus
            >>= statusAnfrageAux konstruktor backup eingabeRest

        statusAnfrageAux
            :: (objekt -> AnfrageFortsetzung AnfrageBefehl (Either BefehlSofort Befehl))
            -> AnfrageBefehl
            -> [EingabeTokenAllgemein]
            -> Either Text objekt
            -> IOStatus Bool
        statusAnfrageAux konstruktor backup eingabeRest (Right objekt) = case konstruktor objekt of
            ergebnis@(AFErgebnis _befehl) -> statusParserAux ([], ergebnis, eingabeRest, backup)
            (AFStatusAnfrage qObjektIOStatus1 konstruktor1)
                -> statusAnfrage qObjektIOStatus1 konstruktor1 backup eingabeRest
            (AFStatusAnfrageMärklin qObjektIOStatus1 konstruktor1)
                -> statusAnfrageZugtyp qObjektIOStatus1 konstruktor1 backup eingabeRest
            (AFStatusAnfrageLego qObjektIOStatus1 konstruktor1)
                -> statusAnfrageZugtyp qObjektIOStatus1 konstruktor1 backup eingabeRest
            (AFZwischenwert anfrage) -> statusParserAux $ parser anfrage eingabeRest
            fehler@(AFFehler _eingabe) -> statusParserAux ([], fehler, eingabeRest, backup)
        statusAnfrageAux _konstruktor backup _eingabeRest (Left eingabe) =
            promptS
                (zeigeAnfrageFehlgeschlagen backup eingabe <!> zeigeAnfrage backup <:> Text.empty)
            >>= statusParserAux . parser backup . lexer

-- | Ausführen eines Befehls, der sofort ausgeführt werden muss
ausführenBefehlSofort :: BefehlSofort -> IOStatus AnfrageBefehl
ausführenBefehlSofort (BSLaden dateipfad) = do
    ausführenBefehl
        $ Laden dateipfad put
        $ fehlerhafteEingabeS
        $ Language.nichtGefundeneDatei <=> dateipfad
    pure AnfrageBefehl
ausführenBefehlSofort
    (BSAusführenMöglich plan) = wähleAnfrageBefehl <$> ausführenMöglich plan
    where
        wähleAnfrageBefehl :: AusführenMöglich -> AnfrageBefehl
        wähleAnfrageBefehl AusführenMöglich = ABAktionPlan plan
        wähleAnfrageBefehl WirdAusgeführt = ABAktionPlanAusführend plan Neu
        wähleAnfrageBefehl (AnschlüsseBelegt anschlüsse) =
            ABAktionPlanGesperrt plan Neu anschlüsse

-- * Eingabe abfragen
prompt :: Text -> IO [Text]
prompt text = do
    Text.putStr text
    hFlush stdout
    Text.words <$> Text.getLine

promptS :: (Sprache -> Text) -> IOStatus [Text]
promptS s = getSprache >>= liftIO . prompt . s

fehlerhafteEingabeS :: (Sprache -> Text) -> IOStatus ()
fehlerhafteEingabeS s = getSprache >>= liftIO . (fehlerhafteEingabe $# s)