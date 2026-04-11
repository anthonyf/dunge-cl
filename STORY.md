# Dunge — Story & Progression

This is a design reference for the story and narrative progression of Dunge. It sits alongside [DESIGN.md](DESIGN.md) (mechanics) and describes what the game is *about*, not how it works. Subject to revision as ideas develop.

## Premise

The player is a travelling adventurer — a mercenary for hire — who arrives in a small town that has recently begun to suffer attacks from a dragon named **Dunge**. The dragon descends periodically to kill livestock and anyone who stands in his way. The town has posted a bounty on his head, but any adventurer who has seen him understands that confronting him directly would be suicide without preparation.

The player uses the town as a base, taking smaller bounties from the adventurer's guild to earn gold, recover useful items, and buy magical equipment. Over time they prepare for the final confrontation — or, depending on what they uncover along the way, a different resolution.

## Setting & Tone

- **Scope:** The game takes place in and around a single town. All civilian interaction happens here.
- **Genre:** Folkloric fantasy — closer to Grimm or Slavic folk tale than high fantasy or modern grimdark. The world has old pacts, named monsters, and the weight of tradition.
- **Tone:** Serious about danger without being bleak. Travellers die in dungeons. Shops close when families are killed. The temple really does heal you, and it really does matter that it can. Not relentless grimness, but not safe either.

## The Town

The town is authored content — hand-written rooms, NPCs, and shops that the player returns to between adventures. Planned locations:

- **Adventurer's Guild** — bounty board (3 active bounties at a time, rotating), companion hiring
- **Inn** — rest, rumors, meet NPCs, overhear story beats
- **Blacksmith** — weapons, armor, repairs
- **General Merchant** — consumables, light sources, provisions, rations
- **Temple** — healing and restoration from the local god
- **Mayor's Mansion** — gated meetings, key story progression, the dragon briefing

Locations and their proprietors should feel like people the player comes to know over many visits. A shop closing or an NPC dying should be noticeable.

## Overarching Goal

Resolve the threat of **Dunge**, the dragon. In the default path, this means slaying him. An alternate resolution may also exist — see [Endings](#endings).

## The Central Twist

The dragon is not acting out of malice.

Generations ago, the town's founders made an **ancient pact** with Dunge. He agreed to slumber beneath the mountain and leave the region in peace. In exchange, they were made custodians of his regalia — scales, bones, a crown, gemstones from his hoard — ceremonial tokens that sealed the pact. The regalia was never the town's property. They were trusted with it.

Over generations the truth faded into myth. A greedy mayor sold pieces. Another was buried with a gem. Bandits raided the vault. Priests repurposed a scale as a temple relic. By the time Dunge woke and came looking, his regalia was scattered across the region — in dungeons, ruins, forgotten cellars, and the hoards of other creatures.

He isn't attacking the town to terrorize it. He's trying to recover what was stolen, and killing anyone who stands between him and it.

### The Mayor's Role

The mayor knows, or at least knows more than he admits. He inherited the lie rather than committing the original sin — he is a tragic figure, not a villain. He is trying to protect a town built on a broken pact, and he is willing to hire strangers (who can disappear without being missed) to recover regalia and return it to him, hoping to placate the dragon or simply hide the evidence.

His exact personal stance — true believer, trapped by duty, or quietly complicit — is an [open question](#open-questions).

### Previous Adventurers

The player is not the first. Successive mayors have been hiring adventurers to recover regalia for generations, never telling them why. Most did not return. Their remains — and their journals — are scattered through the dungeons the player now explores, providing the primary channel through which the truth gradually surfaces.

## Progression Arc

A typical run:

1. **Arrival** — The player enters the town, sees the damage, hears rumors at the inn, visits the adventurer's guild.
2. **Bounty loop** — The player selects bounties from the board. Each bounty leads to an authored "start" (forest, cellar, dungeon, ruin) that transitions into procedurally generated content. Rewards include gold, items, and — occasionally — pieces of Dunge's regalia or remains of previous adventurers.
3. **Milestone beats** — Certain quests, artifact recoveries, and journal fragments unlock scripted story beats that slowly reveal the truth.
4. **Mayor's gate** — Before the dragon can be confronted, the player must get the mayor's blessing. At lower levels the mayor laughs them off. At higher levels he takes them seriously. If the player has uncovered enough of the truth, the meeting plays out differently.
5. **The confrontation** — The final encounter with Dunge. The shape of this encounter depends on what the player has recovered and learned.

### Authored vs. Emergent

- **Authored:** The town, all NPCs, shops, bounty premises, mayor meetings, all milestone beats, the dragon confrontation, the journals of previous adventurers.
- **Emergent:** The interior of each dungeon / forest / cellar (room generation, random encounters, treasure), the order in which the player tackles bounties, which regalia pieces they find first.

This keeps story beats reliable while letting moment-to-moment gameplay stay surprising.

## Milestones & Turning Points

- **First real win** — The player completes their first bounty and is taken seriously by the guild.
- **The first journal** — The player finds the remains of a previous adventurer in a dungeon. Their journal hints that something is off about the mayor or the town's story.
- **First regalia recovery** — The player recovers a piece of Dunge's regalia (they don't know what it is yet) and the mayor is unusually interested in acquiring it.
- **The pattern** — Further journals and artifacts reveal that previous adventurers were hired by earlier mayors for the same reason, and most did not return.
- **The truth** — At some threshold, the player learns the full story of the pact. This is a scripted reveal tied to a specific journal or artifact.
- **Mayor's blessing** — Gated on level and gear, not on knowing the truth. The player can get his blessing and march to their death without ever understanding why the dragon is angry.
- **Rescues and minor bounties** — Smaller reward quests that build relationships with townspeople and shift how the town responds to the player.

## Reveal Pacing

The truth is revealed through two complementary channels:

- **Artifacts.** Each piece of regalia recovered carries a fragment of lore. On the first piece, the player might just notice the mayor's unusual interest. By the third or fourth, they can start to piece together what these objects really are.
- **Journals & remains.** Previous adventurers died in the dungeons the player now explores. Their journals, carried on their remains, tell what they knew at the end — some were loyal to the mayor, some had started to suspect, some died with the truth in hand. These are authored fragments seeded into procgen dungeons.

The goal is for the player to feel like they are assembling the truth themselves, across multiple adventures, rather than being handed it in a single cutscene.

## Endings

- **Slay Dunge** *(primary)* — The pact ends with the dragon. The town survives, but whatever the pact held back (to be decided) is no longer being kept at bay. The player is hailed as a hero. The truth dies with the dragon, unless the player chose to expose it.
- **Alternate resolution** *(open question)* — There should be a path for a player who has learned the truth to resolve the conflict without slaying Dunge. Mechanically, this does not require new systems: the final encounter can branch at the top, with the "return the regalia" path playing out as a scripted choice sequence rather than a call into combat. The shape and consequences of this ending are still to be decided.
- **Death** — The player dies in combat and has no fate points remaining. Run ends.

## Open Questions

These are deliberately unresolved and should be decided as the game develops.

1. **What did the town receive from the pact?** Just "not being eaten by Dunge," or something more — fertile land, protection from worse things in the dark, a blessed well? Something richer gives the *slay Dunge* ending a real cost (the town survives the dragon but loses the pact's boon). Simplest answer is just peace.
2. **Alternate ending shape.** What does resolving the conflict without combat actually look like? A full dialogue scene? A ritual at the mountain? Does Dunge accept and depart, or accept and stay as a sleeping guardian?
3. **The mayor's personal stance.** True believer in the lie, knowingly trapped by duty, or quietly complicit? Changes his dialogue and his arc significantly.
4. **The mayor's fate.** Does he have his own arc — confession, death, exile — or does he remain a constant background presence regardless of what the player uncovers?
5. **What else the pact held back.** Tied to #1. If the pact gave the town more than peace, what exactly, and how does its absence affect the world after *slay Dunge*?
6. **Tone of previous-adventurer journals.** How bleak do these get? Are they mostly cautionary notes, or do some become genuinely tragic (families back home, last words)?
