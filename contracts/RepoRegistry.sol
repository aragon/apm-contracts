pragma solidity ^0.4.11;

import "./AbstractENS.sol";
import "./Ownable.sol";
import "./Repo.sol";
import "./ForwarderFactory.sol";

contract RepoRegistry is AddrResolver, Ownable {
    AbstractENS ens;
    bytes32 public rootNode;
    mapping (bytes32 => address) public registeredRepos;

    address private masterRepo;
    ForwarderFactory private forwarderFactory;

    event NewRepo(bytes32 id, string name, address repo);

    function RepoRegistry(AbstractENS _ens, bytes32 _rootNode, address _masterRepo, ForwarderFactory _forwarderFactory) {
        rootNode = _rootNode;
        ens = _ens;
        masterRepo = _masterRepo;
        forwarderFactory = _forwarderFactory;
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

        NewRepo(node, name, repo);

        return address(repo);
    }

    /**
    * @dev After changing ownership of name, RepoRegistry will fail to create new records
    */
    function setRootOwner(address _newOwner) onlyOwner {
        ens.setOwner(rootNode, _newOwner);
    }

    function addr(bytes32 node) constant returns (address) {
        return registeredRepos[node];
    }

    function newClonedRepo() internal returns (Repo) {
        return Repo(forwarderFactory.createForwarder(masterRepo));
    }
}
