# Design System Integration

_Started 2026-04-24 17:44 UTC_

---

## User

complete the design base on kbsync and figma

## Assistant

_[tool: read_file]_

_[tool: fig_ls]_

_[tool: fig_ls]_

_[tool: read_file]_

Let me explore the Figma file thoroughly before building.

_[tool: fig_ls]_

_[tool: fig_read]_

_[tool: fig_read]_

_[tool: fig_read]_

_[tool: fig_read]_

_[tool: fig_read]_

_[tool: fig_read]_

_[tool: fig_read]_

_[tool: fig_read]_

_[tool: fig_read]_

_[tool: fig_read]_

_[tool: fig_read]_

_[tool: fig_read]_

_[tool: fig_read]_

_[tool: fig_read]_

_[tool: fig_read]_

_[tool: fig_read]_

_[tool: fig_read]_

_[tool: fig_read]_

_[tool: fig_read]_

Now I have a thorough understanding. Let me build the full interactive prototype.

_[tool: update_todos]_

_[tool: write_file]_

_[tool: done]_

_[tool: fork_verifier_agent]_

_[tool: update_todos]_

Here's what was built — **KA-BAYAN SYNC** fully interactive prototype with **14 screens** across both the Hirer and Worker flows:

---

**Onboarding Flow**
- 🏠 Welcome splash → Sign Up / Sign In
- 🪪 ID type selection (National, Student, Barangay)
- 📷 ID scan with animated scan line + auto-capture sim
- ✅ ID review with extracted details confirmation
- 👤 Face liveness scan with progress ring + side-turn arrows
- 🎉 Verification success with Ka-Bayan Verified badge

**Hirer Flow**
- 🗺️ Live map with 2km radius, worker markers, entrance face scan banner, task detail bottom sheet
- 📋 Create Task — service type grid, area chips, complexity, rush/standard mode selector

**Worker Flow**
- 👷 Profile with online/offline toggle, trust score, wallet balance, live task alert
- 📢 Task available with 15-second countdown ring
- 📸 Evidence Log — simulated camera with GPS watermark, verification progress bar, photo capture
- 🏁 Completion Summary — before/after logs, task metadata, proceed to payment

Use the **nav chips** at the top to jump to any screen. All buttons within screens navigate contextually through the flow.

## User

Verifier agent check completed

## Assistant

All checks passed! The prototype is clean and ready. Let me know if you'd like to refine any screen, add more interactions, or adjust the design.

## User

redesign make it modern but same color pallet and fonts also add a resident dashboard and worker dashboard

## Assistant

_[tool: invoke_skill]_

_[tool: update_todos]_

Let me plan the full redesign, then build it all at once.

**Direction:** Warm Civic-Tech — bold typographic hierarchy, frosted glass cards, gradient accents (plum→orange), rich dashboard data layouts, polished micro-interactions. Modern but grounded in Filipino community warmth.

_[tool: write_file]_

_[tool: done]_

_[tool: fork_verifier_agent]_

Here's what's new in **v2**:

---

**🎨 Design Overhaul**
- Gradient accents (plum → orange), refined card shadows, consistent 14–20px border radii
- Bold 800–900 weight typographic hierarchy throughout
- Frosted glass overlays on camera/map screens
- Subtle grid texture on welcome, floating orb animations

**🏡 Resident Dashboard** *(new)*
- 4-metric stat grid (Active Tasks, Monthly Spend, Workers Hired, Avg Rating)
- Quick action service buttons (Cleaning, Pabili, Laundry, Dishes)
- Live active task cards with worker + status
- Nearby workers map preview with tap-to-open
- Spending breakdown with category progress bars
- Task history with ratings

**👷 Worker Dashboard** *(new)*
- Trust Score ring (67/100) + Today's Earnings card side by side
- Ka-Bayan Wallet with balance + trust bond breakdown
- Weekly earnings bar chart with day-by-day breakdown
- Rookie probation progress bar with unlock info
- Live task alert (glowing orange when online)
- Online/offline toggle + recent task feed

**All 15 screens** updated with the same modern system — use the chips at the top to jump between any screen.

## User

Verifier agent check completed

## Assistant

All clear — verifier passed on every screen. The prototype is ready to use. Let me know if you'd like to refine anything, add more flows, or export it.

## User

add worker can see task list nearby

## Assistant

_[tool: read_file]_

_[tool: grep]_

_[tool: str_replace_edit]_

_[tool: str_replace_edit]_

Now wire it into the router and worker nav:

_[tool: str_replace_edit]_

Now update the Worker Dashboard bottom nav to route Tasks → Nearby Tasks, and add the "Browse Tasks" button link:

_[tool: str_replace_edit]_

Now add a "Browse Nearby Tasks" button in the Worker Dashboard and update the task alert to also mention the list:

_[tool: str_replace_edit]_

_[tool: done]_

_[tool: fork_verifier_agent]_

Here's what was added:

**📍 Nearby Tasks screen** — accessible from:
- Worker Dashboard → **Browse Nearby Tasks** button
- Bottom nav **Tasks** tab
- Top chip **📍 Nearby Tasks**

**Features:**
- **Map strip** — mini map showing your location (plum dot) + color-coded task pins per service type, 2km dashed radius ring
- **Filter chips** — All / 🧹 Cleaning / 🛒 Pabili / 🧺 Laundry / 🍽️ Dishes
- **Sort toggle** — switch between By Distance and By Payout
- **Task cards** — show emoji icon, title, area, client name, distance badge, complexity tag (color-coded Light/Moderate/Heavy), payout, time, and inline **Accept** button
- **RUSH badge** on urgent tasks
- Tapping any card or Accept navigates to the Task Available detail screen

## User

Verifier agent check completed

## Assistant

## User

Save as standalone HTML: KaBayanSync v2.html

## Assistant

## Assistant

