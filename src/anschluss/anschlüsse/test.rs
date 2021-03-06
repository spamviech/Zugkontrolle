//! unittests für das anschluss-Modul

use std::thread::sleep;
use std::time::Duration;

use num_x::u3;
use simple_logger::SimpleLogger;

use super::{Anschlüsse, SyncError};
use crate::anschluss::{level::Level, pcf8574};

#[test]
fn drop_semantics() {
    SimpleLogger::new()
        .with_level(log::LevelFilter::Error)
        .with_module_level("zugkontrolle", log::LevelFilter::Debug)
        .init()
        .expect("failed to initialize error logging");

    let mut anschlüsse = Anschlüsse::neu().expect("1.ter Aufruf von neu.");
    Anschlüsse::neu().expect_err("2.ter Aufruf von neu.");
    let llln = anschlüsse
        .reserviere_pcf8574_port(
            Level::Low,
            Level::Low,
            Level::Low,
            pcf8574::Variante::Normal,
            u3::new(0),
        )
        .expect("1. Aufruf von llln.");
    assert_eq!(llln.adresse(), &(Level::Low, Level::Low, Level::Low, pcf8574::Variante::Normal));
    assert_eq!(llln.port(), u3::new(0));
    assert_eq!(
        anschlüsse.reserviere_pcf8574_port(
            Level::Low,
            Level::Low,
            Level::Low,
            pcf8574::Variante::Normal,
            u3::new(0)
        ),
        Err(SyncError::InVerwendung),
        "2. Aufruf von llln."
    );
    drop(llln);
    // Warte etwas, damit der restore-thread genug Zeit hat.
    sleep(Duration::from_secs(1));
    let llln = anschlüsse
        .reserviere_pcf8574_port(
            Level::Low,
            Level::Low,
            Level::Low,
            pcf8574::Variante::Normal,
            u3::new(0),
        )
        .expect("Aufruf von llln nach drop.");
    drop(anschlüsse);

    // jetzt sollte Anschlüsse wieder verfügbar sein
    let mut anschlüsse = Anschlüsse::neu().expect("Aufruf von neu nach drop.");
    assert_eq!(
        anschlüsse.reserviere_pcf8574_port(
            Level::Low,
            Level::Low,
            Level::Low,
            pcf8574::Variante::Normal,
            u3::new(0)
        ),
        Err(SyncError::InVerwendung),
        "Aufruf von llln mit vorherigem Ergebnis in scope."
    );
    drop(llln);
    // Warte etwas, damit der restore-thread genug Zeit hat.
    sleep(Duration::from_secs(1));
    let llln0 = anschlüsse
        .reserviere_pcf8574_port(
            Level::Low,
            Level::Low,
            Level::Low,
            pcf8574::Variante::Normal,
            u3::new(0),
        )
        .expect("Aufruf von llln nach drop.");
    let llln1 = anschlüsse
        .reserviere_pcf8574_port(
            Level::Low,
            Level::Low,
            Level::Low,
            pcf8574::Variante::Normal,
            u3::new(1),
        )
        .expect("Aufruf von llln nach drop, alternativer port.");
    drop(llln0);
    drop(llln1);
    // Warte etwas, damit der restore-thread genug Zeit hat.
    sleep(Duration::from_secs(1));
    let llln = anschlüsse
        .reserviere_pcf8574_port(
            Level::Low,
            Level::Low,
            Level::Low,
            pcf8574::Variante::Normal,
            u3::new(0),
        )
        .expect("Aufruf von llln nach drop.");
    drop(llln);
    drop(anschlüsse);
}
