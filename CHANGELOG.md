# Changelog

All notable changes to this project will be documented in this file.

## [0.1.0] - 2026-05-01

### Added

- Initial release
- DeploymentTask::Base class with DSL for version, phase, and description
- Task registry with automatic discovery and version validation
- Sequential task runner with idempotency and halt-on-failure
- AASM-based state tracking (pending, running, completed, failed, skipped)
- Structured JSON logging with pluggable error reporting
- Rake tasks: `deploy:pre`, `deploy:post`, `deploy:status`, `deploy:retry_failed`
- Rails generator for scaffolding new deployment tasks
- Install generator for initializer setup
- Database-agnostic advisory locking (MySQL, PostgreSQL, SQLite)
- Dry run support for deployment previews
- Configuration block for customization
