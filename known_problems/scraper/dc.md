# District of Columbia (DC) - Missing API Key

**Status:** 🟡 Ready to Fix (API Key Support Added)
**Date Reported:** November 3, 2025
**Date Updated:** November 10, 2025
**Category:** Configuration/Authentication
**Error Type:** `KeyError: 'DC_API_KEY'`
**Scraper Version:** `openstates/scrapers:latest` (as of Nov 2025)

---

## 🔴 Problem

The DC scraper requires an API key to access the District of Columbia's legislative API, but this API key is not configured in the repository secrets.

The scraper **crashes immediately on import** (before even starting to scrape) because it tries to access `os.environ["DC_API_KEY"]` which doesn't exist.

---

## 🔍 Error Details

**Error Location:** `/opt/openstates/openstates/scrapers/dc/bills.py`, line 23

**Stack Trace:**

```python
File "/opt/openstates/openstates/scrapers/dc/bills.py", line 15, in <module>
  class DCBillScraper(Scraper):
File "/opt/openstates/openstates/scrapers/dc/bills.py", line 23, in DCBillScraper
  "Authorization": os.environ["DC_API_KEY"],
File "/usr/local/lib/python3.9/os.py", line 679, in __getitem__
  raise KeyError(key) from None
KeyError: 'DC_API_KEY'
```

**Full Error:** The scraper crashes during class definition when it tries to build the authorization header.

---

## 💥 Impact

### On Scraping:

- ❌ Scraper crashes immediately (before any HTTP requests)
- ❌ All 3 retry attempts fail with same error
- ❌ **0 bills scraped** (0 JSON files created)

### On Output:

```
Found 0 JSON files in _working/_data/dc
ℹ️ No new files found; will use nightly fallback.
```

### On Workflow:

- Falls back to nightly artifact if available
- If no nightly exists, formatter will fail
- **Never gets fresh data until API key is configured**

---

## 🔎 Root Cause

**Configuration Issue:**

DC's legislative API requires authentication. The OpenStates scraper expects a `DC_API_KEY` environment variable to be set, but:

1. We haven't obtained the API key from DC
2. The key isn't added to GitHub repository secrets
3. The workflow doesn't pass the secret to the Docker container

**This is a setup/configuration issue**, not a scraper bug.

---

## ✅ Solution

### Step 1: Obtain DC API Key

**Where to get it:**

- Check OpenStates documentation: https://github.com/openstates/openstates-scrapers/tree/main/scrapers/dc
- Contact DC Council IT department
- Look for developer portal on DC's legislative website
- Check if OpenStates team has shared access

### Step 2: Add Secret to Repository

Once you have the key:

```bash
gh secret set DC_API_KEY \
  --repo windy-civi-pipelines/dc-data-pipeline \
  --body "YOUR_DC_API_KEY_HERE"
```

### Step 3: Update Scrape Workflow ✅ IMPLEMENTED

**The toolkit scrape action now supports API keys!** (Updated November 10, 2025)

**In `.github/workflows/scrape-and-format-data.yml`:**

```yaml
- name: Scrape data
  uses: windy-civi/toolkit/actions/scrape@main
  with:
    state: dc
    api-key: ${{ secrets.DC_API_KEY }}  # Pass your secret here
```

The action automatically:
- Converts state code to uppercase (dc → DC)
- Creates the environment variable name (DC_API_KEY)
- Passes it securely to the Docker container

---

## 🚧 Workaround (Until Fixed)

**Current options:**

1. **Skip DC** - can't scrape without API key
2. **Use nightly fallback** - if fallback exists from a previous successful scrape
3. **Manual scrape** - run the scraper locally with API key, upload data

---

## 📋 Action Items

- [ ] Research where to obtain DC_API_KEY
- [x] Update toolkit scrape action to support environment variable pass-through ✅
- [ ] Add DC_API_KEY to dc-data-pipeline repository secrets (once obtained)
- [ ] Update dc-data-pipeline workflow to use new `api-key` input
- [ ] Test that scraper works with configured key
- [x] Document other states that require API keys (VA, IN) ✅

---

## 🎯 Detection

**How to identify this quickly:**

1. Error happens **immediately** (within first 10 seconds)
2. Crashes on **import**, not during scraping
3. `KeyError` for environment variable
4. **0 JSON files** created
5. Error repeats identically on all 3 retry attempts

**Red flags:**

- `KeyError: 'DC_API_KEY'` in stack trace
- Crash in `bills.py` line 23 during class definition
- No bill scraping even attempted
- Found 0 JSON files

---

**Last Updated:** November 3, 2025
**Priority:** High - DC scraper completely non-functional without API key
**Next Steps:** Research DC API key requirements, update toolkit to support credential pass-through

