# ds3231-spin 
-------------

This is a P8X32A/Propeller, P2X8C4M64P/Propeller 2 driver object for the DS3231 Real-Time Clock.

**IMPORTANT**: This software is meant to be used with the [spin-standard-library](https://github.com/avsa242/spin-standard-library) (P8X32A) or [p2-spin-standard-library](https://github.com/avsa242/p2-spin-standard-library) (P2X8C4M64P). Please install the applicable library first before attempting to use this code, otherwise you will be missing several files required to build the project.

## Salient Features

* I2C connection at up to 400kHz
* Read and set days, hours, months, minutes, seconds, weekday, year (individually)
* Read on-chip temperature sensor

## Requirements

P1/SPIN1:
* spin-standard-library
* 1 extra core/cog for the PASM I2C engine

P2/SPIN2:
* p2-spin-standard-library

## Compiler Compatibility

* P1/SPIN1: OpenSpin (tested with 1.00.81), FlexSpin (tested with 5.2.1-beta)
* P2/SPIN2: FlexSpin (tested with 5.2.1-beta)
* ~~BST~~ (incompatible - no preprocessor)
* ~~Propeller Tool~~ (incompatible - no preprocessor)
* ~~PNut~~ (incompatible - no preprocessor)

## Limitations

* Very early in development - may malfunction, or outright fail to build

## TODO

- [x] Add support for setting square wave output freq
- [x] Add support for reading on-chip temperature sensor
- [x] Add support for interrupts
- [x] Add support for oscillator control
- [x] Add support for oscillator stop flag
- [x] Add support for oscillator aging offset
- [ ] Add support for pure-SPIN I2C engine
- [x] Port to P2/SPIN2
