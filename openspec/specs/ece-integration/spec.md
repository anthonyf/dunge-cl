### Requirement: Ece is registered as a qlot git dependency
The qlfile SHALL contain a `git` source entry for ece using the SSH URL `git@github.com:anthonyf/ece.git`.

#### Scenario: Qlfile contains ece entry
- **WHEN** reading the `qlfile`
- **THEN** it SHALL contain the line `git ece git@github.com:anthonyf/ece.git`

#### Scenario: Qlot install succeeds with ece
- **WHEN** running `qlot install`
- **THEN** the command SHALL complete without error and ece SHALL be available as an ASDF system

### Requirement: Dunge ASDF system depends on ece
The `dunge.asd` system definition SHALL list `"ece"` in its `:depends-on` list so that loading dunge also loads ece.

#### Scenario: ASDF dependency declared
- **WHEN** reading `dunge.asd`
- **THEN** the `:depends-on` list SHALL include `"ece"`

#### Scenario: System loads successfully
- **WHEN** running `(asdf:load-system :dunge)`
- **THEN** the ece system SHALL be loaded and its packages SHALL be available
