// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Ninth House Studios LLC

// --------------------------------------------------------------------------
// Body ID newtypes
// --------------------------------------------------------------------------

/// Counterpart: swisseph::types::AsteroidId
extension type const AsteroidId(int mpcNumber) {
  /// Counterpart: swisseph::types::AsteroidId::new
  static AsteroidId validated(int mpcNumber) {
    if (mpcNumber < 0) {
      throw RangeError.range(mpcNumber, 0, null, 'mpcNumber');
    }
    return AsteroidId(mpcNumber);
  }
}

/// Counterpart: swisseph::types::FictitiousId
extension type const FictitiousId(int rawId) {
  /// Counterpart: swisseph::types::FictitiousId::new
  static FictitiousId validated(int rawId) {
    if (rawId < 40 || rawId > 999) {
      throw RangeError.range(rawId, 40, 999, 'rawId');
    }
    return FictitiousId(rawId);
  }
}

/// Counterpart: swisseph::types::PlanetMoonId
extension type const PlanetMoonId(int encoded) {
  /// Counterpart: swisseph::types::PlanetMoonId::new
  static PlanetMoonId validated(int encoded) {
    if (encoded < 0 || encoded > 999) {
      throw RangeError.range(encoded, 0, 999, 'encoded');
    }
    return PlanetMoonId(encoded);
  }
}

// --------------------------------------------------------------------------
// Sealed Body hierarchy
// --------------------------------------------------------------------------

/// Counterpart: swisseph::types::Body
sealed class Body {
  const Body._();

  /// Counterpart: swisseph::types::Body::to_raw_id
  int get rawValue;

  // -- Standard body constants --

  /// Counterpart: swisseph::types::Body::Sun
  static const sun = StandardBody._(0);

  /// Counterpart: swisseph::types::Body::Moon
  static const moon = StandardBody._(1);

  /// Counterpart: swisseph::types::Body::Mercury
  static const mercury = StandardBody._(2);

  /// Counterpart: swisseph::types::Body::Venus
  static const venus = StandardBody._(3);

  /// Counterpart: swisseph::types::Body::Mars
  static const mars = StandardBody._(4);

  /// Counterpart: swisseph::types::Body::Jupiter
  static const jupiter = StandardBody._(5);

  /// Counterpart: swisseph::types::Body::Saturn
  static const saturn = StandardBody._(6);

  /// Counterpart: swisseph::types::Body::Uranus
  static const uranus = StandardBody._(7);

  /// Counterpart: swisseph::types::Body::Neptune
  static const neptune = StandardBody._(8);

  /// Counterpart: swisseph::types::Body::Pluto
  static const pluto = StandardBody._(9);

  /// Counterpart: swisseph::types::Body::MeanNode
  static const meanNode = StandardBody._(10);

  /// Counterpart: swisseph::types::Body::TrueNode
  static const trueNode = StandardBody._(11);

  /// Counterpart: swisseph::types::Body::MeanApogee
  static const meanApogee = StandardBody._(12);

  /// Counterpart: swisseph::types::Body::OscuApogee
  static const oscuApogee = StandardBody._(13);

  /// Counterpart: swisseph::types::Body::Earth
  static const earth = StandardBody._(14);

  /// Counterpart: swisseph::types::Body::Chiron
  static const chiron = StandardBody._(15);

  /// Counterpart: swisseph::types::Body::Pholus
  static const pholus = StandardBody._(16);

  /// Counterpart: swisseph::types::Body::Ceres
  static const ceres = StandardBody._(17);

  /// Counterpart: swisseph::types::Body::Pallas
  static const pallas = StandardBody._(18);

  /// Counterpart: swisseph::types::Body::Juno
  static const juno = StandardBody._(19);

  /// Counterpart: swisseph::types::Body::Vesta
  static const vesta = StandardBody._(20);

  /// Counterpart: swisseph::types::Body::IntpApogee
  static const intpApogee = StandardBody._(21);

  /// Counterpart: swisseph::types::Body::IntpPerigee
  static const intpPerigee = StandardBody._(22);

  /// Counterpart: swisseph::types::Body::EclipticNutation
  static const eclipticNutation = StandardBody._(-1);

  // -- Payload variant constructors --

  /// Counterpart: swisseph::types::Body::asteroid
  const factory Body.asteroid(AsteroidId id) = AsteroidBody;

  /// Counterpart: swisseph::types::Body::fictitious
  const factory Body.fictitious(FictitiousId id) = FictitiousBody;

  /// Counterpart: swisseph::types::Body::planet_moon
  const factory Body.planetMoon(PlanetMoonId id) = PlanetMoonBody;

  /// Counterpart: swisseph::types::Body (`TryFrom<i32>`)
  factory Body.fromRawId(int rawId) {
    final standard = _standardByRawId[rawId];
    if (standard != null) return standard;
    if (rawId >= 40 && rawId <= 999) {
      return FictitiousBody(FictitiousId(rawId));
    }
    if (rawId >= 9000 && rawId <= 9999) {
      return PlanetMoonBody(PlanetMoonId(rawId - 9000));
    }
    if (rawId >= 10000) {
      return AsteroidBody(AsteroidId(rawId - 10000));
    }
    throw ArgumentError.value(rawId, 'rawId', 'Invalid body ID');
  }

  static final _standardByRawId = {
    for (final b in [
      sun,
      moon,
      mercury,
      venus,
      mars,
      jupiter,
      saturn,
      uranus,
      neptune,
      pluto,
      meanNode,
      trueNode,
      meanApogee,
      oscuApogee,
      earth,
      chiron,
      pholus,
      ceres,
      pallas,
      juno,
      vesta,
      intpApogee,
      intpPerigee,
      eclipticNutation,
    ])
      b.rawValue: b,
  };
}

// --------------------------------------------------------------------------
// Body subtypes (public for exhaustive switch)
// --------------------------------------------------------------------------

/// Counterpart: swisseph::types::Body (standard unit variants)
final class StandardBody extends Body {
  @override
  final int rawValue;

  const StandardBody._(this.rawValue) : super._();

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StandardBody && rawValue == other.rawValue;

  @override
  int get hashCode => rawValue.hashCode;
}

/// Counterpart: swisseph::types::Body::Asteroid
final class AsteroidBody extends Body {
  final AsteroidId id;

  const AsteroidBody(this.id) : super._();

  @override
  int get rawValue => 10000 + id.mpcNumber;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AsteroidBody && id.mpcNumber == other.id.mpcNumber;

  @override
  int get hashCode => id.mpcNumber.hashCode;
}

/// Counterpart: swisseph::types::Body::Fictitious
///
/// Named fictitious body constants mirror `swisseph::types::FictitiousBody`.
final class FictitiousBody extends Body {
  final FictitiousId id;

  const FictitiousBody(this.id) : super._();

  @override
  int get rawValue => id.rawId;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FictitiousBody && id.rawId == other.id.rawId;

  @override
  int get hashCode => id.rawId.hashCode;

  // -- Named fictitious bodies (counterpart: swisseph::types::FictitiousBody) --

  /// Counterpart: swisseph::types::FictitiousBody::Cupido
  static const cupido = FictitiousBody(FictitiousId(40));

  /// Counterpart: swisseph::types::FictitiousBody::Hades
  static const hades = FictitiousBody(FictitiousId(41));

  /// Counterpart: swisseph::types::FictitiousBody::Zeus
  static const zeus = FictitiousBody(FictitiousId(42));

  /// Counterpart: swisseph::types::FictitiousBody::Kronos
  static const kronos = FictitiousBody(FictitiousId(43));

  /// Counterpart: swisseph::types::FictitiousBody::Apollon
  static const apollon = FictitiousBody(FictitiousId(44));

  /// Counterpart: swisseph::types::FictitiousBody::Admetos
  static const admetos = FictitiousBody(FictitiousId(45));

  /// Counterpart: swisseph::types::FictitiousBody::Vulkanus
  static const vulkanus = FictitiousBody(FictitiousId(46));

  /// Counterpart: swisseph::types::FictitiousBody::Poseidon
  static const poseidon = FictitiousBody(FictitiousId(47));

  /// Counterpart: swisseph::types::FictitiousBody::Isis
  static const isis = FictitiousBody(FictitiousId(48));

  /// Counterpart: swisseph::types::FictitiousBody::Nibiru
  static const nibiru = FictitiousBody(FictitiousId(49));

  /// Counterpart: swisseph::types::FictitiousBody::Harrington
  static const harrington = FictitiousBody(FictitiousId(50));

  /// Counterpart: swisseph::types::FictitiousBody::NeptuneLeverrier
  static const neptuneLeverrier = FictitiousBody(FictitiousId(51));

  /// Counterpart: swisseph::types::FictitiousBody::NeptuneAdams
  static const neptuneAdams = FictitiousBody(FictitiousId(52));

  /// Counterpart: swisseph::types::FictitiousBody::PlutoLowell
  static const plutoLowell = FictitiousBody(FictitiousId(53));

  /// Counterpart: swisseph::types::FictitiousBody::PlutoPickering
  static const plutoPickering = FictitiousBody(FictitiousId(54));

  /// Counterpart: swisseph::types::FictitiousBody::Vulcan
  static const vulcan = FictitiousBody(FictitiousId(55));

  /// Counterpart: swisseph::types::FictitiousBody::WhiteMoon
  static const whiteMoon = FictitiousBody(FictitiousId(56));

  /// Counterpart: swisseph::types::FictitiousBody::Proserpina
  static const proserpina = FictitiousBody(FictitiousId(57));

  /// Counterpart: swisseph::types::FictitiousBody::Waldemath
  static const waldemath = FictitiousBody(FictitiousId(58));
}

/// Counterpart: swisseph::types::Body::PlanetMoon
final class PlanetMoonBody extends Body {
  final PlanetMoonId id;

  const PlanetMoonBody(this.id) : super._();

  @override
  int get rawValue => 9000 + id.encoded;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PlanetMoonBody && id.encoded == other.id.encoded;

  @override
  int get hashCode => id.encoded.hashCode;
}
