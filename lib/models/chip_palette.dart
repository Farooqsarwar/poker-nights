import 'chip_color.dart';

/// The F5 chip palette — Addendum 1 §2 row 2.
///
/// v3.1 originally specified "a fixed palette of named chip colours (White,
/// Red, Green, Black, Blue, Purple, Pink, Grey; no yellow or gold)". Addendum 1
/// corrects it to **the mock's ten named colours**, adding Yellow and Orange:
///
/// > White, Red, Green, Black, Blue, Yellow, Pink, Purple, Orange, Grey.
/// > A chip swatch shows a real chip, so it is the one place yellow may appear;
/// > the no-yellow rule (T141) covers the app's own colours.
///
/// **Why a fixed set at all.** The editor previously offered a full colour
/// wheel with a free-text name — its placeholder literally suggested "Gold".
/// Three things follow from that, and all three are fixed here:
///
///  1. A host could pick the owner's banned gold and put it on screen.
///  2. Arbitrary hues produce swatches that match no chip anyone owns, which
///     defeats the point of a swatch: to be recognisable across the table.
///  3. §B5 requires chip colours to be **named in text** as well as shown,
///     because the owner is colour blind (§B4 rule 16). A free wheel cannot
///     guarantee a name at all, let alone a stable one.
///
/// The hexes stay in the flat-UI family the app's presets already use
/// (`tournament_engine.dart`, `tools_screen.dart`), so an existing chip set
/// keeps looking like itself.
class NamedChipColour {
  const NamedChipColour(this.name, this.hex);

  final String name;
  final int hex;
}

/// The ten, in the addendum's own order.
const List<NamedChipColour> kChipPalette = [
  NamedChipColour('White', 0xFFE8E4D9),
  NamedChipColour('Red', 0xFFC0392B),
  NamedChipColour('Green', 0xFF27AE60),
  NamedChipColour('Black', 0xFF2C2C2C),
  NamedChipColour('Blue', 0xFF2980B9),
  // Legal here and nowhere else — see the class doc.
  NamedChipColour('Yellow', 0xFFF1C40F),
  NamedChipColour('Pink', 0xFFE84393),
  NamedChipColour('Purple', 0xFF8E44AD),
  NamedChipColour('Orange', 0xFFE67E22),
  NamedChipColour('Grey', 0xFF95A5A6),
];

/// The palette entry whose hex matches [hex], or null for a colour from before
/// the palette was fixed.
NamedChipColour? chipPaletteEntryForHex(int hex) {
  for (final c in kChipPalette) {
    if (c.hex == hex) return c;
  }
  return null;
}

/// The palette entry named [name], case-insensitively.
NamedChipColour? chipPaletteEntryForName(String name) {
  final key = name.trim().toLowerCase();
  for (final c in kChipPalette) {
    if (c.name.toLowerCase() == key) return c;
  }
  return null;
}

/// Snaps an existing chip onto the fixed palette.
///
/// Chip sets created before the palette was fixed carry arbitrary hues and
/// free-text names. Rather than rewrite them — a host's saved set is their
/// record of chips they physically own — this resolves a display name for one:
/// its palette name when it matches, otherwise the name already stored.
String chipDisplayName(ChipColor chip) =>
    chipPaletteEntryForHex(chip.hex)?.name ??
    (chip.color.trim().isEmpty ? 'Chip' : chip.color.trim());
