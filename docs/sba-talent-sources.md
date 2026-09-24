# SBA talent source research

Checked: **2026-09-24**. The runtime catalog contains nine source-supported targets (eight exact publisher imports and one Fire Mage guide adaptation), fourteen separately labeled `guide-inferred` candidates, 22 exact user-provided targets, and six preserved legacy Druid imports. These are source checks, user submissions and project inferences, not in-game or simulation tests. A page's patch label is not proof that its talent data or every hero variant was retested for that patch.

## Recommended source strategy

Use **SBA-specific creator builds as candidates**, **current class guides for validation and missing coverage**, and **SBA-mode simulations plus gameplay checks for recommendations**. No inspected source established a current, verified, level-by-level SBA optimum for every specialization and hero tree.

| Source | Evidence observed | Appropriate use |
| --- | --- | --- |
| [Dvalin's own SBA guide index](https://www.reddit.com/r/Dvalin/comments/1sglwty/all_my_singlebutton_assistant_sba_builds_for_wow/) | 26 specialization guide links; author directs users to Discord for exports. Latest explicitly listed revision was Windwalker, 2026-06-24. | Best directly SBA-focused starting point found. Obtain the current export and exact post/version for each build; do not infer current patch or every hero tree from the index. |
| [Noxxic One Button simulation documentation](https://www.noxxic.com/wow/info/sim-with-one-button-assisted-highlight) | Published 2026-04-10; current page title says Midnight 12.1. Offers separate Default, Assisted Highlight and One Button modes, and warns of incomplete/broken spec support. | Compare candidate builds using the correct rotation mode only for supported specs. A general Noxxic talent recommendation is not automatically the One Button winner. |
| [Noxxic One Button ranking](https://www.noxxic.com/wow/dps-rankings/one-button-alt) | The older `one-button-288` route redirects here. HTML exposes rankings and SimC revision `849a7bef306cc46d137106e372b95fdb0fdeb061`; no talent exports or report links were found. | Benchmark lead, not a verified import feed or a universal ranking across gear/content. |
| [Icy Veins Havoc alternatives](https://www.icy-veins.com/wow/havoc-demon-hunter-pve-dps-easy-mode) | Wordup, 2026-08-30, 12.1; explicitly supplies Fel-Scarred Rotation Assist raid and dungeon exports. | Both exact exports are in the catalog with manual cooldown/movement requirements. |
| [Icy Veins Devourer alternatives](https://www.icy-veins.com/wow/devourer-demon-hunter-pve-dps-easy-mode) | Voodoo/Wordup, 2026-08-10, 12.1; supplies Annihilator Assist single-target/AoE exports despite major tool limitations. | Both exact exports are in the catalog with the publisher's limitations preserved. |
| [Icy Veins Windwalker Easy Mode](https://www.icy-veins.com/wow/windwalker-monk-pve-dps-easy-mode) | By Babylonius, updated 2026-08-11, patch 12.1; discusses SBA limitations and channel protection alongside beginner guidance. | Class-expert cross-check. Easy Mode plus an SBA section does not by itself demonstrate SBA-optimized talent selection. |
| [Icy Veins Guardian leveling](https://www.icy-veins.com/wow/guardian-druid-leveling-guide) | By Pumps, updated 2026-08-10, patch 12.1; explicitly provides a level-adapted guide. | Candidate leveling order requiring separate SBA validation; not an SBA-specific claim. |
| [Wowhead Guardian talents](https://www.wowhead.com/guide/classes/druid/guardian/talent-builds-pve-tank) | By Pumps, updated 2026-08-28, patch 12.1.0; raid/Mythic+ talent imports. | Current general-build and hero-choice cross-check. The inspected page did not establish a dedicated SBA optimum. |

[Noxxic's character-sim documentation](https://www.noxxic.com/wow/info/character-sims) places character simulations behind Noxxic+ membership. No documented public build-update API was verified in this research. Do not implement a hidden website scrape as an in-game data dependency.

## Catalog coverage after this research

The runtime catalog contains **51 entries across 26 specializations**. The nine source-supported records comprise four publisher-designated assistant alternatives (Havoc and Devourer, two each), four author-endorsed SBA-compatible starters (Frost Death Knight, Beast Mastery Hunter, Brewmaster Monk and Shadow Priest), and the Fire Mage guide adaptation. Fourteen weaker guide-inferred candidates, 22 user-provided targets, and six original legacy Druid imports are counted separately. The status counts are **4 `source-sba`, 4 `source-compatible`, 1 `guide-adapted`, 14 `guide-inferred`, 22 `user-provided`, and 6 `legacy-unverified`**. 14 of the 40 specs still have no bundled target, and hero/content coverage remains incomplete. User submissions improve available-target coverage without establishing publisher or performance verification.

`source-sba` means the publisher explicitly provides that exact export for assisted play. `source-compatible` means the author connects the exact starter build or its talent choices to SBA. `guide-adapted` means BetterSBA changed an export to follow specific written guide advice, with the original and change recorded. `guide-inferred` means the export is an unchanged general publisher build and the accompanying guide discusses SBA at spec level; choosing that exact whole build for assisted play is BetterSBA's inference. It is not an exact-build SBA endorsement. `user-provided` means the user supplied the exact import and any content labels; the word meta is attribution to that submission, not independently verified performance. None of these statuses means this project simulated the build, tested it in game, or proved it best. The publishers did not provide level-by-level acquisition orders. BetterSBA separately derives guide-informed priority weights for covered targets, restricted to talents already in the selected build; these are project inferences rather than publisher-authored leveling orders.

The [Fire Mage basics guide](https://www.wowhead.com/guide/classes/mage/fire/basics) recommends targeted Flamestrike in its prose, but its published starter export selects the ground-targeted variant. BetterSBA's Fire target changes only this choice: node `109409`, from spell `2120` to spell `1254851` / entry `135602`. The [adaptation record](sba-priorities-dk-hunter-mage.json) retains the original, proposed export and comparison showing the other selected entries, ranks, hero selection and header unchanged. The author does not say the targeted variant is technically required by SBA. This is a transparent guide-alignment inference, not a publisher export or an in-game-verified improvement.

[The Icy Veins audit](icy-veins-sba-candidates.json) records every one of the 40 inspected pages, its observed update date, classification and limitations. [The Wowhead audit](wowhead-sba-candidates.json) records the initial strict review of 40 basics pages, linked-guide checks, exact candidate exports and source evidence. Its original exclusion flags describe that initial pass. The [bounded expansion record](sba-catalog-expansion-20260924.json) separately records fourteen later additions under the weaker `guide-inferred` standard, their exact export, hero identity and offline checks. Four additional Feral main-page imports remain research-only `meta-candidate`; their identity with the easy-page builds could not be established.

The expansion covers both hero variants for five previously absent specs:

| Spec | Exact publisher targets added | Source freshness and SBA limits |
| --- | --- | --- |
| Destruction | Diabolist and Hellcaller AoE | [Talent guide](https://www.wowhead.com/guide/classes/warlock/destruction/talent-builds-pve-dps), Loozy, updated 2026-08-29, 12.1.0. Both unchanged exports already select Mayhem, matching the [rotation guide's advice](https://www.wowhead.com/guide/classes/warlock/destruction/rotation-cooldowns-pve-dps) when Havoc would otherwise go unused. Infernal and other cooldowns remain manual. |
| Devastation | Scalecommander and Flameshaper, each raid and Mythic+ | [Talent guide](https://www.wowhead.com/guide/classes/evoker/devastation/talent-builds-pve-dps), Preheat, updated 2026-09-23, 12.1.0. The [basics guide](https://www.wowhead.com/guide/classes/evoker/devastation/basics) describes SBA as suitable at spec level; manual cooldowns and rapid-input empower/channel cancellation still matter. |
| Arms | Slayer and Colossus, each single-target raid and Mythic+ | [Talent guide](https://www.wowhead.com/guide/classes/warrior/arms/talent-builds-pve-dps), Archimtiros, updated 2026-08-12, 12.1.0. The [basics guide](https://www.wowhead.com/guide/classes/warrior/arms/basics) describes capable SBA behavior with manual defensive, mobility and utility use. |
| Assassination | Deathstalker and Fatebound, single-target raid only | [Talent guide](https://www.wowhead.com/guide/classes/rogue/assassination/talent-builds-pve-dps), Whispyr, updated 2026-09-06, 12.1.0. The [basics guide](https://www.wowhead.com/guide/classes/rogue/assassination/basics) distinguishes stronger single-target behavior from missing AoE bleed-spreading behavior; no AoE candidate is promoted here. |
| Augmentation | Chronowarden general raid and Scalecommander Mythic+/Delves | [Easy-mode guide](https://www.icy-veins.com/wow/augmentation-evoker-pve-dps-easy-mode), Saeldur, updated 2026-08-10, 12.1. Includes manual cooldown requirements and empower cancellation concerns. Its historical assistant-related simplification note does not prove current per-hero SBA retesting. |

These additions provide choices to inspect and follow, without representing every new target as author-endorsed for SBA. Their whole-build suitability remains inferred and their rating is blank. The existing guide-priority profiles do not automatically extend to new IDs; uncovered targets use the normal legal path until separate priority evidence is added.

### Exact user-provided targets

The [user-target audit](user-sba-targets-20260924.json) preserves each submitted string byte-for-byte and records its decoded spec, hero tree, purchased entries and tree hash. It contains no invented publisher URL or patch label. The first Blood leveling code was replaced entirely by the user's corrected code; only the replacement remains active and recorded.

| Spec | Decoded hero tree | User-specified content |
| --- | --- | --- |
| Blood Death Knight | San'layn | Leveling / Delves / Dungeons |
| Blood Death Knight | San'layn | Raids |
| Mistweaver Monk | Conduit of the Celestials | General SBA / user-supplied meta |
| Arms Warrior | Slayer | General SBA / user-supplied meta |
| Restoration Shaman | Totemic | General SBA / user-supplied meta |
| Enhancement Shaman | Stormbringer | General SBA / user-supplied meta |
| Discipline Priest | Oracle | General SBA / user-supplied meta |
| Shadow Priest | Voidweaver | General SBA / user-supplied meta |
| Windwalker Monk | Shado-Pan | General SBA / user-supplied meta |
| Unholy Death Knight | Rider of the Apocalypse | General SBA / user-supplied meta |
| Balance Druid | Elune's Chosen | General SBA / user-supplied meta |
| Survival Hunter | Sentinel | General SBA / user-supplied meta |
| Restoration Druid | Wildstalker | General SBA / user-supplied meta |
| Elemental Shaman | Farseer | General SBA / user-supplied meta |
| Frost Death Knight | Deathbringer | General SBA / user-supplied meta |
| Marksmanship Hunter | Sentinel | General SBA / user-supplied meta |
| Guardian Druid | Elune's Chosen | General SBA / user-supplied meta |
| Beast Mastery Hunter | Pack Leader | General SBA / user-supplied meta |
| Brewmaster Monk | Master of Harmony | General SBA / user-supplied meta |
| Feral Druid | Druid of the Claw | General SBA / user-supplied meta |
| Destruction Warlock | Hellcaller | Mythic+ (user supplied) |
| Destruction Warlock | Diabolist | General SBA / user-supplied meta |

The two supplied Destruction imports also match the previously cataloged general Wowhead exports exactly. They remain separate user targets, preserving Hellcaller’s explicit Mythic+ label and Diabolist’s unspecified general-content label without upgrading either to a verified SBA build.

Blood's two imports both select San'layn but differ on 23 nodes, including utility and defensive allocations and the Blood-Soaked Ground/Desecrate, Bloody Fortitude/Vampiric Aura, and Vampiric Speed/Newly Turned choices. The corrected leveling code has a zero tree hash; the raid code has a nonzero hash that must match the running client. The offline decode confirms structural identities, not that hash match or a universally best build.

Current Blood guidance is mixed. [Icy Veins' 12.1 beginner guide](https://www.icy-veins.com/wow/blood-death-knight-pve-tank-easy-mode) now describes SBA as viable while leveling despite remaining offensive and defensive weaknesses. [Wowhead's Blood basics](https://www.wowhead.com/guide/classes/death-knight/blood/basics) still recommends against SBA for Blood and stresses manual defensive use. Neither is presented as the publisher of the user's codes. Deathbringer remains an unfilled Blood hero-variant gap in this catalog.

Healer imports do not turn SBA into a healing decision-maker. It selects supported damage actions; damage-linked passive healing may occur, but targeted heals, triage, utility and defensive choices remain manual. The [Restoration Shaman DPS guide](https://www.icy-veins.com/wow/restoration-shaman-pve-dps-guide) explicitly frames one-button use as damage assistance while healing remains necessary. These user submissions are not classified as verified healer SBA recommendations.

| Class | Spec / inspected Icy Veins page | Added bundled targets | Preserved legacy imports | Icy Veins outcome |
| --- | --- | --- | --- | --- |
| Death Knight | [Blood (250)](https://www.icy-veins.com/wow/blood-death-knight-pve-tank-easy-mode) | 2 user-provided | 0 | Leveling SBA considered viable with limits; no dedicated export obtained |
| Death Knight | [Frost (251)](https://www.icy-veins.com/wow/frost-death-knight-pve-dps-easy-mode) | 1 compatible, 1 user-provided | 0 | General talents; no dedicated SBA export |
| Death Knight | [Unholy (252)](https://www.icy-veins.com/wow/unholy-death-knight-pve-dps-easy-mode) | 1 user-provided | 0 | General talents; no dedicated SBA export |
| Demon Hunter | [Havoc (577)](https://www.icy-veins.com/wow/havoc-demon-hunter-pve-dps-easy-mode) | 2 SBA | 0 | Exact assist alternatives |
| Demon Hunter | [Vengeance (581)](https://www.icy-veins.com/wow/vengeance-demon-hunter-pve-tank-easy-mode) | 0 | 0 | Publisher documents SBA limitations |
| Demon Hunter | [Devourer (1480)](https://www.icy-veins.com/wow/devourer-demon-hunter-pve-dps-easy-mode) | 2 SBA | 0 | Exact assist alternatives |
| Druid | [Balance (102)](https://www.icy-veins.com/wow/balance-druid-pve-dps-easy-mode) | 1 user-provided | 2 | General talents; no dedicated SBA export |
| Druid | [Feral (103)](https://www.icy-veins.com/wow/feral-druid-pve-dps-easy-mode) | 1 user-provided | 2 | Compatibility evidence; exact widget unavailable |
| Druid | [Guardian (104)](https://www.icy-veins.com/wow/guardian-druid-pve-tank-easy-mode) | 1 user-provided | 2 | General talents; no dedicated SBA export |
| Druid | [Restoration (105)](https://www.icy-veins.com/wow/restoration-druid-pve-healing-easy-mode) | 1 user-provided | 0 | Damage assistant; user target does not automate healing decisions |
| Evoker | [Devastation (1467)](https://www.icy-veins.com/wow/devastation-evoker-pve-dps-easy-mode) | 4 inferred | 0 | General talents; no dedicated SBA export |
| Evoker | [Preservation (1468)](https://www.icy-veins.com/wow/preservation-evoker-pve-healing-easy-mode) | 0 | 0 | Damage-only assistant; healing build not qualified |
| Evoker | [Augmentation (1473)](https://www.icy-veins.com/wow/augmentation-evoker-pve-dps-easy-mode) | 2 inferred | 0 | Exact general exports plus SBA guidance; whole-build suitability inferred |
| Hunter | [Beast Mastery (253)](https://www.icy-veins.com/wow/beast-mastery-hunter-pve-dps-easy-mode) | 1 compatible, 1 user-provided | 0 | General talents; no dedicated SBA export |
| Hunter | [Marksmanship (254)](https://www.icy-veins.com/wow/marksmanship-hunter-pve-dps-easy-mode) | 1 user-provided | 0 | General talents; no dedicated SBA export |
| Hunter | [Survival (255)](https://www.icy-veins.com/wow/survival-hunter-pve-dps-easy-mode) | 1 user-provided | 0 | General talents; no dedicated SBA export |
| Mage | [Arcane (62)](https://www.icy-veins.com/wow/arcane-mage-pve-dps-easy-mode) | 0 | 0 | General talents; no dedicated SBA export |
| Mage | [Fire (63)](https://www.icy-veins.com/wow/fire-mage-pve-dps-easy-mode) | 1 guide-adapted | 0 | General talents; no dedicated SBA export |
| Mage | [Frost (64)](https://www.icy-veins.com/wow/frost-mage-pve-dps-easy-mode) | 0 | 0 | General talents; no dedicated SBA export |
| Monk | [Brewmaster (268)](https://www.icy-veins.com/wow/brewmaster-monk-pve-tank-easy-mode) | 1 compatible, 1 user-provided | 0 | Compatibility evidence; exact widget unavailable |
| Monk | [Windwalker (269)](https://www.icy-veins.com/wow/windwalker-monk-pve-dps-easy-mode) | 1 user-provided | 0 | General talents; no dedicated SBA export |
| Monk | [Mistweaver (270)](https://www.icy-veins.com/wow/mistweaver-monk-pve-healing-easy-mode) | 1 user-provided | 0 | Damage assistant; user target does not automate healing decisions |
| Paladin | [Holy (65)](https://www.icy-veins.com/wow/holy-paladin-pve-healing-easy-mode) | 0 | 0 | Damage-only assistant; healing build not qualified |
| Paladin | [Protection (66)](https://www.icy-veins.com/wow/protection-paladin-pve-tank-easy-mode) | 0 | 0 | Publisher documents SBA limitations |
| Paladin | [Retribution (70)](https://www.icy-veins.com/wow/retribution-paladin-pve-dps-easy-mode) | 0 | 0 | Publisher documents SBA limitations |
| Priest | [Discipline (256)](https://www.icy-veins.com/wow/discipline-priest-pve-healing-easy-mode) | 1 user-provided | 0 | Damage assistant; user target does not automate healing decisions |
| Priest | [Holy (257)](https://www.icy-veins.com/wow/holy-priest-pve-healing-easy-mode) | 0 | 0 | Damage-only assistant; healing build not qualified |
| Priest | [Shadow (258)](https://www.icy-veins.com/wow/shadow-priest-pve-dps-easy-mode) | 1 compatible, 1 user-provided | 0 | General talents; no dedicated SBA export |
| Rogue | [Assassination (259)](https://www.icy-veins.com/wow/assassination-rogue-pve-dps-easy-mode) | 2 inferred | 0 | General talents; no dedicated SBA export |
| Rogue | [Outlaw (260)](https://www.icy-veins.com/wow/outlaw-rogue-pve-dps-easy-mode) | 0 | 0 | Publisher documents SBA limitations |
| Rogue | [Subtlety (261)](https://www.icy-veins.com/wow/subtlety-rogue-pve-dps-easy-mode) | 0 | 0 | General talents; no dedicated SBA export |
| Shaman | [Elemental (262)](https://www.icy-veins.com/wow/elemental-shaman-pve-dps-easy-mode) | 1 user-provided | 0 | Publisher documents SBA limitations |
| Shaman | [Enhancement (263)](https://www.icy-veins.com/wow/enhancement-shaman-pve-dps-easy-mode) | 1 user-provided | 0 | Further publisher comparison needed |
| Shaman | [Restoration (264)](https://www.icy-veins.com/wow/restoration-shaman-pve-healing-easy-mode) | 1 user-provided | 0 | Damage assistant; user target does not automate healing decisions |
| Warlock | [Affliction (265)](https://www.icy-veins.com/wow/affliction-warlock-pve-dps-easy-mode) | 0 | 0 | General talents; no dedicated SBA export |
| Warlock | [Demonology (266)](https://www.icy-veins.com/wow/demonology-warlock-pve-dps-easy-mode) | 0 | 0 | General talents; no dedicated SBA export |
| Warlock | [Destruction (267)](https://www.icy-veins.com/wow/destruction-warlock-pve-dps-easy-mode) | 2 inferred, 2 user-provided | 0 | General talents; no dedicated SBA export |
| Warrior | [Arms (71)](https://www.icy-veins.com/wow/arms-warrior-pve-dps-easy-mode) | 4 inferred, 1 user-provided | 0 | General talents; no dedicated SBA export |
| Warrior | [Fury (72)](https://www.icy-veins.com/wow/fury-warrior-pve-dps-easy-mode) | 0 | 0 | General talents; no dedicated SBA export |
| Warrior | [Protection (73)](https://www.icy-veins.com/wow/protection-warrior-pve-tank-easy-mode) | 0 | 0 | General talents; no dedicated SBA export |

One hero variant in a source is not evidence for the other variant. Empty coverage stays empty until an exact candidate and supporting evidence are available. The Dvalin public index remains a useful discovery lead, but its 26 linked guides and Discord invitation do not establish current exports for every spec or hero variant.


## What “next best talent” can mean

Blizzard's [loadout serializer](https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_PlayerSpells/ClassTalents/Blizzard_ClassTalentImportExport.lua) stores selected nodes, purchased ranks and choice entries in tree-node order. It does **not** store the order the author spent points. The file is Blizzard UI source distributed through a community mirror.

Therefore an endgame import alone supplies a **target allocation**, not an evidence-backed next-point priority. A deterministic legal path toward that allocation is useful, but must be described as “follow this build.” Guide-informed priority weights can improve that fallback: favor source-supported engines/synergies and propagate priority back through the selected prerequisite paths. These weights are reasoned project choices, not measured DPS rankings. Calling a choice a proven optimum requires comparative validation. The best temporary leveling allocation can also differ from the final endgame allocation.

For a validated order, record individual rank purchases and choice entries. Respect separate class/spec/hero currencies, prerequisite ranks, level gates and hero unlocks. If the player already chose a conflicting branch, additive auto-spend stops with an explanation. Refunding requires the player's explicit **RESPEC TO SBA** action described below. Each purchase must use its own class/spec/hero currency; a blocked priority must never justify spending outside the selected target.

## Guide-informed priorities in this build

The priority research includes **78 rules across 11 specs**; adding a target does not automatically extend these profiles to its ID. All numeric acquisition weights are project inferences. They favor documented resource engines, relevant passive synergies, survival tools and selected cooldowns; they do not automatically discard talents just because SBA requires a manual cast. A priority is eligible only when its supported build ID and current definition spell ID match the selected full target. The score can promote the selected prerequisite path toward that talent, but cannot add another choice, another hero tree or an out-of-target talent.

| Evidence artifact | Specs | Runtime rules |
| --- | --- | --- |
| [Demon Hunter and Druid priorities](sba-priorities-demonhunter-druid.json) | Havoc, Devourer, Guardian, Feral, Balance | 40 |
| [Death Knight, Hunter and Mage priorities](sba-priorities-dk-hunter-mage.json) | Frost Death Knight, Beast Mastery, Fire | 21: 20 researched weights plus the documented targeted-Flamestrike adaptation rule |
| [Monk and Priest priorities](sba-priorities-monk-priest.json) | Brewmaster, Shadow | 11 |
| [Blood user-target priorities](sba-priorities-blood-user.json) | Blood Death Knight, both supplied San'layn targets | 6 |

The artifacts retain spell identity, source URL, checked date, reasoning and limitations. The Demon Hunter/Druid identities were checked against Icy Veins' live Midnight calculator data, version 44. The other profiles use their recorded guide links and live talent definitions. These identity checks establish which talent a rule refers to; they do not establish its DPS value or its presence in every preserved import. In particular, the legacy Druid target payloads were not certified by adding priorities. Rules absent from the selected target do nothing.

Explicit per-rank orders take precedence over guide weights. Unweighted talents continue through a stable legal target path. Free granted talents are not purchased; hero currencies and level gates still apply. Apex talents can use distinct definitions at successive ranks, so a rule for the first entry does not silently score all later entries.

Regenerate the bundled Lua table with `python .scripts/generate-sba-priorities.py` after reviewing the four JSON artifacts. The generator rejects missing source links, unbounded scores, duplicate spell/spec records and missing build scopes. Runtime guidance only applies on its matching major/minor patch; the selected target also retains the exact client-build, tree-hash and import guards.

## Optional mismatch warning and explicit respec

The mismatch warning is opt-in and saved separately for each character and specialization. It compares the current learned allocation with the selected SBA target. Enabling it does not refund or change talents. A mismatch reports a difference from that target, not evidence that the player's build is bad, nonfunctional or worse for SBA. At lower levels, an unfinished target is also not a failed build assessment.

**RESPEC TO SBA** is the explicit replacement action: it resets purchased class, spec and hero talents for the current specialization, then follows the chosen target using the points available at the player's current level. It neither grants missing points nor changes specialization. The target remains subject to live compatibility, prerequisites, currency and commit checks. Additive **AUTO-SPEND** can continue as more points become available; it does not initiate a reset by itself.

This comparison measures allocation agreement, not gameplay quality. It does not evaluate encounter needs, gear, the player's manual cooldown use, defensive decisions, healing or current SBA simulation performance. There is no verified universal score that makes every mismatch a recommendation to respec.

## Catalog metadata and future extensions

New records implement source/date, `heroTree`, `contentType` and verification fields. The addon validates the live tree and client build when a target is selected and before spending. The offline audit did not run those client checks. Gameplay evidence and authored leveling orders remain outstanding; the additional fields below are proposed extensions.

| Field | Purpose |
| --- | --- |
| `classToken`, `specID`, `heroSubTreeID`, `contentType`, `playstyle` | Distinguish class/spec/hero variant, raid/AoE/leveling and pure SBA versus SBA with manual cooldowns. |
| `importString`, `treeID`, `treeHash`, `serializationVersion` | Exact target and compatibility evidence. Third-party exports may contain a zero hash, which is not validation. |
| `sourceURL`, `author`, `sourceUpdatedAt`, `checkedAt` | Trace the specific guide or Discord message, not a generic home page/invite. |
| `patch`, `testedClientBuild`, `catalogRevision` | Separate game compatibility from addon/content revision. Preserve the actual checked client build. |
| `verificationStatus`, `evidenceURL`, `assumptions` | Runtime statuses used here: `source-sba`, `source-compatible`, `source-talent`, `guide-adapted`, `guide-inferred`, `user-provided`, `legacy-unverified`. `source-talent` means a publisher supplied the WoW talent export, without evidence that SBA performs well with it. Inactive research uses `meta-candidate`. Simulated/gameplay-validated/stale statuses require corresponding evidence. Keep provenance separate from S/A/B ratings. |
| `levelingOrder`, `orderSourceURL`, `orderVerifiedAt` | Per-step `{nodeID, rank}` records, with explicit author priority and gates. Empty means no validated leveling order. |

### LazyGrip 12.1 snapshot (2026-09-24)

[LazyGrip](https://lazygrip.net/browse) publishes GRIP-EMS rotation sequences. Its `!GRIP1!` and `!EMS1!` strings are **not** Blizzard talent imports and are not consumed by BetterSBA. A separate **Talent build** field on some sequence pages contains a WoW talent export. The 12.1 snapshot reviewed 88 sitemap sequence pages, found 33 pages with that structured field, deduplicated four repeated talent codes, and excluded one page named Test Export. The resulting 28 distinct exports are bundled in `Core/LazyGripTalentBuildData.lua` with exact page URLs, class/spec headers, hero tree labels, and `source-talent` status. The live talent tree still validates an export when a player selects it; the website's patch label is not proof of in-game compatibility.

For example, [Slowdog's 12.1 Blood Death Knight page](https://lazygrip.net/sequences/slowdogs-bdk-v6-midnight-121-deathbringer-m-plus-tank-macro-msqkways) shows both a GRIP sequence and a separate Deathbringer talent export. Neither that sequence nor its talent export is described there as Blizzard SBA-specific. The [Kohtas Super SBA page](https://lazygrip.net/sequences/kohtas-enhancement-shaman-super-sba-mrud1kmn) explicitly discusses SBA but is labeled 12.0.7 and has no structured Talent build field; its author says the sequence works with varied talent builds. Across the reviewed pages, no 12.1 entry combined an explicit SBA claim with a structured talent export. Therefore no LazyGrip 12.1 entry is marked `source-sba` or ranked as an SBA meta build.

The six original built-in Druid records in `Core/TalentBuildData.lua` had blank patch/source URLs and no leveling order at the start of this research. Their existing letter ratings are not verification evidence. Retain their imports as attributed candidates without presenting them as current-patch, researched best builds.

## Validation and refresh process

1. On an addon/catalog update, review the source's actual revision and the client's patch/build/tree hash. Mark changed or unreviewed records stale; a changed page title must not silently refresh every build.
2. Acquire the exact import and validate it against the current spec and tree. Check both hero alternatives independently, or show an explicit coverage gap.
3. Compare candidates with the player's intended gear and content. [SimulationCraft's own documentation](https://github.com/simulationcraft/simc/wiki/ActionLists) provides `use_blizzard_action_list=1` and `one_button_mode=1`; `use_cds_with_blizzard_action_list=1` is a separate cooldown assumption. Pin the SimC revision and record targets, duration, gear and cooldown policy. Confirm spec support before trusting results.
4. Use gameplay checks for actual SBA behavior and for tank/healer utility and survivability; DPS simulation alone cannot certify those roles. Validate each spending step across level gates, rather than assuming endgame legality proves a leveling sequence.
5. Publish reviewed, versioned data with the addon or through an explicit user import. Show stale/missing coverage plainly. Do not silently replace a user's selected path when a source changes.

This is a recommended release-time workflow. No recurring monitor, subscription, Discord access or automatic source synchronization was configured by this research.

## Extraction and validation performed

Icy Veins' sitemap provided the 40 exact specialization URLs. Direct class-page HTTP requests were blocked by Cloudflare; the public web text reader exposed their guide content and the four dedicated code widgets. Raw calculator JavaScript was accessible, but was not needed or executed to obtain those codes. No browser was available to open the missing interactive widgets. Wowhead exports were obtained from publisher HTML by the parallel source audit.

The existing `.scripts/extract-icy-veins-sba-builds.js` had accepted every generic talent widget on any page mentioning Combat Assistant. It now requires an assistant-specific widget label before collection, and no longer invents an A rating for Icy Veins records. It was syntax-checked and its classifier checked against the actual dedicated and generic labels. Its remote crawler was not rerun through the Cloudflare block. Its Lua output remains extraction output for review, not a replacement for the merged catalog and preserved legacy entries.

`tests/test_talent_catalog.lua` validates unique IDs, export alphabet, serialization version, class/spec identity and provenance for all runtime records. Full node allocation compatibility and actual purchase behavior still require the addon/client checks; header validation alone is not enough. The extractor is explicitly included in this change; downloaded page caches and temporary research helpers are excluded.

The expansion pass fetched Wowhead's publisher HTML directly and extracted its marked copy-code widgets; Icy Veins' public guide text exposed the two Augmentation codes. All fourteen codes retain the publisher's bytes. The 22 user-provided imports similarly retain their supplied bytes. An offline decoder checked serialization version 2, the expected spec ID, purchased node identities, rank and choice encoding, and selected hero identity against Raidbots' live `talents.json`. The Devastation exports additionally encode one granted node (`98931`) outside that active-spec data view; this is recorded in the audit rather than treated as a purchased talent. These checks do not certify prerequisite legality, point budgets, nonzero client tree-hash matches or in-game behavior. The catalog header/spec check passed for all 51 entries.
