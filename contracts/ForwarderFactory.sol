pragma solidity ^0.4.15;

import "@aragon/core/contracts/common/DelegateProxy.sol";

contract ForwarderFactory {
    event Deployed(address forwarder);

    function createForwarder() returns (address forwarder) {
        forwarder = address(new Forwarder());
        Deployed(forwarder);
    }
}

contract Forwarder is DelegateProxy {
    // After compiling contract, `beefbeef...` is replaced in the bytecode by the real target address
    address constant target = 0xBEeFbeefbEefbeEFbeEfbEEfBEeFbeEfBeEfBeef; // checksumed to silence warning

    /*
    * @dev Forwards all calls to target
    */
    function () payable {
        delegatedFwd(target, msg.data);
    }
}
