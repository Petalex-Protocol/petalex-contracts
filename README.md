# Petalex Contracts

![Main](https://github.com/hmmdeif/petalex/actions/workflows/test.yml/badge.svg)

## Build

`forge build`

## Test

As this is an integration, fork tests are the only tests that are important.

`forge test`

## Deploy

Uses env vars from a file `.env`. Copy and rename `.env.sample` and fill in the required variables.

```
# To load the variables in the .env file
source .env

# To deploy and verify our contract
forge script script/PetalexInitial.s.sol:DeployPetalexInitial --rpc-url $RPC_URL --broadcast -vvvv --slow
```

## Troubleshooting

#### Test contracts are too large

You need to update foundry to a later build. This error is suppressed in later versions for test contracts.

#### Deploy script transaction failures

`--slow` is necessary to stop all tx being sent and being mined out of order.