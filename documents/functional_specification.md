# Functional Specification Document
## ESP32 Carburetor Pressure Monitor & Engine Tuning Tool

| Field        | Value                        |
|--------------|------------------------------|
| Version      | 1.1                          |
| Date         | 2026-03-12                   |
| Status       | In Review                    |

---

## 1. Purpose

This document describes the functional requirements for a wireless engine-tuning tool that reads manifold absolute pressure (MAP / vacuum) from one or more carburetor pressure sensors via an ESP32 microcontroller and streams the data to a dedicated mobile application on the user's smartphone.

---

## 2. Background & Motivation

Accurate carburetor tuning requires real-time feedback on the vacuum level present in the intake tract. Traditional vacuum gauges are analogue, single-point, and inconvenient to read while riding or during bench tuning. This system replaces the analogue gauge with a digital, wireless sensor node that provides live data, logging, and analysis on a smartphone.

The initial target engine is the **Honda CB400F** (four-cylinder, four-carburetor). The expected balanced idle vacuum for this engine is **16–24 cmHg** (approximately 98.1–99.2 kPa absolute). This range serves as the factory default target in the mobile app and the basis for sensor range validation.

---

## 3. Scope

### 3.1 In Scope
- ESP32 firmware for sensor acquisition and wireless data transmission
- Mobile application (iOS and Android) for data display and tuning guidance
- Wireless communication link between ESP32 and the mobile app
- Basic data logging and session review

### 3.2 Out of Scope
- Fuel injection control or ECU integration
- Cloud storage or remote telemetry
- PC/desktop client software
- CAN bus or OBD-II interfaces

---

## 4. Stakeholders

| Role               | Responsibility                                              |
|--------------------|-------------------------------------------------------------|
| End User / Tuner   | Operates the tool during engine tuning sessions             |
| Firmware Engineer  | Develops and maintains ESP32 firmware                       |
| Mobile Developer   | Develops and maintains the iOS/Android application          |
| Hardware Designer  | Selects and integrates sensors and PCB                      |

---

## 5. System Overview

```
┌──────────────────────────────────────┐
│             Engine Bay               │
│                                      │
│  [NXP MPXH6115AC6U × 1–4]            │
│       │  (analog voltage output)     │
│       ▼                              │
│  [ESP32 Microcontroller]             │
│       │                              │
│       │  BLE (primary)               │
│       │  Wi-Fi web UI (stretch)      │
└───────┼──────────────────────────────┘
        │
        ▼
  [User's Smartphone]
  ┌─────────────────┐
  │  Mobile App     │
  │  iOS / Android  │
  │  - Live gauges  │
  │  - Logging      │
  │  - Tuning guide │
  └─────────────────┘
```

---

## 6. Functional Requirements

### 6.1 Sensor Acquisition (ESP32 Firmware)

| ID    | Requirement                                                                                                                                                                                                                                                                                                    | Priority |
| ----- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | -------- |
| SA-01 | The system shall support 1 to 4 MAP/vacuum sensors. The primary use case is 4 sensors (one per carburetor).                                                                                                                                                                                                    | High     |
| SA-02 | Each sensor shall be sampled at a minimum rate of **200 Hz**; target **500 Hz**.                                                                                                                                                                                                                               | High     |
| SA-03 | Pressure readings shall be stored internally as kPa (absolute) and converted to the user's chosen display unit (cmHg, inHg, kPa, mbar). The default display unit shall be **cmHg**.                                                                                                                            | High     |
| SA-04 | The firmware shall apply configurable sensor calibration offsets and scale factors.                                                                                                                                                                                                                            | Medium   |
| SA-05 | The firmware shall detect and flag out-of-range sensor readings.                                                                                                                                                                                                                                               | Medium   |
| SA-06 | The pressure sensor shall be the **NXP MPXH6115AC6U** (Freescale MPXH6115A series). It is an analog output, absolute pressure sensor with an operating range of **15 to 115 kPa** (~11 - 86 cmMg).                                                                                                             | High     |
| SA-07 | Sensor V_OUT shall be sampled by a **Microchip MCP3208** external SPI ADC (12-bit, 8-channel, single supply 2.7–5.5 V). The MCP3208 shall be powered at **3.3 V**, making its SPI interface directly compatible with the ESP32 with no level shifting required.                                                | High     |
| SA-08 | The pressure sensors require a **5.0 V supply** (4.75–5.25 V). A 5 V rail shall be provided on the PCB for all sensors. The MCP3208 is powered separately at 3.3 V.                                                                                                                                            | High     |
| SA-09 | The MCP3208 input range at 3.3 V supply is **0–3.3 V**. A resistor voltage divider shall be fitted on each sensor channel to scale V_OUT (0.2–4.7 V) into this range. Recommended values: **R1 = 30 kΩ, R2 = 68 kΩ** (divider ratio 0.694; max divided voltage at 115 kPa = 3.26 V, using 98.8% of ADC range). | High     |
| SA-10 | The firmware shall apply the sensor transfer function **V_OUT = V_S × (0.009 × P − 0.095)** (rearranged for P) when converting ADC counts to kPa.                                                                                                                                                              | High     |
| SA-11 | The firmware shall recover actual V_OUT from the MCP3208 ADC count using: **V_OUT = (ADC_count / 4096) × 3.3 / 0.694** before applying the transfer function.                                                                                                                                                  | High     |
| SA-12 | The MCP3208 shall communicate with the ESP32 via SPI (mode 0,0 or 1,1). SPI clock shall not exceed **2 MHz** at 3.3 V supply. The 4 active sensor channels shall use MCP3208 channels 0–3; channels 4–7 are reserved for future expansion.                                                                     | High     |

---

### 6.2 Wireless Communication

| ID    | Requirement                                                                                                           | Priority |
| ----- | --------------------------------------------------------------------------------------------------------------------- | -------- |
| WC-01 | The ESP32 shall advertise as a BLE peripheral and expose a GATT notify characteristic for pressure data.              | High     |
| WC-02 | The ESP32 shall request a BLE connection interval of 7.5–15 ms to meet the end-to-end latency requirement.            | High     |
| WC-03 | The ESP32 shall negotiate an MTU sufficient to carry a full 4-sensor data packet without fragmentation.               | High     |
| WC-04 | The data packet shall include: timestamp (ms), per-sensor pressure values (kPa) and status flags, and calculated RPM. | High     |
| WC-05 | End-to-end latency from sensor read to phone display shall be ≤ 200 ms.                                               | Medium   |
| WC-06 | The connection shall tolerate temporary signal loss of up to 2 s and auto-reconnect.                                  | Medium   |
| WC-07 | The protocol shall be versioned to allow firmware and app updates independently.                                      | Low      |

### 6.3 Mobile Application — General

| ID     | Requirement                                                                                                            | Priority |
| ------ | ---------------------------------------------------------------------------------------------------------------------- | -------- |
| MA-01  | The app shall be built using **Flutter** (Dart) targeting iOS (≥ 16) and Android (≥ 10) from a single codebase.        | High     |
| MA-01a | BLE communication shall use the **flutter_blue_plus** package (or equivalent actively maintained Flutter BLE library). | High     |
| MA-02  | The app shall discover and pair with the ESP32 device automatically.                                                   | High     |
| MA-03  | The app shall display connection status (connected / disconnected / searching).                                        | High     |
| MA-04  | The app shall function without an internet connection.                                                                 | High     |

### 6.4 Mobile Application — Live Display

| ID    | Requirement                                                                                               | Priority |
| ----- | --------------------------------------------------------------------------------------------------------- | -------- |
| LD-01 | The app shall display a real-time vacuum gauge for each connected sensor.                                 | High     |
| LD-02 | Gauge units shall be selectable: kPa, PSI, inHg, cmHg, mbar.                                              | Medium   |
| LD-03 | The app shall display a numerical readout alongside the gauge.                                            | High     |
| LD-04 | The app shall display a live scrolling graph (time vs. pressure) with a configurable time window.         | High     |
| LD-05 | When multiple sensors are connected, the app shall display readings side-by-side for balance/sync tuning. | Medium   |
| LD-06 | The app shall highlight readings that are outside user-defined target ranges (e.g. colour coding).        | Medium   |
| LD-07 | The display shall remain readable in bright sunlight (high-contrast mode or brightness control).          | Low      |
| LD-08 | The app shall display the calculated engine RPM as a numerical readout alongside the vacuum gauges.       | Medium   |
| LD-09 | The balance view shall display four linear bar gauges arranged side by side — one per sensor. In portrait orientation the bars shall be vertical; in landscape orientation the bars shall be horizontal. The bar fill shall reflect the current (averaged) vacuum reading relative to a fixed scale (default 0–30 cmHg). | High     |
| LD-10 | Gauge unit selection shall be accessible via a clearly labelled button showing the current unit. Tapping the button shall open a modal dialog listing all available units (see LD-02) as radio button options with Cancel and Confirm actions. The selection shall apply immediately to all gauges and readouts on confirm. | Medium   |
| LD-11 | The balance view shall display a user-adjustable target pressure line overlaid across all gauges. The line shall be draggable to any position within the gauge scale. Gauge bars shall be coloured to indicate whether the averaged reading is at or above the target (green) or below it (amber). | High     |
| LD-12 | The displayed pressure value for each sensor shall be a rolling average over a configurable time window (default: **5 s**). This mimics the damping effect of a traditional plenum or damper valve, providing a steady reading suitable for tuning. The averaging window shall be user-adjustable at runtime via an in-app control without requiring an app restart. | High     |

#### Unit Conversion Table

This table documents the conversion factor for each unit from the default cmHg (centimeters of mercury).

| Unit                   | Symbol | Conversion      |
| ---------------------- | ------ | --------------- |
| Inches of Mercury      | inHg   | cmHg / 2.54     |
| Kilopascals            | kPa    | cmHg * 0.133322 |
| Millibars              | mbar   | cmHg * 1.33322  |
| Pounds per Square Inch | PSI    | cmHg * 0.019337 |

### 6.5 Mobile Application — Data Logging

| ID    | Requirement                                                                                                   | Priority |
| ----- | ------------------------------------------------------------------------------------------------------------- | -------- |
| DL-01 | The user shall be able to start and stop named logging sessions from within the app.                          | High     |
| DL-02 | Log files shall be stored locally on the phone in a standard format (CSV or JSON).                            | High     |
| DL-03 | The user shall be able to review past sessions as a graph and numerical summary.                              | Medium   |
| DL-04 | Log files shall be exportable via standard OS share sheet (email, AirDrop, etc.).                             | Medium   |
| DL-05 | Minimum recorded fields per sample: timestamp, sensor ID, pressure (kPa), unit display value, calculated RPM. | High     |

### 6.6 Mobile Application — Tuning Guidance

| ID    | Requirement                                                                                                                                                                                      | Priority |
| ----- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ | -------- |
| TG-01 | The app shall ship with a default target vacuum range of **16–24 cmHg** (Honda CB400F baseline). The user shall be able to override the target range per sensor for other engine configurations. | Medium   |
| TG-02 | The app shall provide a visual indicator (e.g. progress bar or needle zone) showing how far off-target the reading is.                                                                           | Medium   |
| TG-03 | A sync view (for multi-sensor setups) shall show the difference between sensors to assist balancing.                                                                                             | Medium   |

### 6.7 Engine Calculations — RPM

Engine RPM shall be derived from the intake vacuum pulse signal detected in the MAP sensor data. No additional sensor or ignition tap is required.

**Principle:** On a 4-stroke 4-cylinder engine, each intake stroke produces a detectable vacuum drop in the carburetor throat. With cylinders firing 90° apart, 4 pulses occur per 2 crank revolutions. Measuring the inter-pulse timing gives engine speed.

**Timing resolution analysis at 500 Hz (2 ms per sample):**

| RPM  | Rev period | Samples/rev | Inter-pulse period | ±1 sample error (raw) | ±1 sample error (8-pulse avg) |
|------|------------|-------------|--------------------|-----------------------|-------------------------------|
| 1000 | 60 ms      | 30          | 15 ms              | ±67 RPM               | ±8 RPM                        |
| 3000 | 20 ms      | 10          | 5 ms               | ±200 RPM              | ±25 RPM                       |
| 6000 | 10 ms      | 5           | 2.5 ms             | ±400 RPM              | ±50 RPM                       |

A rolling average over 8 pulse periods gives acceptable accuracy across the tuning RPM range (idle to ~4000 RPM). Accuracy is best at idle and low RPM — exactly where carburetor balancing takes place.

**Known limitations:**
- Pulse amplitude varies with throttle position; detection threshold must be adaptive.
- Rapid throttle changes or very low RPM (<500) may produce unreliable readings.
- The calculated RPM is a firmware-side estimate; it is not a substitute for a dedicated tachometer signal.

| ID     | Requirement                                                                                                  | Priority |
|--------|--------------------------------------------------------------------------------------------------------------|----------|
| EC-01  | The firmware shall detect intake vacuum pulses in the MAP sensor signal by identifying threshold-crossing events on the rate of pressure change (dP/dt). | High     |
| EC-02  | The pulse detection threshold shall be adaptive, adjusting to the recent peak-to-peak signal amplitude to remain robust across varying throttle positions. | Medium   |
| EC-03  | The firmware shall calculate RPM using a rolling average of the most recent **8 inter-pulse periods** across all active sensors. | High     |
| EC-04  | RPM shall be calculated as: `RPM = (4 × 60) / (N_cylinders × T_avg_pulse)` where T_avg_pulse is the mean inter-pulse period in seconds. | High     |
| EC-05  | The firmware shall flag the RPM value as invalid when fewer than 2 consecutive pulses have been detected within the last 500 ms. | Medium   |
| EC-06  | The calculated RPM shall be included in each BLE data packet (see WC-04).                                    | High     |

---

## 7. Stretch Goals

Stretch goals are desirable features that are out of scope for the initial release but should be considered during architecture and firmware design to avoid closing off future implementation.

| ID    | Goal                                                                                                    |
|-------|---------------------------------------------------------------------------------------------------------|
| SG-01 | **Wi-Fi diagnostic web UI:** The ESP32 shall optionally host a lightweight web page over Wi-Fi (AP mode) that displays live sensor readings in a browser. This provides a fallback diagnostic tool without requiring the mobile app to be installed. The BLE primary transport shall remain unaffected when this mode is active. |

---

## 8. Non-Functional Requirements

| ID    | Requirement                                                                                           |
| ----- | ----------------------------------------------------------------------------------------------------- |
| NF-01 | The ESP32 module shall operate from 5 V or 3.3 V supplied by the vehicle's electrical system.         |
| NF-02 | ESP32 firmware shall be updateable over-the-air (OTA) without requiring specialist equipment.         |
| NF-03 | The system shall be resilient to vibration and electromagnetic interference typical of an engine bay. |
| NF-04 | The mobile app binary size shall not exceed 50 MB.                                                    |
| NF-05 | All stored data shall remain on the user's device; no data is transmitted to external servers.        |

---

## 9. Open Questions & Decisions Required

| #     | Question                                                                                                                                                                                                  | Owner                   | Target Date                                                                                                                                            |
| ----- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ----------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------ |
| ~~1~~ | ~~**Wireless transport:** BLE vs. Wi-Fi — evaluate range, power, and pairing UX.~~                                                                                                                        | ~~Hardware / Firmware~~ | **Resolved 2026-02-25** — BLE selected. Wi-Fi web UI added as stretch goal SG-01. See WC-01 to WC-07.                                                  |
| ~~2~~ | ~~**Sensor selection:** Identify MAP sensor part number, interface type (analog / I²C / SPI), and pressure range.~~                                                                                       | ~~Hardware Designer~~   | **Resolved 2026-02-25** — NXP MPXH6115AC6U, analog output, 15–115 kPa, 5 V supply. Voltage divider required for ESP32 ADC (see SA-06 to SA-11).        |
| ~~3~~ | ~~**Number of sensors:** Confirm minimum and maximum sensor count for target engine configurations.~~                                                                                                     | ~~End User / PM~~       | **Resolved 2026-02-25** — min 1, max 4, primary use case 4.                                                                                            |
| ~~4~~ | ~~**Mobile framework:** Native Swift/Kotlin vs. cross-platform (Flutter, React Native).~~                                                                                                                 | ~~Mobile Developer~~    | **Resolved 2026-02-25** — Flutter selected. See MA-01 and MA-01a.                                                                                      |
| ~~5~~ | ~~**Target vacuum range:** Confirm typical MAP/vacuum values for the engine type being tuned.~~                                                                                                           | ~~End User~~            | **Resolved 2026-02-25** — Honda CB400F, target 16–24 cmHg (~98.1–99.2 kPa absolute). Set as app default in TG-01.                                      |
| ~~6~~ | ~~**External ADC selection:** Choose SPI ADC part. Prefer split AVDD (5 V) / DVDD (3.3 V) to avoid voltage divider on sensor channels. Minimum 4 channels, minimum 12-bit, minimum 10 kSPS per channel.~~ | ~~Hardware Designer~~   | **Resolved 2026-02-25** — MCP3208 selected for prototype. 3.3 V supply, voltage divider required (R1=30 kΩ, R2=68 kΩ). See SA-07 to SA-12 and ADR-009. |

---

## 10. Glossary

| Term  | Definition                                                                 |
|-------|----------------------------------------------------------------------------|
| ESP32 | Espressif Systems dual-core microcontroller with integrated BLE and Wi-Fi  |
| MAP   | Manifold Absolute Pressure                                                 |
| kPa   | Kilopascal — SI unit of pressure                                           |
| inHg  | Inches of mercury — common unit for vacuum measurement                     |
| BLE   | Bluetooth Low Energy                                                       |
| OTA   | Over-The-Air firmware update                                               |
| GATT  | Generic Attribute Profile — BLE data exchange standard                     |
| Flutter | Google's open-source UI framework using Dart; compiles to native iOS and Android |
| Dart  | Programming language used by Flutter                                       |

---

## 11. Revision History

| Version | Date       | Author  | Notes          |
|---------|------------|---------|----------------|
| 0.1     | 2026-02-25 | —       | Initial draft  |
| 0.2     | 2026-02-25 | —       | SA-01 updated: sensor count confirmed as min 1, max 4, primary use case 4 |
| 0.3     | 2026-02-25 | —       | SA-06 to SA-11 added: sensor confirmed as NXP MPXH6115AC6U, analog interface, 5 V supply, voltage divider requirement, transfer function |
| 0.4     | 2026-02-25 | —       | WC section updated: BLE selected as primary transport, WC-01 to WC-07 revised. Section 7 (Stretch Goals) added with SG-01 Wi-Fi web UI fallback. Sections renumbered. |
| 0.5     | 2026-02-25 | —       | Target engine confirmed as Honda CB400F. SA-03 updated: default display unit cmHg. TG-01 updated: default target range 16–24 cmHg. Background section updated. |
| 0.6     | 2026-02-25 | —       | Mobile framework confirmed as Flutter. MA-01 updated, MA-01a added for BLE library. Glossary updated. |
| 0.7     | 2026-02-25 | —       | SA-02 revised: minimum 200 Hz, target 500 Hz. Nyquist and BLE bandwidth rationale added as design note under SA-02. |
| 0.8     | 2026-02-25 | —       | Section 6.7 added: RPM calculation from MAP pulse detection (EC-01 to EC-06). WC-04 updated to include RPM in packet. LD-08 and DL-05 updated. |
| 0.9     | 2026-02-25 | —       | SA-07 to SA-12 revised: external SPI ADC adopted in place of ESP32 internal ADC. Split AVDD/DVDD preference documented. Open question 6 added for ADC part selection. |
| 1.0     | 2026-02-25 | —       | MCP3208 selected as ADC for prototype (SA-07 to SA-12 updated with part specifics, divider values, firmware formula). All open questions resolved. |
| 1.1     | 2026-03-12 | —       | LD-09 to LD-12 added: four linear bar gauges (LD-09), unit selector button and modal (LD-10), draggable target pressure line with colour-coded bars (LD-11), rolling average display with runtime-adjustable window (LD-12). Unit conversion factors section added. |
