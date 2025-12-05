# Napier fuses

This folder contains the Plasma Vault fuses that integrate with Napier v2 via the universal router.

## Components
- **Supply/Redeem/Collect**: mint, redeem, and collect yield from principal and yield tokens.
- **Combine**: merge PT and YT back into the underlying or asset using the router.
- **Swap PT / Swap YT**: perform router-powered swaps between underlying, PT, and YT.

## Safety expectations
- Every external address (router, PT/YT, pools, Permit2, tokenOut/tokenIn) must be granted as a substrate on the `NAPIER` market.
- Router calls use explicit deadlines and minimum-out checks; balance deltas are validated to avoid underflows.
- Permit2 approvals are scoped per-call and cleared after execution for YT swaps.

## Configuration notes
- Add the Napier market (`IporFusionMarkets.NAPIER`) with substrates for the pool, PT, YT, underlying/asset tokens, router, and Permit2.
- Ensure the price oracle middleware is configured with a USD source for the pricing asset referenced by the Toki oracle.
