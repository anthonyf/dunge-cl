## REMOVED Requirements

### Requirement: CL engine source files removed
All Common Lisp engine source files (17 files) SHALL be deleted from src/. Only ece-bootstrap.lisp SHALL remain.

### Requirement: CL engine tests removed
All Common Lisp engine test files SHALL be deleted from tests/. The web test directory SHALL be preserved.

### Requirement: ASDF system simplified
The dunge.asd system definition SHALL contain only the ece-bootstrap component and the ece dependency. The alexandria dependency and test system definition SHALL be removed.
