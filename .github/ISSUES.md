# Open Issues derived from TODO list

This file tracks the outstanding TODO items requested for follow-up. Create real GitHub issues mirroring each entry when syncing with the hosted repo.

1. **NapierCollectFuse validation** – ensure the error path distinguishes invalid principal tokens from market IDs and aligns with substrate checks.
2. **NapierCombineFuse safety** – reorder cheap checks, require tokenOut substrates, and guard balance delta calculations against underflow.
3. **NapierRedeemFuse routing** – validate tokenOut as a substrate and decide on deadline-aware router execution where appropriate.
4. **NapierSupplyFuse substrates** – verify router/external addresses are granted as substrates and protect balance delta arithmetic from underflow.
5. **NapierSwapPtFuse slippage guards** – enforce minimum-out parameters, add underflow protections, and validate all swap assets and routers as substrates.
6. **NapierSwapYtFuse approvals** – reset Permit2 approvals after execution, add underflow checks, and validate swap assets/routers as substrates with min-out handling.
7. **PT/YT balance symmetry review** – confirm vault invariants when combining PT and YT assume equal balances or document constraints.
8. **IporFusionMarkets Napier constant** – revisit the chosen Napier market ID and align it with sequencing guidance.
9. **NapierPriceFeed decimals/middleware** – settle on 18-decimal outputs and middleware-driven QUOTE sourcing per vault policy.
10. **Napier README coverage** – add or refine the Napier fuse overview documentation in `contracts/fuses/napier/`.
11. **File header/comments hygiene** – ensure consistent file headers and inline rationale/comments across modified files.
