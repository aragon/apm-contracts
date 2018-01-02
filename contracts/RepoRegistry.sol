pragma solidity ^0.4.11;

import "@aragon/core/contracts/apps/App.sol";
import "@aragon/core/contracts/common/Initializable.sol";

import "./AbstractENS.sol";
import "./Repo.sol";
import "./ForwarderFactory.sol";

contract RepoRegistry is AddrResolver, App, Initializable {
    AbstractENS ens;
    bytes32 public rootNode;
    mapping (bytes32 => address) public registeredRepos;

    ForwarderFactory private repoFactory;

    bytes32 public constant CREATE_REPO_ROLE = bytes32(1);
    bytes32 public constant SET_ROOT_OWNER_ROLE = bytes32(2);

    event NewRepo(bytes32 id, string name, address repo);

    /**
    * @dev In order to function correctly, Registry must be set as the owner of the rootNode record in the ENS
    * @param _ens Reference to the ENS Registry
    * @param _rootNode ENS namehash where the registry is running. Example: namehash("aragonpm.eth")
    * @param _repoFactory Forwarder factory instance that deploys forwarders to Repo contracts
    */
    function initialize(
        AbstractENS _ens,
        bytes32 _rootNode,
        ForwarderFactory _repoFactory
    ) onlyInit public {
        rootNode = _rootNode;
        ens = _ens;
        repoFactory = _repoFactory;
    }

    /**
    * @notice Create new repo in registry with `_name`
    * @param _name Repo name
    */
    function newRepo(string _name) public auth(CREATE_REPO_ROLE) returns (address) {
        Repo repo = _newRepo(_name);
        return address(repo);
    }

    /**
    * @notice Create new repo in registry with `_name` and first repo version
    * @param _name Repo name
    * @param _initialSemanticVersion Semantic version for new repo version
    * @param _contractAddress address for smart contract logic for version (if set to 0, it uses last versions' contractAddress)
    * @param _contentURI External URI for fetching new version's content
    */
    function newRepoWithVersion(
        string _name,
        uint16[3] _initialSemanticVersion,
        address _contractAddress,
        bytes _contentURI
    ) public auth(CREATE_REPO_ROLE) returns (address) {
        Repo repo = _newRepo(_name);
        repo.newVersion(_initialSemanticVersion, _contractAddress, _contentURI);
        return address(repo);
    }

    /**
    * @dev After receiving ownership of rootnode, this can be called to set contract as
    *      resolver for rootnode, resulting in rootnode resolving to the RepoRegistry address
    */
    function setResolver() public {
        ens.setResolver(rootNode, address(this));
    }

    /**
    * @dev Transfers rootNode ownership (used for migrating to another Registry)
    *      After changing ownership of name, RepoRegistry will fail to create new records
    */
    function setRootOwner(address _newOwner) public auth(SET_ROOT_OWNER_ROLE) {
        ens.setOwner(rootNode, _newOwner);
    }

    /**
    * @dev Conformance to ENS AddrResolver
    * @param node ENS namehash for name
    */
    function addr(bytes32 node) constant returns (address) {
        // Resolve to RepoRegistry if asked for root node, otherwise return repo address if exists
        return node == rootNode ? address(this) : registeredRepos[node];
    }

    function _newRepo(string _name) internal returns (Repo) {
        bytes32 label = sha3(_name);
        bytes32 node = sha3(rootNode, label);
        require(registeredRepos[node] == 0);

        Repo repo = newClonedRepo();
        registeredRepos[node] = address(repo);

        // Creates [name] subdomain in the rootNode and sets registry as resolver
        ens.setSubnodeOwner(rootNode, label, address(this));
        ens.setResolver(node, address(this));

        NewRepo(node, _name, repo);

        return repo;
    }

    function newClonedRepo() internal returns (Repo) {
        return Repo(repoFactory.createForwarder());
    }
}
