pragma solidity ^0.4.11;

contract Ownable {
    modifier onlyOwner {_;}
    function transferOwnership(address newOwner) {}
}

contract AbstractENS {
    function owner(bytes32 node) constant returns(address);
    function resolver(bytes32 node) constant returns(address);
    function ttl(bytes32 node) constant returns(uint64);
    function setOwner(bytes32 node, address owner);
    function setSubnodeOwner(bytes32 node, bytes32 label, address owner);
    function setResolver(bytes32 node, address resolver);
    function setTTL(bytes32 node, uint64 ttl);
}

contract Repo is Ownable {
    struct Version {
        uint32 semanticVersion;
        bytes32 frontendIPFSHash; // is it bytes32?
        address contractApplicationFactory;
    }

    mapping (uint32 => uint256) public versionIdBySemanticVersion;
    uint32 public lastVersion;
    Version[] versions;
}

contract VersioningProtocol {
    bytes32 constant public ROOT_NODE = sha3(sha3(bytes32(0), sha3('test')), sha3('aragonpm'));
    AbstractENS constant ens = AbstractENS(0x112234455C3a32FD11230C42E7Bccd4A84e02010); // testnet

    mapping (bytes32 => address) registeredRepos;

    function newRepo(bytes32 label) returns (address) {
        require(registeredRepos[label] == 0);

        Repo repo = new Repo();
        repo.transferOwnership(msg.sender);
        ens.setSubnodeOwner(ROOT_NODE, label, address(repo));
        ens.setResolver(sha3(ROOT_NODE, label), address(repo));

        registeredRepos[label] = address(repo);
        return address(repo);
    }
}
