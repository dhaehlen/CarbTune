# Architecture Decision Records
## ESP32 Carburetor Pressure Monitor & Engine Tuning Tool

| Field   | Value         |
|---------|---------------|
| Version | 1.0           |
| Date    | 2026-02-25    |
| Status  | Living Document — append new records as decisions are made |

Architecture Decision Records (ADRs) capture significant design choices: the context that forced a decision, the options considered, the outcome, and the consequences. This document is the authoritative record of why the system is designed the way it is.

---

## ADR-001 — Wireless Transport Protocol

| Field   | Value              |
|---------|--------------------|
| Date    | 2026-02-25         |
| Status  | **Accepted**       |
| Refs    | FSD WC-01 to WC-07, SG-01 |

### Context
The ESP32 must transmit continuous sensor data to a smartphone app. The ESP32 supports three wireless options: BLE, Wi-Fi, and Bluetooth Classic (BR/EDR). A transport had to be chosen before the mobile app and firmware could be designed.

### Options Considered

**Option A — BLE (Bluetooth Low Energy)**
- Native GATT notify pattern suited to sensor streaming
- Phone retains its own Wi-Fi connection during use
- Simple, automatic device discovery from app
- Fast and reliable reconnection after signal loss
- Lower power draw than Wi-Fi or Classic BT
- Well supported by Flutter via `flutter_blue_plus`
- BLE 4.2 practical bandwidth: ~200 kbps
- BLE 5.0 (ESP32-S3): ~1.3 Mbps

**Option B — Wi-Fi (HTTP/WebSocket)**
- Higher bandwidth headroom
- Phone must join ESP32's hotspot (AP mode), losing its own internet connection
- iOS warns the user the network has no internet and may auto-disconnect
- Slower, more complex reconnection behaviour
- Higher ESP32 power consumption (~80–170 mA active vs ~10–30 mA BLE)
- Requires SSID/password provisioning on first use

**Option C — Bluetooth Classic (BR/EDR / SPP)**
- Practical throughput ~300–400 kbps (higher than BLE 4.2)
- **Hard blocker on iOS:** Apple restricts Classic BT to MFi-certified accessories only. Third-party apps cannot use it via a public API without an Apple authentication chip on the PCB and MFi programme enrolment (significant cost, time, and ongoing licensing)
- Available only on original ESP32 (WROOM/WROVER); not on ESP32-S3, C3, or S2 — constrains hardware choice
- No maintained cross-platform Flutter library for Classic BT that covers iOS
- Higher power consumption than BLE

### Decision
**BLE selected as the primary transport (Option A).** Wi-Fi retained as a stretch goal for a browser-accessible diagnostic web UI (SG-01), without displacing BLE.

### Rationale
- Our data rate (4 sensors × 500 Hz × ~31 bytes/packet ≈ 124 kbps) sits comfortably at 62% of BLE 4.2 capacity. There is no bandwidth problem to solve.
- Classic BT is blocked on iOS for third-party apps without MFi certification — a hard, non-negotiable constraint for a cross-platform product.
- BLE provides the best user experience: no network switching, no configuration, seamless auto-reconnect.
- If bandwidth ever becomes a constraint (e.g. higher sample rates), upgrading to an ESP32-S3 with BLE 5.0 (2M PHY, ~1.3 Mbps) resolves it without changing the protocol.

### Consequences
- Firmware must request a BLE connection interval of 7.5–15 ms to meet ≤200 ms latency requirement.
- MTU negotiation required to fit a full 4-sensor packet without fragmentation.
- Flutter BLE library (`flutter_blue_plus`) must be maintained and kept up to date for iOS/Android compatibility.
- Hardware choice of ESP32 variant should prefer S3 or later to ensure BLE 5.0 availability.

---

## ADR-002 — Pressure Sensor Selection

| Field   | Value              |
|---------|--------------------|
| Date    | 2026-02-25         |
| Status  | **Accepted**       |
| Refs    | FSD SA-06 to SA-11 |

### Context
A pressure sensor was needed to measure intake manifold vacuum in the carburetor throat. The sensor must interface with the ESP32, survive an engine bay environment, and cover the expected vacuum range for the target engine.

### Options Considered

**Option A — NXP MPXH6115AC6U (selected)**
- Absolute pressure, 15–115 kPa operating range
- Analog voltage output (V_OUT)
- Supply: 5.0 V (4.75–5.25 V)
- Sensitivity: 45.0 mV/kPa
- Accuracy: ±1.5% full-scale span (0–85 °C)
- Response time: 1 ms
- Temperature compensated: –40 °C to +125 °C
- Designed for engine MAP applications (listed as a typical application in the datasheet)
- SSOP-8 surface mount package, suitable for a compact PCB

**Option B — Generic I²C/SPI digital pressure sensors (e.g. BMP280, MS5611)**
- Digital output — no voltage divider required
- Typically slower sample rates and higher per-unit cost for automotive-grade variants
- BMP280 max sample rate: 157 Hz (below the 200 Hz minimum)
- MS5611: 500 Hz possible but not rated for automotive temperature range without external compensation

### Decision
**NXP MPXH6115AC6U selected (Option A).**

### Rationale
- Expressly designed for automotive MAP sensing — proven in this application
- 1 ms response time supports the 500 Hz target sample rate
- Temperature compensation built in, suitable for engine bay temperatures
- Well-documented transfer function: `V_OUT = V_S × (0.009 × P − 0.095)` makes firmware conversion straightforward

### Consequences
- Sensor requires a **5 V supply rail** on the PCB. ESP32 runs at 3.3 V logic, so a 5 V regulator is required.
- Sensor V_OUT peaks at ~4.7 V (115 kPa), which exceeds the ESP32 ADC input limit of 3.3 V. A **resistor voltage divider** is required on each of the 4 sensor channels.
- Firmware must account for the divider ratio when back-calculating V_OUT from ADC counts, then apply the inverted transfer function to obtain pressure in kPa:
  `P = (V_OUT / V_S + 0.095) / 0.009`
- Four sensors require four independent ADC channels on the ESP32. Pin assignment must be confirmed during PCB design (avoid ADC2 channels, which conflict with Wi-Fi on the original ESP32).

---

## ADR-003 — Number of Sensors

| Field   | Value              |
|---------|--------------------|
| Date    | 2026-02-25         |
| Status  | **Accepted**       |
| Refs    | FSD SA-01          |

### Context
The system needed a defined sensor count to drive PCB design, ADC channel allocation, BLE packet structure, and UI layout decisions.

### Decision
**Minimum 1 sensor, maximum 4 sensors. Primary use case: 4 sensors** (one per carburetor on the Honda CB400F four-cylinder engine).

### Rationale
Supporting 1–4 sensors allows the same hardware and firmware to serve single-carb engines (e.g. singles, twins) as well as the primary 4-carb use case, maximising the tool's utility without added complexity.

### Consequences
- PCB must provide 4 independent ADC input channels with voltage dividers.
- BLE packet structure sized for 4 sensors; unused sensor slots carry a "not connected" status flag.
- Mobile app sync view (TG-03) must handle 1–4 sensor displays gracefully.

---

## ADR-004 — Mobile Application Framework

| Field   | Value              |
|---------|--------------------|
| Date    | 2026-02-25         |
| Status  | **Accepted**       |
| Refs    | FSD MA-01, MA-01a  |

### Context
The mobile app must target both iOS and Android. A framework decision was required before UI and BLE integration work could begin.

### Options Considered

**Option A — Flutter (Dart)**
- Single codebase for iOS and Android
- Compiles to native ARM code — good performance for real-time gauge rendering
- Strong BLE support via `flutter_blue_plus` (actively maintained, supports iOS and Android)
- Large widget ecosystem; suitable for custom gauge and graph UIs
- Growing adoption in embedded/IoT companion app space

**Option B — Native Swift (iOS) + Kotlin (Android)**
- Best platform integration and access to latest OS APIs
- Two separate codebases — doubles development and maintenance effort
- No cross-platform benefit for a two-person or solo team

**Option C — React Native**
- Cross-platform JavaScript framework
- BLE libraries available but less actively maintained than flutter_blue_plus
- JavaScript bridge adds latency overhead — a concern for real-time gauge updates
- Larger app bundle size

### Decision
**Flutter selected (Option A).**

### Rationale
- Single codebase directly halves mobile development effort.
- `flutter_blue_plus` provides the BLE GATT client needed for the ESP32 connection with good iOS and Android support.
- Flutter's rendering pipeline is well suited to high-frequency gauge and graph updates.

### Consequences
- Dart is the implementation language; team must be proficient or upskill.
- `flutter_blue_plus` must be monitored for maintenance status; if abandoned, an alternative BLE library must be evaluated.
- iOS BLE requires `NSBluetoothAlwaysUsageDescription` in `Info.plist`; Android requires `BLUETOOTH_SCAN` and `BLUETOOTH_CONNECT` permissions (Android 12+).

---

## ADR-005 — Sensor Sampling Rate

| Field   | Value              |
|---------|--------------------|
| Date    | 2026-02-25         |
| Status  | **Accepted**       |
| Refs    | FSD SA-02          |

### Context
An initial sampling rate of 50 Hz was proposed. This was reviewed against the signal characteristics of the target engine at the intended tuning RPM.

### Analysis

**Intake pulse frequency at 3000 RPM (Honda CB400F, 4-cylinder 4-stroke):**
- 3000 RPM = 50 rev/sec
- Each cylinder fires once per 2 revolutions → 25 firings/sec per cylinder
- 4 cylinders, 90° apart → intake pulse frequency = 25 × 4 = **100 Hz**

**Nyquist assessment:**

| Rate   | Samples/rev @ 3000 RPM | vs. Intake Pulse Nyquist | Assessment |
|--------|------------------------|--------------------------|------------|
| 50 Hz  | 1                      | Below (aliases)          | Rejected — one sample per revolution, no averaging possible |
| 100 Hz | 2                      | At limit                 | Rejected — marginal, no headroom |
| 200 Hz | 4                      | 2× above                 | Minimum acceptable |
| 500 Hz | 10                     | 5× above                 | Target — good averaging and dynamic response |
| 1000 Hz| 20                     | 10× above                | Excellent but approaches BLE 4.2 bandwidth ceiling |

**BLE bandwidth impact (4 sensors, ~31 bytes/packet):**

| Rate    | Data rate   | % of BLE 4.2 (~200 kbps) |
|---------|-------------|--------------------------|
| 200 Hz  | ~50 kbps    | 25%                      |
| 500 Hz  | ~124 kbps   | 62%                      |
| 1000 Hz | ~248 kbps   | >100% — exceeds limit    |

### Decision
**Minimum 200 Hz, target 500 Hz.**

### Rationale
50 Hz is below the Nyquist limit for intake pulse events at 3000 RPM and yields only one sample per crank revolution — insufficient for reliable averaging or dynamic event capture. 500 Hz provides 10 samples per revolution, enabling robust rolling averages and capture of transient events (e.g. throttle blips), while remaining comfortably within BLE 4.2 bandwidth limits.

### Consequences
- ESP32 ADC must sustain 4 × 500 Hz = 2000 samples/sec — well within capability.
- If sample rate is increased beyond 500 Hz in future, BLE 5.0 (ESP32-S3, 2M PHY, ~1.3 Mbps) resolves the bandwidth constraint.
- Higher sample rate enables the RPM calculation feature (ADR-006).

---

## ADR-006 — RPM Derivation from MAP Sensor Pulses

| Field   | Value              |
|---------|--------------------|
| Date    | 2026-02-25         |
| Status  | **Accepted**       |
| Refs    | FSD EC-01 to EC-06 |

### Context
Engine RPM is useful contextual information during carb tuning. Options were to add a dedicated RPM sensor (tachometer signal tap from the ignition) or derive it from the MAP data already being collected.

### Options Considered

**Option A — Dedicated tachometer signal tap**
- Read the ignition pulse signal from the coil or existing tach wire
- High accuracy, clean digital signal
- Requires additional wiring into the ignition circuit — invasive, potential reliability risk in an engine bay
- Adds a hardware input and protection circuitry to the PCB

**Option B — Derive RPM from MAP sensor pulses (selected)**
- Each intake stroke produces a detectable vacuum drop in the MAP signal
- No additional sensor, wiring, or PCB input required
- Dependent on adequate sample rate (met by ADR-005 decision of 500 Hz)
- Accuracy is lower than a dedicated signal but sufficient for tuning use

### Decision
**Derive RPM from MAP sensor pulses (Option B).**

### Rationale
The 500 Hz sample rate provides enough time resolution to detect intake pulse timing. A rolling average over 8 pulse periods gives acceptable accuracy across the tuning RPM range:

| RPM  | ±1 sample error (raw) | ±1 sample error (8-pulse avg) |
|------|-----------------------|-------------------------------|
| 1000 | ±67 RPM               | ±8 RPM                        |
| 3000 | ±200 RPM              | ±25 RPM                       |
| 6000 | ±400 RPM              | ±50 RPM                       |

Accuracy is best at idle and low RPM — exactly where carburettor balancing is performed. Avoiding the ignition tap reduces wiring complexity, PCB complexity, and the risk of introducing electrical noise from the ignition system.

### Consequences
- Firmware must implement dP/dt (rate of pressure change) threshold detection rather than absolute pressure threshold, to remain robust across varying throttle positions.
- Detection threshold must be adaptive to recent peak-to-peak signal amplitude.
- RPM readings below ~500 RPM or during rapid throttle transients may be unreliable; firmware must flag invalid readings (EC-05).
- RPM is an estimate, not a precision measurement. If high-accuracy RPM is required in future, a dedicated tach input should be added to the PCB as a hardware provision even if unpopulated initially.

---

## ADR-007 — Target Engine and Default Vacuum Range

| Field   | Value              |
|---------|--------------------|
| Date    | 2026-02-25         |
| Status  | **Accepted**       |
| Refs    | FSD Background, SA-03, TG-01 |

### Context
A default target vacuum range was needed for the mobile app's tuning guidance feature, and a reference engine was needed to validate the sensor range and sampling rate choices.

### Decision
**Primary target engine: Honda CB400F (four-cylinder, four-carburettor).** Default target vacuum range: **16–24 cmHg** (~98.1–99.2 kPa absolute).

### Rationale
The CB400F is the immediate use case driving this project. Its expected balanced idle vacuum of 16–24 cmHg falls well within the NXP MPXH6115AC6U's operating range of 15–115 kPa. Using cmHg as the default display unit aligns with how the target user measures and communicates vacuum on this engine.

### Consequences
- Default display unit set to cmHg (SA-03). Other units (kPa, inHg, mbar) remain selectable.
- App ships with 16–24 cmHg pre-loaded as the target range; user can override for other engines (TG-01).
- Sensor range validation thresholds (SA-05) should be set relative to the expected operating range at initial configuration.

---

## ADR-008 — Microcontroller Variant and ADC Architecture

| Field   | Value              |
|---------|--------------------|
| Date    | 2026-02-25         |
| Status  | **Accepted**       |
| Refs    | FSD SA-07, SA-09, SA-12 |

### Context
The ESP32's internal ADC has well-documented weaknesses: significant non-linearity (±2–3 kPa error in 11dB attenuation mode), ~9–10 ENOB effective resolution, temperature sensitivity, and a conflict between ADC2 channels and Wi-Fi. A review was triggered to determine whether the ADC was adequate for reliable pressure measurement and whether a different microcontroller should be considered.

### Options Considered

**Option A — ESP32 (original) with internal ADC**
- No additional hardware cost or complexity
- ADC non-linearity ±2.8 cmHg across the 8 cmHg target range — marginal
- Systematic errors partially cancel for relative (sync) measurements
- Requires software calibration (`esp_adc_cal`) and per-channel offset correction
- ADC2 channels cannot be used while Wi-Fi is active; all 4 channels must land on ADC1
- Adequate for prototype/proof-of-concept; marginal for a refined tool

**Option B — ESP32 (original) with external SPI ADC (selected)**
- Retains the familiar ESP32 ecosystem (Arduino/IDF, BLE, Wi-Fi)
- Offloads ADC work to a dedicated chip with far better linearity and noise performance
- Good external ADCs (e.g. ADS8688) support split AVDD 5 V / DVDD 3.3 V — sensor connects directly without a voltage divider, simplifying the PCB
- SPI interface is straightforward on the ESP32; well-documented libraries available
- Small added BOM cost; accessible to hobbyist builders
- Retains Wi-Fi for SG-01 stretch goal

**Option C — ESP32-S3 with external SPI ADC**
- Adds BLE 5.0 (2M PHY, higher bandwidth ceiling)
- Different pinout and GPIO mapping from original ESP32 — not a drop-in replacement
- Requires updated PCB layout and pin assignment review
- Higher cost; less widely available in hobbyist form (e.g. dev boards)
- Assumption that "upgrading to S3 is straightforward" is recorded here as **unverified** — it requires a new PCB spin and firmware pin remapping at minimum
- Deferred: if BLE 5.0 bandwidth becomes necessary, this is the natural upgrade path

**Option D — nRF52840**
- Native BLE 5.0, better internal ADC than ESP32
- No Wi-Fi — eliminates SG-01 stretch goal without an additional module
- Different SDK/toolchain (Zephyr or nRF SDK); higher learning curve for hobbyist context
- Rejected on ecosystem and Wi-Fi grounds

**Option E — STM32WB55**
- Dual-core (application + BLE coprocessor), BLE 5.0, good ADC
- No Wi-Fi; complex development environment
- Rejected: highest complexity, loses hobbyist accessibility

### Decision
**ESP32 (original) with external SPI ADC (Option B).**

### Rationale
- Keeps the project accessible to hobbyist builders — the ESP32 has the largest community, most tutorials, and widest dev board availability
- External SPI ADC resolves the ADC quality issue without changing the MCU
- Preferred ADC architecture: split AVDD (5 V analogue) / DVDD (3.3 V digital), which eliminates the voltage divider on sensor channels and reduces per-channel component count
- Retains Wi-Fi for the SG-01 stretch goal
- BLE 4.2 bandwidth is sufficient at 500 Hz (124 kbps, 62% of capacity); BLE 5.0 is not required today

### Consequences
- External ADC part must be selected (open question 6 in FSD). Key criteria: ≥4 channels, ≥12-bit, ≥10 kSPS per channel, SPI interface, split AVDD 5 V / DVDD 3.3 V preferred.
- If the chosen ADC does not support split supply, resistor voltage dividers are required on each sensor channel (SA-09).
- SPI pin assignment on ESP32 must be confirmed during PCB design. The ESP32 has two SPI buses available (HSPI, VSPI) beyond the internal flash connection.
- **S3 upgrade path note:** Moving to ESP32-S3 in future would require a new PCB layout, GPIO remapping, and verification that the same external ADC and BLE libraries are compatible. It is not a drop-in change. The decision to use original ESP32 is made with eyes open on this point.
- Voltage divider requirements (SA-09, SA-11) are now conditional on ADC selection — to be confirmed when open question 6 is resolved.

---

## ADR-009 — External ADC Part Selection (Prototype)

| Field   | Value              |
|---------|--------------------|
| Date    | 2026-02-25         |
| Status  | **Accepted**       |
| Refs    | FSD SA-07 to SA-12 |

### Context
ADR-008 established that an external SPI ADC would replace the ESP32 internal ADC for the prototype. A specific part was needed to enable PCB design, firmware development, and BOM sourcing. Six candidates were evaluated.

### Options Considered

| Part        | Bits   | Ch    | Supply           | Voltage Divider | Package    | Price   | Hobbyist  |
| ----------- | ------ | ----- | ---------------- | --------------- | ---------- | ------- | --------- |
| MCP3204     | 12     | 4     | 3.3 V single     | Yes             | DIP-14     | ~£1     | ★★★★★     |
| **MCP3208** | **12** | **8** | **3.3 V single** | **Yes**         | **DIP-16** | **~£2** | **★★★★★** |
| ADS8684     | 16     | 4     | Split 5V/3.3V    | No              | TSSOP-24   | ~£10    | ★★★       |
| ADS8688     | 16     | 8     | Split 5V/3.3V    | No              | TSSOP-24   | ~£15    | ★★★       |
| ADS131M04   | 24     | 4     | 3.3 V single     | Yes             | VQFN-32    | ~£12    | ★★        |
| MCP3564R    | 24     | 8     | 3.3 V single     | Yes             | SOIC-8     | ~£7     | ★★★       |

### Decision
**MCP3208 for the initial prototype.**

### Rationale
- **DIP-16 package** — breadboard and hand-solder friendly; ideal for a first prototype
- **3.3 V supply** — SPI interface is directly compatible with the ESP32, no level shifting required
- **8 channels** — 4 used for sensors, 4 spare for future expansion without changing the ADC
- **100 kSPS** — 200× headroom over the 500 Hz per-channel target; ample room for oversampling
- **Mature ecosystem** — extensive Arduino libraries, tutorials, and community support
- **Cost** — ~£2, easily sourced from Mouser, Digikey, and hobbyist suppliers

The main trade-off accepted is that the MCP3208's 3.3 V supply means the sensor V_OUT (0.2–4.7 V) requires a per-channel resistor voltage divider. This adds 8 resistors to the BOM (2 per channel × 4 channels) but keeps the design accessible and well understood.

The ADS8688 remains the preferred choice for a refined or production version of the hardware (see ADR-008 consequences).

### Consequences
- **Voltage divider required** on each of the 4 active sensor channels.
  - Values: R1 = 30 kΩ, R2 = 68 kΩ (ratio 0.694)
  - Maximum divided voltage at 115 kPa: 4.7 × 0.694 = **3.26 V** (within 3.3 V ADC range, uses 98.8% of full scale)
- **Firmware ADC-to-voltage conversion:** `V_OUT = (ADC_count / 4096) × 3.3 / 0.694`
- **SPI clock:** must not exceed 2 MHz at 3.3 V supply (conservative; datasheet specifies 3.6 MHz at 5 V)
- MCP3208 channels 0–3 assigned to the 4 pressure sensors; channels 4–7 reserved for future use
- Resistor tolerances (typically ±1–5%) will introduce small per-channel offset errors; firmware per-channel calibration (SA-04) should be used to compensate

---

## Revision History

| Version | Date       | Notes                        |
|---------|------------|------------------------------|
| 1.0     | 2026-02-25 | Initial document — ADR-001 to ADR-007 captured from project decisions to date |
| 1.1     | 2026-02-25 | ADR-008 added: ESP32 (original) + external SPI ADC selected; S3 upgrade assumption documented |
| 1.2     | 2026-02-25 | ADR-009 added: MCP3208 selected for prototype ADC; divider values and firmware formula documented |
