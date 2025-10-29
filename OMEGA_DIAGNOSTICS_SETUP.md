# OMEGA Diagnostics Setup Instructions

## Problem Fixed
The donation page was showing "Failed to load performer information" because:
- Code was querying `profiles` table (doesn't exist) instead of `user_profiles`
- Code was querying `storage_thumbnail_path` column (doesn't exist)
- Client-side joins had schema mismatches with actual database

## Solution
OMEGA diagnostics creates a server-side VIEW and RPC function that centralizes all schema logic in one place, so the Flutter app just makes one clean call.

---

## Step 1: Run SQL in Supabase Dashboard

1. Open your **Supabase Dashboard**: https://supabase.com/dashboard/project/oemeugiejcjfbpmsftot
2. Go to **SQL Editor** (left sidebar)
3. Click **New Query**
4. Copy and paste the entire contents of `supabase_migration_omega_donation_header.sql`
5. Click **Run** to execute

This creates:
- ✅ VIEW `v_donation_header` - Joins videos + user_profiles with correct columns
- ✅ RPC function `donation_header()` - Returns one joined record
- ✅ RLS policies - Allows public read access to videos and user_profiles

---

## Step 2: Verify It Works

After running the SQL, test the RPC with a known video ID:

```sql
SELECT * FROM donation_header(
  '9392b257-1c26-47b2-b68e-5f2199e1c190'::uuid,
  '657e9f74-82d3-460a-b3c4-4179d6b880c1'::uuid
);
```

You should see a row with:
- `display_name`, `handle`, `avatar_url`, `location_line`, `thumb_any`

---

## Step 3: Test the App

1. Navigate to the discovery feed
2. Tap the **$** button on any video
3. The donation page should now show:
   - ✅ Performer name, avatar, handle
   - ✅ Location (e.g., "Washington Square Park, Manhattan")
   - ✅ Video thumbnail
   - ✅ No error message

---

## Debug Panel (Long-Press Title)

If you still see errors, **long-press the "Support Performer" title** to open the OMEGA debug panel:

- Shows route args (videoId, performerId)
- Shows loaded data from RPC/VIEW
- Shows any error messages
- Copy button to share diagnostics

---

## What Changed in Flutter

The app now:
1. ✅ Calls `donation_header()` RPC first (preferred path)
2. ✅ Falls back to querying `v_donation_header` VIEW if RPC fails
3. ✅ Uses correct table name: `user_profiles` (not `profiles`)
4. ✅ Removed `storage_thumbnail_path` references
5. ✅ Added OMEGA debug panel for troubleshooting
6. ✅ Added detailed logging with `[OMEGA]` prefix

---

## Console Logs to Look For

After tapping the $ button, you should see:
```
[OMEGA] fetchHeader start v=<uuid> p=<uuid>
[OMEGA] RPC ok: <performer name>
[OMEGA] Parsed: display=<name>, avatar=YES, location=<location>, thumb=YES
```

If you see errors, the debug panel will show exactly what's failing.

---

## Rollback (If Needed)

If something goes wrong, you can remove the changes:

```sql
DROP FUNCTION IF EXISTS public.donation_header(uuid, uuid);
DROP VIEW IF EXISTS public.v_donation_header;
DROP POLICY IF EXISTS videos_public_read ON public.videos;
DROP POLICY IF EXISTS user_profiles_public_read ON public.user_profiles;
```

---

## Next Steps

After verifying the donation page works:
1. Test with multiple videos/performers
2. Verify all locations display correctly
3. Check that avatars and thumbnails load
4. Test the debug panel (long-press title)

---

## Support

If you encounter issues:
1. Open the OMEGA debug panel (long-press "Support Performer" title)
2. Check console logs for `[OMEGA]` messages
3. Verify the SQL script ran successfully in Supabase
4. Check that RLS policies are active on videos and user_profiles tables
