# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a **specification-stage** project for a wireless engine-tuning tool. There is no source code yet — the repository contains only design documentation. The tool reads manifold absolute pressure (MAP/vacuum) from up to four carburetor sensors and streams data to a mobile app via BLE.

Target use case: balancing carburetors on the Honda CB400F (4-cylinder, 4-carb) at a target vacuum of 16–24 cmHg.

## Repository Contents

All documentation lives in `Documents/`:

- **`functional_specification.md`** — v1.0 FSD. Authoritative source for functional requirements (SA-xx sensor acquisition, WC-xx wireless comms, MA-xx mobile app, LD-xx live display, DL-xx data logging, TG-xx tuning guidance, EC-xx engine calculations). All open questions resolved as of 2026-02-25.
- **`design_decisions.md`** — ADR-001 through ADR-009. Records what was decided and why for each major architecture choice.
- **`MPXA6115A.pdf`** — NXP pressure sensor datasheet (referenced by ADR-002 and SA-06).

## Intended Architecture (from ADRs)

### Hardware
- **MCU:** ESP32 (original WROOM/WROVER, not S3)
- **Sensors:** NXP MPXH6115AC6U, analog output (0.2–4.7 V at 5 V supply), 1–4 channels
- **ADC:** Microchip MCP3208 — 12-bit, 8-channel, SPI, DIP-16. Selected over ESP32 internal ADC due to poor linearity (±2–3 kPa), temperature sensitivity, and ADC2/Wi-Fi conflicts.
- **Voltage divider per channel:** R1=30 kΩ, R2=68 kΩ (ratio 0.694) to scale 5 V sensor output into ESP32's 3.3 V ADC range. Firmware conversion: `V_OUT = (ADC_count / 4096) × 3.3 / 0.694`
- **SPI clock:** ≤2 MHz at 3.3 V

### Wireless
- **Primary:** BLE (ADR-001). Connection interval 7.5–15 ms, ≤200 ms end-to-end latency. At 500 Hz sampling, data rate is ~124 kbps (62% of BLE 4.2 capacity). Packet: timestamp + 4×(4 B pressure + 1 B status) + 4 B RPM ≈ 31 bytes.
- **Stretch goal SG-01:** Wi-Fi web UI diagnostic tool.

### Firmware
- Sampling rate: 200 Hz minimum, 500 Hz target (ADR-005)
- RPM derived from MAP pulse detection via dP/dt threshold crossing — no dedicated tach input (ADR-006). Adaptive threshold; rolling 8-pulse average. Formula: `RPM = (4 × 60) / (N_cylinders × T_avg_pulse)`. RPM flagged invalid if <2 pulses in last 500 ms.

### Mobile App
- **Framework:** Flutter / Dart targeting iOS ≥16 and Android ≥10 (ADR-004)
- **BLE library:** `flutter_blue_plus`
- **Screens:** Live gauges, multi-sensor sync/balance view, session logging, session review, CSV/JSON export
- **Units:** cmHg, inHg, kPa, mbar (user-configurable)
- **App size:** ≤50 MB

## Development Notes

No build system, package manager, or test infrastructure exists yet. When source code is added, update this file with build/test/lint commands.

When editing the FSD or ADRs, maintain the existing requirement ID numbering (SA-xx, WC-xx, etc.) and ADR format (Status / Context / Decision / Consequences).
