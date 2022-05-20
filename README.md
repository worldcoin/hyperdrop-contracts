# Universal Split

> A contract that splits any token it receives between all humans

A smart contract that allows any human to register itself as a claimer (using [World ID](https://id.worldcoin.org)), and can receive ERC-20 transfers. The received tokens are then split between all of the registered claimers.

## Technology

To make sure each human can only register one receiver account, we use Worldcoin's World ID protocol, which uses [the Semaphore library](http://semaphore.appliedzkp.org) to manage identity groups and verify zero-knowledge proofs.

## Usage

Since only members of a group can claim the airdrop, you'll need to add some entries to your Semaphore group first. End-users will need to generate an identity commitment (which can be done through the [@zk-kit/identity](https://github.com/appliedzkp/zk-kit/tree/main/packages/identity) or [semaphore-rs](https://github.com/worldcoin/semaphore-rs) SDKs). Once they have one, you can add it to the group by calling `Semaphore.addMember(YOUR_GROUP_ID, IDENTITY_COMMITMENT)`.

Once users have identities included on the configured group, they should generate a nullifier hash and a proof for it (which can be done through the [@zk-kit/protocols](https://github.com/appliedzkp/zk-kit/tree/main/packages/protocols) or [semaphore-rs](https://github.com/worldcoin/semaphore-rs) SDKs, using the address who will receive the tokens as the signal). Once they have both, they can register as claimers calling `WLDSplit.register(RECEIVER_ADDRESS, SEMAPHORE_ROOT, NULLIFIER_HASH, SOLIDITY_ENCODED_PROOF)`.

After registering, anyone can call the claim function specified a registered wallet and the address of a token the contract holds to receive their proportional share, like so `WLDSplit.claim(RECEIVER_ADDRESS, TOKEN_ADDRESS)`. A `getOutstandingFor` view function is also provided for convenience.

## Deployment

First, you'll need a contract that adheres to the [ISemaphore](https://github.com/worldcoin/world-id-example-airdrop/blob/main/src/interfaces/ISemaphore.sol) interface to manage the zero-knowledge groups. If you don't have any special requirements, you can use [this one](https://github.com/worldcoin/world-id-example-airdrop/blob/main/src/Semaphore.sol). Next, you'll need to create a Semaphore group (`Semaphore.createGroup(YOUR_GROUP_ID, 20, 0)` should do the trick). Finally, deploy the `SemaphoreAirdrop` contract with the Semaphore contract address, and the group id.

## Usage with Worldcoin

Right now, Worldcoin maintains a staging Semaphore instance instance (for use with our [mock app](https://mock-app.id.worldcoin.org) and its faucet) on Polygon Mumbai. The address is `0x330C8452C879506f313D1565702560435b0fee4C`, and the group ID is `1`. A production instance will be deployed soon.

## Development

This repository uses the [Foundry](https://github.com/gakonst/foundry) smart contract toolkit. You can download the Foundry installer by running `curl -L https://foundry.paradigm.xyz | bash`, and then install the latest version by running `foundryup` on a new terminal window (additional instructions are available [on the Foundry repo](https://github.com/gakonst/foundry#installation)). You'll also need [Node.js](https://nodejs.org) if you're planning to run the automated tests.

Once you have everything installed, you can run `make` from the base directory to install all dependencies, build the smart contracts, and configure the Poseidon Solidity library.

## License

This project is open-sourced software licensed under the MIT license. See the [License file](LICENSE) for more information.
