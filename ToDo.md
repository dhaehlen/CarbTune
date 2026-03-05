Place to write down the things that pop into my head.

## Software
### Android/ iOS App

- [ ] when the units are changed, how should the graph pressure axis change?
- [ ] should the user be able to set the axis on the gauge graph? (effectively zoom in and out)
- [ ] create mock data for testing UI
- [ ] kPa might not make sense as a unit, maybe just Pa
- [ ] mock up time/pressure graph
### Embedded Firmware

- [ ] validate transfer function Claude pulled from sensor spec
- [ ] look into a self calibration routine on start up
- [ ] review 6.7 Engine Calculations - RPM there are some assumptions in there 
## Hardware

### Electronics

- [ ] Evaluate SPI level shift options
- [ ] determine how it will be powered (battery, tap from engine, usb)
- [ ] source capacitors
- [ ] source resistors (consider tolerance incase we use them for voltage dividing)
- [ ] breakout boards for sensors because I bought SMD and that is not great for prototyping on a breadboard
### Mechanical
 
 - [ ] Find suitable tubing
 - [ ] Determine how tubing will be connected to carburetor

## Integrations

- [ ] Determine BLE payload
- [ ] UI component when sensors are calibrating so that users are aware
- [ ] Warn users of out of range readings
- [ ] calculating RPM will be more accurate if we take into account the number of cylinders we are measuring
## Overall Project

- [ ] Create BOM

---
## Incomplete Functional Requirements

## App

1. shall have a button for selecting the units for all pressure readouts. Options are: kPa, PSI, mbar, and cmHg. When the user clicks the button a modal should appear displaying all the options and allows the user to select their choice. There should be a button to confirm the choice or to exit and leave the choice unchanged.
2. 4 gauges one for each sensor. They will be linear gauges similar to loading bars set next to each other for easy visual comparison.
3. be able to mark sensors as deactivated, in situations where fewer than 4 sensors are in use
4. single sensor view? instead of side by side bar graph, select sensor and see a standard guage and readout, with time/pressure graph 
5. set tolerance for tuning range, so that when pressure is within range we can change color or make a tone <- a tone might be a good feature for tuning without looking at the gauge (like tuning an instrument)