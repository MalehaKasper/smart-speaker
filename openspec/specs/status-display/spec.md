# status-display Specification

## Purpose
TBD - created by archiving change build-firmware. Update Purpose after archive.
## Requirements
### Requirement: Вивід стану на екран TM1650
Екран TM1650, підключений по I2C, SHALL відображати поточний рівень гучності або обране джерело звуку.

#### Scenario: Гучність відображається після зміни
- **WHEN** гучність змінюється (енкодером, ІЧ-пультом або з додатка)
- **THEN** екран TM1650 оновлює відображення до поточного значення гучності

#### Scenario: Джерело звуку відображається після перемикання
- **WHEN** джерело звуку перемикається між Bluetooth і AUX
- **THEN** екран TM1650 відображає поточне обране джерело

