# 📸 Snapshot Generation Plan

## 🎯 Goal
Create snapshots for a diverse sample set of small states/territories to validate the format action across different data structures and regions.

## 📋 Sample State Set (6 jurisdictions)

1. **wy** (Wyoming) ✅ - Already completed
   - Small state, Mountain West region
   - Baseline reference

2. **id** (Idaho)
   - Small state, Mountain West region
   - Different from Wyoming

3. **ri** (Rhode Island)
   - Small state, Northeast region
   - Different geographic area

4. **vt** (Vermont)
   - Small state, Northeast region
   - Different legislative structure

5. **de** (Delaware)
   - Small state, East Coast region
   - Different region

6. **gu** (Guam)
   - Territory (not a state)
   - Different jurisdiction type
   - Tests territory handling

## ✅ Selection Criteria Met

- ✅ Small data volumes (easier to work with)
- ✅ No API key requirements
- ✅ No known major issues
- ✅ Geographic diversity (Mountain West, Northeast, East Coast, Pacific)
- ✅ Different jurisdiction types (states + territory)
- ✅ Different legislative structures

## 📝 Tasks

### Phase 1: Update Scripts
- [x] Update `render_snapshot.sh` to accept state parameter (instead of hardcoded "wy")
- [x] Make script flexible to handle any state
- [x] Add error handling for missing production mocks
- [x] Auto-detect latest prod-mocks directory
- [x] Update `update-mocks-from-production.sh` to accept state parameter

### Phase 2: Generate Production Mocks
- [x] Verify which states have production mocks in `actions/scrape/prod-mocks-2025-11-25/_working/_data/`
  - **Current Status**: Only `wy` (Wyoming) has production mocks
  - **Missing**: id, ri, vt, de, gu
- [ ] Generate production mocks for remaining states using `update-mocks-from-production.sh`
  - Run: `cd actions/scrape && ./update-mocks-from-production.sh id`
  - Run: `cd actions/scrape && ./update-mocks-from-production.sh ri`
  - Run: `cd actions/scrape && ./update-mocks-from-production.sh vt`
  - Run: `cd actions/scrape && ./update-mocks-from-production.sh de`
  - Run: `cd actions/scrape && ./update-mocks-from-production.sh gu`
- [ ] Note: Each run creates a new dated directory. Latest will be auto-detected by `render_snapshot.sh`

### Phase 3: Generate Snapshots
- [ ] Generate snapshot for **id** (Idaho)
- [ ] Generate snapshot for **ri** (Rhode Island)
- [ ] Generate snapshot for **vt** (Vermont)
- [ ] Generate snapshot for **de** (Delaware)
- [ ] Generate snapshot for **gu** (Guam)

### Phase 4: Validation
- [ ] Verify all snapshots generated successfully
- [ ] Check snapshot structure matches expected format
- [ ] Validate schema compliance for all snapshots
- [ ] Document any state-specific differences found

### Phase 5: Batch Processing (Optional)
- [ ] Create batch script to process all states at once
- [ ] Add progress tracking
- [ ] Add error recovery

## 🔧 Technical Changes Needed

### `render_snapshot.sh` Updates
- Accept state code as parameter (or environment variable)
- Make INPUT_DIR configurable or auto-detect
- Add validation for state code
- Improve error messages

### `main.sh` Updates (if needed)
- Verify it already handles all state codes correctly
- Check territory handling (gu)

## 📊 Expected Output Structure

```
actions/format/snapshots/
├── wy/          ✅ (already exists)
├── id/          (to be created)
├── ri/          (to be created)
├── vt/          (to be created)
├── de/          (to be created)
└── gu/          (to be created)
```

Each snapshot should contain:
- `country:us/state:{code}/sessions/{session}/bills/{bill_id}/`
  - `metadata.json`
  - `logs/*.json`
- `.windycivi/`
  - `sessions.json`
  - `bill_session_mapping.json`
  - `latest_timestamp_seen.txt`
  - `errors/` (if any)

## 🚀 Next Steps

1. ✅ Update `render_snapshot.sh` to be state-agnostic
2. ✅ Update `update-mocks-from-production.sh` to accept state parameter
3. Generate production mocks for remaining states
4. Generate snapshots for all states
5. Validate and document

## 📖 Usage

### Generate Production Mocks

```bash
cd actions/scrape

# Generate mocks for a specific state
./update-mocks-from-production.sh id
./update-mocks-from-production.sh ri
./update-mocks-from-production.sh vt
./update-mocks-from-production.sh de
./update-mocks-from-production.sh gu
```

This creates a dated directory like `prod-mocks-2025-11-25/` with the scraped data.

### Generate Snapshots

```bash
cd actions/format

# Generate snapshot for a state (auto-detects latest prod-mocks)
./render_snapshot.sh id
./render_snapshot.sh ri
./render_snapshot.sh vt
./render_snapshot.sh de
./render_snapshot.sh gu

# Or specify a specific prod-mocks directory
./render_snapshot.sh id ../scrape/prod-mocks-2025-11-25
```

### Batch Processing (Future)

Once individual snapshots work, we can create a batch script to process all states at once.

