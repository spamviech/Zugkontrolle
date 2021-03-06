//! Style Strukturen für die Hintergrund-Farbe eines iced::Container

pub const WHITE: Grey = Grey(1.);
pub const BLACK: Grey = Grey(0.);

pub struct Grey(pub f32);
impl iced::container::StyleSheet for Grey {
    fn style(&self) -> iced::container::Style {
        iced::container::Style {
            background: Some(iced::Background::Color(iced::Color::from_rgb(
                self.0, self.0, self.0,
            ))),
            ..Default::default()
        }
    }
}
