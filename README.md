# Aragon Package Manager

The Aragon Package Manager allows for management and discoverability of applications to be run in the context of AragonOS organizations.

Its main goals are:

- Being able to find packages with human-readable names.
- Update publishing in a secure way. Leveraging Ethereum accounts for authentication, allows to use complex governance mechanisms to push updates.
- Finding the client-side counterparty to a smart contract. If a smart contract exposes a reference to the package (`appId` concept in AragonOS), the Package Manager can be used to look-up for the dApp frontend code for that version of the smart contract.

### Repo Registry

The Repo registry is a contract that allows the creation of new repos. The repo registry gives every package a ENS subdomain for discoverability.

It is initialized with a ENS name root that the Repo Registry must be the owner of, so it can create and assign subdomains. The Repo Registry Aragon deploy will use the `aragonpm.eth` name root, so all packages registered will be in the form of `test.aragonpm.eth`.

The repo registry also implements the ENS resolver interface for address types for registered repos, so no further setup is required.

### Repo

Repos are the core concept of the package manager. A repo is versioned using [Semantic Versioning](http://semver.org).

Before creating a version, the repo contract checks:

- The new version is being created by the repo owner. The repo owner is an Ethereum address, so it can be anything from a simple private key to a full DAO. The repo owner can transfer ownership to another address.

- The version bump is valid. Only one element can be increased by one, more significant members are kept the same and less significant elements are set to 0. Example: from 0.1.0 the only valid version bumps are to: 0.1.1, 0.2.0, 1.0.0.

- Updates to the smart contract code address are only permitted on major versions. Even if it doesn't introduce breaking changes to the API, updating smart contract code always requires user interaction as it must be done carefully.

A repo version updates two values:

- **Contract address**: Deployed instance of the smart contract component of the package. Can only be changed on major version releases. Changes are only allowed on major versions.

- **Content URI**: Location of the full package to be loaded client-side. The content URI can point to different types of storage locations. Content addressable storage is preferred, so once a version has been saved in the Repo, the content behind it cannot change without creating a new version. For an initial implementation we will support:

 - **IPFS**: ipfs:QmPXME1oRtoT627YKaDPDQ3PwA8tdP9rWuAAweLzqSwAWT
 - (Adding more for v0.5?)

A repo contract can be queried in multiple ways:

- `repo.getLatest()`: will return the latest version created in the repo.
- `repo.getLatestForContractAddress(address c)`: will return the last version of the package that used that particular contract address.
- `repo.getBySemanticVersion(uint16[3] v)`: will return the package for that particular semantic version.
- `repo.getByVersionId(uint256 n)`: will return the `n`th created version.

The return value for all queries is:

- semanticVersion `uint16[3]`
- contractAddress `address`
- contentURI `bytes`
