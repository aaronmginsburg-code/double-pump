# Publishing Double Pump

Nothing here has been done for you. Publishing publicly and turning on Robux sales are
your calls; the code ships with sales **off** and no product IDs.

## Before you publish

- [ ] Shotgun imported, sounds and map art uploaded (`docs/ASSET_PIPELINE.md`). Check the
      Studio output has no "Shotgun asset not found" or "missing sound IDs" warnings.
- [ ] `lune run tests/run.luau` passes.
- [ ] A Studio playtest with **Test > Clients and Servers > 2 players** (or more) runs a
      full match: countdown, kills, results, map vote, next map. Use `docs/PLAYTEST.md`.
- [ ] A private test with real people on real devices (PC, phone, controller).
- [ ] `GameConfig.Debug` flags are all `false`.

## 1. First publish (private)

1. **File > Publish to Roblox As...** > **Create new experience**. Name it
   "Double Pump", pick the genre (Shooter / FPS) and the owner (you or your group).
2. **Home > Game Settings**:
   - **Basic Info**: description, icon (512×512) and thumbnails. The map renders in
     `docs/images/maps/` are renders, not gameplay screenshots; take real screenshots in
     Studio once the shotgun is imported if you want gameplay thumbnails.
   - **Permissions > Playability**: **Private** for now.
   - **Places > (the start place) > Max Players: 10**. Server fill: *Roblox optimised*.
   - **Avatar**: Avatar type R15, Animation *Standard* is fine (the game draws its own
     first-person arms and gun).
   - **Security > Enable Studio Access to API Services**: on (for testing saves).
3. Fill in the **Experience Questionnaire** (Creator Dashboard > your experience >
   Audience > Maturity & Compliance). Double Pump is cartoon shooting with no blood,
   which usually rates as *Mild violence*. Answer it honestly for your final build.

## 2. Private testing

Add testers under **Collaborators** or switch Playability to **Friends** while you test.
Fill in `docs/PLAYTEST.md` from those sessions.

## 3. Robux coin packs (only when you decide to sell)

The shop sells skins for **coins**, which players earn by playing. Coin packs for Robux are
optional and off. To turn them on:

1. Creator Dashboard > your experience > **Monetization > Developer Products > Create**.
   Create one product per pack in `src/shared/Config/Products.luau`:

   | key | Suggested name | Coins |
   |---|---|---|
   | Coins500 | Pocket of Shells | 500 |
   | Coins1200 | Bandolier | 1200 |
   | Coins3000 | Ammo Crate | 3000 |

   You set the Robux price; the code never reads it.
2. Copy each product's **ID** into its `productId` in `Products.luau`.
3. Set `Products.Enabled = true` and publish.
4. Test with a purchase in Studio (Studio purchases are free test purchases), then check
   the coins arrive and that rejoining doesn't grant them again.

How it's handled: the server grants coins inside `ProcessReceipt`, records the receipt ID
in the player's save, saves, and only then tells Roblox the purchase is done. If the save
fails the coins are taken back and Roblox retries later, so a purchase is never lost or
granted twice. Unknown product IDs are left unprocessed.

## 4. Going public

When you're happy: **Game Settings > Permissions > Public**, then publish. After launch,
watch **Creator Dashboard > Analytics** (retention, session length) and the error report
(**Analytics > Errors**) for script errors from live servers.

## Changing things later

- Balance numbers: `src/shared/Config/WeaponConfig.luau` and `GameConfig.luau`.
- XP and coin rewards: `src/shared/Progression/Levels.luau`.
- Skins and prices: `src/shared/Progression/Cosmetics.luau`.
- Changing the shape of save data: bump the profile version in
  `src/shared/Progression/Profile.luau` and add a migration there. Don't rename the
  DataStore (`DoublePump_Profiles_v1`) unless you mean to wipe everyone's progress.
