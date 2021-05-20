//! Pcf8574, gesteuert über I2C.
//!
//! Alle Methoden in diesem Modul können an einem Mutex blocken (exklusiver I2C-Zugriff).
//! Der Zugriff auf diese Mutex ist auf dieses Modul beschränkt,
//! so dass es zu keinen Deadlocks kommen sollte.

use std::fmt::Debug;
use std::sync::{mpsc::Sender, Arc, Mutex, PoisonError};

use cfg_if::cfg_if;
use log::debug;
use log::error;
use num_x::u3;
#[cfg(raspi)]
use num_x::u7;
#[cfg(raspi)]
use rppal::{gpio, i2c};

use super::pin::input;
use super::{level::Level, trigger::Trigger};

#[derive(Debug, Clone, Copy)]
pub(super) enum Modus {
    Input,
    High,
    Low,
}
impl From<Level> for Modus {
    fn from(level: Level) -> Self {
        match level {
            Level::High => Modus::High,
            Level::Low => Modus::Low,
        }
    }
}

/// Ein Pcf8574, gesteuert über I2C.
#[derive(Debug)]
pub struct Pcf8574 {
    a0: Level,
    a1: Level,
    a2: Level,
    variante: Variante,
    ports: [Modus; 8],
    interrupt: Option<input::Pin>,
    #[cfg(raspi)]
    i2c: Arc<RwLock<i2c::I2C>>,
}

pub(super) type Nachricht = (Level, Level, Level, Variante);

impl Pcf8574 {
    pub(super) fn neu(
        a0: Level,
        a1: Level,
        a2: Level,
        variante: Variante,
        #[cfg(raspi)] i2c: Arc<i2c::I2c>,
    ) -> Self {
        Pcf8574 {
            a0,
            a1,
            a2,
            variante,
            ports: [Modus::Input; 8],
            interrupt: None,
            #[cfg(raspi)]
            i2c,
        }
    }

    /// Assoziiere den angeschlossenen InterruptPin.
    /// Rückgabewert ist ein evtl. vorher konfigurierter InterruptPin.
    /// Interrupt-Callbacks werden nicht zurückgesetzt!
    fn set_interrupt(&mut self, interrupt: input::Pin) -> Option<input::Pin> {
        std::mem::replace(&mut self.interrupt, Some(interrupt))
    }

    /*
    /// Adress-Bits (a0, a1, a2) und Variante eines Pcf8574.
    #[inline]
    fn adresse(&self) -> (Level, Level, Level, Variante) {
        (self.a0, self.a1, self.a2, self.variante)
    }
    */

    #[cfg(raspi)]
    /// 7-bit i2c-Adresse ohne R/W-Bit
    fn i2c_adresse(&self) -> u7 {
        let Pcf8574 { a0, a1, a2, variante, .. } = self;
        let mut adresse = u7::new(match variante {
            Variante::Normal => 0x20,
            Variante::A => 0x38,
        });
        if let Level::High = a0 {
            adresse = adresse + u7::new(0b100);
        }
        if let Level::High = a1 {
            adresse = adresse + u7::new(0b010);
        }
        if let Level::High = a2 {
            adresse = adresse + u7::new(0b001);
        }
        adresse
    }

    /// Lese von einem Pcf8574.
    /// Nur als Input konfigurierte Ports werden als Some-Wert zurückgegeben.
    ///
    /// Bei Interrupt-basiertem lesen sollten alle Port gleichzeitig gelesen werden!
    fn read(&self) -> Result<[Option<Level>; 8], Error> {
        cfg_if! {
            if #[cfg(raspi)] {
                if let Ok(mut i2c_channel) = &mut *self.i2c.lock() {
                    i2c_channel.set_slave_address(self.i2c_adresse.into())?;
                    let mut buf = [0; 1];
                    let bytes_read = i2c_channel.read(&mut buf)?;
                    if bytes_read != 1 {
                        debug!("bytes_read = {} != 1", bytes_read)
                    }
                    let mut result = [None; 8];
                    for (port, modus) in self.ports.iter().enumerate() {
                        let port_bit = 2u8.pow(port as u32) as u8;
                        if let Modus::Input = modus {
                            Some(if (buf[0] & port_bit) > 0 { Level::High } else { Level::Low })
                        } else {
                            None
                        }
                    }
                    Ok(result)
                } else {
                    error!("I2C-Mutex poisoned!");
                    Err(Error::PoisonError)
                }
            } else {
                debug!("{:?}.read()", self);
                Err(Error::KeinRaspberryPi)
            }
        }
    }

    /// Konvertiere einen Port als Input.
    fn port_as_input(&mut self, port: u3) -> Result<(), Error> {
        self.write_port(port, Level::High)?;
        self.ports[usize::from(port)] = Modus::Input;
        Ok(())
    }

    /// Schreibe auf einen Port des Pcf8574.
    /// Der Port wird automatisch als Output gesetzt.
    fn write_port(&mut self, port: u3, level: Level) -> Result<(), Error> {
        self.ports[usize::from(port)] = level.into();
        cfg_if! {
            if #[cfg(raspi)] {
                if let Ok(mut i2c_channel) = &mut *self.i2c.lock() {
                    i2c_channel.set_slave_address(self.i2c_adresse.into())?;
                    let mut wert = 0;
                    for (port, modus) in self.ports.iter().enumerate() {
                        wert |= match modus {
                            Modus::Input | Modus::High => 2u8.pow(port as u32) as u8,
                            Modus::Low => 0,
                        };
                    }
                    let buf = [wert; 1];
                    let bytes_written = i2c_channel.write(&buf)?;
                    if bytes_written != 1 {
                        debug!("bytes_written = {} != 1", bytes_written)
                    }
                    Ok(())
                } else {
                    error!("I2C-Mutex poisoned!");
                    Err(Error::PoisonError)
                }
            } else {
                debug!("{:?}.read()", self);
                Err(Error::KeinRaspberryPi)
            }
        }
    }
}
impl PartialEq for Pcf8574 {
    fn eq(&self, other: &Self) -> bool {
        self.a0 == other.a0
            && self.a1 == other.a1
            && self.a2 == other.a2
            && self.variante == other.variante
    }
}
impl Eq for Pcf8574 {}
/// Variante eines Pcf8574, beeinflusst die I2C-Adresse.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Variante {
    Normal,
    A,
}

/// Ein Port eines Pcf8574.
#[derive(Debug)]
pub struct Port {
    pcf8574: Arc<Mutex<Pcf8574>>,
    nachricht: Nachricht,
    port: u3,
    sender: Sender<(Nachricht, u3)>,
}
impl PartialEq for Port {
    fn eq(&self, other: &Self) -> bool {
        self.port == other.port && self.nachricht == other.nachricht
    }
}
impl Eq for Port {}
impl Drop for Port {
    fn drop(&mut self) {
        let Port { port, nachricht, sender, .. } = self;
        debug!("dropped {:?} {:?} ", nachricht, port);
        // Schicke Werte als Tupel, um keine Probleme mit dem Drop-Handler zu bekommen.
        // (Ein Klon würde bei send-Fehler eine Endlos-Schleife erzeugen)
        if let Err(err) = sender.send((nachricht.clone(), port.clone())) {
            debug!("send error while dropping: {}", err)
        }
    }
}
impl Port {
    pub(super) fn neu(
        pcf8574: Arc<Mutex<Pcf8574>>,
        nachricht: Nachricht,
        port: u3,
        sender: Sender<(Nachricht, u3)>,
    ) -> Self {
        Port { pcf8574, port, nachricht, sender }
    }

    #[inline]
    pub fn adresse(&self) -> &Nachricht {
        &self.nachricht
    }

    #[inline]
    pub fn port(&self) -> u3 {
        self.port
    }

    /// Konfiguriere den Port für Output.
    pub fn into_output(self) -> Result<OutputPort, Error> {
        {
            let pcf8574 = &mut *self.pcf8574.lock()?;
            pcf8574.write_port(self.port, Level::High)?;
        }
        Ok(OutputPort(self))
    }

    /// Konfiguriere den Port für Input.
    pub fn into_input(self) -> Result<InputPort, Error> {
        {
            let pcf8574 = &mut *self.pcf8574.lock()?;
            pcf8574.port_as_input(self.port)?;
        }
        Ok(InputPort(self))
    }
}

// Ein Port eines Pcf8574, konfiguriert für Output.
#[derive(Debug)]
pub struct OutputPort(Port);

impl OutputPort {
    #[inline]
    pub fn adresse(&self) -> &Nachricht {
        self.0.adresse()
    }

    #[inline]
    pub fn port(&self) -> u3 {
        self.0.port()
    }

    pub fn write(&mut self, level: Level) -> Result<(), Error> {
        {
            let pcf8574 = &mut *self.0.pcf8574.lock()?;
            pcf8574.write_port(self.0.port, level)?;
        }
        Ok(())
    }
}

// Ein Port eines Pcf8574, konfiguriert für Input.
#[derive(Debug)]
pub struct InputPort(Port);

impl InputPort {
    #[inline]
    pub fn adresse(&self) -> &Nachricht {
        self.0.adresse()
    }

    #[inline]
    pub fn port(&self) -> u3 {
        self.0.port()
    }

    pub fn read(&self) -> Result<Level, Error> {
        let values = {
            let pcf8574 = &mut *self.0.pcf8574.lock()?;
            pcf8574.read()?
        };
        if let Some(value) = values[usize::from(self.0.port)] {
            Ok(value)
        } else {
            error!("{:?} war nicht als input korrigiert!", self);
            // war nicht als Input konfiguriert -> erneut konfigurieren und neu versuchen
            {
                let pcf8574 = &mut *self.0.pcf8574.lock()?;
                pcf8574.port_as_input(self.0.port)?;
            }
            self.read()
        }
    }

    /// Assoziiere den angeschlossenen InterruptPin für den Pcf8574.
    /// Rückgabewert ist ein evtl. vorher konfigurierter InterruptPin.
    /// Interrupt-Callbacks werden nicht zurückgesetzt!
    pub fn set_interrupt(&mut self, interrupt: input::Pin) -> Result<Option<input::Pin>, Error> {
        let pcf8574 = &mut *self.0.pcf8574.lock()?;
        Ok(pcf8574.set_interrupt(interrupt))
    }

    /// Configures an asynchronous interrupt trigger, which executes the callback on a separate
    /// thread when the interrupt is triggered.
    ///
    /// The callback closure or function pointer is called with a single Level argument.
    ///
    /// Any previously configured (a)synchronous interrupt triggers for this pin are cleared when
    /// set_async_interrupt is called, or when InputPin goes out of scope.
    #[cfg_attr(not(raspi), allow(unused_variables))]
    #[inline]
    pub fn set_async_interrupt<C>(&mut self, trigger: Trigger, mut callback: C) -> Result<(), Error>
    where
        C: FnMut(Level) + Send + 'static,
    {
        let mut last = self.read()?;
        let clone = InputPort(Port {
            pcf8574: self.0.pcf8574.clone(),
            port: self.0.port,
            sender: self.0.sender.clone(),
            nachricht: self.0.nachricht.clone(),
        });
        let pcf8574 = &mut *self.0.pcf8574.lock()?;
        Ok(pcf8574.interrupt.as_mut().ok_or(Error::KeinInterruptPin)?.set_async_interrupt(
            Trigger::FallingEdge,
            move |_level| match clone.read() {
                Ok(current) => match trigger {
                    Trigger::Both | Trigger::FallingEdge
                        if last == Level::High && current == Level::Low =>
                    {
                        callback(current)
                    },
                    Trigger::Both | Trigger::RisingEdge
                        if last == Level::High && current == Level::Low =>
                    {
                        callback(current)
                    },
                    _ => {
                        last = current;
                    },
                },
                Err(error) => {
                    error!("Error while reading InputPort: {:?}", error);
                },
            },
        )?)
    }

    /// Removes a previously configured asynchronous interrupt trigger.
    #[inline]
    pub fn clear_async_interrupt(&mut self) -> Result<(), Error> {
        let pcf8574 = &mut *self.0.pcf8574.lock()?;
        Ok(pcf8574.interrupt.as_mut().ok_or(Error::KeinInterruptPin)?.clear_async_interrupt()?)
    }
}

// TODO genauere Eingrenzung auf einzelne Methoden
#[derive(Debug)]
pub enum Error {
    #[cfg(raspi)]
    I2c(i2c::Error),
    #[cfg(raspi)]
    Gpio(gpio::Error),
    #[cfg(not(raspi))]
    KeinRaspberryPi,
    PoisonError,
    KeinInterruptPin,
}
#[cfg(raspi)]
impl From<i2c::Error> for Error {
    fn from(error: i2c::Error) -> Self {
        Error::I2c(error)
    }
}
impl From<input::Error> for Error {
    fn from(error: input::Error) -> Self {
        match error {
            #[cfg(raspi)]
            input::Error::Gpio(err) => Error::Gpio(err),
            #[cfg(not(raspi))]
            input::Error::KeinRaspberryPi => Error::KeinRaspberryPi,
        }
    }
}
impl<T> From<PoisonError<T>> for Error {
    fn from(_: PoisonError<T>) -> Self {
        Error::PoisonError
    }
}
