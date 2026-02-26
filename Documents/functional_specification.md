# Functional Specification Document
## ESP32 Carburetor Pressure Monitor & Engine Tuning Tool

| Field        | Value                        |
|--------------|------------------------------|
| Version      | 0.1 (Draft)                  |
| Date         | 2026-02-25                   |
| Status       | In Review                    |

---

## 1. Purpose

This document describes the functional requirements for a wireless engine-tuning tool that reads manifold absolute pressure (MAP / vacuum) from one or more carburetor pressure sensors via an ESP32 microcontroller and streams the data to a dedicated mobile application on the user's smartphone.

---

## 2. Background & Motivation

Accurate carburetor tuning requires real-time feedback on the vacuum level present in the intake tract. Traditional vacuum gauges are analogue, single-point, and inconvenient to read while riding or during bench tuning. This system replaces the analogue gauge with a digital, wireless sensor node that provides live data, logging, and analysis on a smartphone.

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
│  [Pressure Sensor(s)]                │
│       │  (analog / I²C / SPI)        │
│       ▼                              │
│  [ESP32 Microcontroller]             │
│       │                              │
│       │  Wireless Link               │
│       │  (BLE or Wi-Fi — TBD)        │
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

| ID    | Requirement                                                                                   | Priority |
|-------|-----------------------------------------------------------------------------------------------|----------|
| SA-01 | The system shall support 1 to 4 MAP/vacuum sensors. The primary use case is 4 sensors (one per carburetor). | High     |
| SA-02 | Each sensor shall be sampled at a minimum rate of 10 Hz; target ≥ 50 Hz.                      | High     |
| SA-03 | Pressure readings shall be expressed in kPa (absolute) and converted to inHg for display.    | High     |
| SA-04 | The firmware shall apply configurable sensor calibration offsets and scale factors.           | Medium   |
| SA-05 | The firmware shall detect and flag out-of-range sensor readings.                              | Medium   |
| SA-06 | The pressure sensor shall be the **NXP MPXH6115AC6U** (Freescale MPXH6115A series). It is an analog output, absolute pressure sensor with an operating range of **15 to 115 kPa**. | High     |
| SA-07 | The sensor interface is **analog voltage output**. The ESP32 ADC shall be used to sample V_OUT on each sensor. | High     |
| SA-08 | The sensor requires a **5.0 V supply** (4.75–5.25 V). A 5 V rail shall be provided on the PCB for all sensors. | High     |
| SA-09 | The sensor output ranges from ~0.2 V (15 kPa) to ~4.7 V (115 kPa). A **resistor voltage divider** shall scale V_OUT to the ESP32 ADC input range (0–3.3 V) on each sensor channel. | High     |
| SA-10 | The firmware shall apply the sensor transfer function **V_OUT = V_S × (0.009 × P − 0.095)** (rearranged for P) when converting ADC counts to kPa. | High     |
| SA-11 | The firmware shall account for the voltage divider ratio when computing the actual V_OUT from the ADC reading. | High     |

### 6.2 Wireless Communication

> **Decision Pending:** The wireless transport (BLE vs. Wi-Fi) is not yet decided. Both options are documented below. A final decision shall be made during hardware design review.

| ID    | Requirement                                                                                             | Priority |
|-------|---------------------------------------------------------------------------------------------------------|----------|
| WC-01 | **[BLE option]** The ESP32 shall advertise as a BLE peripheral and expose a GATT characteristic for pressure data. | High |
| WC-02 | **[Wi-Fi option]** The ESP32 shall host a WebSocket server and stream pressure data to connected clients. | High |
| WC-03 | The data packet shall include: timestamp (ms), sensor ID, pressure value (kPa), and status flag.        | High     |
| WC-04 | End-to-end latency from sensor read to phone display shall be ≤ 200 ms.                                 | Medium   |
| WC-05 | The connection shall tolerate temporary signal loss of up to 2 s and auto-reconnect.                    | Medium   |
| WC-06 | The protocol shall be versioned to allow firmware and app updates independently.                        | Low      |

### 6.3 Mobile Application — General

| ID    | Requirement                                                                                             | Priority |
|-------|---------------------------------------------------------------------------------------------------------|----------|
| MA-01 | The app shall be available on iOS (≥ 16) and Android (≥ 10).                                           | High     |
| MA-02 | The app shall discover and pair with the ESP32 device automatically.                                    | High     |
| MA-03 | The app shall display connection status (connected / disconnected / searching).                         | High     |
| MA-04 | The app shall function without an internet connection.                                                  | High     |

### 6.4 Mobile Application — Live Display

| ID    | Requirement                                                                                             | Priority |
|-------|---------------------------------------------------------------------------------------------------------|----------|
| LD-01 | The app shall display a real-time vacuum gauge for each connected sensor.                               | High     |
| LD-02 | Gauge units shall be selectable: kPa, inHg, cmHg, mbar.                                                | Medium   |
| LD-03 | The app shall display a numerical readout alongside the gauge.                                          | High     |
| LD-04 | The app shall display a live scrolling graph (time vs. pressure) with a configurable time window.       | High     |
| LD-05 | When multiple sensors are connected, the app shall display readings side-by-side for balance/sync tuning. | Medium |
| LD-06 | The app shall highlight readings that are outside user-defined target ranges (e.g. colour coding).      | Medium   |
| LD-07 | The display shall remain readable in bright sunlight (high-contrast mode or brightness control).        | Low      |

### 6.5 Mobile Application — Data Logging

| ID    | Requirement                                                                                             | Priority |
|-------|---------------------------------------------------------------------------------------------------------|----------|
| DL-01 | The user shall be able to start and stop named logging sessions from within the app.                    | High     |
| DL-02 | Log files shall be stored locally on the phone in a standard format (CSV or JSON).                     | High     |
| DL-03 | The user shall be able to review past sessions as a graph and numerical summary.                        | Medium   |
| DL-04 | Log files shall be exportable via standard OS share sheet (email, AirDrop, etc.).                       | Medium   |
| DL-05 | Minimum recorded fields per sample: timestamp, sensor ID, pressure (kPa), unit display value.          | High     |

### 6.6 Mobile Application — Tuning Guidance

| ID    | Requirement                                                                                             | Priority |
|-------|---------------------------------------------------------------------------------------------------------|----------|
| TG-01 | The user shall be able to set a target vacuum range per sensor.                                         | Medium   |
| TG-02 | The app shall provide a visual indicator (e.g. progress bar or needle zone) showing how far off-target the reading is. | Medium |
| TG-03 | A sync view (for multi-sensor setups) shall show the difference between sensors to assist balancing.   | Medium   |

---

## 7. Non-Functional Requirements

| ID    | Requirement                                                                                             |
|-------|---------------------------------------------------------------------------------------------------------|
| NF-01 | The ESP32 module shall operate from 5 V or 3.3 V supplied by the vehicle's electrical system.          |
| NF-02 | ESP32 firmware shall be updateable over-the-air (OTA) without requiring specialist equipment.          |
| NF-03 | The system shall be resilient to vibration and electromagnetic interference typical of an engine bay.  |
| NF-04 | The mobile app binary size shall not exceed 50 MB.                                                     |
| NF-05 | All stored data shall remain on the user's device; no data is transmitted to external servers.         |

---

## 8. Open Questions & Decisions Required

| #  | Question                                                          | Owner              | Target Date |
|----|-------------------------------------------------------------------|--------------------|-------------|
| 1  | **Wireless transport:** BLE vs. Wi-Fi — evaluate range, power, and pairing UX. | Hardware / Firmware | TBD |
| ~~2~~ | ~~**Sensor selection:** Identify MAP sensor part number, interface type (analog / I²C / SPI), and pressure range.~~ | ~~Hardware Designer~~ | **Resolved 2026-02-25** — NXP MPXH6115AC6U, analog output, 15–115 kPa, 5 V supply. Voltage divider required for ESP32 ADC (see SA-06 to SA-11). |
| ~~3~~ | ~~**Number of sensors:** Confirm minimum and maximum sensor count for target engine configurations.~~ | ~~End User / PM~~ | **Resolved 2026-02-25** — min 1, max 4, primary use case 4. |
| 4  | **Mobile framework:** Native Swift/Kotlin vs. cross-platform (Flutter, React Native). | Mobile Developer | TBD |
| 5  | **Target vacuum range:** Confirm typical MAP/vacuum values for the engine type being tuned. | End User | TBD |

---

## 9. Glossary

| Term  | Definition                                                                 |
|-------|----------------------------------------------------------------------------|
| ESP32 | Espressif Systems dual-core microcontroller with integrated BLE and Wi-Fi  |
| MAP   | Manifold Absolute Pressure                                                 |
| kPa   | Kilopascal — SI unit of pressure                                           |
| inHg  | Inches of mercury — common unit for vacuum measurement                     |
| BLE   | Bluetooth Low Energy                                                       |
| OTA   | Over-The-Air firmware update                                               |
| GATT  | Generic Attribute Profile — BLE data exchange standard                     |

---

## 10. Revision History

| Version | Date       | Author  | Notes          |
|---------|------------|---------|----------------|
| 0.1     | 2026-02-25 | —       | Initial draft  |
| 0.2     | 2026-02-25 | —       | SA-01 updated: sensor count confirmed as min 1, max 4, primary use case 4 |
| 0.3     | 2026-02-25 | —       | SA-06 to SA-11 added: sensor confirmed as NXP MPXH6115AC6U, analog interface, 5 V supply, voltage divider requirement, transfer function |
