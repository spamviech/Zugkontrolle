//! Steuerung einer Model-Eisenbahn über einen raspberry pi

use std::marker::PhantomData;

use gio::prelude::*;
use gtk::prelude::*;
use gtk::{Application, ApplicationWindow, DrawingArea};
use simple_logger::SimpleLogger;

use gleis::gerade::Gerade;
use gleis::kreuzung::{self, Kreuzung};
use gleis::kurve::Kurve;
use gleis::types::*;
use gleis::weiche::{DreiwegeWeiche, KurvenWeiche, Weiche, WeichenRichtung};
use gleis::widget::Zeichnen;
use zugtyp::Maerklin;

pub mod gleis;
pub mod zugtyp;

// include std in doc generated by `cargo doc`
// https://github.com/rust-lang/rfcs/issues/2324#issuecomment-502437904
#[cfg(doc)]
#[doc(inline)]
pub use std;

fn main() {
    SimpleLogger::new().init().expect("failed to initialize error logging");

    let application =
        Application::new(None, Default::default()).expect("failed to initialize GTK application");

    application.connect_activate(|app| {
        let window = ApplicationWindow::new(app);
        window.set_title("Zugkontrolle");
        window.set_default_size(600, 400);

        let drawing_area = DrawingArea::new();
        fn test(drawing_area: &DrawingArea, c: &cairo::Context) -> glib::signal::Inhibit {
            let allocation = drawing_area.get_allocation();
            let cairo: &Cairo = &Cairo::new(c);
            cairo.translate(CanvasX(0.5 * (allocation.width as u64) as f64), CanvasY(10.));
            let gerade: Gerade<Maerklin> =
                Gerade { length: Length::new(180.), zugtyp: PhantomData };
            show_gleis(cairo, gerade);
            let kurve: Kurve<Maerklin> = Kurve {
                radius: Radius::new(360.),
                angle: AngleDegrees::new(30.),
                zugtyp: PhantomData,
            };
            show_gleis(cairo, kurve);
            let weiche: Weiche<Maerklin> = Weiche {
                length: Length::new(180.),
                radius: Radius::new(360.),
                angle: AngleDegrees::new(30.),
                direction: WeichenRichtung::Links,
                zugtyp: PhantomData,
            };
            show_gleis(cairo, weiche);
            let dreiwege_weiche: DreiwegeWeiche<Maerklin> = DreiwegeWeiche {
                length: Length::new(180.),
                radius: Radius::new(360.),
                angle: AngleDegrees::new(30.),
                zugtyp: PhantomData,
            };
            show_gleis(cairo, dreiwege_weiche);
            let kurven_weiche: KurvenWeiche<Maerklin> = KurvenWeiche {
                length: Length::new(100.),
                radius: Radius::new(360.),
                angle: AngleDegrees::new(30.),
                direction: WeichenRichtung::Links,
                zugtyp: PhantomData,
            };
            show_gleis(cairo, kurven_weiche);
            let kreuzung: Kreuzung<Maerklin> = Kreuzung {
                length: Length::new(180.),
                radius: Radius::new(360.),
                variante: kreuzung::Variante::MitKurve,
                zugtyp: PhantomData,
            };
            show_gleis(cairo, kreuzung);
            glib::signal::Inhibit(false)
        }
        drawing_area.set_size_request(600, 800);
        drawing_area.connect_draw(test);
        window.add(&drawing_area);

        window.show_all();
    });

    application.run(&[]);
}

fn show_gleis<T: Zeichnen>(cairo: &Cairo, gleis: T) {
    cairo.with_save_restore(|cairo| {
        cairo.translate(CanvasX(-0.5 * (gleis.width() as f64)), CanvasY(0.));
        // zeichne Box umd das Gleis (überprüfen von width, height)
        cairo.with_save_restore(|cairo| {
            cairo.set_source_rgb(0., 1., 0.);
            let left = CanvasX(0.);
            let right = CanvasX(gleis.width() as f64);
            let up = CanvasY(0.);
            let down = CanvasY(gleis.height() as f64);
            cairo.move_to(left, up);
            cairo.line_to(right, up);
            cairo.line_to(right, down);
            cairo.line_to(left, down);
            cairo.line_to(left, up);
            cairo.stroke();
        });
        // zeichne gleis
        cairo.with_save_restore(|cairo| {
            gleis.zeichne(cairo);
            cairo.stroke();
        });
    });
    // verschiebe Context, damit nächstes Gleis unter das aktuelle gezeichnet wird
    let skip_y: CanvasAbstand = CanvasY(10.).into();
    cairo.translate(CanvasX(0.), CanvasY(gleis.height() as f64) + skip_y);
}
