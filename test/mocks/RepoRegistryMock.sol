pragma solidity ^0.4.15;

import "../../contracts/RepoRegistry.sol";

contract RepoRegistryMock is RepoRegistry {
    function RepoRegistryMock(AbstractENS _ens, bytes32 _rootNode)
             RepoRegistry(_ens, _rootNode, 0, ForwarderFactory(0)) {}

    // Forwarder contracts created by ForwarderFactory don't work in testrpc.
    // For testing we create a vanilla instance of the repo
    function newClonedRepo() internal returns (Repo) {
        return new Repo();
    }
}
