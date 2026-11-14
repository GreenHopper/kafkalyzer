# Spec Delta

## ADDED Requirements

### Requirement: Duplicate a Cluster Profile Including Secrets

The Settings cluster list SHALL offer a "Duplicate" action per profile. It SHALL open the cluster dialog with a copy of every field, including secrets, the environment tag, the TLS verification state and additional properties, under a suggested unique name. On save, the copy's secrets SHALL be stored in the OS keyring under the new name. The source profile and its secrets SHALL stay unchanged.

#### Scenario: Duplicating a SASL profile
- **WHEN** the user duplicates profile "orders-prod" that uses SASL SCRAM with a stored password and saves the dialog unchanged
- **THEN** a profile "orders-prod (copy)" SHALL exist with the same mechanism, username and password
- **AND** after an application restart both profiles SHALL connect without re-entering a password

#### Scenario: Suggested name is unique
- **WHEN** profiles "orders-prod" and "orders-prod (copy)" exist and the user duplicates "orders-prod"
- **THEN** the suggested name SHALL be "orders-prod (copy 2)"

#### Scenario: Cancelled duplicate
- **WHEN** the user cancels the dialog opened by "Duplicate"
- **THEN** no profile and no keyring entry SHALL be created

#### Scenario: Copy is independent
- **WHEN** the user changes the password of the copy and saves
- **THEN** the source profile SHALL keep its original password

#### Scenario: Keyring unavailable while duplicating
- **WHEN** the OS keyring is unavailable and the user saves a duplicate
- **THEN** the copy SHALL be created and the existing "passwords are not saved" notice SHALL apply to it

### Requirement: Allowlisted Additional Client Properties

A profile SHALL be able to store additional Kafka client properties. Only keys on a fixed positive allowlist SHALL be applied to a connection, and only with a value of the allowed type and range. Keys outside the allowlist SHALL never reach the Kafka client, whatever their source (dialog, stored data, import). The allowlist SHALL contain no key that can write, commit, join a group, enable transactions or idempotence, create topics, run commands, load plugins, or change TLS or SASL settings.

#### Scenario: Allowed property is applied
- **WHEN** a profile carries `client.id=kafkalyzer-alice` and the user connects
- **THEN** the Kafka client SHALL use `kafkalyzer-alice` as its client id

#### Scenario: Forbidden property in imported or stored data
- **WHEN** an imported profile bundle contains additional properties `enable.auto.commit`, `transactional.id`, `allow.auto.create.topics`, `group.instance.id` or `enable.ssl.certificate.verification` and the user connects
- **THEN** none of these keys SHALL be passed to the Kafka client
- **AND** the cluster dialog SHALL mark them as not allowed when the profile is opened

#### Scenario: Properties set by the application win
- **WHEN** a profile carries an allowlisted property
- **THEN** the consumer settings the application fixes for read-only operation (manual assignment, auto-commit off, partition EOF, fetch limits) SHALL be unchanged

#### Scenario: Additional properties survive restart and export
- **WHEN** the user saves a profile with additional properties, restarts the application, and exports and imports the profile
- **THEN** the additional properties SHALL be unchanged after the restart and after the import

#### Scenario: Read-only operation preserved
- **WHEN** any combination of allowlisted properties is applied
- **THEN** the connection SHALL issue only the same read-only requests as without additional properties
