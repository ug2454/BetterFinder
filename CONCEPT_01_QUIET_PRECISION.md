# BetterFinder — Concept 01: Quiet Precision
## UI & Technical Architecture Specification

**Document Version:** 1.0  
**Design Reference:** macOS 2026 Human Interface Guidelines ("Quiet Precision")  
**Target Window Resolution:** 1440 × 960 pt (Retina @2x: 2880 × 1920 px)  
**Supported Modes:** Dark Mode & Light Mode (Side-by-Side Reference)

---

## 1. Visual Mockup Reference

![Concept 01: Quiet Precision — Dark & Light Mode Comparison](/Users/mecazor/.gemini/antigravity/brain/f6b3f683-e5de-4695-92c4-044034de1f8a/betterfinder_ui_mockup_1789755910314.jpg)

---

## 2. Design Objective & Aesthetic Philosophy

Concept 01 (**Quiet Precision**) delivers the structural transparency and explicit navigation hierarchy of modern desktop file managers while honoring Apple's native craftsmanship. 

* **Restrained Surfaces:** Translucent acrylic vibrancy is applied exclusively to structural chrome (sidebar, unified header toolbar, floating inspector), while file listings sit on stable, high-legibility opaque surfaces.
* **Full-Bleed Chrome:** Seamless integration between window controls and toolbar navigation without redundant window titlebars.
* **Micro-Hairline Definition:** 0.5 pt subtle boundary glow separating panes rather than harsh 1 pt opaque dividers.
* **Tabular Alignment:** Monospaced, tabular numbers for sizes, modification dates, and counts to ensure visual scanning speed.

---

## 3. Window Geometry & Spatial Layout

Primary canvas standard: **1440 × 960 pt**.

```
+---------------------------------------------------------------------------------------------------------+  y = 0
| [• • •]  [ < ] [ > ] [ ^ ]   ( Macintosh HD › Users › alex › Projects › Northstar ▾ )   [Grid|List] [Q] |  h = 52 pt
+-------------------------+-------------------------------------------------------------+-----------------+  y = 52
| SIDEBAR                 | MAIN FILE PANE                                              | INSPECTOR       |
|                         | Column Header: Name | Date Modified | Size | Kind           |                 |
| Favorites               | ----------------------------------------------------------- | Hero Preview    |
|   AirDrop               |   _assets                 Today at 1:25 AM      --   Folder | [ 3D / PNG ]    |
|   Recents               |   config.json             Today at 9:30 AM  3.7 KB   JSON   |                 |
|   Applications          |   index.html              Today at 9:30 PM  2.4 KB   HTML   | Metadata Tags   |
|   Downloads             |   README.md               Today at 1:35 AM  1.2 KB   MD     | #project-north  |
| > Projects              | > screenshot_01.png       Today at 1:25 PM   32 KB   PNG    | #ui-design      |
|                         |   styles.css              Today at 1:25 AM  3.8 KB   CSS    |                 |
| Workspaces              |                                                             | Action Buttons  |
| Drives                  |                                                             | [Open] [Share]  |
| [====================]  |                                                             |                 |
| 312 GB of 1 TB used     | Status: 6 items, 1 selected (32 KB)                         | [ Quick Look ]  |
+-------------------------+-------------------------------------------------------------+-----------------+  y = 936
| STATUS BAR: Items count, selection summary, volume format                                               |  h = 24 pt
+---------------------------------------------------------------------------------------------------------+  y = 960
  w = 224 pt (min: 180, max: 320)  w = 928 pt (min: 480 pt)                     w = 288 pt (min: 240, max: 400)
```

### Dimensions Breakdown
| Region | Width | Height | Resizing Constraints |
| :--- | :--- | :--- | :--- |
| **Window Frame** | 1440 pt | 960 pt | Min: 960 × 640 pt, Default: 1440 × 960 pt |
| **Unified Titlebar / Toolbar** | 100% (1440 pt) | 52 pt | Fixed height, drag region outside controls |
| **Left Sidebar** | 224 pt | 884 pt | Min: 180 pt, Max: 320 pt, collapsible (`Cmd+Option+S`) |
| **Main Content Table** | 928 pt | 884 pt | Flexible, minimum 480 pt |
| **Right Floating Inspector** | 288 pt | 884 pt | Min: 240 pt, Max: 400 pt, collapsible (`Cmd+Option+I`) |
| **Status Bar** | 100% (1440 pt) | 24 pt | Optional toggle, subtle bottom border |

---

## 4. Material & Color Tokens

### 4.1 Vibrancy & Material Specifications
* **Sidebar Vibrancy:** `NSVisualEffectView(material: .sidebar, blendingMode: .behindWindow, state: .active)`
* **Toolbar Vibrancy:** `NSVisualEffectView(material: .headerView, blendingMode: .withinWindow, state: .active)`
* **Floating Inspector:** `NSVisualEffectView(material: .popover, blendingMode: .withinWindow, state: .active)` with `layer.cornerRadius = 14 pt`, `shadowRadius = 24 pt`, `shadowOpacity = 0.18`.
* **Hairline Separators:** `0.5 pt` stroke with 12% white overlay (Dark) or 10% black overlay (Light).

### 4.2 Semantic Palette
| Token | Dark Mode (Graphite Obsidian) | Light Mode (Porcelain Snow) | Usage |
| :--- | :--- | :--- | :--- |
| `surface.window` | `#131518` (80% opacity blur) | `#F6F8FA` (85% opacity blur) | Base window background |
| `surface.content` | `#1A1D21` (100% opaque) | `#FFFFFF` (100% opaque) | Main list view background |
| `surface.elevated` | `#24282F` | `#ECEFF4` | Hovered rows, search pills |
| `text.primary` | `#F3F5F7` (96% white) | `#14181F` (90% black) | File titles, active breadcrumbs |
| `text.secondary` | `#96A0B0` (60% white) | `#5D6878` (65% black) | File sizes, dates, categories |
| `text.tertiary` | `#5F6775` | `#929CA8` | Breadcrumb chevrons, disabled icons |
| `accent.primary` | `#0A84FF` (System Blue) | `#007AFF` | Primary highlights, default buttons |
| `selection.row` | `#1F385C` with subtle border | `#E5EFFF` with subtle border | Active selected row in table |
| `selection.glow` | `rgba(10, 132, 255, 0.25)` | `rgba(0, 122, 255, 0.15)` | 0.5px border glow around selected row |

---

## 5. Component Deep Dive

### 5.1 Unified Titlebar & Capsule Navigation
* **Window Inset Traffic Lights:** Left margin 16 pt, vertically centered at `y = 26 pt`.
* **History Navigation Pills:**
  * Back (`chevron.backward`), Forward (`chevron.forward`), Parent (`chevron.up`).
  * Grouped in a segmented glass pill container (height: 28 pt, corner radius: 7 pt).
* **Capsule Breadcrumb Bar:**
  * Container: Pill-shaped capsule (`background: surface.elevated`, border: `0.5 pt hairline`).
  * Segments: `Macintosh HD` › `Users` › `alex` › `Projects` › `Northstar`.
  * Interaction: Hovering any segment displays a subtle rounded hover indicator (`corner-radius: 5 pt`). Clicking a chevron opens a jump menu of siblings.
  * Direct Path Editing: Double clicking the capsule or pressing `Cmd+L` smoothly flips the capsule into an inline editable NSTextField with autocomplete.
* **Toolbar Actions:**
  * Grid / List view segmented toggle (`rectangle.grid.2x2` vs `list.bullet`).
  * Scoped Search Pill: Compact glass pill input field with magnifying glass icon and scope dropdown (`"Current Folder"` / `"Everywhere"`).

### 5.2 Translucent Sidebar & Storage Telemetry
* **Section Headers:** Uppercase tracking (`10 pt`, weight: `.semibold`, `text.secondary`), e.g. `FAVORITES`, `WORKSPACES`, `DRIVES`.
* **Sidebar Rows:**
  * Height: 28 pt, corner radius: 6 pt.
  * Active Selection: Soft pill fill (`surface.elevated`) with bold SF Symbol glyph.
* **Storage Meter Capsule:**
  * Positioned at the bottom of the sidebar (height: 48 pt, padded 12 pt from bottom).
  * Contains Drive Name (`Macintosh HD`), Storage Bar (`height: 6 pt`, gradient fill `accent.primary` -> `cyan`), and legend (`"312 GB of 1 TB used"`).

### 5.3 Main Content View (List View)
* **Header Bar:**
  * Columns: `Name` (elastic), `Date Modified` (160 pt), `Size` (90 pt, right-aligned), `Kind` (110 pt).
  * Sort Indicator: Sleek chevron showing direction on active column.
* **Row Formatting:**
  * Row Height: 32 pt (standard) or 26 pt (compact setting).
  * File Icon: Native 18 × 18 pt Retina icon with realistic system shadows.
  * Active Selection Row: Full-width rounded capsule fill with soft electric-blue boundary accent (`selection.glow`).
  * Typography: Numerical data (Size, Date) formatted with `font.monospacedDigitSystemFont`.

### 5.4 Floating Right Inspector
* **Placement:** Positioned as an elevated acrylic slate with 16 pt padding from the right edge, or docked pane.
* **Hero Preview:**
  * High-res 3D drop-shadowed preview tile (aspect ratio 4:3 or 16:10).
  * Rounded corners (10 pt), glass border.
* **Metadata Grouping:**
  * Tag Chips: Pill badges (`#project-northstar`, `#mockup`, `#ui-design`).
  * File Attributes: Dimensions (`2880 × 1920`), File size (`32.4 KB`), Created/Modified timestamps, POSIX permissions (`-rw-r--r--`).
* **Contextual Actions:**
  * Glass action buttons: `Open` (primary blue), `Share` (standard glass), `Info / Quick Look` (icon pill).

---

## 6. Implementation & Architecture Mapping (AppKit / Swift)

| Component | AppKit Class / Protocol | Responsibilities |
| :--- | :--- | :--- |
| **Window** | `NSWindow` with `.fullSizeContentView` | Titlebar hidden, window controls inset |
| **Split Container** | `NSSplitViewController` | Manages 3-pane split (Sidebar, Browser, Inspector) |
| **Vibrancy Layer** | `NSVisualEffectView` | Blending modes and materials per panel |
| **Breadcrumbs** | `NSPathControl` / Custom `NSView` | Interactive segment clicking, drag-drop target, path edit toggle |
| **Table List** | `NSTableView` + `NSTableRowView` | Virtualized row recycling, custom selection glow rendering, keyboard navigation |
| **Folder Sizing** | Background POSIX worker | Non-blocking recursive directory size resolution |
| **Preview Engine** | `QLPreviewView` / `QuickLookUI` | Native Quick Look thumbnailing & preview rendering |

---

## 7. Keyboard Navigation & Shortcuts

| Shortcut | Action |
| :--- | :--- |
| `Cmd + 1` / `Cmd + 2` | Toggle List View / Icon View |
| `Cmd + [` / `Cmd + ]` | Navigate Back / Forward |
| `Cmd + Up` | Navigate to Parent Directory |
| `Cmd + L` | Focus & Edit Path Address Bar |
| `Cmd + Option + S` | Toggle Sidebar Visibility |
| `Cmd + Option + I` | Toggle Right Inspector |
| `Space` | Instant Native Quick Look |
| `Cmd + F` | Focus Scoped Search Pill |
| `Return` / `Enter` | Rename Selected Item |
| `Cmd + Down` / `Cmd + O`| Open Selected File / Enter Folder |
