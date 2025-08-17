# Test Workflow Guide

This repository uses a dual testing strategy:

## 🚀 Quick CI Tests (Automatic)
**Files**: `CI_1.10.yml`, `CI_1.11.yml`
**Purpose**: Fast compatibility checks on GitHub CI
**Triggers**: Push to master, PRs
**Features**:
- Tests Julia 1.10 & 1.11 on Ubuntu & macOS
- Single-thread only (fast)
- Skips heavy simulation tests
- Dry-run notifications only
- No coverage upload
- ~5-10 minutes runtime

**Environment variables set**:
```bash
MERA_CI_MODE=true
MERA_SKIP_HEAVY=true
MERA_SKIP_AQUA=true
MERA_ZULIP_DRY_RUN=true
MERA_BASIC_ZULIP_TESTS=true
```

## 📊 Full Coverage Tests (Manual)
**File**: `coverage_local.yml`
**Purpose**: Complete test suite with coverage upload
**Triggers**: Manual dispatch only
**Features**:
- Full test suite including heavy tests
- Multi-threading support (1-8 threads)
- Real notification testing
- Coverage upload to Codecov & Coveralls
- Configurable Julia version
- ~20-60 minutes runtime

## Running Tests

### Local Development
```bash
# Quick local test (like CI)
MERA_SKIP_HEAVY=true julia --project=test test/runtests.jl

# Full local test 
julia --project=test -t 4 test/runtests.jl

# Coverage test
julia --project=test -t 4 --code-coverage=user test/runtests.jl
```

### GitHub Actions

#### Trigger Full Coverage Test
```bash
# Using GitHub CLI
gh workflow run coverage_local.yml --ref master

# Or via GitHub web interface:
# 1. Go to Actions tab
# 2. Select "Coverage (Local Full Test)"
# 3. Click "Run workflow"
# 4. Choose options:
#    - Julia version: 1.10 or 1.11
#    - Threads: 1, 2, 4, or 8
#    - Skip heavy tests: true/false
```

#### Monitor CI Tests
CI tests run automatically on push/PR and show results in the Actions tab.

## Coverage Setup

### Codecov
1. Get token from https://codecov.io/gh/ManuelBehrendt/Mera.jl
2. Add as repository secret: `CODECOV_TOKEN`

### Coveralls  
1. Get token from https://coveralls.io/github/ManuelBehrendt/Mera.jl
2. Add as repository secret: `COVERALLS_REPO_TOKEN`

## Test Modes Comparison

| Feature | CI Tests | Full Coverage |
|---------|----------|---------------|
| Threading | Single only | 1-8 threads |
| Heavy tests | Skipped | Included |
| Notifications | Dry-run | Real if configured |
| Aqua quality | Skipped | Included |
| Coverage upload | No | Yes |
| Runtime | 5-10 min | 20-60 min |
| Purpose | Compatibility | Full validation |

## Environment Variables

### CI Control
- `MERA_CI_MODE=true` - Enables CI-specific behavior
- `MERA_SKIP_HEAVY=true` - Skips simulation data tests
- `MERA_SKIP_AQUA=true` - Skips Aqua quality tests

### Notification Control  
- `MERA_ZULIP_DRY_RUN=true` - Prevents real message sending
- `MERA_BASIC_ZULIP_TESTS=true` - Reduces Zulip test complexity
- `MERA_ZULIP_ENABLE_NETWORK=true` - Allows real notifications

### Coverage Control
- `MERA_LOCAL_COVERAGE=true` - Enables full test mode for coverage

### Performance Control
- `MERA_TEST_TIMEOUT=1200` - Test timeout in seconds
- `MERA_DOWNLOAD_RETRIES=2` - Download retry attempts
- `JULIA_NUM_THREADS=4` - Thread count

## Troubleshooting

### CI Tests Failing
- Check compatibility with Julia version
- Look for basic functionality regressions
- Tests are designed to be minimal and fast

### Coverage Tests Failing  
- May indicate issues with multi-threading
- Could be notification configuration problems
- Heavy tests might have data download issues

### Missing Coverage Upload
- Check repository secrets are set correctly
- Verify tokens haven't expired
- Ensure workflow has appropriate permissions
