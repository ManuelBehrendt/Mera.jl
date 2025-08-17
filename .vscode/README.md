# Mera.jl VSCode Development Setup

This directory contains VSCode configuration for optimal Mera.jl development with coverage support.

## Quick Start

1. **Install recommended extensions** (prompted automatically):
   - Julia Language Support
   - Coverage Gutters  
   - GitLens
   - Test Adapter Converter

2. **Run tests with coverage**:
   - Press `Ctrl+Shift+P` → "Tasks: Run Task" → "Run Tests with Coverage"
   - Or use terminal: `julia scripts/run_coverage.jl`

3. **View coverage**:
   - Press `Ctrl+Shift+P` → "Coverage Gutters: Display Coverage"
   - Green lines = covered, red lines = uncovered

## Available Commands

### Debug Configurations (F5)
- **Run Mera.jl Tests**: Full test suite with 4 threads
- **Run Tests with Coverage**: Tests + coverage generation
- **Run Current Test File**: Execute currently open test file
- **Quick Test (No Heavy)**: Fast tests skipping heavy operations

### Tasks (Ctrl+Shift+P → Tasks)
- **Run Tests**: Standard test execution
- **Run Tests with Coverage**: Tests + coverage collection  
- **Generate Coverage Report**: Process existing .cov files
- **Quick Test (No Heavy)**: Fast compatibility check
- **Upload Coverage to Codecov**: Upload to external services

## Coverage Workflow

### Local Development
```bash
# 1. Run tests with coverage
julia scripts/run_coverage.jl

# 2. View in VSCode
# Press Ctrl+Shift+P → "Coverage Gutters: Display Coverage"

# 3. Generate reports
julia scripts/generate_coverage.jl
```

### Upload to Codecov/Coveralls
```bash
# Set tokens
export CODECOV_TOKEN=your_token
export COVERALLS_TOKEN=your_token

# Run with upload
julia scripts/run_coverage.jl --upload
```

### Quick Coverage Check
```bash
# Fast coverage (skips heavy tests)
julia scripts/run_coverage.jl --quick --threads=2
```

## Files Generated

### Coverage Files
- `lcov.info` - Coverage data (VSCode, Codecov, Coveralls)
- `*.cov` - Line-by-line coverage files  
- `coverage_summary.txt` - Text report
- `coverage/index.html` - HTML report

### VSCode Integration
- Coverage shown in editor gutters (green/red lines)
- Status bar shows overall coverage percentage
- Hover for detailed line coverage info

## Environment Variables

### For Testing
- `JULIA_NUM_THREADS` - Thread count (auto-set by VSCode tasks)
- `MERA_SKIP_HEAVY` - Skip heavy simulation tests
- `MERA_ZULIP_DRY_RUN` - Disable real notification sending
- `MERA_LOCAL_COVERAGE` - Enable full coverage mode

### For Upload  
- `CODECOV_TOKEN` - Codecov API token
- `COVERALLS_TOKEN` - Coveralls repository token

## Settings Explained

### Coverage Gutters
- Shows coverage directly in editor
- Supports `.cov` and `lcov.info` files
- Configurable colors for covered/uncovered lines

### Julia Language Server
- Code completion and linting
- Integrated with REPL
- Symbol caching for better performance

### File Associations
- `.jl` files use Julia syntax
- `.cov` files show as Julia for easy reading
- TOML files properly highlighted

## Troubleshooting

### Coverage Not Showing
1. Ensure Coverage Gutters extension is installed
2. Run tests with coverage first: `julia scripts/run_coverage.jl`
3. Check `lcov.info` exists in workspace root
4. Press `Ctrl+Shift+P` → "Coverage Gutters: Display Coverage"

### Tests Failing
1. Check Julia environment: `julia --project=test -e 'using Pkg; Pkg.status()'`
2. Try quick test mode: Task → "Quick Test (No Heavy)"
3. Check thread count in VSCode settings

### Upload Failing
1. Verify tokens are set: `echo $CODECOV_TOKEN`
2. Check network connectivity
3. Use GitHub Actions workflow for reliable upload

## GitHub Integration

This VSCode setup integrates with the GitHub Actions workflows:

- **Local development**: Full coverage with VSCode integration
- **CI tests**: Reduced tests for compatibility checking  
- **Coverage workflow**: Manual full test with upload to services

The `lcov.info` format is compatible between local VSCode and GitHub Actions, ensuring consistent coverage reporting.
