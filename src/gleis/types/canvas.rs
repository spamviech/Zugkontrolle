//! newtypes für einen cairo::Context

use std::convert::From;
use std::ops::{Add, AddAssign, Div, DivAssign, Mul, MulAssign, Neg, Sub, SubAssign};

use cairo::Context;
pub use cairo::Matrix;

use super::angle::{Angle, Trigonometrie};
use super::{Length, Radius, Spurweite};

/// newtype auf einen cairo-Context
///
/// Only implements the methods I need, might add others later.
/// All methods only work with corresponding Canvas..-Types
#[derive(Debug)]
pub struct Cairo<'t>(&'t Context);

impl<'t> Cairo<'t> {
    pub fn new(c: &'t Context) -> Cairo<'t> {
        Cairo(c)
    }

    pub fn move_to(&self, x: CanvasX, y: CanvasY) {
        self.0.move_to(x.0, y.0)
    }
    pub fn rel_move_to(&self, dx: CanvasX, dy: CanvasY) {
        self.0.rel_move_to(dx.0, dy.0)
    }

    pub fn line_to(&self, x: CanvasX, y: CanvasY) {
        self.0.line_to(x.0, y.0)
    }
    pub fn rel_line_to(&self, dx: CanvasX, dy: CanvasY) {
        self.0.rel_line_to(dx.0, dy.0)
    }

    /// Strike an arc around (xc,xy) with given radius from angle1 to angle2
    ///
    /// Unlike the method on the cairo context,
    /// doesn't strike a direct line from the current point to the start of the arc!
    pub fn arc(
        &self,
        xc: CanvasX,
        yc: CanvasY,
        radius: CanvasRadius,
        angle1: Angle,
        angle2: Angle,
    ) {
        let radius_abstand: CanvasAbstand = radius.into();
        self.move_to(xc + radius_abstand * angle1.cos(), yc + radius_abstand * angle1.sin());
        self.0.arc(xc.0, yc.0, radius.0, angle1.0, angle2.0)
    }

    pub fn stroke(&self) {
        self.0.stroke()
    }

    /// perform a /save/ before and a /restore/ after action
    pub fn with_save_restore<F: FnOnce(&Self)>(&self, action: F) {
        self.0.save().expect("Error in cairo::Context::save");
        action(self);
        self.0.restore().expect("Error in cairo::Context::restore");
    }

    pub fn translate(&self, tx: CanvasX, ty: CanvasY) {
        self.0.translate(tx.0, ty.0)
    }

    pub fn rotate(&self, angle: Angle) {
        self.0.rotate(angle.0)
    }

    pub fn transform(&self, matrix: Matrix) {
        self.0.transform(matrix)
    }

    pub fn set_source_rgb(&self, red: f64, green: f64, blue: f64) {
        self.0.set_source_rgb(red, green, blue)
    }
    pub fn set_source_rgba(&self, red: f64, green: f64, blue: f64, alpha: f64) {
        self.0.set_source_rgba(red, green, blue, alpha)
    }
}

pub trait Zeichnen {
    /// Maximale Breite
    fn width(&self) -> u64;

    /// Maximale Höhe
    fn height(&self) -> u64;

    /// Darstellen im Kontext an Position (0,0).
    ///
    /// Der Kontext wurde bereits für eine Darstellung in korrekter Position transformiert.
    fn zeichne(&self, cairo: &Cairo);

    /// Identifier for AnchorPoints.
    /// An enum is advised, but others work as well.
    ///
    /// Since they are used as keys in an HashMap, Hash+Eq must be implemented (derived).
    type AnchorName;
    /// Storage Type for AnchorPoints, should implement /AnchorLookup<Self::AnchorName>/.
    type AnchorPoints;
    /// AnchorPoints (Anschluss-Möglichkeiten für andere Gleise).
    ///
    /// Position ausgehend von zeichnen bei (0,0),
    /// Richtung nach außen zeigend.
    fn anchor_points(&self) -> Self::AnchorPoints;
}

/// Horizontale Koordinate auf einem Cairo-Canvas
#[derive(Debug, PartialEq, PartialOrd, Clone, Copy)]
pub struct CanvasX(pub f64);
impl Add<CanvasAbstand> for CanvasX {
    type Output = CanvasX;

    fn add(self, CanvasAbstand(rhs): CanvasAbstand) -> CanvasX {
        CanvasX(self.0 + rhs)
    }
}
impl AddAssign<CanvasAbstand> for CanvasX {
    fn add_assign(&mut self, CanvasAbstand(rhs): CanvasAbstand) {
        self.0 += rhs
    }
}
impl Sub<CanvasAbstand> for CanvasX {
    type Output = Self;

    fn sub(self, CanvasAbstand(rhs): CanvasAbstand) -> Self {
        CanvasX(self.0 - rhs)
    }
}
impl SubAssign<CanvasAbstand> for CanvasX {
    fn sub_assign(&mut self, CanvasAbstand(rhs): CanvasAbstand) {
        self.0 -= rhs
    }
}
impl Neg for CanvasX {
    type Output = CanvasX;

    fn neg(self) -> Self {
        CanvasX(-self.0)
    }
}
/// Vertikale Koordinate auf einem Cairo-Canvas
#[derive(Debug, PartialEq, PartialOrd, Clone, Copy)]
pub struct CanvasY(pub f64);
impl Add<CanvasAbstand> for CanvasY {
    type Output = Self;

    fn add(self, CanvasAbstand(rhs): CanvasAbstand) -> Self {
        CanvasY(self.0 + rhs)
    }
}
impl AddAssign<CanvasAbstand> for CanvasY {
    fn add_assign(&mut self, CanvasAbstand(rhs): CanvasAbstand) {
        self.0 += rhs
    }
}
impl Sub<CanvasAbstand> for CanvasY {
    type Output = Self;

    fn sub(self, CanvasAbstand(rhs): CanvasAbstand) -> Self {
        CanvasY(self.0 - rhs)
    }
}
impl SubAssign<CanvasAbstand> for CanvasY {
    fn sub_assign(&mut self, CanvasAbstand(rhs): CanvasAbstand) {
        self.0 -= rhs
    }
}
impl Neg for CanvasY {
    type Output = CanvasY;

    fn neg(self) -> Self {
        CanvasY(-self.0)
    }
}
/// Radius auf einem Cairo-Canvas
#[derive(Debug, PartialEq, Clone, Copy)]
pub struct CanvasRadius(pub f64);
impl Add<CanvasAbstand> for CanvasRadius {
    type Output = Self;

    fn add(self, CanvasAbstand(rhs): CanvasAbstand) -> Self {
        CanvasRadius(self.0 + rhs)
    }
}
impl AddAssign<CanvasAbstand> for CanvasRadius {
    fn add_assign(&mut self, CanvasAbstand(rhs): CanvasAbstand) {
        self.0 += rhs
    }
}
impl Sub<CanvasAbstand> for CanvasRadius {
    type Output = Self;

    fn sub(self, CanvasAbstand(rhs): CanvasAbstand) -> Self {
        CanvasRadius(self.0 - rhs)
    }
}
impl SubAssign<CanvasAbstand> for CanvasRadius {
    fn sub_assign(&mut self, CanvasAbstand(rhs): CanvasAbstand) {
        self.0 -= rhs
    }
}
/// Abstand/Länge auf einem Cairo-Canvas
#[derive(Debug, PartialEq, PartialOrd, Clone, Copy)]
pub struct CanvasAbstand(f64);
impl CanvasAbstand {
    const fn new_from_mm(abstand_mm: f64) -> CanvasAbstand {
        CanvasAbstand(abstand_mm)
    }

    pub fn max(&self, other: &CanvasAbstand) -> CanvasAbstand {
        CanvasAbstand(self.0.max(other.0))
    }

    /// Anzahl benötigter Pixel um den CanvasAbstand darstellen zu können
    pub fn pixel(&self) -> u64 {
        self.0.ceil() as u64
    }
}
// with Self
impl Add<CanvasAbstand> for CanvasAbstand {
    type Output = Self;

    fn add(self, CanvasAbstand(rhs): CanvasAbstand) -> Self {
        CanvasAbstand(self.0 + rhs)
    }
}
impl AddAssign<CanvasAbstand> for CanvasAbstand {
    fn add_assign(&mut self, CanvasAbstand(rhs): CanvasAbstand) {
        self.0 += rhs
    }
}
impl Sub<CanvasAbstand> for CanvasAbstand {
    type Output = Self;

    fn sub(self, CanvasAbstand(rhs): CanvasAbstand) -> Self {
        CanvasAbstand(self.0 - rhs)
    }
}
impl SubAssign<CanvasAbstand> for CanvasAbstand {
    fn sub_assign(&mut self, CanvasAbstand(rhs): CanvasAbstand) {
        self.0 -= rhs
    }
}
// with CanvasX
impl From<CanvasX> for CanvasAbstand {
    fn from(CanvasX(input): CanvasX) -> Self {
        CanvasAbstand(input)
    }
}
impl Add<CanvasX> for CanvasAbstand {
    type Output = CanvasX;

    fn add(self, CanvasX(rhs): CanvasX) -> CanvasX {
        CanvasX(self.0 + rhs)
    }
}
// with CanvasY
impl From<CanvasY> for CanvasAbstand {
    fn from(CanvasY(input): CanvasY) -> Self {
        CanvasAbstand(input)
    }
}
impl Add<CanvasY> for CanvasAbstand {
    type Output = CanvasY;

    fn add(self, CanvasY(rhs): CanvasY) -> CanvasY {
        CanvasY(self.0 + rhs)
    }
}
// with CanvasRadius
impl From<CanvasRadius> for CanvasAbstand {
    fn from(CanvasRadius(input): CanvasRadius) -> Self {
        CanvasAbstand(input)
    }
}
impl Add<CanvasRadius> for CanvasAbstand {
    type Output = CanvasRadius;

    fn add(self, CanvasRadius(rhs): CanvasRadius) -> CanvasRadius {
        CanvasRadius(self.0 + rhs)
    }
}
// scale with f64
impl Mul<f64> for CanvasAbstand {
    type Output = CanvasAbstand;

    fn mul(self, rhs: f64) -> CanvasAbstand {
        CanvasAbstand(self.0 * rhs)
    }
}
impl Mul<CanvasAbstand> for f64 {
    type Output = CanvasAbstand;

    fn mul(self, CanvasAbstand(rhs): CanvasAbstand) -> CanvasAbstand {
        CanvasAbstand(self * rhs)
    }
}
impl MulAssign<f64> for CanvasAbstand {
    fn mul_assign(&mut self, rhs: f64) {
        self.0 *= rhs
    }
}
impl Div<f64> for CanvasAbstand {
    type Output = CanvasAbstand;

    fn div(self, rhs: f64) -> CanvasAbstand {
        CanvasAbstand(self.0 / rhs)
    }
}
impl DivAssign<f64> for CanvasAbstand {
    fn div_assign(&mut self, rhs: f64) {
        self.0 /= rhs
    }
}
/// Umrechnung von mm-Größen auf Canvas-Koordinaten
/// Verwenden dieser Funktion um evtl. in der Zukunft einen Faktor zu erlauben
impl From<Spurweite> for CanvasAbstand {
    fn from(Spurweite(spurweite): Spurweite) -> CanvasAbstand {
        CanvasAbstand::new_from_mm(spurweite)
    }
}
impl From<Length> for CanvasAbstand {
    fn from(Length(length): Length) -> CanvasAbstand {
        CanvasAbstand::new_from_mm(length)
    }
}
impl From<Radius> for CanvasAbstand {
    fn from(Radius(radius): Radius) -> CanvasAbstand {
        CanvasAbstand::new_from_mm(radius)
    }
}
