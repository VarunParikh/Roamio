# Screen states checklist (spec §12)

Rules:
- **One primary (chartreuse) button per screen**, pulsing three times on empty states. It respects Android's "remove animations" setting and Remote Config `cta_pulse_enabled`.
- **No dead ends:** every empty, error and offline state has exactly one clear next action.
- **Accessibility:** touch targets ≥ 48 dp, a label on every control, text contrast ≥ 4.5:1.

Tests:
- States: `app/test/features/ux/screen_states_test.dart`, plus the feature tests named below.
- Accessibility: `app/test/features/ux/accessibility_test.dart`, which runs Flutter's tap-target, label and contrast guidelines on Sign in, Home (empty and full), the adventure page, Add tab, Activity, Split, You and the Privacy centre.
- Palette: `app/test/core/theme/contrast_test.dart`.

## Primary button per screen

| Screen | Primary | Notes |
|---|---|---|
| Sign in / Email sign-in / Create account / Verify email / Complete profile / Confirm adult | the screen's one action | `AuthScaffold.primary` |
| Waiting for parent | Send request, *or* Send the email again | two states, never both at once |
| Parent consent (link) | Agree | decline is secondary |
| Home | Create a new adventure (pulses), only with nothing ahead | with an adventure ahead, New adventure is a plain outlined button and Add tab is white |
| Create / Edit adventure, Add / Edit tab | Save | |
| Adventure page | Share invite | Add tab floats as an ink button with a chartreuse icon, not a second primary |
| Split | none on the screen | Save budget and Mark as settled are primaries inside their own sheets |
| You | Save profile | |
| Privacy centre | Download my data | Delete is a coral outlined button |
| Tab detail, Activity, Invite link, Account paused, Splash | none | read-only or single-exit screens; their one action is an outlined button |

## States and their one next action

| Screen | State | Next action | Test |
|---|---|---|---|
| Home | nothing ahead, no adventures | Create a new adventure (pulsing primary) | `first_screen_test`: no adventures |
| Home | nothing ahead, past trips only | Create a new adventure, then the Past list | `first_screen_test`: past trips only |
| Home card, expanded | no tabs | No spending yet, with See split | `home_expanded_test`: no tabs |
| Home card, expanded | before the trip | no chart, See split stays | `home_expanded_test`: before the trip |
| Home | prompts waiting | Needs you: top 2, then See all | `needs_you_test` |
| Home | can't load | Try again | `screen_states_test`: Home: adventures can't load → Try again |
| Home | offline / back online | banner; Sync when back | `offline_ui_test` |
| Invites on Home | expired or bad code | explains; nothing saved | `invite_flow_test`: an expired code explains itself… |
| Invite link | can't be used | Go to Home | `invite_flow_test` |
| Adventure page | not available (left, removed, not loaded) | Back to Home | `screen_states_test` |
| Adventure page | no tabs | Add tab | `tab_list_test`: an empty list says how to start |
| Adventure page | offline | banner, online-only buttons off with a reason | `offline_ui_test` |
| Tab detail | adventure not available | Back to Home | `screen_states_test` |
| Tab detail | tab deleted / not available | Back to the adventure | `adventure_page_test`: a deleted tab says so |
| Add / Edit tab | adventure not available | Back to Home | `screen_states_test` |
| Add / Edit tab | problems | each field explains; nothing saved | `add_tab_test` |
| Add tab | bill unreadable / OCR fails | says so; nothing changed | `scan_bill_test` |
| Edit adventure | not available | Back to Home | `screen_states_test` |
| Activity | empty | Back to the adventure | `screen_states_test` |
| Activity | can't load | Try again | `screen_states_test` |
| Split | no adventures | New Adventure | `screen_states_test`: Split with no adventures → New Adventure |
| Split | no tabs | Open adventure | `split_screen_test`: no tabs: all square, with a way to add one |
| Split | only waiting tabs | "2 tabs waiting for approval" opens the tab list | `split_screen_test`: only waiting tabs |
| Split | only personal tabs | Open adventure | `split_screen_test`: only personal tabs |
| Split | everyone settled | Everyone is square 🎉; the breakdown still opens | `split_screen_test`: settled |
| Split | can't work out the split | Try again | `screen_states_test` |
| Split | no exchange rates | shown in trip currency, with the reason; if even that can't be worked out, a note and Open adventure | `split_screen_test` |
| Budget | rates missing | says it can't measure yet | `budget_test` |
| Sync | failed | Try again | `offline_ui_test`: a failed sync shows the error and Try again |
| You | photo can't be read | says so (pick another) | `screen_states_test`: You: a photo that can't be read says so |
| Privacy centre | download fails | the reason inline | `privacy_centre_test`: says why a download failed |
| Privacy centre | offline | Download and Delete off, "Needs a connection." | `privacy_centre_test` |
| Privacy centre | leader deleting | "hand over first" message | `privacy_centre_test` |
| Waiting for parent | link expired or declined | Send request again | `consent_flow_test` |
| Parent consent link | expired or replaced | says why, with a way on | `consent_flow_test` |
| Account paused | consent withdrawn | Sign out | `consent_flow_test`: a withdrawn minor sees their account is paused |
| Weather | unavailable | hidden (never an error) | `hero_weather_test` |
| Update popup | below minimum version | Download update (can't be dismissed) | `update_popup_test` |

## Contrast (WCAG, on canvas `#F9FAFB` / white)

| Text colour | Ratio | Use |
|---|---|---|
| ink `#0F1115` | 18.1 / 18.9 | body, headings |
| slate `#64748B` | 4.55 / 4.76 | secondary text (just passes) |
| cobalt `#2563EB` | 4.95 / 5.17 | links |
| coralText `#BE123C` | 6.01 / 6.29 | error and "over budget" words |
| mintText `#047857` | 5.25 / 5.48 | "adds up" words |
| muted `#A1A1AA` | 2.45 / 2.56 | **never as text on light**; only on dark (splash, hero banner) |
| coral `#F43F5E`, mint `#10B981` | 3.5 / 2.5 | fills, bars and icons only |
| ink on chartreuse | 16.3 | primary button |

## Needs eyes on a device (owner's manual session)
- Pulse feel, TalkBack reading order, and hero-card text over real banner photos (the contrast depends on the photo and gradient).
