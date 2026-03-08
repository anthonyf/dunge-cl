## MODIFIED Requirements

### Requirement: Combat log formatting
The system SHALL format combat results as human-readable strings showing damage, critical hits, saves, and outcomes. String building SHALL use ECE string interpolation where it improves readability.

#### Scenario: Normal attack log
- **WHEN** player deals 4 HP damage and enemy deals 2 HP damage
- **THEN** the log SHALL include "You deal 4 damage." and "The enemy deals 2 damage."

#### Scenario: Combat stat display uses interpolation
- **WHEN** combat stats are displayed during an active encounter
- **THEN** enemy and player stats SHALL be rendered using string interpolation, producing identical output to the current implementation
