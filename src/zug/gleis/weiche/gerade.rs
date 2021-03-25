//! Definition und zeichnen einer Weiche

// TODO
// non_ascii_idents might be stabilized soon
// use english names until then :(
// (nightly crashes atm on Sized-check)
// https://github.com/rust-lang/rust/issues/55467

use std::marker::PhantomData;

use crate::zug::gleis::anchor;
use crate::zug::gleis::gerade::Gerade;
use crate::zug::gleis::kurve::Kurve;
use crate::zug::gleis::types::*;
use crate::zug::gleis::widget::{AnchorLookup, Zeichnen};

/// Definition einer Weiche
#[derive(Debug, Clone)]
pub struct Weiche<Z> {
    pub zugtyp: PhantomData<*const Z>,
    pub length: Length,
    pub radius: Radius,
    pub angle: AngleDegrees,
    pub direction: WeichenRichtung,
}
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum WeichenRichtung {
    Links,
    Rechts,
}
#[derive(Debug, PartialEq, Eq, Hash, Clone, Copy)]
pub enum AnchorName {
    Anfang,
    Gerade,
    Kurve,
}
#[derive(Debug)]
pub struct AnchorPoints {
    anfang: anchor::Point,
    gerade: anchor::Point,
    kurve: anchor::Point,
}

impl<Z: Zugtyp> Zeichnen for Weiche<Z> {
    type AnchorName = AnchorName;
    type AnchorPoints = AnchorPoints;

    fn width(&self) -> u64 {
        let Weiche { zugtyp, length, radius, angle, direction: _ } = *self;
        let width_gerade = Gerade { zugtyp, length }.width();
        let width_kurve = Kurve { zugtyp, radius, angle }.width();
        width_gerade.max(width_kurve)
    }

    fn height(&self) -> u64 {
        let Weiche { zugtyp, length: _, radius, angle, direction: _ } = *self;
        Kurve { zugtyp, radius, angle }.width()
    }

    fn zeichne(&self, cairo: &Cairo) {
        let Weiche { zugtyp, length, radius, angle, direction } = *self;
        if direction == WeichenRichtung::Links {
            // spiegel y-Achse in der Mitte
            let x = CanvasX(0.);
            let half_height = CanvasY(0.5 * (self.height() as f64));
            cairo.translate(x, half_height);
            cairo.transform(Matrix { x0: 0., y0: 0., xx: 1., xy: 0., yx: 0., yy: -1. });
            cairo.translate(-x, -half_height);
        }
        Gerade { zugtyp, length }.zeichne(cairo);
        Kurve { zugtyp, radius, angle }.zeichne(cairo)
    }

    fn anchor_points(&self) -> Self::AnchorPoints {
        let start_height: CanvasY;
        let mult: f64;
        match self.direction {
            WeichenRichtung::Links => {
                start_height = CanvasY(0.);
                mult = 1.;
            }
            WeichenRichtung::Rechts => {
                start_height = CanvasY(self.height() as f64);
                mult = -1.;
            }
        };
        AnchorPoints {
            anfang: anchor::Point {
                position: anchor::Position {
                    x: CanvasX(0.),
                    y: start_height + mult * 0.5 * Z::beschraenkung(),
                },
                direction: anchor::Direction { dx: CanvasX(-1.), dy: CanvasY(mult * 0.) },
            },
            gerade: anchor::Point {
                position: anchor::Position {
                    x: CanvasX(0.) + CanvasAbstand::new(self.length.0),
                    y: start_height + mult * 0.5 * Z::beschraenkung(),
                },
                direction: anchor::Direction { dx: CanvasX(1.), dy: CanvasY(mult * 0.) },
            },
            kurve: anchor::Point {
                position: anchor::Position {
                    x: CanvasX(0.) + self.angle.sin() * CanvasAbstand::new(self.radius.0),
                    y: start_height
                        + mult
                            * (0.5 * Z::beschraenkung()
                                + CanvasAbstand::new(self.radius.0) * (1. - self.angle.cos())),
                },
                direction: anchor::Direction {
                    dx: CanvasX(self.angle.cos()),
                    dy: CanvasY(mult * self.angle.sin()),
                },
            },
        }
    }
}

impl AnchorLookup<AnchorName> for AnchorPoints {
    fn get(&self, key: AnchorName) -> &anchor::Point {
        match key {
            AnchorName::Anfang => &self.anfang,
            AnchorName::Gerade => &self.gerade,
            AnchorName::Kurve => &self.kurve,
        }
    }
    fn get_mut(&mut self, key: AnchorName) -> &mut anchor::Point {
        match key {
            AnchorName::Anfang => &mut self.anfang,
            AnchorName::Gerade => &mut self.gerade,
            AnchorName::Kurve => &mut self.kurve,
        }
    }
    fn map<F: FnMut(&anchor::Point)>(&self, mut action: F) {
        action(&self.anfang);
        action(&self.gerade);
        action(&self.kurve);
    }
}
