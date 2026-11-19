# Odoch Export Tracker

A static web app for managing export shipments, tracking manual milestones and sharing buyer-facing tracking links.

## Features
- Interactive D3 globe with indicative great-circle routes.
- Create, search, edit and delete shipments.
- Dashboard progress totals and shipment status.
- Six manually updated shipment milestones, with timestamps and undo.
- Supabase Auth for private exporter accounts.
- Row-level security to isolate each exporter's shipments and event history.
- Token-based, read-only buyer tracking links.

## Backend setup
1. Create a **dedicated Supabase project for Odoch Export Tracker**. Do not reuse, pause, modify or run SQL against SmartAttend or any other production project.
2. In the new project's SQL Editor, run `supabase/001_initial_schema.sql`.
3. In Project Settings → API, copy the Project URL and publishable/anon key.
4. Open the app and enter those values in its initial connection screen.
5. Create an exporter account and sign in. Confirm the email first if email confirmation is enabled.

Only use the publishable/anon key in browser code. Never expose a service-role/secret key or database password.

## GitHub Pages deployment
The repository includes a GitHub Actions workflow at `.github/workflows/pages.yml`. In GitHub, open **Settings → Pages** and select **GitHub Actions** as the build and deployment source. Push the application files to `main`; the workflow will publish the repository root.

## Launch checklist
- Set the Supabase Auth Site URL and allowed redirect URLs to the final HTTPS site URL.
- Configure SMTP before inviting customers at scale.
- Review the fields returned by `public_track_shipment`; buyer tracking intentionally exposes shipment details and milestone timestamps.
- Use non-sensitive buyer-visible references.
- Test account isolation with at least two exporter accounts.
- Configure backups, privacy policy, terms and support contact before commercial launch.

## MVP boundaries
- No live AIS vessel positioning; route lines are indicative only.
- Milestones are entered manually by the exporter.
- SMS/email notifications, carrier integrations and payment processing are not included.
- A dedicated Supabase project and credentials are required; the frontend is not connected to a live backend until configured.
