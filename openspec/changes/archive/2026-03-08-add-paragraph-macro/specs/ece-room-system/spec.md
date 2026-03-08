## ADDED Requirements

### Requirement: Paragraph macro displays text with trailing blank line
The `p` macro SHALL display its arguments concatenated together followed by two newlines (a paragraph break).

#### Scenario: Paragraph with content
- **WHEN** `(p "Welcome to the town.")` is evaluated
- **THEN** the output SHALL display "Welcome to the town." followed by a blank line

#### Scenario: Paragraph with multiple arguments
- **WHEN** `(p "Hello " name "!")` is evaluated where name is "Aragorn"
- **THEN** the output SHALL display "Hello Aragorn!" followed by a blank line
