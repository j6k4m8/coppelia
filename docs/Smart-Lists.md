# Smart Lists (Self-Updating Playlists)

Smart Lists are local-only, rule-driven playlists that update automatically.
They do not sync to Jellyfin and do not change your library. They live only
inside Coppelia.

This document explains how Smart Lists work for users, and also defines the
rule language that powers them.

---

## Quick Start

To get started, click the new smart list item in the sidebar.

<img width="250" height="146" alt="image" src="https://github.com/user-attachments/assets/656cc092-21dc-45d7-bb39-b8b80ed46f31" />

You will see a smart-list creation wizard:

<img width="712" height="798" alt="image" src="https://github.com/user-attachments/assets/c06f5673-4a6d-47b6-be29-a3efc2a986f4" />

Several templates are available to get you started.

<img width="710" height="540" alt="image" src="https://github.com/user-attachments/assets/28c9963d-0f85-4837-ac52-5da78926432b" />

If you have a more complicated rule-set, you can compose nested rules yourself:

<img width="700" height="576" alt="image" src="https://github.com/user-attachments/assets/2508c697-542e-4045-ae54-9f0161be368e" />

<img width="699" height="904" alt="image" src="https://github.com/user-attachments/assets/67a96e06-312c-4961-bd36-1bf8b362da36" />

Once you submit the rule-set, your smart list will appear in the sidebar under Smart Lists.

<img width="250" height="135" alt="image" src="https://github.com/user-attachments/assets/2f412cc6-5d3f-444a-9bd8-891560b35dca" />

<img width="1024" height="620" alt="image" src="https://github.com/user-attachments/assets/f2d14cdd-9364-43fa-a4c8-0888a22311dd" />

Clicking or tapping the ellipsis in the smart list header gives you the opportunity to edit the rules or delete the smart list.

<img width="766" height="425" alt="image" src="https://github.com/user-attachments/assets/45bd38d8-4bf4-4db8-9c77-a9c57b710657" />

---

## Where They Live

Smart Lists appear in the sidebar under **Playlists** and above
**Available Offline**. They behave like playlists, but they are generated
from rules.

---

## How Rules Work

A rule is:

**Field + Operator + Value**

Examples:

-   Title contains "Adagio"
-   Play count equals 0
-   Added date in last 30d

Rules live inside groups, and groups decide how to combine rules:

-   **All** (AND): every rule must match
-   **Any** (OR): at least one rule must match
-   **Not** (NOT): none of the rules may match

Groups can be nested.

---

## Input Formats

Dates:

-   Absolute date: `YYYY-MM-DD` (ex: `2024-10-01`)
-   Relative date: `30d`, `8w`, `6m`, `1y`

Duration:

-   `mm:ss` (ex: `04:32`)
-   Or plain seconds (ex: `272`)

Numbers:

-   Use plain numeric values (ex: `0`, `5`, `12`)

Text:

-   Case-insensitive matches

---

## What You Can Filter (Current)

Scope:

-   Tracks only (for now)

Fields:

-   Title
-   Album
-   Artist
-   Genre
-   Added date
-   Play count
-   Last played date
-   Duration
-   Track is favorite
-   Track is downloaded (pinned for offline)
-   Album is favorite (based on track album)
-   Artist is favorite (based on track artists)

Operators:

-   Text: contains, does not contain, equals, not equals, starts with, ends with
-   Numbers: equals, not equals, greater than, less than, between
-   Dates: is before, is after, is on, in last, not in last
-   Booleans: is true, is false

---

## Sorting and Limits

After filtering, Smart Lists can:

-   Sort by any field (ascending or descending)
-   Limit the number of results

Limits apply after sorting.

---

## Examples

1. Added recently

```
addedAt inLast 30d
```

2. Unplayed favorites

```
isFavorite isTrue AND playCount equals 0
```

3. Not live recordings

```
NOT (title contains "Live")
```

4. Long tracks

```
duration greaterThan 10:00
```

---

## Under the Hood (Spec)

Smart Lists are stored locally as JSON and evaluated in-app.

Structure:

-   `name`: display name
-   `scope`: tracks (future: albums, artists)
-   `group`: the root rule group
-   `sorts`: list of sort rules
-   `limit`: maximum results

Pseudo-DSL:

```
group(match: "all") {
  rule(field: "addedAt", op: "inLast", value: "30d")
  rule(field: "playCount", op: "equals", value: 0)
}
```

---

## Planned (Not Yet Implemented)

-   Album/artist Smart List scopes
-   Multi-value rules (ex: artist in [A, B, C])
-   Regex matching
-   Ratings, tags, user labels
-   Rule presets per genre or mood
