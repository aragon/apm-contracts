pragma solidity ^0.4.11;


contract Ownable {
  address public owner;
  modifier onlyOwner {
    require(msg.sender == owner || owner == 0);
    _;
  }
  function transferOwnership(address newOwner) onlyOwner {
    owner = newOwner;
  }
}

// 0x80836585c10c1595f2d5411727c0ab89aad5cdb3

contract AbstractENS {
  function owner(bytes32 node) constant returns(address);
  function resolver(bytes32 node) constant returns(address);
  function ttl(bytes32 node) constant returns(uint64);
  function setOwner(bytes32 node, address owner);
  function setSubnodeOwner(bytes32 node, bytes32 label, address owner);
  function setResolver(bytes32 node, address resolver);
  function setTTL(bytes32 node, uint64 ttl);

  // Logged when the owner of a node assigns a new owner to a subnode.
  event NewOwner(bytes32 indexed node, bytes32 indexed label, address owner);

  // Logged when the owner of a node transfers ownership to a new account.
  event Transfer(bytes32 indexed node, address owner);

  // Logged when the resolver for a node changes.
  event NewResolver(bytes32 indexed node, address resolver);

  // Logged when the TTL of a node changes
  event NewTTL(bytes32 indexed node, uint64 ttl);
}


contract Constants {
  bytes32 constant public ROOT_NODE = sha3(sha3(bytes32(0), sha3('test')), sha3('aragonpm'));
  AbstractENS constant ens = AbstractENS(0x80836585c10c1595f2d5411727c0ab89aad5cdb3); // kovan ens
}

contract Repo is Constants, Ownable {
  struct Version {
    uint16[3] semanticVersion;
    uint16 locationId;
    bytes contentHash;
  }

  Version[] versions;

  bytes32 rootNode = sha3(ROOT_NODE, sha3('ownership'));
  mapping (bytes32 => uint) versionForNode;

  event NewVersion(bytes32);

  function newVersion(uint16[3] _newSemanticVersion, uint16 _locationId, bytes _contentHash) onlyOwner {
    require(versions.length == 0 || isValidBump(versions[versions.length - 1].semanticVersion, _newSemanticVersion));
    if (versions.length == 0) {
      versions.length += 1;
    }
    uint versionId = versions.push(Version(_newSemanticVersion, _locationId, _contentHash)) - 1;

    registerVersion(versionId, _newSemanticVersion);
  }

  function registerVersion(uint versionId, uint16[3] semanticVersion) internal returns (bytes32, bytes32) {
    bytes32 majorLabel = sha3(uintToString(semanticVersion[0]));
    bytes32 majorNode = sha3(rootNode, majorLabel);

    bytes32 minorLabel = sha3(uintToString(semanticVersion[1]));
    bytes32 minorNode = sha3(majorNode, minorLabel);

    bytes32 patchLabel = sha3(uintToString(semanticVersion[2]));
    bytes32 patchNode = sha3(minorNode, patchLabel);

    if (versionForNode[majorNode] == 0) {
      ens.setSubnodeOwner(rootNode, majorLabel, address(this));
      ens.setResolver(majorNode, address(this));
    }

    if (versionForNode[minorNode] == 0) {
      ens.setSubnodeOwner(majorNode, minorLabel, address(this));
      ens.setResolver(minorNode, address(this));
    }

    if (versionForNode[patchNode] == 0) {
      ens.setSubnodeOwner(minorNode, patchLabel, address(this));
      ens.setResolver(patchNode, address(this));
    }

    versionForNode[rootNode] = versionId;
    versionForNode[majorNode] = versionId;
    versionForNode[minorNode] = versionId;
    versionForNode[patchNode] = versionId;
  }

  function content(bytes32 node) constant returns (uint16, bytes) {
    Version version = versions[versionForNode[node]];
    return (version.locationId, version.contentHash);
  }

  function isValidBump(uint16[3] oldVersion, uint16[3] newVersion) constant returns (bool) {
    bool hasBumped;
    uint i = 0;
    while (i < 3) {
      if (hasBumped) {
        if (newVersion[i] != 0) return false;
        } else if (newVersion[i] != oldVersion[i]) {
          if (newVersion[i] - oldVersion[i] != 1) return false;
          hasBumped = true;
        }
        i++;
      }
    return hasBumped;
  }

  function getVersionId(uint16[3] semanticVersion) constant returns (uint) {
    return versionForNode[getVersionNode(semanticVersion)];
  }

  function getVersionNode(uint16[3] semanticVersion) constant returns (bytes32) {
    return sha3(sha3(sha3(rootNode, sha3(uintToString(semanticVersion[0]))), sha3(uintToString(semanticVersion[1]))), sha3(uintToString(semanticVersion[2])));
  }

  function uintToString(uint v) constant returns (string str) {
    uint maxlength = 6;
    bytes memory reversed = new bytes(maxlength);
    uint i = 0;
    if (v == 0) return '0';
    while (v != 0) {
      uint remainder = v % 10;
      v = v / 10;
      reversed[i++] = byte(48 + remainder);
    }

    bytes memory s = new bytes(i);
    for (uint j = 0; j <= i; j++) {
      if (j > 0 && reversed[i] == 0) s[j - 1] = reversed[i - j];
    }
    str = string(s);
  }

  function setRootNode(bytes32 _newRootNode) onlyOwner {
    rootNode = _newRootNode;
    ens.setResolver(rootNode, address(this));
  }
}

contract ForwarderFactory {
  function createForwarder(address target) returns (address fwdContract) {
    bytes32 b1 = 0x602e600c600039602e6000f33660006000376101006000366000730000000000; // length 27 bytes = 1b
    bytes32 b2 = 0x5af41558576101006000f3000000000000000000000000000000000000000000; // length 11 bytes

    uint256 shiftedAddress = uint256(target) * ((2 ** 8) ** 12);   // Shift address 12 bytes to the left

    assembly {
      let contractCode := mload(0x40)                 // Find empty storage location using "free memory pointer"
      mstore(contractCode, b1)                        // We add the first part of the bytecode
      mstore(add(contractCode, 0x1b), shiftedAddress) // Add target address
      mstore(add(contractCode, 0x2f), b2)             // Final part of bytecode
      fwdContract := create(0, contractCode, 0x3A)    // total length 58 dec = 3a
      jumpi(invalidJumpLabel, iszero(extcodesize(fwdContract)))
    }

    ForwarderDeployed(fwdContract, target);
  }

  event ForwarderDeployed(address forwarderAddress, address targetContract);
}

// at 0xb3b2222ada396cf05e7a5c6944762a96f4c2d1bc
contract VersionedReposRegistry is Constants {
  mapping (bytes32 => address) registeredRepos;
  address masterRepo;
  ForwarderFactory forwarderFactory;

  function VersionedReposRegistry() {
    masterRepo = new Repo();
    forwarderFactory = new ForwarderFactory();
  }

  function newRepo(bytes32 label) returns (address) {
    require(registeredRepos[label] == 0);

    Repo repo = newClonedRepo();

    ens.setSubnodeOwner(ROOT_NODE, label, address(repo));
    repo.setRootNode(sha3(ROOT_NODE, label));
    repo.transferOwnership(msg.sender);

    registeredRepos[label] = address(repo);
    return address(repo);
  }

  function newClonedRepo() returns (Repo) {
    return Repo(forwarderFactory.createForwarder(masterRepo));
  }

  function requestOwnership() {
    ens.setOwner(ROOT_NODE, msg.sender);
  }
}
