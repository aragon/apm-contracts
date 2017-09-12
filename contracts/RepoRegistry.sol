pragma solidity ^0.4.11;

import "./AbstractENS.sol";
import "./Ownable.sol";
import "./Repo.sol";
import "./ForwarderFactory.sol";

contract Constants {
    AbstractENS constant ens = AbstractENS(0xbeefbeefbeefbeefbeefbeefbeefbeefbeefbeef); // replace on bytecode
}

contract RepoRegistry is Constants, AddrResolver, Ownable {
    bytes32 public rootNode;
    mapping (bytes32 => address) public registeredRepos;

    address private masterRepo;
    ForwarderFactory private forwarderFactory;

    event NewRepo(string name, address repo);

    function VersionedReposRegistry(bytes32 _rootNode) {
        masterRepo = new Repo();
        forwarderFactory = new ForwarderFactory();
        rootNode = _rootNode;
    }

    function newRepo(string name) returns (address) {
        bytes32 label = sha3(name);
        bytes32 node = sha3(rootNode, label);
        require(registeredRepos[node] == 0);

        Repo repo = newClonedRepo();
        registeredRepos[node] = address(repo);

        ens.setSubnodeOwner(rootNode, label, address(this));
        ens.setResolver(node, address(this));
        repo.transferOwnership(msg.sender);

        NewRepo(name, repo);

        return address(repo);
    }

    function addr(bytes32 node) constant returns (address) {
        return registeredRepos[node];
    }

    function newClonedRepo() returns (Repo) {
        return Repo(forwarderFactory.createForwarder(masterRepo));
    }

    function setRootOwner(address _newOwner) onlyOwner {
        ens.setOwner(rootNode, _newOwner);
    }
}
