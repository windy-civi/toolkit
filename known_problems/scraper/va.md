# Virginia (VA) - Missing API Key (But Has Workaround!)

**Status:** 🟡 Failing (But Solvable - API Key Support Added)
**Date Reported:** November 3, 2025
**Date Updated:** November 10, 2025
**Category:** Configuration/Authentication
**Error Type:** `ScrapeError: no objects returned from VaBillScraper scrape`
**Scraper Version:** `openstates/scrapers:latest` (as of Nov 2025)

---

## 🟡 Problem

The Virginia scraper requires an API key to access the Virginia Legislative Information System (LIS), but this API key is not configured.

**However, Virginia helpfully provides an alternative scraper (`csv_bills`) that works WITHOUT an API key!**

---

## 🔍 Error Details

**Error Message:**

```
ERROR openstates: Virginia requires an LIS api key.
Register at https://lis.virginia.gov/developers
API key registration can take days, the csv_bills scraper works without one.
```

**Error Type:**

```python
openstates.exceptions.ScrapeError: no objects returned from VaBillScraper scrape
```

---

## 💥 Impact

### On Scraping:

- ❌ Primary scraper (`VaBillScraper`) fails immediately
- ❌ All 3 retry attempts fail the same way
- ❌ Saves only 4 JSON files (jurisdiction + organizations)
- ❌ **0 bills scraped**

### On Output:

```
Found 4 JSON files in _working/_data/va
```

### On Workflow:

- Falls back to nightly artifact if available
- If no nightly exists, formatter fails
- **Never gets fresh data until API key is configured OR alternate scraper is used**

---

## ✅ Solution Options

### Option A: Use CSV Scraper (Recommended - Quick Fix)

Virginia has an **alternate scraper** that doesn't require authentication:

**How to enable:**
Check OpenStates documentation for how to specify `csv_bills` scraper instead of the default API-based scraper.

**Pros:**

- ✅ Works immediately, no registration needed
- ✅ No API key required
- ✅ No waiting period

**Cons:**

- ❓ CSV scraper might have less data or be less frequently updated
- ❓ May not include all fields that API provides

**Next steps:**

1. Research how to specify alternate scraper in OpenStates
2. Test `csv_bills` scraper locally
3. Update workflow if it works well

---

### Option B: Register for LIS API Key (Long-term) ✅ NOW SUPPORTED

**Registration:**

- URL: https://lis.virginia.gov/developers
- ⚠️ **Can take days** to get approved

**Once you have the key:**

```bash
# Add to repository secrets
gh secret set VA_LIS_API_KEY \
  --repo windy-civi-pipelines/va-data-pipeline \
  --body "YOUR_API_KEY_HERE"
```

**Update workflow to use the new API key support** (Updated November 10, 2025):

```yaml
- name: Scrape data
  uses: windy-civi/toolkit/actions/scrape@main
  with:
    state: va
    api-key: ${{ secrets.VA_LIS_API_KEY }}  # New: built-in API key support!
```

The action automatically:
- Converts state code to uppercase (va → VA)
- Creates the environment variable name (VA_LIS_API_KEY)
- Passes it securely to the Docker container

**Pros:**

- ✅ Official API access
- ✅ Likely more complete data
- ✅ Better maintained
- ✅ **Toolkit now supports API keys!** (as of Nov 10, 2025)

**Cons:**

- ❌ Requires registration and approval (days)
- ❌ Another secret to manage

---

## 🎯 Recommended Approach

**Short-term (This Week):**

1. Research the `csv_bills` scraper option
2. If viable, switch Virginia to use it
3. Get fresh data flowing

**Long-term (When Available):**

1. Register for LIS API key anyway
2. Once approved, switch to API-based scraper for better data quality
3. Document which approach works better

---

## 🔍 Comparison with DC

| State  | Issue                | Workaround Available?        | Priority |
| ------ | -------------------- | ---------------------------- | -------- |
| **DC** | Missing `DC_API_KEY` | ❌ No known alternative      | High     |
| **VA** | Missing LIS API key  | ✅ Yes - `csv_bills` scraper | Medium   |

**Virginia is easier to solve** because it has a built-in fallback option!

---

## 📋 Upstream Information

- **Repository:** https://github.com/openstates/openstates-scrapers
- **Scraper File:** `scrapers/va/bills.py`
- **Registration:** https://lis.virginia.gov/developers
- **Alternative:** `csv_bills` scraper (documented in OpenStates)

---

## 🎯 Detection

**How to identify this quickly:**

1. Error message explicitly mentions "requires an LIS api key"
2. Includes registration URL
3. **Mentions csv_bills workaround!**
4. Crash happens immediately (within first 10 seconds)
5. Only 4 JSON files created

**Red flags:**

- `ScrapeError: no objects returned`
- ERROR message about API key
- Helpful suggestion for alternative scraper

---

## 📝 Action Items

- [ ] Research how to use `csv_bills` scraper for Virginia
- [ ] Test csv_bills scraper data quality
- [ ] If acceptable, switch VA to use csv_bills
- [ ] (Optional) Register for LIS API key for future use
- [ ] Document scraper comparison (API vs CSV)
- [x] Update toolkit to support API key pass-through ✅ (Nov 10, 2025)

---

**Last Updated:** November 10, 2025
**Priority:** Medium - workaround exists, but needs investigation
**Next Steps:** Research and test `csv_bills` scraper as immediate solution, or register for API key now that toolkit supports it

