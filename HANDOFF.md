# Odoch Export Tracker — Deployment Handoff

**Status:** Frontend package prepared; repository setup in progress.

## Important separation rule
Odoch Export Tracker must use its own dedicated Supabase project. Do not run its SQL, change settings, pause, reset, or otherwise modify SmartAttend or any other production database. No Odoch database has been provisioned or connected by this deployment.

## Repository and hosting
- Repository: https://github.com/odoema/odoch_export_tracker
- Default branch: main
- Hosting target: GitHub Pages using the workflow in .github/workflows/pages.yml
- After the app files are committed, open Settings → Pages and select **GitHub Actions** as the source.

## Backend still required
1. Create a separate Supabase project exclusively for Odoch Export Tracker.
2. Apply supabase/001_initial_schema.sql in that new project's SQL Editor.
3. Verify the profiles, shipments and shipment_events tables, RLS policies and tracking RPCs.
4. Configure Auth Site URL and redirect URLs for the final GitHub Pages URL.
5. Enter only the project's URL and publishable/anon key in the app. Never expose service-role keys or database passwords.
6. Test sign-up, sign-in, shipment CRUD, milestones, owner isolation and buyer tracking.

## MVP limitations
- Routes are indicative great-circle routes, not live AIS positions.
- Shipment milestones are manually entered.
- SMS/email notifications, carrier integrations and payment processing are not included.
- Review buyer-visible tracking fields and use non-sensitive references.

## Completion status
- [x] Improved frontend package prepared and syntax-checked
- [x] GitHub repository verified and write access confirmed
- [ ] Full application files committed
- [ ] GitHub Pages configured and deployment verified
- [ ] Dedicated Odoch Supabase project created
- [ ] SQL migration applied and security reviewed
- [ ] Frontend connected and end-to-end tested
