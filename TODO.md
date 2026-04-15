
active
  (none)


follow-ups (tracked separately)

#2 change tropical/sidereal automatically changing ayanamsa to something suitable
    — split zodiac (tropical|sidereal) from ayanamsa choice in ContextBarState;
      remember last sidereal ayanamsa across zodiac toggles; greys out when tropical.
      Touches every tab that reads ayanamsa; needs a migration for persisted state.

#5 add a small atlas
    — bundled CSV (GeoNames cities1000 trimmed ~5MB) + typeahead in ContextBar
      location field; IANA tz via package:timezone. Alternative: Nominatim online.

#6 see if v2 swisseph.dart methods are useful
    — triage bucket, not a single feature. Quick wins: difDegn/difDeg2n for math
      tab, housesEx for Houses, solEclipseHow/lunEclipseHow panels on Eclipses,
      Gauquelin sector, lunar occultations, heliacal extras. Accuracy knobs
      (deltatEx, setTidAcc, setLapseRate, refracExtended, setInterpolateNut,
      ET variants) → Advanced section on FlagBar. Date helpers → serve via
      Code View feature (doc/swe-dashboard-v2.md), not new UI.
    source list:
      date/time: julday, utcToJd, jdToUtc, jdetToUtc, utcTimeZone, dateConversion
      ET variants: calc, getAyanamsa, fixstar2, solCross, moonCross,
        moonCrossNode, helioCross, nodAps, pheno
      extended ayanamsa: getAyanamsaExUt, getAyanamsaEx
      extended houses: housesEx, housesEx2, housesArmc, housesArmcEx2, housePos
      Gauquelin sector: gauquelinSector
      eclipse "how" + lunar occultations: solEclipseHow, lunEclipseHow,
        lunOccultWhenLoc, lunOccultWhenGlob, lunOccultWhere
      rise/set true-horizon: riseTransTrueHor
      angular difference: difDegn, difDeg2n
      refraction/time/tidal: refracExtended, deltatEx, sidTime0,
        setDeltaTUserdef, getTidAcc, setTidAcc
      heliacal extras: heliacalPhenoUt, visLimitMag
      config/misc: setJplFile, getLibraryPath, getCurrentFileData,
        setInterpolateNut, setLapseRate


defer

verify charts file types correctly implemented
implement writing these chart types
