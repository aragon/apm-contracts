pragma solidity ^0.4.15;

contract DelegateProxy {
    bool constant IS_BYZANTIUM = false;
    /**
    * @dev Performs a delegatecall and returns whatever the delegatecall returned (entire context execution will return!)
    * @param _dst Destination address to perform the delegatecall
    * @param _calldata Calldata for the delegatecall
    */
    function delegatedFwd(address _dst, bytes _calldata) internal {
        uint useByzantiumOpcodes = IS_BYZANTIUM ? 1 : 0;
        assembly {
            switch extcodesize(_dst) case 0 { revert(0, 0) }

            switch useByzantiumOpcodes
            case 0 {
                let len := 4096
                let result := delegatecall(sub(gas, 10000), _dst, add(_calldata, 0x20), mload(_calldata), 0, len)
                switch result case 0 { invalid() }
                return (0, len)
            }
            default {
                let result := delegatecall(sub(gas, 10000), _dst, add(_calldata, 0x20), mload(_calldata), 0, 0)
                let size := returndatasize

                let ptr := mload(0x40)
                returndatacopy(ptr, 0, size)

                // revert instead of invalid() bc if the underlying call failed with invalid() it already wasted gas.
                // if the call returned error data, forward it
                switch result case 0 { revert(ptr, size) }
                default { return(ptr, size) }
            }
        }
    }
}

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
