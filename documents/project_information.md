# Project Information

This is documentation to help users find information and familiarize themselves with the repository.

## Project Structure

```
CarbTune/
├── app/
│   ├── carbtune/               Flutter app (Dart/Flutter, iOS & Android)
│   │   ├── lib/
│   │   │   ├── main.dart
│   │   │   ├── models/
│   │   │   │   ├── pressure_unit.dart
│   │   │   │   └── sensor_data.dart
│   │   │   ├── providers/
│   │   │   │   └── app_state.dart
│   │   │   ├── screens/
│   │   │   │   └── balance_screen.dart
│   │   │   └── widgets/
│   │   │       ├── connection_status_bar.dart
│   │   │       └── unit_selector_modal.dart
│   │   ├── android/            Generated Android platform code
│   │   ├── ios/                Generated iOS platform code
│   │   ├── test/
│   │   └── pubspec.yaml
│   └── mockups/                UI design sketches (Excalidraw + exported JPGs)
├── documents/                  Project documentation (Obsidian vault)
│   ├── functional_specification.md   Authoritative requirements (FSD v1.1)
│   ├── design_decisions.md           Architecture Decision Records (ADR-001–009)
│   └── project_information.md        This file
├── firmware/                   ESP32 firmware (to be developed)
├── hardware/
│   ├── BOM.md                  Bill of Materials
│   └── documents/
│       └── MPXA6115A.pdf       NXP pressure sensor datasheet
├── CLAUDE.md                   Guidance for Claude Code
├── ToDo.md                     Running list of ideas and open tasks
└── README.md
```